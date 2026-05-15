trigger CaseLeadTrigger on Case (after insert) {
    
    if (Trigger.isAfter && Trigger.isInsert) {
        CaseTriggerHandler.createLeadFromCase(Trigger.new);
    }
}