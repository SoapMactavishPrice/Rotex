@IsTest
private class DealerNotificationServiceTest {

    @TestSetup
    static void setup() {
        // Just create some standard setup data if needed
    }

    @IsTest
    static void testSendNotification() {
        Set<Id> userIds = new Set<Id>{UserInfo.getUserId()};
        Id dummyTargetId = UserInfo.getUserId(); // just a valid ID format
        
        Test.startTest();
        DealerNotificationService.sendNotification(userIds, 'Test Title', 'Test Body', dummyTargetId);
        Test.stopTest();
        
        List<Notification__c> notifs = [SELECT Id, Title__c, Message__c, Is_Read__c, Target_Record_Id__c FROM Notification__c WHERE User__c = :UserInfo.getUserId()];
        System.assertEquals(1, notifs.size(), 'Should have inserted 1 notification');
        System.assertEquals('Test Title', notifs[0].Title__c, 'Title should match');
        System.assertEquals('Test Body', notifs[0].Message__c, 'Body should match');
        System.assertEquals(false, notifs[0].Is_Read__c, 'Should be unread');
        System.assertEquals(String.valueOf(dummyTargetId), notifs[0].Target_Record_Id__c, 'Target ID should match');
    }
    
    @IsTest
    static void testSendNotificationNulls() {
        Test.startTest();
        // Null set
        DealerNotificationService.sendNotification(null, 'Title', 'Body', null);
        // Empty set
        DealerNotificationService.sendNotification(new Set<Id>(), 'Title', 'Body', null);
        Test.stopTest();
        
        List<Notification__c> notifs = [SELECT Id FROM Notification__c];
        System.assertEquals(0, notifs.size(), 'Should not have inserted any notifications');
    }

    @IsTest
    static void testGetUnreadNotifications() {
        // Setup mock notification
        Notification__c n = new Notification__c(
            User__c = UserInfo.getUserId(),
            Title__c = 'Test Title',
            Message__c = 'Test Msg',
            Is_Read__c = false
        );
        insert n;
        
        Test.startTest();
        String jsonResult = DealerNotificationService.getUnreadNotifications();
        Test.stopTest();
        
        System.assertNotEquals(null, jsonResult, 'Should return JSON string');
        
        DealerNotificationService.NotificationPageWrapper wrapper = (DealerNotificationService.NotificationPageWrapper) JSON.deserialize(jsonResult, DealerNotificationService.NotificationPageWrapper.class);
        System.assertEquals(1, wrapper.notifications.size(), 'Should have 1 notification in wrapper');
        System.assertEquals(n.Id, wrapper.notifications[0].id, 'Id should match');
        System.assertEquals('Test Title', wrapper.notifications[0].payload.messageTitle, 'Title should match');
        System.assertEquals(false, wrapper.notifications[0].read, 'Should be unread');
    }

    @IsTest
    static void testMarkAsRead() {
        Notification__c n = new Notification__c(
            User__c = UserInfo.getUserId(),
            Title__c = 'Test Title',
            Message__c = 'Test Msg',
            Is_Read__c = false
        );
        insert n;
        
        Test.startTest();
        DealerNotificationService.markAsRead(n.Id);
        DealerNotificationService.markAsRead(null); // Should handle null gracefully
        Test.stopTest();
        
        Notification__c updatedNotif = [SELECT Is_Read__c FROM Notification__c WHERE Id = :n.Id];
        System.assertEquals(true, updatedNotif.Is_Read__c, 'Notification should be marked as read');
    }

    @IsTest
    static void testMarkAllAsRead() {
        List<Notification__c> notifs = new List<Notification__c>();
        for (Integer i = 0; i < 3; i++) {
            notifs.add(new Notification__c(
                User__c = UserInfo.getUserId(),
                Title__c = 'Test Title ' + i,
                Message__c = 'Test Msg ' + i,
                Is_Read__c = false
            ));
        }
        insert notifs;
        
        Test.startTest();
        DealerNotificationService.markAllAsRead();
        Test.stopTest();
        
        List<Notification__c> updatedNotifs = [SELECT Is_Read__c FROM Notification__c WHERE User__c = :UserInfo.getUserId()];
        System.assertEquals(3, updatedNotifs.size(), 'Should have 3 notifications');
        for (Notification__c n : updatedNotifs) {
            System.assertEquals(true, n.Is_Read__c, 'All notifications should be marked as read');
        }
    }
}