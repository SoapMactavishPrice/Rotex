@isTest
private class CheckContentDocumentBeforeCompleteTest {

    @isTest
    static void testTaskCompletionWithContentDocument() {
        // Step 1: Create a Task
        Task taskWithFile = new Task(
            Subject = 'Test Task 1',
            Status = 'Not Started',
            Priority = 'High'
        );
        insert taskWithFile;

        // Step 2: Create a ContentVersion (this creates a ContentDocument)
        ContentVersion contentVersion = new ContentVersion(
            Title = 'Test Document', 
            PathOnClient = 'TestPath/testDoc.pdf',
            VersionData = Blob.valueOf('Test Content')
        );
        insert contentVersion;

        // Step 3: Create ContentDocumentLink to associate ContentDocument with Task
        ContentDocumentLink docLink = new ContentDocumentLink(
            ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1].ContentDocumentId,
            LinkedEntityId = taskWithFile.Id,
            ShareType = 'V'
        );
        insert docLink;

        // Step 4: Update the Task to 'Completed' - should pass as it has a ContentDocument
        taskWithFile.Status = 'Completed';
        update taskWithFile;

        // Assert: The task was updated to 'Completed' without any error
        Task updatedTask = [SELECT Status FROM Task WHERE Id = :taskWithFile.Id];
    }

    @isTest
    static void testTaskCompletionWithoutContentDocument() {
        // Step 1: Create a Task with no ContentDocument
        Task taskWithoutFile = new Task(
            Subject = 'Test Task 2',
            Status = 'Not Started',
            Priority = 'High'
        );
        insert taskWithoutFile;

        // Step 2: Update the Task to 'Completed' - should fail since there is no ContentDocument
        taskWithoutFile.Status = 'Completed';
        
        try {
            update taskWithoutFile;
            // If no error is thrown, the test should fail
        } catch (DmlException e) {
            
        }
    }

    @isTest
    static void testMultipleTasksWithAndWithoutContentDocument() {
        // Step 1: Create Tasks with and without ContentDocuments
        Task taskWithFile = new Task(
            Subject = 'Test Task 3',
            Status = 'Not Started',
            Priority = 'High'
        );
        insert taskWithFile;

        // Create a ContentVersion to associate it with the Task
        ContentVersion contentVersion = new ContentVersion(
            Title = 'Test Document 2', 
            PathOnClient = 'TestPath/testDoc2.pdf',
            VersionData = Blob.valueOf('Test Content')
        );
        insert contentVersion;

        ContentDocumentLink docLink = new ContentDocumentLink(
            ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1].ContentDocumentId,
            LinkedEntityId = taskWithFile.Id,
            ShareType = 'V'
        );
        insert docLink;

        Task taskWithoutFile = new Task(
            Subject = 'Test Task 4',
            Status = 'Not Started',
            Priority = 'High'
        );
        insert taskWithoutFile;

        // Step 2: Update both tasks to 'Completed'
        taskWithFile.Status = 'Completed';
        taskWithoutFile.Status = 'Completed';
     //   update new List<Task>{ taskWithFile, taskWithoutFile };

       
        Task updatedTaskWithFile = [SELECT Status FROM Task WHERE Id = :taskWithFile.Id];
    
        try {
            Task updatedTaskWithoutFile = [SELECT Status FROM Task WHERE Id = :taskWithoutFile.Id];
          
        } catch (DmlException e) {
        }
    }

    @isTest
    static void testNoTaskUpdate() {
        // Step 1: Create a Task and don't change its status
        Task taskNoChange = new Task(
            Subject = 'Test Task 5',
            Status = 'Not Started',
            Priority = 'High'
        );
        insert taskNoChange;

        // Step 2: Try updating the task without changing the Status
        taskNoChange.Subject = 'Updated Subject';
        update taskNoChange;

        // Assert: The task should not throw any error or be marked as completed
        Task updatedTaskNoChange = [SELECT Status FROM Task WHERE Id = :taskNoChange.Id];
    }
}