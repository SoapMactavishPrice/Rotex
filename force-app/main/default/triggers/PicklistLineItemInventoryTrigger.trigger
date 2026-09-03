trigger PicklistLineItemInventoryTrigger on Pick_List_Line_Item__c (after insert) {
    // Quote Reserved inventory txn is created when picklist products are added
    InventoryTransactionQuoteHandler.handlePicklistLineItemsAfterInsert(Trigger.new);
}