public class TaskCompletionBellNotificationHandler {
    
    public static void notifyCreator(
        List<Task> newList,
        Map<Id, Task> oldMap
    ) {
        
        Map<Id, Task> eligibleTasks = new Map<Id, Task>();
        Set<Id> ownerIds = new Set<Id>();
        
        for (Task t : newList) {
            Task oldTask = oldMap.get(t.Id);
            
            if (
                oldTask.Status != 'Completed' &&
                t.Status == 'Completed' &&
                t.CreatedById != t.OwnerId
            ) {
                eligibleTasks.put(t.Id, t);
                ownerIds.add(t.OwnerId);
            }
        }
        
        if (eligibleTasks.isEmpty()) return;
        
        // 🔹 Get Owner → Manager
        Map<Id, User> ownerMap = new Map<Id, User>(
            [SELECT Id, ManagerId FROM User WHERE Id IN :ownerIds]
        );
        
        // 🔹 Get Notification Type
        Id notificationTypeId = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Task_Completed_Notification'
            LIMIT 1
        ].Id;
        
        for (Task t : eligibleTasks.values()) {
            
            User ownerUser = ownerMap.get(t.OwnerId);
            
            // skip if no manager
            if (ownerUser == null || ownerUser.ManagerId == null) {
                continue;
            }
            
            Messaging.CustomNotification notification =
                new Messaging.CustomNotification();
            
            notification.setTitle('Task Completed');
            notification.setBody(
                'Task "' + t.Subject +
                '" completed by ' + UserInfo.getName()
            );
            
            notification.setNotificationTypeId(notificationTypeId);
            notification.setTargetId(t.Id);
            
            // 🔔 send to Assigned To's Manager
            notification.send(
                new Set<String>{ String.valueOf(ownerUser.ManagerId) }
            );
        }
    }
}