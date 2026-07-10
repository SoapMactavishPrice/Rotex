trigger PartnerUserTrigger on User (after insert, after update) {

    if (Trigger.isAfter && Trigger.isInsert) {
        PartnerPermissionSetAssignmentHandler.assignPermissionSet(Trigger.new, null);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        PartnerPermissionSetAssignmentHandler.assignPermissionSet(Trigger.new, Trigger.oldMap);
    }
}