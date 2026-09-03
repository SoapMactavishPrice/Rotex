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
    private static final String GST_API_BASE         = 'https://gst.jamku.app/api/gstin/';
    private static final String GST_API_KEY          = 'RZRZMZQQMAL';

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
    // Isolation: WHERE Channel_Partner_Name__c = dealer's Account
    // Rejection Remark = CRM approval "Comments" (ProcessInstance), not an Account field
    // ─────────────────────────────────────────────

    /** Portal list row: Account + Reject Account modal Comments from approval history. */
    public class CustomerListRow {
        @AuraEnabled public Account record;
        @AuraEnabled public String rejectionRemark;
        /**
         * Latest activity timestamp: Account LastModifiedDate plus related
         * Quote / Order / Task / Event touch times for this secondary customer.
         */
        @AuraEnabled public Datetime lastModifiedDate;
    }

    @AuraEnabled
    public static List<CustomerListRow> getCustomersByDealer(Id dealerAccountId) {
        try {
            if (dealerAccountId == null) {
                throw new AuraHandledException('Dealer Account ID is required.');
            }

            List<Account> customers = [
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
                    Target_Non_Rotex__c,
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
                    CreatedById,
                    OwnerId,
                    LastModifiedDate,
                    Approval_Status__c,
                    Approved_Date__c,
                    Rejection_date__c
                FROM Account
                WHERE Channel_Partner_Name__c = :dealerAccountId
                  AND RecordType.DeveloperName = 'Customer'
                ORDER BY CreatedDate DESC
            ];
            customers = (List<Account>) DealerVisibilityService.filterByVisibility(customers);

            Map<Id, String> remarksByAccount = getApprovalRejectionComments(customers);
            Map<Id, Datetime> activityByAccount = getLastActivityDates(customers);

            List<CustomerListRow> rows = new List<CustomerListRow>();
            for (Account a : customers) {
                CustomerListRow row = new CustomerListRow();
                row.record = a;
                row.rejectionRemark = remarksByAccount.get(a.Id);
                Datetime activity = activityByAccount.get(a.Id);
                row.lastModifiedDate = activity != null ? activity : a.LastModifiedDate;
                rows.add(row);
            }
            return rows;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Max of Account.LastModifiedDate and related Quote / Order / Task / Event
     * changes so portal shows when CP last worked against this secondary customer.
     */
    private static Map<Id, Datetime> getLastActivityDates(List<Account> customers) {
        Map<Id, Datetime> latestByAccount = new Map<Id, Datetime>();
        if (customers == null || customers.isEmpty()) {
            return latestByAccount;
        }

        Set<Id> accountIds = new Set<Id>();
        for (Account a : customers) {
            accountIds.add(a.Id);
            if (a.LastModifiedDate != null) {
                latestByAccount.put(a.Id, a.LastModifiedDate);
            }
        }

        // Quotes on standard Account, Quote Account, or custom Account__c
        for (AggregateResult ar : [
            SELECT AccountId accId, MAX(LastModifiedDate) lastTouch
            FROM Quote
            WHERE AccountId IN :accountIds
            GROUP BY AccountId
        ]) {
            mergeLatest(latestByAccount, (Id) ar.get('accId'), (Datetime) ar.get('lastTouch'));
        }
        for (AggregateResult ar : [
            SELECT QuoteAccountId accId, MAX(LastModifiedDate) lastTouch
            FROM Quote
            WHERE QuoteAccountId IN :accountIds
            GROUP BY QuoteAccountId
        ]) {
            mergeLatest(latestByAccount, (Id) ar.get('accId'), (Datetime) ar.get('lastTouch'));
        }
        for (AggregateResult ar : [
            SELECT Account__c accId, MAX(LastModifiedDate) lastTouch
            FROM Quote
            WHERE Account__c IN :accountIds
            GROUP BY Account__c
        ]) {
            mergeLatest(latestByAccount, (Id) ar.get('accId'), (Datetime) ar.get('lastTouch'));
        }

        // Orders for this customer account
        for (AggregateResult ar : [
            SELECT AccountId accId, MAX(LastModifiedDate) lastTouch
            FROM Order
            WHERE AccountId IN :accountIds
            GROUP BY AccountId
        ]) {
            mergeLatest(latestByAccount, (Id) ar.get('accId'), (Datetime) ar.get('lastTouch'));
        }

        // Tasks / Events related to the customer
        for (AggregateResult ar : [
            SELECT WhatId accId, MAX(LastModifiedDate) lastTouch
            FROM Task
            WHERE WhatId IN :accountIds
            GROUP BY WhatId
        ]) {
            mergeLatest(latestByAccount, (Id) ar.get('accId'), (Datetime) ar.get('lastTouch'));
        }
        for (AggregateResult ar : [
            SELECT WhatId accId, MAX(LastModifiedDate) lastTouch
            FROM Event
            WHERE WhatId IN :accountIds
            GROUP BY WhatId
        ]) {
            mergeLatest(latestByAccount, (Id) ar.get('accId'), (Datetime) ar.get('lastTouch'));
        }

        // Contacts under customer (registration multi-contact updates)
        for (AggregateResult ar : [
            SELECT AccountId accId, MAX(LastModifiedDate) lastTouch
            FROM Contact
            WHERE AccountId IN :accountIds
            GROUP BY AccountId
        ]) {
            mergeLatest(latestByAccount, (Id) ar.get('accId'), (Datetime) ar.get('lastTouch'));
        }

        return latestByAccount;
    }

    private static void mergeLatest(Map<Id, Datetime> latestByAccount, Id accountId, Datetime candidate) {
        if (accountId == null || candidate == null) {
            return;
        }
        Datetime current = latestByAccount.get(accountId);
        if (current == null || candidate > current) {
            latestByAccount.put(accountId, candidate);
        }
    }

    /**
     * Latest non-blank Comments from ProcessInstance when approver rejected
     * (same text as CRM Reject Account Comments box).
     */
    private static Map<Id, String> getApprovalRejectionComments(List<Account> customers) {
        Map<Id, String> remarksByAccount = new Map<Id, String>();
        if (customers == null || customers.isEmpty()) {
            return remarksByAccount;
        }

        Set<Id> rejectedIds = new Set<Id>();
        for (Account a : customers) {
            if (a.Approval_Status__c == 'Rejected') {
                rejectedIds.add(a.Id);
            }
        }
        if (rejectedIds.isEmpty()) {
            return remarksByAccount;
        }

        for (ProcessInstance pi : [
            SELECT TargetObjectId,
                (SELECT Comments, StepStatus, CreatedDate
                 FROM StepsAndWorkitems
                 WHERE StepStatus = 'Rejected'
                 ORDER BY CreatedDate DESC)
            FROM ProcessInstance
            WHERE TargetObjectId IN :rejectedIds
            ORDER BY CreatedDate DESC
        ]) {
            if (remarksByAccount.containsKey(pi.TargetObjectId)) {
                continue;
            }
            if (pi.StepsAndWorkitems == null || pi.StepsAndWorkitems.isEmpty()) {
                continue;
            }
            for (ProcessInstanceHistory hist : pi.StepsAndWorkitems) {
                if (String.isNotBlank(hist.Comments)) {
                    remarksByAccount.put(pi.TargetObjectId, hist.Comments);
                    break;
                }
            }
        }
        return remarksByAccount;
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

            assertAnnualPotentialNotLessThanTarget(input);

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
                    input.gstNo,
                    input.pinCode,
                    input.businessType,
                    input.dealerAccountId,
                    null
                );

                if (dup != null) {
                    throw new AuraHandledException(buildDuplicateMessage(dup));
                }
            }

            ContactPersonInput primary = getPrimaryContactPerson(input);

            Account newCustomer = new Account(
                RecordTypeId                          = customerRT.Id,
                Name                                   = input.customerName,
                Customer_Name__c                       = input.customerName,
                Channel_Partner_Name__c                = currentUser.AccountId,
                OwnerId                                = UserInfo.getUserId(),
                GST_No__c                              = input.gstNo,
                Timestamp__c                           = ts,
                Street__c                              = input.address,
                Business_type__c                       = input.businessType,
                Target__c                              = resolveTargetRotex(input),
                Target_Non_Rotex__c                    = resolveTargetNonRotex(input),
                Customer_Profile__c                    = input.customerProfile,
                Additional_details_in_case_of_OEM__c   = input.oemDetails,
                State__c                               = input.state,
                District__c                            = input.district,
                Postal_Code__c                         = input.pinCode,
                Annual_Business_Potential__c           = input.annualPotential,
                Website                                = input.customerWebsite,
                Country__c                             = input.country,
                Contact_Person_Name__c                 = primary != null ? primary.firstName : input.contactFirstName,
                Contact_Person_Last_Name__c            = primary != null ? primary.lastName : input.contactLastName,
                Contact_Person_Telephone_No__c         = primary != null ? primary.phone : input.contactPhone,
                Contact_Person_Email_ID__c             = primary != null ? primary.email : input.contactEmail,
                Contact_Person_Designation__c          = primary != null ? primary.designation : input.contactDesignation
            );

            insert newCustomer;
            createDealerContacts(newCustomer.Id, input);
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
    // Create Contact records under the customer Account
    // ─────────────────────────────────────────────
    private static ContactPersonInput getPrimaryContactPerson(CustomerInput input) {
        List<ContactPersonInput> people = resolveContactPeople(input);
        return people.isEmpty() ? null : people[0];
    }

    private static List<ContactPersonInput> resolveContactPeople(CustomerInput input) {
        List<ContactPersonInput> people = new List<ContactPersonInput>();
        if (input.contacts != null) {
            for (ContactPersonInput cp : input.contacts) {
                if (cp == null) {
                    continue;
                }
                if (String.isBlank(cp.firstName)
                    && String.isBlank(cp.lastName)
                    && String.isBlank(cp.phone)
                    && String.isBlank(cp.email)) {
                    continue;
                }
                people.add(cp);
            }
        }
        if (people.isEmpty()
            && (String.isNotBlank(input.contactFirstName)
                || String.isNotBlank(input.contactLastName))) {
            ContactPersonInput single = new ContactPersonInput();
            single.firstName = input.contactFirstName;
            single.lastName = input.contactLastName;
            single.phone = input.contactPhone;
            single.email = input.contactEmail;
            single.designation = input.contactDesignation;
            people.add(single);
        }
        return people;
    }

    private static void createDealerContacts(Id customerAccountId, CustomerInput input) {
        List<ContactPersonInput> people = resolveContactPeople(input);
        if (people.isEmpty()) {
            return;
        }

        List<Contact> toInsert = new List<Contact>();
        for (ContactPersonInput cp : people) {
            // Skip already-persisted contacts (edit flow)
            if (String.isNotBlank(cp.contactId)) {
                continue;
            }
            Contact con = new Contact(
                AccountId = customerAccountId,
                OwnerId = UserInfo.getUserId(),
                FirstName = cp.firstName,
                LastName = String.isBlank(cp.lastName) ? cp.firstName : cp.lastName,
                Phone = cp.phone,
                Email = cp.email,
                CurrencyIsoCode = UserInfo.getDefaultCurrency(),
                Status__c = 'Active',
                Contact_Person_Designation__c = cp.designation
            );
            toInsert.add(con);
        }
        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
    }

    @AuraEnabled
    public static List<Map<String, String>> getCustomerContacts(Id customerId) {
        if (customerId == null) {
            return new List<Map<String, String>>();
        }
        List<Map<String, String>> rows = new List<Map<String, String>>();
        List<Contact> contacts = [
            SELECT Id, FirstName, LastName, Phone, Email,
                   Contact_Person_Designation__c, OwnerId, CreatedById
            FROM Contact
            WHERE AccountId = :customerId
            ORDER BY CreatedDate ASC
        ];
        contacts = (List<Contact>) DealerVisibilityService.filterByVisibility(contacts);
        for (Contact c : contacts) {
            rows.add(new Map<String, String>{
                'contactId' => c.Id,
                'firstName' => c.FirstName,
                'lastName' => c.LastName,
                'phone' => c.Phone,
                'email' => c.Email,
                'designation' => c.Contact_Person_Designation__c
            });
        }
        return rows;
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

    String biz = String.isNotBlank(dup.Business_type__c)
        ? dup.Business_type__c
        : 'the same business line';

    String message =
        'This GST Number and Pin Code is already registered ' +
        (String.isNotBlank(dup.Approval_Status__c)
            ? '(' + dup.Approval_Status__c + ') '
            : '') +
        'for business line "' + biz + '" under Channel Partner "' +
        dealerName +
        '" (' +
        dup.Name +
        '). You cannot register another customer with business line ROTEX or BOTH using the same GST and Pin Code when an Approved ROTEX/BOTH customer already exists.';

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
            assertAnnualPotentialNotLessThanTarget(input);

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
                    Target_Non_Rotex__c,
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
                    input.gstNo,
                    input.pinCode,
                    input.businessType,
                    currentUser.AccountId,
                    input.customerId
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
            acc.Target__c                             = resolveTargetRotex(input);
            acc.Target_Non_Rotex__c                   = resolveTargetNonRotex(input);
            acc.Customer_Profile__c                   = input.customerProfile;
            acc.Additional_details_in_case_of_OEM__c  = input.oemDetails;
            acc.State__c                              = input.state;
            acc.District__c                           = input.district;
            acc.Postal_Code__c = input.pinCode;
            acc.Annual_Business_Potential__c          = input.annualPotential;
            acc.Website           = input.customerWebsite;
           acc.Country__c = input.country;
            ContactPersonInput primary = getPrimaryContactPerson(input);
            if (primary != null) {
                acc.Contact_Person_Name__c = primary.firstName;
                acc.Contact_Person_Last_Name__c = primary.lastName;
                acc.Contact_Person_Telephone_No__c = primary.phone;
                acc.Contact_Person_Email_ID__c = primary.email;
                acc.Contact_Person_Designation__c = primary.designation;
            } else {
                acc.Contact_Person_Name__c = input.contactFirstName;
                acc.Contact_Person_Last_Name__c = input.contactLastName;
                acc.Contact_Person_Telephone_No__c        = input.contactPhone;
                acc.Contact_Person_Email_ID__c            = input.contactEmail;
                acc.Contact_Person_Designation__c         = input.contactDesignation;
            }
    
            update acc;
            createDealerContacts(acc.Id, input);
    
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

        String district = office.get('District') != null
            ? String.valueOf(office.get('District')).trim()
            : '';
        String state = office.get('State') != null
            ? String.valueOf(office.get('State')).trim()
            : '';

        // Return whatever is available (either/both) so the UI can lock only filled fields
        return new Map<String, String>{
            'district' => String.isNotBlank(district) ? district : null,
            'state'    => String.isNotBlank(state) ? state : null
        };
    }

    // ─────────────────────────────────────────────
    // GST search API (Jamku)
    // ─────────────────────────────────────────────
    public class GSTDetails {
        @AuraEnabled public Boolean isValid           { get; set; }
        @AuraEnabled public String  legalName         { get; set; }
        @AuraEnabled public String  registeredAddress { get; set; }
        @AuraEnabled public String  pincode           { get; set; }
        @AuraEnabled public String  tradeName         { get; set; }
        @AuraEnabled public String  status            { get; set; }
        @AuraEnabled public String  gstin             { get; set; }
    }

    @AuraEnabled
    public static GSTDetails fetchGSTDetails(String gstNo) {
        GSTDetails result = new GSTDetails();
        result.isValid = false;

        if (String.isBlank(gstNo) || gstNo.trim().length() != 15) {
            return result;
        }

        try {
            String gstin = gstNo.trim().toUpperCase();
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(
                GST_API_BASE + EncodingUtil.urlEncode(gstin, 'UTF-8')
                + '?apiKeySelf=' + EncodingUtil.urlEncode(GST_API_KEY, 'UTF-8')
            );
            req.setMethod('GET');
            req.setTimeout(120000);
            req.setHeader('Accept', 'application/json');

            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200) {
                return result;
            }

            Map<String, Object> response =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

            if (response == null) {
                return result;
            }

            // Jamku success + data payload
            // Some GSTINs return success with blank name / address / pincode — still treat as verified
            Boolean success = response.get('success') == true;
            Object dataObj = response.get('data');
            if (!success || !(dataObj instanceof Map<String, Object>)) {
                return result;
            }

            Map<String, Object> data = (Map<String, Object>) dataObj;

            String responseGstin = data.get('gstin') != null
                ? String.valueOf(data.get('gstin')).trim().toUpperCase()
                : null;
            String pan = data.get('pan') != null
                ? String.valueOf(data.get('pan')).trim()
                : null;

            // Valid if Jamku returns the GSTIN, or at least PAN from a successful lookup
            if (String.isBlank(responseGstin) && String.isBlank(pan) && data.isEmpty()) {
                return result;
            }

            String legalName = data.get('lgnm') != null
                ? String.valueOf(data.get('lgnm')).trim()
                : null;
            String tradeName = data.get('tradeName') != null
                ? String.valueOf(data.get('tradeName')).trim()
                : null;
            // Jamku sometimes uses tradeNam
            if (String.isBlank(tradeName) && data.get('tradeNam') != null) {
                tradeName = String.valueOf(data.get('tradeNam')).trim();
            }
            String regAddress = data.get('adr') != null
                ? String.valueOf(data.get('adr')).trim()
                : null;
            String pincode = data.get('pincode') != null
                ? String.valueOf(data.get('pincode')).trim()
                : null;
            String status = data.get('sts') != null
                ? String.valueOf(data.get('sts')).trim()
                : null;

            // Normalize empty strings to null so portal can leave those fields manual
            if (String.isBlank(legalName)) {
                legalName = null;
            }
            if (String.isBlank(tradeName)) {
                tradeName = null;
            }
            if (String.isBlank(regAddress)) {
                regAddress = null;
            }
            if (String.isBlank(pincode)) {
                pincode = null;
            }

            result.isValid = true;
            result.gstin = String.isNotBlank(responseGstin) ? responseGstin : gstin;
            result.legalName = legalName;
            // Trade name drives Customer Name on the registration form
            result.tradeName = tradeName;
            result.registeredAddress = regAddress;
            result.pincode = pincode;
            result.status = status;
            return result;

        } catch (Exception e) {
            System.debug(e.getMessage());
            return result;
        }
    }

    @AuraEnabled
    public static Boolean verifyGST(String gstNo) {
        GSTDetails details = fetchGSTDetails(gstNo);
        return details != null && details.isValid == true;
    }

    /**
     * Annual Business Potential must not be less than Target (Rotex) when both are set.
     */
    private static void assertAnnualPotentialNotLessThanTarget(CustomerInput input) {
        if (input == null || input.annualPotential == null || String.isBlank(input.target)) {
            return;
        }
        String bl = input.businessType == null ? '' : input.businessType.trim();
        if (bl.equalsIgnoreCase('Non ROTEX')) {
            return;
        }
        String cleaned = input.target.trim().replaceAll(',', '');
        Decimal targetVal;
        try {
            targetVal = Decimal.valueOf(cleaned);
        } catch (Exception ex) {
            return;
        }
        if (input.annualPotential < targetVal) {
            throw new AuraHandledException(
                'Annual Business Potential cannot be less than Target (Rotex).'
            );
        }
    }

    /**
     * ROTEX / BOTH → Target__c; Non ROTEX clears Rotex target.
     */
    private static String resolveTargetRotex(CustomerInput input) {
        if (input == null) {
            return null;
        }
        String bl = input.businessType == null ? '' : input.businessType.trim();
        if (bl.equalsIgnoreCase('Non ROTEX')) {
            return null;
        }
        return String.isBlank(input.target) ? null : input.target.trim();
    }

    /**
     * Non ROTEX / BOTH → Target_Non_Rotex__c; pure ROTEX clears Non-Rotex target.
     */
    private static Decimal resolveTargetNonRotex(CustomerInput input) {
        if (input == null) {
            return null;
        }
        String bl = input.businessType == null ? '' : input.businessType.trim();
        if (bl.equalsIgnoreCase('ROTEX')) {
            return null;
        }
        return input.targetNonRotex;
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
        /** Target(Rotex) — maps to Account.Target__c (Text) */
        @AuraEnabled public String  target             { get; set; }
        /** Target(Non-Rotex) — maps to Account.Target_Non_Rotex__c (Number) */
        @AuraEnabled public Decimal targetNonRotex     { get; set; }
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
        /** Multiple contacts (preferred). Falls back to single contact* fields. */
        @AuraEnabled public List<ContactPersonInput> contacts { get; set; }
    }

    public class ContactPersonInput {
        @AuraEnabled public String contactId   { get; set; }
        @AuraEnabled public String firstName   { get; set; }
        @AuraEnabled public String lastName    { get; set; }
        @AuraEnabled public String designation { get; set; }
        @AuraEnabled public String phone       { get; set; }
        @AuraEnabled public String email       { get; set; }
    }
}