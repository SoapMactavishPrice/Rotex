trigger QuoteApprovalNotificationTrigger on Quote (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        LeadForwardToDealerHandler.handleQuoteAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}