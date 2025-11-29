trigger EmployeeWiseAccountTargetLineItem on Employee_Wise_Account_Target_Line_Item__c (before insert) {
    
if(Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
		TargetAllInOneTriggerHandler.evaluateValues(Trigger.New);
		System.debug('EmployeeWiseProductTargetLineItem__Trigger__');
		TargetAllInOneTriggerHandler.UpdateAmountValues(Trigger.New);
		System.debug('EmployeeWiseProductTargetLineItem__Trigger__2:>> ' +Trigger.new);
}
}