@IsTest
public class ProductControllerTest {

    @TestSetup
    static void setupData() {
        // Find an existing internal User with a Role to create the Portal Account
        List<User> adminUsers = [SELECT Id FROM User WHERE UserRoleId != null AND IsActive = true AND UserType = 'Standard' LIMIT 1];
        User runUser = adminUsers.isEmpty() ? new User(Id = UserInfo.getUserId()) : adminUsers[0];
        
        System.runAs(runUser) {
            // Create CP Account
            Account cpAcc = new Account(
                Name = 'Test Partner',
                RecordTypeId = getRecordTypeId('Account', 'Channel_Partner')
            );
            insert cpAcc;
            
            // Create CP Contact
            Contact cpContact = new Contact(
                LastName = 'Partner Contact',
                AccountId = cpAcc.Id,
                Email = 'partner@example.com'
            );
            insert cpContact;
            
            // Create Partner User
            Profile partnerProfile = [SELECT Id FROM Profile WHERE Name IN ('Partner Community User', 'Partner Community Login User') LIMIT 1];
            
            String uniqueName = String.valueOf(DateTime.now().getTime());
            User partnerUser = new User(
                Alias = 'part',
                Email = 'partner@example.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'PartnerTest',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = partnerProfile.Id,
                ContactId = cpContact.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                Username = 'partneruser' + uniqueName + '@testorg.com'
            );
            insert partnerUser;
            
            // Ensure Standard Pricebook is active
            Id standardPbId = Test.getStandardPricebookId();
            update new Pricebook2(Id = standardPbId, IsActive = true);
        }
    }
    
    private static User getPartnerUser() {
        return [SELECT Id, AccountId FROM User WHERE LastName = 'PartnerTest' LIMIT 1];
    }

    @IsTest
    static void testGetCurrencyPicklistValues() {
        Test.startTest();
        List<Map<String, String>> currencies = ProductController.getCurrencyPicklistValues();
        Test.stopTest();

        System.assertNotEquals(null, currencies, 'Should return currency values');
    }

    @IsTest
    static void testGetMyChannelPartnerAccountId() {
        Test.startTest();
        Id partnerId = ProductController.getMyChannelPartnerAccountId();
        Test.stopTest();
        // Since test runs as standard user without portal account, this will be null
        System.assertEquals(null, partnerId, 'Standard user should not have partner account');
    }

    @IsTest
    static void testGetMyProducts_Empty() {
        Test.startTest();
        List<ProductController.ProductWrapper> products = ProductController.getMyProducts();
        Test.stopTest();
        
        System.assertEquals(0, products.size(), 'Should return empty list for standard user');
    }

    @IsTest
    static void testProductLifecycle_CreateAndUpdate() {
        Account partner = [SELECT Id FROM Account WHERE Name = 'Test Partner' LIMIT 1];

        ProductController.ProductCreateInput input = new ProductController.ProductCreateInput();
        input.name = 'Test New Product';
        input.productCode = '12345';
        input.description = 'Test Description';
        input.isActive = true;
        input.hsnCode = 'HSN-123';
        input.partnerAccountId = partner.Id;
        
        // Add Price Information
        ProductController.PriceEntryInput priceEntry = new ProductController.PriceEntryInput();
        priceEntry.currencyIsoCode = 'INR';
        priceEntry.unitPrice = 150.00;
        priceEntry.validFrom = String.valueOf(Date.today());
        priceEntry.validTo = String.valueOf(Date.today().addDays(30));
        input.priceEntries = new List<ProductController.PriceEntryInput>{ priceEntry };

        User partnerUser = getPartnerUser();
        
        System.runAs(partnerUser) {
            Test.startTest();
            // Test Create Product
            ProductController.ProductWrapper created = ProductController.createProduct(input);
            
            System.assertNotEquals(null, created, 'Product should be created');
            System.assertNotEquals(null, created.id, 'Product Id should be populated');
            System.assertEquals('CP12345', created.productCode, 'Product Code should be prefixed with CP');
            System.assertEquals('Test New Product', created.name, 'Name should match');
            System.assertEquals('HSN-123', created.hsnCode, 'HSN Code should match');
    
            // Test Update Product
            input.productId = created.id;
            input.name = 'Updated Product Name';
            input.hsnCode = 'HSN-999';
            
            ProductController.PriceEntryInput priceEntryUpdate = new ProductController.PriceEntryInput();
            priceEntryUpdate.currencyIsoCode = 'INR';
            priceEntryUpdate.unitPrice = 200.00; // changed price
            priceEntryUpdate.validFrom = String.valueOf(Date.today());
            priceEntryUpdate.validTo = String.valueOf(Date.today().addDays(60));
            input.priceEntries = new List<ProductController.PriceEntryInput>{ priceEntryUpdate };
    
            ProductController.ProductWrapper updated = ProductController.updateProduct(input);
            Test.stopTest();
    
            System.assertEquals('Updated Product Name', updated.name, 'Name should be updated');
            System.assertEquals('HSN-999', updated.hsnCode, 'HSN Code should be updated');
            System.assertEquals(1, updated.priceEntries.size(), 'Should still have 1 price entry');
            System.assertEquals(200.00, updated.priceEntries[0].unitPrice, 'Price should be updated');
        }
    }

    @IsTest
    static void testGetRotexProductExtras() {
        Product2 p = new Product2(
            Name = 'Rotex Item',
            ProductCode = 'ROTEX-1',
            Description = 'Rotex Desc',
            IsActive = true
        );
        insert p;

        Plant_Data__c pd = new Plant_Data__c(
            Product__c = p.Id,
            Plant__c = '1100',
            HSN_Code__c = 'HSN-ROTEX',
            Name = 'ROTEX-1'
        );
        insert pd;

        Test.startTest();
        Map<String, Object> extras = ProductController.getRotexProductExtras(p.Id);
        Test.stopTest();

        System.assertNotEquals(null, extras, 'Should return extras map');
        System.assertEquals('Rotex Desc', (String) extras.get('description'), 'Description should match');
        System.assertEquals('HSN-ROTEX', (String) extras.get('hsnCode'), 'HSN Code should match');
    }
    
    @IsTest
    static void testExceptions() {
        Account partner = [SELECT Id FROM Account WHERE Name = 'Test Partner' LIMIT 1];
        
        ProductController.ProductCreateInput input = new ProductController.ProductCreateInput();
        // Missing name
        try {
            ProductController.createProduct(input);
            System.assert(false, 'Should throw exception for missing name');
        } catch (AuraHandledException e) {}
        
        input.name = 'Test Name';
        // Missing code
        try {
            ProductController.createProduct(input);
            System.assert(false, 'Should throw exception for missing code');
        } catch (AuraHandledException e) {}
        
        input.productCode = '123';
        // Missing description
        try {
            ProductController.createProduct(input);
            System.assert(false, 'Should throw exception for missing description');
        } catch (AuraHandledException e) {}
        
        input.description = 'Desc';
        // Missing isActive
        try {
            ProductController.createProduct(input);
            System.assert(false, 'Should throw exception for missing isActive');
        } catch (AuraHandledException e) {}
        
        input.isActive = true;
        // Missing partner account
        try {
            ProductController.createProduct(input);
            System.assert(false, 'Should throw exception for missing partner account if not portal user');
        } catch (AuraHandledException e) {}
        
        input.partnerAccountId = partner.Id;
        
        // No price entries
        try {
            ProductController.createProduct(input);
            System.assert(false, 'Should throw exception for missing price entries');
        } catch (AuraHandledException e) {}
        
        // Add valid price entry
        ProductController.PriceEntryInput priceEntry = new ProductController.PriceEntryInput();
        priceEntry.currencyIsoCode = 'INR';
        priceEntry.unitPrice = 100.00;
        input.priceEntries = new List<ProductController.PriceEntryInput>{ priceEntry };
        
        ProductController.createProduct(input); // Succeeds
        
        // Try creating duplicate product code
        try {
            ProductController.createProduct(input);
            System.assert(false, 'Should throw exception for duplicate product code');
        } catch (Exception e) {
            System.assert(e instanceof System.AuraHandledException, 'Duplicate product code exception expected');
        }
    }
    
    @IsTest
    static void testHelperMethods() {
        Account partner = [SELECT Id, Name FROM Account WHERE Name = 'Test Partner' LIMIT 1];
        
        Test.startTest();
        Id pbId = ProductController.resolveOrCreatePartnerPricebook(partner.Id);
        System.assertNotEquals(null, pbId, 'Should create pricebook');
        
        Id foundPbId = ProductController.findPartnerPricebookId(partner.Id);
        System.assertEquals(pbId, foundPbId, 'Should find the created pricebook');
        
        String pbName = ProductController.findPartnerPricebookName(pbId);
        System.assertEquals(partner.Name, pbName, 'Should find the pricebook name');
        Test.stopTest();
    }

    // Helper to get RecordType without hardcoding ID
    private static Id getRecordTypeId(String sObjectType, String developerName) {
        List<RecordType> rts = [SELECT Id FROM RecordType WHERE SObjectType = :sObjectType AND DeveloperName = :developerName LIMIT 1];
        return rts.isEmpty() ? null : rts[0].Id;
    }
}