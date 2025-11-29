trigger LeadOwnerChangeSharingTrigger on Lead (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        LeadSharingHandler.handleOwnerChange(Trigger.new, Trigger.oldMap);
    }
}