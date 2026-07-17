@IsTest
private class QuoteSapApprovalCompletionTest {

    @IsTest
    static void coversRunNowEntryPoint() {
        Test.startTest();
        QuoteSapApprovalCompletionBatch.runNow(1);
        Test.stopTest();
    }

    @IsTest
    static void coversExecuteWithSapQuoteAndQli() {
        Id quoteId = createSapApprovedQuoteData();

        QuoteSapApprovalCompletionBatch batchJob = new QuoteSapApprovalCompletionBatch();

        Test.startTest();
        batchJob.execute(null, new List<SObject>{ new Quote(Id = quoteId) });
        batchJob.finish(null);
        Test.stopTest();
    }

    @IsTest
    static void coversCalculationBranchesInMemory() {
        Id approverId = UserInfo.getUserId();
        Id quoteId = fakeId(Quote.SObjectType, 2);

        Quote q = new Quote(
            Id = quoteId,
            SAP_Quotation_Number__c = 'SAP-COVERAGE',
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
        Integer highestRank = QuoteSapApprovalCompletionBatch.getHighestFinalApproverRank(q, qlis);
        Id highestApprover = QuoteSapApprovalCompletionBatch.getApproverAtRank(q, qlis, highestRank);

        QuoteSapApprovalCompletionBatch.buildQuoteCompletionUpdate(
            q,
            highestRank,
            highestApprover,
            DateTime.now()
        );

        QuoteSapApprovalCompletionBatch.buildQuoteLineItemCompletionUpdate(
            qli,
            q,
            highestRank,
            highestApprover,
            DateTime.now()
        );

        QuoteSapApprovalCompletionBatch.buildQuoteCompletionUpdate(
            new Quote(Id = fakeId(Quote.SObjectType, 3)),
            0,
            null,
            DateTime.now()
        );

        QuoteSapApprovalCompletionBatch.buildQuoteLineItemCompletionUpdate(
            new QuoteLineItem(Id = fakeId(QuoteLineItem.SObjectType, 2), QuoteId = quoteId),
            q,
            0,
            null,
            DateTime.now()
        );
    }

    private static Id createSapApprovedQuoteData() {
        Id approverId = UserInfo.getUserId();
        Id quoteId;

        QuoteSapApprovalCompletionBatch.setCompletionRunningForTest(true);
        try {
            Account acc = new Account(Name = 'SAP Completion Account');
            insert acc;

            Opportunity opp = new Opportunity(
                Name = 'SAP Completion Opportunity',
                AccountId = acc.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                Pricebook2Id = Test.getStandardPricebookId()
            );
            insert opp;

            Product2 product = new Product2(Name = 'SAP Completion Product', IsActive = true);
            insert product;

            PricebookEntry pbe = new PricebookEntry(
                Pricebook2Id = Test.getStandardPricebookId(),
                Product2Id = product.Id,
                UnitPrice = 1000,
                IsActive = true
            );
            insert pbe;

            Quote q = new Quote(
                Name = 'SAP Completion Quote',
                OpportunityId = opp.Id,
                Pricebook2Id = Test.getStandardPricebookId(),
                Status = 'Draft',
                SAP_Quotation_Number__c = 'SAP-TEST-001',
                Sales_Manager__c = approverId,
                Country_Continent_Sales_Head_LOB_Head__c = approverId,
                Global_Sales_Head__c = approverId,
                Rotex_Board_Member__c = approverId,
                Managing_Director_Country_Manager__c = approverId,
                Final_Warranty_Terms_Approver__c = approverId,
                Final_Validity_Offer_Approver__c = approverId,
                Final_Total_Value_Approver__c = approverId,
                SM_Warranty_Status__c = 'Submitted',
                SM_Validity_Offer_Status__c = 'Submitted',
                SM_Value_Status__c = 'Submitted'
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
                Final_Discount_Approver__c = approverId,
                Sales_Manager_Status__c = 'Submitted'
            );
            insert qli;
        } finally {
            QuoteSapApprovalCompletionBatch.setCompletionRunningForTest(false);
        }

        return quoteId;
    }

    private static Id fakeId(Schema.SObjectType sObjectType, Integer seed) {
        String suffix = String.valueOf(seed == null ? 1 : seed).leftPad(12, '0');
        return (Id) (sObjectType.getDescribe().getKeyPrefix() + suffix);
    }
}