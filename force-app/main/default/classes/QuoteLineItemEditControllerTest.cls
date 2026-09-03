@IsTest
private class QuoteLineItemEditControllerTest {
    
    @IsTest
    static void testBlockEdit() {
        Account acc = new Account(Name = 'Test Account', SAP_Customer_Code__c = '1001176');
        insert acc;
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            AccountId = acc.Id
        );
        insert opp;
        
        Id standardPricebookId = Test.getStandardPricebookId();
        
        Quote quote = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = standardPricebookId,
            Quote_Valid_Till__c = Date.today().addDays(90)
        );
        insert quote;
        
        Sales_Area_Item__c sai = new Sales_Area_Item__c(
            Name = 'Test SAI',
            Sales_Org__c = '1100',
            Distribution_Channel__c = '10',
            Division__c = '30',
            Account__c = acc.Id
        );
        insert sai;
        
        Partner_Details__c pd1 = new Partner_Details__c(
            Name = 'BP Partner',
            Partner_Function__c = 'BP',
            Partner_No__c = 'P001',
            Account__c = acc.Id,
            Sales_Area_Item__c = sai.Id
        );
        insert pd1;
        
        Partner_Details__c pd2 = new Partner_Details__c(
            Name = 'SH Partner',
            Partner_Function__c = 'SH',
            Partner_No__c = 'P002',
            Account__c = acc.Id,
            Sales_Area_Item__c = sai.Id
        );
        insert pd2;
        
        Partner_Details__c pd3 = new Partner_Details__c(
            Name = 'CA Partner',
            Partner_Function__c = 'CA',
            Partner_No__c = 'P003',
            Account__c = acc.Id,
            Sales_Area_Item__c = sai.Id
        );
        insert pd3;
        
        Product2 prod = new Product2(Name = 'Test Product', ProductCode = 'PROD001', IsActive = true);
        insert prod;
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;
        
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = quote.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 100
        );
        insert qli;
        
        // Create StandardController
        ApexPages.StandardController sc =
            new ApexPages.StandardController(qli);
        
        // Create Controller
        QuoteLineItemEditController controller =
            new QuoteLineItemEditController(sc);
        
        Test.startTest();
        
        PageReference result = controller.blockEdit();
        
        Test.stopTest();
        
        // Validate result
        System.assertEquals(
            null,
            result,
            'blockEdit should return null'
        );
        
        // Validate error message
        System.assertEquals(
            1,
            ApexPages.getMessages().size(),
            'One error message should be generated'
        );
        
        System.assertEquals(
            ApexPages.Severity.ERROR,
            ApexPages.getMessages()[0].getSeverity(),
            'Message should be an ERROR'
        );
        
      /*  System.assertEquals(
            'Quote Line Item cannot be edited from this screen. Please use the Quote Line Item LWC.',
            ApexPages.getMessages()[0].getSummary(),
            'Incorrect error message'
        );*/
    }
}