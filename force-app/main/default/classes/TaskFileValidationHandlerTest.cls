@IsTest
public class TaskFileValidationHandlerTest {
    
    // Utility method to create a Task
    private static Task createTask(String status) {
        Task t = new Task(
            Subject = 'Test Task',
            Status = status,
            Priority = 'Normal'
        );
        insert t;
        return t;
    }
    
    // Utility method to upload a file and link it to Task
    private static void uploadFile(Id taskId) {
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test Content')
        );
        insert cv;
        
        ContentVersion insertedCV = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];
        
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = insertedCV.ContentDocumentId,
            LinkedEntityId = taskId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;
    }
    
    // ❌ NEGATIVE TEST — should FAIL if no file uploaded
    @IsTest
    static void testTaskCompletionWithoutFile() {
        
        Task t = createTask('Not Started');
        
        Test.startTest();
        try {
            t.Status = 'Completed';
            update t;
            System.assert(false, 'Expected validation error was not thrown');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains('Please upload at least one file'),
                'Incorrect validation message'
            );
        }
        Test.stopTest();
    }
    
    // ✅ POSITIVE TEST — should PASS when file is uploaded
    @IsTest
    static void testTaskCompletionWithFile() {
        
        Task t = createTask('In Progress');
        
        uploadFile(t.Id);
        
        Test.startTest();
        t.Status = 'Completed';
        update t;
        Test.stopTest();
        
        Task updatedTask = [
            SELECT Status
            FROM Task
            WHERE Id = :t.Id
        ];
        
        System.assertEquals(
            'Completed',
            updatedTask.Status,
            'Task should be completed successfully'
        );
    }
    
    // ✅ CONTROL TEST — status not changed to Completed (no validation)
    @IsTest
    static void testStatusUpdateWithoutCompletion() {
        
        Task t = createTask('Not Started');
        
        Test.startTest();
        t.Status = 'In Progress';
        update t;
        Test.stopTest();
        
        Task updatedTask = [
            SELECT Status
            FROM Task
            WHERE Id = :t.Id
        ];
        
        System.assertEquals(
            'In Progress',
            updatedTask.Status,
            'Task status update should succeed without file'
        );
    }
}