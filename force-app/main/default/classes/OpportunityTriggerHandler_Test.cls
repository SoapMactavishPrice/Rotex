@isTest
private class OpportunityTriggerHandler_Test {
    
    /*@isTest
    static void testHandleProposalOpportunities() {
        
        Id PID = Test.getStandardPricebookId();
        
        Product2 prod = new Product2();
        prod.name='VOXCO CHROME ORANGE VO-750/SA';
        prod.isActive=true;
        insert prod;
        
        
        PricebookEntry standardPrice = new PricebookEntry(
            Pricebook2Id = PID, 
            Product2Id = prod.Id,
            UnitPrice = 1000,
            IsActive = true);
        
        insert standardPrice;
        
        Account acc = new Account();
        acc.Name = 'Finesse IT';
        
        insert acc;
     
        

        Contact con = new Contact();
        con.AccountId = acc.id;
        con.FirstName = 'Prashant';
        con.LastName = 'Padal';
        con.Email = 'Prashantpadal@finessedirect.com';
        con.Phone = '123-456-7890';
        
        con.MailingCountry= 'India';
        con.MailingCity='Navi Mumbai';
        con.MailingState='Maharashtra';
        con.MailingStreet='MBP Road';
        con.MailingPostalCode='400710';	
        insert con;
        
        
        Opportunity opp = new Opportunity();
        opp.Name = 'Finesse Opportunity';
        opp.StageName = 'Needs Analysis';
        opp.CloseDate = Date.today();
        opp.AccountId = acc.Id;
        opp.Project_Contact__c = con.Id;
        opp.Pricebook2Id=PID;
        
        insert opp;

        OpportunityLineItem oli = new OpportunityLineItem
            (OpportunityId = opp.Id,
             pricebookentryid=standardPrice.id, 
             product2Id= prod.Id,
             UnitPrice = 1000, 
             Quantity = 1, 
             Discount=10);
        insert oli;
        System.debug('oli' +oli);
        
        opp.StageName = 'Firm Proposal';
        update opp;
        
        opp.StageName='Closed Won';
        update opp;
        
        
        Map<Id, Opportunity> oldOpportunityMap = new Map<Id, Opportunity>();
        oldOpportunityMap.put(opp.Id, new Opportunity(StageName = 'Needs Analysis')); 
        
        List<Opportunity> newOpportunities = new List<Opportunity>{opp};
            
     	Test.startTest();
    	  OpportunityTriggerHandler.handleProposalOpportunities(newOpportunities, oldOpportunityMap);
     	  OpportunityTriggerHandler.handleClosedWonOpportunities(newOpportunities, oldOpportunityMap);
    
        Test.stopTest();
    }*/
    @isTest
    static void testHandleProposalOpportunities() {
    
        Id standardPricebookId = Test.getStandardPricebookId();
        Pricebook2 stdPb = new Pricebook2(
            Id = standardPricebookId,
            Name = 'Standard Price Book',
            IsActive = true
        );
        upsert stdPb;
    
        Product2 prod = new Product2(
            Name = 'VOXCO CHROME ORANGE VO-750/SA',
            IsActive = true
        );
        insert prod;
    
        PricebookEntry standardPrice;
        List<PricebookEntry> existingPbe = [
            SELECT Id FROM PricebookEntry 
            WHERE Pricebook2Id = :standardPricebookId AND Product2Id = :prod.Id LIMIT 1
        ];
        if (existingPbe.isEmpty()) {
            standardPrice = new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = prod.Id,
                UnitPrice = 1000,
                IsActive = true,
                CurrencyIsoCode = 'INR'
            );
            insert standardPrice;
        } else {
            standardPrice = existingPbe[0];
        }
    
        Account acc = new Account(Name = 'Finesse IT');
        insert acc;
    
        Contact con = new Contact(
            AccountId = acc.Id,
            FirstName = 'Prashant',
            LastName = 'Padal',
            Email = 'Prashantpadal@finessedirect.com',
            Phone = '123-456-7890',
            MailingCountry = 'India',
            MailingCity = 'Navi Mumbai',
            MailingState = 'Maharashtra',
            MailingStreet = 'MBP Road',
            MailingPostalCode = '400710'
        );
        insert con;
        Sales_Area_Item__c sai= new Sales_Area_Item__c();
        sai.Account__c = acc.Id;
        sai.Distribution_Channel__c = '10';
        sai.Division__c = '10';
        sai.Sales_Org__c = '1100';
        Insert sai;
        Opportunity opp = new Opportunity(
            Name = 'Finesse Opportunity',
            StageName = 'Needs Analysis',
            CloseDate = Date.today(),
            AccountId = acc.Id,
            Project_Contact__c = con.Id,
            Pricebook2Id = standardPricebookId
        );
        insert opp;
    
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = standardPrice.Id, // << Must match Opportunity Pricebook
            UnitPrice = 1000,
            Quantity = 1,
            Discount = 10
        );
        insert oli;
    
        opp.StageName = 'Firm Proposal';
        update opp;
    
        opp.StageName = 'Closed Won';
        update opp;
    
        Map<Id, Opportunity> oldOpportunityMap = new Map<Id, Opportunity>{
            opp.Id => new Opportunity(StageName = 'Needs Analysis')
        };
        List<Opportunity> newOpportunities = new List<Opportunity>{opp};
    
        Test.startTest();
        OpportunityTriggerHandler.handleProposalOpportunities(newOpportunities, oldOpportunityMap);
       // OpportunityTriggerHandler.handleClosedWonOpportunities(newOpportunities, oldOpportunityMap);
        Test.stopTest();
    }

        
}