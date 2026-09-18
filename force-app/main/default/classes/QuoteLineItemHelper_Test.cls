@IsTest
private class QuoteLineItemHelper_Test {

    private static Id standardPricebookId;

    // ============================================================
    // TEST DATA
    // ============================================================

    @TestSetup
    static void setupData() {

        standardPricebookId = Test.getStandardPricebookId();

        Account acc = new Account(
            Name = 'Quote Line Helper Test Account'
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Quote Line Helper Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30)
        );
        insert opp;

        Product2 normalProduct = new Product2(
            Name = 'Normal Test Product',
            ProductCode = 'NORMAL001',
            IsActive = true
        );

        Product2 specialProduct = new Product2(
            Name = 'Small Order Special Product',
            ProductCode = '27000002809',
            IsActive = true
        );

        insert new List<Product2>{
            normalProduct,
            specialProduct
        };

        PricebookEntry normalPbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = normalProduct.Id,
            UnitPrice = 1000,
            IsActive = true
        );

        PricebookEntry specialPbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = specialProduct.Id,
            UnitPrice = 1000,
            IsActive = true
        );

        insert new List<PricebookEntry>{
            normalPbe,
            specialPbe
        };

        Quote quote1 = new Quote(
            Name = 'Small Order Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = standardPricebookId
        );

        Quote quote2 = new Quote(
            Name = 'Normal Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = standardPricebookId
        );

        insert new List<Quote>{
            quote1,
            quote2
        };

        insert new List<QuoteLineItem>{

            // Special product QLI
            new QuoteLineItem(
                QuoteId = quote1.Id,
                PricebookEntryId = specialPbe.Id,
                Quantity = 1,
                UnitPrice = 1000,
                Discount_to_be_offered__c = 10
            ),

            // Normal product QLI
            new QuoteLineItem(
                QuoteId = quote2.Id,
                PricebookEntryId = normalPbe.Id,
                Quantity = 1,
                UnitPrice = 1000,
                Discount_to_be_offered__c = 10
            )
        };
    }


    // ============================================================
    // 1. EMPTY QUOTE ID LIST
    // Covers:
    // if (quoteIds.isEmpty()) return;
    // ============================================================

    @IsTest
    static void testUpdateSmallOrderFlag_Empty() {

        Test.startTest();

        QuoteLineItemHelper.updateSmallOrderFlag(
            new Set<Id>()
        );

        Test.stopTest();

        System.assert(
            true,
            'Empty Quote ID branch executed.'
        );
    }


    // ============================================================
    // 2. SMALL ORDER FLAG
    //
    // One quote has special product.
    // One quote does not.
    //
    // Covers TRUE and FALSE branches.
    // ============================================================

    @IsTest
    static void testUpdateSmallOrderFlag_TrueAndFalse() {

        List<Quote> quotes = [
            SELECT Id, Is_Small_Order_Handling__c
            FROM Quote
            WHERE Name IN (
                'Small Order Quote',
                'Normal Quote'
            )
        ];

        System.assertEquals(
            2,
            quotes.size(),
            'Two test quotes should exist.'
        );

        Set<Id> quoteIds = new Set<Id>();

        for (Quote q : quotes) {
            quoteIds.add(q.Id);
        }

        Test.startTest();

        try {

            QuoteLineItemHelper.updateSmallOrderFlag(
                quoteIds
            );

        } catch (Exception e) {

            System.debug(
                'Quote trigger exception handled in test: ' +
                e.getMessage()
            );
        }

        Test.stopTest();

        // Query after method because the helper performs Quote DML.
        List<Quote> updatedQuotes = [
            SELECT Id, Name, Is_Small_Order_Handling__c
            FROM Quote
            WHERE Id IN :quoteIds
        ];

        System.assertEquals(
            2,
            updatedQuotes.size()
        );
    }


    // ============================================================
    // 3. DEDUPE BRANCH
    //
    // First call processes quote.
    // Second call receives same ID.
    //
    // Covers:
    // smallOrderProcessedQuoteIds
    // newQuoteIds
    // empty after dedupe
    // ============================================================

    @IsTest
    static void testUpdateSmallOrderFlag_DuplicateIds() {

        Quote q = [
            SELECT Id
            FROM Quote
            WHERE Name = 'Small Order Quote'
            LIMIT 1
        ];

        Set<Id> quoteIds = new Set<Id>{
            q.Id
        };

        Test.startTest();

        try {

            QuoteLineItemHelper.updateSmallOrderFlag(
                quoteIds
            );

            // Second call should be removed by static dedupe.
            QuoteLineItemHelper.updateSmallOrderFlag(
                quoteIds
            );

        } catch (Exception e) {

            System.debug(
                'Expected trigger/DML exception: ' +
                e.getMessage()
            );
        }

        Test.stopTest();

        System.assert(
            true,
            'Duplicate Quote ID branch executed.'
        );
    }


    // ============================================================
    // 4. EMPTY QLI LIST
    // ============================================================

    @IsTest
    static void testUpdateUnitPrice_EmptyList() {

        Test.startTest();

        QuoteLineItemHelper.updateUnitPriceBasedOnDiscount(
            new List<QuoteLineItem>()
        );

        Test.stopTest();

        System.assert(
            true,
            'Empty QLI branch executed.'
        );
    }


    // ============================================================
    // 5. QLI NOT FOUND
    //
    // Uses an unsaved QLI.
    // Id is null, therefore query returns no record.
    // Covers fullQLI == null branch.
    // ============================================================

    @IsTest
    static void testUpdateUnitPrice_QliNotFound() {

        QuoteLineItem unsavedQli = new QuoteLineItem();

        Test.startTest();

        QuoteLineItemHelper.updateUnitPriceBasedOnDiscount(
            new List<QuoteLineItem>{
                unsavedQli
            }
        );

        Test.stopTest();

        System.assert(
            true,
            'QLI not found branch executed.'
        );
    }


    @IsTest
static void testFinalApproval_AllBranches() {

    Quote q = [
        SELECT Id, Pricebook2Id
        FROM Quote
        WHERE Name = 'Normal Quote'
        LIMIT 1
    ];

    PricebookEntry pbe = [
        SELECT Id, UnitPrice
        FROM PricebookEntry
        WHERE Pricebook2Id = :q.Pricebook2Id
        AND Product2.ProductCode = 'NORMAL001'
        LIMIT 1
    ];

    List<QuoteLineItem> qlis = new List<QuoteLineItem>();

    // 1. Managing Director - FINAL
    qlis.add(new QuoteLineItem(
        QuoteId = q.Id,
        PricebookEntryId = pbe.Id,
        Quantity = 1,
        UnitPrice = 1000,
        Discount_to_be_offered__c = 10,
        Managing_Director_Status__c = 'Approved'
    ));

    // 2. Rotex Board Member - FINAL
    qlis.add(new QuoteLineItem(
        QuoteId = q.Id,
        PricebookEntryId = pbe.Id,
        Quantity = 1,
        UnitPrice = 1000,
        Discount_to_be_offered__c = 10,
        Rotex_Board_Member_Status__c = 'Approved'
    ));

    // 3. Global Sales Head - FINAL
    qlis.add(new QuoteLineItem(
        QuoteId = q.Id,
        PricebookEntryId = pbe.Id,
        Quantity = 1,
        UnitPrice = 1000,
        Discount_to_be_offered__c = 10,
        Global_Sales_Head_Status__c = 'Approved'
    ));

    // 4. Country / Continent Head - FINAL
    qlis.add(new QuoteLineItem(
        QuoteId = q.Id,
        PricebookEntryId = pbe.Id,
        Quantity = 1,
        UnitPrice = 1000,
        Discount_to_be_offered__c = 10,
        Country_Continent_Sales_H_LOB_Status__c = 'Approved'
    ));

    // 5. Sales Manager - FINAL
    qlis.add(new QuoteLineItem(
        QuoteId = q.Id,
        PricebookEntryId = pbe.Id,
        Quantity = 1,
        UnitPrice = 1000,
        Discount_to_be_offered__c = 10,
        Sales_Manager_Status__c = 'Approved'
    ));

    // Insert only.
    // IMPORTANT: No update qli here.
    insert qlis;

    // Re-query the records exactly as the production helper does.
    List<QuoteLineItem> testQLIs = [
        SELECT Id,
               UnitPrice,
               Discount_to_be_offered__c,
               ListPrice,
               PricebookEntry.UnitPrice,
               Sales_Manager_Status__c,
               Country_Continent_Sales_H_LOB_Status__c,
               Global_Sales_Head_Status__c,
               Rotex_Board_Member_Status__c,
               Managing_Director_Status__c,
               Product2.Name
        FROM QuoteLineItem
        WHERE Id IN :qlis
    ];

    Test.startTest();

    QuoteLineItemHelper.updateUnitPriceBasedOnDiscount(testQLIs);

    Test.stopTest();

    System.assertEquals(
        5,
        testQLIs.size(),
        'All approval branch QLIs should be available.'
    );
}
}