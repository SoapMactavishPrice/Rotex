@isTest
public class SyncQuote_Test {
    static testMethod void testSyncQuoteOppWithAcceptedQuote() {
        // Setup test data
        
        Id PID = Test.getStandardPricebookId();
        
        
        Product2 prod = new Product2();
        prod.name='VOXCO CHROME ORANGE VO-750/SA';
        prod.isActive=true;
        insert prod;
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = PID, 
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true);
        
        insert pbe;  
        
        Account acc = new Account();
        acc.Name = 'Finesse IT';
        insert acc;
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            CloseDate = System.today().addDays(10),
            StageName = 'Sampling',
            AccountId = acc.Id,
            Pricebook2Id=PID);
        insert opp;
        
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            Product2Id = prod.Id,
            Quantity = 5,
            UnitPrice = 100.00,
            PricebookEntryId = pbe.Id);
        insert oli;
        
        Quote testQuote = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Status = 'Accepted');
        insert testQuote;
        
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = testQuote.Id,
            Product2Id = prod.Id,
            Quantity = 5,
            UnitPrice = 100.00,
            PricebookEntryId = pbe.Id);
        insert qli;
        
        Test.startTest();
        // Make sure to pass the quote ID to the page parameters
        ApexPages.currentPage().getParameters().put('id', testQuote.Id);
        SyncQuote controller = new SyncQuote();
        PageReference pageRef = controller.syncQuoteOpp();
        Test.stopTest();
        
    }
    
    @isTest
    static void testSyncQuoteWithNonAcceptedStatus() {
        // Setup test data similar to the first test but with the Quote Status not being 'Accepted'
        
        Id PID = Test.getStandardPricebookId();
        
        
        Product2 prod= new Product2();
        prod.name='VOXCO CHROME ORANGE VO-750/SA';
        prod.isActive=true;
        insert prod;
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = PID, 
            Product2Id = prod.Id,
            UnitPrice = 10000,
            IsActive = true);
        
        insert pbe;  
        
        Account acc = new Account();
        acc.Name = 'Finesse IT';
        insert acc;
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            CloseDate = System.today().addDays(10),
            StageName = 'Proposal',
            AccountId = acc.Id,
            Pricebook2Id=PID);
        insert opp;
        
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            Product2Id = prod.Id,
            Quantity = 5,
            UnitPrice = 100.00,
            PricebookEntryId = pbe.Id);
        insert oli;
        
        Quote quote = new Quote(Name='Test Quote', OpportunityId=opp.Id, Status='Draft');
        insert quote;
        
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = quote.Id,
            Product2Id = prod.Id,
            Quantity = 5,
            UnitPrice = 100.00,
            PricebookEntryId = pbe.Id);
        insert qli;
        
        Test.startTest();
        // Make sure to pass the quote ID to the page parameters
        ApexPages.currentPage().getParameters().put('id', quote.Id);
        SyncQuote controller = new SyncQuote();
        PageReference pageRef = controller.syncQuoteOpp();
        Test.stopTest();
        
    }
   
    static testMethod void testSyncQuoteElseBlock() {
        Id PID = Test.getStandardPricebookId();
        
        system.debug('PID - '+PID);
        
        Product2 prod= new Product2();
        prod.name='VOXCO SCARLET CHROME';
        prod.isActive=true;
        insert prod;
        system.debug('prod - '+prod);
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = PID, 
            Product2Id = prod.Id,
            UnitPrice = 10000,
            IsActive = true);
        
        insert pbe;
        system.debug('price book entry ID - '+pbe);
        
        
        Account acc = new Account();
        acc.Name = 'Finesse IT';
        insert acc;
        
        Opportunity testOpportunity = new Opportunity
            (Name='Test Opportunity', 
             StageName='Proposal',
             CloseDate=System.today().addDays(10), 
             AccountId=acc.Id,
             Pricebook2Id =PID
            );
        insert testOpportunity;
        system.debug('testOpportunity - '+testOpportunity);
        
        Quote testQuote = new Quote(
            Name='Test Quote', 
            OpportunityId=testOpportunity.Id, 
            account__c = acc.id,
            Status='Draft'
        );
        insert testQuote;
        system.debug('quote - '+testQuote);
        
        QuoteLineItem testQuoteLineItem = new QuoteLineItem(
            QuoteId=testQuote.Id,
            Product2Id = prod.Id,
            PricebookEntryId=pbe.Id,
            Quantity=1, 
            UnitPrice=100
        );
        
        testQuote.status = 'Accepted';
        update testQuote;
        
        insert testQuoteLineItem;
        system.debug('testQuoteLineItem - '+testQuoteLineItem);
        
        
        Test.startTest();
        
        ApexPages.currentPage().getParameters().put('id', testQuote.Id);
        SyncQuote controller = new SyncQuote();
        PageReference pageRef = controller.syncQuoteOpp();
        Test.stopTest();
        
    } 
    
}