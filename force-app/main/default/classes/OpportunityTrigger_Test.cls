@isTest
public class OpportunityTrigger_Test {
    
    @isTest
    static void testHandleProposalOpportunities() {
        
        Id PID = Test.getStandardPricebookId();

        Pricebook2 priceBook = new Pricebook2(Id = PID, IsActive = true);
        update priceBook;
        
        Product2 prod = new Product2();
        prod.name='VOXCO CHROME ORANGE VO-750/SA';
        prod.isActive=true;
        insert prod;
        
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
        opp.Amount = 35000;
        opp.Pricebook2Id=PID;
        
        insert opp;

        opp.Amount = 50000;
        update opp;

        PricebookEntry standardPrice = [
            SELECT Id, Name, UnitPrice, IsActive, Pricebook2Id, Product2Id
            FROM PricebookEntry
            WHERE Pricebook2Id = :PID
            AND Product2Id = :prod.Id
            LIMIT 1
        ];

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
        oldOpportunityMap.put(opp.Id, new Opportunity(StageName = 'Sampling')); 
        
        List<Opportunity> newOpportunities = new List<Opportunity>{opp};
            
     	Test.startTest();
    	  OpportunityTriggerHandler.handleProposalOpportunities(newOpportunities, oldOpportunityMap);
     	  OpportunityTriggerHandler.handleClosedWonOpportunities(newOpportunities, oldOpportunityMap);
    
        Test.stopTest();
    }
        
}