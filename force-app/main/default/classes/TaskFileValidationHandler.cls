public class TaskFileValidationHandler {
    
    public static void validateFilesOnCompletion(
        List<Task> newList,
        Map<Id, Task> oldMap
    ) {
        Set<Id> completedTaskIds = new Set<Id>();
        
        for (Task t : newList) {
            Task oldTask = oldMap.get(t.Id);
            
            if (
                oldTask.Status != 'Completed' &&
                t.Status == 'Completed'
            ) {
                completedTaskIds.add(t.Id);
            }
        }
        
        if (completedTaskIds.isEmpty()) return;
        
        Map<Id, Integer> fileCountMap = new Map<Id, Integer>();
        
        for (AggregateResult ar : [
            SELECT LinkedEntityId taskId, COUNT(Id) fileCount
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :completedTaskIds
            GROUP BY LinkedEntityId
        ]) {
            fileCountMap.put(
                (Id) ar.get('taskId'),
                (Integer) ar.get('fileCount')
            );
        }
        
        for (Task t : newList) {
            if (
                completedTaskIds.contains(t.Id) &&
                !fileCountMap.containsKey(t.Id)
            ) {
                t.addError(
                    'Please upload at least one file before completing the task.'
                );
            }
        }
    }
}