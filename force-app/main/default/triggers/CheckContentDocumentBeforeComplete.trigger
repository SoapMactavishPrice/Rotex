trigger CheckContentDocumentBeforeComplete on Task (before update) {
 
    // Collect tasks that are being updated to 'Completed'
    List<Task> tasksToCheck = new List<Task>();
    Set<Id> taskIdsToCheck = new Set<Id>();

    // Loop through the updated tasks and identify the ones being marked as 'Completed'
    for (Task t : Trigger.new) {
        Task oldTask = Trigger.oldMap.get(t.Id);

        // Check if the task's status is being updated to 'Completed'
        if (t.Status == 'Completed' && oldTask.Status != 'Completed') {
            tasksToCheck.add(t);
            taskIdsToCheck.add(t.Id);
        }
    }

    // If there are no tasks being updated to 'Completed', exit early
    if (tasksToCheck.isEmpty()) {
        return;
    }

    // Query ContentDocumentLink to check if there are files linked to these tasks
    List<ContentDocumentLink> contentLinks = [
        SELECT ContentDocumentId, LinkedEntityId
        FROM ContentDocumentLink
        WHERE LinkedEntityId IN :taskIdsToCheck
    ];

    // Use a set to track which tasks have ContentDocuments
    Set<Id> tasksWithDocuments = new Set<Id>();
    for (ContentDocumentLink link : contentLinks) {
        tasksWithDocuments.add(link.LinkedEntityId);
    }

    // Validate each task: if it's being marked as 'Completed', check if it has a ContentDocument
    for (Task t : tasksToCheck) {
        if (!tasksWithDocuments.contains(t.Id)) {
            // Prevent task from being marked as 'Completed' without a ContentDocument
            t.addError('Cannot mark the task as "Completed" without a Attachment.');
        }
    } 
}