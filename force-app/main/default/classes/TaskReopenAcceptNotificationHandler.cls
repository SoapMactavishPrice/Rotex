public class TaskReopenAcceptNotificationHandler {
    
    public static void notifyAssignee(
        List<Task> newList,
        Map<Id, Task> oldMap
    ) {
        
        Map<Id, Task> reopenTasks = new Map<Id, Task>();
        Map<Id, Task> acceptedTasks = new Map<Id, Task>();
        
        // 1️⃣ Detect status change
        for (Task t : newList) {
            Task oldTask = oldMap.get(t.Id);
            
            if (oldTask.Status != t.Status) {
                
                if (t.Status == 'Re-Open') {
                    reopenTasks.put(t.Id, t);
                }
                else if (t.Status == 'Accepted') {
                    acceptedTasks.put(t.Id, t);
                }
            }
        }
        
        // 2️⃣ Fetch Notification Types
        Map<String, Id> notificationTypeMap = new Map<String, Id>();
        
        for (CustomNotificationType cnt : [
            SELECT Id, DeveloperName
            FROM CustomNotificationType
            WHERE DeveloperName IN (
                'Reopen_Notification',
                'Accepted_Notification'
            )
        ]) {
            notificationTypeMap.put(cnt.DeveloperName, cnt.Id);
        }
        
        // 3️⃣ Send Reopen Notifications
        for (Task t : reopenTasks.values()) {
            
            Messaging.CustomNotification notification =
                new Messaging.CustomNotification();
            
            notification.setTitle('Task Reopened - ' + t.Subject);
            notification.setBody(
                'Task "' + t.Subject +
                '" has been reopened and assigned to you.'
            );
            
            notification.setNotificationTypeId(
                notificationTypeMap.get('Reopen_Notification')
            );
            notification.setTargetId(t.Id);
            
            notification.send(
                new Set<String>{ String.valueOf(t.OwnerId) }
            );
        }
        
        // 4️⃣ Send Accepted Notifications
        for (Task t : acceptedTasks.values()) {
            
            Messaging.CustomNotification notification =
                new Messaging.CustomNotification();
            
            notification.setTitle('Task Accepted - '+ t.Subject);
            notification.setBody(
                'Task "' + t.Subject +
                '" has been accepted and assigned to you.'
            );
            
            notification.setNotificationTypeId(
                notificationTypeMap.get('Accepted_Notification')
            );
            notification.setTargetId(t.Id);
            
            notification.send(
                new Set<String>{ String.valueOf(t.OwnerId) }
            );
        }
    }
}