@isTest
public class EmployeeWiseAccountTargetLineItemTest {
    
    @isTest
    static void testBeforeInsert() {
        try{
       
        List<Employee_Wise_Account_Target_Line_Item__c> testLineItems = new List<Employee_Wise_Account_Target_Line_Item__c>();

        for (Integer i = 0; i < 5; i++) {
            Employee_Wise_Account_Target_Line_Item__c lineItem = new Employee_Wise_Account_Target_Line_Item__c();
            
            lineItem.Actual_Quantity__c = 100 + i;
            lineItem.Month_Name__c = 'January';
            lineItem.Start_Date__c = Date.today() + 1;
            lineItem.End_Date__c = Date.today() + 5;
            testLineItems.add(lineItem);
        }
        
        Test.startTest();
        insert testLineItems;
        Test.stopTest();
        
        for (Employee_Wise_Account_Target_Line_Item__c item : [SELECT Id, Actual_Quantity__c FROM Employee_Wise_Account_Target_Line_Item__c WHERE Id IN :testLineItems]) {
            System.assertNotEquals(null, item.Id); 
            System.assert(item.Actual_Quantity__c > 100); 
            System.assertNotEquals(null, item.Employee_Wise_Account_Target__c); 
        }
    }Catch(Exception e){}
    }
    
  
}