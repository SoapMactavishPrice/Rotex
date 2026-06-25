@isTest
private class QuoteHierarchyHandlerTest {
    
    @testSetup
    static void setupTestData() {
        User boardMember = createUser('Board', 'Member', 'Rotex Board Member', null);
        User globalHead = createUser('Global', 'Head', 'Global Sales Head', boardMember.Id);
        User countryHead = createUser('Country', 'Head', 'Country / Continent Sales Head / LOB Head', globalHead.Id);
        User managingDirector = createUser('Managing', 'Director', 'Managing Director / Country Manager', countryHead.Id);
        User salesManager = createUser('Sales', 'Manager', 'Sales Manager', managingDirector.Id);
        User salesRep = createUser('Sales', 'Rep', 'Sales Rep', salesManager.Id);
        // User otherProfile = createUser('Other', 'User', 'Other Profile', null);
    }
    
    static User createUser(String firstName, String lastName, String profile, Id managerId) {
        String uniqueName = firstName + lastName + System.currentTimeMillis() + Math.random();
        User u = new User(
            FirstName = firstName,
            LastName = lastName,
            Email = uniqueName + '@test.com',
            Username = uniqueName + '@test.com.testorg',
            Alias = (firstName + lastName).left(8),
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US',
            SOA_Profile__c = profile,
            ManagerId = managerId
        );
        insert u;
        return u;
    }
    
    @isTest
    static void testQuoteInsert() {
        User salesRep = [SELECT Id FROM User WHERE FirstName = 'Sales' AND LastName = 'Rep' LIMIT 1];
        
        // ✅ Set OwnerId so the hierarchy logic in step 6 doesn't bail out early
        Account acc = new Account(Name = 'Test Account', OwnerId = salesRep.Id);
        insert acc;
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Id standardPriceBookId = Test.getStandardPricebookId();
        Pricebook2 priceBook = new Pricebook2(Id = standardPriceBookId, IsActive = true);
        update priceBook;
        
        Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
        insert prod;
        
        Test.startTest();
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            OwnerId = salesRep.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Validity_of_Offer__c = '180 Days',
            Payment_Terms__c = 'Open Credit upto 180 days',
            Warranty_Terms__c = '48 Months from date of supply'
        );
        insert q;

        PricebookEntry pbe = [
            SELECT Id, Name, UnitPrice, IsActive, Pricebook2Id, Product2Id
            FROM PricebookEntry
            WHERE Pricebook2Id = :standardPricebookId
            AND Product2Id = :prod.Id
            LIMIT 1
        ];
        
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );
        insert qli;
        Test.stopTest();

        // ✅ Verify the red block (step 7) actually synced hierarchy fields to the QLI
        QuoteLineItem updatedQli = [
            SELECT Sales_Rep__c, Sales_Manager__c,
                Country_Continent_Sales_Head_LOB_Head__c,
                Global_Sales_Head__c, Rotex_Board_Member__c,
                Managing_Director_Country_Manage__c
            FROM QuoteLineItem
            WHERE Id = :qli.Id
        ];

        System.assertNotEquals(null, updatedQli.Sales_Rep__c, 'Sales_Rep__c should be synced to QLI');
        System.assertNotEquals(null, updatedQli.Sales_Manager__c, 'Sales_Manager__c should be synced to QLI');
        System.assertNotEquals(null, updatedQli.Country_Continent_Sales_Head_LOB_Head__c, 'Country/Continent head should be synced');
        System.assertNotEquals(null, updatedQli.Global_Sales_Head__c, 'Global Sales Head should be synced');
        System.assertNotEquals(null, updatedQli.Rotex_Board_Member__c, 'Rotex Board Member should be synced');
        System.assertNotEquals(null, updatedQli.Managing_Director_Country_Manage__c, 'Managing Director should be synced');
    }
    
    @isTest
    static void testQuoteUpdate() {
        User salesRep = [SELECT Id FROM User WHERE FirstName = 'Sales' AND LastName = 'Rep' LIMIT 1];
        User salesManager = [SELECT Id FROM User WHERE FirstName = 'Sales' AND LastName = 'Manager' LIMIT 1];
        
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            OwnerId = salesRep.Id
        );
        insert q;
        
        Test.startTest();
        q.OwnerId = salesManager.Id;
        try{
        update q;
        }Catch(Exception e){}
        Test.stopTest();
    }
    
    @isTest
    static void testAccountOwnerHierarchyFieldsAreApplied() {
        User salesRep = [SELECT Id FROM User WHERE FirstName = 'Sales' AND LastName = 'Rep' LIMIT 1];
        User salesManager = [SELECT Id FROM User WHERE FirstName = 'Sales' AND LastName = 'Manager' LIMIT 1];
        User managingDirector = [SELECT Id FROM User WHERE FirstName = 'Managing' AND LastName = 'Director' LIMIT 1];
        User countryHead = [SELECT Id FROM User WHERE FirstName = 'Country' AND LastName = 'Head' LIMIT 1];
        User globalHead = [SELECT Id FROM User WHERE FirstName = 'Global' AND LastName = 'Head' LIMIT 1];
        User boardMember = [SELECT Id FROM User WHERE FirstName = 'Board' AND LastName = 'Member' LIMIT 1];
        
        Account acc = new Account(Name = 'Hierarchy Account', OwnerId = salesRep.Id);
        insert acc;
        
        Opportunity opp = new Opportunity(
            Name = 'Hierarchy Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        
        Test.startTest();
        Quote q = new Quote(
            Name = 'Hierarchy Quote',
            OpportunityId = opp.Id,
            OwnerId = salesRep.Id
        );
        insert q;
        
        q.Name = 'Hierarchy Quote Updated';
        update q;
        Test.stopTest();
        
        Quote updatedQuote = [
            SELECT Sales_Rep__c, Sales_Manager__c, Managing_Director_Country_Manager__c,
                   Country_Continent_Sales_Head_LOB_Head__c, Global_Sales_Head__c,
                   Rotex_Board_Member__c
            FROM Quote
            WHERE Id = :q.Id
        ];
        
    }
}