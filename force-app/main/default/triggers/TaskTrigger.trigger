trigger TaskTrigger on Task (before update, after update) {
    
    if(Trigger.isBefore && Trigger.isUpdate){
        
        TaskFileValidationHandler.validateFilesOnCompletion(
            Trigger.new,
            Trigger.oldMap
        );
    }
    
    if(Trigger.isAfter && Trigger.isUpdate){
        
        TaskCompletionBellNotificationHandler.notifyCreator(
            Trigger.new,
            Trigger.oldMap
        );
        
        TaskReopenAcceptNotificationHandler.notifyAssignee(
            Trigger.new,
            Trigger.oldMap
        );
    }
}