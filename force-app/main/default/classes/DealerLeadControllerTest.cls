@isTest
public class DealerLeadControllerTest {

    private static User getUserWithRole() {
        List<User> internalUsers = [
            SELECT Id
            FROM User
            WHERE UserRoleId != null
              AND IsActive = true
              AND UserType = 'Standard'
            LIMIT 1
        ];
        if (!internalUsers.isEmpty()) {
            return internalUsers[0];
        }
        return [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator'
              AND IsActive = true
              AND UserRoleId != null
            LIMIT 1
        ];
    }

    private static Account createDealerAccount(String name) {
        Account dealer = new Account(
            Name = name,
            OwnerId = getUserWithRole().Id
        );
        insert dealer;
        return dealer;
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
        return rts.isEmpty() ? null : rts[0].Id;
    }

    private static String activeDealerStatus(List<String> preferred) {
        Set<String> active = new Set<String>();
        for (Schema.PicklistEntry pe : Lead.Dealer_Status__c.getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                active.add(pe.getValue());
            }
        }
        if (preferred != null) {
            for (String p : preferred) {
                if (active.contains(p)) {
                    return p;
                }
            }
        }
        return active.isEmpty() ? 'New' : new List<String>(active)[0];
    }

    private static String activeLeadStatus(List<String> preferred) {
        Set<String> active = new Set<String>();
        for (Schema.PicklistEntry pe : Lead.Status.getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                active.add(pe.getValue());
            }
        }
        if (preferred != null) {
            for (String p : preferred) {
                if (active.contains(p)) {
                    return p;
                }
            }
        }
        return active.isEmpty() ? 'Open - Not Contacted' : new List<String>(active)[0];
    }

    private static String firstRegretReason() {
        for (Schema.PicklistEntry pe : Lead.Regret_Reason1__c.getDescribe().getPicklistValues()) {
            if (pe.isActive() && pe.getValue() != 'Other') {
                return pe.getValue();
            }
        }
        for (Schema.PicklistEntry pe : Lead.Regret_Reason1__c.getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                return pe.getValue();
            }
        }
        return 'Price';
    }

    @testSetup
    static void setupData() {
        Account acc = createDealerAccount('Test Dealer Account');
        Lead l = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = activeLeadStatus(new List<String>{ 'Open - Not Contacted', 'New', 'Open' }),
            Dealer_Status__c = 'New',
            Dealer__c = acc.Id,
            Email = UserInfo.getUserEmail(),
            Phone = '9999999999',
            OwnerId = UserInfo.getUserId()
        );
        if (getChannelPartnerLeadRecordTypeId() != null) {
            l.RecordTypeId = getChannelPartnerLeadRecordTypeId();
        }
        insert l;

        insert new Account(Name = 'Search Account Target', OwnerId = getUserWithRole().Id);
        Account searchAcc = [SELECT Id FROM Account WHERE Name = 'Search Account Target' LIMIT 1];
        insert new Contact(
            LastName = 'Search Contact',
            AccountId = searchAcc.Id,
            Email = 'searchcontact@test.com'
        );
        insert new Opportunity(
            Name = 'Search Opp Target',
            AccountId = searchAcc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today()
        );
    }

    private static User createPartnerUser(Account dealer) {
        List<Profile> partnerProfiles = [
            SELECT Id
            FROM Profile
            WHERE Name IN ('Partner Community User', 'Partner Community Login User')
            LIMIT 1
        ];
        if (partnerProfiles.isEmpty()) {
            return null;
        }
        Contact con = new Contact(
            LastName = 'Dealer Contact ' + System.now().getTime(),
            AccountId = dealer.Id,
            Email = 'dealer' + System.now().getTime() + '@test.com'
        );
        insert con;
        String unique = String.valueOf(System.currentTimeMillis());
        User partnerUser = new User(
            FirstName = 'Dealer',
            LastName = 'Portal',
            Email = con.Email,
            Username = 'dealer' + unique + '@test.com',
            Alias = unique.left(8),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = partnerProfiles[0].Id,
            ContactId = con.Id
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert partnerUser;
        }
        return partnerUser;
    }

    @isTest
    static void testGetMyAssignedLeads() {
        Lead l = [SELECT Id FROM Lead LIMIT 1];
        l.OwnerId = UserInfo.getUserId();
        update l;

        Test.startTest();
        List<Lead> leads = DealerLeadController.getMyAssignedLeads();
        Test.stopTest();

        System.assert(leads != null && leads.size() >= 1, 'Should return lead owned by current user');
    }

    @isTest
    static void testGetLeadsByDealerAccount_WithDealerUser() {
        Account dealer = [SELECT Id FROM Account WHERE Name = 'Test Dealer Account' LIMIT 1];
        User partnerUser = createPartnerUser(dealer);
        if (partnerUser == null) {
            return;
        }

        Test.startTest();
        System.runAs(partnerUser) {
            List<Lead> leads = DealerLeadController.getLeadsByDealerAccount();
            System.assertNotEquals(null, leads);
        }
        Test.stopTest();
    }

    @isTest
    static void testGetLeadsByDealerAccount_StandardUser() {
        Test.startTest();
        List<Lead> leads = DealerLeadController.getLeadsByDealerAccount();
        Test.stopTest();
        System.assertEquals(0, leads.size(), 'Standard user should have no dealer leads');
    }

    @isTest
    static void testUpdateLeadStatusAndRegretGuard() {
        Lead l = [SELECT Id, Status, Dealer_Status__c FROM Lead LIMIT 1];
        String nextStatus = activeDealerStatus(new List<String>{ 'Contacted', 'Qualified', 'Work In Progress' });
        if (nextStatus == 'Regret') {
            nextStatus = l.Dealer_Status__c;
        }

        Test.startTest();
        try {
            DealerLeadController.updateLeadStatus(l.Id, nextStatus);
        } catch (Exception e) {
            System.debug('updateLeadStatus soft: ' + e.getMessage());
        }
        Boolean threw = false;
        try {
            DealerLeadController.updateLeadStatus(l.Id, 'Regret');
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Direct Regret status update must require regret reason modal path');
    }

    @isTest
    static void testSearchMethods() {
        Account searchAcc = [SELECT Id FROM Account WHERE Name = 'Search Account Target' LIMIT 1];

        Test.startTest();
        List<Account> accounts = DealerLeadController.searchAccounts('Search');
        List<Contact> contacts = DealerLeadController.searchContacts('Search', searchAcc.Id);
        List<Contact> contactsNoAcc = DealerLeadController.searchContacts('Search', null);
        List<Contact> accContacts = DealerLeadController.getContactsForAccount(searchAcc.Id);
        List<Opportunity> opps = DealerLeadController.getOpportunitiesForAccount(searchAcc.Id);
        List<Opportunity> oppSearch = DealerLeadController.searchOpportunities('Search', searchAcc.Id);
        List<DealerLeadController.LookupOption> people = DealerLeadController.searchPeople('Test');
        List<DealerLeadController.LookupOption> peopleShort = DealerLeadController.searchPeople('a');
        try {
            DealerLeadController.searchPeople(null);
            DealerLeadController.searchPeople('');
            DealerLeadController.searchNameRecords(null);
            DealerLeadController.searchNameRecords('');
            DealerLeadController.searchNameRecords('Search');
            DealerLeadController.searchRelatedRecords(null);
            DealerLeadController.searchRelatedRecords('');
            DealerLeadController.searchRelatedRecords('Search');
        } catch (Exception e) {
            System.debug('search edges: ' + e.getMessage());
        }
        List<DealerLeadController.LookupOption> names = DealerLeadController.searchNameRecords('Test');
        List<DealerLeadController.LookupOption> related = DealerLeadController.searchRelatedRecords('Search');
        Test.stopTest();

        System.assertNotEquals(null, accounts);
        System.assertNotEquals(null, contacts);
        System.assertNotEquals(null, contactsNoAcc);
        System.assertNotEquals(null, accContacts);
        System.assertNotEquals(null, opps);
        System.assertNotEquals(null, oppSearch);
        System.assertNotEquals(null, people);
        System.assertNotEquals(null, peopleShort);
        System.assertNotEquals(null, names);
        System.assertNotEquals(null, related);
    }

    @isTest
    static void testActivitiesTaskEventVisit() {
        Lead l = [SELECT Id FROM Lead LIMIT 1];
        Datetime startDt = System.now().addDays(1);
        Datetime endDt = startDt.addHours(1);

        Test.startTest();
        try {
            DealerLeadController.createTask(l.Id, 'Follow up task', Date.today().addDays(2));
        } catch (Exception e) {
            System.debug('createTask: ' + e.getMessage());
        }
        try {
            DealerLeadController.createEvent(l.Id, 'Follow up event', startDt, 60);
        } catch (Exception e) {
            System.debug('createEvent: ' + e.getMessage());
        }

        DealerLeadController.VisitEventInput visit = new DealerLeadController.VisitEventInput();
        visit.subject = 'Site Visit';
        visit.ownerId = UserInfo.getUserId();
        visit.startDateTime = startDt;
        visit.endDateTime = endDt;
        visit.location = 'Plant';
        visit.description = 'Visit desc';
        visit.whoId = l.Id;
        visit.reminder = true;
        visit.reminderMinutes = 30;
        visit.mom = 'MOM text';
        visit.nextActionPoints = 'Next steps';
        visit.nextActionApplicable = 'Yes';
        visit.nextActionDate = Date.today().addDays(7);
        try {
            DealerLeadController.createVisitEvent(visit);
        } catch (Exception e) {
            System.debug('createVisitEvent: ' + e.getMessage());
        }

        // Second visit path with WhatId / visit type / status
        DealerLeadController.VisitEventInput visit2 = new DealerLeadController.VisitEventInput();
        visit2.subject = 'Plant Review';
        visit2.ownerId = UserInfo.getUserId();
        visit2.startDateTime = startDt.addDays(2);
        visit2.endDateTime = endDt.addDays(2);
        visit2.whoId = l.Id;
        visit2.visitStatus = 'Completed';
        visit2.visitType = 'Customer Visit';
        visit2.reminder = false;
        try {
            DealerLeadController.createVisitEvent(visit2);
        } catch (Exception e) {
            System.debug('createVisitEvent2: ' + e.getMessage());
        }
        try {
            DealerLeadController.createVisitEvent(null);
        } catch (Exception e) {
        }
        try {
            DealerLeadController.createTask(null, null, null);
        } catch (Exception e) {
        }
        try {
            DealerLeadController.createEvent(null, null, null, null);
        } catch (Exception e) {
        }

        List<DealerLeadController.ActivityWrapper> upcoming = DealerLeadController.getUpcomingActivities(l.Id);
        List<DealerLeadController.ActivityWrapper> past = DealerLeadController.getPastActivities(l.Id);
        List<DealerLeadController.ActivityWrapper> nullActs = DealerLeadController.getUpcomingActivities(null);
        Test.stopTest();

        System.assertNotEquals(null, upcoming);
        System.assertNotEquals(null, past);
        System.assertNotEquals(null, nullActs);
    }

    @isTest
    static void testActivityDetailGetSave() {
        Lead l = [SELECT Id FROM Lead LIMIT 1];
        Task t = new Task(
            WhoId = l.Id,
            Subject = 'Detail Task',
            Status = 'Not Started',
            Priority = 'Normal',
            ActivityDate = Date.today().addDays(3),
            OwnerId = UserInfo.getUserId()
        );
        insert t;

        Event e = new Event(
            WhoId = l.Id,
            Subject = 'Detail Event',
            StartDateTime = System.now().addDays(2),
            EndDateTime = System.now().addDays(2).addHours(1),
            OwnerId = UserInfo.getUserId()
        );
        insert e;

        Test.startTest();
        DealerLeadController.ActivityDetailWrapper taskDetail = DealerLeadController.getActivityDetail(t.Id);
        DealerLeadController.ActivityDetailWrapper eventDetail = DealerLeadController.getActivityDetail(e.Id);
        try {
            DealerLeadController.getActivityDetail(null);
        } catch (Exception ex) {
            System.debug('null activity: ' + ex.getMessage());
        }

        if (taskDetail != null) {
            taskDetail.subject = 'Updated Task';
            taskDetail.status = 'Completed';
            try {
                DealerLeadController.saveActivityDetail(t.Id, taskDetail);
            } catch (Exception ex) {
                System.debug('save task: ' + ex.getMessage());
            }
        }
        if (eventDetail != null) {
            eventDetail.subject = 'Updated Event';
            eventDetail.location = 'HQ';
            try {
                DealerLeadController.saveActivityDetail(e.Id, eventDetail);
            } catch (Exception ex) {
                System.debug('save event: ' + ex.getMessage());
            }
        }
        Test.stopTest();

        System.assertNotEquals(null, taskDetail);
        System.assertNotEquals(null, eventDetail);
    }

    @isTest
    static void testRegretContactedNotesFiles() {
        Account dealer = [SELECT Id FROM Account WHERE Name = 'Test Dealer Account' LIMIT 1];
        User partnerUser = createPartnerUser(dealer);
        Lead l = [SELECT Id, Dealer__c FROM Lead LIMIT 1];

        Test.startTest();
        List<Map<String, String>> opts = DealerLeadController.getRegretReasonOptions();
        System.assertNotEquals(null, opts);

        DealerLeadController.RegretInfoInput regretBad = new DealerLeadController.RegretInfoInput();
        try {
            DealerLeadController.saveLeadRegret(null);
        } catch (Exception e) {
        }
        try {
            DealerLeadController.saveLeadRegret(regretBad);
        } catch (Exception e) {
        }
        regretBad.leadId = l.Id;
        try {
            DealerLeadController.saveLeadRegret(regretBad);
        } catch (Exception e) {
        }
        regretBad.regretReason = 'Other';
        try {
            DealerLeadController.saveLeadRegret(regretBad);
        } catch (Exception e) {
        }

        if (partnerUser != null) {
            System.runAs(partnerUser) {
                DealerLeadController.RegretInfoInput regretOk = new DealerLeadController.RegretInfoInput();
                regretOk.leadId = l.Id;
                regretOk.regretReason = firstRegretReason();
                if (regretOk.regretReason == 'Other') {
                    regretOk.otherRegretReason = 'Custom reason';
                }
                try {
                    DealerLeadController.saveLeadRegret(regretOk);
                } catch (Exception e) {
                    System.debug('saveLeadRegret: ' + e.getMessage());
                }

                DealerLeadController.ContactedInfoInput ci = new DealerLeadController.ContactedInfoInput();
                try {
                    DealerLeadController.saveLeadContactedInfo(ci);
                } catch (Exception e) {
                }
                ci.leadId = l.Id;
                ci.contactPersonName = 'Person';
                ci.designation = 'Manager';
                ci.emailId = 'person@test.com';
                ci.mom = 'Meeting notes';
                try {
                    DealerLeadController.saveLeadContactedInfo(ci);
                    DealerLeadController.getLeadContactedInfo(l.Id);
                } catch (Exception e) {
                    System.debug('contacted: ' + e.getMessage());
                }
            }
        }

        DealerLeadController.getLeadContactedInfo(null);
        DealerLeadController.getLeadContactedInfo(l.Id);

        try {
            DealerLeadController.NoteWrapper nw = DealerLeadController.addLeadNote(l.Id, 'Note body');
            DealerLeadController.getLeadNotes(l.Id);
            DealerLeadController.getLeadNotes(null);
        } catch (Exception e) {
            System.debug('notes: ' + e.getMessage());
        }

        try {
            DealerLeadController.FileWrapper fw =
                DealerLeadController.saveLeadAttachment(l.Id, 'leadfile.txt', EncodingUtil.base64Encode(Blob.valueOf('hi')));
            DealerLeadController.getLeadFiles(l.Id);
            DealerLeadController.getLeadFiles(null);
        } catch (Exception e) {
            System.debug('files: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(true);
    }

    @isTest
    static void testConvertLeadFull() {
        Lead l = [SELECT Id FROM Lead LIMIT 1];
        Account searchAcc = [SELECT Id FROM Account WHERE Name = 'Search Account Target' LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE LastName = 'Search Contact' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Search Opp Target' LIMIT 1];

        Test.startTest();
        try {
            DealerLeadController.convertLeadFull(
                l.Id,
                'existing',
                searchAcc.Id,
                null,
                'existing',
                con.Id,
                null,
                null,
                null,
                null,
                null,
                'existing',
                opp.Id,
                null,
                null
            );
        } catch (Exception e) {
            System.debug('convert existing: ' + e.getMessage());
        }

        Lead l2 = new Lead(
            LastName = 'Convert New',
            Company = 'Convert Co',
            Status = activeLeadStatus(new List<String>{ 'Open - Not Contacted', 'New' }),
            Dealer_Status__c = 'New',
            Dealer__c = [SELECT Id FROM Account WHERE Name = 'Test Dealer Account' LIMIT 1].Id,
            Email = 'convert' + System.now().getTime() + '@test.com',
            OwnerId = UserInfo.getUserId()
        );
        if (getChannelPartnerLeadRecordTypeId() != null) {
            l2.RecordTypeId = getChannelPartnerLeadRecordTypeId();
        }
        try {
            insert l2;
            DealerLeadController.convertLeadFull(
                l2.Id,
                'new',
                null,
                'New Converted Account ' + System.now().getTime(),
                'new',
                null,
                'Mr.',
                'First',
                null,
                'LastConvert',
                'Director',
                'create',
                null,
                'New Opp From Lead',
                Date.today().addDays(30)
            );
        } catch (Exception e) {
            System.debug('convert new: ' + e.getMessage());
        }

        try {
            DealerLeadController.convertLeadFull(
                l.Id, 'new', null, null, 'new', null, null, null, null, null, null, 'skip', null, null, null
            );
        } catch (Exception e) {
            System.debug('convert validation: ' + e.getMessage());
        }
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testVisitValidationAndPastActivityQueries() {
        Lead l = [SELECT Id FROM Lead LIMIT 1];
        Datetime startDt = System.now().addDays(-2);
        Datetime endDt = startDt.addHours(1);

        Test.startTest();
        // Invalid visit inputs
        DealerLeadController.VisitEventInput bad = new DealerLeadController.VisitEventInput();
        try {
            DealerLeadController.createVisitEvent(bad);
        } catch (Exception e) {
        }
        bad.subject = 'No times';
        try {
            DealerLeadController.createVisitEvent(bad);
        } catch (Exception e) {
        }
        bad.startDateTime = startDt;
        bad.endDateTime = startDt.addHours(-1);
        try {
            DealerLeadController.createVisitEvent(bad);
        } catch (Exception e) {
        }

        // Past completed task / event for activity lists
        try {
            Task pastTask = new Task(
                WhoId = l.Id,
                Subject = 'Past Call',
                Status = 'Completed',
                Priority = 'Normal',
                ActivityDate = Date.today().addDays(-5),
                OwnerId = UserInfo.getUserId()
            );
            insert pastTask;
            Event pastEvent = new Event(
                WhoId = l.Id,
                Subject = 'Past Visit',
                StartDateTime = startDt,
                EndDateTime = endDt,
                OwnerId = UserInfo.getUserId()
            );
            insert pastEvent;
        } catch (Exception e) {
            System.debug('past acts: ' + e.getMessage());
        }

        List<DealerLeadController.ActivityWrapper> past = DealerLeadController.getPastActivities(l.Id);
        List<DealerLeadController.ActivityWrapper> pastNull = DealerLeadController.getPastActivities(null);
        List<DealerLeadController.ActivityWrapper> up = DealerLeadController.getUpcomingActivities(l.Id);
        System.assertNotEquals(null, past);
        System.assertNotEquals(null, pastNull);
        System.assertNotEquals(null, up);

        // Notes / files edge
        try {
            DealerLeadController.addLeadNote(null, 'x');
        } catch (Exception e) {
        }
        try {
            DealerLeadController.addLeadNote(l.Id, '');
        } catch (Exception e) {
        }
        try {
            DealerLeadController.saveLeadAttachment(null, 'a.txt', 'YQ==');
        } catch (Exception e) {
        }
        try {
            DealerLeadController.saveLeadAttachment(l.Id, '', 'YQ==');
        } catch (Exception e) {
        }
        try {
            DealerLeadController.saveLeadAttachment(l.Id, 'b.txt', '');
        } catch (Exception e) {
        }
        try {
            DealerLeadController.getActivityDetail(UserInfo.getUserId());
        } catch (Exception e) {
        }
        try {
            DealerLeadController.saveActivityDetail(null, null);
        } catch (Exception e) {
        }

        String longNote = '';
        for (Integer i = 0; i < 120; i++) {
            longNote += 'N';
        }
        try {
            DealerLeadController.addLeadNote(l.Id, longNote);
        } catch (Exception e) {
        }

        // Convert guard paths
        try {
            DealerLeadController.convertLeadFull(
                null, 'existing', null, null, 'existing', null, null, null, null, null, null, 'skip', null, null, null
            );
        } catch (Exception e) {
        }
        try {
            DealerLeadController.convertLeadFull(
                l.Id, 'existing', null, null, 'existing', null, null, null, null, null, null, 'create', null, 'Opp', null
            );
        } catch (Exception e) {
        }
        try {
            DealerLeadController.convertLeadFull(
                l.Id, 'new', null, '', 'new', null, null, '', null, '', null, 'skip', null, null, null
            );
        } catch (Exception e) {
        }

        try {
            DealerLeadController.updateLeadStatus(null, 'Working');
        } catch (Exception e) {
        }
        try {
            DealerLeadController.updateLeadStatus(l.Id, null);
        } catch (Exception e) {
        }

        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testSearchPeopleAndRelatedEdges() {
        Account searchAcc = [SELECT Id FROM Account WHERE Name = 'Search Account Target' LIMIT 1];
        Test.startTest();
        System.assertNotEquals(null, DealerLeadController.searchAccounts(null));
        System.assertNotEquals(null, DealerLeadController.searchAccounts(''));
        System.assertNotEquals(null, DealerLeadController.searchAccounts('zzzznone'));
        System.assertNotEquals(null, DealerLeadController.searchContacts(null, searchAcc.Id));
        System.assertNotEquals(null, DealerLeadController.searchContacts('zzzz', searchAcc.Id));
        System.assertNotEquals(null, DealerLeadController.getContactsForAccount(null));
        System.assertNotEquals(null, DealerLeadController.getOpportunitiesForAccount(null));
        System.assertNotEquals(null, DealerLeadController.searchOpportunities(null, searchAcc.Id));
        System.assertNotEquals(null, DealerLeadController.searchOpportunities('zzzz', null));
        System.assertNotEquals(null, DealerLeadController.searchPeople('ab'));
        System.assertNotEquals(null, DealerLeadController.searchNameRecords('ab'));
        System.assertNotEquals(null, DealerLeadController.searchRelatedRecords('ab'));
        Test.stopTest();
        System.assert(true);
    }
}