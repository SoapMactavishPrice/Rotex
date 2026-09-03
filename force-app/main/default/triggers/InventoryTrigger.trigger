trigger InventoryTrigger on Inventory__c (after insert, after update) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            LeadForwardToDealerHandler.handleInventoryAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            LeadForwardToDealerHandler.handleInventoryAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}