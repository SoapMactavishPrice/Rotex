public without sharing class DealerLeadController {

    /* =========================================================
       EXISTING METHODS (unchanged)
    ========================================================= */

    @AuraEnabled(cacheable=true)
    public static List<Lead> getMyAssignedLeads() {
        try {
            Id currentUserId = UserInfo.getUserId();
            List<Lead> result = [
                SELECT Id, Name, Email, Phone, Status, Dealer_Status__c, Company
                FROM Lead
                WHERE OwnerId = :currentUserId
                ORDER BY CreatedDate DESC
            ];
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching leads: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Lead> getLeadsByDealerAccount() {
        try {
            Id currentUserId = UserInfo.getUserId();

            List<User> users = [
                SELECT AccountId
                FROM User
                WHERE Id = :currentUserId
                LIMIT 1
            ];

            if (users.isEmpty() || users[0].AccountId == null) {
                return new List<Lead>();
            }

            Id dealerAccountId = users[0].AccountId;

            List<Lead> leads = [
                SELECT
                    Id, Name, Salutation, FirstName, MiddleName, LastName, Title,
                    Company, Email, Phone, Website, Status, Dealer_Status__c, Rating,
                    LeadSource, Industry, AnnualRevenue, NumberOfEmployees,
                    CreatedDate, CreatedById, Description,
                    Street, City, State, PostalCode, Country,
                    Customer_Type__c,
                    OwnerId, Owner.Name,
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
                WHERE Dealer__c = :dealerAccountId
                AND IsConverted = false
                AND RecordType.DeveloperName = 'Channel_Partner'
                ORDER BY CreatedDate DESC
            ];

            return (List<Lead>) DealerVisibilityService.filterByVisibility(leads);

        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }

    /* =========================================================
       LEAD CONVERSION (full replica of the standard Convert
       Lead screen: Account create/choose, Contact create/choose,
       Opportunity create/skip). This is what the custom modal
       in the dealer portal calls.
    ========================================================= */

    @AuraEnabled
    public static Id convertLeadFull(
        Id leadId,
        String accountOption,          // 'new' | 'existing'
        Id existingAccountId,
        String newAccountName,
        String contactOption,          // 'new' | 'existing'
        Id existingContactId,
        String contactSalutation,      // only used when contactOption == 'new'
        String contactFirstName,
        String contactMiddleName,      // remove if your org doesn't have Middle Names enabled
        String contactLastName,
        String contactDesignation,
        String opportunityOption,      // 'create' | 'existing' | 'skip'
        Id existingOpportunityId,
        String opportunityName,
        Date opportunityCloseDate
    ) {
        try {
            Lead ld = [
                SELECT Id, FirstName, LastName, Company, Email, Phone, Title,
                       Street, City, State, PostalCode, Country, Status, GST_Number__c
                FROM Lead
                WHERE Id = :leadId
                LIMIT 1
            ];

            String designationValue = String.isNotBlank(contactDesignation)
                ? contactDesignation.trim()
                : ld.Title;

            if (contactOption != 'existing') {
                if (String.isBlank(contactLastName)) {
                    throw new AuraHandledException('Last Name is required for the new contact.');
                }

                update new Lead(
                    Id          = leadId,
                    Salutation  = contactSalutation,
                    FirstName   = contactFirstName,
                    MiddleName  = contactMiddleName,
                    LastName    = contactLastName
                );
            }

            Id accountIdToUse;

            // 1) ACCOUNT: reuse an existing Account, or create a new one the
            //    same way the original flow did (placeholder SAP code, Customer RT).
            if (accountOption == 'existing') {
                if (existingAccountId == null) {
                    throw new AuraHandledException('Please select an existing account.');
                }
                accountIdToUse = existingAccountId;
            } else {
                Id customerRecordTypeId = [
                    SELECT Id FROM RecordType
                    WHERE SObjectType = 'Account' AND DeveloperName = 'Customer'
                    LIMIT 1
                ].Id;

                Account newAcc = new Account(
                    Name                  = String.isNotBlank(newAccountName) ? newAccountName : ld.Company,
                    RecordTypeId          = customerRecordTypeId,
                    SAP_Customer_Code__c  = generatePlaceholderSapCode()
                );
                insert newAcc;
                accountIdToUse = newAcc.Id;
            }

            LeadStatus convertStatus = [
                SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1
            ];

            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(leadId);
            lc.setAccountId(accountIdToUse);
            lc.setConvertedStatus(convertStatus.MasterLabel);

            // 2) CONTACT: attach an existing Contact, or let standard conversion
            //    create a new one from the Lead's name/details (default behaviour
            //    when ContactId is left unset).
            if (contactOption == 'existing') {
                if (existingContactId == null) {
                    throw new AuraHandledException('Please select an existing contact.');
                }
                lc.setContactId(existingContactId);
            }

            // 3) OPPORTUNITY: create new, attach to an existing one, or skip.
            if (opportunityOption == 'existing') {
                if (existingOpportunityId == null) {
                    throw new AuraHandledException('Please select an existing opportunity.');
                }
                lc.setOpportunityId(existingOpportunityId);
            } else {
                Boolean makeOpp = (opportunityOption == 'create');
                lc.setDoNotCreateOpportunity(!makeOpp);
                if (makeOpp && String.isNotBlank(opportunityName)) {
                    lc.setOpportunityName(opportunityName);
                }
            }

            Database.LeadConvertResult lcr;
            try {
                lcr = Database.convertLead(lc);
            } catch (Exception convEx) {
                throw new AuraHandledException('Lead conversion failed: ' + convEx.getMessage());
            }

            if (!lcr.isSuccess()) {
                throw new AuraHandledException('Lead conversion failed.');
            }

            Id accountId = lcr.getAccountId();
            Id opportunityId = lcr.getOpportunityId();
            Id contactId = lcr.getContactId();

            Date closeDate = opportunityCloseDate != null
                ? opportunityCloseDate
                : Date.today().addDays(30);
            Id pricebookId = resolvePricebookIdForAccount(accountId);

            // Set Close Date + Price Book on newly created Opportunity
            if (opportunityOption == 'create' && opportunityId != null) {
                Opportunity oppUpdate = new Opportunity(Id = opportunityId, CloseDate = closeDate);
                if (pricebookId != null) {
                    oppUpdate.Pricebook2Id = pricebookId;
                }
                update oppUpdate;

                // Match CRM convert behaviour: also create a Quote on the Opportunity
                createQuoteForConvertedOpportunity(
                    opportunityId,
                    accountId,
                    contactId,
                    ld,
                    closeDate,
                    opportunityName,
                    pricebookId
                );
            }

            // Only stamp the Channel Partner / address fields when WE created
            // the account just now - don't overwrite data on an existing Account.
            if (accountOption != 'existing') {
                User currentUser = [
                    SELECT AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1
                ];

                update new Account(
                Id                          = accountId,
                Channel_Partner_Name__c     = currentUser.AccountId,
            
                Street__c                   = ld.Street,
                District__c                 = ld.City,
                State__c                    = ld.State,
                Postal_Code__c              = ld.PostalCode,
                GST_No__c                   = ld.GST_Number__c,

                Contact_Person_Name__c      = ld.FirstName,
                Contact_Person_Last_Name__c = ld.LastName,
                Contact_Person_Telephone_No__c = ld.Phone,
                Contact_Person_Email_ID__c  = ld.Email,
                Contact_Person_Designation__c = designationValue
);

            }

            // Stamp designation on the Contact created/used by conversion
            if (contactId != null && contactOption != 'existing' && String.isNotBlank(designationValue)) {
                update new Contact(
                    Id = contactId,
                    Contact_Person_Designation__c = designationValue
                );
            }

            return accountId;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error converting lead: ' + e.getMessage());
        }
    }

    private static void createQuoteForConvertedOpportunity(
        Id opportunityId,
        Id accountId,
        Id contactId,
        Lead ld,
        Date closeDate,
        String opportunityName,
        Id pricebookId
    ) {
        if (opportunityId == null || accountId == null) {
            return;
        }

        String quoteName = String.isNotBlank(opportunityName)
            ? opportunityName.trim()
            : (String.isNotBlank(ld.Company) ? ld.Company.trim() : 'Quote');

        Quote q = new Quote();
        q.Name = quoteName;
        q.OpportunityId = opportunityId;
        q.QuoteAccountId = accountId;
        q.Account__c = accountId;
        q.ContactId = contactId;
        q.Status = 'Draft';
        q.OwnerId = UserInfo.getUserId();
        q.Quote_Type__c = 'Secondary Customer';
        q.Quote_Date__c = Date.today();
        q.Quote_Valid_Till__c = closeDate != null ? closeDate : Date.today().addDays(30);
        if (pricebookId != null) {
            q.Pricebook2Id = pricebookId;
        }
        insert q;
    }

    private static Id resolvePricebookIdForAccount(Id accountId) {
        if (accountId == null) {
            return null;
        }

        Account acc = [
            SELECT Id, Pricelist__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        if (acc.Pricelist__c != null) {
            return acc.Pricelist__c;
        }

        List<Sales_Area_Item__c> salesAreas = [
            SELECT Distribution_Channel__c
            FROM Sales_Area_Item__c
            WHERE Account__c = :accountId
            AND Sales_Org__c = '1100'
            LIMIT 1
        ];
        if (!salesAreas.isEmpty() && String.isNotBlank(salesAreas[0].Distribution_Channel__c)) {
            List<Pricebook2> pbs = [
                SELECT Id
                FROM Pricebook2
                WHERE IsActive = true
                  AND Distribution_Channel__c = :salesAreas[0].Distribution_Channel__c
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!pbs.isEmpty()) {
                return pbs[0].Id;
            }
        }

        List<Pricebook2> anyActive = [
            SELECT Id
            FROM Pricebook2
            WHERE IsActive = true
            ORDER BY IsStandard DESC, CreatedDate DESC
            LIMIT 1
        ];
        return anyActive.isEmpty() ? null : anyActive[0].Id;
    }

    // Generates a placeholder SAP code prefixed with "10" (adjust to your real numbering rules)
    private static String generatePlaceholderSapCode() {
        return '10' + String.valueOf(Datetime.now().getTime());
    }

    /* =========================================================
       SEARCH HELPERS for the custom Convert Lead modal
       ("Choose Existing Account" / "Choose Existing Contact")
    ========================================================= */

    @AuraEnabled(cacheable=true)
    public static List<Account> searchAccounts(String searchTerm) {
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
            return new List<Account>();
        }
        String term = '%' + searchTerm + '%';
        return [
            SELECT Id, Name, AccountNumber
            FROM Account
            WHERE Name LIKE :term
            ORDER BY Name
            LIMIT 10
        ];
    }

    // "searchTerm" narrows by name; "accountId" (optional) scopes the search
    // to Contacts that already belong to a specific Account - used once the
    // dealer has picked an existing Account, mirroring how the standard
    // Convert Lead screen surfaces contacts related to the chosen account.
    @AuraEnabled(cacheable=true)
    public static List<Contact> searchContacts(String searchTerm, Id accountId) {
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
            return new List<Contact>();
        }
        String term = '%' + searchTerm + '%';

        if (accountId != null) {
            return [
                SELECT Id, Name, Account.Name
                FROM Contact
                WHERE Name LIKE :term
                AND AccountId = :accountId
                ORDER BY Name
                LIMIT 10
            ];
        }

        return [
            SELECT Id, Name, Account.Name
            FROM Contact
            WHERE Name LIKE :term
            ORDER BY Name
            LIMIT 10
        ];
    }

    // Contacts already linked to a chosen Account, shown automatically the
    // moment the dealer selects that Account (no typing required) - same
    // "related to that account" experience as the standard Convert screen.
    @AuraEnabled(cacheable=true)
    public static List<Contact> getContactsForAccount(Id accountId) {
        if (accountId == null) {
            return new List<Contact>();
        }
        return [
            SELECT Id, Name, Account.Name
            FROM Contact
            WHERE AccountId = :accountId
            ORDER BY Name
            LIMIT 10
        ];
    }

    // Opportunities already linked to a chosen Account, shown automatically
    // the moment the dealer selects that Account.
    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getOpportunitiesForAccount(Id accountId) {
        if (accountId == null) {
            return new List<Opportunity>();
        }
        return [
            SELECT Id, Name, StageName
            FROM Opportunity
            WHERE AccountId = :accountId
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
    }

    // Existing Opportunities are only searched within the Account already
    // chosen for this conversion, matching the standard Convert Lead screen's
    // "To find opportunity, choose an existing account" behaviour.
    @AuraEnabled(cacheable=true)
    public static List<Opportunity> searchOpportunities(String searchTerm, Id accountId) {
        if (accountId == null || String.isBlank(searchTerm) || searchTerm.length() < 2) {
            return new List<Opportunity>();
        }
        String term = '%' + searchTerm + '%';
        return [
            SELECT Id, Name, StageName
            FROM Opportunity
            WHERE AccountId = :accountId
              AND Name LIKE :term
            ORDER BY Name
            LIMIT 10
        ];
    }

    /* =========================================================
       LOOKUPS for New Event modal (Assigned To / Name / Related To)
    ========================================================= */

    public class LookupOption {
        @AuraEnabled public String id;
        @AuraEnabled public String label;
        @AuraEnabled public String subtitle;
        @AuraEnabled public String objectType;
        @AuraEnabled public String iconName;

        public LookupOption(String id, String label, String subtitle, String objectType, String iconName) {
            this.id = id;
            this.label = label;
            this.subtitle = subtitle;
            this.objectType = objectType;
            this.iconName = iconName;
        }
    }

    @AuraEnabled
    public static List<LookupOption> searchPeople(String searchTerm) {
        List<LookupOption> results = new List<LookupOption>();
        String term = searchTerm == null ? '' : searchTerm.trim();
        String likeKey = '%' + term + '%';

        List<User> users;
        if (String.isBlank(term)) {
            users = [
                SELECT Id, Name, FirstName, LastName, Email, Username, UserType
                FROM User
                WHERE IsActive = true
                AND UserType IN (
                    'Standard',
                    'PowerPartner',
                    'PowerCustomerSuccess',
                    'CspLitePortal'
                )
                ORDER BY FirstName NULLS LAST, LastName NULLS LAST, Name
                LIMIT 20
            ];
        } else {
            users = [
                SELECT Id, Name, FirstName, LastName, Email, Username, UserType
                FROM User
                WHERE IsActive = true
                AND UserType IN (
                    'Standard',
                    'PowerPartner',
                    'PowerCustomerSuccess',
                    'CspLitePortal'
                )
                AND (
                    Name LIKE :likeKey
                    OR FirstName LIKE :likeKey
                    OR LastName LIKE :likeKey
                    OR Email LIKE :likeKey
                )
                ORDER BY FirstName NULLS LAST, LastName NULLS LAST, Name
                LIMIT 20
            ];
        }

        for (User u : users) {
            String displayName = formatUserDisplayName(u);
            // Skip technical / auto-generated user labels
            if (String.isBlank(displayName) || isTechnicalUserLabel(displayName)) {
                continue;
            }
            results.add(new LookupOption(
                String.valueOf(u.Id),
                displayName,
                u.Email,
                'User',
                'standard:user'
            ));
            if (results.size() >= 10) {
                break;
            }
        }
        return results;
    }

    private static String formatUserDisplayName(User u) {
        String firstLast = (
            (u.FirstName == null ? '' : u.FirstName) +
            ' ' +
            (u.LastName == null ? '' : u.LastName)
        ).trim();
        if (String.isNotBlank(firstLast)) {
            return firstLast;
        }
        if (String.isNotBlank(u.Name) && !isTechnicalUserLabel(u.Name)) {
            return u.Name;
        }
        if (String.isNotBlank(u.Email)) {
            return u.Email;
        }
        return u.Username;
    }

    private static Boolean isTechnicalUserLabel(String label) {
        if (String.isBlank(label)) {
            return true;
        }
        // Matches values like User173609808993493945
        return Pattern.matches('(?i)^User\\d{8,}$', label.trim());
    }

    @AuraEnabled
    public static List<LookupOption> searchNameRecords(String searchTerm) {
        List<LookupOption> results = new List<LookupOption>();
        String term = searchTerm == null ? '' : searchTerm.trim();

        if (String.isBlank(term)) {
            for (Contact c : [
                SELECT Id, Name, Account.Name
                FROM Contact
                ORDER BY LastModifiedDate DESC
                LIMIT 10
            ]) {
                results.add(new LookupOption(
                    String.valueOf(c.Id),
                    c.Name,
                    c.Account != null ? c.Account.Name : '',
                    'Contact',
                    'standard:contact'
                ));
            }
            return results;
        }

        String likeKey = '%' + term + '%';
        for (Contact c : [
            SELECT Id, Name, Account.Name
            FROM Contact
            WHERE Name LIKE :likeKey
            ORDER BY Name
            LIMIT 10
        ]) {
            results.add(new LookupOption(
                String.valueOf(c.Id),
                c.Name,
                c.Account != null ? c.Account.Name : '',
                'Contact',
                'standard:contact'
            ));
        }

        for (Lead l : [
            SELECT Id, Name, Company
            FROM Lead
            WHERE IsConverted = false
            AND Name LIKE :likeKey
            ORDER BY Name
            LIMIT 5
        ]) {
            results.add(new LookupOption(
                String.valueOf(l.Id),
                l.Name,
                String.isBlank(l.Company) ? 'Lead' : l.Company,
                'Lead',
                'standard:lead'
            ));
        }
        return results;
    }

    @AuraEnabled
    public static List<LookupOption> searchRelatedRecords(String searchTerm) {
        List<LookupOption> results = new List<LookupOption>();
        String term = searchTerm == null ? '' : searchTerm.trim();

        if (String.isBlank(term)) {
            for (Account a : [
                SELECT Id, Name, AccountNumber, BillingCity, BillingState
                FROM Account
                ORDER BY LastModifiedDate DESC
                LIMIT 10
            ]) {
                results.add(new LookupOption(
                    String.valueOf(a.Id),
                    a.Name,
                    formatAccountLookupSubtitle(a),
                    'Account',
                    'standard:account'
                ));
            }
            return results;
        }

        String likeKey = '%' + term + '%';
        for (Account a : [
            SELECT Id, Name, AccountNumber, BillingCity, BillingState
            FROM Account
            WHERE Name LIKE :likeKey
            OR AccountNumber LIKE :likeKey
            ORDER BY Name
            LIMIT 10
        ]) {
            results.add(new LookupOption(
                String.valueOf(a.Id),
                a.Name,
                formatAccountLookupSubtitle(a),
                'Account',
                'standard:account'
            ));
        }
        return results;
    }

    private static String formatAccountLookupSubtitle(Account a) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(a.AccountNumber)) {
            parts.add(a.AccountNumber);
        }
        List<String> loc = new List<String>();
        if (String.isNotBlank(a.BillingCity)) {
            loc.add(a.BillingCity);
        }
        if (String.isNotBlank(a.BillingState)) {
            loc.add(a.BillingState);
        }
        if (!loc.isEmpty()) {
            parts.add('(' + String.join(loc, '-') + ')');
        }
        return parts.isEmpty() ? '' : String.join(parts, ' ');
    }

   public class VisitEventInput {
        @AuraEnabled public String subject { get; set; }
        @AuraEnabled public Id ownerId { get; set; }
        @AuraEnabled public Datetime startDateTime { get; set; }
        @AuraEnabled public Datetime endDateTime { get; set; }
        @AuraEnabled public String location { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String visitStatus { get; set; }
        @AuraEnabled public String managerReviewStatus { get; set; }
        @AuraEnabled public String visitType { get; set; }
        @AuraEnabled public Id whatId { get; set; }
        @AuraEnabled public Id whoId { get; set; }
        @AuraEnabled public Boolean reminder { get; set; }
        @AuraEnabled public Integer reminderMinutes { get; set; }
        @AuraEnabled public String mom { get; set; }
        @AuraEnabled public String nextActionPoints { get; set; }
        @AuraEnabled public String nextActionApplicable { get; set; }
        @AuraEnabled public Date nextActionDate { get; set; }
    }

 @AuraEnabled
public static ActivityWrapper createVisitEvent(VisitEventInput wrapper) {
    if (wrapper == null) {
        throw new AuraHandledException('Event details are required.');
    }
        if (String.isBlank(wrapper.subject)) {
            throw new AuraHandledException('Subject is required.');
        }
        if (String.isBlank(wrapper.description)) {
            throw new AuraHandledException('Visit Description is required.');
        }
        if (wrapper.startDateTime == null || wrapper.endDateTime == null) {
            throw new AuraHandledException('Start and End are required.');
        }
        if (wrapper.endDateTime <= wrapper.startDateTime) {
            throw new AuraHandledException('End must be after Start.');
        }

        Boolean isLeadWho = false;
        if (wrapper.whoId != null) {
            String whoPrefix = String.valueOf(wrapper.whoId).substring(0, 3);
            isLeadWho = whoPrefix == Lead.SObjectType.getDescribe().getKeyPrefix();
        }
        if (isLeadWho && wrapper.whatId != null) {
            throw new AuraHandledException(
                'Related To cannot be set when Name is a Lead. Clear Related To or choose a Contact.'
            );
        }

        if (wrapper.visitStatus == 'Completed') {
            // Completed is only allowed when editing an existing Event from the portal.
            wrapper.visitStatus = 'Scheduled';
        }
        Event ev = new Event();
        ev.Subject = wrapper.subject;
        ev.OwnerId = resolveEventOwnerId(wrapper.ownerId);
        ev.StartDateTime = wrapper.startDateTime;
        ev.EndDateTime = wrapper.endDateTime;
        ev.Location = wrapper.location;
        ev.Visit_Status__c = wrapper.visitStatus;
        if (canEditManagerReviewStatus()) {
            ev.Manager_Review_Status__c = blankToNull(wrapper.managerReviewStatus);
        }
        ev.Visit_Type__c = wrapper.visitType;
        ev.WhatId = wrapper.whatId;
        ev.WhoId = wrapper.whoId;
        ev.IsReminderSet = wrapper.reminder == true;
        ev.Description = wrapper.description;

       if (ev.IsReminderSet) {
            Integer mins = wrapper.reminderMinutes == null ? 15 : wrapper.reminderMinutes;
            ev.ReminderDateTime = wrapper.startDateTime.addMinutes(-mins);
        }

        if (wrapper.visitStatus == 'Completed') {
            ev.MOM__c = wrapper.mom;
            ev.Next_Action_Applicable__c = wrapper.nextActionApplicable;
            // Points + Date only when Applicable = Yes. When No, store N/A for points
            // so existing org validation on Completed can pass without the UI requiring them.
            if (wrapper.nextActionApplicable == 'Yes') {
                ev.Next_Action_Points__c = wrapper.nextActionPoints;
                ev.Next_Action_Date__c = wrapper.nextActionDate;
            } else if (wrapper.nextActionApplicable == 'No') {
                ev.Next_Action_Points__c = 'N/A';
                ev.Next_Action_Date__c = null;
            } else {
                ev.Next_Action_Points__c = wrapper.nextActionPoints;
                ev.Next_Action_Date__c = wrapper.nextActionDate;
            }
        }

        try {
            insert ev;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }

        ActivityWrapper w = new ActivityWrapper();
        w.id = ev.Id;
        w.subject = ev.Subject;
        w.type = 'Event';
        w.dueDate = ev.StartDateTime.format('dd MMM yyyy, hh:mm a');
        w.isOverdue = false;
        w.isClosed = false;
        return w;
    }

    private static Id resolveEventOwnerId(Id ownerOrContactId) {
        if (ownerOrContactId == null) {
            return UserInfo.getUserId();
        }
        String prefix = String.valueOf(ownerOrContactId).substring(0, 3);
        String userPrefix = User.SObjectType.getDescribe().getKeyPrefix();
        String contactPrefix = Contact.SObjectType.getDescribe().getKeyPrefix();

        if (prefix == userPrefix) {
            return ownerOrContactId;
        }
        if (prefix == contactPrefix) {
            List<User> linkedUsers = [
                SELECT Id
                FROM User
                WHERE ContactId = :ownerOrContactId
                AND IsActive = true
                LIMIT 1
            ];
            if (!linkedUsers.isEmpty()) {
                return linkedUsers[0].Id;
            }
            return UserInfo.getUserId();
        }
        return UserInfo.getUserId();
    }

    /* =========================================================
       ACTIVITY: Tasks & Events (Upcoming/Overdue + Past)
    ========================================================= */

    public class ActivityWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String subject;
        @AuraEnabled public String type;       // 'Task' | 'Call' | 'Event'
        @AuraEnabled public String dueDate;    // formatted for display
        @AuraEnabled public Boolean isOverdue;
        @AuraEnabled public Boolean isClosed;
    }

    // Open/future Tasks + future Events owned by the logged-in user (Assigned To You).
    // When leadId is set, further scoped to that Lead (WhoId).
    @AuraEnabled
    public static List<ActivityWrapper> getUpcomingActivities(Id leadId) {
        List<ActivityWrapper> results = new List<ActivityWrapper>();
        Id currentUserId = UserInfo.getUserId();

        List<Task> tasks;
        List<Event> events;
        if (leadId != null) {
            tasks = [
                SELECT Id, Subject, ActivityDate, IsClosed
                FROM Task
                WHERE OwnerId = :currentUserId
                  AND WhoId = :leadId
                  AND IsClosed = false
                ORDER BY ActivityDate ASC NULLS LAST
                LIMIT 50
            ];
            events = [
                SELECT Id, Subject, StartDateTime
                FROM Event
                WHERE OwnerId = :currentUserId
                  AND WhoId = :leadId
                  AND StartDateTime >= :Datetime.now()
                ORDER BY StartDateTime ASC
                LIMIT 50
            ];
        } else {
            tasks = [
                SELECT Id, Subject, ActivityDate, IsClosed
                FROM Task
                WHERE OwnerId = :currentUserId
                  AND IsClosed = false
                ORDER BY ActivityDate ASC NULLS LAST
                LIMIT 50
            ];
            events = [
                SELECT Id, Subject, StartDateTime
                FROM Event
                WHERE OwnerId = :currentUserId
                  AND StartDateTime >= :Datetime.now()
                ORDER BY StartDateTime ASC
                LIMIT 50
            ];
        }

        for (Task t : tasks) {
            ActivityWrapper w = new ActivityWrapper();
            w.id = t.Id;
            w.subject = t.Subject;
            w.type = 'Task';
            w.dueDate = t.ActivityDate != null
                ? t.ActivityDate.format()
                : 'No due date';
            w.isOverdue = t.ActivityDate != null && t.ActivityDate < Date.today();
            w.isClosed = false;
            results.add(w);
        }

        for (Event ev : events) {
            ActivityWrapper w = new ActivityWrapper();
            w.id = ev.Id;
            w.subject = ev.Subject;
            w.type = 'Event';
            w.dueDate = ev.StartDateTime != null
                ? ev.StartDateTime.format('dd MMM yyyy, hh:mm a')
                : '';
            w.isOverdue = false;
            w.isClosed = false;
            results.add(w);
        }

        return results;
    }

    // Closed Tasks + past Events owned by the logged-in user (Assigned To You).
    @AuraEnabled
    public static List<ActivityWrapper> getPastActivities(Id leadId) {
        List<ActivityWrapper> results = new List<ActivityWrapper>();
        Id currentUserId = UserInfo.getUserId();

        List<Task> tasks;
        List<Event> events;
        if (leadId != null) {
            tasks = [
                SELECT Id, Subject, ActivityDate, IsClosed
                FROM Task
                WHERE OwnerId = :currentUserId
                  AND WhoId = :leadId
                  AND IsClosed = true
                ORDER BY ActivityDate DESC NULLS LAST
                LIMIT 50
            ];
            events = [
                SELECT Id, Subject, StartDateTime
                FROM Event
                WHERE OwnerId = :currentUserId
                  AND WhoId = :leadId
                  AND StartDateTime < :Datetime.now()
                ORDER BY StartDateTime DESC
                LIMIT 50
            ];
        } else {
            tasks = [
                SELECT Id, Subject, ActivityDate, IsClosed
                FROM Task
                WHERE OwnerId = :currentUserId
                  AND IsClosed = true
                ORDER BY ActivityDate DESC NULLS LAST
                LIMIT 50
            ];
            events = [
                SELECT Id, Subject, StartDateTime
                FROM Event
                WHERE OwnerId = :currentUserId
                  AND StartDateTime < :Datetime.now()
                ORDER BY StartDateTime DESC
                LIMIT 50
            ];
        }

        for (Task t : tasks) {
            ActivityWrapper w = new ActivityWrapper();
            w.id = t.Id;
            w.subject = t.Subject;
            w.type = 'Task';
            w.dueDate = t.ActivityDate != null ? t.ActivityDate.format() : '';
            w.isOverdue = false;
            w.isClosed = true;
            results.add(w);
        }

        for (Event ev : events) {
            ActivityWrapper w = new ActivityWrapper();
            w.id = ev.Id;
            w.subject = ev.Subject;
            w.type = 'Event';
            w.dueDate = ev.StartDateTime != null
                ? ev.StartDateTime.format('dd MMM yyyy, hh:mm a')
                : '';
            w.isOverdue = false;
            w.isClosed = true;
            results.add(w);
        }

        return results;
    }

    public class ActivityDetailWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String objectType { get; set; } // Task | Event
        @AuraEnabled public String subject { get; set; }
        @AuraEnabled public Id ownerId { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public Id whoId { get; set; }
        @AuraEnabled public String whoName { get; set; }
        @AuraEnabled public Id whatId { get; set; }
        @AuraEnabled public String whatName { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Boolean reminderSet { get; set; }
        @AuraEnabled public Integer reminderMinutes { get; set; }
        @AuraEnabled public String reminderDateTime { get; set; }
        @AuraEnabled public String reminderDateTimeIso { get; set; }
        @AuraEnabled public String createdDate { get; set; }
        // Task
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String priority { get; set; }
        @AuraEnabled public String dueDate { get; set; }
        @AuraEnabled public String dueDateIso { get; set; }
        // Event
        @AuraEnabled public String startDateTime { get; set; }
        @AuraEnabled public String endDateTime { get; set; }
        @AuraEnabled public String startDateTimeIso { get; set; }
        @AuraEnabled public String endDateTimeIso { get; set; }
        @AuraEnabled public String location { get; set; }
        @AuraEnabled public String visitStatus { get; set; }
        @AuraEnabled public String managerReviewStatus { get; set; }
        @AuraEnabled public Boolean canEditManagerReviewStatus { get; set; }
        @AuraEnabled public String visitType { get; set; }
        @AuraEnabled public String mom { get; set; }
        @AuraEnabled public String nextActionPoints { get; set; }
        @AuraEnabled public String nextActionApplicable { get; set; }
        @AuraEnabled public String nextActionDate { get; set; }
        @AuraEnabled public String nextActionDateIso { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static Boolean canEditManagerReviewStatus() {
        return DealerVisibilityService.resolve().portalRole == 'Manager';
    }

    @AuraEnabled
    public static ActivityDetailWrapper getActivityDetail(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('Record Id is required.');
        }

        DealerVisibilityService.Scope visibility = DealerVisibilityService.resolve();
        Set<Id> visibleUserIds = visibility.visibleUserIds;
        Set<Id> allPartnerUserIds = visibility.allPartnerUserIds;
        String prefix = String.valueOf(recordId).substring(0, 3);
        String taskPrefix = Task.SObjectType.getDescribe().getKeyPrefix();
        String eventPrefix = Event.SObjectType.getDescribe().getKeyPrefix();

        ActivityDetailWrapper d = new ActivityDetailWrapper();
        d.id = recordId;

        if (prefix == taskPrefix) {
            List<Task> tasks = [
                SELECT Id, Subject, Status, Priority, ActivityDate, Description,
                       IsReminderSet, ReminderDateTime, CreatedDate,
                       OwnerId, Owner.Name, WhoId, Who.Name, WhatId, What.Name
                FROM Task
                WHERE Id = :recordId
                  AND (OwnerId IN :visibleUserIds OR OwnerId NOT IN :allPartnerUserIds)
                LIMIT 1
            ];
            if (tasks.isEmpty()) {
                throw new AuraHandledException('Task not found or you do not have access.');
            }
            Task t = tasks[0];
            d.objectType = 'Task';
            d.subject = t.Subject;
            d.status = t.Status;
            d.priority = t.Priority;
            d.dueDate = t.ActivityDate != null ? t.ActivityDate.format() : '';
            d.dueDateIso = t.ActivityDate != null ? String.valueOf(t.ActivityDate) : '';
            d.description = t.Description;
            d.reminderSet = t.IsReminderSet == true;
            d.reminderDateTime = t.ReminderDateTime != null
                ? t.ReminderDateTime.format('dd MMM yyyy, hh:mm a')
                : '';
            d.reminderDateTimeIso = toDateTimeLocal(t.ReminderDateTime);
            d.createdDate = t.CreatedDate != null
                ? t.CreatedDate.format('dd MMM yyyy')
                : '';
            d.ownerId = t.OwnerId;
            d.ownerName = t.Owner != null ? t.Owner.Name : '';
            d.whoId = t.WhoId;
            d.whoName = t.Who != null ? t.Who.Name : '';
            d.whatId = t.WhatId;
            d.whatName = t.What != null ? t.What.Name : '';
            return d;
        }

        if (prefix == eventPrefix) {
            List<Event> events = [
                SELECT Id, Subject, StartDateTime, EndDateTime, Location, Description,
                       IsReminderSet, ReminderDateTime, CreatedDate,
                       Visit_Status__c, Manager_Review_Status__c, Visit_Type__c, MOM__c,
                       Next_Action_Points__c, Next_Action_Applicable__c, Next_Action_Date__c,
                       OwnerId, Owner.Name, WhoId, Who.Name, WhatId, What.Name
                FROM Event
                WHERE Id = :recordId
                  AND (OwnerId IN :visibleUserIds OR OwnerId NOT IN :allPartnerUserIds)
                LIMIT 1
            ];
            if (events.isEmpty()) {
                throw new AuraHandledException('Event not found or you do not have access.');
            }
            Event ev = events[0];
            d.objectType = 'Event';
            d.subject = ev.Subject;
            d.startDateTime = ev.StartDateTime != null
                ? ev.StartDateTime.format('dd MMM yyyy, hh:mm a')
                : '';
            d.endDateTime = ev.EndDateTime != null
                ? ev.EndDateTime.format('dd MMM yyyy, hh:mm a')
                : '';
            d.startDateTimeIso = toDateTimeLocal(ev.StartDateTime);
            d.endDateTimeIso = toDateTimeLocal(ev.EndDateTime);
            d.location = ev.Location;
            d.description = ev.Description;
            d.reminderSet = ev.IsReminderSet == true;
            d.reminderDateTime = ev.ReminderDateTime != null
                ? ev.ReminderDateTime.format('dd MMM yyyy, hh:mm a')
                : '';
            if (
                ev.IsReminderSet == true &&
                ev.ReminderDateTime != null &&
                ev.StartDateTime != null
            ) {
                Long ms = ev.StartDateTime.getTime() - ev.ReminderDateTime.getTime();
                d.reminderMinutes = Integer.valueOf(ms / 60000);
            } else {
                d.reminderMinutes = 15;
            }
            d.createdDate = ev.CreatedDate != null
                ? ev.CreatedDate.format('dd MMM yyyy')
                : '';
            d.visitStatus = ev.Visit_Status__c;
            d.managerReviewStatus = ev.Manager_Review_Status__c;
            d.canEditManagerReviewStatus = visibility.portalRole == 'Manager';
            d.visitType = ev.Visit_Type__c;
            d.mom = ev.MOM__c;
            d.nextActionApplicable = ev.Next_Action_Applicable__c;
            // Hide placeholder used only to satisfy org VR when Applicable = No
            if (ev.Next_Action_Applicable__c == 'No' && ev.Next_Action_Points__c == 'N/A') {
                d.nextActionPoints = '';
            } else {
                d.nextActionPoints = ev.Next_Action_Points__c;
            }
            d.nextActionDate = ev.Next_Action_Date__c != null
                ? ev.Next_Action_Date__c.format()
                : '';
            d.nextActionDateIso = ev.Next_Action_Date__c != null
                ? String.valueOf(ev.Next_Action_Date__c)
                : '';
            d.ownerId = ev.OwnerId;
            d.ownerName = ev.Owner != null ? ev.Owner.Name : '';
            d.whoId = ev.WhoId;
            d.whoName = ev.Who != null ? ev.Who.Name : '';
            d.whatId = ev.WhatId;
            d.whatName = ev.What != null ? ev.What.Name : '';
            return d;
        }

        throw new AuraHandledException('Unsupported activity type.');
    }

    /**
     * Portal Task/Event edit. Fields that already had a value stay locked,
     * except Event Visit Status which is always editable.
     * recordId is a top-level param — nested wrapper "id" often fails Aura deserialization.
     */
    @AuraEnabled
    public static ActivityDetailWrapper saveActivityDetail(Id recordId, ActivityDetailWrapper input) {
        if (recordId == null && input != null && input.id != null) {
            recordId = input.id;
        }
        if (recordId == null) {
            throw new AuraHandledException('Record Id is required.');
        }
        if (input == null) {
            input = new ActivityDetailWrapper();
        }
        input.id = recordId;

        Id currentUserId = UserInfo.getUserId();
        String prefix = String.valueOf(recordId).substring(0, 3);
        String taskPrefix = Task.SObjectType.getDescribe().getKeyPrefix();
        String eventPrefix = Event.SObjectType.getDescribe().getKeyPrefix();

            if (prefix == taskPrefix) {
            List<Task> tasks = [
                SELECT Id, Subject, Status, Priority, ActivityDate, Description, OwnerId,
                       WhoId, WhatId, IsReminderSet, ReminderDateTime
                FROM Task
                WHERE Id = :recordId AND OwnerId = :currentUserId
                LIMIT 1
            ];
            if (tasks.isEmpty()) {
                throw new AuraHandledException('Task not found or you do not have access.');
            }
            Task t = tasks[0];
            if (input.subject != null) {
                t.Subject = blankToNull(input.subject);
            }
            if (input.status != null) {
                t.Status = blankToNull(input.status);
            }
            if (input.priority != null) {
                t.Priority = blankToNull(input.priority);
            }
            if (String.isNotBlank(input.dueDateIso)) {
                t.ActivityDate = Date.valueOf(input.dueDateIso);
            }
            if (input.description != null) {
                t.Description = blankToNull(input.description);
            }
            if (input.ownerId != null) {
                t.OwnerId = resolveEventOwnerId(input.ownerId);
            }
            if (input.whatId != null) {
                t.WhatId = input.whatId;
            }
            if (input.whoId != null) {
                t.WhoId = input.whoId;
            }
            if (input.reminderSet != null) {
                t.IsReminderSet = input.reminderSet == true;
                if (t.IsReminderSet == true && String.isNotBlank(input.reminderDateTimeIso)) {
                    t.ReminderDateTime = parseDateTimeLocal(input.reminderDateTimeIso);
                } else if (t.IsReminderSet != true) {
                    t.ReminderDateTime = null;
                }
            }
            update t;
            try {
                return getActivityDetail(t.Id);
            } catch (Exception e) {
                ActivityDetailWrapper w = new ActivityDetailWrapper();
                w.id = t.Id;
                w.objectType = 'Task';
                return w;
            }
        }

        if (prefix == eventPrefix) {
            List<Event> events = [
                SELECT Id, Subject, StartDateTime, EndDateTime, Location, Description,
                       Visit_Status__c, Manager_Review_Status__c, Visit_Type__c, MOM__c,
                       Next_Action_Points__c, Next_Action_Applicable__c, Next_Action_Date__c,
                       OwnerId, WhoId, WhatId, IsReminderSet, ReminderDateTime
                FROM Event
                WHERE Id = :recordId AND OwnerId = :currentUserId
                LIMIT 1
            ];
            if (events.isEmpty()) {
                throw new AuraHandledException('Event not found or you do not have access.');
            }
            Event ev = events[0];
            // All event detail fields are editable from the portal
            if (input.visitStatus != null) {
                ev.Visit_Status__c = blankToNull(input.visitStatus);
            }
            if (canEditManagerReviewStatus() && input.managerReviewStatus != null) {
                ev.Manager_Review_Status__c = blankToNull(input.managerReviewStatus);
            }
            if (input.subject != null) {
                ev.Subject = blankToNull(input.subject);
            }
            if (String.isNotBlank(input.startDateTimeIso)) {
                ev.StartDateTime = parseDateTimeLocal(input.startDateTimeIso);
            }
            if (String.isNotBlank(input.endDateTimeIso)) {
                ev.EndDateTime = parseDateTimeLocal(input.endDateTimeIso);
            }
            if (input.location != null) {
                ev.Location = blankToNull(input.location);
            }
            if (input.visitType != null) {
                ev.Visit_Type__c = blankToNull(input.visitType);
            }
            if (input.description != null) {
                ev.Description = blankToNull(input.description);
            }
            if (input.ownerId != null) {
                ev.OwnerId = resolveEventOwnerId(input.ownerId);
            }
            if (input.whatId != null) {
                ev.WhatId = input.whatId;
            }
            if (input.whoId != null) {
                ev.WhoId = input.whoId;
            }
            if (input.reminderSet != null) {
                ev.IsReminderSet = input.reminderSet == true;
                if (ev.IsReminderSet == true && ev.StartDateTime != null) {
                    Integer mins = input.reminderMinutes == null ? 15 : input.reminderMinutes;
                    ev.ReminderDateTime = ev.StartDateTime.addMinutes(-mins);
                } else {
                    ev.ReminderDateTime = null;
                }
            }

            // Completion / status-description fields (same as Create Visit Completed flow).
            // Points + Date are required only when Applicable = Yes (Apex + LWC).
            // When Applicable = No, do not require user input; set Points to N/A so the
            // existing org validation ("Please add Next Action Point.") still passes.
            String statusAfter =
                String.isNotBlank(ev.Visit_Status__c) ? ev.Visit_Status__c : input.visitStatus;
            if (statusAfter == 'Completed') {
                if (input.mom != null) {
                    ev.MOM__c = blankToNull(input.mom);
                }
                if (input.nextActionApplicable != null) {
                    ev.Next_Action_Applicable__c = blankToNull(input.nextActionApplicable);
                }

                String applicableAfter = hasText(ev.Next_Action_Applicable__c)
                    ? ev.Next_Action_Applicable__c.trim()
                    : null;

                if (applicableAfter == 'Yes') {
                    if (input.nextActionPoints != null) {
                        ev.Next_Action_Points__c = blankToNull(input.nextActionPoints);
                    }
                    if (String.isNotBlank(input.nextActionDateIso)) {
                        ev.Next_Action_Date__c = Date.valueOf(input.nextActionDateIso);
                    }
                } else if (applicableAfter == 'No') {
                    // N/A satisfies org VR requiring points on Completed without user entry.
                    ev.Next_Action_Points__c = 'N/A';
                    ev.Next_Action_Date__c = null;
                }

                if (!hasText(ev.MOM__c)) {
                    throw new AuraHandledException('MOM is required.');
                }
                if (!hasText(ev.Next_Action_Applicable__c)) {
                    throw new AuraHandledException('Next Action Applicable is required.');
                }
                if (ev.Next_Action_Applicable__c == 'Yes') {
                    if (!hasText(ev.Next_Action_Points__c) ||
                        ev.Next_Action_Points__c == 'N/A') {
                        throw new AuraHandledException('Next Action Points is required.');
                    }
                    if (ev.Next_Action_Date__c == null) {
                        throw new AuraHandledException('Next Action Date is required.');
                    }
                }
            }

            try {
                update ev;
            } catch (DmlException e) {
                throw new AuraHandledException(e.getDmlMessage(0));
            }
            // Owner may have changed; still try to return detail for the current user
            try {
                return getActivityDetail(ev.Id);
            } catch (Exception e) {
                ActivityDetailWrapper w = new ActivityDetailWrapper();
                w.id = ev.Id;
                w.objectType = 'Event';
                return w;
            }
        }

        throw new AuraHandledException('Unsupported activity type.');
    }

    private static String toDateTimeLocal(Datetime dt) {
        if (dt == null) {
            return '';
        }
        return dt.format('yyyy-MM-dd\'T\'HH:mm');
    }

    private static Boolean hasText(String value) {
        return String.isNotBlank(value);
    }

    private static String blankToNull(String value) {
        return String.isBlank(value) ? null : value.trim();
    }

    private static Datetime parseDateTimeLocal(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String norm = value.trim().replace('T', ' ');
        List<String> parts = norm.split(' ');
        if (parts.isEmpty()) {
            return null;
        }
        Date d = Date.valueOf(parts[0]);
        Integer hour = 0;
        Integer minute = 0;
        Integer second = 0;
        if (parts.size() > 1) {
            List<String> tp = parts[1].split(':');
            if (!tp.isEmpty()) {
                hour = Integer.valueOf(tp[0]);
            }
            if (tp.size() > 1) {
                minute = Integer.valueOf(tp[1]);
            }
            if (tp.size() > 2) {
                second = Integer.valueOf(tp[2]);
            }
        }
        return Datetime.newInstance(d.year(), d.month(), d.day(), hour, minute, second);
    }

    // "New Task" quick action
    @AuraEnabled
    public static ActivityWrapper createTask(Id leadId, String subject, Date dueDate) {
        Task t = new Task();
        t.WhoId = leadId;
        t.Subject = String.isBlank(subject) ? 'New Task' : subject;
        t.ActivityDate = dueDate;
        t.Status = 'Not Started';
        t.TaskSubtype = 'Task';
        insert t;

        ActivityWrapper w = new ActivityWrapper();
        w.id = t.Id;
        w.subject = t.Subject;
        w.type = 'Task';
        w.dueDate = t.ActivityDate != null ? t.ActivityDate.format() : 'No due date';
        w.isOverdue = false;
        w.isClosed = false;
        return w;
    }

    // "New Event" quick action
    @AuraEnabled
    public static ActivityWrapper createEvent(Id leadId, String subject, Datetime startDateTime, Integer durationMinutes) {
        Event ev = new Event();
        ev.WhoId = leadId;
        ev.Subject = String.isBlank(subject) ? 'New Event' : subject;
        ev.StartDateTime = startDateTime;
        ev.DurationInMinutes = durationMinutes == null ? 30 : durationMinutes;
        insert ev;

        ActivityWrapper w = new ActivityWrapper();
        w.id = ev.Id;
        w.subject = ev.Subject;
        w.type = 'Event';
        w.dueDate = ev.StartDateTime != null
            ? ev.StartDateTime.format('dd MMM yyyy, hh:mm a')
            : '';
        w.isOverdue = false;
        w.isClosed = false;
        return w;
    }

   @AuraEnabled
public static void updateLeadStatus(Id leadId, String newStatus) {
    Lead leadRecord = [
        SELECT Id, Dealer_Status__c
        FROM Lead
        WHERE Id = :leadId
        LIMIT 1
    ];

    // Regret requires Regret_Reason1__c — use saveLeadRegret from the portal modal
    if (newStatus == 'Regret') {
        throw new AuraHandledException(
            'Please set Regret Reason to mark this lead as Regret.'
        );
    }

    leadRecord.Dealer_Status__c = newStatus;
    update leadRecord;
}

    /**
     * Portal path "Regret": requires Regret Reason (Regret_Reason1__c).
     * When reason is Other, Other Regret Reason (Regret_Reason__c) is required.
     */
    public class RegretInfoInput {
        @AuraEnabled public Id leadId { get; set; }
        @AuraEnabled public String regretReason { get; set; }
        @AuraEnabled public String otherRegretReason { get; set; }
    }

    public class RegretInfoResult {
        @AuraEnabled public Id leadId { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String regretReason { get; set; }
        @AuraEnabled public String otherRegretReason { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getRegretReasonOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Schema.DescribeFieldResult dfr = Lead.Regret_Reason1__c.getDescribe();
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (!pe.isActive()) {
                continue;
            }
            options.add(new Map<String, String>{
                'label' => pe.getLabel(),
                'value' => pe.getValue()
            });
        }
        return options;
    }

    @AuraEnabled
    public static RegretInfoResult saveLeadRegret(RegretInfoInput input) {
        if (input == null || input.leadId == null) {
            throw new AuraHandledException('Lead is required.');
        }
        if (String.isBlank(input.regretReason)) {
            throw new AuraHandledException('Regret Reason is required.');
        }
        String reason = input.regretReason.trim();
        String otherReason = String.isNotBlank(input.otherRegretReason)
            ? input.otherRegretReason.trim()
            : null;

        if (reason == 'Other' && String.isBlank(otherReason)) {
            throw new AuraHandledException('Other Regret Reason is required when reason is Other.');
        }
        if (reason != 'Other') {
            otherReason = null;
        }

        Lead leadRecord = [
            SELECT Id, Status, Dealer_Status__c, Dealer__c, Regret_Reason1__c, Regret_Reason__c
            FROM Lead
            WHERE Id = :input.leadId
            LIMIT 1
        ];

        User currentUser = [
            SELECT AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (leadRecord.Dealer__c != currentUser.AccountId) {
            throw new AuraHandledException('You are not authorised to update this lead.');
        }

        leadRecord.Dealer_Status__c = 'Regret';
        leadRecord.Regret_Reason1__c = reason;
        leadRecord.Regret_Reason__c = otherReason;
        leadRecord.Regret_Date_Time__c = System.now();

        try {
            update leadRecord;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }

        RegretInfoResult result = new RegretInfoResult();
        result.leadId = leadRecord.Id;
        result.status = 'Regret';
        result.regretReason = reason;
        result.otherRegretReason = otherReason;
        return result;
    }

    private static final String CONTACTED_DOC_TITLE = 'Portal_Contacted_Info';

    public class ContactedInfoInput {
        @AuraEnabled public Id leadId { get; set; }
        @AuraEnabled public String contactPersonName { get; set; }
        @AuraEnabled public String designation { get; set; }
        @AuraEnabled public String emailId { get; set; }
        @AuraEnabled public String mom { get; set; }
    }

    public class ContactedInfoResult {
        @AuraEnabled public Id leadId { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String contactPersonName { get; set; }
        @AuraEnabled public String designation { get; set; }
        @AuraEnabled public String emailId { get; set; }
        @AuraEnabled public String mom { get; set; }
    }

    /**
     * Saves Contacted-path details as a linked Content file (no Lead custom fields)
     * and moves Dealer Status to Contacted. Portal-only payload for display under Files.
     */
    @AuraEnabled
    public static ContactedInfoResult saveLeadContactedInfo(ContactedInfoInput input) {
        if (input == null || input.leadId == null) {
            throw new AuraHandledException('Lead is required.');
        }
        if (String.isBlank(input.contactPersonName)) {
            throw new AuraHandledException('Contact Person Name is required.');
        }
        if (String.isBlank(input.designation)) {
            throw new AuraHandledException('Designation is required.');
        }
        if (String.isBlank(input.emailId)) {
            throw new AuraHandledException('Email ID is required.');
        }
        if (String.isBlank(input.mom)) {
            throw new AuraHandledException('MOM is required.');
        }

        Lead leadRecord = [
            SELECT Id, Status, Dealer_Status__c, Dealer__c
            FROM Lead
            WHERE Id = :input.leadId
            LIMIT 1
        ];

        User currentUser = [
            SELECT AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (leadRecord.Dealer__c != currentUser.AccountId) {
            throw new AuraHandledException('You are not authorised to update this lead.');
        }

        Map<String, String> payload = new Map<String, String>{
            'contactPersonName' => input.contactPersonName.trim(),
            'designation' => input.designation.trim(),
            'emailId' => input.emailId.trim(),
            'mom' => input.mom.trim()
        };
        String jsonBody = JSON.serialize(payload);

        Id existingDocId = null;
        List<ContentDocumentLink> existingLinks = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :input.leadId
              AND ContentDocument.Title = :CONTACTED_DOC_TITLE
            ORDER BY ContentDocument.CreatedDate DESC
            LIMIT 1
        ];
        if (!existingLinks.isEmpty()) {
            existingDocId = existingLinks[0].ContentDocumentId;
        }

        ContentVersion cv = new ContentVersion();
        cv.Title = CONTACTED_DOC_TITLE;
        cv.PathOnClient = CONTACTED_DOC_TITLE + '.txt';
        cv.VersionData = Blob.valueOf(jsonBody);
        cv.IsMajorVersion = true;
        if (existingDocId != null) {
            cv.ContentDocumentId = existingDocId;
        } else {
            cv.FirstPublishLocationId = input.leadId;
        }
        insert cv;

        leadRecord.Dealer_Status__c = 'Contacted';
        update leadRecord;

        ContactedInfoResult result = new ContactedInfoResult();
        result.leadId = leadRecord.Id;
        result.status = leadRecord.Dealer_Status__c;
        result.contactPersonName = payload.get('contactPersonName');
        result.designation = payload.get('designation');
        result.emailId = payload.get('emailId');
        result.mom = payload.get('mom');
        return result;
    }

    @AuraEnabled
    public static ContactedInfoResult getLeadContactedInfo(Id leadId) {
        ContactedInfoResult result = new ContactedInfoResult();
        result.leadId = leadId;
        if (leadId == null) {
            return result;
        }

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :leadId
              AND ContentDocument.Title = :CONTACTED_DOC_TITLE
            ORDER BY ContentDocument.CreatedDate DESC
            LIMIT 1
        ];
        if (links.isEmpty()) {
            return result;
        }

        ContentVersion cv = [
            SELECT VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :links[0].ContentDocumentId
              AND IsLatest = true
            LIMIT 1
        ];
        if (cv.VersionData == null) {
            return result;
        }

        try {
            Map<String, Object> data =
                (Map<String, Object>) JSON.deserializeUntyped(cv.VersionData.toString());
            result.contactPersonName = data.get('contactPersonName') != null
                ? String.valueOf(data.get('contactPersonName'))
                : null;
            // Prefer new keys; fall back to old mobileNo / remarks if previously saved
            Object desig = data.containsKey('designation') ? data.get('designation') : data.get('mobileNo');
            Object momVal = data.containsKey('mom') ? data.get('mom') : data.get('remarks');
            result.designation = desig != null ? String.valueOf(desig) : null;
            result.emailId = data.get('emailId') != null
                ? String.valueOf(data.get('emailId'))
                : null;
            result.mom = momVal != null ? String.valueOf(momVal) : null;
        } catch (Exception e) {
            System.debug(e.getMessage());
        }
        return result;
    }

    /* =========================================================
       NOTES (ContentNote linked to the Lead)
    ========================================================= */

    public class NoteWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String body;
        @AuraEnabled public String createdDate;
        @AuraEnabled public String author;
    }

    @AuraEnabled
    public static List<NoteWrapper> getLeadNotes(Id leadId) {
        List<NoteWrapper> results = new List<NoteWrapper>();
        if (leadId == null) {
            return results;
        }

        // LinkedEntityId filter allows ContentDocument.* fields in SELECT/WHERE
        for (ContentDocumentLink l : [
            SELECT
                ContentDocumentId,
                ContentDocument.Title,
                ContentDocument.FileType,
                ContentDocument.CreatedDate,
                ContentDocument.CreatedBy.Name,
                ContentDocument.LatestPublishedVersion.TextPreview
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :leadId
              AND ContentDocument.FileType = 'SNOTE'
            ORDER BY ContentDocument.CreatedDate DESC
        ]) {
            NoteWrapper w = new NoteWrapper();
            w.id = l.ContentDocumentId;
            String preview = l.ContentDocument.LatestPublishedVersion != null
                ? l.ContentDocument.LatestPublishedVersion.TextPreview
                : null;
            w.body = String.isBlank(preview)
                ? l.ContentDocument.Title
                : stripHtml(preview);
            w.createdDate = l.ContentDocument.CreatedDate.format('dd MMM yyyy, hh:mm a');
            w.author = l.ContentDocument.CreatedBy.Name;
            results.add(w);
        }

        return results;
    }

    // Adds a plain-text note and links it to the Lead
    @AuraEnabled
    public static NoteWrapper addLeadNote(Id leadId, String noteBody) {
        if (leadId == null) {
            throw new AuraHandledException('Lead Id is required.');
        }
        if (String.isBlank(noteBody)) {
            throw new AuraHandledException('Note text is required.');
        }

        String bodyText = noteBody.trim();

        ContentNote note = new ContentNote();
        note.Title = bodyText.length() > 80 ? bodyText.substring(0, 80) : bodyText;
        // Enhanced Notes store HTML; escape plain text so CRM and portal both display it
        note.Content = Blob.valueOf(bodyText.escapeHtml4());
        insert note;

        // ContentNote.Id == ContentDocumentId — do NOT query ContentVersion by note.Id
        ContentDocumentLink link = new ContentDocumentLink();
        link.ContentDocumentId = note.Id;
        link.LinkedEntityId = leadId;
        link.ShareType = 'V';
        link.Visibility = 'AllUsers';
        insert link;

        ContentVersion insertedNoteCV = [
            SELECT ContentDocumentId, TextPreview, CreatedDate, CreatedBy.Name, Title
            FROM ContentVersion
            WHERE ContentDocumentId = :note.Id
              AND IsLatest = true
            LIMIT 1
        ];

        NoteWrapper w = new NoteWrapper();
        w.id = insertedNoteCV.ContentDocumentId;
        w.body = String.isBlank(insertedNoteCV.TextPreview)
            ? insertedNoteCV.Title
            : stripHtml(insertedNoteCV.TextPreview);
        w.createdDate = insertedNoteCV.CreatedDate.format('dd MMM yyyy, hh:mm a');
        w.author = insertedNoteCV.CreatedBy.Name;

        return w;
    }

    private static String stripHtml(String value) {
        if (String.isBlank(value)) {
            return value;
        }
        return value
            .replaceAll('(?i)<br\\s*/?>', '\n')
            .replaceAll('(?i)</p>', '\n')
            .replaceAll('<[^>]+>', '')
            .unescapeHtml4()
            .trim();
    }


    /* =========================================================
       FILES (real Salesforce Files via ContentDocumentLink)
    ========================================================= */

    public class FileWrapper {
        @AuraEnabled public Id id;              // ContentDocumentId
        @AuraEnabled public Id versionId;       // ContentVersionId - needed to build a download/preview URL
        @AuraEnabled public String title;
        @AuraEnabled public String size;        // human readable
        @AuraEnabled public String uploadedDate;
        @AuraEnabled public String fileType;    // e.g. 'PNG', 'JPG', 'PDF' - used by the UI to decide how to render the preview
    }

    @AuraEnabled
    public static List<FileWrapper> getLeadFiles(Id leadId) {
        List<FileWrapper> results = new List<FileWrapper>();

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId,
                   ContentDocument.Title,
                   ContentDocument.ContentSize,
                   ContentDocument.CreatedDate,
                   ContentDocument.FileType,
                   ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :leadId
            ORDER BY ContentDocument.CreatedDate DESC
        ];

        for (ContentDocumentLink l : links) {
            // Skip ContentNotes here — they're surfaced in getLeadNotes() instead
            if (l.ContentDocument.FileType == 'SNOTE') {
                continue;
            }
            // Skip portal Contacted payload file — shown in Contacted Details card
            if (l.ContentDocument.Title == CONTACTED_DOC_TITLE) {
                continue;
            }

            FileWrapper w = new FileWrapper();
            w.id = l.ContentDocumentId;
            w.versionId = l.ContentDocument.LatestPublishedVersionId;
            w.fileType = l.ContentDocument.FileType;
            w.title = l.ContentDocument.Title;
            w.size = formatFileSize(l.ContentDocument.ContentSize);
            w.uploadedDate = l.ContentDocument.CreatedDate.format('dd MMM yyyy');
            results.add(w);
        }

        return results;
    }

    private static String formatFileSize(Integer bytes) {
        if (bytes == null) return '';
        if (bytes < 1024) return bytes + ' B';
        if (bytes < 1024 * 1024) return (bytes / 1024) + ' KB';
        return (bytes / (1024 * 1024)) + ' MB';
    }

    
    @AuraEnabled
    public static FileWrapper saveLeadAttachment(Id leadId, String fileName, String base64Data) {
        try {
            // Confirm the Lead belongs to the current user's dealer account
            Lead ld = [
                SELECT Id, Dealer__c
                FROM Lead
                WHERE Id = :leadId
                LIMIT 1
            ];

            User currentUser = [
                SELECT AccountId
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];

            if (ld.Dealer__c != currentUser.AccountId) {
                throw new AuraHandledException('Unauthorised attachment operation.');
            }

            ContentVersion cv = new ContentVersion(
                Title          = fileName,
                PathOnClient   = fileName,
                VersionData    = EncodingUtil.base64Decode(base64Data),
                IsMajorVersion = true
            );
            insert cv;

            ContentVersion insertedCV = [
                SELECT ContentDocumentId,
                       ContentDocument.Title,
                       ContentDocument.ContentSize,
                       ContentDocument.CreatedDate,
                       ContentDocument.FileType,
                       ContentDocument.LatestPublishedVersionId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ];

            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = insertedCV.ContentDocumentId,
                LinkedEntityId    = leadId,
                ShareType         = 'V',
                Visibility        = 'AllUsers'
            );
            insert cdl;

            FileWrapper w = new FileWrapper();
            w.id = insertedCV.ContentDocumentId;
            w.versionId = insertedCV.ContentDocument.LatestPublishedVersionId;
            w.fileType = insertedCV.ContentDocument.FileType;
            w.title = insertedCV.ContentDocument.Title;
            w.size = formatFileSize(insertedCV.ContentDocument.ContentSize);
            w.uploadedDate = insertedCV.ContentDocument.CreatedDate.format('dd MMM yyyy');

            return w;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}