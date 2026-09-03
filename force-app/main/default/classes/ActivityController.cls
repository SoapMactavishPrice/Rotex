public without sharing class ActivityController {

    /*------------------------------------------------------------
     * Wrapper for Picklist
     *-----------------------------------------------------------*/
    public class PicklistOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }

        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    /*------------------------------------------------------------
     * Lookup search result
     *-----------------------------------------------------------*/
    public class LookupResult {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String subtitle { get; set; }
        @AuraEnabled public String objectType { get; set; }

        public LookupResult(Id id, String name, String subtitle, String objectType) {
            this.id = id != null ? String.valueOf(id) : null;
            this.name = name;
            this.subtitle = subtitle;
            this.objectType = objectType;
        }
    }

    /*------------------------------------------------------------
     * Created activity summary for UI refresh
     *-----------------------------------------------------------*/
    public class ActivitySummary {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String subject { get; set; }
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public String dueDate { get; set; }
        @AuraEnabled public Boolean isOverdue { get; set; }
        @AuraEnabled public Boolean isClosed { get; set; }
    }

    /*------------------------------------------------------------
     * Wrapper used to create Event
     *-----------------------------------------------------------*/
    public class EventWrapper {
        @AuraEnabled public String subject;
        @AuraEnabled public Id ownerId;
        @AuraEnabled public Datetime startDateTime;
        @AuraEnabled public Datetime endDateTime;
        @AuraEnabled public String location;
        @AuraEnabled public String description;
        @AuraEnabled public String visitStatus;
        @AuraEnabled public String visitType;
        @AuraEnabled public Id whatId;
        @AuraEnabled public Id whoId;
        @AuraEnabled public Boolean reminder;
        @AuraEnabled public String mom;
        @AuraEnabled public String nextActionPoints;
        @AuraEnabled public Date nextActionDate;
        @AuraEnabled public String nextActionApplicable;
        @AuraEnabled public Integer reminderMinutes;
    }

    public class TaskWrapper {
        @AuraEnabled public String subject { get; set; }
        @AuraEnabled public String priority { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String assignedToId { get; set; }
        @AuraEnabled public String dueDate { get; set; }
        @AuraEnabled public String whatId { get; set; }
        @AuraEnabled public String whoId { get; set; }
        @AuraEnabled public Boolean reminderSet { get; set; }
        @AuraEnabled public String reminderDateTime { get; set; }
        @AuraEnabled public String completedDateTime { get; set; }
        @AuraEnabled public String leadId { get; set; }
        @AuraEnabled public String partnerAccountId { get; set; }
        @AuraEnabled public String quoteId { get; set; }
    }

    /*------------------------------------------------------------
     * Current user (Assigned To default)
     *-----------------------------------------------------------*/
    @AuraEnabled(cacheable=true)
    public static User getCurrentUser() {
        return [
            SELECT Id, Name, Email
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
    }

    /*------------------------------------------------------------
     * Event Subject Picklist
     *-----------------------------------------------------------*/
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getEventSubjects() {
        try {
            List<PicklistOption> result = getActivePicklistOptions(
                Event.Subject.getDescribe()
            );
            if (!result.isEmpty()) {
                return result;
            }
        } catch (Exception e) {
            // fall through to defaults
        }
        return defaultSubjects();
    }

    /*------------------------------------------------------------
     * Visit Status Picklist (Scheduled, Completed)
     *-----------------------------------------------------------*/
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getVisitStatusValues() {
        try {
            List<PicklistOption> result = getActivePicklistOptions(
                Event.Visit_Status__c.getDescribe()
            );
            if (!result.isEmpty()) {
                return result;
            }
        } catch (Exception e) {
            // fall through to defaults
        }
        return defaultVisitStatuses();
    }

    /*------------------------------------------------------------
     * Visit Type Picklist (Offline, Virtual)
     *-----------------------------------------------------------*/
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getVisitTypeValues() {
        try {
            List<PicklistOption> result = getActivePicklistOptions(
                Event.Visit_Type__c.getDescribe()
            );
            if (!result.isEmpty()) {
                return result;
            }
        } catch (Exception e) {
            // fall through to defaults
        }
        return defaultVisitTypes();
    }

    /*------------------------------------------------------------
     * Create Event
     *-----------------------------------------------------------*/
    @AuraEnabled
    public static ActivitySummary createEvent(EventWrapper wrapper) {
        if (wrapper == null) {
            throw new AuraHandledException('Event details are required.');
        }
        if (String.isBlank(wrapper.subject)) {
            throw new AuraHandledException('Subject is required.');
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

        // Lead WhoId cannot be combined with WhatId
        if (isLeadWho && wrapper.whatId != null) {
            throw new AuraHandledException(
                'Related To cannot be set when Name is a Lead. Clear Related To or choose a Contact.'
            );
        }

        Event ev = new Event();
        ev.Subject = wrapper.subject;
        ev.OwnerId = wrapper.ownerId != null ? wrapper.ownerId : UserInfo.getUserId();
        ev.StartDateTime = wrapper.startDateTime;
        ev.EndDateTime = wrapper.endDateTime;
        ev.Location = wrapper.location;
        ev.Visit_Status__c = wrapper.visitStatus;
        ev.Visit_Type__c = wrapper.visitType;
        ev.WhatId = wrapper.whatId;
        ev.WhoId = wrapper.whoId;
        ev.IsReminderSet = wrapper.reminder == true;

        if (ev.IsReminderSet) {
            Integer mins = wrapper.reminderMinutes == null
                ? 15
                : wrapper.reminderMinutes;

            ev.ReminderDateTime = wrapper.startDateTime.addMinutes(-mins);
        }

        // Status & Description fields — only when Visit Status = Completed
        if (wrapper.visitStatus == 'Completed') {
            ev.Description = wrapper.description;
            ev.MOM__c = wrapper.mom;
            ev.Next_Action_Points__c = wrapper.nextActionPoints;
            ev.Next_Action_Applicable__c = wrapper.nextActionApplicable;
            ev.Next_Action_Date__c = wrapper.nextActionDate;
        }

        try {
            insert ev;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }

        ActivitySummary summary = new ActivitySummary();
        summary.id = ev.Id;
        summary.subject = ev.Subject;
        summary.type = 'Event';
        summary.dueDate = ev.StartDateTime.format('dd MMM yyyy, hh:mm a');
        summary.isOverdue = false;
        summary.isClosed = false;
        return summary;
    }

    /*------------------------------------------------------------
     * Task Subject Picklist
     *-----------------------------------------------------------*/
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getTaskSubjects() {
        try {
            List<PicklistOption> result = getActivePicklistOptions(
                Task.Subject.getDescribe()
            );
            if (!result.isEmpty()) {
                return result;
            }
        } catch (Exception e) {
            // fall through to defaults
        }
        return defaultSubjects();
    }

    /*------------------------------------------------------------
     * Task Priority Picklist (High, Normal, ...)
     *-----------------------------------------------------------*/
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getTaskPriorityValues() {
        try {
            List<PicklistOption> result = getActivePicklistOptions(
                Task.Priority.getDescribe()
            );
            if (!result.isEmpty()) {
                return result;
            }
        } catch (Exception e) {
            // fall through to defaults
        }
        return new List<PicklistOption>{
            new PicklistOption('High', 'High'),
            new PicklistOption('Normal', 'Normal'),
            new PicklistOption('Low', 'Low')
        };
    }

    /*------------------------------------------------------------
     * Task Status — Open / Completed only
     *-----------------------------------------------------------*/
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getTaskStatusValues() {
        return new List<PicklistOption>{
            new PicklistOption('Open', 'Open'),
            new PicklistOption('Completed', 'Completed')
        };
    }

    /*------------------------------------------------------------
     * Create Task
     *-----------------------------------------------------------*/
    @AuraEnabled
    public static ActivitySummary createTask(TaskWrapper wrapper) {
        if (wrapper == null) {
            throw new AuraHandledException('Task details are required.');
        }
        if (String.isBlank(wrapper.subject)) {
            throw new AuraHandledException('Subject is required.');
        }
        if (String.isBlank(wrapper.description)) {
            throw new AuraHandledException('Task Description is required.');
        }
        Date dueDate = parseClientDate(wrapper.dueDate);
        if (dueDate == null) {
            throw new AuraHandledException('Task Due Date is required.');
        }
        if (String.isBlank(wrapper.whatId) && String.isBlank(wrapper.quoteId)) {
            throw new AuraHandledException('Related To is required.');
        }
        Id quoteId = String.isBlank(wrapper.quoteId) ? null : Id.valueOf(wrapper.quoteId);
        Id whatId = String.isBlank(wrapper.whatId) ? null : Id.valueOf(wrapper.whatId);
        Id leadId = String.isBlank(wrapper.leadId) ? null : Id.valueOf(wrapper.leadId);
        Id partnerAccountId = String.isBlank(wrapper.partnerAccountId)
            ? null
            : Id.valueOf(wrapper.partnerAccountId);

        if (quoteId != null) {
            assertQuoteAccessibleForPartner(quoteId, partnerAccountId);
            whatId = quoteId;
        } else if (!isCustomerOfPartner(whatId, leadId, partnerAccountId)) {
            throw new AuraHandledException(
                'Related To must be a Customer account linked to your Channel Partner.'
            );
        }
        if (String.isBlank(wrapper.whoId)) {
            throw new AuraHandledException('Name is required.');
        }
        Id whoId = Id.valueOf(wrapper.whoId);

        // Name must be a Contact of the selected Customer account (or Quote's account)
        List<Contact> whoContacts = [
            SELECT Id, AccountId
            FROM Contact
            WHERE Id = :whoId
            LIMIT 1
        ];
        if (whoContacts.isEmpty()) {
            throw new AuraHandledException(
                'Name must be a Contact of the selected Related To Customer account.'
            );
        }
        if (quoteId == null && whoContacts[0].AccountId != whatId) {
            throw new AuraHandledException(
                'Name must be a Contact of the selected Related To Customer account.'
            );
        }
        if (quoteId != null) {
            Id quoteAccountId = resolveQuoteAccountId(quoteId);
            if (quoteAccountId != null && whoContacts[0].AccountId != quoteAccountId) {
                throw new AuraHandledException(
                    'Name must be a Contact of the Quote Account.'
                );
            }
        }

        Id assignedToId = String.isBlank(wrapper.assignedToId)
            ? null
            : Id.valueOf(wrapper.assignedToId);

        Task t = new Task();
        t.Subject = wrapper.subject;
        t.Priority = wrapper.priority;
        t.Status = wrapper.status;
        t.Description = wrapper.description;
        t.OwnerId = resolveAssignedToUserId(assignedToId);
        t.ActivityDate = dueDate;
        t.WhatId = whatId;
        t.WhoId = whoId;
        t.IsReminderSet = wrapper.reminderSet == true;

        if (t.IsReminderSet) {
            Datetime remindAt = parseClientDateTime(wrapper.reminderDateTime);
            if (remindAt == null) {
                remindAt = parseClientDateTime(wrapper.completedDateTime);
            }
            if (remindAt != null) {
                t.ReminderDateTime = remindAt;
            }
        }

        try {
            insert t;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }

        ActivitySummary summary = new ActivitySummary();
        summary.id = t.Id;
        summary.subject = t.Subject;
        summary.type = 'Task';
        summary.dueDate = t.ActivityDate != null ? t.ActivityDate.format() : '';
        summary.isOverdue = t.ActivityDate != null && t.ActivityDate < Date.today();
        summary.isClosed = t.Status == 'Completed';
        return summary;
    }

    /*------------------------------------------------------------
     * Debug helper — returns how Channel Partner was resolved
     * so the UI can show why lookups are empty.
     *-----------------------------------------------------------*/
    public class PartnerDebugInfo {
        @AuraEnabled public Id userId { get; set; }
        @AuraEnabled public String userName { get; set; }
        @AuraEnabled public String userEmail { get; set; }
        @AuraEnabled public Id userAccountId { get; set; }
        @AuraEnabled public Id userContactAccountId { get; set; }
        @AuraEnabled public Id leadId { get; set; }
        @AuraEnabled public Id leadDealerId { get; set; }
        @AuraEnabled public Id passedPartnerAccountId { get; set; }
        @AuraEnabled public Id resolvedPartnerId { get; set; }
        @AuraEnabled public String resolvedPartnerName { get; set; }
        @AuraEnabled public String resolveStep { get; set; }
        @AuraEnabled public Integer partnerContactCount { get; set; }
        @AuraEnabled public Integer customerAccountCount { get; set; }
        @AuraEnabled public String message { get; set; }
    }

    @AuraEnabled
    public static PartnerDebugInfo debugPartnerContext(Id leadId, Id partnerAccountId) {
        PartnerDebugInfo info = new PartnerDebugInfo();
        info.leadId = leadId;
        info.passedPartnerAccountId = partnerAccountId;
        info.partnerContactCount = 0;
        info.customerAccountCount = 0;

        User u = [
            SELECT Id, Name, Email, AccountId, ContactId, Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        info.userId = u.Id;
        info.userName = u.Name;
        info.userEmail = u.Email;
        info.userAccountId = u.AccountId;
        info.userContactAccountId = u.Contact != null ? u.Contact.AccountId : null;

        if (leadId != null) {
            for (Lead ld : [
                SELECT Dealer__c
                FROM Lead
                WHERE Id = :leadId
                LIMIT 1
            ]) {
                info.leadDealerId = ld.Dealer__c;
            }
        }

        Id resolved;
        String step;
        if (partnerAccountId != null) {
            resolved = partnerAccountId;
            step = 'passedPartnerAccountId';
        } else if (info.leadDealerId != null) {
            resolved = info.leadDealerId;
            step = 'lead.Dealer__c';
        } else {
            resolved = getLoginPartnerAccountId();
            step = resolved != null ? 'getLoginPartnerAccountId' : 'NONE';
        }

        info.resolvedPartnerId = resolved;
        info.resolveStep = step;

        if (resolved != null) {
            for (Account a : [
                SELECT Name FROM Account WHERE Id = :resolved LIMIT 1
            ]) {
                info.resolvedPartnerName = a.Name;
            }
            info.partnerContactCount = [
                SELECT COUNT()
                FROM Contact
                WHERE AccountId = :resolved
            ];
            Id customerRTId = getCustomerRecordTypeId();
            if (customerRTId != null) {
                info.customerAccountCount = [
                    SELECT COUNT()
                    FROM Account
                    WHERE RecordTypeId = :customerRTId
                    AND (
                        Channel_Partner_Name__c = :resolved
                        OR Channel_Partner__c = :resolved
                    )
                ];
            }
            info.message =
                'Partner=' + info.resolvedPartnerName +
                ' | Contacts=' + info.partnerContactCount +
                ' | Customers=' + info.customerAccountCount;
        } else {
            info.message =
                'Could not resolve Channel Partner. ' +
                'User.AccountId=' + String.valueOf(info.userAccountId) +
                ', Lead.Dealer__c=' + String.valueOf(info.leadDealerId) +
                ', User=' + info.userName;
        }
        return info;
    }

    /*------------------------------------------------------------
     * Returns the Channel Partner Account Id for the login user
     * (used by New Task modal to seed lookups).
     *-----------------------------------------------------------*/
    @AuraEnabled(cacheable=true)
    public static Id getMyChannelPartnerAccountId() {
        return getLoginPartnerAccountId();
    }

    /*------------------------------------------------------------
     * Assigned To
     * Contacts on the login user's Channel Partner account.
     * Example: CP "Dhvanit shah" → Niraj Jain, Dhvanit Shah.
     *-----------------------------------------------------------*/
    @AuraEnabled
    public static List<LookupResult> searchUsers(
        String searchText,
        Id leadId,
        Id partnerAccountId
    ) {
        List<LookupResult> results = new List<LookupResult>();
        Id resolvedPartnerId = resolvePartnerAccountId(leadId, partnerAccountId);
        if (resolvedPartnerId == null) {
            return results;
        }

        String term = searchText == null ? '' : searchText.trim();
        String likeKey = '%' + term + '%';
        Set<Id> seen = new Set<Id>();

        List<Contact> contacts = String.isBlank(term)
            ? [
                SELECT Id, Name, Email, Account.Name
                FROM Contact
                WHERE AccountId = :resolvedPartnerId
                ORDER BY Name
                LIMIT 50
              ]
            : [
                SELECT Id, Name, Email, Account.Name
                FROM Contact
                WHERE AccountId = :resolvedPartnerId
                AND (
                    Name LIKE :likeKey
                    OR Email LIKE :likeKey
                )
                ORDER BY Name
                LIMIT 50
              ];

        for (Contact c : contacts) {
            seen.add(c.Id);
            String subtitle = String.isNotBlank(c.Email)
                ? c.Email
                : (c.Account != null ? c.Account.Name : 'Channel Partner Contact');
            results.add(new LookupResult(c.Id, c.Name, subtitle, 'Contact'));
        }

        // Also include contacts related via AccountContactRelation
        if (results.size() < 50) {
            Integer remaining = 50 - results.size();
            List<AccountContactRelation> rels = String.isBlank(term)
                ? [
                    SELECT ContactId, Contact.Name, Contact.Email, Contact.Account.Name
                    FROM AccountContactRelation
                    WHERE AccountId = :resolvedPartnerId
                    AND IsActive = true
                    AND ContactId != null
                    ORDER BY Contact.Name
                    LIMIT :remaining
                  ]
                : [
                    SELECT ContactId, Contact.Name, Contact.Email, Contact.Account.Name
                    FROM AccountContactRelation
                    WHERE AccountId = :resolvedPartnerId
                    AND IsActive = true
                    AND ContactId != null
                    AND (
                        Contact.Name LIKE :likeKey
                        OR Contact.Email LIKE :likeKey
                    )
                    ORDER BY Contact.Name
                    LIMIT :remaining
                  ];

            for (AccountContactRelation rel : rels) {
                if (rel.ContactId == null || seen.contains(rel.ContactId)) {
                    continue;
                }
                seen.add(rel.ContactId);
                String subtitle = (rel.Contact != null && String.isNotBlank(rel.Contact.Email))
                    ? rel.Contact.Email
                    : 'Channel Partner Contact';
                results.add(new LookupResult(
                    rel.ContactId,
                    rel.Contact != null ? rel.Contact.Name : null,
                    subtitle,
                    'Contact'
                ));
            }
        }

        return results;
    }

    /*------------------------------------------------------------
     * Name (WhoId = Contact)
     * Example: Customer "finesse direct" → its Contacts appear here.
     * Only after Related To (Customer) is selected.
     *-----------------------------------------------------------*/
    @AuraEnabled
    public static List<LookupResult> searchWho(
        String searchText,
        Id accountId,
        Id leadId,
        Id partnerAccountId
    ) {
        List<LookupResult> results = new List<LookupResult>();
        if (accountId == null || !isCustomerOfPartner(accountId, leadId, partnerAccountId)) {
            return results;
        }

        String term = searchText == null ? '' : searchText.trim();
        String likeKey = '%' + term + '%';

        List<Contact> contacts = String.isBlank(term)
            ? [
                SELECT Id, Name, Email, Account.Name
                FROM Contact
                WHERE AccountId = :accountId
                ORDER BY Name
                LIMIT 50
              ]
            : [
                SELECT Id, Name, Email, Account.Name
                FROM Contact
                WHERE AccountId = :accountId
                AND (
                    Name LIKE :likeKey
                    OR Email LIKE :likeKey
                )
                ORDER BY Name
                LIMIT 50
              ];

        for (Contact c : contacts) {
            String subtitle = String.isNotBlank(c.Email)
                ? c.Email
                : (c.Account != null ? c.Account.Name : 'Contact');
            results.add(new LookupResult(c.Id, c.Name, subtitle, 'Contact'));
        }
        return results;
    }

    /*------------------------------------------------------------
     * Related To (WhatId)
     * Example: Customer "finesse direct" has Channel Partner Name =
     * "Dhvanit shah" → shows for that partner login.
     * Customer record type only, linked by Channel_Partner_Name__c.
     *-----------------------------------------------------------*/
    @AuraEnabled
    public static List<LookupResult> searchWhat(
        String searchText,
        Id leadId,
        Id partnerAccountId
    ) {
        List<LookupResult> results = new List<LookupResult>();
        Id resolvedPartnerId = resolvePartnerAccountId(leadId, partnerAccountId);
        Id customerRTId = getCustomerRecordTypeId();
        if (resolvedPartnerId == null || customerRTId == null) {
            return results;
        }

        String term = searchText == null ? '' : searchText.trim();
        String likeKey = '%' + term + '%';

        List<Account> accts = String.isBlank(term)
            ? [
                SELECT Id, Name, AccountNumber, BillingStreet, BillingCity, BillingState,
                       Street__c, State__c, District__c
                FROM Account
                WHERE RecordTypeId = :customerRTId
                AND (
                    Channel_Partner_Name__c = :resolvedPartnerId
                    OR Channel_Partner__c = :resolvedPartnerId
                )
                ORDER BY Name
                LIMIT 50
              ]
            : [
                SELECT Id, Name, AccountNumber, BillingStreet, BillingCity, BillingState,
                       Street__c, State__c, District__c
                FROM Account
                WHERE RecordTypeId = :customerRTId
                AND (
                    Channel_Partner_Name__c = :resolvedPartnerId
                    OR Channel_Partner__c = :resolvedPartnerId
                )
                AND (Name LIKE :likeKey OR AccountNumber LIKE :likeKey)
                ORDER BY Name
                LIMIT 50
              ];

        for (Account a : accts) {
            results.add(new LookupResult(a.Id, a.Name, formatAccountSubtitle(a), 'Account'));
        }
        return results;
    }

    /*------------------------------------------------------------
     * Helpers — partner hierarchy isolation
     *-----------------------------------------------------------*/
    private static Id resolveAssignedToUserId(Id assignedToId) {
        if (assignedToId == null) {
            return UserInfo.getUserId();
        }

        String prefix = String.valueOf(assignedToId).substring(0, 3);
        String userPrefix = User.SObjectType.getDescribe().getKeyPrefix();
        String contactPrefix = Contact.SObjectType.getDescribe().getKeyPrefix();

        if (prefix == userPrefix) {
            return assignedToId;
        }

        if (prefix == contactPrefix) {
            List<User> linkedUsers = [
                SELECT Id
                FROM User
                WHERE ContactId = :assignedToId
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

    /**
     * Resolve Channel Partner Account.
     * Priority:
     * 1) Explicit partnerAccountId from UI (Lead.Dealer__c)
     * 2) Lead.Dealer__c
     * 3) Login user Channel Partner resolution (see getLoginPartnerAccountId)
     */
    private static Id resolvePartnerAccountId(Id leadId, Id partnerAccountId) {
        if (partnerAccountId != null) {
            return partnerAccountId;
        }

        if (leadId != null) {
            for (Lead ld : [
                SELECT Dealer__c
                FROM Lead
                WHERE Id = :leadId
                LIMIT 1
            ]) {
                if (ld.Dealer__c != null) {
                    return ld.Dealer__c;
                }
            }
        }

        return getLoginPartnerAccountId();
    }

    /**
     * Find the login user's Channel Partner account.
     * Supports portal users (AccountId) AND internal users who own
     * Customer accounts or match the Channel Partner account by name/email.
     */
    private static Id getLoginPartnerAccountId() {
        User u = [
            SELECT Id, Name, Email, AccountId, ContactId, Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        Id cpRtId = getChannelPartnerRecordTypeId();
        Id customerRTId = getCustomerRecordTypeId();

        // 1) Portal: User.AccountId is Channel Partner
        if (u.AccountId != null) {
            Id partnerId = coerceToChannelPartnerId(u.AccountId, cpRtId);
            if (partnerId != null) {
                return partnerId;
            }
        }

        // 2) Portal: Contact's Account is Channel Partner
        if (u.Contact != null && u.Contact.AccountId != null) {
            Id partnerId = coerceToChannelPartnerId(u.Contact.AccountId, cpRtId);
            if (partnerId != null) {
                return partnerId;
            }
        }

        // 3) Match user email to a Contact on a Channel Partner account
        //    Example: contact "Dhvanit shah" email on CP account
        if (cpRtId != null && String.isNotBlank(u.Email)) {
            for (Contact c : [
                SELECT AccountId
                FROM Contact
                WHERE Email = :u.Email
                AND AccountId != null
                AND Account.RecordTypeId = :cpRtId
                LIMIT 1
            ]) {
                return c.AccountId;
            }
        }

        // 4) Match user name to Channel Partner Account Name
        //    Example: User "Dhvanit shah" ↔ Account "Dhvanit shah"
        if (cpRtId != null && String.isNotBlank(u.Name)) {
            for (Account a : [
                SELECT Id
                FROM Account
                WHERE RecordTypeId = :cpRtId
                AND Name = :u.Name
                LIMIT 1
            ]) {
                return a.Id;
            }
        }

        // 5) Match user name to a Contact on a Channel Partner account
        if (cpRtId != null && String.isNotBlank(u.Name)) {
            for (Contact c : [
                SELECT AccountId
                FROM Contact
                WHERE Name = :u.Name
                AND AccountId != null
                AND Account.RecordTypeId = :cpRtId
                LIMIT 1
            ]) {
                return c.AccountId;
            }
        }

        // 6) Internal user who owns Customer accounts —
        //    take Channel_Partner_Name__c from one of those customers
        //    Example: owns "finesse direct" → Channel Partner Name = Dhvanit shah
        if (customerRTId != null) {
            for (Account cust : [
                SELECT Channel_Partner_Name__c, Channel_Partner__c
                FROM Account
                WHERE RecordTypeId = :customerRTId
                AND OwnerId = :UserInfo.getUserId()
                AND (
                    Channel_Partner_Name__c != null
                    OR Channel_Partner__c != null
                )
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ]) {
                if (cust.Channel_Partner_Name__c != null) {
                    return cust.Channel_Partner_Name__c;
                }
                if (cust.Channel_Partner__c != null) {
                    return cust.Channel_Partner__c;
                }
            }
        }

        // 7) Last resort: raw AccountId
        if (u.AccountId != null) {
            return u.AccountId;
        }
        return u.Contact != null ? u.Contact.AccountId : null;
    }

    private static Id coerceToChannelPartnerId(Id accountId, Id cpRtId) {
        if (accountId == null) {
            return null;
        }
        List<Account> accts = [
            SELECT Id, RecordTypeId, RecordType.DeveloperName,
                   Channel_Partner_Name__c, Channel_Partner__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        if (accts.isEmpty()) {
            return null;
        }
        Account a = accts[0];
        if (cpRtId != null && a.RecordTypeId == cpRtId) {
            return a.Id;
        }
        if (a.RecordType != null && a.RecordType.DeveloperName == 'Channel_Partner') {
            return a.Id;
        }
        if (a.Channel_Partner_Name__c != null) {
            return a.Channel_Partner_Name__c;
        }
        if (a.Channel_Partner__c != null) {
            return a.Channel_Partner__c;
        }
        return null;
    }

    private static Id getCustomerRecordTypeId() {
        for (RecordType rt : [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
            AND (DeveloperName = 'Customer' OR Name = 'Customer')
            LIMIT 1
        ]) {
            return rt.Id;
        }
        return null;
    }

    private static Id getChannelPartnerRecordTypeId() {
        for (RecordType rt : [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
            AND (
                DeveloperName = 'Channel_Partner'
                OR Name = 'Channel Partner'
            )
            LIMIT 1
        ]) {
            return rt.Id;
        }
        return null;
    }

    private static Boolean isCustomerOfPartner(
        Id accountId,
        Id leadId,
        Id partnerAccountId
    ) {
        if (accountId == null) {
            return false;
        }
        Id resolvedPartnerId = resolvePartnerAccountId(leadId, partnerAccountId);
        if (resolvedPartnerId == null) {
            return false;
        }
        Id customerRTId = getCustomerRecordTypeId();

        List<Account> accts = [
            SELECT Id, Channel_Partner_Name__c, Channel_Partner__c, RecordTypeId
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        if (accts.isEmpty()) {
            return false;
        }
        Account a = accts[0];
        if (customerRTId != null && a.RecordTypeId != customerRTId) {
            return false;
        }
        return a.Channel_Partner_Name__c == resolvedPartnerId
            || a.Channel_Partner__c == resolvedPartnerId;
    }

    private static String formatAccountSubtitle(Account a) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(a.AccountNumber)) {
            parts.add(a.AccountNumber);
        }
        List<String> loc = new List<String>();
        String street = String.isNotBlank(a.Street__c) ? a.Street__c : a.BillingStreet;
        String city = String.isNotBlank(a.District__c) ? a.District__c : a.BillingCity;
        String state = String.isNotBlank(a.State__c) ? a.State__c : a.BillingState;
        if (String.isNotBlank(street)) {
            loc.add(street);
        }
        if (String.isNotBlank(city)) {
            loc.add(city);
        }
        if (String.isNotBlank(state)) {
            loc.add(state);
        }
        if (!loc.isEmpty()) {
            parts.add('(' + String.join(loc, ', ') + ')');
        }
        return parts.isEmpty() ? 'Customer' : String.join(parts, ' ');
    }

    private static List<PicklistOption> getActivePicklistOptions(
        Schema.DescribeFieldResult fieldDescribe
    ) {
        List<PicklistOption> result = new List<PicklistOption>();
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            if (entry.isActive()) {
                result.add(new PicklistOption(entry.getLabel(), entry.getValue()));
            }
        }
        return result;
    }

    private static List<PicklistOption> defaultSubjects() {
        return new List<PicklistOption>{
            new PicklistOption('Call', 'Call'),
            new PicklistOption('Send Letter', 'Send Letter'),
            new PicklistOption('Send Quote', 'Send Quote'),
            new PicklistOption('Delegation Task', 'Delegation Task'),
            new PicklistOption('Checklist Task', 'Checklist Task'),
            new PicklistOption('Help Ticket', 'Help Ticket'),
            new PicklistOption('Reminder', 'Reminder'),
            new PicklistOption('Follow-up Task', 'Follow-up Task'),
            new PicklistOption('Other', 'Other')
        };
    }

    private static List<PicklistOption> defaultVisitStatuses() {
        return new List<PicklistOption>{
            new PicklistOption('Scheduled', 'Scheduled'),
            new PicklistOption('Completed', 'Completed')
        };
    }

    private static List<PicklistOption> defaultVisitTypes() {
        return new List<PicklistOption>{
            new PicklistOption('Offline', 'Offline'),
            new PicklistOption('Virtual', 'Virtual')
        };
    }

    private static Datetime parseClientDateTime(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return (Datetime) JSON.deserialize('"' + value + '"', Datetime.class);
        } catch (Exception e1) {
            try {
                String normalized = value.replace('T', ' ').replace('Z', '');
                if (normalized.length() == 16) {
                    normalized += ':00';
                } else if (normalized.length() > 19) {
                    normalized = normalized.substring(0, 19);
                }
                return Datetime.valueOf(normalized);
            } catch (Exception e2) {
                return null;
            }
        }
    }

    private static Date parseClientDate(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return Date.valueOf(value.substring(0, Math.min(10, value.length())));
        } catch (Exception e) {
            return null;
        }
    }

    private static void assertQuoteAccessibleForPartner(Id quoteId, Id partnerAccountId) {
        Id partnerId = resolvePartnerAccountId(null, partnerAccountId);
        if (partnerId == null) {
            throw new AuraHandledException('Channel Partner account could not be resolved.');
        }
        List<Quote> quotes = [
            SELECT Id
            FROM Quote
            WHERE Id = :quoteId
              AND (
                   AccountId = :partnerId
                OR QuoteAccountId = :partnerId
                OR Account__c = :partnerId
                OR OwnerId = :UserInfo.getUserId()
                OR Account.Channel_Partner_Name__c = :partnerId
                OR Account.Channel_Partner__c = :partnerId
                OR QuoteAccount.Channel_Partner_Name__c = :partnerId
                OR QuoteAccount.Channel_Partner__c = :partnerId
                OR Account__r.Channel_Partner_Name__c = :partnerId
                OR Account__r.Channel_Partner__c = :partnerId
                OR Contact.Account.Channel_Partner_Name__c = :partnerId
                OR Contact.Account.Channel_Partner__c = :partnerId
                OR Contact.AccountId = :partnerId
              )
            LIMIT 1
        ];
        if (quotes.isEmpty()) {
            throw new AuraHandledException('Unauthorised quote operation.');
        }
    }

    private static Id resolveQuoteAccountId(Id quoteId) {
        List<Quote> quotes = [
            SELECT QuoteAccountId, AccountId, Account__c
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
        if (quotes.isEmpty()) {
            return null;
        }
        Quote q = quotes[0];
        return q.QuoteAccountId != null
            ? q.QuoteAccountId
            : (q.Account__c != null ? q.Account__c : q.AccountId);
    }
}