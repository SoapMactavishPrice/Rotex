trigger AccountApprovalNotificationTrigger on Account (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        LeadForwardToDealerHandler.handleAccountAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}