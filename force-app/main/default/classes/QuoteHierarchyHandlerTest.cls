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
        
        Account acc = new Account(Name = 'Test Account');
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
    static void testBulkInsert() {
        User salesRep = [SELECT Id FROM User WHERE FirstName = 'Sales' AND LastName = 'Rep' LIMIT 1];
        
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        List<Opportunity> opps = new List<Opportunity>();
        for(Integer i = 0; i < 200; i++) {
            opps.add(new Opportunity(
                Name = 'Test Opp ' + i,
                AccountId = acc.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            ));
        }
        insert opps;
        
        List<Quote> quotes = new List<Quote>();
        for(Opportunity o : opps) {
            quotes.add(new Quote(
                Name = 'Test Quote',
                OpportunityId = o.Id,
                OwnerId = salesRep.Id
            ));
        }
        
        Test.startTest();
        insert quotes;
        Test.stopTest();
    }
}