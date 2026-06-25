@isTest
public class targetvsactualChildControllerTest {

    @IsTest
    static void testGetYearly_EmployeeWiseAccountTarget() {
        // Create a Fiscal Year record
        Fiscal_Year__c fy = new Fiscal_Year__c(
            Name = 'FY 2024',
            FY_Start_Date__c = Date.newInstance(2024, 1, 1),
            FY_End_Date__c = Date.newInstance(2024, 12, 31)
        );
        insert fy;
        
        User user = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        Account product = new Account(Name = 'Test Product');
        insert product;
        
        String empId = user.Id;
        String prodCatVal = 'TestProductCategory';
        String yearlyData = '[{"ParameterId":"' + user.Id + '","Target_Amount_New__c":"1000","Target_Amount_New__c":"100"}]';
        String yearlyProductData = '[{"ParameterId":"' + product.Id + '","Target_Amount_New__c":"2000","Target_Amount_New__c":"200"}]';

        // Create Product records
        List<Account> products = new List<Account>();
        products.add(new Account(Name = 'VOXCO CHROME ORANGE VO-750/SA '));
        products.add(new Account(Name = 'VOXCO ZINC PHOSPHATE '));
        insert products;

        // Create Account records
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

        // Create Employee Wise Account Target records
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
        String result1 = targetvsactualChildController.getYearly(product.id, fy.Id, userinfo.getUserId(), 'Employee_Wise_Target__c', prodCatVal);
        String result2 = targetvsactualChildController.getYearly(product.id, fy.Id, userinfo.getUserId(), 'Employee_Wise_Account_Target__c', prodCatVal);
        String result3 = targetvsactualChildController.getYearly(null, fy.Id, userinfo.getUserId(), 'Employee_Wise_Target__c', null);
        String result4 = targetvsactualChildController.getYearly(null, fy.Id, userinfo.getUserId(), 'Employee_Wise_Account_Target__c', null);
        Test.stopTest();
    }

    @isTest
    static void updateMonthlyTargetEntriesTest1() {
        Fiscal_Year__c fy = new Fiscal_Year__c(
            Name = 'FY 2024',
            FY_Start_Date__c = Date.newInstance(2024, 1, 1),
            FY_End_Date__c = Date.newInstance(2024, 12, 31)
        );
        insert fy;

        User user = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        Account product = new Account(Name = 'Test Product');
        insert product;
        
        String empId = user.Id;
        String prodCatVal = 'TestProductCategory';
        String yearlyData = '[{"ParameterId":"' + user.Id + '","Target_Amount_New__c":"1000","Target_Amount_New__c":"100"}]';
        String yearlyProductData = '[{"ParameterId":"' + product.Id + '","Target_Amount_New__c":"2000","Target_Amount_New__c":"200"}]';
        
        // Create Product records
        List<Account> products = new List<Account>();
        products.add(new Account(Name = 'VOXCO CHROME ORANGE VO-750/SA '));
        products.add(new Account(Name = 'VOXCO ZINC PHOSPHATE ' ));
        insert products;

        Employee_Wise_Target__c target = new Employee_Wise_Target__c(
            Employee__c = UserInfo.getUserId(),
            Fiscal_Year__c = fy.Id,
            Target_Amount__c = 1000
        );
        insert target;
        
        // Create Employee Wise Account Target records
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

        List<sObject> newRecords = new List<sObject>{target};
        Map<Id, sObject> newMap = new Map<Id, sObject>(newRecords);
        Map<Id, sObject> oldMap = new Map<Id, sObject>{
            target.Id => new Employee_Wise_Target__c(
                Id = target.Id,
                Target_Amount__c = 10000
            )
        };

        Test.startTest();
        targetvsactualChildController T = new targetvsactualChildController();
        targetvsactualChildController.getMonthly(fy.Id, userinfo.getUserId(), 'Employee_Wise_Target__c');
        targetvsactualChildController.getMonthly(fy.Id, userinfo.getUserId(), 'Employee_Wise_Account_Target__c');
        Test.stopTest();
    }
}