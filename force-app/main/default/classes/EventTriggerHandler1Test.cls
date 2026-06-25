@IsTest
private class EventTriggerHandler1Test {

    @IsTest
    static void testCreateFollowupTask() {

        Account acc = new Account(
            Name = 'Test Customer'
        );
        insert acc;

        Event evt = new Event(
            Subject = 'Customer Visit',
            Visit_Status__c = 'Scheduled',
            OwnerId = UserInfo.getUserId(),
            WhatId = acc.Id,
            Description = 'Visit Discussion',
            Next_Action_Date__c = Date.today().addDays(10),
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1),
            Mom__c = 'Testing'
        );
        insert evt;

        Test.startTest();

        evt.Visit_Status__c = 'Completed';
        update evt;

        Test.stopTest();

        List<Task> tasks = [
            SELECT Id,
                   Subject,
                   OwnerId,
                   Priority,
                   Status,
                   ActivityDate,
                   Description
            FROM Task
            WHERE Subject = 'Customer Visit'
        ];

        System.assertEquals(
            1,
            tasks.size(),
            'One follow-up task should be created'
        );

        Task t = tasks[0];

        System.assertEquals(
            'Customer Visit',
            t.Subject
        );

        System.assertEquals(
            UserInfo.getUserId(),
            t.OwnerId
        );

        System.assertEquals(
            'Normal',
            t.Priority
        );

        System.assertEquals(
            'Open',
            t.Status
        );

        System.assertEquals(
            Date.today().addDays(10),
            t.ActivityDate
        );

        System.assertEquals(
            'Visit Discussion',
            t.Description
        );
    }

    @IsTest
    static void testNoTaskCreatedWhenAlreadyCompleted() {

        Account acc = new Account(
            Name = 'Test Customer 2'
        );
        insert acc;

        Event evt = new Event(
            Subject = 'Completed Visit',
            Visit_Status__c = 'Completed',
            OwnerId = UserInfo.getUserId(),
            WhatId = acc.Id,
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1),
            Mom__c = 'Testing'
        );
        insert evt;

        Test.startTest();

        evt.Subject = 'Completed Visit Updated';
        update evt;

        Test.stopTest();

        Integer taskCount = [
            SELECT Count()
            FROM Task
            WHERE Subject = 'Completed Visit Updated'
        ];

        System.assertEquals(
            0,
            taskCount,
            'No task should be created because status did not change to Completed'
        );
    }
}