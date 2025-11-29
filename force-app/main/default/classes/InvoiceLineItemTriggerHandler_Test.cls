@isTest
public class InvoiceLineItemTriggerHandler_Test {

    @isTest
    static void testUpdateQuantityOnTarget() {
        Fiscal_Year__c fiscalYear = new Fiscal_Year__c(
            Name = 'FY 2024',
            FY_Start_Date__c = Date.newInstance(2024, 1, 1),
            FY_End_Date__c = Date.newInstance(2024, 12, 31)
        );
        insert fiscalYear;
        
        // Test data creation
        Account account = new Account(Name = 'Test Account');
        insert account;

        Product2 product = new Product2(Name = 'Sample Product 3', isActive = true);
        insert product;

        User user = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        Order order = new Order(Name = 'Test Order', AccountId = account.Id, OwnerId = user.Id, EffectiveDate = Date.today(), Status = 'Draft');
        insert order;

        SO_Invoice__c invoice = new SO_Invoice__c( Order__c = order.Id);
        insert invoice;

        Invoice_Line_Item__c invoiceLineItem = new Invoice_Line_Item__c(
            Name = 'Test Invoice Line Item',
            SO_Invoice__c = invoice.Id,
            Quantity__c = 10,
            Line_Amount__c = 100,
            Product__c = product.Id,
            Account__c = account.Id
        );
        insert invoiceLineItem;

        Employee_Wise_Target__c empTarget = new Employee_Wise_Target__c(
            Employee__c = user.Id,
            
            Fiscal_Year__c = fiscalYear.Id,
            Target_Quantity__c= 100
            //Target_Amount__c=1000
        );
        
        insert empTarget;

        Employee_Wise_Target_Line_Item__c TargetLineItem = new Employee_Wise_Target_Line_Item__c(
            Employee_Wise_Target__c = empTarget.Id,
            Start_Date__c = Date.newInstance(2024, 1, 1),
            End_Date__c = Date.newInstance(2024, 1, 31),
            Monthly_Target_Quantity__c = 100
            //Monthly_Target_Amount__c = 1000
        );
        insert TargetLineItem;

        Employee_Wise_Product_Target__c productTarget = new Employee_Wise_Product_Target__c(
            Employee__c = user.Id,
            Product__c = product.Id,
            Fiscal_Year__c = fiscalYear.Id,
            Target_Quantity__c= 100
            //Target_Amount__c=1000
        );
        
        insert productTarget;

        // Employee Wise Product Target Line Item
        Employee_Wise_Product_Target_Line_Item__c productTargetLineItem = new Employee_Wise_Product_Target_Line_Item__c(
            Employee_Wise_Product_Target__c = productTarget.Id,
            Start_Date__c = Date.newInstance(2024, 1, 1),
            End_Date__c = Date.newInstance(2024, 1, 31),
            Monthly_Target_Quantity__c = 100
           // Monthly_Target_Amount__c = 1000
        );
        insert productTargetLineItem;

        // Execute the method
        Test.startTest();
        List<Invoice_Line_Item__c> invoiceLineItemList = [SELECT Id, Quantity__c, Product__c, Account__c FROM Invoice_Line_Item__c WHERE Id = :invoiceLineItem.Id];
        InvoiceLineItemTriggerHandler.updatequantityontarget(invoiceLineItemList);
        Test.stopTest();

            }

    @isTest
    static void testUpdateQuantityOnTargetWithEmptyList() {
        Test.startTest();
        InvoiceLineItemTriggerHandler.updatequantityontarget(new List<Invoice_Line_Item__c>());
        Test.stopTest();
        // No asserts needed, just ensuring no exceptions are thrown
    }

    @isTest
    static void testUpdateQuantityOnTargetWithNullList() {
        Test.startTest();
        InvoiceLineItemTriggerHandler.updatequantityontarget(null);
        Test.stopTest();
    }
}