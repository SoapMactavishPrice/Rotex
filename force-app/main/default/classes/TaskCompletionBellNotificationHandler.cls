public class TaskCompletionBellNotificationHandler {

    public static void notifyCreator(
        List<Task> newList,
        Map<Id, Task> oldMap
    ) {
        Map<Id, Task> eligibleTasks = new Map<Id, Task>();

        for (Task t : newList) {
            Task oldTask = oldMap.get(t.Id);

            if (
                oldTask.Status != 'Completed' &&
                t.Status == 'Completed' &&
                t.CreatedById != t.OwnerId
            ) {
                eligibleTasks.put(t.Id, t);
            }
        }

        if (eligibleTasks.isEmpty()) return;

        Id notificationTypeId = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Task_Completed_Notification'
            LIMIT 1
        ].Id;

        for (Task t : eligibleTasks.values()) {

            Messaging.CustomNotification notification =
                new Messaging.CustomNotification();

            notification.setTitle('Task Completed');
            notification.setBody(
                'Your task "' + t.Subject +
                '" has been completed by another user.'
            );

            notification.setNotificationTypeId(notificationTypeId);
            notification.setTargetId(t.Id);

            // ✅ WORKING method in your org
            notification.send(
                new Set<String>{ String.valueOf(t.CreatedById) }
            );
        }
    }
}