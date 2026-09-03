public without sharing class NewLeadController {

    public class LeadCreateInput {
        @AuraEnabled public String salutation { get; set; }
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String lastName { get; set; }
        @AuraEnabled public String company { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String website { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String leadSource { get; set; }
        @AuraEnabled public String requirement { get; set; }
        @AuraEnabled public String gstNumber { get; set; }
        @AuraEnabled public String street { get; set; }
        @AuraEnabled public String city { get; set; }
        @AuraEnabled public String state { get; set; }
        @AuraEnabled public String postalCode { get; set; }
        @AuraEnabled public String country { get; set; }
        @AuraEnabled public Id partnerAccountId { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getLeadSourcePicklistValues() {
        return getActivePicklistValues(Lead.LeadSource.getDescribe());
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getLeadStatusPicklistValues() {
        return getActivePicklistValues(Lead.Dealer_Status__c.getDescribe());
    }

    @AuraEnabled
    public static Lead createLead(LeadCreateInput input) {
        if (input == null) {
            throw new AuraHandledException('Lead details are required.');
        }
        if (String.isBlank(input.firstName)) {
            throw new AuraHandledException('First Name is required.');
        }
        if (String.isBlank(input.lastName)) {
            throw new AuraHandledException('Last Name is required.');
        }
        if (String.isBlank(input.company)) {
            throw new AuraHandledException('Customer Name is required.');
        }
        if (String.isBlank(input.status)) {
            throw new AuraHandledException('Lead Status is required.');
        }
        if (String.isBlank(input.leadSource)) {
            throw new AuraHandledException('Lead Source is required.');
        }
        if (String.isBlank(input.requirement)) {
            throw new AuraHandledException('Requirement is required.');
        }
        if (String.isNotBlank(input.gstNumber) && input.gstNumber.trim().length() != 15) {
            throw new AuraHandledException('GST Number must be exactly 15 characters.');
        }

        Id dealerAccountId = resolveDealerAccountId(input.partnerAccountId);

        Lead ld = new Lead();
        ld.RecordTypeId = getChannelPartnerLeadRecordTypeId();
        ld.Salutation = blankToNull(input.salutation);
        ld.FirstName = input.firstName.trim();
        ld.LastName = input.lastName.trim();
        ld.Company = input.company.trim();
        ld.Title = blankToNull(input.title);
        ld.Phone = blankToNull(input.phone);
        ld.Email = blankToNull(input.email);
        ld.Website = blankToNull(input.website);
        ld.Dealer_Status__c = input.status.trim();
        ld.Status = defaultStandardLeadStatus();
        ld.LeadSource = input.leadSource.trim();
        ld.Requirement__c = input.requirement.trim();
        ld.GST_Number__c = String.isNotBlank(input.gstNumber)
            ? input.gstNumber.trim().toUpperCase()
            : null;
        ld.Street = blankToNull(input.street);
        ld.City = blankToNull(input.city);
        ld.State = blankToNull(input.state);
        ld.PostalCode = blankToNull(input.postalCode);
        ld.Country = blankToNull(input.country);
        ld.OwnerId = UserInfo.getUserId();

        if (dealerAccountId != null) {
            ld.Dealer__c = dealerAccountId;
        }

        try {
            insert ld;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }

        List<Lead> created = [
            SELECT
                Id, Name, Salutation, FirstName, MiddleName, LastName, Title,
                Company, Email, Phone, Website, Status, Dealer_Status__c, Rating,
                LeadSource, Industry, AnnualRevenue, NumberOfEmployees,
                CreatedDate, Description,
                Street, City, State, PostalCode, Country,
                Customer_Type__c,
                Owner.Name,
                Dealer__c, Dealer_Name__c, Territory__c,
                Product_Name__c, Product_Category__c, Product_Interested__c,
                Requirement__c, Dealer_Description__c,
                GST_Number__c,
                Sales_Turnover__c, Quantity__c, Quotation_Value__c,
                Application_Specification__c, Fluid_circuit_Functionality__c,
                Lead_Type__c, Submission_Date__c, Opening_Date__c, Receive_Date__c,
                Enq_No__c
            FROM Lead
            WHERE Id = :ld.Id
            LIMIT 1
        ];
        return created.isEmpty() ? ld : created[0];
    }

    /**
     * Update an existing Channel Partner lead (portal Edit).
     * Create path is separate — do not call this from createLead.
     */
    @AuraEnabled
    public static Lead updateLead(LeadCreateInput input, Id leadId) {
        if (leadId == null) {
            throw new AuraHandledException('Lead Id is required.');
        }
        if (input == null) {
            throw new AuraHandledException('Lead details are required.');
        }
        if (String.isBlank(input.firstName)) {
            throw new AuraHandledException('First Name is required.');
        }
        if (String.isBlank(input.lastName)) {
            throw new AuraHandledException('Last Name is required.');
        }
        if (String.isBlank(input.company)) {
            throw new AuraHandledException('Customer Name is required.');
        }
        if (String.isBlank(input.status)) {
            throw new AuraHandledException('Lead Status is required.');
        }
        if (String.isBlank(input.leadSource)) {
            throw new AuraHandledException('Lead Source is required.');
        }
        if (String.isBlank(input.requirement)) {
            throw new AuraHandledException('Requirement is required.');
        }
        if (String.isNotBlank(input.gstNumber) && input.gstNumber.trim().length() != 15) {
            throw new AuraHandledException('GST Number must be exactly 15 characters.');
        }

        Id dealerAccountId = resolveDealerAccountId(input.partnerAccountId);

        List<Lead> existing = [
            SELECT Id, Dealer__c, IsConverted, OwnerId
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            throw new AuraHandledException('Lead not found.');
        }
        Lead ld = existing[0];
        if (ld.IsConverted) {
            throw new AuraHandledException('Converted leads cannot be edited.');
        }
        if (dealerAccountId != null && ld.Dealer__c != dealerAccountId) {
            throw new AuraHandledException('You are not authorised to update this lead.');
        }

        ld.Salutation = blankToNull(input.salutation);
        ld.FirstName = input.firstName.trim();
        ld.LastName = input.lastName.trim();
        ld.Company = input.company.trim();
        ld.Title = blankToNull(input.title);
        ld.Phone = blankToNull(input.phone);
        ld.Email = blankToNull(input.email);
        ld.Website = blankToNull(input.website);
        ld.Dealer_Status__c = input.status.trim();
        ld.LeadSource = input.leadSource.trim();
        ld.Requirement__c = input.requirement.trim();
        ld.GST_Number__c = String.isNotBlank(input.gstNumber)
            ? input.gstNumber.trim().toUpperCase()
            : null;
        ld.Street = blankToNull(input.street);
        ld.City = blankToNull(input.city);
        ld.State = blankToNull(input.state);
        ld.PostalCode = blankToNull(input.postalCode);
        ld.Country = blankToNull(input.country);

        try {
            update ld;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }

        List<Lead> updated = [
            SELECT
                Id, Name, Salutation, FirstName, MiddleName, LastName, Title,
                Company, Email, Phone, Website, Status, Dealer_Status__c, Rating,
                LeadSource, Industry, AnnualRevenue, NumberOfEmployees,
                CreatedDate, Description,
                Street, City, State, PostalCode, Country,
                Customer_Type__c,
                Owner.Name,
                Dealer__c, Dealer_Name__c, Territory__c,
                Product_Name__c, Product_Category__c, Product_Interested__c,
                Requirement__c, Dealer_Description__c,
                GST_Number__c,
                Sales_Turnover__c, Quantity__c, Quotation_Value__c,
                Application_Specification__c, Fluid_circuit_Functionality__c,
                Lead_Type__c, Submission_Date__c, Opening_Date__c, Receive_Date__c,
                Enq_No__c,
                Regret_Reason1__c, Regret_Reason__c, Regret_Date_Time__c
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];
        return updated.isEmpty() ? ld : updated[0];
    }

    /** Standard Lead.Status is still required by Salesforce; portal stage lives on Dealer_Status__c. */
    private static String defaultStandardLeadStatus() {
        String firstActive;
        for (Schema.PicklistEntry pe : Lead.Status.getDescribe().getPicklistValues()) {
            if (!pe.isActive()) {
                continue;
            }
            if (pe.isDefaultValue()) {
                return pe.getValue();
            }
            if (firstActive == null) {
                firstActive = pe.getValue();
            }
        }
        return firstActive != null ? firstActive : 'Open - Not Contacted';
    }

    private static List<String> getActivePicklistValues(Schema.DescribeFieldResult fieldResult) {
        List<String> values = new List<String>();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (entry.isActive()) {
                values.add(entry.getValue());
            }
        }
        return values;
    }

    private static Id resolveDealerAccountId(Id partnerAccountId) {
        if (partnerAccountId != null) {
            return partnerAccountId;
        }
        List<User> users = [
            SELECT AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (!users.isEmpty() && users[0].AccountId != null) {
            return users[0].AccountId;
        }
        return null;
    }

    private static Id getChannelPartnerLeadRecordTypeId() {
        List<RecordType> rts = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Lead'
              AND DeveloperName = 'Channel_Partner'
              AND IsActive = true
            LIMIT 1
        ];
        if (rts.isEmpty()) {
            throw new AuraHandledException('Channel Partner lead record type is not available.');
        }
        return rts[0].Id;
    }

    private static String blankToNull(String value) {
        return String.isBlank(value) ? null : value.trim();
    }
}