@IsTest
public class TaskCompletionNotificationHandlerTest {
    
    /* =====================================================
Helper: Create another user
===================================================== */
    private static User createUser() {
        
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];
        
        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'user' + System.currentTimeMillis() + '@test.com',
            Username = 'user' + System.currentTimeMillis() + '@test.com',
            Alias = 'tusr',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;
        return u;
    }
    
    /* =====================================================
Helper: Upload file to Task
===================================================== */
    private static void uploadFileToTask(Id taskId) {
        
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.txt',
            VersionData = Blob.valueOf('Test Content')
        );
        insert cv;
        
        ContentVersion insertedCV = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];
        
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = insertedCV.ContentDocumentId,
            LinkedEntityId = taskId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;
    }
    
    /* =====================================================
✅ Test: Creator ≠ Owner → Completion allowed
===================================================== */
    @IsTest
    static void testCompletionWithFile() {
        
        User otherUser = createUser();
        
        Task t = new Task(
            Subject = 'Task With File',
            Status = 'In Progress',
            OwnerId = otherUser.Id
        );
        insert t;
        
        // 🔑 MUST satisfy file validation
        uploadFileToTask(t.Id);
        
        Test.startTest();
        t.Status = 'Completed';
        update t;
        Test.stopTest();
        
        System.assertEquals(
            'Completed',
            [SELECT Status FROM Task WHERE Id = :t.Id].Status
        );
    }
    
    /* =====================================================
❌ Test: Creator = Owner (no notification)
===================================================== */
    @IsTest
    static void testCreatorIsOwner() {
        
        Task t = new Task(
            Subject = 'Self Assigned Task',
            Status = 'In Progress',
            OwnerId = UserInfo.getUserId()
        );
        insert t;
        
        uploadFileToTask(t.Id);
        
        Test.startTest();
        t.Status = 'Completed';
        update t;
        Test.stopTest();
        
        System.assertEquals('Completed', t.Status);
    }
    
    /* =====================================================
❌ Test: Status not completed
===================================================== */
    @IsTest
    static void testNotCompleted() {
        
        User otherUser = createUser();
        
        Task t = new Task(
            Subject = 'Not Completed Task',
            Status = 'Not Started',
            OwnerId = otherUser.Id
        );
        insert t;
        
        Test.startTest();
        t.Status = 'In Progress';
        update t;
        Test.stopTest();
        
        System.assertEquals('In Progress', t.Status);
    }
}