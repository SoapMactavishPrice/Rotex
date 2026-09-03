trigger AccountTrigger on Account (before insert, before update, after update) {
    if(Trigger.isBefore) {
        if(Trigger.isInsert || Trigger.isUpdate) {
            AccountTriggerHandler.updateAccountOwner(Trigger.new, Trigger.oldMap);
        }
    }
    if (Trigger.isAfter) {
        if (Trigger.isUpdate) {
            AccountSharingHandler.shareAccountWithChannelPartner(Trigger.new,Trigger.oldMap);
        }
    }
}