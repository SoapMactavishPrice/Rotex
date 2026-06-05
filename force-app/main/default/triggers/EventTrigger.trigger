trigger EventTrigger on Event (after update) {
    
    if (Trigger.isAfter && Trigger.isUpdate) {
        EventTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    // New Task Creation Logic
        EventTriggerHandler1.createFollowupTasks(Trigger.new, Trigger.oldMap);
       }

}