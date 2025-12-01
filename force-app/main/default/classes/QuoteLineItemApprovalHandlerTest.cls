@isTest
public class QuoteLineItemApprovalHandlerTest {

    @testSetup
    static void setupTestData() {
        // Activate Standard Pricebook
        Id standardPricebookId = Test.getStandardPricebookId();
        Pricebook2 stdPb = new Pricebook2(Id = standardPricebookId, IsActive = true);
        upsert stdPb;

        // Create Product
        Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
        insert prod;

        // Check if PricebookEntry already exists, if not create it
        List<PricebookEntry> existingPbe = [
            SELECT Id FROM PricebookEntry 
            WHERE Product2Id = :prod.Id 
            AND Pricebook2Id = :standardPricebookId 
            LIMIT 1
        ];
        
        if (existingPbe.isEmpty()) {
            PricebookEntry pbe = new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = prod.Id,
                UnitPrice = 100,
                IsActive = true
            );
            insert pbe;
        }

        // Create Users with different SOA Profiles
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User salesRep = new User(
            FirstName = 'Sales',
            LastName = 'Rep',
            Email = 'salesrep' + System.currentTimeMillis() + '@test.com',
            Username = 'salesrep' + System.currentTimeMillis() + '@test.com',
            Alias = 'srep',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US',
            SOA_Profile__c = 'Sales Rep'
        );
        insert salesRep;

        User salesManager = new User(
            FirstName = 'Sales',
            LastName = 'Manager',
            Email = 'salesmanager' + System.currentTimeMillis() + '@test.com',
            Username = 'salesmanager' + System.currentTimeMillis() + '@test.com',
            Alias = 'smgr',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US',
            SOA_Profile__c = 'Sales Manager'
        );
        insert salesManager;

        User countryHead = new User(
            FirstName = 'Country',
            LastName = 'Head',
            Email = 'countryhead' + System.currentTimeMillis() + '@test.com',
            Username = 'countryhead' + System.currentTimeMillis() + '@test.com',
            Alias = 'chead',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US',
            SOA_Profile__c = 'Country / Continent Sales Head / LOB Head'
        );
        insert countryHead;

        // Create Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
    }

    @isTest
    static void testProcessApprovals_EmptyList() {
        Test.startTest();
        QuoteLineItemApprovalHandler.processApprovals(new List<QuoteLineItem>());
        Test.stopTest();
    }

    @isTest
    static void testProcessApprovals_SalesRepOwner() {
        // Get test data
        User salesRep = [SELECT Id FROM User WHERE SOA_Profile__c = 'Sales Rep' LIMIT 1];
        User salesManager = [SELECT Id FROM User WHERE SOA_Profile__c = 'Country / Continent Sales Head / LOB Head' LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Id standardPricebookId = Test.getStandardPricebookId();

        // Create Quote owned by Sales Rep
        Quote quoteRep = new Quote(
            Name = 'Quote - Sales Rep Owner',
            OwnerId = salesRep.Id,
            OpportunityId = opp.Id,
            Pricebook2Id = standardPricebookId,
            Sales_Manager__c = salesManager.Id
        );
        insert quoteRep;

        // Create QLI with discount exceeding SAP discount
        QuoteLineItem qliRep = new QuoteLineItem(
            QuoteId = quoteRep.Id,
            PricebookEntryId = pbe.Id,
            Product2Id = prod.Id,
            Quantity = 5,
            UnitPrice = 100,
            Discount_to_be_offered__c = 15,
            Discount_as_per_SAP__c = 10
        );

        Test.startTest();
        insert qliRep;
        Test.stopTest();
    }

    @isTest
    static void testProcessApprovals_SalesManagerOwner() {
        // Get test data
        User salesManager = [SELECT Id FROM User WHERE SOA_Profile__c = 'Sales Manager' LIMIT 1];
        User countryHead = [SELECT Id FROM User WHERE SOA_Profile__c = 'Country / Continent Sales Head / LOB Head' LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Id standardPricebookId = Test.getStandardPricebookId();

        // Create Quote owned by Sales Manager
        Quote quoteMgr = new Quote(
            Name = 'Quote - Sales Manager Owner',
            OwnerId = salesManager.Id,
            OpportunityId = opp.Id,
            Pricebook2Id = standardPricebookId,
            Country_Continent_Sales_Head_LOB_Head__c = countryHead.Id
        );
        insert quoteMgr;

        // Create QLI with discount exceeding SAP discount
        QuoteLineItem qliMgr = new QuoteLineItem(
            QuoteId = quoteMgr.Id,
            PricebookEntryId = pbe.Id,
            Product2Id = prod.Id,
            Quantity = 10,
            UnitPrice = 200,
            Discount_to_be_offered__c = 20,
            Discount_as_per_SAP__c = 5
        );

        Test.startTest();
        insert qliMgr;
        Test.stopTest();
    }

    @isTest
    static void testProcessApprovals_NoApprovalNeeded() {
        // Get test data
        User salesRep = [SELECT Id FROM User WHERE SOA_Profile__c = 'Sales Rep' LIMIT 1];
        User salesManager = [SELECT Id FROM User WHERE SOA_Profile__c = 'Sales Manager' LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Id standardPricebookId = Test.getStandardPricebookId();

        Quote quoteRep = new Quote(
            Name = 'Quote - No Approval',
            OwnerId = salesRep.Id,
            OpportunityId = opp.Id,
            Pricebook2Id = standardPricebookId,
            Sales_Manager__c = salesManager.Id
        );
        insert quoteRep;

        // Create QLI with discount within SAP discount (no approval needed)
        QuoteLineItem qliNoApproval = new QuoteLineItem(
            QuoteId = quoteRep.Id,
            PricebookEntryId = pbe.Id,
            Product2Id = prod.Id,
            Quantity = 5,
            UnitPrice = 100,
            Discount_to_be_offered__c = 8,  // Less than SAP discount
            Discount_as_per_SAP__c = 10
        );

        Test.startTest();
        insert qliNoApproval;
        Test.stopTest();
    }

    @isTest
    static void testProcessApprovals_NullDiscountFields() {
        // Get test data
        User salesRep = [SELECT Id FROM User WHERE SOA_Profile__c = 'Sales Rep' LIMIT 1];
        User salesManager = [SELECT Id FROM User WHERE SOA_Profile__c = 'Sales Manager' LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Id standardPricebookId = Test.getStandardPricebookId();

        Quote quoteRep = new Quote(
            Name = 'Quote - Null Fields',
            OwnerId = salesRep.Id,
            OpportunityId = opp.Id,
            Pricebook2Id = standardPricebookId,
            Sales_Manager__c = salesManager.Id
        );
        insert quoteRep;

        // Create QLI with null discount fields
        QuoteLineItem qliNull = new QuoteLineItem(
            QuoteId = quoteRep.Id,
            PricebookEntryId = pbe.Id,
            Product2Id = prod.Id,
            Quantity = 5,
            UnitPrice = 100,
            Discount_to_be_offered__c = null,
            Discount_as_per_SAP__c = null
        );

        Test.startTest();
        insert qliNull;
        Test.stopTest();
    }

    @isTest
    static void testProcessApprovals_MultipleQLIs() {
        // Get test data
        User salesRep = [SELECT Id FROM User WHERE SOA_Profile__c = 'Sales Rep' LIMIT 1];
        User salesManager = [SELECT Id FROM User WHERE SOA_Profile__c = 'Sales Manager' LIMIT 1];
        User countryHead = [SELECT Id FROM User WHERE SOA_Profile__c = 'Country / Continent Sales Head / LOB Head' LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Id standardPricebookId = Test.getStandardPricebookId();

        // Create two quotes
        Quote quoteRep = new Quote(
            Name = 'Quote Rep Multi',
            OwnerId = salesRep.Id,
            OpportunityId = opp.Id,
            Pricebook2Id = standardPricebookId,
            Sales_Manager__c = salesManager.Id
        );
        
        Quote quoteMgr = new Quote(
            Name = 'Quote Mgr Multi',
            OwnerId = salesManager.Id,
            OpportunityId = opp.Id,
            Pricebook2Id = standardPricebookId,
            Country_Continent_Sales_Head_LOB_Head__c = countryHead.Id
        );
        insert new List<Quote>{ quoteRep, quoteMgr };

        // Create multiple QLIs
        List<QuoteLineItem> qlis = new List<QuoteLineItem>{
            new QuoteLineItem(
                QuoteId = quoteRep.Id,
                PricebookEntryId = pbe.Id,
                Product2Id = prod.Id,
                Quantity = 5,
                UnitPrice = 100,
                Discount_to_be_offered__c = 15,
                Discount_as_per_SAP__c = 10
            ),
            new QuoteLineItem(
                QuoteId = quoteMgr.Id,
                PricebookEntryId = pbe.Id,
                Product2Id = prod.Id,
                Quantity = 10,
                UnitPrice = 200,
                Discount_to_be_offered__c = 20,
                Discount_as_per_SAP__c = 5
            )
        };

        Test.startTest();
        insert qlis;
        Test.stopTest();
    }

    @isTest
    static void testGetCustomNotificationTypeId_NotFound() {
        User salesRep = [SELECT Id FROM User WHERE SOA_Profile__c = 'Sales Rep' LIMIT 1];
        User salesManager = [SELECT Id FROM User WHERE SOA_Profile__c = 'Sales Manager' LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Id standardPricebookId = Test.getStandardPricebookId();

        Quote quoteRep = new Quote(
            Name = 'Quote - Notification Test',
            OwnerId = salesRep.Id,
            OpportunityId = opp.Id,
            Pricebook2Id = standardPricebookId,
            Sales_Manager__c = salesManager.Id
        );
        insert quoteRep;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = quoteRep.Id,
            PricebookEntryId = pbe.Id,
            Product2Id = prod.Id,
            Quantity = 5,
            UnitPrice = 100,
            Discount_to_be_offered__c = 15,
            Discount_as_per_SAP__c = 10
        );

        Test.startTest();
        insert qli;
        Test.stopTest();
    }
}