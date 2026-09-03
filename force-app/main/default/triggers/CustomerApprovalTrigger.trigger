trigger CustomerApprovalTrigger on Account (before insert, before update, after insert) {
    if (Trigger.isBefore && Trigger.isInsert) {
        CustomerApprovalTriggerHandler.handleBeforeInsert(Trigger.new);
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        CustomerApprovalTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter && Trigger.isInsert) {
        CustomerApprovalTriggerHandler.handleAfterInsert(Trigger.new);
    }
}