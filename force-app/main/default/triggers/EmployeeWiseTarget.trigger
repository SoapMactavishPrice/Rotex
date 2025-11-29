trigger EmployeeWiseTarget on Employee_Wise_Target__c (before insert,after insert, before update, After Update) {

    if(Trigger.isBefore && Trigger.isUpdate) {
        TargetAllInOneTriggerHandler.rollupTargetAmount(Trigger.New, Trigger.oldMap, 'EmployeeWiseTarget');
    }
    
    if(Trigger.isAfter && Trigger.isInsert) {
        TargetAllInOneTriggerHandler.createMonthlyTargetEntries(Trigger.New);
    }
    
   if(Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
       // TargetAllInOneTriggerHandler.updateBranchTarget(Trigger.New, Trigger.oldMap);
        TargetAllInOneTriggerHandler.shareRecordWithUser(Trigger.New, Trigger.oldMap);
    } 
    
    if(Trigger.isAfter && Trigger.isUpdate) {
        TargetAllInOneTriggerHandler.updateMonthlyTargetEntries(Trigger.New, Trigger.oldMap, Trigger.newMap, 'EmployeeWiseTarget');
    } 
    
}