@IsTest
public class targetvsactualChildControllerTest {

    @IsTest
    static void testGetYearly_EmployeeWiseAccountTarget() {
        // Create a Fiscal Year record
        Fiscal_Year__c fy = new Fiscal_Year__c(
            Name = 'FY 2025',
            FY_Start_Date__c = Date.newInstance(2025, 1, 1),
            FY_End_Date__c = Date.newInstance(2026, 12, 31)
        );
        insert fy;
        
        User user = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        // Create a sample Account/Product
        Account product = new Account(Name = 'Test Product');
        insert product;
        
        String prodCatVal = 'TestProductCategory';

        // Create multiple Product records
        List<Account> products = new List<Account>{
            new Account(Name = 'VOXCO CHROME ORANGE VO-750/SA'),
            new Account(Name = 'VOXCO ZINC PHOSPHATE')
        };
        insert products;

        // Create Employee_Wise_Target__c records
        List<Employee_Wise_Target__c> empTargets = new List<Employee_Wise_Target__c>();
        for (Integer i = 0; i < 5; i++) {
            empTargets.add(new Employee_Wise_Target__c(
              //  Name = 'EmpTarget ' + i,
                Employee__c = user.Id,
                Fiscal_Year__c = fy.Id,
                Target_Amount__c = 1000 * (i + 1)
            ));
        }
        insert empTargets;

        // Create Employee_Wise_Account_Target__c records
        List<Employee_Wise_Account_Target__c> prodTargets = new List<Employee_Wise_Account_Target__c>();
        for (Account prod : products) {
            prodTargets.add(new Employee_Wise_Account_Target__c(
               // Name = 'ProdTarget ' + prod.Name,
                Employee__c = user.Id,
                Fiscal_Year__c = fy.Id,
                Account__c = prod.Id,
               // Product_Category__c = prodCatVal,
                Target_Amount__c = 2000
            ));
        }
        insert prodTargets;

        Test.startTest();
        // Call the controller methods
        String result1 = targetvsactualChildController.getYearly(
            product.Id, fy.Id, user.Id, 'Employee_Wise_Target__c', prodCatVal
        );
        String result2 = targetvsactualChildController.getYearly(
            product.Id, fy.Id, user.Id, 'Employee_Wise_Account_Target__c', prodCatVal
        );
        String result3 = targetvsactualChildController.getYearly(
            null, fy.Id, user.Id, 'Employee_Wise_Target__c', null
        );
        String result4 = targetvsactualChildController.getYearly(
            null, fy.Id, user.Id, 'Employee_Wise_Account_Target__c', null
        );
        Test.stopTest();
    }

    @IsTest
    static void updateMonthlyTargetEntriesTest1() {
        // Create Fiscal Year
        Fiscal_Year__c fy = new Fiscal_Year__c(
            Name = 'FY 2025',
            FY_Start_Date__c = Date.newInstance(2025, 1, 1),
            FY_End_Date__c = Date.newInstance(2026, 12, 31)
        );
        insert fy;

        User user = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        // Create a sample Product/Account
        Account product = new Account(Name = 'Test Product');
        insert product;

        String prodCatVal = 'TestProductCategory';

        // Create Product records
        List<Account> products = new List<Account>{
            new Account(Name = 'VOXCO CHROME ORANGE VO-750/SA'),
            new Account(Name = 'VOXCO ZINC PHOSPHATE')
        };
        insert products;

        // Create Employee_Wise_Target__c
        Employee_Wise_Target__c empTarget = new Employee_Wise_Target__c(
          //  Name = 'EmpTarget',
            Employee__c = user.Id,
            Fiscal_Year__c = fy.Id,
            Target_Amount__c = 1000
        );
        insert empTarget;

        // Create Employee_Wise_Account_Target__c
        List<Employee_Wise_Account_Target__c> prodTargets = new List<Employee_Wise_Account_Target__c>();
        for (Account prod : products) {
            prodTargets.add(new Employee_Wise_Account_Target__c(
               // Name = 'ProdTarget ' + prod.Name,
                Employee__c = user.Id,
                Fiscal_Year__c = fy.Id,
                Account__c = prod.Id,
               // Product_Category__c = prodCatVal,
                Target_Amount__c = 2000
            ));
        }
        insert prodTargets;

        Test.startTest();
        // Call monthly methods
        targetvsactualChildController.getMonthly(fy.Id, user.Id, 'Employee_Wise_Target__c');
        targetvsactualChildController.getMonthly(fy.Id, user.Id, 'Employee_Wise_Account_Target__c');
        Test.stopTest();
    }
}