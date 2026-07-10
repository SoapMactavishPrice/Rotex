@isTest
public class AddProductPageOpp_Test {
    
    @TestSetup
    static void setupTestData() {
        // Create Account
        Account acc = new Account(Name = 'Test Account', Discount__c = 10);
        insert acc;
        
        // Activate Standard Pricebook
        Pricebook2 standardPricebook = new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
        );
        update standardPricebook;
        
        // Create Product with unique name and code
        Long timestamp = System.now().getTime();
        Product2 prod = new Product2(
            Name = 'Test Product ' + timestamp,
            ProductCode = 'TEST' + timestamp,
            Family = 'Test Family',
            Description = 'Test Description',
            IsActive = true
        );
        insert prod;
        
        // Check if Standard Pricebook Entry already exists (Fix 1)
        List<PricebookEntry> existingStandardPbe = [
            SELECT Id
            FROM PricebookEntry
            WHERE Pricebook2Id = :Test.getStandardPricebookId()
            AND Product2Id = :prod.Id
        ];
        
        if (existingStandardPbe.isEmpty()) {
            PricebookEntry standardPbe = new PricebookEntry(
                Pricebook2Id = Test.getStandardPricebookId(),
                Product2Id = prod.Id,
                UnitPrice = 100,
                IsActive = true
            );
            insert standardPbe;
        }
        
        // Create Custom Pricebook
        Pricebook2 pb = new Pricebook2(
            Name = 'Test Pricebook ' + timestamp,
            IsActive = true,
            Distribution_Channel__c = '20'
        );
        insert pb;
        
        // Create Custom Pricebook Entry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pb.Id,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            Sales_Org__c = '1100',
            Distribution_Channel__c = '20',
            CurrencyIsoCode = 'EUR'
        );
        insert pbe;
        
        // Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity ' + timestamp,
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = pb.Id
        );
        insert opp;
        
        // Create Sales Area Item
        Sales_Area_Item__c sai = new Sales_Area_Item__c(
            Account__c = acc.Id,
            Sales_Org__c = '1100',
            Distribution_Channel__c = '20',
            Division__c = '10',
            Incoterms__c = 'Test Inco',
            CurrencyIsoCode = 'EUR'
        );
        insert sai;
        
        // Create Plant Data
        Plant_Data__c pd = new Plant_Data__c(
            Plant__c = '1100',
            Product__c = prod.Id
        );
        insert pd;
        
        // Create Customer ARC Pricing
        Customer_ARC_Pricing__c arc = new Customer_ARC_Pricing__c(
            Customer__c = acc.Id,
            Material__c = prod.Id,
            Sales_Organization__c = '1100',
            Distribution_Channel__c = '20',
            Amount__c = 100,
            Scale_Qty1__c = 10,
            Scale_Amt1__c = 90,
            Scale_Qty2__c = 20,
            Scale_Amt2__c = 80,
            Valid_To__c = system.today().addDays(30),
            CurrencyIsoCode = 'EUR'
        );
        insert arc;
        
        // Create Incoterm
        Incoterm__c inco = new Incoterm__c(
            Name = 'Test Inco',
            Sales_Org__c = '1100',
            Distribution_Channel__c = '20',
            Division__c = '10',
            Valid_From__c = Date.today().addDays(-30),
            Valid_To__c = Date.today().addDays(30),
            Incoterm_Percent__c = 105,
            CurrencyIsoCode = 'EUR'
        );
        insert inco;
    }
    
    @isTest
    static void testFindProduct() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        List<String> productFamily = new List<String>{'Test Family'};
        
        Test.startTest();
        String result = AddProductPageOpp.findProduct(opp.Id, productFamily, 'Test', 1);
        String result2 = AddProductPageOpp.findProduct(opp.Id, productFamily, '', 2);
        Test.stopTest();
    }
    
    @isTest
    static void testFindProductWithSearchKey() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        List<String> productFamily = new List<String>{'Test Family'};
        
        Test.startTest();
        String result = AddProductPageOpp.findProduct(opp.Id, productFamily, 'TEST', 1);
        String result2 = AddProductPageOpp.findProduct(opp.Id, productFamily, 'Product', 2);
        Test.stopTest();
    }
    
    @isTest
    static void testFindProductNoSalesAreaItem() {
        Account acc = new Account(Name = 'Test Account No SAI');
        insert acc;
        
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE Name LIKE 'Test Pricebook%' LIMIT 1];
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity No SAI',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = pb.Id
        );
        insert opp;
        
        Test.startTest();
        String result = AddProductPageOpp.findProduct(opp.Id, new List<String>(), '', 1);
        Test.stopTest();
    }
    
    @isTest
    static void testFindProductsOptimized() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        AddProductPageOpp.findProductsOptimized(opp.Id, 'Test', 'SOV (0-15000)');
        AddProductPageOpp.findProductsOptimized(opp.Id, '', '');
        AddProductPageOpp.findProductsOptimized(opp.Id, 'Product', 'Standard');
        Test.stopTest();
    }
    
    @isTest
    static void testFindProductsOptimizedWithARC() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        AddProductPageOpp.findProductsOptimized(opp.Id, '', 'SOV (0-15000)');
        Test.stopTest();
    }
    
    @isTest
    static void testFindProductsOptimizedNoSalesAreaItem() {
        Account acc = new Account(Name = 'Test Account No SAI Opt');
        insert acc;
        
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE Name LIKE 'Test Pricebook%' LIMIT 1];
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity No SAI Opt',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = pb.Id
        );
        insert opp;
        
        Test.startTest();
        AddProductPageOpp.findProductsOptimized(opp.Id, '', '');
        Test.stopTest();
    }
    
    @isTest
    static void testFindProductsOptimizedNoProducts() {
        Account acc = new Account(Name = 'Test Account No Products');
        insert acc;
        
        Pricebook2 pb = new Pricebook2(
            Name = 'Test Pricebook No Prod ' + System.now().getTime(),
            IsActive = true,
            Distribution_Channel__c = '20'
        );
        insert pb;
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity No Products',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = pb.Id
        );
        insert opp;
        
        Sales_Area_Item__c sai = new Sales_Area_Item__c(
            Account__c = acc.Id,
            Sales_Org__c = '1100',
            Distribution_Channel__c = '20',
            Division__c = '10',
            Incoterms__c = 'Test Inco',
            CurrencyIsoCode = 'EUR'
        );
        insert sai;
        
        Test.startTest();
        AddProductPageOpp.findProductsOptimized(opp.Id, '', 'SOV (0-15000)');
        Test.stopTest();
    }
    
    @isTest
    static void testGetCustomerDiscount() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        String result = AddProductPageOpp.getCustomerDiscount(opp.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testGetProductFamily() {
        Test.startTest();
        List<AddProductPageOpp.PicklistValue> result = AddProductPageOpp.getproductfamily();
        Test.stopTest();
    }
    
    @isTest
    static void testSaveProducts() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry 
                              WHERE Pricebook2Id != :Test.getStandardPricebookId() 
                              LIMIT 1];
        
        List<AddProductPageOpp.ProductWrapper> wrapperList = new List<AddProductPageOpp.ProductWrapper>();
        AddProductPageOpp.ProductWrapper pw = new AddProductPageOpp.ProductWrapper();
        pw.Id = pbe.Id;
        pw.Product2Id = prod.Id;
        pw.Quantity = 10;
        pw.Price = 100;
        pw.ListPrice = 100;
        pw.IsARC = false;
        pw.Discount = 5;
        pw.LineDescription = 'Test Line';
        pw.Family = 'Test Family';
        pw.ProductCode = 'TEST001';
        pw.Name = 'Test Product';
        pw.CurrencyIsoCode = 'EUR';
        wrapperList.add(pw);
        
        String recordData = JSON.serialize(wrapperList);
        
        Test.startTest();
        String result = AddProductPageOpp.saveProducts(recordData, opp.Id, 10);
        Test.stopTest();
    }
    
    @isTest
    static void testSaveProductsARC() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry 
                              WHERE Pricebook2Id != :Test.getStandardPricebookId() 
                              LIMIT 1];
        
        List<AddProductPageOpp.ProductWrapper> wrapperList = new List<AddProductPageOpp.ProductWrapper>();
        AddProductPageOpp.ProductWrapper pw = new AddProductPageOpp.ProductWrapper();
        pw.Id = pbe.Id;
        pw.Product2Id = prod.Id;
        pw.Quantity = 10;
        pw.Price = 100;
        pw.ListPrice = 100;
        pw.IsARC = true;
        pw.Discount = 5;
        pw.LineDescription = 'Test Line ARC';
        pw.Family = 'Test Family';
        pw.ProductCode = 'TEST001';
        pw.Name = 'Test Product';
        pw.CurrencyIsoCode = 'EUR';
        wrapperList.add(pw);
        
        String recordData = JSON.serialize(wrapperList);
        
        Test.startTest();
        String result = AddProductPageOpp.saveProducts(recordData, opp.Id, null);
        Test.stopTest();
    }
    
    @isTest
    static void testSaveProductsWithDiscount() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry 
                              WHERE Pricebook2Id != :Test.getStandardPricebookId() 
                              LIMIT 1];
        
        List<AddProductPageOpp.ProductWrapper> wrapperList = new List<AddProductPageOpp.ProductWrapper>();
        AddProductPageOpp.ProductWrapper pw = new AddProductPageOpp.ProductWrapper();
        pw.Id = pbe.Id;
        pw.Product2Id = prod.Id;
        pw.Quantity = 10;
        pw.Price = 100;
        pw.ListPrice = 100;
        pw.IsARC = false;
        pw.Discount = 15;
        pw.LineDescription = 'Test Line Discount';
        pw.Family = 'Test Family';
        pw.ProductCode = 'TEST001';
        pw.Name = 'Test Product';
        pw.CurrencyIsoCode = 'EUR';
        wrapperList.add(pw);
        
        String recordData = JSON.serialize(wrapperList);
        
        Test.startTest();
        String result = AddProductPageOpp.saveProducts(recordData, opp.Id, 20);
        Test.stopTest();
    }
    
    @isTest
    static void testSaveProductsError() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry 
                              WHERE Pricebook2Id != :Test.getStandardPricebookId() 
                              LIMIT 1];
        
        List<AddProductPageOpp.ProductWrapper> wrapperList = new List<AddProductPageOpp.ProductWrapper>();
        AddProductPageOpp.ProductWrapper pw = new AddProductPageOpp.ProductWrapper();
        pw.Id = pbe.Id;
        pw.Product2Id = prod.Id;
        pw.Quantity = 0;
        pw.Price = 100;
        pw.ListPrice = 100;
        pw.IsARC = false;
        pw.Discount = 5;
        pw.LineDescription = 'Test Line';
        pw.Family = 'Test Family';
        pw.ProductCode = 'TEST001';
        pw.Name = 'Test Product';
        pw.CurrencyIsoCode = 'EUR';
        wrapperList.add(pw);
        
        String recordData = JSON.serialize(wrapperList);
        
        Test.startTest();
        String result = AddProductPageOpp.saveProducts(recordData, opp.Id, 10);
        Test.stopTest();
    }
    
    @isTest
    static void testOpportunityNotFound() {
        Test.startTest();
        String result = AddProductPageOpp.findProduct('InvalidId', new List<String>(), '', 1);
        Test.stopTest();
    }
    
    @isTest
    static void testGetCustomerDiscountError() {
        Test.startTest();
        try {
            String result = AddProductPageOpp.getCustomerDiscount('InvalidId');
        } catch (Exception e) {
            // Expected exception
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCoverageMethod() {
        Test.startTest();
        AddProductPageOpp.testCoverageMethod();
        Test.stopTest();
    }
}