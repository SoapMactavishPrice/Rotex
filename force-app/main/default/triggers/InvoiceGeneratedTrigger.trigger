trigger InvoiceGeneratedTrigger on SO_Invoice__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        LeadForwardToDealerHandler.handleInvoiceAfterInsert(Trigger.new);
    }
}