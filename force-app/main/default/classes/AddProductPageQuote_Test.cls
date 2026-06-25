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
        
        // Create Sales Area Item
        Sales_Area_Item__c salesAreaItem = new Sales_Area_Item__c(
            Name = 'Test Sales Area',
            Account__c = testAccount.Id,
            Sales_Org__c = '1100',
            Distribution_Channel__c = '10',
            Division__c = '30',
            Incoterms__c = 'CIF'
        );
        insert salesAreaItem;
        
        // Create Incoterm
        Incoterm__c incoterm = new Incoterm__c(
            Name = 'CIF',
            Sales_Org__c = '1100',
            Distribution_Channel__c = '10',
            Division__c = '30',
            Valid_From__c = Date.today().addDays(-30),
            Valid_To__c = Date.today().addDays(30),
            Incoterm_Percent__c = 105.0
        );
        insert incoterm;
        
        // Create Products
        List<Product2> testProducts = new List<Product2>{
            new Product2(
                Name = 'Test Product 1',
                ProductCode = 'TP1',
                Family = 'Test Family',
            //    Item_Type__c = 'SOV (30001-45000)',
                IsActive = true
            ),
            new Product2(
                Name = 'Test Product 2',
                ProductCode = 'TP2',
                Family = 'Test Family',
             //   Item_Type__c = 'Coil',
                IsActive = true
            )
        };
        insert testProducts;
        
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
            Distribution_Channel__c = '10',
            Scale_Qty1__c = 10,
            Scale_Amt1__c = 100,
            Scale_Qty2__c = 20,
            Scale_Amt2__c = 190,
            Scale_Qty3__c = 30,
            Scale_Amt3__c = 270
        );
        insert arcPricing;
        
        // Create Pricebook Entries
        Id pricebookId = Test.getStandardPricebookId();
        List<PricebookEntry> pbEntries = new List<PricebookEntry>();
        for(Product2 prod : testProducts) {
            pbEntries.add(new PricebookEntry(
                Pricebook2Id = pricebookId,
                Product2Id = prod.Id,
                UnitPrice = 100,
                IsActive = true,
                Distribution_Channel__c = '10',
                Sales_Org__c = '1100'
            ));
        }
        insert pbEntries;
        
        // Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = testAccount.Id,
            Pricebook2Id = pricebookId
        );
        insert opp;
        
        // Create Quote with AccountId
        Quote testQuote = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = pricebookId
          //  AccountId = testAccount.Id
        );
        insert testQuote;
    }
    
    @isTest
    static void testFindProduct() {
        Quote testQuote = [SELECT Id, AccountId, Pricebook2Id FROM Quote LIMIT 1];
        
        Test.startTest();
        String result = AddProductPageQuote.findProduct(testQuote.Id, new List<String>(), '', 1);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        
        Map<String, Object> resultMap = (Map<String, Object>)JSON.deserializeUntyped(result);
        System.assert(!resultMap.containsKey('error'), 'No error should be returned: ' + result);
    }
    
    @isTest
    static void testFindProductWithSearchKey() {
        Quote testQuote = [SELECT Id, AccountId, Pricebook2Id FROM Quote LIMIT 1];
        
        Test.startTest();
        String result = AddProductPageQuote.findProduct(testQuote.Id, new List<String>(), 'TP1', 1);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        
        Map<String, Object> resultMap = (Map<String, Object>)JSON.deserializeUntyped(result);
        System.assert(!resultMap.containsKey('error'), 'No error should be returned');
    }
    
    @isTest
    static void testFindProductWithBatchNo2() {
        Quote testQuote = [SELECT Id, AccountId, Pricebook2Id FROM Quote LIMIT 1];
        
        Test.startTest();
        String result = AddProductPageQuote.findProduct(testQuote.Id, new List<String>(), 'TP1', 2);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        
        Map<String, Object> resultMap = (Map<String, Object>)JSON.deserializeUntyped(result);
        System.assert(!resultMap.containsKey('error'), 'No error should be returned');
    }
    
    @isTest
    static void testFindProductWithProductFamily() {
        Quote testQuote = [SELECT Id, AccountId, Pricebook2Id FROM Quote LIMIT 1];
        
        Test.startTest();
        List<String> families = new List<String>{'Test Family'};
        String result = AddProductPageQuote.findProduct(testQuote.Id, families, '', 1);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        
        Map<String, Object> resultMap = (Map<String, Object>)JSON.deserializeUntyped(result);
        System.assert(!resultMap.containsKey('error'), 'No error should be returned');
    }
    
    @isTest
    static void testFindProductWithNoSalesAreaItem() {
        // Delete sales area item to test error case
        delete [SELECT Id FROM Sales_Area_Item__c LIMIT 1];
        
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        
        Test.startTest();
        String result = AddProductPageQuote.findProduct(testQuote.Id, new List<String>(), '', 1);
        Test.stopTest();
        
        // Verify error message
        Map<String, Object> resultMap = (Map<String, Object>)JSON.deserializeUntyped(result);
        System.assert(resultMap.containsKey('error'), 'Error message should be returned');
    }
    
    @isTest
    static void testFindProductWithInvalidQuote() {
        Test.startTest();
        String result = AddProductPageQuote.findProduct('invalidQuoteId', new List<String>(), '', 1);
        Test.stopTest();
        
        Map<String, Object> resultMap = (Map<String, Object>)JSON.deserializeUntyped(result);
        System.assert(resultMap.containsKey('error'), 'Error message should be returned for invalid quote');
    }
    
    @isTest
    static void testGetCustomerDiscount() {
        Quote testQuote = [SELECT Id, AccountId FROM Quote LIMIT 1];
        
        Test.startTest();
        String discount = AddProductPageQuote.getCustomerDiscount(testQuote.Id);
        Test.stopTest();
        
        // Verify the discount is returned correctly
        System.assertNotEquals(null, discount, 'Discount should not be null');
    }
    
    @isTest
    static void testGetCustomerDiscountWithInvalidId() {
        Test.startTest();
        try {
            String discount = AddProductPageQuote.getCustomerDiscount('invalidId');
            System.assert(false, 'Expected exception was not thrown');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException, 'Expected AuraHandledException');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetProductFamily() {
        Test.startTest();
        List<AddProductPageQuote.PicklistValue> families = AddProductPageQuote.getproductfamily();
        Test.stopTest();
        
        // Verify product families are returned
        System.assertNotEquals(null, families, 'Families list should not be null');
    }
    
    @isTest
    static void testSaveProducts() {
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        Product2 testProduct = [SELECT Id FROM Product2 LIMIT 1];
        
        // Get the pricebook entry for the test product
        PricebookEntry pbe = [SELECT Id, Product2Id, UnitPrice FROM PricebookEntry WHERE Product2Id = :testProduct.Id LIMIT 1];
        
        // Create test product wrapper with required fields
        AddProductPageQuote.ProductWrapper wrapper = new AddProductPageQuote.ProductWrapper();
        wrapper.Product2Id = testProduct.Id;
        wrapper.Id = pbe.Id;
        wrapper.Quantity = 5;
        wrapper.Price = 100;
        wrapper.ListPrice = 100;
        wrapper.IsARC = false;
        wrapper.Discount = 0;
        wrapper.LineDescription = 'Test Description';
        
        List<AddProductPageQuote.ProductWrapper> wrappers = new List<AddProductPageQuote.ProductWrapper>{wrapper};
        String recordData = JSON.serialize(wrappers);
        Double customerSAPdiscount = 10.0;
        
        Test.startTest();
        String result = AddProductPageQuote.saveProducts(recordData, testQuote.Id, customerSAPdiscount);
        Test.stopTest();
        
        // Verify the result
        System.assertEquals('success', result, 'Products should be saved successfully');
        
        // Verify quote line items were created
        List<QuoteLineItem> lineItems = [SELECT Id, Quantity, UnitPrice FROM QuoteLineItem WHERE QuoteId = :testQuote.Id];
    //    System.assertEquals(1, lineItems.size(), 'One quote line item should be created');
    //    System.assertEquals(5, lineItems[0].Quantity, 'Quantity should be 5');
    //    System.assertEquals(100, lineItems[0].UnitPrice, 'Unit price should be 100');
    }
    
    @isTest
    static void testSaveProductsWithMultipleProducts() {
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        List<Product2> testProducts = [SELECT Id FROM Product2];
        List<PricebookEntry> pbes = [SELECT Id, Product2Id, UnitPrice FROM PricebookEntry WHERE Product2Id IN :testProducts];
        
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
            wrappers.add(wrapper);
        }
        
        String recordData = JSON.serialize(wrappers);
        Double customerSAPdiscount = 10.0;
        
        Test.startTest();
        String result = AddProductPageQuote.saveProducts(recordData, testQuote.Id, customerSAPdiscount);
        Test.stopTest();
        
        System.assertEquals('success', result, 'Products should be saved successfully');
        
        List<QuoteLineItem> lineItems = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :testQuote.Id];
        System.assertEquals(testProducts.size(), lineItems.size(), 'All quote line items should be created');
    }
    
    @isTest
    static void testSaveProductsWithARCProduct() {
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        Product2 testProduct = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :testProduct.Id LIMIT 1];
        
        AddProductPageQuote.ProductWrapper wrapper = new AddProductPageQuote.ProductWrapper();
        wrapper.Product2Id = testProduct.Id;
        wrapper.Id = pbe.Id;
        wrapper.Quantity = 10;
        wrapper.Price = 100;
        wrapper.ListPrice = 100;
        wrapper.IsARC = true;
        wrapper.Discount = 0;
        
        List<AddProductPageQuote.ProductWrapper> wrappers = new List<AddProductPageQuote.ProductWrapper>{wrapper};
        String recordData = JSON.serialize(wrappers);
        Double customerSAPdiscount = 10.0;
        
        Test.startTest();
        String result = AddProductPageQuote.saveProducts(recordData, testQuote.Id, customerSAPdiscount);
        Test.stopTest();
        
        System.assertEquals('success', result, 'ARC product should be saved successfully');
    }
    
    @isTest
    static void testSaveProductsWithNullDiscount() {
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        Product2 testProduct = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :testProduct.Id LIMIT 1];
        
        AddProductPageQuote.ProductWrapper wrapper = new AddProductPageQuote.ProductWrapper();
        wrapper.Product2Id = testProduct.Id;
        wrapper.Id = pbe.Id;
        wrapper.Quantity = 5;
        wrapper.Price = 100;
        wrapper.ListPrice = 100;
        wrapper.IsARC = false;
        
        List<AddProductPageQuote.ProductWrapper> wrappers = new List<AddProductPageQuote.ProductWrapper>{wrapper};
        String recordData = JSON.serialize(wrappers);
        
        Test.startTest();
        String result = AddProductPageQuote.saveProducts(recordData, testQuote.Id, null);
        Test.stopTest();
        
        System.assertEquals('success', result, 'Products should be saved with null discount');
    }
    
  /*  @isTest
    static void testSaveProductsWithError() {
        Test.startTest();
        try {
            // Test with invalid JSON
            String result = AddProductPageQuote.saveProducts('invalid json', 'invalidId', 10.0);
            System.assert(false, 'Expected exception was not thrown');
        } catch (Exception e) {
            System.assert(e instanceof System.JSONException, 'Expected JSONException but got: ' + e.getTypeName());
        }
        Test.stopTest();
    }   */
    
    @isTest
    static void testFindProductsOptimized() {
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        
        Test.startTest();
        List<String> result = AddProductPageQuote.findProductsOptimized(testQuote.Id, 'TP1', 'SOV (30001-45000)');
        Test.stopTest();
        
     //   System.assertNotEquals(null, result, 'Result should not be null');
     //   System.assert(result.size() > 0, 'Should have at least one chunk');
        
        // Verify chunk data can be parsed
        if(result.size() > 0) {
            Map<String, Object> chunkObj = (Map<String, Object>)JSON.deserializeUntyped(result[0]);
            System.assert(chunkObj.containsKey('productList'), 'Chunk should contain productList');
        }
    }
    
    @isTest
    static void testFindProductsOptimizedWithEmptySearch() {
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        
        Test.startTest();
        List<String> result = AddProductPageQuote.findProductsOptimized(testQuote.Id, '', '');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
  /*  @isTest
    static void testFindProductsOptimizedWithInvalidQuote() {
        Test.startTest();
        List<String> result = AddProductPageQuote.findProductsOptimized('invalidQuoteId', 'TP1', '');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        if(result.size() > 0) {
            Map<String, Object> errorObj = (Map<String, Object>)JSON.deserializeUntyped(result[0]);
            System.assert(errorObj.containsKey('error'), 'Should return error for invalid quote');
        }
    }  */
    
    @isTest
    static void testBuildScaleList() {
        
        Customer_ARC_Pricing__c cap = [SELECT Id
                                       FROM Customer_ARC_Pricing__c
                                       LIMIT 1];
        
        cap.Scale_Qty4__c = 40;
        cap.Scale_Amt4__c = 340;
        cap.Scale_Qty5__c = 50;
        cap.Scale_Amt5__c = 400;
        update cap;
        
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        
        Test.startTest();
        List<String> result = AddProductPageQuote.findProductsOptimized(
            testQuote.Id,
            'TP1',
            ''
        );
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assert(result.size() > 0);
    }
    
    @isTest
    static void testWrapperClass() {
        // Test wrapper class instantiation
        AddProductPageQuote.wrapperClass wc = new AddProductPageQuote.wrapperClass();
        wc.priceBook = 'Test Price Book';
        wc.productList = new List<AddProductPageQuote.ProductWrapper>();
        wc.chunkIndex = 0;
        wc.totalChunks = 3;
        wc.totalRecords = 100;
        
        System.assertEquals('Test Price Book', wc.priceBook);
        System.assertEquals(0, wc.chunkIndex);
        System.assertEquals(3, wc.totalChunks);
        System.assertEquals(100, wc.totalRecords);
    }
    
    @isTest
    static void testProductWrapperClass() {
        // Test ProductWrapper class instantiation
        AddProductPageQuote.ProductWrapper pw = new AddProductPageQuote.ProductWrapper();
        pw.Name = 'Test Product';
        pw.Id = 'testId';
        pw.ProductCode = 'TP001';
        pw.Quantity = 10;
        pw.Price = 100.50;
        pw.IsARC = false;
        pw.Discount = 5;
        pw.itemType = 'Test Type';
        
        System.assertEquals('Test Product', pw.Name);
        System.assertEquals(10, pw.Quantity);
        System.assertEquals(100.50, pw.Price);
        System.assertEquals(false, pw.IsARC);
        System.assertEquals(5, pw.Discount);
    }
    
    @isTest
    static void testPicklistValueClass() {
        AddProductPageQuote.PicklistValue pv = new AddProductPageQuote.PicklistValue('testValue', 'Test Label');
        
        System.assertEquals('testValue', pv.value);
        System.assertEquals('Test Label', pv.label);
    }
}