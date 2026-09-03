@IsTest
private class QuoteHighestApprovalCoordinatorTest {
    private static final Id SM = (Id)'005000000000001AAA';
    private static final Id CH = (Id)'005000000000002AAA';
    private static final Id GS = (Id)'005000000000003AAA';
    private static final Id BM = (Id)'005000000000004AAA';
    private static final Id MD = (Id)'005000000000005AAA';

    @IsTest
    static void ranksQuoteAndLineApproversInSoaOrder() {
        Quote q = quoteHierarchy();
        QuoteLineItem qli = qliHierarchy();

        System.assertEquals(1, QuoteHighestApprovalCoordinator.quoteRank(q, SM));
        System.assertEquals(4, QuoteHighestApprovalCoordinator.quoteRank(q, BM));
        System.assertEquals(5, QuoteHighestApprovalCoordinator.qliRank(qli, MD));
        System.assertEquals(0, QuoteHighestApprovalCoordinator.qliRank(qli, null));
    }

    @IsTest
    static void recognizesOnlyEffectiveFinalApproval() {
        QuoteLineItem oldQli = qliHierarchy();
        oldQli.Final_Discount_Approver__c = SM;
        oldQli.Effective_Final_Discount_Approver__c = BM;
        oldQli.Sales_Manager_Status__c = 'Submitted';
        oldQli.Rotex_Board_Member_Status__c = 'Submitted';

        QuoteLineItem smApproved = oldQli.clone(false, false, false, false);
        smApproved.Sales_Manager_Status__c = 'Approved';
        System.assertEquals(false,
            QuoteHighestApprovalCoordinator.isEffectiveQliApprovalJustGranted(smApproved, oldQli));

        QuoteLineItem bmApproved = oldQli.clone(false, false, false, false);
        bmApproved.Rotex_Board_Member_Status__c = 'Approved';
        System.assertEquals(true,
            QuoteHighestApprovalCoordinator.isEffectiveQliApprovalJustGranted(bmApproved, oldQli));
    }

    @IsTest
    static void jumpsFromIntrinsicFinalDirectlyToHighestFinal() {
        Id qliId = (Id)'0QL000000000001AAA';
        QuoteLineItem oldQli = qliHierarchy();
        oldQli.Id = qliId;
        oldQli.Final_Discount_Approver__c = SM;
        oldQli.Effective_Final_Discount_Approver__c = BM;
        oldQli.Sales_Manager_Status__c = 'Submitted';

        QuoteLineItem newQli = oldQli.clone(true, false, false, false);
        newQli.Sales_Manager_Status__c = 'Approved';

        QuoteLineItemSequentialApprovalHandler.defineNextApprover(
            new List<QuoteLineItem>{ newQli },
            new Map<Id, QuoteLineItem>{ qliId => oldQli }
        );

        System.assertEquals('Submitted', newQli.Rotex_Board_Member_Status__c);
        System.assertEquals(null, newQli.Country_Continent_Sales_H_LOB_Status__c);
        System.assertEquals(null, newQli.Global_Sales_Head_Status__c);
    }

    private static Quote quoteHierarchy() {
        return new Quote(
            Sales_Manager__c = SM,
            Country_Continent_Sales_Head_LOB_Head__c = CH,
            Global_Sales_Head__c = GS,
            Rotex_Board_Member__c = BM,
            Managing_Director_Country_Manager__c = MD
        );
    }

    private static QuoteLineItem qliHierarchy() {
        return new QuoteLineItem(
            Sales_Manager__c = SM,
            Country_Continent_Sales_Head_LOB_Head__c = CH,
            Global_Sales_Head__c = GS,
            Rotex_Board_Member__c = BM,
            Managing_Director_Country_Manage__c = MD,
            Discount_to_be_offered__c = 25
        );
    }
}