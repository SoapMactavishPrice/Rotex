@isTest
public class TargetAllInOneTriggerHandlerTest {
   @isTest
    static void testRollupTargetAmountEmployeeWiseTarget() {
        Fiscal_Year__c fy = new Fiscal_Year__c(
            Name = 'FY 2025',
            FY_Start_Date__c = Date.newInstance(2025, 1, 1),
            FY_End_Date__c = Date.newInstance(2026, 12, 31)
        );
        insert fy;

        Employee_Wise_Target__c target = new Employee_Wise_Target__c(
            Employee__c = UserInfo.getUserId(),
            Fiscal_Year__c = fy.Id,
            Target_Quantity__c = 10,
            Target_Amount__c = 1000
        );
        insert target;

        List<sObject> newRecords = new List<sObject>{target};
        Map<Id, sObject> oldMap = new Map<Id, sObject>{
            target.Id => new Employee_Wise_Target__c(
                Id = target.Id,
                Target_Quantity__c = 100,
                Target_Amount__c = 10000
            )
        };

        Test.startTest();
        TargetAllInOneTriggerHandler.rollupTargetAmount(newRecords, oldMap, 'EmployeeWiseTarget');
        Test.stopTest();
    }

    @isTest
    static void testRollupTargetAmountEmployeeWiseProductTarget() {
        Fiscal_Year__c fy = new Fiscal_Year__c(
            Name = 'FY 2024',
            FY_Start_Date__c = Date.newInstance(2025, 1, 1),
            FY_End_Date__c = Date.newInstance(2026, 12, 31)
        );
        insert fy;

        Product2 prod = new Product2();
        prod.Name = 'VOXCO ZINC PHOSPHATE';
        prod.Family = 'Anti-Corrosive';
        insert prod;

        Employee_Wise_Product_Target__c productTarget = new Employee_Wise_Product_Target__c(
            Employee__c = UserInfo.getUserId(),
            Product__c = prod.Id,
            Fiscal_Year__c = fy.Id,
            Target_Quantity__c = 100,
            Target_Amount__c = 1200
        );
        insert productTarget;

        List<sObject> newRecords = new List<sObject>{productTarget};
        Map<Id, sObject> oldMap = new Map<Id, sObject>{
            productTarget.Id => new Employee_Wise_Product_Target__c(
                Id = productTarget.Id,
                Target_Quantity__c = 100,
                Target_Amount__c = 1200
            )
        };
            
          

        Test.startTest();
        TargetAllInOneTriggerHandler.rollupTargetAmount(newRecords, oldMap, 'EmployeeWiseProductTarget');
        Test.stopTest();
    }

    static void createMonthlyTargetEntriesTest() {
        Fiscal_Year__c fy = new Fiscal_Year__c(
            Name = 'FY 2024',
            FY_Start_Date__c = Date.newInstance(2025, 1, 1),
            FY_End_Date__c = Date.newInstance(2026, 12, 31)
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
    } 

    @isTest
    static void updateMonthlyTargetEntriesTest() {
        Fiscal_Year__c fy = new Fiscal_Year__c(
            Name = 'FY 2024',
           FY_Start_Date__c = Date.newInstance(2025, 1, 1),
            FY_End_Date__c = Date.newInstance(2026, 12, 31)
        );
        insert fy;

        Employee_Wise_Target__c target = new Employee_Wise_Target__c(
            Employee__c = UserInfo.getUserId(),
            Fiscal_Year__c = fy.Id,
            Target_Quantity__c = 10,
            Target_Amount__c = 1000
        );
        insert target;

        List<sObject> newRecords = new List<sObject>{target};
        Map<Id, sObject> newMap = new Map<Id, sObject>(newRecords);
        Map<Id, sObject> oldMap = new Map<Id, sObject>{
            target.Id => new Employee_Wise_Target__c(
                Id = target.Id,
                Target_Quantity__c = 100,
                Target_Amount__c = 10000
            )
        };

        Test.startTest();
        TargetAllInOneTriggerHandler.updateMonthlyTargetEntries(newRecords, oldMap, newMap, 'EmployeeWiseTarget');
        Test.stopTest();
    }

 /*   @isTest
    static void updateMonthlyAccountTargetEntriesTest() {
        Fiscal_Year__c fy = new Fiscal_Year__c(
            Name = 'FY 2024',
            FY_Start_Date__c = Date.newInstance(2024, 1, 1),
            FY_End_Date__c = Date.newInstance(2024, 12, 31)
        );
        insert fy;

        Account acc = new Account(Name = 'Account');
        insert acc;

        Employee_Wise_Account_Target__c target = new Employee_Wise_Account_Target__c(
            Account__c = acc.Id,
            Employee__c = UserInfo.getUserId(),
            Fiscal_Year__c = fy.Id,
            Target_Quantity__c = 10,
            Target_Amount__c = 1000
        );
        insert target;

        List<sObject> newRecords = new List<sObject>{target};
        Map<Id, sObject> newMap = new Map<Id, sObject>(newRecords);
        Map<Id, sObject> oldMap = new Map<Id, sObject>{
            target.Id => new Employee_Wise_Account_Target__c(
                Id = target.Id,
                Target_Quantity__c = 100,
                Target_Amount__c = 10000
            )
        };

        Test.startTest();
        TargetAllInOneTriggerHandler.updateMonthlyTargetEntries(newRecords, oldMap, newMap, 'EmployeeWiseAccountTarget');
        Test.stopTest();
    } */

  /*  @isTest
    static void shareRecordWithUserTest() {
        List<Employee_Wise_Target__c> employeeTargets = new List<Employee_Wise_Target__c>();
        List<Employee_Wise_Product_Target__c> productTargets = new List<Employee_Wise_Product_Target__c>();
        List<Employee_Wise_Account_Target__c> accountTargets = new List<Employee_Wise_Account_Target__c>();

        Fiscal_Year__c fy = new Fiscal_Year__c(
            Name = 'FY 2024',
            FY_Start_Date__c = Date.newInstance(2024, 1, 1),
            FY_End_Date__c = Date.newInstance(2024, 12, 31)
        );
        insert fy;

        Product2 prod = new Product2();
        prod.Name = 'VOXCO ZINC PHOSPHATE';
        prod.Family = 'Anti-Corrosive';
        insert prod;

        Employee_Wise_Target__c ewt = new Employee_Wise_Target__c(
            Fiscal_Year__c = fy.Id,
            Target_Quantity__c = 100,
            Target_Amount__c = 1000,
            Employee__c = UserInfo.getUserId()
        );
        employeeTargets.add(ewt);

        Employee_Wise_Product_Target__c ewpt = new Employee_Wise_Product_Target__c(
            Fiscal_Year__c = fy.Id,
            Product__c = prod.Id,
            Target_Quantity__c = 200,
            Target_Amount__c = 2000,
            Employee__c = UserInfo.getUserId()
        );
        productTargets.add(ewpt);

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Employee_Wise_Account_Target__c ewat = new Employee_Wise_Account_Target__c(
            Fiscal_Year__c = fy.Id,
            Account__c = acc.Id,
            Target_Quantity__c = 300,
            Target_Amount__c = 3000,
            Employee__c = UserInfo.getUserId()
        );
        accountTargets.add(ewat);

        insert employeeTargets;
        insert productTargets;
        insert accountTargets;

        List<sObject> newRecords = new List<sObject>();
        newRecords.addAll(employeeTargets);
        newRecords.addAll(productTargets);
        newRecords.addAll(accountTargets);

        Test.startTest();
        TargetAllInOneTriggerHandler.shareRecordWithUser(newRecords, null);
        Test.stopTest();
    } */

   /*  @isTest
   static void testAccountWiseProductTargetTrigger() {
        Fiscal_Year__c fy = new Fiscal_Year__c(
            Name = 'FY 2024',
            FY_Start_Date__c = Date.newInstance(2024, 1, 1),
            FY_End_Date__c = Date.newInstance(2024, 12, 31)
        );
        insert fy;

        Account_Wise_Product_Target__c awpt = new Account_Wise_Product_Target__c(
            Employee__c = UserInfo.getUserId(),
            Fiscal_Year__c = fy.Id,
            Target_Quantity__c = 100,
            Target_Amount__c = 1200
        );
        insert awpt;

        Account_Wise_Product_Target_Line_Item__c awptLineItem = new Account_Wise_Product_Target_Line_Item__c(
            Account_Wise_Product_Target__c = awpt.Id
        );

        Test.startTest();
        insert awptLineItem;
        Test.stopTest();
    }

    @isTest
    static void testAccountWiseProductTargetLineItemTrigger() {
        Fiscal_Year__c fy = new Fiscal_Year__c(
            Name = 'FY 2024',
            FY_Start_Date__c = Date.newInstance(2024, 1, 1),
            FY_End_Date__c = Date.newInstance(2024, 12, 31)
        );
        insert fy;

        Account_Wise_Product_Target__c awpt = new Account_Wise_Product_Target__c(
            Employee__c = UserInfo.getUserId(),
            Fiscal_Year__c = fy.Id,
            Target_Quantity__c = 100,
            Target_Amount__c = 1200
        );
        insert awpt;

        Account_Wise_Product_Target_Line_Item__c awptLineItem = new Account_Wise_Product_Target_Line_Item__c(
            Account_Wise_Product_Target__c = awpt.Id
        );

        Test.startTest();
        insert awptLineItem;
        Test.stopTest();
    } */
}