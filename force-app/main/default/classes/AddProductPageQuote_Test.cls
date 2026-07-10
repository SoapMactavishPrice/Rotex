@isTest
public class AddProductPageQuote_Test {
    
    @TestSetup
    static void setupTestData() {
        // Create Account
        Account testAccount = new Account(
            Name = 'Test Account',
            BillingCountry = 'United States',
            Discount__c = 10
        );
        insert testAccount;
        
        // Activate Standard Pricebook
        Pricebook2 standardPricebook = new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
        );
        update standardPricebook;
        
        // Create Products
        Long timestamp = System.now().getTime();
        List<Product2> testProducts = new List<Product2>{
            new Product2(
                Name = 'Test Product 1 ' + timestamp,
                ProductCode = 'TP1_' + timestamp,
                Family = 'Test Family',
                IsActive = true
            ),
            new Product2(
                Name = 'Test Product 2 ' + timestamp,
                ProductCode = 'TP2_' + timestamp,
                Family = 'Test Family',
                IsActive = true
            )
        };
        insert testProducts;
        
        // Check if Standard Pricebook Entries already exist
        Map<Id, Product2> productMap = new Map<Id, Product2>(testProducts);
        List<PricebookEntry> existingStandardEntries = [
            SELECT Id, Product2Id
            FROM PricebookEntry
            WHERE Pricebook2Id = :Test.getStandardPricebookId()
            AND Product2Id IN :productMap.keySet()
        ];
        
        Set<Id> existingProductIds = new Set<Id>();
        for (PricebookEntry entry : existingStandardEntries) {
            existingProductIds.add(entry.Product2Id);
        }
        
        // Only insert Standard Pricebook Entries for products that don't already have one
        List<PricebookEntry> standardPbEntries = new List<PricebookEntry>();
        for(Product2 prod : testProducts) {
            if (!existingProductIds.contains(prod.Id)) {
                standardPbEntries.add(new PricebookEntry(
                    Pricebook2Id = standardPricebook.Id,
                    Product2Id = prod.Id,
                    UnitPrice = 100,
                    IsActive = true
                ));
            }
        }
        if (!standardPbEntries.isEmpty()) {
            insert standardPbEntries;
        }
        
        // Create Custom Pricebook
        Pricebook2 pb = new Pricebook2(
            Name = 'Test Pricebook ' + timestamp,
            IsActive = true,
            Distribution_Channel__c = '20'
        );
        insert pb;
        
        // Create Custom Pricebook Entries
        List<PricebookEntry> pbEntries = new List<PricebookEntry>();
        for(Product2 prod : testProducts) {
            pbEntries.add(new PricebookEntry(
                Pricebook2Id = pb.Id,
                Product2Id = prod.Id,
                UnitPrice = 100,
                IsActive = true,
                Distribution_Channel__c = '20',
                Sales_Org__c = '1100',
                CurrencyIsoCode = 'EUR'
            ));
        }
        insert pbEntries;
        
        // Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity ' + timestamp,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = testAccount.Id,
            Pricebook2Id = pb.Id
        );
        insert opp;
        
        // Create Quote
        Quote testQuote = new Quote(
            Name = 'Test Quote ' + timestamp,
            OpportunityId = opp.Id,
            Pricebook2Id = pb.Id
        );
        insert testQuote;
        
        // Create Sales Area Item with Distribution Channel matching Pricebook
        Sales_Area_Item__c salesAreaItem = new Sales_Area_Item__c(
            Name = 'Test Sales Area',
            Account__c = testAccount.Id,
            Sales_Org__c = '1100',
            Distribution_Channel__c = '20',
            Division__c = '10',
            Incoterms__c = 'CIF',
            CurrencyIsoCode = 'EUR'
        );
        insert salesAreaItem;
        
        // Create Incoterm
        Incoterm__c incoterm = new Incoterm__c(
            Name = 'CIF',
            Sales_Org__c = '1100',
            Distribution_Channel__c = '20',
            Division__c = '10',
            Valid_From__c = Date.today().addDays(-30),
            Valid_To__c = Date.today().addDays(30),
            Incoterm_Percent__c = 105.0,
            CurrencyIsoCode = 'EUR'
        );
        insert incoterm;
        
        // Create Plant Data
        List<Plant_Data__c> plantDataList = new List<Plant_Data__c>();
        for(Product2 prod : testProducts) {
            plantDataList.add(new Plant_Data__c(
                Plant__c = '1100',
                Product__c = prod.Id
            ));
        }
        insert plantDataList;
        
        // Create Customer ARC Pricing
        Customer_ARC_Pricing__c arcPricing = new Customer_ARC_Pricing__c(
            Customer__c = testAccount.Id,
            Material__c = testProducts[0].Id,
            Sales_Organization__c = '1100',
            Distribution_Channel__c = '20',
            Scale_Qty1__c = 10,
            Scale_Amt1__c = 100,
            Scale_Qty2__c = 20,
            Scale_Amt2__c = 190,
            Scale_Qty3__c = 30,
            Scale_Amt3__c = 270,
            Valid_To__c = system.today().addDays(30),
            CurrencyIsoCode = 'EUR'
        );
        insert arcPricing;
    }
    
    @isTest
    static void testFindProduct() {
        Quote testQuote = [SELECT Id, AccountId, Pricebook2Id FROM Quote LIMIT 1];
        
        Test.startTest();
        String result = AddProductPageQuote.findProduct(testQuote.Id, new List<String>(), '', 1);
        Test.stopTest();
    }
    
    @isTest
    static void testFindProductWithSearchKey() {
        Quote testQuote = [SELECT Id, AccountId, Pricebook2Id FROM Quote LIMIT 1];
        
        Test.startTest();
        String result = AddProductPageQuote.findProduct(testQuote.Id, new List<String>(), 'TP1', 1);
        Test.stopTest();
    }
    
    @isTest
    static void testFindProductWithBatchNo2() {
        Quote testQuote = [SELECT Id, AccountId, Pricebook2Id FROM Quote LIMIT 1];
        
        Test.startTest();
        String result = AddProductPageQuote.findProduct(testQuote.Id, new List<String>(), 'TP1', 2);
        Test.stopTest();
    }
    
    @isTest
    static void testFindProductWithNoSalesAreaItem() {
        delete [SELECT Id FROM Sales_Area_Item__c LIMIT 1];
        
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        
        Test.startTest();
        String result = AddProductPageQuote.findProduct(testQuote.Id, new List<String>(), '', 1);
        Test.stopTest();
    }
    
    @isTest
    static void testFindProductWithInvalidQuote() {
        Test.startTest();
        String result = AddProductPageQuote.findProduct('invalidQuoteId', new List<String>(), '', 1);
        Test.stopTest();
    }
    
    @isTest
    static void testGetCustomerDiscount() {
        Quote testQuote = [SELECT Id, AccountId FROM Quote LIMIT 1];
        
        Test.startTest();
        String discount = AddProductPageQuote.getCustomerDiscount(testQuote.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testGetCustomerDiscountWithInvalidId() {
        Test.startTest();
        try {
            String discount = AddProductPageQuote.getCustomerDiscount('invalidId');
        } catch (Exception e) {
            // Expected exception
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetProductFamily() {
        Test.startTest();
        List<AddProductPageQuote.PicklistValue> families = AddProductPageQuote.getproductfamily();
        Test.stopTest();
    }
    
    @isTest
    static void testSaveProducts() {
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        Product2 testProduct = [SELECT Id FROM Product2 LIMIT 1];
        
        PricebookEntry pbe = [SELECT Id, Product2Id, UnitPrice FROM PricebookEntry WHERE Product2Id = :testProduct.Id AND Pricebook2Id != :Test.getStandardPricebookId() LIMIT 1];
        
        AddProductPageQuote.ProductWrapper wrapper = new AddProductPageQuote.ProductWrapper();
        wrapper.Product2Id = testProduct.Id;
        wrapper.Id = pbe.Id;
        wrapper.Quantity = 5;
        wrapper.Price = 100;
        wrapper.ListPrice = 100;
        wrapper.IsARC = false;
        wrapper.Discount = 0;
        wrapper.LineDescription = 'Test Description';
        wrapper.Name = 'Test Product';
        wrapper.ProductCode = 'TP001';
        wrapper.CurrencyIsoCode = 'EUR';
        
        List<AddProductPageQuote.ProductWrapper> wrappers = new List<AddProductPageQuote.ProductWrapper>{wrapper};
        String recordData = JSON.serialize(wrappers);
        Double customerSAPdiscount = 10.0;
        
        Test.startTest();
        String result = AddProductPageQuote.saveProducts(recordData, testQuote.Id, customerSAPdiscount);
        Test.stopTest();
    }
    
    @isTest
    static void testSaveProductsWithMultipleProducts() {
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        List<Product2> testProducts = [SELECT Id FROM Product2];
        List<PricebookEntry> pbes = [SELECT Id, Product2Id, UnitPrice FROM PricebookEntry WHERE Product2Id IN :testProducts AND Pricebook2Id != :Test.getStandardPricebookId()];
        
        List<AddProductPageQuote.ProductWrapper> wrappers = new List<AddProductPageQuote.ProductWrapper>();
        
        for(Integer i = 0; i < testProducts.size(); i++) {
            AddProductPageQuote.ProductWrapper wrapper = new AddProductPageQuote.ProductWrapper();
            wrapper.Product2Id = testProducts[i].Id;
            wrapper.Id = pbes[i].Id;
            wrapper.Quantity = i + 1;
            wrapper.Price = 100;
            wrapper.ListPrice = 100;
            wrapper.IsARC = false;
            wrapper.Discount = 0;
            wrapper.Name = 'Test Product ' + i;
            wrapper.ProductCode = 'TP00' + i;
            wrapper.CurrencyIsoCode = 'EUR';
            wrappers.add(wrapper);
        }
        
        String recordData = JSON.serialize(wrappers);
        Double customerSAPdiscount = 10.0;
        
        Test.startTest();
        String result = AddProductPageQuote.saveProducts(recordData, testQuote.Id, customerSAPdiscount);
        Test.stopTest();
    }
    
    @isTest
    static void testSaveProductsWithARCProduct() {
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        Product2 testProduct = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :testProduct.Id AND Pricebook2Id != :Test.getStandardPricebookId() LIMIT 1];
        
        AddProductPageQuote.ProductWrapper wrapper = new AddProductPageQuote.ProductWrapper();
        wrapper.Product2Id = testProduct.Id;
        wrapper.Id = pbe.Id;
        wrapper.Quantity = 10;
        wrapper.Price = 100;
        wrapper.ListPrice = 100;
        wrapper.IsARC = true;
        wrapper.Discount = 0;
        wrapper.Name = 'Test ARC Product';
        wrapper.ProductCode = 'ARC001';
        wrapper.CurrencyIsoCode = 'EUR';
        
        List<AddProductPageQuote.ProductWrapper> wrappers = new List<AddProductPageQuote.ProductWrapper>{wrapper};
        String recordData = JSON.serialize(wrappers);
        Double customerSAPdiscount = 10.0;
        
        Test.startTest();
        String result = AddProductPageQuote.saveProducts(recordData, testQuote.Id, customerSAPdiscount);
        Test.stopTest();
    }
    
    @isTest
    static void testFindProductsOptimized() {
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        
        Test.startTest();
        List<String> result = AddProductPageQuote.findProductsOptimized(testQuote.Id, 'TP1', '');
        Test.stopTest();
    }
    
    @isTest
    static void testFindProductsOptimizedWithEmptySearch() {
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        
        Test.startTest();
        List<String> result = AddProductPageQuote.findProductsOptimized(testQuote.Id, '', '');
        Test.stopTest();
    }
    
    @isTest
    static void testFindProductsOptimizedWithItemType() {
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        
        Test.startTest();
        List<String> result = AddProductPageQuote.findProductsOptimized(testQuote.Id, 'TP1', 'Standard');
        Test.stopTest();
    }
    
    @isTest
    static void testFindProductsOptimizedNoSalesAreaItem() {
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        
        delete [SELECT Id FROM Sales_Area_Item__c LIMIT 1];
        
        Test.startTest();
        List<String> result = AddProductPageQuote.findProductsOptimized(testQuote.Id, 'TP1', '');
        Test.stopTest();
    }
    
    @isTest
    static void testBuildScaleList() {
        Customer_ARC_Pricing__c cap = [SELECT Id FROM Customer_ARC_Pricing__c LIMIT 1];
        
        cap.Scale_Qty4__c = 40;
        cap.Scale_Amt4__c = 340;
        cap.Scale_Qty5__c = 50;
        cap.Scale_Amt5__c = 400;
        update cap;
        
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        
        Test.startTest();
        List<String> result = AddProductPageQuote.findProductsOptimized(testQuote.Id, 'TP1', '');
        Test.stopTest();
    }
    
    @isTest
    static void testWrapperClass() {
        AddProductPageQuote.wrapperClass wc = new AddProductPageQuote.wrapperClass();
        wc.priceBook = 'Test Price Book';
        wc.productList = new List<AddProductPageQuote.ProductWrapper>();
        wc.chunkIndex = 0;
        wc.totalChunks = 3;
        wc.totalRecords = 100;
    }
    
    @isTest
    static void testProductWrapperClass() {
        AddProductPageQuote.ProductWrapper pw = new AddProductPageQuote.ProductWrapper();
        pw.Name = 'Test Product';
        pw.Id = 'testId';
        pw.ProductCode = 'TP001';
        pw.Quantity = 10;
        pw.Price = 100.50;
        pw.ListPrice = 100.50;
        pw.IsARC = false;
        pw.Discount = 5;
        pw.itemType = 'Test Type';
        pw.CurrencyIsoCode = 'EUR';
    }
    
    @isTest
    static void testPicklistValueClass() {
        AddProductPageQuote.PicklistValue pv = new AddProductPageQuote.PicklistValue('testValue', 'Test Label');
    }
}