@IsTest
private class QuoteHighApproverBackfillTest {

    @IsTest
    static void coversRunNowEntryPoint() {
        Test.startTest();
        QuoteHighestFinalApproverBackfillBatch.runNow(1);
        Test.stopTest();
    }

    @IsTest
    static void coversExecuteWithQuoteAndQuoteLineItem() {
        Id quoteId = createBackfillData();

        QuoteHighestFinalApproverBackfillBatch batchJob =
            new QuoteHighestFinalApproverBackfillBatch();

        Test.startTest();
        batchJob.execute(null, new List<SObject>{
            new Quote(Id = quoteId)
        });
        batchJob.finish(null);
        Test.stopTest();
    }

    @IsTest
    static void coversEffectiveApproverCalculationOnly() {
        Id approverId = UserInfo.getUserId();
        Id quoteId = fakeId(Quote.SObjectType, 2);

        Quote q = new Quote(
            Id = quoteId,
            Sales_Manager__c = approverId,
            Country_Continent_Sales_Head_LOB_Head__c = approverId,
            Global_Sales_Head__c = approverId,
            Rotex_Board_Member__c = approverId,
            Managing_Director_Country_Manager__c = approverId,
            Final_Warranty_Terms_Approver__c = approverId,
            Final_Validity_Offer_Approver__c = approverId,
            Final_Total_Value_Approver__c = approverId
        );

        QuoteLineItem qli = new QuoteLineItem(
            Id = fakeId(QuoteLineItem.SObjectType, 1),
            QuoteId = quoteId,
            Sales_Manager__c = approverId,
            Country_Continent_Sales_Head_LOB_Head__c = approverId,
            Global_Sales_Head__c = approverId,
            Rotex_Board_Member__c = approverId,
            Managing_Director_Country_Manage__c = approverId,
            Final_Discount_Approver__c = approverId
        );

        List<QuoteLineItem> qlis = new List<QuoteLineItem>{ qli };
        Integer highestRank =
            QuoteHighestFinalApproverBackfillBatch.getHighestFinalApproverRank(q, qlis);
        Id highestApprover =
            QuoteHighestFinalApproverBackfillBatch.getApproverAtRank(q, qlis, highestRank);

        QuoteHighestFinalApproverBackfillBatch.buildQuoteEffectiveApproverUpdate(
            q,
            highestRank,
            highestApprover
        );

        QuoteHighestFinalApproverBackfillBatch.buildQuoteLineItemEffectiveApproverUpdate(
            qli,
            q,
            highestRank,
            highestApprover
        );

        QuoteHighestFinalApproverBackfillBatch.buildQuoteEffectiveApproverUpdate(
            new Quote(Id = fakeId(Quote.SObjectType, 3)),
            0,
            null
        );

        QuoteHighestFinalApproverBackfillBatch.buildQuoteLineItemEffectiveApproverUpdate(
            new QuoteLineItem(Id = fakeId(QuoteLineItem.SObjectType, 2), QuoteId = quoteId),
            q,
            0,
            null
        );
    }

    private static Id createBackfillData() {
        Id approverId = UserInfo.getUserId();
        Id quoteId;

        QuoteHighestFinalApproverBackfillBatch.setBackfillRunningForTest(true);
        try {
            Account acc = new Account(Name = 'Backfill Account');
            insert acc;

            Opportunity opp = new Opportunity(
                Name = 'Backfill Opportunity',
                AccountId = acc.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                Pricebook2Id = Test.getStandardPricebookId()
            );
            insert opp;

            Product2 product = new Product2(Name = 'Backfill Product', IsActive = true);
            insert product;

            PricebookEntry pbe = new PricebookEntry(
                Pricebook2Id = Test.getStandardPricebookId(),
                Product2Id = product.Id,
                UnitPrice = 1000,
                IsActive = true
            );
            insert pbe;

            Quote q = new Quote(
                Name = 'Backfill Quote',
                OpportunityId = opp.Id,
                Pricebook2Id = Test.getStandardPricebookId(),
                Status = 'Draft',
                Sales_Manager__c = approverId,
                Country_Continent_Sales_Head_LOB_Head__c = approverId,
                Global_Sales_Head__c = approverId,
                Rotex_Board_Member__c = approverId,
                Managing_Director_Country_Manager__c = approverId,
                Final_Warranty_Terms_Approver__c = approverId,
                Final_Validity_Offer_Approver__c = approverId,
                Final_Total_Value_Approver__c = approverId
            );
            insert q;
            quoteId = q.Id;

            QuoteLineItem qli = new QuoteLineItem(
                QuoteId = q.Id,
                PricebookEntryId = pbe.Id,
                Quantity = 1,
                UnitPrice = 1000,
                Sales_Manager__c = approverId,
                Country_Continent_Sales_Head_LOB_Head__c = approverId,
                Global_Sales_Head__c = approverId,
                Rotex_Board_Member__c = approverId,
                Managing_Director_Country_Manage__c = approverId,
                Final_Discount_Approver__c = approverId
            );
            insert qli;
        } finally {
            QuoteHighestFinalApproverBackfillBatch.setBackfillRunningForTest(false);
        }

        return quoteId;
    }

    private static Id fakeId(Schema.SObjectType sObjectType, Integer seed) {
        String suffix = String.valueOf(seed == null ? 1 : seed).leftPad(12, '0');
        return (Id) (sObjectType.getDescribe().getKeyPrefix() + suffix);
    }
}
