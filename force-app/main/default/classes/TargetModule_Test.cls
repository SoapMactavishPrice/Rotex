@isTest
public class TargetModule_Test {

    @isTest
    static void updateMonthlyTargetEntriesTest() {
        Fiscal_Year__c fy = new Fiscal_Year__c(
            Name = 'FY 2025',
            FY_Start_Date__c = Date.newInstance(2025, 1, 1),
            FY_End_Date__c = Date.newInstance(2026, 12, 31)
        );
        insert fy;

        User user = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        Account product = new Account(Name = 'Test Product');
        insert product;
        
        String empId = user.Id;
        String prodCatVal = 'TestProductCategory';
        String yearlyData = '[{"ParameterId":"' + user.Id + '","Target_Amount_New__c":"1000","Target_Quantity_New__c":"100"}]';
        String yearlyProductData = '[{"ParameterId":"' + product.Id + '","Target_Amount_New__c":"2000","Target_Quantity_New__c":"200"}]';

        Employee_Wise_Target__c target = new Employee_Wise_Target__c(
            Employee__c = UserInfo.getUserId(),
            Fiscal_Year__c = fy.Id,
            Target_Amount__c = 1000
        );
        insert target;

        List<sObject> newRecords = new List<sObject>{ target };
        Map<Id, sObject> newMap = new Map<Id, sObject>(newRecords);
        Map<Id, sObject> oldMap = new Map<Id, sObject>{
            target.Id => new Employee_Wise_Target__c(
                Id = target.Id,
                Target_Amount__c = 10000
            )
        };

        Test.startTest();
        
        TargetModule T = new TargetModule();
        try{
        TargetModule.getDefaultFilterValues();
        }Catch(Exception e){}
        String result1 = TargetModule.getYearly(null, fy.Id, userInfo.getUserId(), 'Employee_Wise_Target__c', null);
        String result2 = TargetModule.getYearly(product.Id, fy.Id, userInfo.getUserId(), 'Employee_Wise_Target__c', prodCatVal);
        String result3 = TargetModule.getYearly(null, fy.Id, userInfo.getUserId(), 'Employee_Wise_Account_Target__c', null);
        String result4 = TargetModule.getYearly(product.Id, fy.Id, userInfo.getUserId(), 'Employee_Wise_Account_Target__c', prodCatVal);
        
        String result5 = TargetModule.getMonthly(fy.Id, userInfo.getUserId(), 'Employee_Wise_Target__c', null);
        String result6 = TargetModule.getMonthly(fy.Id, userInfo.getUserId(), 'Employee_Wise_Account_Target__c', null);
        
        TargetModule.saveRecords(yearlyData, fy.Id, user.Id, 'Employee_Wise_Target__c', 'Yearly');
        TargetModule.saveRecords(yearlyProductData, fy.Id, user.Id, 'Employee_Wise_Account_Target__c', 'Yearly');
        
        TargetModule.getTargetQuantityByEmpId(UserInfo.getUserId());
        TargetModule.getProductTargetQtyByProdCatVal(prodCatVal, empId);

        Test.stopTest();
    }

    @isTest
    static void updateMonthlyTargetEntriesTest1() {
        Fiscal_Year__c fy = new Fiscal_Year__c(
            Name = 'FY 2025',
            FY_Start_Date__c = Date.newInstance(2025, 1, 1),
            FY_End_Date__c = Date.newInstance(2026, 12, 31)
        );
        insert fy;

        User user = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        Account product = new Account(Name = 'Test Product');
        insert product;
        
        String empId = user.Id;
        String prodCatVal = 'TestProductCategory';
        String yearlyData = '[{"ParameterId":"' + user.Id + '","Target_Amount_New__c":"1000","Target_Quantity_New__c":"100"}]';
        String yearlyProductData = '[{"ParameterId":"' + product.Id + '","Target_Amount_New__c":"2000","Target_Quantity_New__c":"200"}]';

        Employee_Wise_Target__c target = new Employee_Wise_Target__c(
            Employee__c = UserInfo.getUserId(),
            Fiscal_Year__c = fy.Id,
            Target_Amount__c = 1000
        );
        insert target;

        Test.startTest();

        String result1 = TargetModule.getYearly(null, fy.Id, userInfo.getUserId(), 'Employee_Wise_Account_Target__c', null);
        String result2 = TargetModule.getYearly(product.Id, fy.Id, userInfo.getUserId(), 'Employee_Wise_Account_Target__c', prodCatVal);
        
        TargetModule.saveRecords(yearlyData, fy.Id, user.Id, 'Employee_Wise_Target__c', 'Monthly');
        TargetModule.saveRecords(yearlyProductData, fy.Id, user.Id, 'Employee_Wise_Account_Target__c', 'Monthly');
        
        TargetModule.getTargetQuantityByEmpId(UserInfo.getUserId());
        TargetModule.getProductTargetQtyByProdCatVal(prodCatVal, empId);

        Test.stopTest();
    }

    @isTest
    static void testGetYearly_EmployeeWiseAccountTarget() {
        Fiscal_Year__c fy = new Fiscal_Year__c(
            Name = 'FY 2024',
            FY_Start_Date__c = Date.newInstance(2025, 1, 1),
            FY_End_Date__c = Date.newInstance(2026, 12, 31)
        );
        insert fy;

        List<Account> products = new List<Account>();
        products.add(new Account(Name = 'VOXCO CHROME ORANGE VO-750/SA '));
        products.add(new Account(Name = 'VOXCO ZINC PHOSPHATE '));
        insert products;

        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            accounts.add(new Account(Name = 'Account ' + i));
        }
        insert accounts;

        List<Employee_Wise_Target__c> empTargets = new List<Employee_Wise_Target__c>();
        for (Integer i = 0; i < 5; i++) {
            empTargets.add(new Employee_Wise_Target__c(
                Employee__c = UserInfo.getUserId(),
                Fiscal_Year__c = fy.Id,
                Target_Amount__c = 1000 * i
            ));
        }
        insert empTargets;

        Account product = new Account(Name = 'Test Product');
        insert product;

        List<Employee_Wise_Account_Target__c> prodTargets = new List<Employee_Wise_Account_Target__c>();
        for (Account prod : products) {
            prodTargets.add(new Employee_Wise_Account_Target__c(
                Account__c = prod.Id,
                Employee__c = UserInfo.getUserId(),
                Fiscal_Year__c = fy.Id,
                Target_Amount__c = 2000 * products.indexOf(prod)
            ));
        }
        insert prodTargets;

        Test.startTest();

        String result1 = TargetModule.getYearly(null, fy.Id, userInfo.getUserId(), 'Employee_Wise_Target__c', null);
        String result2 = TargetModule.getYearly(null, fy.Id, userInfo.getUserId(), 'Employee_Wise_Account_Target__c', null);
        String result3 = TargetModule.getMonthly(fy.Id, userInfo.getUserId(), 'Employee_Wise_Target__c', null);
        String result4 = TargetModule.getMonthly(fy.Id, userInfo.getUserId(), 'Employee_Wise_Account_Target__c', null);

        Test.stopTest();
    }
    
    @isTest
    static void updateMonthlyTargetEntriesTest2() {
        // Create Fiscal Year
        Fiscal_Year__c fy = new Fiscal_Year__c(
            Name = 'FY 2024',
            FY_Start_Date__c = Date.newInstance(2025, 1, 1),
            FY_End_Date__c = Date.newInstance(2026, 12, 31)
        );
        insert fy;
        
        // Create User - Assume a user is already available in the org
        User user = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        
        // Create Product
        Product2 product = new Product2(Name = 'Test Product', Family = 'Test Family');
        insert product;
        
        // Setup input data for yearly and product targets
        String yearlyData = '[{"ParameterId":"' + user.Id + '","Monthly_Target_Amount_New__c":"1000"}]';
        String yearlyProductData = '[{"ParameterId":"' + product.Id + '","Monthly_Target_Amount_New__c":"2000"}]';
        
        // Create an Employee Wise Target record to associate with the data
        Employee_Wise_Target__c target = new Employee_Wise_Target__c(
            Employee__c = user.Id,
            Fiscal_Year__c = fy.Id,
            Target_Amount__c = 1000
        );
        insert target;
        
        // Start Test
        Test.startTest();
        
        // Simulate calling the TargetModule.saveRecords with 'Monthly' subType
        TargetModule.saveRecords(yearlyData, fy.Id, user.Id, 'Employee_Wise_Target__c', 'Monthly');
        TargetModule.saveRecords(yearlyProductData, fy.Id, user.Id, 'Employee_Wise_Account_Target__c', 'Monthly');
        
        // Optionally, you can call other methods to verify further behaviors
        TargetModule.getTargetQuantityByEmpId(user.Id);
        TargetModule.getProductTargetQtyByProdCatVal('TestProductCategory', user.Id);
        
        // Stop Test
        Test.stopTest();
        
    }

}