/**
 * CustomerController.cls
 * Apex controller for Customer Management LWC
 * Handles CRUD for Account (Customer) records, file uploads,
 * and dealer-scoped visibility.
 */
public without sharing class CustomerController {

    // ─────────────────────────────────────────────
    // Callout endpoint constants
    // ─────────────────────────────────────────────
    private static final String PINCODE_API_ENDPOINT = 'https://api.postalpincode.in/pincode/';
    private static final String GST_API_ENDPOINT      = 'https://services.gst.gov.in/services/api/search/goodservice?gstin=';

    // ─────────────────────────────────────────────
    // Get logged-in dealer's Account (Parent Account)
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static Account getDealerAccount() {
        try {
            // Fetch the Account linked to the current portal/community user
            User currentUser = [
                SELECT Id, Name, AccountId, Account.Name, Account.RecordType.DeveloperName
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];

            if (currentUser.AccountId == null) {
                throw new AuraHandledException('No dealer account linked to your user. Please contact your administrator.');
            }

            return [
                SELECT Id, Name, RecordType.DeveloperName
                FROM Account
                WHERE Id = :currentUser.AccountId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─────────────────────────────────────────────
    // Get all Customer accounts under this dealer
    // Isolation: WHERE ParentId = dealer's Account
    // ─────────────────────────────────────────────
    @AuraEnabled
    public static List<Account> getCustomersByDealer(Id dealerAccountId) {
        try {
            if (dealerAccountId == null) {
                throw new AuraHandledException('Dealer Account ID is required.');
            }

            return [
                SELECT
                    Id,
                    Name,
                    ParentId,
                    Parent.Name,
                    Channel_Partner_Name__c,
                    Channel_Partner_Name__r.Name,
                    RecordType.DeveloperName,
                    RecordType.Name,
                    Customer_Name__c,
                    GST_No__c,
                    Timestamp__c,
                    Street__c,
                    Business_type__c,
                    Target__c,
                    Customer_Profile__c,
                    Additional_details_in_case_of_OEM__c,
                    State__c,
                    District__c,
                    Postal_Code__c,
                    Annual_Business_Potential__c,
                    Website,
                   Country__c,
Contact_Person_Name__c,
Contact_Person_Last_Name__c,
                    Contact_Person_Telephone_No__c,
                    Contact_Person_Email_ID__c,
                    Contact_Person_Designation__c,
                    CreatedDate,
                    Approval_Status__c
                FROM Account
                WHERE Channel_Partner_Name__c = :dealerAccountId
AND RecordType.DeveloperName = 'Customer'
                ORDER BY CreatedDate DESC
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─────────────────────────────────────────────
    // Create a new Customer account under the dealer
    // ─────────────────────────────────────────────
    @AuraEnabled
    public static Id createCustomer(CustomerInput input) {
        try {
            // Validate dealer isolation — confirm the dealer account belongs to the current user
            User currentUser = [
                SELECT AccountId, Email, Account.Name
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];

            if (currentUser.AccountId == null || currentUser.AccountId != input.dealerAccountId) {
                throw new AuraHandledException('You are not authorised to create customers under this dealer account.');
            }

            // Fetch Customer Record Type Id
            RecordType customerRT = [
                SELECT Id
                FROM RecordType
                WHERE SObjectType = 'Account'
                  AND DeveloperName = 'Customer'
                LIMIT 1
            ];

            Datetime ts = System.now();

            if (String.isNotBlank(input.gstNo) && String.isNotBlank(input.pinCode)) {
                Account dup = DuplicateCheckHelper.findGstPinDuplicate(
                    input.gstNo, input.pinCode, null
                );

                if (dup != null) {
                    throw new AuraHandledException(buildDuplicateMessage(dup));
                }
            }

            Account newCustomer = new Account(
                RecordTypeId                          = customerRT.Id,
                Name                                   = input.customerName,
                Customer_Name__c                       = input.customerName,
                Channel_Partner_Name__c                = currentUser.AccountId,
                GST_No__c                              = input.gstNo,
                Timestamp__c                           = ts,
                Street__c = input.address,
                Business_type__c                       = input.businessType,
                Target__c                              = input.target,
                Customer_Profile__c                    = input.customerProfile,
                Additional_details_in_case_of_OEM__c   = input.oemDetails,
                State__c                                = input.state,
                District__c                             = input.district,
                Postal_Code__c = input.pinCode,
                Annual_Business_Potential__c            = input.annualPotential,
                Website = input.customerWebsite,
              Country__c = input.country,
Contact_Person_Name__c = input.contactFirstName,
Contact_Person_Last_Name__c = input.contactLastName,
                Contact_Person_Telephone_No__c          = input.contactPhone,
                Contact_Person_Email_ID__c              = input.contactEmail,
                Contact_Person_Designation__c           = input.contactDesignation
            );

            insert newCustomer;
            createDealerContact(newCustomer.Id, input);
            return newCustomer.Id;

        } catch (AuraHandledException e) {
            throw e;
        } catch (DmlException dmlEx) {
            throw new AuraHandledException(
                'Save failed: ' + dmlEx.getDmlMessage(0)
            );
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unexpected Error: ' + e.getMessage()
            );
        }
    }

    // ─────────────────────────────────────────────
    // Create a Contact under the dealer Account from
    // the customer's contact-person details
    // ─────────────────────────────────────────────
   private static void createDealerContact(Id customerAccountId, CustomerInput input) {
    if (String.isBlank(input.contactFirstName) && String.isBlank(input.contactLastName)) {
        return;
    }

    Contact con = new Contact(
    AccountId = customerAccountId,
    FirstName = input.contactFirstName,
    LastName = String.isBlank(input.contactLastName)
        ? input.contactFirstName
        : input.contactLastName,
    Phone = input.contactPhone,
    Email = input.contactEmail,
    CurrencyIsoCode = UserInfo.getDefaultCurrency()
);
    if (String.isNotBlank(input.contactDesignation)) {
        con.Contact_Person_Designation__c = input.contactDesignation;
    }

    insert con;
}
private static String getPrimaryContactName(Id accountId) {
    List<Contact> contacts = [
        SELECT Name
        FROM Contact
        WHERE AccountId = :accountId
        ORDER BY CreatedDate ASC
        LIMIT 1
    ];

    return contacts.isEmpty() ? null : contacts[0].Name;
}

// ─────────────────────────────────────────────
// Build a clear, professional duplicate-account message
// ─────────────────────────────────────────────
private static String buildDuplicateMessage(Account dup) {

    String contactName = getPrimaryContactName(dup.Id);

    String dealerName = '';

    if (dup.Channel_Partner_Name__r != null) {
        dealerName = dup.Channel_Partner_Name__r.Name;
    }

    String message =
        'This GST Number and Pin Code combination is already registered under Channel Partner "' +
        dealerName +
        '" by "' +
        dup.Name +
        '"';

    if (String.isNotBlank(contactName)) {
        message += ' (Primary Contact: ' + contactName + ')';
    }


    return message;
}
    // ─────────────────────────────────────────────
    // Update an existing Customer account
    // ─────────────────────────────────────────────
    @AuraEnabled
    public static Id updateCustomer(CustomerInput input) {
        Boolean wasLocked = false;
        try {
            List<Account> accList = [
                SELECT
                    Id,
                    ParentId,
                    Name,
                    Channel_Partner_Name__c,
                    Customer_Name__c,
                    GST_No__c,
                    Street__c,
                    Business_type__c,
                    Target__c,
                    Customer_Profile__c,
                    Additional_details_in_case_of_OEM__c,
                    State__c,
                    District__c,
                    Postal_Code__c,
                    Annual_Business_Potential__c,
                    Website,
                   Country__c,
Contact_Person_Name__c,
Contact_Person_Last_Name__c,
                    Contact_Person_Telephone_No__c,
                    Contact_Person_Email_ID__c,
                    Contact_Person_Designation__c
                FROM Account
                WHERE Id = :input.customerId
            ];
    
            if (accList.isEmpty()) {
                throw new AuraHandledException('Customer not found.');
            }
    
            Account acc = accList[0];
    
            User currentUser = [
                SELECT AccountId
                FROM User
                WHERE Id = :UserInfo.getUserId()
            ];
    
            if (acc.Channel_Partner_Name__c != currentUser.AccountId) {
            throw new AuraHandledException('You are not authorised to update this customer.');
       }
    
            if (String.isNotBlank(input.gstNo) && String.isNotBlank(input.pinCode)) {
                Account dup = DuplicateCheckHelper.findGstPinDuplicate(
                    input.gstNo, input.pinCode, input.customerId
                );
    
                if (dup != null) {
                    throw new AuraHandledException(buildDuplicateMessage(dup));
                }
            }
    
            // ── Unlock if the record is locked by an approval process ──
            Approval.UnlockResult[] unlockResults = Approval.unlock(new List<Id>{ acc.Id }, false);
            if (unlockResults[0].isSuccess()) {
                wasLocked = true;
            }
    
            acc.Name                                  = input.customerName;
            acc.Customer_Name__c                      = input.customerName;
            acc.GST_No__c                             = input.gstNo;
            acc.Street__c = input.address;
            acc.Business_type__c                      = input.businessType;
            acc.Target__c                             = input.target;
            acc.Customer_Profile__c                   = input.customerProfile;
            acc.Additional_details_in_case_of_OEM__c  = input.oemDetails;
            acc.State__c                              = input.state;
            acc.District__c                           = input.district;
            acc.Postal_Code__c = input.pinCode;
            acc.Annual_Business_Potential__c          = input.annualPotential;
            acc.Website           = input.customerWebsite;
           acc.Country__c = input.country;
            acc.Contact_Person_Name__c = input.contactFirstName;
            acc.Contact_Person_Last_Name__c = input.contactLastName;
            acc.Contact_Person_Telephone_No__c        = input.contactPhone;
            acc.Contact_Person_Email_ID__c            = input.contactEmail;
            acc.Contact_Person_Designation__c         = input.contactDesignation;
    
            update acc;
    
            return acc.Id;
    
        } catch (AuraHandledException e) {
            throw e;
        } catch (DmlException dmlEx) {
            throw new AuraHandledException(
                'Save failed: ' + dmlEx.getDmlMessage(0)
            );
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unexpected Error: ' + e.getMessage()
            );
        } finally {
            // ── Re-lock the record if we unlocked it ──
            if (wasLocked) {
                Approval.lock(new List<Id>{ input.customerId }, false);
            }
        }
    }
    @AuraEnabled(cacheable=true)
    public static Boolean getShowSoTreeFlag() {
        Feature_Setting__mdt setting = Feature_Setting__mdt.getInstance('Default');
        return setting != null && setting.Show_SO_Tree__c;
    }

    // ─────────────────────────────────────────────
    // Save ContentVersion (file/attachment) and link
    // to the customer Account via ContentDocumentLink
    // ─────────────────────────────────────────────
    @AuraEnabled
    public static void saveAttachment(Id recordId, String fileName, String base64Data, String fileType) {
        try {
            // Validate the record belongs to current user's dealer tree
            Account acct = [
                SELECT Id, ParentId
                FROM Account
                WHERE Id = :recordId
                LIMIT 1
            ];

            User currentUser = [
                SELECT AccountId
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];

            if (acct.ParentId != currentUser.AccountId
                && acct.Channel_Partner_Name__c != currentUser.AccountId) {
                throw new AuraHandledException('Unauthorised attachment operation.');
            }

            ContentVersion cv = new ContentVersion(
                Title          = fileName,
                PathOnClient   = fileName,
                VersionData    = EncodingUtil.base64Decode(base64Data),
                IsMajorVersion = true
            );
            insert cv;

            // Get the ContentDocumentId from the inserted ContentVersion
            ContentVersion insertedCV = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ];

            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = insertedCV.ContentDocumentId,
                LinkedEntityId    = recordId,
                ShareType         = 'V',
                Visibility        = 'AllUsers'
            );
            insert cdl;

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─────────────────────────────────────────────
    // Get attachments (Salesforce Files) for a record
    // ─────────────────────────────────────────────
    @AuraEnabled
    public static List<ContentDocument> getAttachments(Id recordId) {
        try {
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :recordId
            ];

            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink cdl : links) {
                docIds.add(cdl.ContentDocumentId);
            }

            if (docIds.isEmpty()) {
                return new List<ContentDocument>();
            }

            return [
                SELECT
                    Id,
                    Title,
                    FileType,
                    FileExtension,
                    ContentSize,
                    CreatedDate,
                    LatestPublishedVersionId
                FROM ContentDocument
                WHERE Id IN :docIds
                ORDER BY CreatedDate DESC
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─────────────────────────────────────────────
    // Look up State / District for a given Pin Code
    // via the postalpincode.in public API
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getStateDistrictByPincode(String pinCode) {

        Http http = new Http();
        HttpRequest req = new HttpRequest();

        req.setEndpoint(PINCODE_API_ENDPOINT + pinCode);
        req.setMethod('GET');

        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            return null;
        }

        List<Object> response = (List<Object>) JSON.deserializeUntyped(res.getBody());

        if (response.isEmpty()) {
            return null;
        }

        Map<String, Object> first = (Map<String, Object>) response[0];

        if ((String) first.get('Status') != 'Success') {
            return null;
        }

        List<Object> offices = (List<Object>) first.get('PostOffice');

        if (offices == null || offices.isEmpty()) {
            return null;
        }

        Map<String, Object> office = (Map<String, Object>) offices[0];

        return new Map<String, String>{
            'district' => (String) office.get('District'),
            'state'    => (String) office.get('State')
        };
    }

    // ─────────────────────────────────────────────
    // GST search API
    // ─────────────────────────────────────────────
    @AuraEnabled
    public static Boolean verifyGST(String gstNo) {
        try {
            Http http = new Http();
            HttpRequest req = new HttpRequest();

            req.setEndpoint(
                GST_API_ENDPOINT + EncodingUtil.urlEncode(gstNo, 'UTF-8')
            );

            req.setMethod('GET');
            req.setTimeout(120000);

            HttpResponse res = http.send(req);

            System.debug('Status Code : ' + res.getStatusCode());
            System.debug('Response : ' + res.getBody());

            if (res.getStatusCode() != 200) {
                return false;
            }

            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

            // Invalid GST
            if (response.containsKey('errorCode')) {
                return false;
            }

            // Goods Details
            if (response.containsKey('bzgddtls')) {
                List<Object> goods = (List<Object>) response.get('bzgddtls');

                if (goods != null && !goods.isEmpty()) {
                    return true;
                }
            }

            // Service Details
            if (response.containsKey('bzsdtls')) {
                List<Object> services = (List<Object>) response.get('bzsdtls');

                if (services != null && !services.isEmpty()) {
                    return true;
                }
            }

            // Any other list returned by GST API
            for (String key : response.keySet()) {
                Object value = response.get(key);

                if (value instanceof List<Object>) {
                    List<Object> data = (List<Object>) value;

                    if (data != null && !data.isEmpty()) {
                        return true;
                    }
                }
            }

            return false;

        } catch (Exception e) {
            System.debug(e.getMessage());
            return false;
        }
    }

    // ─────────────────────────────────────────────
    // Inner wrapper class for create/update input
    // ─────────────────────────────────────────────
    public class CustomerInput {
        @AuraEnabled public Id      dealerAccountId    { get; set; }
        @AuraEnabled public Id      customerId         { get; set; }
        @AuraEnabled public String  customerName       { get; set; }
        @AuraEnabled public String  gstNo              { get; set; }
        @AuraEnabled public String  address            { get; set; }
        @AuraEnabled public String  businessType       { get; set; }
        @AuraEnabled public String  target             { get; set; }
        @AuraEnabled public String  customerProfile    { get; set; }
        @AuraEnabled public String  oemDetails         { get; set; }
        @AuraEnabled public String  state              { get; set; }
        @AuraEnabled public String  district           { get; set; }
        @AuraEnabled public String  pinCode            { get; set; }
        @AuraEnabled public Decimal annualPotential    { get; set; }
        @AuraEnabled public String  customerWebsite    { get; set; }
       @AuraEnabled public String country { get; set; }
@AuraEnabled public String contactFirstName { get; set; }
@AuraEnabled public String contactLastName { get; set; }
        @AuraEnabled public String  contactPhone       { get; set; }
        @AuraEnabled public String  contactEmail       { get; set; }
        @AuraEnabled public String  contactDesignation { get; set; }
    }
}