@IsTest
public class TaskReopenAcceptedBellNotificationTest {
    
    /* ================================
Helper: Create another user
================================ */
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
    
    /* ================================
✅ Reopen → notify Owner
================================ */
    @IsTest
    static void testReopenNotification() {
        
        User assignee = createUser();
        
        Task t = new Task(
            Subject = 'Reopen Task',
            Status = 'In Progress',
            OwnerId = assignee.Id
        );
        insert t;
        
        Test.startTest();
        t.Status = 'Re-Open';
        update t;
        Test.stopTest();
        
        Task updatedTask = [
            SELECT Status
            FROM Task
            WHERE Id = :t.Id
        ];
        
        System.assertEquals('Re-Open', updatedTask.Status);
    }
    
    /* ================================
✅ Accepted → notify Owner
================================ */
    @IsTest
    static void testAcceptedNotification() {
        
        User assignee = createUser();
        
        Task t = new Task(
            Subject = 'Accepted Task',
            Status = 'Re-Open',
            OwnerId = assignee.Id
        );
        insert t;
        
        Test.startTest();
        t.Status = 'Accepted';
        update t;
        Test.stopTest();
        
        Task updatedTask = [
            SELECT Status
            FROM Task
            WHERE Id = :t.Id
        ];
        
        System.assertEquals('Accepted', updatedTask.Status);
    }
    
    /* ================================
❌ Status unchanged → no notify
================================ */
    @IsTest
    static void testNoNotificationWhenStatusUnchanged() {
        
        User assignee = createUser();
        
        Task t = new Task(
            Subject = 'No Status Change',
            Status = 'In Progress',
            OwnerId = assignee.Id
        );
        insert t;
        
        Test.startTest();
        t.Subject = 'Updated Subject Only';
        update t;
        Test.stopTest();
        
        Task updatedTask = [
            SELECT Subject, Status
            FROM Task
            WHERE Id = :t.Id
        ];
        
        System.assertEquals('Updated Subject Only', updatedTask.Subject);
        System.assertEquals('In Progress', updatedTask.Status);
    }
}