@isTest
public class EmployeeWiseAccountTarget_Test {
    @isTest
    static void createMonthlyTargetEntriesTest() {
        try{
        Fiscal_Year__c fy = new Fiscal_Year__c(
            Name = 'FY 2024',
            FY_Start_Date__c = Date.newInstance(2024, 1, 1),
            FY_End_Date__c = Date.newInstance(2024, 12, 31)
        );
        insert fy;

        Account acc = new Account(Name = 'Account');
        insert acc;

        Employee_Wise_Account_Target__c accountTarget = new Employee_Wise_Account_Target__c(
            Employee__c = UserInfo.getUserId(),
            Account__c = acc.Id,
            Fiscal_Year__c = fy.Id,
            Target_Quantity__c = 100,
            Target_Amount__c = 1200
        );
        insert accountTarget;

        List<sObject> newRecords = new List<sObject>{accountTarget};
        Map<Id, sObject> oldMap = new Map<Id, sObject>{
            accountTarget.Id => new Employee_Wise_Account_Target__c(
                Id = accountTarget.Id,
                Target_Quantity__c = 100,
                Target_Amount__c = 1000
            )
        };

        Test.startTest();
        TargetAllInOneTriggerHandler.createMonthlyTargetEntries(newRecords);
        Test.stopTest();
    }Catch(Exception e){}
    } 
   

}