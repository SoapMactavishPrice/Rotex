trigger LeadForwardToDealerTrigger on Lead (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        // Stamp stage date fields when Dealer_Status__c changes (day-6 / day-90 reminders)
        LeadStatusDateHandler.applyStatusDates(Trigger.new, Trigger.oldMap);
        // Stamp Dealer_* date fields for portal reporting (separate fields, same status change)
        LeadDealerStatusDateHandler.applyDealerStatusDates(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter && Trigger.isInsert) {
        LeadForwardToDealerHandler.handleAfterInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        LeadForwardToDealerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}