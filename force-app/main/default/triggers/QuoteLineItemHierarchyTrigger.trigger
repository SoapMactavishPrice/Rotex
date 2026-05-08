trigger QuoteLineItemHierarchyTrigger on QuoteLineItem (after insert, after update) {
    
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        QuoteLineItemHandler.updateHierarchyFromQuote(Trigger.new);
    }
}