public without sharing class DealerNotificationService {
    
    /**
     * Sends a custom notification to a set of users by inserting Notification__c records.
     *
     * @param userIds Set of User IDs to receive the notification
     * @param title Title of the notification
     * @param body Body text of the notification
     * @param targetId The record ID to link the notification to (when clicked)
     */
    public static void sendNotification(Set<Id> userIds, String title, String body, Id targetId) {
        if (userIds == null || userIds.isEmpty()) {
            return;
        }

        List<Notification__c> notifsToInsert = new List<Notification__c>();
        
        for (Id uId : userIds) {
            Notification__c notif = new Notification__c();
            notif.User__c = uId;
            notif.Title__c = title;
            notif.Message__c = body;
            
            // targetId can be null, so check before converting to string
            if (targetId != null) {
                notif.Target_Record_Id__c = String.valueOf(targetId);
            }
            notif.Is_Read__c = false;
            
            notifsToInsert.add(notif);
        }

        try {
            if (!notifsToInsert.isEmpty()) {
                insert notifsToInsert;
            }
        } catch (Exception e) {
            System.debug('DealerNotificationService error: ' + e.getMessage());
        }
    }

    // =========================================================================
    // LWC CONTROLLER METHODS (Moved from DealerUserMenuController)
    // =========================================================================
    
    public class NotificationPayload {
        public String messageTitle;
    }

    public class NotificationWrapper {
        public String id;
        public String messageBody;
        public Boolean read;
        public Datetime lastModifiedDate;
        public String targetRecordId;
        public NotificationPayload payload;
    }

    public class NotificationPageWrapper {
        public List<NotificationWrapper> notifications;
    }

    @AuraEnabled
    public static String getUnreadNotifications() {
        try {
            List<Notification__c> notifs = [
                SELECT Id, Title__c, Message__c, Is_Read__c, CreatedDate, Target_Record_Id__c
                FROM Notification__c
                WHERE User__c = :UserInfo.getUserId()
                ORDER BY CreatedDate DESC
                LIMIT 20
            ];

            NotificationPageWrapper page = new NotificationPageWrapper();
            page.notifications = new List<NotificationWrapper>();

            for (Notification__c n : notifs) {
                NotificationWrapper nw = new NotificationWrapper();
                nw.id = n.Id;
                nw.messageBody = n.Message__c;
                nw.read = n.Is_Read__c;
                nw.lastModifiedDate = n.CreatedDate;
                nw.targetRecordId = n.Target_Record_Id__c;

                NotificationPayload p = new NotificationPayload();
                p.messageTitle = n.Title__c;
                nw.payload = p;

                page.notifications.add(nw);
            }

            return JSON.serialize(page);
        } catch (Exception e) {
            System.debug('Error fetching custom notifications: ' + e.getMessage());
            return null;
        }
    }

    @AuraEnabled
    public static void markAsRead(Id notificationId) {
        if (notificationId == null) {
            return;
        }
        try {
            List<Notification__c> rows = [
                SELECT Id, Is_Read__c
                FROM Notification__c
                WHERE Id = :notificationId
                  AND User__c = :UserInfo.getUserId()
                LIMIT 1
            ];
            if (rows.isEmpty()) {
                return;
            }
            if (rows[0].Is_Read__c != true) {
                rows[0].Is_Read__c = true;
                update rows;
            }
        } catch (Exception e) {
            System.debug('Error marking notification as read: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void markAllAsRead() {
        try {
            // Find all unread notifications for this user and mark them as read
            List<Notification__c> unread = [
                SELECT Id, Is_Read__c 
                FROM Notification__c 
                WHERE User__c = :UserInfo.getUserId() 
                  AND Is_Read__c = false
            ];
            
            for (Notification__c n : unread) {
                n.Is_Read__c = true;
            }
            
            if (!unread.isEmpty()) {
                update unread;
            }
        } catch (Exception e) {
            System.debug('Error marking custom notifications as read: ' + e.getMessage());
        }
    }
}