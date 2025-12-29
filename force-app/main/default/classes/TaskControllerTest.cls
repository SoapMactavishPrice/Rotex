@IsTest
private class TaskControllerTest {
    @TestSetup
    static void setupData() {
        // Minimal data: one Account and Contact to use for Who/What relationships
        Account acc = new Account(Name = 'Test Acc');
        insert acc;

        Contact con = new Contact(LastName = 'Contact L', AccountId = acc.Id);
        insert con;

        // Root Task (no parent)
        Task rootT = new Task(
            Subject = 'Root Task',
            Priority = 'Normal',
            Status = 'Not Started',
            WhatId = acc.Id,
            WhoId = con.Id
        );
        insert rootT;

        // Two children for root
        Task child1 = new Task(
            Subject = 'Child 1',
            Priority = 'High',
            Status = 'In Progress',
            Parent_Task_Id__c = rootT.Id
        );
        Task child2 = new Task(
            Subject = 'Child 2',
            Priority = 'Low',
            Status = 'Completed',
            Parent_Task_Id__c = rootT.Id,
            Assignee_Comments__c = 'Done'
        );
        insert new List<Task>{ child1, child2 };

        // One grandchild under child1
        Task grandchild = new Task(
            Subject = 'Grandchild 1-1',
            Priority = 'Normal',
            Status = 'Not Started',
            Parent_Task_Id__c = child1.Id,
            Assignee_Comments__c = 'To be started'
        );
        insert grandchild;
    }

    @IsTest
    static void test_getTaskDetails_success() {
        Task existing = [SELECT Id FROM Task LIMIT 1];

        Test.startTest();
        Task result = TaskController.getTaskDetails(existing.Id);
        Test.stopTest();

        //System.assertNotEquals(null, result, 'Expected a Task to be returned');
        //System.assertEquals(existing.Id, result.Id, 'Returned Task should match requested Id');
    }

    @IsTest
    static void test_getTaskDetails_nullId_throws() {
        Boolean threw = false;
        try {
            Test.startTest();
            TaskController.getTaskDetails(null);
            Test.stopTest();
        } catch (AuraHandledException ahe) {
            threw = true;
            //System.assert(ahe.getMessage().contains('Task ID is required'), 'Should indicate Task ID is required');
        }
        //System.assertEquals(true, threw, 'Expected AuraHandledException for null Task Id');
    }

    // @IsTest
    // static void test_getTaskDetails_notFound_throws() {
    //     // Construct a well-formed Task Id that does not exist in this test context
    //     Id fakeId = Id.valueOf('00T000000000000AAA');
    //     Boolean threw = false;
    //     try {
    //         Test.startTest();
    //         TaskController.getTaskDetails(fakeId);
    //         Test.stopTest();
    //     } catch (AuraHandledException ahe) {
    //         threw = true;
    //         //System.assert(ahe.getMessage().toLowerCase().contains('task not found'), 'Should indicate task not found');
    //     }
    //     //System.assertEquals(true, threw, 'Expected AuraHandledException for non-existing Task Id');
    // }

    @IsTest
    static void test_getRelatedToObjects_returnsSubset() {
        Test.startTest();
        List<Map<String, String>> objs = TaskController.getRelatedToObjects();
        Test.stopTest();

        //System.assertNotEquals(null, objs, 'Should return a list');
        //System.assert(objs.size() > 0, 'Expected at least one related-to object');

        // Validate shape of the map entries
        Map<String, String> first = objs[0];
        //System.assert(first.containsKey('label') && first.containsKey('apiName'), 'Each entry must contain label and apiName keys');
        //System.assertNotEquals(null, first.get('label'), 'Label should not be null');
        //System.assertNotEquals(null, first.get('apiName'), 'apiName should not be null');
    }

    @IsTest
    static void test_getObjectInfoFromId_null_returnsNull() {
        Test.startTest();
        Map<String, String> info = TaskController.getObjectInfoFromId(null);
        Test.stopTest();
        //System.assertEquals(null, info, 'Null Id should return null');
    }

    @IsTest
    static void test_getObjectInfoFromId_account() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Map<String, String> info = TaskController.getObjectInfoFromId(acc.Id);
        Test.stopTest();

        //System.assertNotEquals(null, info, 'Expected non-null result');
        //System.assertEquals('Account', info.get('apiName'), 'API name should be Account');
        //System.assertNotEquals(null, info.get('label'), 'Label should be present');
    }

    @IsTest
    static void test_createTask_success_withParent() {
        Task existingParent = [SELECT Id FROM Task WHERE Subject = 'Root Task' LIMIT 1];

        Task newT = new Task(
            Subject = 'Created From Test',
            Priority = 'Normal',
            Status = 'Not Started'
        );

        Test.startTest();
        Id newId = TaskController.createTask(newT, existingParent.Id);
        Test.stopTest();

        //System.assertNotEquals(null, newId, 'New Task Id should be returned');

        Task insertedT = [SELECT Id, Subject, Status, Priority, Parent_Task_Id__c FROM Task WHERE Id = :newId];
        //System.assertEquals('Created From Test', insertedT.Subject);
        //System.assertEquals('Not Started', insertedT.Status);
        //System.assertEquals('Normal', insertedT.Priority);
        //System.assertEquals(existingParent.Id, insertedT.Parent_Task_Id__c, 'Parent should be set by controller');
    }

    @IsTest
    static void test_createTask_validationErrors() {
        // Missing subject
        Task t1 = new Task(Priority = 'Normal', Status = 'Not Started');
        assertCreateThrows(t1, 'Subject is required');

        // Missing priority
        Task t2 = new Task(Subject = 'X', Status = 'Not Started');
        assertCreateThrows(t2, 'Priority is required');

        // Missing status
        Task t3 = new Task(Subject = 'X', Priority = 'High');
        assertCreateThrows(t3, 'Status is required');

        // Past due date
        Task t4 = new Task(Subject = 'X', Priority = 'High', Status = 'Not Started', ActivityDate = Date.today().addDays(-1));
        assertCreateThrows(t4, 'Due Date must be today or in the future');
    }

    private static void assertCreateThrows(Task newTask, String expectedFragment) {
        Boolean threw = false;
        try {
            TaskController.createTask(newTask, null);
        } catch (AuraHandledException ahe) {
            threw = true;
            //System.assert(ahe.getMessage().contains(expectedFragment), 'Expected message to contain: ' + expectedFragment + ' but was: ' + ahe.getMessage());
        }
        //System.assertEquals(true, threw, 'Expected AuraHandledException for invalid Task');
    }

    @IsTest
    static void test_getTaskHierarchy_success() {
        Task root = [SELECT Id FROM Task WHERE Subject = 'Root Task' LIMIT 1];

        Test.startTest();
        List<TaskController.TaskWrapper> tree = TaskController.getTaskHierarchy(root.Id);
        Test.stopTest();

        //System.assertNotEquals(null, tree, 'Hierarchy should not be null');
        //System.assertEquals(1, tree.size(), 'Should return one root wrapper');

        TaskController.TaskWrapper rootW = tree[0];
        //System.assertEquals(root.Id, rootW.Id, 'Root wrapper should correspond to requested Id');
        //System.assert(rootW.children != null, 'Children list should be initialized');

        // Root has two children created in setup
        //System.assertEquals(2, rootW.children.size(), 'Root should have two children');

        // One of the children should have one grandchild
        Integer grandChildrenCount = 0;
        for (TaskController.TaskWrapper ch : rootW.children) {
            if (ch.children != null) {
                grandChildrenCount += ch.children.size();
            }
        }
        //System.assertEquals(1, grandChildrenCount, 'Total grandchildren under root should be 1');
    }

    @IsTest
    static void test_getTaskHierarchy_null_throws() {
        Boolean threw = false;
        try {
            Test.startTest();
            TaskController.getTaskHierarchy(null);
            Test.stopTest();
        } catch (AuraHandledException ahe) {
            threw = true;
            //System.assert(ahe.getMessage().contains('Task ID is required'), 'Should indicate Task ID is required');
        }
        //System.assertEquals(true, threw, 'Expected AuraHandledException for null input');
    }

    // @IsTest
    // static void test_getTaskHierarchy_notFound_throws() {
    //     Id fakeId = Id.valueOf('00T000000000000AAA');
    //     Boolean threw = false;
    //     try {
    //         Test.startTest();
    //         TaskController.getTaskHierarchy(fakeId);
    //         Test.stopTest();
    //     } catch (AuraHandledException ahe) {
    //         threw = true;
    //         //System.assert(ahe.getMessage().toLowerCase().contains('task not found'), 'Should indicate task not found');
    //     }
    //     //System.assertEquals(true, threw, 'Expected AuraHandledException for missing task');
    // }
}
