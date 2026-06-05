@IsTest
private class QuoteApprovalResubmitControllerTest {

    private static Quote createQuote() {
        Account acc = new Account(Name = 'Resubmit Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Resubmit Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10)
        );
        insert opp;

        Quote q = new Quote(
            Name = 'Resubmit Test Quote',
            OpportunityId = opp.Id,
            Status = 'Draft',
            Pricebook2Id = Test.getStandardPricebookId(),
            Sales_Manager__c = UserInfo.getUserId()
        );
        insert q;
        return q;
    }

    @IsTest
    static void testGetResubmittableApprovalsOnlyReturnsRejectedTypes() {
        Quote q = createQuote();
        q.Warranty_Terms_Draft__c = '24 Months from date of supply';
        q.Requested_Validity_Of_Offer__c = '60 Days';
        update q;

        q = [
            SELECT Id,
                   SM_Warranty_Status__c,
                   SM_Validity_Offer_Status__c,
                   SM_Value_Status__c
            FROM Quote
            WHERE Id = :q.Id
        ];
        q.SM_Warranty_Status__c = 'Rejected';
        q.SM_Warranty_Comments__c = 'Warranty comment';
        q.SM_Validity_Offer_Status__c = 'Submitted';
        q.SM_Value_Status__c = 'Rejected';
        q.SM_Value_Comments__c = 'Total value comment';
        update q;

        Test.startTest();
        QuoteApprovalResubmitController.ResubmitData data =
            QuoteApprovalResubmitController.getResubmittableApprovals(q.Id);
        Test.stopTest();

        System.assertEquals(2, data.options.size(), 'Only rejected approval types should be returned.');
        Set<String> optionValues = new Set<String>();
        for (QuoteApprovalResubmitController.ApprovalOption option : data.options) {
            optionValues.add(option.value);
        }
        System.assert(optionValues.contains('WARRANTY'), 'Warranty should be resubmittable.');
        System.assert(optionValues.contains('TOTAL_VALUE'), 'Total Value should be resubmittable.');
        System.assert(!optionValues.contains('VALIDITY'), 'Submitted Validity should not be resubmittable.');
    }

    @IsTest
    static void testResubmitWarrantyPreservesCommentsAndClearsDates() {
        Quote q = createQuote();
        q.Warranty_Terms_Draft__c = '24 Months from date of supply';
        update q;

        q = [SELECT Id, SM_Warranty_Status__c FROM Quote WHERE Id = :q.Id];
        q.SM_Warranty_Status__c = 'Rejected';
        q.SM_Warranty_Comments__c = 'Keep this warranty comment';
        q.SM_Warranty_Date_Time__c = DateTime.now().addDays(-1);
        update q;

        Test.startTest();
        String result = QuoteApprovalResubmitController.resubmitApproval(q.Id, 'WARRANTY');
        Test.stopTest();

        Quote refreshed = [
            SELECT SM_Warranty_Status__c,
                   SM_Warranty_Comments__c,
                   SM_Warranty_Date_Time__c,
                   CH_Warranty_Status__c
            FROM Quote
            WHERE Id = :q.Id
        ];
        System.assertEquals('Success', result);
        System.assertEquals('Submitted', refreshed.SM_Warranty_Status__c);
        System.assertEquals('Keep this warranty comment', refreshed.SM_Warranty_Comments__c);
        System.assertEquals(null, refreshed.SM_Warranty_Date_Time__c);
        System.assertEquals(null, refreshed.CH_Warranty_Status__c);
    }

    @IsTest
    static void testResubmitTotalValueRecalculatesAndPreservesComments() {
        Quote q = createQuote();
        q = [SELECT Id, SM_Value_Status__c FROM Quote WHERE Id = :q.Id];
        q.SM_Value_Status__c = 'Rejected';
        q.SM_Value_Comments__c = 'Keep this total value comment';
        q.SM_Value_Date_Time__c = DateTime.now().addDays(-1);
        q.CH_Value_Status__c = 'Submitted';
        q.CH_Value_Comments__c = 'Existing CH comment';
        q.CH_Value_Date_Time__c = DateTime.now().addDays(-1);
        update q;

        Test.startTest();
        String result = QuoteApprovalResubmitController.resubmitApproval(q.Id, 'TOTAL_VALUE');
        Test.stopTest();

        Quote refreshed = [
            SELECT Is_Total_Value_Approved__c,
                   Final_Total_Value_Approver__c,
                   Sales_Manager__c,
                   SM_Value_Status__c,
                   SM_Value_Comments__c,
                   SM_Value_Date_Time__c,
                   CH_Value_Status__c,
                   CH_Value_Comments__c,
                   CH_Value_Date_Time__c
            FROM Quote
            WHERE Id = :q.Id
        ];
        System.assertEquals('Success', result);
        System.assertEquals(false, refreshed.Is_Total_Value_Approved__c);
        System.assertEquals(refreshed.Sales_Manager__c, refreshed.Final_Total_Value_Approver__c);
        System.assertEquals('Submitted', refreshed.SM_Value_Status__c);
        System.assertEquals('Keep this total value comment', refreshed.SM_Value_Comments__c);
        System.assertEquals(null, refreshed.SM_Value_Date_Time__c);
        System.assertEquals(null, refreshed.CH_Value_Status__c);
        System.assertEquals('Existing CH comment', refreshed.CH_Value_Comments__c);
        System.assertEquals(null, refreshed.CH_Value_Date_Time__c);
    }

    @IsTest
    static void testCannotResubmitNonRejectedApproval() {
        Quote q = createQuote();
        q.Requested_Validity_Of_Offer__c = '60 Days';
        update q;

        Boolean blocked = false;
        try {
            QuoteApprovalResubmitController.resubmitApproval(q.Id, 'VALIDITY');
        } catch (AuraHandledException e) {
            blocked = true;
        }
        System.assertEquals(true, blocked, 'Expected non-rejected approval to be blocked.');
    }

    @IsTest
    static void testResubmitValidityPreservesCommentsAndClearsDates() {
        Quote q = createQuote();
        q.Requested_Validity_Of_Offer__c = '60 Days';
        update q;

        q = [SELECT Id, SM_Validity_Offer_Status__c FROM Quote WHERE Id = :q.Id];
        q.SM_Validity_Offer_Status__c = 'Approved';
        q.SM_Validity_Offer_Comments__c = 'Keep SM validity comment';
        q.SM_Validity_Offer_Date_Time__c = DateTime.now().addDays(-2);
        q.CH_Validity_Offer_Status__c = 'Rejected';
        q.CH_Validity_Offer_Comments__c = 'Keep CH validity comment';
        q.CH_Validity_Offer_Date_Time__c = DateTime.now().addDays(-1);
        update q;

        Test.startTest();
        String result = QuoteApprovalResubmitController.resubmitApproval(q.Id, 'VALIDITY');
        Test.stopTest();

        Quote refreshed = [
            SELECT SM_Validity_Offer_Status__c,
                   SM_Validity_Offer_Comments__c,
                   SM_Validity_Offer_Date_Time__c,
                   CH_Validity_Offer_Status__c,
                   CH_Validity_Offer_Comments__c,
                   CH_Validity_Offer_Date_Time__c
            FROM Quote
            WHERE Id = :q.Id
        ];
        System.assertEquals('Success', result);
        System.assertEquals('Submitted', refreshed.SM_Validity_Offer_Status__c);
        System.assertEquals('Keep SM validity comment', refreshed.SM_Validity_Offer_Comments__c);
        System.assertEquals(null, refreshed.SM_Validity_Offer_Date_Time__c);
        System.assertEquals(null, refreshed.CH_Validity_Offer_Status__c);
        System.assertEquals('Keep CH validity comment', refreshed.CH_Validity_Offer_Comments__c);
        System.assertEquals(null, refreshed.CH_Validity_Offer_Date_Time__c);
    }

    @IsTest
    static void testUnsupportedApprovalTypeIsBlocked() {
        Quote q = createQuote();

        Boolean blocked = false;
        try {
            QuoteApprovalResubmitController.resubmitApproval(q.Id, 'NOT_REAL');
        } catch (AuraHandledException e) {
            blocked = true;
        }
        System.assertEquals(true, blocked, 'Unsupported approval type should be blocked.');
    }

    @IsTest
    static void testEmptyAndInvalidRequestsAreHandled() {
        Quote q = createQuote();

        Test.startTest();
        QuoteApprovalResubmitController.ResubmitData data =
            QuoteApprovalResubmitController.getResubmittableApprovals(q.Id);
        Test.stopTest();

        System.assertEquals(0, data.options.size(), 'A quote without rejected approvals should have no options.');

        Boolean nullQuoteBlocked = false;
        try {
            QuoteApprovalResubmitController.getResubmittableApprovals(null);
        } catch (AuraHandledException e) {
            nullQuoteBlocked = true;
        }
        System.assertEquals(true, nullQuoteBlocked, 'Null Quote Id should be blocked.');

        Boolean blankTypeBlocked = false;
        try {
            QuoteApprovalResubmitController.resubmitApproval(q.Id, ' ');
        } catch (AuraHandledException e) {
            blankTypeBlocked = true;
        }
        System.assertEquals(true, blankTypeBlocked, 'Blank approval type should be blocked.');
    }
}