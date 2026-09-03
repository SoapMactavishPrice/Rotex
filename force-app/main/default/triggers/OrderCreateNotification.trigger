trigger OrderCreateNotification on Order (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        LeadForwardToDealerHandler.handleOrderAfterInsert(Trigger.new);
    }
}