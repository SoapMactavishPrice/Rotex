trigger CustomerApprovalTrigger on Account (after insert) {
    CustomerApprovalTriggerHandler.handleAfterInsert(Trigger.new);
}