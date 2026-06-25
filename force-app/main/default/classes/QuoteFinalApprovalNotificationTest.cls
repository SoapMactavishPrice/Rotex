@isTest
private class QuoteFinalApprovalNotificationTest {

    private static Account createAccount() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        return acc;
    }

    private static Opportunity createOpportunity(Id accId) {
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            AccountId = accId
        );
        insert opp;
        return opp;
    }

    private static Quote createQuote(Id oppId) {
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = oppId,
            Status = 'Draft',
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert q;
        return q;
    }

    private static Product2 createProduct() {
        Product2 product = new Product2(Name = 'Test Product', IsActive = true);
        insert product;
        return product;
    }

    private static PricebookEntry createPricebookEntry(Product2 product) {
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = product.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert pbe;
        return pbe;
    }

    private static QuoteLineItem createQuoteLineItem(Id quoteId, Id pricebookEntryId) {
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = quoteId,
            PricebookEntryId = pricebookEntryId,
            Quantity = 1,
            UnitPrice = 100.00
        );
        insert qli;
        return qli;
    }

    private static User createUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@testorg.com',
            Username = 'testuser' + DateTime.now().getTime() + '@testorg.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;
        return u;
    }

    // ─── handleQuotesAfterUpdate ───────────────────────────────────────────────

    @isTest
    static void testHandleQuotesAfterUpdate_NullInputs() {
        Test.startTest();
        QuoteFinalApprovalNotificationHandler.handleQuotesAfterUpdate(null, null);
        QuoteFinalApprovalNotificationHandler.handleQuotesAfterUpdate(new List<Quote>(), new Map<Id, Quote>());
        Test.stopTest();
    }

    @isTest
    static void testHandleQuotesAfterUpdate_ApprovalStatusJustApproved() {
        Account acc = createAccount();
        Opportunity opp = createOpportunity(acc.Id);
        Quote q = createQuote(opp.Id);

        Quote oldQ = q.clone(true, true, false, false);
        oldQ.Approval_Status__c = 'Pending';

        Quote newQ = q.clone(true, true, false, false);
        newQ.Approval_Status__c = 'Approved';

        Test.startTest();
        QuoteFinalApprovalNotificationHandler.handleQuotesAfterUpdate(
            new List<Quote>{ newQ },
            new Map<Id, Quote>{ oldQ.Id => oldQ }
        );
        Test.stopTest();
    }

    @isTest
    static void testHandleQuotesAfterUpdate_PaymentTermsJustApproved() {
        Account acc = createAccount();
        Opportunity opp = createOpportunity(acc.Id);
        Quote q = createQuote(opp.Id);

        Quote oldQ = q.clone(true, true, false, false);
        oldQ.Payment_Terms_Approval_Status__c = 'Pending';

        Quote newQ = q.clone(true, true, false, false);
        newQ.Payment_Terms_Approval_Status__c = 'Approved';

        Test.startTest();
        QuoteFinalApprovalNotificationHandler.handleQuotesAfterUpdate(
            new List<Quote>{ newQ },
            new Map<Id, Quote>{ oldQ.Id => oldQ }
        );
        Test.stopTest();
    }

    @isTest
    static void testHandleQuotesAfterUpdate_WarrantyTermsJustApproved() {
        Account acc = createAccount();
        Opportunity opp = createOpportunity(acc.Id);
        Quote q = createQuote(opp.Id);

        Quote oldQ = q.clone(true, true, false, false);
        oldQ.Warranty_Terms_Approval_Status__c = 'Pending';

        Quote newQ = q.clone(true, true, false, false);
        newQ.Warranty_Terms_Approval_Status__c = 'Approved';

        Test.startTest();
        QuoteFinalApprovalNotificationHandler.handleQuotesAfterUpdate(
            new List<Quote>{ newQ },
            new Map<Id, Quote>{ oldQ.Id => oldQ }
        );
        Test.stopTest();
    }

    @isTest
    static void testHandleQuotesAfterUpdate_MinimumOfferJustApproved() {
        Account acc = createAccount();
        Opportunity opp = createOpportunity(acc.Id);
        Quote q = createQuote(opp.Id);

        Quote oldQ = q.clone(true, true, false, false);
        oldQ.Minimum_Offer_Approval_Status__c = 'Pending';

        Quote newQ = q.clone(true, true, false, false);
        newQ.Minimum_Offer_Approval_Status__c = 'Approved';

        Test.startTest();
        QuoteFinalApprovalNotificationHandler.handleQuotesAfterUpdate(
            new List<Quote>{ newQ },
            new Map<Id, Quote>{ oldQ.Id => oldQ }
        );
        Test.stopTest();
    }

    @isTest
    static void testHandleQuotesAfterUpdate_WarrantyFinalApprover_BM() {
        User u = createUser();
        Account acc = createAccount();
        Opportunity opp = createOpportunity(acc.Id);
        Quote q = createQuote(opp.Id);

        Quote oldQ = q.clone(true, true, false, false);
        oldQ.BM_Warranty_Status__c = 'Pending';
        oldQ.Rotex_Board_Member__c = u.Id;
        oldQ.Final_Warranty_Terms_Approver__c = u.Id;

        Quote newQ = q.clone(true, true, false, false);
        newQ.BM_Warranty_Status__c = 'Approved';
        newQ.Rotex_Board_Member__c = u.Id;
        newQ.Final_Warranty_Terms_Approver__c = u.Id;

        Test.startTest();
        QuoteFinalApprovalNotificationHandler.handleQuotesAfterUpdate(
            new List<Quote>{ newQ },
            new Map<Id, Quote>{ oldQ.Id => oldQ }
        );
        Test.stopTest();
    }

    @isTest
    static void testHandleQuotesAfterUpdate_NoChange() {
        Account acc = createAccount();
        Opportunity opp = createOpportunity(acc.Id);
        Quote q = createQuote(opp.Id);

        Quote oldQ = q.clone(true, true, false, false);
        oldQ.Approval_Status__c = 'Approved';

        Quote newQ = q.clone(true, true, false, false);
        newQ.Approval_Status__c = 'Approved'; // no change

        Test.startTest();
        QuoteFinalApprovalNotificationHandler.handleQuotesAfterUpdate(
            new List<Quote>{ newQ },
            new Map<Id, Quote>{ oldQ.Id => oldQ }
        );
        Test.stopTest();
    }

    // ─── Warranty Approver Final Approval ─────────────────────────────────────

    @isTest
    static void testHandleQuotesAfterUpdate_WarrantyFinalApprover_SM() {
        User u = createUser();
        Account acc = createAccount();
        Opportunity opp = createOpportunity(acc.Id);
        Quote q = createQuote(opp.Id);

        Quote oldQ = q.clone(true, true, false, false);
        oldQ.SM_Warranty_Status__c = 'Pending';
        oldQ.Sales_Manager__c = u.Id;
        oldQ.Final_Warranty_Terms_Approver__c = u.Id;

        Quote newQ = q.clone(true, true, false, false);
        newQ.SM_Warranty_Status__c = 'Approved';
        newQ.Sales_Manager__c = u.Id;
        newQ.Final_Warranty_Terms_Approver__c = u.Id;

        Test.startTest();
        QuoteFinalApprovalNotificationHandler.handleQuotesAfterUpdate(
            new List<Quote>{ newQ },
            new Map<Id, Quote>{ oldQ.Id => oldQ }
        );
        Test.stopTest();
    }

    @isTest
    static void testHandleQuotesAfterUpdate_ValidityFinalApprover_CH() {
        User u = createUser();
        Account acc = createAccount();
        Opportunity opp = createOpportunity(acc.Id);
        Quote q = createQuote(opp.Id);

        Quote oldQ = q.clone(true, true, false, false);
        oldQ.CH_Validity_Offer_Status__c = 'Pending';
        oldQ.Country_Continent_Sales_Head_LOB_Head__c = u.Id;
        oldQ.Final_Validity_Offer_Approver__c = u.Id;

        Quote newQ = q.clone(true, true, false, false);
        newQ.CH_Validity_Offer_Status__c = 'Approved';
        newQ.Country_Continent_Sales_Head_LOB_Head__c = u.Id;
        newQ.Final_Validity_Offer_Approver__c = u.Id;

        Test.startTest();
        QuoteFinalApprovalNotificationHandler.handleQuotesAfterUpdate(
            new List<Quote>{ newQ },
            new Map<Id, Quote>{ oldQ.Id => oldQ }
        );
        Test.stopTest();
    }

    @isTest
    static void testHandleQuotesAfterUpdate_TotalValueFinalApprover_GS() {
        User u = createUser();
        Account acc = createAccount();
        Opportunity opp = createOpportunity(acc.Id);
        Quote q = createQuote(opp.Id);

        Quote oldQ = q.clone(true, true, false, false);
        oldQ.GS_Value_Status__c = 'Pending';
        oldQ.Global_Sales_Head__c = u.Id;
        oldQ.Final_Total_Value_Approver__c = u.Id;

        Quote newQ = q.clone(true, true, false, false);
        newQ.GS_Value_Status__c = 'Approved';
        newQ.Global_Sales_Head__c = u.Id;
        newQ.Final_Total_Value_Approver__c = u.Id;

        Test.startTest();
        QuoteFinalApprovalNotificationHandler.handleQuotesAfterUpdate(
            new List<Quote>{ newQ },
            new Map<Id, Quote>{ oldQ.Id => oldQ }
        );
        Test.stopTest();
    }

    @isTest
    static void testHandleQuotesAfterUpdate_MinOfferFinalApprover_MD() {
        User u = createUser();
        Account acc = createAccount();
        Opportunity opp = createOpportunity(acc.Id);
        Quote q = createQuote(opp.Id);

        Quote oldQ = q.clone(true, true, false, false);
        oldQ.MD_Min_Offer_Status__c = 'Pending';
        oldQ.Managing_Director_Country_Manager__c = u.Id;
        oldQ.Final_Minimum_Offer_Value_Approver__c = u.Id;

        Quote newQ = q.clone(true, true, false, false);
        newQ.MD_Min_Offer_Status__c = 'Approved';
        newQ.Managing_Director_Country_Manager__c = u.Id;
        newQ.Final_Minimum_Offer_Value_Approver__c = u.Id;

        Test.startTest();
        QuoteFinalApprovalNotificationHandler.handleQuotesAfterUpdate(
            new List<Quote>{ newQ },
            new Map<Id, Quote>{ oldQ.Id => oldQ }
        );
        Test.stopTest();
    }

    @isTest
    static void testHandleQuotesAfterUpdate_FinalApprover_Null() {
        Account acc = createAccount();
        Opportunity opp = createOpportunity(acc.Id);
        Quote q = createQuote(opp.Id);

        Quote oldQ = q.clone(true, true, false, false);
        oldQ.Final_Warranty_Terms_Approver__c = null;
        oldQ.SM_Warranty_Status__c = 'Pending';

        Quote newQ = q.clone(true, true, false, false);
        newQ.Final_Warranty_Terms_Approver__c = null;
        newQ.SM_Warranty_Status__c = 'Approved';

        Test.startTest();
        QuoteFinalApprovalNotificationHandler.handleQuotesAfterUpdate(
            new List<Quote>{ newQ },
            new Map<Id, Quote>{ oldQ.Id => oldQ }
        );
        Test.stopTest();
    }

    // ─── handleQuoteLineItemsAfterUpdate ──────────────────────────────────────

    @isTest
    static void testHandleQuoteLineItemsAfterUpdate_NullInputs() {
        Test.startTest();
        QuoteFinalApprovalNotificationHandler.handleQuoteLineItemsAfterUpdate(null, null);
        QuoteFinalApprovalNotificationHandler.handleQuoteLineItemsAfterUpdate(
            new List<QuoteLineItem>(),
            new Map<Id, QuoteLineItem>()
        );
        Test.stopTest();
    }

    @isTest
    static void testHandleQuoteLineItemsAfterUpdate_ApprovalStatusJustApproved() {
        Account acc = createAccount();
        Opportunity opp = createOpportunity(acc.Id);
        Quote q = createQuote(opp.Id);
        Product2 product = createProduct();
        PricebookEntry pbe = createPricebookEntry(product);
        QuoteLineItem qli = createQuoteLineItem(q.Id, pbe.Id);

        QuoteLineItem oldQli = qli.clone(true, true, false, false);
        oldQli.Approval_Status__c = 'Pending';

        QuoteLineItem newQli = qli.clone(true, true, false, false);
        newQli.Approval_Status__c = 'Approved';

        Test.startTest();
        QuoteFinalApprovalNotificationHandler.handleQuoteLineItemsAfterUpdate(
            new List<QuoteLineItem>{ newQli },
            new Map<Id, QuoteLineItem>{ oldQli.Id => oldQli }
        );
        Test.stopTest();
    }

    @isTest
    static void testHandleQuoteLineItemsAfterUpdate_SalesManagerStageApproved() {
        User u = createUser();
        Account acc = createAccount();
        Opportunity opp = createOpportunity(acc.Id);
        Quote q = createQuote(opp.Id);
        Product2 product = createProduct();
        PricebookEntry pbe = createPricebookEntry(product);
        QuoteLineItem qli = createQuoteLineItem(q.Id, pbe.Id);

        QuoteLineItem oldQli = qli.clone(true, true, false, false);
        oldQli.Sales_Manager_Status__c = 'Pending';
        oldQli.Sales_Manager__c = u.Id;
        oldQli.Final_Discount_Approver__c = u.Id;

        QuoteLineItem newQli = qli.clone(true, true, false, false);
        newQli.Sales_Manager_Status__c = 'Approved';
        newQli.Sales_Manager__c = u.Id;
        newQli.Final_Discount_Approver__c = u.Id;

        Test.startTest();
        QuoteFinalApprovalNotificationHandler.handleQuoteLineItemsAfterUpdate(
            new List<QuoteLineItem>{ newQli },
            new Map<Id, QuoteLineItem>{ oldQli.Id => oldQli }
        );
        Test.stopTest();
    }

}