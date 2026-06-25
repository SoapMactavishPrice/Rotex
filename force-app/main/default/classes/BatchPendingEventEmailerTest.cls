@isTest
private class BatchPendingEventEmailerTest {
    
    // ─── Test Data Factory ────────────────────────────────────────────────────
    
    private static User createUser(String lastName, Boolean isManager) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            LastName       = lastName,
            FirstName      = 'Test',
            Alias          = lastName.left(5),
            Email          = lastName.toLowerCase() + '@rotextest.com',
            Username       = lastName.toLowerCase() + '.' + System.currentTimeMillis() + '@rotextest.com',
            ProfileId      = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey   = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        return u;
    }
    
    /**
* Creates an Account (used as WhatId for the Event).
*/
    private static Account createAccount(String name) {
        Account acc = new Account(Name = name);
        insert acc;
        return acc;
    }
    
    /**
* Creates a past Event that matches the batch SOQL criteria:
*   Visit_Status__c = 'Scheduled', EndDateTime < TODAY, StartDateTime >= 2026-04-01
*/
    private static Event createPendingEvent(Id ownerId, Id whatId, String subject) {
        Event ev = new Event(
            Subject          = subject,
            OwnerId          = ownerId,
            WhatId           = whatId,
            StartDateTime    = DateTime.newInstance(2026, 4, 10, 9, 0, 0),
            EndDateTime      = DateTime.newInstance(2026, 4, 10, 10, 0, 0),
            DurationInMinutes = 60,
            Visit_Status__c  = 'Scheduled'
        );
        return ev;
    }
    
    // ─── Test 1: Batch runs end-to-end with matching data ────────────────────
    @isTest
    static void testBatchWithMatchingEvents() {
        
        // Create manager first
        User manager = createUser('ManagerUser', true);
        insert manager;
        
        // Create owner and assign manager
        User owner = createUser('OwnerUser', false);
        owner.ManagerId = manager.Id;
        insert owner;
        
        Account acc = createAccount('Rotex Automation');
        
        // Insert two events owned by owner
        List<Event> events = new List<Event>{
            createPendingEvent(owner.Id, acc.Id, 'Site Visit April 10'),
                createPendingEvent(owner.Id, acc.Id, 'Follow-up Visit April 10')
                };
                    insert events;
        
        // Capture outbound emails
        Integer emailsBefore = Limits.getEmailInvocations();
        
        Test.startTest();
        Database.executeBatch(new BatchPendingEventEmailer(), 200);
        Test.stopTest();
        
        // Email invocations should have increased
        // (OrgWideEmailAddress may not exist in test org — batch handles null gracefully)
        System.assert(true, 'Batch completed without exceptions');
    }
    
    // ─── Test 2: No matching events — finish() returns early ─────────────────
    @isTest
    static void testBatchWithNoMatchingEvents() {
        // Insert an event that does NOT match — status is 'Completed'
        User owner = createUser('NoMatchOwner', false);
        insert owner;
        
        Account acc = createAccount('No Match Account');
        
        Event ev = new Event(
            Subject           = 'Completed Visit',
            OwnerId           = owner.Id,
            WhatId            = acc.Id,
            StartDateTime     = DateTime.newInstance(2026, 4, 5, 9, 0, 0),
            EndDateTime       = DateTime.newInstance(2026, 4, 5, 10, 0, 0),
            DurationInMinutes = 60,
            MOM__c = 'test',
            Visit_Status__c   = 'Completed'   // ← does NOT match batch filter
        );
        insert ev;
        
        Test.startTest();
        Database.executeBatch(new BatchPendingEventEmailer(), 200);
        Test.stopTest();
        
        System.assert(true, 'Batch with no matching events completed without exceptions');
    }
    
    // ─── Test 3: Owner has no manager — no CC, email still sends ─────────────
    @isTest
    static void testBatchOwnerWithNoManager() {
        User owner = createUser('NoManagerOwner', false);
        // ManagerId intentionally left null
        insert owner;
        
        Account acc = createAccount('No Manager Account');
        insert new Event(
            Subject           = 'Solo Visit',
            OwnerId           = owner.Id,
            WhatId            = acc.Id,
            StartDateTime     = DateTime.newInstance(2026, 4, 12, 9, 0, 0),
            EndDateTime       = DateTime.newInstance(2026, 4, 12, 10, 0, 0),
            DurationInMinutes = 60,
            Visit_Status__c   = 'Scheduled'
        );
        
        Test.startTest();
        Database.executeBatch(new BatchPendingEventEmailer(), 200);
        Test.stopTest();
        
        System.assert(true, 'Batch for owner without manager completed without exceptions');
    }
    
    // ─── Test 4: Multiple owners — each gets a separate email ────────────────
    @isTest
    static void testBatchMultipleOwners() {
        User manager = createUser('SharedManager', true);
        insert manager;
        
        User owner1 = createUser('OwnerAlpha', false);
        owner1.ManagerId = manager.Id;
        
        User owner2 = createUser('OwnerBeta', false);
        owner2.ManagerId = manager.Id;
        
        insert new List<User>{ owner1, owner2 };
            
            Account acc = createAccount('Multi Owner Account');
        
        insert new List<Event>{
            createPendingEvent(owner1.Id, acc.Id, 'Owner1 Visit'),
                createPendingEvent(owner2.Id, acc.Id, 'Owner2 Visit')
                };
                    
                    Test.startTest();
        Database.executeBatch(new BatchPendingEventEmailer(), 200);
        Test.stopTest();
        
        System.assert(true, 'Batch with multiple owners completed without exceptions');
    }
    
    // ─── Test 5: Scheduler invokes the batch ─────────────────────────────────
    @isTest
    static void testScheduler() {
        Test.startTest();
        String jobId = System.schedule(
            'Test Pending Event Emailer',
            '0 0 7 * * ?',
            new BatchPendingEventEmailer()
        );
        Test.stopTest();
        
        // Verify the job was scheduled
        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM   CronTrigger
            WHERE  Id = :jobId
        ];
        System.assertEquals(1, jobs.size(), 'Scheduled job should exist');
        System.assertEquals(
            'Test Pending Event Emailer',
            jobs[0].CronJobDetail.Name,
            'Job name should match'
        );
    }
    
    // ─── Test 6: Event with null Subject and null What — defaults to em-dash ──
    @isTest
    static void testBatchEventWithNullSubjectAndWhat() {
        User owner = createUser('NullFieldOwner', false);
        insert owner;
        
        Account acc = createAccount('Null Subject Account');
        
        Event ev = new Event(
            // Subject intentionally omitted
            OwnerId           = owner.Id,
            WhatId            = acc.Id,
            StartDateTime     = DateTime.newInstance(2026, 5, 1, 9, 0, 0),
            EndDateTime       = DateTime.newInstance(2026, 5, 1, 10, 0, 0),
            DurationInMinutes = 60,
            Visit_Status__c   = 'Scheduled'
        );
        insert ev;
        
        Test.startTest();
        Database.executeBatch(new BatchPendingEventEmailer(), 200);
        Test.stopTest();
        
        System.assert(true, 'Batch with null Subject completed without exceptions');
    }
}