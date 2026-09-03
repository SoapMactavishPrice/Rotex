trigger QuoteInventoryTrigger on Quote (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        InventoryTransactionQuoteHandler.handleQuotesAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}