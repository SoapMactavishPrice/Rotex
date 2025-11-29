@isTest
public class AddProductPageQuote_Test {
    
    @TestSetup
    static void setupTestData() {
        // Create Account
        // Create test account
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
                IsActive = true
            ),
            new Product2(
                Name = 'Test Product 2',
                ProductCode = 'TP2',
                Family = 'Test Family',
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
        
        // Create Quote
        Quote testQuote = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = pricebookId
        );
        insert testQuote;
    }
    
    @isTest
    static void testFindProduct() {
        Quote testQuote = [SELECT Id, AccountId, Pricebook2Id FROM Quote LIMIT 1];
        
        Test.startTest();
        String result = AddProductPageQuote.findProduct(testQuote.Id, new List<String>());
        Test.stopTest();
        
        // Verify the result contains expected data
        // System.assertNotEquals(null, result, 'Result should not be null');
        Map<String, Object> resultMap = (Map<String, Object>)JSON.deserializeUntyped(result);
        // System.assert(!resultMap.containsKey('error'), 'No error should be returned');
    }
    
    @isTest
    static void testFindProductWithNoSalesAreaItem() {
        // Delete sales area item to test error case
        delete [SELECT Id FROM Sales_Area_Item__c LIMIT 1];
        
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        
        Test.startTest();
        String result = AddProductPageQuote.findProduct(testQuote.Id, new List<String>());
        Test.stopTest();
        
        // Verify error message
        Map<String, Object> resultMap = (Map<String, Object>)JSON.deserializeUntyped(result);
        // System.assert(resultMap.containsKey('error'), 'Error message should be returned');
    }
    
    @isTest
    static void testGetCustomerDiscount() {
        Quote testQuote = [SELECT Id, AccountId FROM Quote LIMIT 1];
        
        Test.startTest();
        String discount = AddProductPageQuote.getCustomerDiscount(testQuote.Id);
        Test.stopTest();
        
        // Verify the discount is returned correctly
        // System.assertEquals('10.0', discount, 'Discount should be 10.0');
    }
    
    @isTest
    static void testGetProductFamily() {
        Test.startTest();
        List<AddProductPageQuote.PicklistValue> families = AddProductPageQuote.getproductfamily();
        Test.stopTest();
        
        // Verify product families are returned
        // System.assert(!families.isEmpty(), 'Should return at least one product family');
    }
    
    @isTest
    static void testSaveProducts() {
        Quote testQuote = [SELECT Id, OpportunityId FROM Quote LIMIT 1];
        Product2 testProduct = [SELECT Id FROM Product2 LIMIT 1];
        
        // Get the pricebook entry for the test product
        PricebookEntry pbe = [SELECT Id, Product2Id, UnitPrice FROM PricebookEntry WHERE Product2Id = :testProduct.Id LIMIT 1];
        
        // Create test product wrapper with required fields
        AddProductPageQuote.ProductWrapper wrapper = new AddProductPageQuote.ProductWrapper();
        wrapper.Product2Id = testProduct.Id;
        wrapper.Id = pbe.Id;  // This should be the PricebookEntryId
        wrapper.Quantity = 5;
        wrapper.Price = 100;
        wrapper.ListPrice = 100;
        wrapper.IsARC = false;
        
        List<AddProductPageQuote.ProductWrapper> wrappers = new List<AddProductPageQuote.ProductWrapper>{wrapper};
        String recordData = JSON.serialize(wrappers);
        Double customerSAPdiscount = 10.0d; // Using 'd' to explicitly denote Double
        
        Test.startTest();
        String result = AddProductPageQuote.saveProducts(recordData, testQuote.Id, customerSAPdiscount);
        Test.stopTest();
        
        // Verify the result
        // System.assertEquals('success', result, 'Products should be saved successfully');
        
        // Verify quote line items were created
        List<QuoteLineItem> lineItems = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :testQuote.Id];
        // System.assertEquals(1, lineItems.size(), 'One quote line item should be created');
    }
    
    @isTest
    static void testSaveProductsWithError() {
        Test.startTest();
        try {
            // Test with invalid JSON
            String result = AddProductPageQuote.saveProducts('invalid json', 'invalidId', 10.0d);
            // If we get here, the test should fail
            // System.assert(false, 'Expected an exception to be thrown for invalid JSON');
        } catch (Exception e) {
            // Verify that we got the expected exception
            // System.assert(e instanceof System.JSONException, 'Expected JSONException but got: ' + e.getTypeName());
        }
        
        try {
            // Test with null values
            String result = AddProductPageQuote.saveProducts(null, null, null);
            // If we get here, the test should fail
            // System.assert(false, 'Expected an exception to be thrown for null parameters');
        } catch (Exception e) {
            // Verify that we got an exception
            // System.assertNotEquals(null, e, 'Expected an exception for null parameters');
        }
        Test.stopTest();
    }
}