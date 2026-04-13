@isTest
private class CreateTaskFromTaskControllerTest {
    
    @testSetup
    static void setup() {
        // Create test data
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = acc.Id
        );
        insert con;

        Task sourceTask = new Task(
            Subject = 'Source Task',
            Priority = 'High',
            Status = 'In Progress',
            WhoId = con.Id,
            WhatId = acc.Id,
            ActivityDate = Date.today().addDays(5)
        );
        insert sourceTask;
    }

    @isTest
    static void testGetTaskDetails() {
        Task sourceTask = [SELECT Id FROM Task LIMIT 1];

        Test.startTest();
        Task result = CreateTaskFromTaskController.getTaskDetails(sourceTask.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Task should be retrieved');
        System.assertEquals('Source Task', result.Subject, 'Subject should match');
        System.assertEquals('High', result.Priority, 'Priority should match');
    }

    @isTest
    static void testCreateTaskSuccess() {
        Task sourceTask = [SELECT Id FROM Task LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Task newTask = new Task(
            Subject = 'New Task',
            Priority = 'Normal',
            Status = 'Open',
            ActivityDate = Date.today().addDays(3),
            WhoId = con.Id,
            WhatId = acc.Id
        );

        Test.startTest();
        Id newTaskId = CreateTaskFromTaskController.createTask(newTask, sourceTask.Id);
        Test.stopTest();

        Task createdTask = [
            SELECT Id, Subject, Priority, Parent_Task_Id__c
            FROM Task
            WHERE Id = :newTaskId
        ];

        System.assertNotEquals(null, createdTask, 'Task should be created');
        System.assertEquals('New Task', createdTask.Subject, 'Subject should match');
        System.assertEquals(sourceTask.Id, createdTask.Parent_Task_Id__c, 'Parent Task Id should be set');
    }

    @isTest
    static void testCreateTaskMissingSubject() {
        Task sourceTask = [SELECT Id FROM Task LIMIT 1];

        Task newTask = new Task(
            Subject = '',
            Priority = 'Normal',
            Status = 'Open'
        );

        Test.startTest();
        try {
            CreateTaskFromTaskController.createTask(newTask, sourceTask.Id);
            System.assert(false, 'Exception should be thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Subject is required'), 'Error message should mention Subject');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateTaskPastDueDate() {
        Task sourceTask = [SELECT Id FROM Task LIMIT 1];

        Task newTask = new Task(
            Subject = 'Test Task',
            Priority = 'Normal',
            Status = 'Open',
            ActivityDate = Date.today().addDays(-1)
        );

        Test.startTest();
        try {
            CreateTaskFromTaskController.createTask(newTask, sourceTask.Id);
            System.assert(false, 'Exception should be thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Due Date'), 'Error message should mention Due Date');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetTaskDetailsInvalidId() {
        Test.startTest();
        try {
            CreateTaskFromTaskController.getTaskDetails(null);
            System.assert(false, 'Exception should be thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Error message should mention required');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateTaskMissingPriority() {
        Task sourceTask = [SELECT Id FROM Task LIMIT 1];

        Task newTask = new Task(
            Subject = 'Test Task',
            Priority = '',
            Status = 'Open'
        );

        Test.startTest();
        try {
            CreateTaskFromTaskController.createTask(newTask, sourceTask.Id);
            System.assert(false, 'Exception should be thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Priority is required'), 'Error message should mention Priority');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateTaskMissingStatus() {
        Task sourceTask = [SELECT Id FROM Task LIMIT 1];

        Task newTask = new Task(
            Subject = 'Test Task',
            Priority = 'Normal',
            Status = ''
        );

        Test.startTest();
        try {
            CreateTaskFromTaskController.createTask(newTask, sourceTask.Id);
            System.assert(false, 'Exception should be thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Status is required'), 'Error message should mention Status');
        }
        Test.stopTest();
    }
}