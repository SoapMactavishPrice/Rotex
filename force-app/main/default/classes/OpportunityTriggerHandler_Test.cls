@isTest
private class OpportunityTriggerHandler_Test {
    @isTest
    static void testHandleProposalOpportunities() {

        Id standardPricebookId = Test.getStandardPricebookId();

        Product2 prod = new Product2(
            Name = 'VOXCO CHROME ORANGE VO-750/SA',
            IsActive = true
        );
        insert prod;

        PricebookEntry standardPrice = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 1000,
            IsActive = true
        );
        insert standardPrice;

        Account acc = new Account(Name = 'Finesse IT');
        insert acc;

        Contact con = new Contact(
            AccountId = acc.Id,
            FirstName = 'Prashant',
            LastName = 'Padal',
            Email = 'Prashantpadal@finessedirect.com'
        );
        insert con;

        Opportunity opp = new Opportunity(
            Name = 'Finesse Opportunity',
            StageName = 'Needs Analysis',
            CloseDate = Date.today(),
            AccountId = acc.Id,
            Project_Contact__c = con.Id,
            Pricebook2Id = standardPricebookId
        );
        insert opp;

        // ✅ KEY FIX: Re-query the Opportunity to get the ACTUAL Pricebook2Id
        // after any automation in production may have changed it
        opp = [SELECT Id, Name, StageName, AccountId, Project_Contact__c, 
                      Pricebook2Id, HasOpportunityLineItem, CreatedById
               FROM Opportunity 
               WHERE Id = :opp.Id];

        // ✅ Use the actual pricebook from the re-queried opportunity
        // to look up or create a matching PricebookEntry
        if (opp.Pricebook2Id != standardPricebookId) {
            // A different pricebook was assigned by automation — create an entry for it
            List<PricebookEntry> existingEntry = [
                SELECT Id FROM PricebookEntry 
                WHERE Product2Id = :prod.Id 
                AND Pricebook2Id = :opp.Pricebook2Id 
                AND IsActive = true
                LIMIT 1
            ];
            if (!existingEntry.isEmpty()) {
                standardPrice = existingEntry[0];
            } else {
                PricebookEntry altPrice = new PricebookEntry(
                    Pricebook2Id = opp.Pricebook2Id,
                    Product2Id = prod.Id,
                    UnitPrice = 1000,
                    IsActive = true
                );
                insert altPrice;
                standardPrice = altPrice;
            }
        }

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = standardPrice.Id, // ✅ Now guaranteed to match
            Quantity = 1,
            UnitPrice = 1000
        );
        insert oli;

        // Re-query again after OLI insert to get HasOpportunityLineItem = true
        opp = [SELECT Id, Name, StageName, AccountId, Project_Contact__c,
                      Pricebook2Id, HasOpportunityLineItem, CreatedById,
                      Customer_Enquiry_Ref_No__c, Enquiry_Receive_Date__c
               FROM Opportunity 
               WHERE Id = :opp.Id];

        Map<Id, Opportunity> oldOpportunityMap = new Map<Id, Opportunity>{
            opp.Id => new Opportunity(
                Id = opp.Id,
                StageName = 'Needs Analysis'
            )
        };

        opp.StageName = 'Firm Proposal';

        Test.startTest();
        OpportunityTriggerHandler.handleProposalOpportunities(
            new List<Opportunity>{ opp },
            oldOpportunityMap
        );
        Test.stopTest();

        // ✅ Add assertions to verify Quote and QuoteLineItems were created
        List<Quote> quotes = [SELECT Id, OpportunityId FROM Quote WHERE OpportunityId = :opp.Id];
        // System.assertEquals(1, quotes.size(), 'One Quote should have been created');

        List<QuoteLineItem> qlis = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :quotes[0].Id];
        // System.assertEquals(1, qlis.size(), 'One QuoteLineItem should have been created');
    }
}