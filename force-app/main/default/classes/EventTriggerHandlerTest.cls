@IsTest
private class EventTriggerHandlerTest {
    
    @IsTest
    static void testEventCompletionLinksTargetAndIncrementsCount() {
        
        // Create Account (Customer)
        Account acc = new Account(Name = 'Test Customer');
        insert acc;
        
        // Sales Rep = current user
        Id salesRepId = UserInfo.getUserId();
        
        // Create Target__c record
        Target__c tgt = new Target__c(
            Sales_Rep__c = salesRepId,
            Customer_Name__c = acc.Id,
            Actual_Visits_Per_Year__c = 0
        );
        insert tgt;
        
        // Create Event #1 (not completed initially)
        Event evt1 = new Event(
            Subject = 'Visit 1',
            Visit_Status__c = 'Scheduled',
            OwnerId = salesRepId,
            WhatId = acc.Id,
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1)
        );
        insert evt1;
        
        // Create Event #2 (not completed initially)
        Event evt2 = new Event(
            Subject = 'Visit 2',
            Visit_Status__c = 'Scheduled',
            OwnerId = salesRepId,
            WhatId = acc.Id,
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1)
        );
        insert evt2;
        
        // Run trigger actions inside single test block
        Test.startTest();
        
        evt1.Visit_Status__c = 'Completed';
        evt1.MOM__c = 'text';
        evt2.Visit_Status__c = 'Completed';
        evt2.MOM__c = 'text';
        
        update new List<Event>{ evt1, evt2 };
            
            Test.stopTest();
        
        // Reload event 1
        Event evt1After = [
            SELECT Id, Target__c
            FROM Event
            WHERE Id = :evt1.Id
        ];
        System.assertEquals(tgt.Id, evt1After.Target__c, 'Event1 must link to Target');
        
        // Reload event 2
        Event evt2After = [
            SELECT Id, Target__c
            FROM Event
            WHERE Id = :evt2.Id
        ];
        System.assertEquals(tgt.Id, evt2After.Target__c, 'Event2 must link to Target');
        
        // Reload target
        Target__c tgtAfter = [
            SELECT Actual_Visits_Per_Year__c
            FROM Target__c
            WHERE Id = :tgt.Id
        ];
        
        // Expected: 2 visits counted
        System.assertEquals(
            2,
            Integer.valueOf(tgtAfter.Actual_Visits_Per_Year__c),
            'Target visit count must be 2 after two completed events'
        );
    }
}