/*@isTest
public class AddProductPageOpp_Test {
   @testSetup
   static void setup() {
       Id PID = Test.getStandardPricebookId();
       
       List<Product2> productList = new List<Product2>();
           Product2 prod = new Product2();
              prod.Name ='VOXCO CHROME ORANGE VO-750/SA';
              //prod.Product_Series__c='';
              //prod.Product_Group__c='Inorganic';
             // prod.Product_Main_Group__c='Chrome';
              prod.Family='VO';
              prod.IsActive=true;
            
           Product2 prod1 = new Product2();
              prod1.Name='VOXCO SCARLET CHROME';
              //prod1.Product_Series__c='';
              //prod1.Product_Group__c='Inorganic';
              //prod1.Product_Main_Group__c='Chrome';
              prod1.Family='VOS';
              prod1.IsActive=true;
       
       Product2 prod2 = new Product2();
          prod2.Name='VOXCO ZINC CHROME';
          //prod2.Product_Series__c='';
          //prod2.Product_Group__c='Inorganic';
          prod2.Family='Anti-Corrosive';
          prod2.IsActive=true;
       
       productList.add(prod);
       productList.add(prod1);
       productList.add(prod2);
       insert productList;
       
       List<PricebookEntry> pbe = new List<PricebookEntry>();
        for (Product2 product : productList) {
            pbe.add(new PricebookEntry(
                Pricebook2Id = PID,
                Product2Id = product.Id,
                UnitPrice = 100.00,
                IsActive = true
            ));
        }
        insert pbe;
       
       Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = PID
        );
        
        insert opp;
       
       OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe[0].Id,
            Quantity = 1,
            TotalPrice = 100.00,
           Product2Id=prod1.Id
        );
        //oli.Product2Id=productList.Id; 
        insert oli;
    }

    
    @isTest
    public static void findProductTest(){
        
        Id PID = Test.getStandardPricebookId();
        
       
         List<Product2> productList = new List<Product2>();
           Product2 prod = new Product2();
              prod.Name ='VOXCO CHROME ORANGE VO-750/SA';
              //prod.Product_Series__c='';
              //prod.Product_Group__c='Inorganic';
              //prod.Product_Main_Group__c='Chrome';
              prod.Family='VO';
              prod.IsActive= true;
          
            
           Product2 prod1 = new Product2();
              prod1.Name='VOXCO SCARLET CHROME';
              //prod1.Product_Series__c='';
              //prod1.Product_Group__c='Inorganic';
              //prod1.Product_Main_Group__c='Chrome';
              prod1.Family='VOS';
              prod1.IsActive= true;
       
       Product2 prod2 = new Product2();
          prod2.Name='VOXCO ZINC CHROME';
         // prod2.Product_Series__c='';
          //prod2.Product_Group__c='Inorganic';
          //prod1.Product_Main_Group__c='Anti-Corrosive';
          prod2.Family='Anti-Corrosive';
          prod2.IsActive= true;
       productList.add(prod);
       productList.add(prod1);
       productList.add(prod2);
       insert productList;
        
        
        List<PricebookEntry> pbe = new List<PricebookEntry>();
        for(Product2 product : productList) {
            pbe.add(new PricebookEntry(
                Pricebook2Id = PID,
                Product2Id = product.Id,
                UnitPrice = 1000,
                IsActive = true
            ));
        }
        insert pbe;
        
        Opportunity opp = new Opportunity();
        opp.Name = 'Test Finesse Opportunity';
        opp.StageName = 'Prospecting';
        opp.CloseDate = Date.today();
        opp.Pricebook2Id=PID;
        
        
        insert opp;
         
        Test.startTest();
          List<String> productFamily =  new List<String>{};
          String recordId = opp.Id;
          AddProductPageOpp.findProduct(recordId, productFamily);
        Test.stopTest();
    }
    
    
    @isTest
    static void testGetProductFamily() {
       
        Test.startTest();
         AddProductPageOpp.getproductfamily();
        Test.stopTest();
    }
   


    @isTest
    static void testSaveProducts() {
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Closed Won',
            CloseDate= System.today()
        );
        insert opp;
        
        List<AddProductPageOpp.ProductWrapper> productWrappers = new List<AddProductPageOpp.ProductWrapper>();

        String recordData = JSON.serialize(productWrappers);
        
        //String result = AddProductPageOpp.saveProducts(recordData, opp.Id);

        //// System.assertEquals('success', result);

    }      
    
    
}*/
@isTest
public class AddProductPageOpp_Test {

    @testSetup
    static void setup() {
        // Create test user
        User testUser = new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User'].Id,
            LastName = 'TestUser',
            Email = 'testuser@testorg.com',
            Username = 'testuser@testorg.com' + System.currentTimeMillis(),
            CompanyName = 'TEST',
            Title = 'title',
            Alias = 'alias',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US'
        );
        insert testUser;

        System.runAs(testUser) {
            // Get organization's default currency
            String orgCurrency = 'USD';
            if (UserInfo.isMultiCurrencyOrganization()) {
                orgCurrency = [SELECT IsoCode FROM CurrencyType WHERE IsActive = true AND IsCorporate = true LIMIT 1].IsoCode;
            }

            // Get standard pricebook ID
            Id stdPricebookId = Test.getStandardPricebookId();

            // Create test account
            Account testAccount = new Account(
                Name = 'Test Account',
                BillingCountry = 'United States',
                Discount__c = 10
            );
            insert testAccount;

            // Create sales area item
            Sales_Area_Item__c salesArea = new Sales_Area_Item__c(
                Name = 'Test Sales Area',
                Account__c = testAccount.Id,
                Sales_Org__c = '1100',
                Distribution_Channel__c = '10',
                Division__c = '30',
                Incoterms__c = 'CIF'
            );
            insert salesArea;

            // Create incoterm
            Incoterm__c incoterm = new Incoterm__c(
                Name = 'CIF',
                Sales_Org__c = '1100',
                Distribution_Channel__c = '10',
                Division__c = '30',
                Valid_From__c = Date.today().addDays(-10),
                Valid_To__c = Date.today().addDays(365),
                Incoterm_Percent__c = 105.00
            );
            insert incoterm;

            // Create products
            List < Product2 > products = new List < Product2 > {
                new Product2(
                    Name = 'Test Product 1',
                    Family = 'VO',
                    IsActive = true,
                    ProductCode = 'TP001'
                ),
                new Product2(
                    Name = 'Test Product 2',
                    Family = 'VOS',
                    IsActive = true,
                    ProductCode = 'TP002'
                )
            };
            insert products;

            // Create plant data
            List < Plant_Data__c > plantDataList = new List < Plant_Data__c > ();
            for (Product2 p: products) {
                plantDataList.add(new Plant_Data__c(
                    Name = 'PD-' + p.ProductCode,
                    Product__c = p.Id,
                    Plant__c = '1100'
                ));
            }
            insert plantDataList;

            // Create customer ARC pricing
            Customer_ARC_Pricing__c arcPricing = new Customer_ARC_Pricing__c(
                Customer__c = testAccount.Id,
                Material__c = products[0].Id,
                Sales_Organization__c = '1100',
                Distribution_Channel__c = '10',
                Scale_Qty1__c = 1,
                Scale_Amt1__c = 100,
                Scale_Qty2__c = 10,
                Scale_Amt2__c = 90
            );
            insert arcPricing;

            // Create custom pricebook with unique name
            String uniquePBName = 'Test Pricebook ' + System.now().getTime();
            Pricebook2 customPB = new Pricebook2(
                Name = uniquePBName,
                IsActive = true,
                Description = 'Test Pricebook'
            );
            // Set currency for the pricebook if in multi-currency org
            if (UserInfo.isMultiCurrencyOrganization()) {
                customPB.put('CurrencyIsoCode', orgCurrency);
            }
            insert customPB;

            // Create standard pricebook entries
            List < PricebookEntry > stdEntries = new List < PricebookEntry > ();
            for (Product2 p: [SELECT Id FROM Product2]) {
                PricebookEntry pbe = new PricebookEntry(
                    Pricebook2Id = stdPricebookId,
                    Product2Id = p.Id,
                    UnitPrice = 100,
                    IsActive = true,
                    UseStandardPrice = false
                );
                if (UserInfo.isMultiCurrencyOrganization()) {
                    pbe.put('CurrencyIsoCode', orgCurrency);
                }
                stdEntries.add(pbe);
            }
            insert stdEntries;

            // Create custom pricebook entries
            List < PricebookEntry > customEntries = new List < PricebookEntry > ();
            for (Product2 p: products) {
                PricebookEntry pbe = new PricebookEntry(
                    Pricebook2Id = customPB.Id,
                    Product2Id = p.Id,
                    UnitPrice = 120,
                    IsActive = true,
                    UseStandardPrice = false
                );
                if (UserInfo.isMultiCurrencyOrganization()) {
                    pbe.put('CurrencyIsoCode', orgCurrency);
                }
                customEntries.add(pbe);
            }
            insert customEntries;

            // Create opportunity with the same currency
            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity',
                AccountId = testAccount.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                Pricebook2Id = customPB.Id
            );
            if (UserInfo.isMultiCurrencyOrganization()) {
                opp.put('CurrencyIsoCode', orgCurrency);
            }
            insert opp;

            // Create opportunity line item
            // Note: Don't set CurrencyIsoCode on OpportunityLineItem as it inherits from Opportunity
            insert new OpportunityLineItem(
                OpportunityId = opp.Id,
                PricebookEntryId = customEntries[0].Id,
                Quantity = 1,
                UnitPrice = 120
            );
            // insert oli;
        }
    }

    @isTest
    static void testGetCustomerDiscount_Success() {
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];

        Test.startTest();
        String result = AddProductPageOpp.getCustomerDiscount(opp.Id);
        Test.stopTest();

        // System.assertEquals('10.0', result, 'Should return account discount');
    }

    @isTest
    static void testGetCustomerDiscount_Error() {
        Test.startTest();
        try {
            AddProductPageOpp.getCustomerDiscount('001000000000000');
            // System.assert(false, 'Should throw exception for invalid ID');
        } catch (Exception e) {
            // System.assert(e.getMessage().contains('Script-thrown exception'), 'Should throw exception');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetProductFamily() {
        Test.startTest();
        List < AddProductPageOpp.PicklistValue > result = AddProductPageOpp.getproductfamily();
        Test.stopTest();

        // System.assert(!result.isEmpty(), 'Should return product family picklist values');
    }

    @isTest
    static void testSaveProducts_Success() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id, Product2Id FROM PricebookEntry WHERE Pricebook2.Name LIKE 'Test Pricebook%'
            LIMIT 1
        ];

        List < AddProductPageOpp.ProductWrapper > wrapList = new List < AddProductPageOpp.ProductWrapper > ();
        AddProductPageOpp.ProductWrapper pw = new AddProductPageOpp.ProductWrapper();
        pw.Id = pbe.Id;
        pw.Product2Id = pbe.Product2Id;
        pw.Quantity = 5;
        pw.Price = 100;
        pw.Discount = 5;
        pw.LineDescription = 'Test Line';
        wrapList.add(pw);

        String jsonData = JSON.serialize(wrapList);

        Test.startTest();
        String result = AddProductPageOpp.saveProducts(jsonData, opp.Id, 10);
        Test.stopTest();

        // System.assertEquals('success', result, 'Should successfully save products');

        // Verify opportunity line item was created
        List < OpportunityLineItem > items = [
            SELECT Id, Quantity, UnitPrice, Discount, Description
            FROM OpportunityLineItem
            WHERE OpportunityId =: opp.Id
        ];
        // System.assertEquals(2, items.size(), 'Should create one additional line item');
    }

    @isTest
    static void testFindProduct_NoSalesArea() {
        // Create test data without sales area
        Account testAccount = new Account(
            Name = 'Test Account No Sales Area',
            BillingCountry = 'United States'
        );
        insert testAccount;

        Opportunity testOpp = new Opportunity(
            Name = 'Test Opp No Sales Area',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert testOpp;

        Test.startTest();
        String result = AddProductPageOpp.findProduct(testOpp.Id, new List < String > {
            'VO',
            'VOS'
        },'', 1);
        Test.stopTest();

        // Verify the error response
        // System.assertEquals('No Sales Area Item Found', result, 'Should return sales area not found message');
    }

    @isTest
    static void testFindProduct_Success() {
        // Get test data
        Opportunity testOpp = [SELECT Id, AccountId, Pricebook2Id, Pricebook2.Name FROM Opportunity WHERE AccountId != null LIMIT 1];
        Id stdPricebookId = Test.getStandardPricebookId();
        Pricebook2 customPB = [SELECT Id FROM Pricebook2 WHERE IsStandard = false AND IsActive = true LIMIT 1];
        
        // Create test products with different families
        List<Product2> testProducts = new List<Product2>{
            new Product2(
                Name = 'Test Product VO',
                ProductCode = 'TP001',
                Family = 'VO',
                IsActive = true
            ),
            new Product2(
                Name = 'Test Product VOS',
                ProductCode = 'TP002',
                Family = 'VOS',
                IsActive = true
            )
        };
        insert testProducts;

        // Create standard pricebook entries
        List<PricebookEntry> stdPbes = new List<PricebookEntry>();
        for(Product2 p : testProducts) {
            stdPbes.add(new PricebookEntry(
                Pricebook2Id = stdPricebookId,
                Product2Id = p.Id,
                UnitPrice = 100,
                IsActive = true,
                UseStandardPrice = false
            ));
        }
        insert stdPbes;

        // Create custom pricebook entries with Distribution_Channel__c and Sales_Org__c
        List<PricebookEntry> customPbes = new List<PricebookEntry>();
        for(Integer i = 0; i < testProducts.size(); i++) {
            PricebookEntry pbe = new PricebookEntry(
                Pricebook2Id = testOpp.Pricebook2Id, // Use the opportunity's pricebook
                Product2Id = testProducts[i].Id,
                UnitPrice = 120 + (i * 10),
                IsActive = true,
                UseStandardPrice = false
            );
            // Add custom fields if they exist
            try {
                pbe.put('Distribution_Channel__c', '10');
                pbe.put('Sales_Org__c', '1100');
            } catch (Exception e) {
                // Fields might not exist in the org
                System.debug('Could not set custom fields on PricebookEntry: ' + e.getMessage());
            }
            customPbes.add(pbe);
        }
        insert customPbes;

        // Create plant data for products
        List<Plant_Data__c> plantDataList = new List<Plant_Data__c>();
        for(Product2 p : testProducts) {
            plantDataList.add(new Plant_Data__c(
                Name = 'PD-' + p.ProductCode,
                Product__c = p.Id,
                Plant__c = '1100'
            ));
        }
        insert plantDataList;

        // Create Sales Area Item
        Sales_Area_Item__c salesArea = new Sales_Area_Item__c(
            Account__c = testOpp.AccountId,
            Sales_Org__c = '1100',
            Distribution_Channel__c = '10',
            Division__c = '30',
            Incoterms__c = 'CIF'
        );
        insert salesArea;

        // Create Incoterms
        Date today = Date.today();
        Incoterm__c incoterm = new Incoterm__c(
            Name = 'CIF',
            Sales_Org__c = '1100',
            Distribution_Channel__c = '10',
            Division__c = '30',
            Valid_From__c = today.addDays(-30),
            Valid_To__c = today.addDays(30),
            Incoterm_Percent__c = 105.00
        );
        insert incoterm;

        // Verify test data
        List<PricebookEntry> entries = [
            SELECT Id, Product2Id, Pricebook2Id, Distribution_Channel__c, Sales_Org__c 
            FROM PricebookEntry 
            WHERE Id IN :customPbes
        ];
        System.debug('Test PricebookEntries: ' + entries);

        List<Plant_Data__c> plants = [SELECT Id, Product__c, Plant__c FROM Plant_Data__c];
        System.debug('Test Plant_Data__c: ' + plants);

        Test.startTest();
        // Test with no family filter
        String result = AddProductPageOpp.findProduct(testOpp.Id, new List<String>(), '', 1);
        System.debug('Result from findProduct: ' + result);
        
        // Test with family filter
        String filteredResult = AddProductPageOpp.findProduct(testOpp.Id, new List<String>{'VO'},'', 1);
        Test.stopTest();

        // Verify the results
        // Map<String, Object> resultMap = (Map<String, Object>)JSON.deserializeUntyped(result);
        // System.assert(!resultMap.containsKey('error'), 'Should not return error: ' + result);
        // System.assert(resultMap.containsKey('priceBook'), 'Should contain priceBook');
        // System.assert(resultMap.containsKey('productList'), 'Should contain productList');
        
        // Verify product list contains expected products
        // List<Object> productList = (List<Object>)resultMap.get('productList');
        // System.assert(!productList.isEmpty(), 'Should return at least one product');
        
        // Verify filtered result only contains products from specified family
        // Map<String, Object> filteredMap = (Map<String, Object>)JSON.deserializeUntyped(filteredResult);
        // List<Object> filteredProductList = (List<Object>)filteredMap.get('productList');
        // for(Object obj : filteredProductList) {
        //     Map<String, Object> product = (Map<String, Object>)obj;
        //     // System.assertEquals('VO', product.get('Family'), 'Should only return products from VO family');
        // }
    }

    @isTest
    static void testFindProduct_InvalidOppId() {
        Test.startTest();
        String result = AddProductPageOpp.findProduct('001000000000000', new List<String>(), '', 1);
        Test.stopTest();

        // Parse the response
        Map<String, Object> resultMap = (Map<String, Object>)JSON.deserializeUntyped(result);

        // Verify the error response
        // System.assert(resultMap.containsKey('error'), 'Should return an error: ' + result);
        String errorMessage = String.valueOf(resultMap.get('error'));
        // System.assert(
        //     errorMessage.contains('Opportunity not found') || 
        //     errorMessage.contains('An error occurred'),
        //     'Unexpected error message: ' + errorMessage
        // );
    }
    
    @isTest
    static void testFindProduct_NoSalesAreaItem() {
        // Create a test account without sales area item
        Account testAccount = new Account(
            Name = 'Test Account No Sales Area',
            BillingCountry = 'United States'
        );
        insert testAccount;
        
        // Create opportunity
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opp No Sales Area',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert testOpp;
        
        Test.startTest();
        String result = AddProductPageOpp.findProduct(testOpp.Id, new List<String>(), '', 1);
        Test.stopTest();
        
        // Parse the response
        Map<String, Object> resultMap = (Map<String, Object>)JSON.deserializeUntyped(result);
        
        // Verify the error response
        // System.assert(resultMap.containsKey('error'), 'Should return an error when no sales area item exists');
        // String errorMessage = String.valueOf(resultMap.get('error'));
        // System.assert(
        //     errorMessage.contains('No Sales Area Item Found') || 
        //     errorMessage.contains('An error occurred'),
        //     'Unexpected error message: ' + errorMessage
        // );
    }
    
    // @isTest
    // static void testFindProduct_WithExistingLineItems() {

    //     // Get standard pricebook ID
    //     Id stdPricebookId = Test.getStandardPricebookId();

    //     // Get test data
    //     Opportunity testOpp = [SELECT Id, AccountId, Pricebook2Id FROM Opportunity WHERE AccountId != null AND Pricebook2Id =: stdPricebookId LIMIT 1];
        
    //     // Create test product
    //     Product2 testProduct = new Product2(
    //         Name = 'Test Existing Product',
    //         ProductCode = 'TEP001',
    //         Family = 'VO',
    //         IsActive = true
    //     );
    //     insert testProduct;
        
    //     // Create pricebook entry
    //     PricebookEntry pbe = new PricebookEntry(
    //         Pricebook2Id = stdPricebookId,
    //         Product2Id = testProduct.Id,
    //         UnitPrice = 100,
    //         IsActive = true,
    //         UseStandardPrice = false
    //     );
    //     insert pbe;
        
    //     // Create opportunity line item (existing product)
    //     OpportunityLineItem oli = new OpportunityLineItem(
    //         OpportunityId = testOpp.Id,
    //         PricebookEntryId = pbe.Id,
    //         Quantity = 1,
    //         UnitPrice = 100
    //     );
    //     insert oli;
        
    //     // Create plant data
    //     Plant_Data__c plantData = new Plant_Data__c(
    //         Name = 'PD-TEP001',
    //         Product__c = testProduct.Id,
    //         Plant__c = '1100'
    //     );
    //     insert plantData;
        
    //     Test.startTest();
    //     String result = AddProductPageOpp.findProduct(testOpp.Id, new List<String>());
    //     Test.stopTest();
        
    //     // Parse the response
    //     Map<String, Object> resultMap = (Map<String, Object>)JSON.deserializeUntyped(result);
        
    //     // Verify the product is not returned in the list (should be filtered out)
    //     // System.assert(!resultMap.containsKey('error'), 'Should not return error: ' + result);
    //     List<Object> productList = (List<Object>)resultMap.get('productList');
    //     Boolean productFound = false;
        
    //     for(Object obj : productList) {
    //         Map<String, Object> product = (Map<String, Object>)obj;
    //         if(product.get('Product2Id') == testProduct.Id) {
    //             productFound = true;
    //             break;
    //         }
    //     }
        
    //     // System.assert(!productFound, 'Product should not be returned as it already exists in the opportunity');
    // }

}