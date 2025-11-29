@isTest
public class OrderItemTriggerHandlerTest {

    @testSetup
    static void setup() {
        // Existing setup logic to create Account, Products, PriceBook, Orders, etc.
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Id PID = Test.getStandardPricebookId();

        Pricebook2 priceBook = new Pricebook2(Id = PID, IsActive = true);
        update priceBook;

        Product2 product1 = new Product2(Name = 'Product 1', IsActive = true);
        Product2 product2 = new Product2(Name = 'Product 2', IsActive = true);
        insert new List<Product2>{ product1, product2 };

        Order testOrder = new Order(
            Name = 'Test Order',
            Status = 'Draft',
            EffectiveDate = Date.today(),
            AccountId = testAccount.Id,
            Pricebook2Id = PID
        );
        insert testOrder;

        PricebookEntry priceBookEntry1 = [
            SELECT Id, Name, UnitPrice, IsActive, Pricebook2Id, Product2Id
            FROM PricebookEntry
            WHERE Pricebook2Id = :PID
            AND Product2Id = :product1.Id
            LIMIT 1
        ];

        OrderItem orderItem1 = new OrderItem(
            OrderId = testOrder.Id,
            Product2Id = product1.Id,
            PricebookEntryId = priceBookEntry1.Id,
            Quantity = 2,
            UnitPrice = 100
        );

        PricebookEntry priceBookEntry2 = [
            SELECT Id, Name, UnitPrice, IsActive, Pricebook2Id, Product2Id
            FROM PricebookEntry
            WHERE Pricebook2Id = :PID
            AND Product2Id = :product2.Id
            LIMIT 1
        ];

        OrderItem orderItem2 = new OrderItem(
            OrderId = testOrder.Id,
            Product2Id = product2.Id,
            PricebookEntryId = priceBookEntry2.Id,
            Quantity = 1,
            UnitPrice = 200
        );
        insert new List<OrderItem>{ orderItem1, orderItem2 };

        Fiscal_Year__c fiscalYear = new Fiscal_Year__c(
            Name = 'FY 2025',
            FY_Start_Date__c = Date.newInstance(2025, 1, 1),
            FY_End_Date__c = Date.newInstance(2025, 12, 31)
        );
        insert fiscalYear;

        // Employee Wise Target Setup
        Employee_Wise_Target__c target = new Employee_Wise_Target__c(
            Employee__c = UserInfo.getUserId(),  // Assuming the current user is the target employee
            Fiscal_Year__c = fiscalYear.Id,
            Target_Amount__c = 1000
        );
        insert target;

        // Create Employee_Wise_Target_Line_Item__c records
        Employee_Wise_Target_Line_Item__c targetLineItem = new Employee_Wise_Target_Line_Item__c(
            Employee_Wise_Target__c = target.Id,
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c = Date.today().addDays(1),
            Actual_Amount__c = 0
        );
        insert targetLineItem;
    }

    @isTest
    static void testAccountTargetUpdates() {
        // Retrieve test data
        List<OrderItem> orderItems = [SELECT Id, Product2Id, Order.AccountId, TotalPrice, Order.OwnerId FROM OrderItem LIMIT 2];
        List<Employee_Wise_Target_Line_Item__c> targetEmpList = [
            SELECT Id, Actual_Amount__c, Employee_Wise_Target__r.Employee__c
            FROM Employee_Wise_Target_Line_Item__c
        ];

        // Call the method to trigger the update logic
        Test.startTest();
        OrderItemTriggerHandler.updateQuantityOnTarget(orderItems);
        Test.stopTest();

        // Verify updates on Employee_Wise_Target_Line_Item__c
        List<Employee_Wise_Target_Line_Item__c> updatedTargetItems = [
            SELECT Actual_Amount__c
            FROM Employee_Wise_Target_Line_Item__c
            WHERE Employee_Wise_Target__r.Employee__c = :UserInfo.getUserId()
        ];

        
    }

    @isTest
    static void testNoMatchingAccountTarget() {
        // Create an OrderItem with no matching product target
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Id PID = Test.getStandardPricebookId();

        Pricebook2 priceBook = new Pricebook2(Id = PID, IsActive = true);
        update priceBook;

        Product2 product1 = new Product2(Name = 'Product 1', IsActive = true);
        Product2 product2 = new Product2(Name = 'Product 2', IsActive = true);
        insert new List<Product2>{ product1, product2 };

        Order testOrder = [SELECT Id FROM Order LIMIT 1];

        PricebookEntry priceBookEntry1 = [
            SELECT Id, Name, UnitPrice, IsActive, Pricebook2Id, Product2Id
            FROM PricebookEntry
            WHERE Pricebook2Id = :PID
            AND Product2Id = :product1.Id
            LIMIT 1
        ];
        
        OrderItem orderItem = new OrderItem(
            OrderId = testOrder.Id,
            Product2Id = product1.Id,
            PricebookEntryId = priceBookEntry1.Id,
            Quantity = 1,
            UnitPrice = 300
        );
        insert orderItem;

        // Call the method
        Test.startTest();
        OrderItemTriggerHandler.updateQuantityOnTarget(new List<OrderItem>{ orderItem });
        Test.stopTest();

        // Assert no updates
        List<Employee_Wise_Target_Line_Item__c> updatedAccountTargets = [
            SELECT Actual_Amount__c FROM Employee_Wise_Target_Line_Item__c
        ];
        for (Employee_Wise_Target_Line_Item__c target : updatedAccountTargets) {
            System.assertNotEquals(300, target.Actual_Amount__c, 'No updates should occur for non-matching accounts');
        }
    }
}