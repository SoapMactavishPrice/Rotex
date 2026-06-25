trigger EmployeeWiseTargetLineItem on Employee_Wise_Target_Line_Item__c (before insert, before update) {

    if(Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
      TargetAllInOneTriggerHandler.evaluateValues(Trigger.New);
       TargetAllInOneTriggerHandler.UpdateAmountValues(Trigger.New);
    } 

}