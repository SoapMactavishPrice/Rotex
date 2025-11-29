trigger QuoteOwnerHierarchyTrigger on Quote (after insert, after update) {
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        QuoteHierarchyHandler.updateQuoteHierarchy(Trigger.new, Trigger.oldMap);
    }
}