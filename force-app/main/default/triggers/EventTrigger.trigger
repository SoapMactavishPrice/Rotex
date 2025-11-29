trigger EventTrigger on Event (after update) {
    
    if (Trigger.isAfter && Trigger.isUpdate) {
        EventTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}