@IsTest
private class QuoteClonerTest {
    @TestSetup
    static void setupData() {
        Account account = new Account(Name = 'Quote Cloner Test Account');
        insert account;

        Opportunity opportunity = new Opportunity(
            Name = 'Quote Cloner Test Opportunity',
            AccountId = account.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opportunity;

        Id standardPricebookId = Test.getStandardPricebookId();
        update new Pricebook2(Id = standardPricebookId, IsActive = true);

        Product2 product = new Product2(
            Name = 'Quote Cloner Test Product',
            IsActive = true
        );
        insert product;

        PricebookEntry pricebookEntry = getOrCreatePricebookEntry(standardPricebookId, product.Id, 1000);

        Quote quote = new Quote(
            Name = 'Quote Cloner Test Quote',
            OpportunityId = opportunity.Id,
            Pricebook2Id = standardPricebookId,
            Status = 'Draft',
            ExpirationDate = Date.today().addDays(15),
            Description = 'Original quote description',
            Customer_State__c = 'Gujarat'
        );
        insert quote;

        QuoteLineItem lineItem = new QuoteLineItem(
            QuoteId = quote.Id,
            PricebookEntryId = pricebookEntry.Id,
            Quantity = 2,
            UnitPrice = 800,
            Description = 'Original line item',
            ServiceDate = Date.today().addDays(5)
        );
        insert lineItem;
    }

    @IsTest
    static void cloneQuoteWithLineItems_clonesQuoteAndLineItems() {
        Quote originalQuote = [
            SELECT Id, Name, OpportunityId, Pricebook2Id, Status, Description, ExpirationDate
            FROM Quote
            WHERE Name = 'Quote Cloner Test Quote'
            LIMIT 1
        ];

        QuoteLineItem originalLineItem = [
            SELECT Id, QuoteId, PricebookEntryId, Quantity, UnitPrice, ListPrice, Description, ServiceDate
            FROM QuoteLineItem
            WHERE QuoteId = :originalQuote.Id
            LIMIT 1
        ];

        Test.startTest();
        Id clonedQuoteId = QuoteCloner.cloneQuoteWithLineItems(originalQuote.Id);
        Test.stopTest();

        System.assertNotEquals(null, clonedQuoteId, 'Cloned quote Id should be returned.');
        System.assertNotEquals(originalQuote.Id, clonedQuoteId, 'Clone should be a new Quote record.');

        Quote clonedQuote = [
            SELECT Id, Name, OpportunityId, Pricebook2Id, Status, Description, ExpirationDate
            FROM Quote
            WHERE Id = :clonedQuoteId
            LIMIT 1
        ];

        System.assertEquals(originalQuote.Name + ' - Clone', clonedQuote.Name, 'Clone name should include suffix.');
        System.assertEquals('Draft', clonedQuote.Status, 'Cloned quote should be reset to Draft.');
        System.assertEquals(originalQuote.OpportunityId, clonedQuote.OpportunityId, 'Opportunity should be copied.');
        System.assertEquals(originalQuote.Pricebook2Id, clonedQuote.Pricebook2Id, 'Pricebook should be copied.');
        System.assertEquals(originalQuote.Description, clonedQuote.Description, 'Description should be copied.');
        System.assertEquals(originalQuote.ExpirationDate, clonedQuote.ExpirationDate, 'Expiration date should be copied.');

        List<QuoteLineItem> clonedLineItems = [
            SELECT Id, QuoteId, PricebookEntryId, Quantity, UnitPrice, ListPrice, Description, ServiceDate
            FROM QuoteLineItem
            WHERE QuoteId = :clonedQuoteId
        ];

        System.assertEquals(1, clonedLineItems.size(), 'One line item should be cloned.');
        QuoteLineItem clonedLineItem = clonedLineItems[0];

        System.assertNotEquals(originalLineItem.Id, clonedLineItem.Id, 'Cloned line item should be a new record.');
        System.assertEquals(clonedQuoteId, clonedLineItem.QuoteId, 'Cloned line item should belong to cloned quote.');
        System.assertEquals(originalLineItem.PricebookEntryId, clonedLineItem.PricebookEntryId, 'Pricebook entry should be copied.');
        System.assertEquals(originalLineItem.Quantity, clonedLineItem.Quantity, 'Quantity should be copied.');
        System.assertEquals(originalLineItem.ListPrice, clonedLineItem.UnitPrice, 'Unit price should reset to list price.');
        System.assertEquals(originalLineItem.Description, clonedLineItem.Description, 'Line description should be copied.');
        System.assertEquals(originalLineItem.ServiceDate, clonedLineItem.ServiceDate, 'Service date should be copied.');
    }

    @IsTest
    static void cloneQuoteWithLineItems_handlesQuoteWithoutLineItems() {
        Opportunity opportunity = [
            SELECT Id
            FROM Opportunity
            WHERE Name = 'Quote Cloner Test Opportunity'
            LIMIT 1
        ];

        Quote quoteWithoutLines = new Quote(
            Name = 'Quote Without Lines',
            OpportunityId = opportunity.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Status = 'Draft'
        );
        insert quoteWithoutLines;

        Test.startTest();
        Id clonedQuoteId = QuoteCloner.cloneQuoteWithLineItems(quoteWithoutLines.Id);
        Test.stopTest();

        Quote clonedQuote = [
            SELECT Id, Name, Status
            FROM Quote
            WHERE Id = :clonedQuoteId
            LIMIT 1
        ];
        Integer clonedLineItemCount = [
            SELECT COUNT()
            FROM QuoteLineItem
            WHERE QuoteId = :clonedQuoteId
        ];

        System.assertEquals('Quote Without Lines - Clone', clonedQuote.Name, 'Quote should clone without line items.');
        System.assertEquals('Draft', clonedQuote.Status, 'Cloned quote should be Draft.');
        System.assertEquals(0, clonedLineItemCount, 'No line items should be created when original has none.');
    }

    private static PricebookEntry getOrCreatePricebookEntry(Id pricebookId, Id productId, Decimal unitPrice) {
        List<PricebookEntry> entries = [
            SELECT Id
            FROM PricebookEntry
            WHERE Pricebook2Id = :pricebookId
            AND Product2Id = :productId
            LIMIT 1
        ];

        if (!entries.isEmpty()) {
            return entries[0];
        }

        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = productId,
            UnitPrice = unitPrice,
            IsActive = true
        );
        insert entry;
        return entry;
    }
}
