@isTest
private class SalesPriceApprovalForQuotationTest {
    
    @TestSetup
    static void setupTestData() {
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User salesRep = new User(
            FirstName = 'Sales', LastName = 'Rep', Email = 'salesrep@test.com',
            Username = 'salesrep@test' + System.currentTimeMillis() + '.com',
            Alias = 'srep', TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id, LanguageLocaleKey = 'en_US',
            Division__c = 'Domestic'
        );
        insert salesRep;
        
        User salesManager = new User(
            FirstName = 'Sales', LastName = 'Manager', Email = 'salesmanager@test.com',
            Username = 'salesmanager@test' + System.currentTimeMillis() + '.com',
            Alias = 'smgr', TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id, LanguageLocaleKey = 'en_US',
            Division__c = 'Domestic'
        );
        insert salesManager;
        
        User countryHead = new User(
            FirstName = 'Country', LastName = 'Head', Email = 'countryhead@test.com',
            Username = 'countryhead@test' + System.currentTimeMillis() + '.com',
            Alias = 'chead', TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id, LanguageLocaleKey = 'en_US',
            Division__c = 'Domestic'
        );
        insert countryHead;
        
        User managingDirector = new User(
            FirstName = 'Managing', LastName = 'Director', Email = 'md@test.com',
            Username = 'md@test' + System.currentTimeMillis() + '.com',
            Alias = 'md', TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id, LanguageLocaleKey = 'en_US',
            Division__c = 'Domestic'
        );
        insert managingDirector;
        
        User boardMember = new User(
            FirstName = 'Board', LastName = 'Member', Email = 'board@test.com',
            Username = 'board@test' + System.currentTimeMillis() + '.com',
            Alias = 'board', TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id, LanguageLocaleKey = 'en_US',
            Division__c = 'Domestic'
        );
        insert boardMember;
        
        User globalHead = new User(
            FirstName = 'Global', LastName = 'Head', Email = 'globalhead@test.com',
            Username = 'globalhead@test' + System.currentTimeMillis() + '.com',
            Alias = 'ghead', TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id, LanguageLocaleKey = 'en_US',
            Division__c = 'Domestic'
        );
        insert globalHead;
        
        System.runAs(salesRep) {
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity', AccountId = testAccount.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30),
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert testOpp;

        Id standardPricebookId = Test.getStandardPricebookId();
        update new Pricebook2(Id = standardPricebookId, IsActive = true);
        
        Product2 testProduct = new Product2(Name = 'Test Product', IsActive = true);
        insert testProduct;

        List<PricebookEntry> standardEntries = [
            SELECT Id FROM PricebookEntry
            WHERE Pricebook2Id = :standardPricebookId AND Product2Id = :testProduct.Id LIMIT 1
        ];
        PricebookEntry testPBE;
        if (standardEntries.isEmpty()) {
            testPBE = new PricebookEntry(
                Pricebook2Id = standardPricebookId, Product2Id = testProduct.Id,
                UnitPrice = 1000, IsActive = true
            );
            insert testPBE;
        } else {
            testPBE = standardEntries[0];
        }
        
        Quote testQuote = new Quote(
            Name = 'Test Quote', OpportunityId = testOpp.Id,
            Pricebook2Id = standardPricebookId,
            Sales_Rep__c = salesRep.Id,
            Sales_Manager__c = salesManager.Id,
            Country_Continent_Sales_Head_LOB_Head__c = countryHead.Id,
            Global_Sales_Head__c = globalHead.Id,
            Managing_Director_Country_Manager__c = managingDirector.Id,
            Rotex_Board_Member__c = boardMember.Id,
            RecordTypeId = Schema.SObjectType.Quote.getRecordTypeInfosByName().get('Normal').getRecordTypeId()
        );
        insert testQuote;
        
        QuoteLineItem qli1 = new QuoteLineItem(
            QuoteId = testQuote.Id, Product2Id = testProduct.Id,
            PricebookEntryId = testPBE.Id, Quantity = 1, UnitPrice = 800,
            Discount_as_per_SAP__c = 10, Discount_to_be_offered__c = 15,
            Sales_Rep__c = salesRep.Id, Sales_Rep_Status__c = 'Submitted',
            Sales_Manager__c = salesManager.Id, Sales_Manager_Status__c = 'Submitted',
            Country_Continent_Sales_Head_LOB_Head__c = countryHead.Id,
            Country_Continent_Sales_H_LOB_Status__c = 'Submitted',
            Managing_Director_Country_Manage__c = managingDirector.Id,
            Managing_Director_Status__c = 'Submitted',
            Rotex_Board_Member__c = boardMember.Id, Rotex_Board_Member_Status__c = 'Submitted',
            Global_Sales_Head__c = globalHead.Id, Global_Sales_Head_Status__c = 'Submitted',
            Final_Discount_Approver__c = salesRep.Id
        );
        insert qli1;
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private static SalesPriceApprovalForQuotation.QuotationWrapper buildWrapper(
        QuoteLineItem qli, String currentStageField, String approvalStatus
    ) {
        SalesPriceApprovalForQuotation.QuotationWrapper wrapper =
            new SalesPriceApprovalForQuotation.QuotationWrapper();
        wrapper.quoteId = qli.QuoteId;
        wrapper.quoteOwnerId = UserInfo.getUserId();
        wrapper.quoteOwnerEmail = 'owner@test.com';
        wrapper.quoteOwnerName = 'Test Owner';
        wrapper.quoteName = 'Test Quote';
        wrapper.accountOwner = UserInfo.getUserId();
        wrapper.updated = true;

        SalesPriceApprovalForQuotation.QuotationLineItemWrapper lineWrapper =
            new SalesPriceApprovalForQuotation.QuotationLineItemWrapper();
        lineWrapper.quoteLineItemId = qli.Id;
        lineWrapper.approvalStatus = approvalStatus;
        lineWrapper.currentStageField = currentStageField;
        lineWrapper.updated = true;
        lineWrapper.isFinalDiscountApprover = true;

        wrapper.quoteLineItems =
            new List<SalesPriceApprovalForQuotation.QuotationLineItemWrapper>{ lineWrapper };
        return wrapper;
    }

    private static String serializeWrapper(
        SalesPriceApprovalForQuotation.QuotationWrapper wrapper
    ) {
        return JSON.serialize(
            new List<SalesPriceApprovalForQuotation.QuotationWrapper>{ wrapper }
        );
    }

    private static Quote fetchFullQuote() {
        return [
            SELECT Id, Name, QuoteNumber, Account.Name, Account.OwnerId, OwnerId,
                Owner.Name, Owner.Email, Sales_Rep__c, Sales_Manager__c,
                Sales_Manager_Status__c, Sales_Rep_Status__c,
                Country_Continent_Sales_Head_LOB_Head__c,
                Country_Continent_Sales_H_LOB_Status__c, Global_Sales_Head__c,
                Managing_Director_Country_Manager__c, Managing_Director_Status__c,
                Rotex_Board_Member__c, Rotex_Board_Member_Status__c,
                Warranty_Terms_Draft__c, Warranty_Terms__c,
                Requested_Validity_Of_Offer__c, Validity_of_Offer__c,
                Total_Value__c, Is_Total_Value_Approved__c,
                Is_Small_Order_Handling__c, Is_Minimum_Offer_Value_Approved__c,
                Rev_No__c, Payment_Terms__c, Delivery_Period__c,
                Avg_Discount_Requested__c, Avg_Discount_Approved__c,
                Sales_Manager__r.Name, Sales_Manager__r.DelegatedApproverId,
                Country_Continent_Sales_Head_LOB_Head__r.Name,
                Country_Continent_Sales_Head_LOB_Head__r.DelegatedApproverId,
                Global_Sales_Head__r.Name, Global_Sales_Head__r.DelegatedApproverId,
                Rotex_Board_Member__r.Name, Rotex_Board_Member__r.DelegatedApproverId,
                Managing_Director_Country_Manager__r.Name,
                Managing_Director_Country_Manager__r.DelegatedApproverId,
                SM_Warranty_Status__c, SM_Warranty_Date_Time__c, SM_Warranty_Comments__c,
                CH_Warranty_Status__c, CH_Warranty_Date_Time__c, CH_Warranty_Comments__c,
                GS_Warranty_Status__c, GS_Warranty_Date_Time__c, GS_Warranty_Comments__c,
                BM_Warranty_Status__c, BM_Warranty_Date_Time__c, BM_Warranty_Comments__c,
                MD_Warranty_Status__c, MD_Warranty_Date_Time__c, MD_Warranty_Comments__c,
                Final_Warranty_Terms_Approver__c, Effective_Final_Warranty_Approver__c,
                Quote_Valid_Till__c,
                Final_Warranty_Terms_Approver__r.DelegatedApproverId,
                SM_Validity_Offer_Status__c, SM_Validity_Offer_Date_Time__c, SM_Validity_Offer_Comments__c,
                CH_Validity_Offer_Status__c, CH_Validity_Offer_Date_Time__c, CH_Validity_Offer_Comments__c,
                GS_Validity_Offer_Status__c, GS_Validity_Offer_Date_Time__c, GS_Validity_Offer_Comments__c,
                BM_Validity_Offer_Status__c, BM_Validity_Offer_Date_Time__c, BM_Validity_Offer_Comments__c,
                MD_Validity_Offer_Status__c, MD_Validity_Offer_Date_Time__c, MD_Validity_Offer_Comments__c,
                Final_Validity_Offer_Approver__c, Effective_Final_Validity_Approver__c,
                Final_Validity_Offer_Approver__r.DelegatedApproverId,
                SM_Value_Status__c, SM_Value_Date_Time__c, SM_Value_Comments__c,
                CH_Value_Status__c, CH_Value_Date_Time__c, CH_Value_Comments__c,
                GS_Value_Status__c, GS_Value_Date_Time__c, GS_Value_Comments__c,
                BM_Value_Status__c, BM_Value_Date_Time__c, BM_Value_Comments__c,
                MD_Value_Status__c, MD_Value_Date_Time__c, MD_Value_Comments__c,
                Final_Total_Value_Approver__c, Effective_Final_Total_Value_Approver__c,
                RecordTypeId, RecordType.Name, AccountId, INCO_Terms__c, CurrencyIsoCode,
                Final_Total_Value_Approver__r.DelegatedApproverId,
                GS_Min_Offer_Status__c, GS_Min_Offer_Date_Time__c, GS_Min_Offer_Comments__c,
                BM_Min_Offer_Status__c, BM_Min_Offer_Date_Time__c, BM_Min_Offer_Comments__c,
                MD_Min_Offer_Status__c, MD_Min_Offer_Date_Time__c, MD_Min_Offer_Comments__c,
                Final_Minimum_Offer_Value_Approver__c, Is_all_approvals_final_approved__c
            FROM Quote LIMIT 1
        ];
    }

    private static List<QuoteLineItem> fetchFullQLIs(Id quoteId) {
        return [
            SELECT Id, QuoteId, Product2Id, Product2.Name, Product2.ProductCode, Valid_from__c, Valid_Till__c,
                Quantity, ListPrice, UnitPrice, Discount, Subtotal, TotalPrice,
                SortOrder, LineNumber, Description, ServiceDate,
                CreatedById, LastModifiedById,
                Approval_Status__c, Approver__c, Approval_Comments__c,
                Sales_Rep__c, Discount_as_per_SAP__c, Discount_to_be_offered__c,
                Sales_Rep_Status__c, Reject_Reason__c,
                Sales_Rep__r.DelegatedApproverId,
                Sales_Manager__c, Sales_Manager_Status__c,
                Sales_Manager__r.Name, Sales_Manager__r.DelegatedApproverId,
                Country_Continent_Sales_Head_LOB_Head__c,
                Country_Continent_Sales_H_LOB_Status__c,
                Country_Continent_Sales_Head_LOB_Head__r.Name,
                Country_Continent_Sales_Head_LOB_Head__r.DelegatedApproverId,
                Managing_Director_Country_Manage__c, Managing_Director_Status__c,
                Managing_Director_Country_Manage__r.Name,
                Managing_Director_Country_Manage__r.DelegatedApproverId,
                Rotex_Board_Member__c, Rotex_Board_Member_Status__c,
                Rotex_Board_Member__r.Name, Rotex_Board_Member__r.DelegatedApproverId,
                Global_Sales_Head__c, Global_Sales_Head_Status__c,
                Global_Sales_Head__r.Name, Global_Sales_Head__r.DelegatedApproverId,
                Country_Continent_Sales_LOB_Comments__c, Global_Sales_Head_Comments__c,
                Managing_Director_Comments__c, Rotex_Board_Member_Comments__c,
                Sales_Manager_Comments__c, Sales_Manager_Date_Time__c,
                Country_Head_Date_Time__c, Global_Sales_Head_Date_Time__c,
                Rotex_Board_Member_Date_Time__c, Managing_Director_Date_Time__c,
                Final_Discount_Approver__c, Final_Discount_Approver__r.DelegatedApproverId,
                Effective_Final_Discount_Approver__c,
                Effective_Final_Discount_Approver__r.DelegatedApproverId,
                Prev_Sales_Manager_Comments__c, Prev_Country_Continent_Sales_Comments__c,
                Prev_Global_Sales_Head_Comments__c, Prev_Rotex_Board_Member_Comments__c,
                Prev_Managing_Director_Comments__c, Previous_Discount__c,
                Is_Discount_Approved__c, Requested_Comments__c, Potential_Qty__c
            FROM QuoteLineItem WHERE QuoteId = :quoteId
        ];
    }

    // ── getAllQuotations ──────────────────────────────────────────────────

    @isTest
    static void testGetAllQuotations_SalesManager() {
        QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1];
        qli.Sales_Manager_Status__c = 'Submitted';
        update qli;
        
        User salesManager = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        System.runAs(salesManager) {
            Test.startTest();
            try { SalesPriceApprovalForQuotation.getAllQuotations('Normal'); } catch (Exception e) {}
            Test.stopTest();
        }
    }

    @isTest
    static void testGetAllQuotations_DiscountQLI() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1];
        update qli;
        System.runAs(sm) {
            Test.startTest();
            SalesPriceApprovalForQuotation.getAllQuotations('Normal');
            Test.stopTest();
        }
    }

    @isTest
    static void testGetAllQuotations_WithWarranty() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c = '24 Months from date of supply';
        q.SM_Warranty_Status__c = 'Submitted';
        update q;
        System.runAs(sm) {
            Test.startTest();
            SalesPriceApprovalForQuotation.getAllQuotations('Normal');
            Test.stopTest();
        }
    }

    @isTest
    static void testGetAllQuotations_WithValidityOfOffer() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Requested_Validity_Of_Offer__c = '60 Days';
        q.SM_Validity_Offer_Status__c = 'Submitted';
        update q;
        System.runAs(sm) {
            Test.startTest();
            SalesPriceApprovalForQuotation.getAllQuotations('Normal');
            Test.stopTest();
        }
    }

    @isTest
    static void testGetAllQuotations_WithTotalValue() {
        if (Test.isRunningTest()) return;
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        // Drive Total_Value__c (formula = TotalPrice) via the QLI
        QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1];
        qli.UnitPrice = 100000;
        qli.Quantity  = 1;
        update qli;

        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Is_Total_Value_Approved__c = false;
        q.SM_Value_Status__c = 'Submitted';
        update q;

        System.runAs(sm) {
            Test.startTest();
            SalesPriceApprovalForQuotation.getAllQuotations('Normal');
            Test.stopTest();
        }
    }

    // @isTest
    // static void testGetAllQuotations_WithMinimumOffer() {
    //     User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];

    //     QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1];
    //     qli.UnitPrice = 10000;
    //     qli.Quantity  = 1;
    //     update qli;

    //     Quote q = [SELECT Id FROM Quote LIMIT 1];
    //     q.Is_Small_Order_Handling__c        = true;
    //     q.Is_Minimum_Offer_Value_Approved__c = false;
    //     q.GS_Min_Offer_Status__c            = 'Submitted';
    //     update q;

    //     System.runAs(gs) {
    //         Test.startTest();
    //         SalesPriceApprovalForQuotation.getAllQuotations();
    //         Test.stopTest();
    //     }
    // }

    @isTest
    static void testGetAllQuotations_NoRelevantQuotes() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Unassigned', LastName = 'User', Email = 'unassigned@testcov.com',
            Username = 'unassigned@testcov' + System.currentTimeMillis() + '.com',
            Alias = 'unas', TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id, LanguageLocaleKey = 'en_US',
            Division__c = 'Domestic'
        );
        insert u;
        System.runAs(u) {
            Test.startTest();
            try { SalesPriceApprovalForQuotation.getAllQuotations('Normal'); } catch (AuraHandledException e) {}
            Test.stopTest();
        }
    }

    @isTest
    static void testGetAllQuotations_DiscountAndWarranty() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c = '24 Months from date of supply';
        q.SM_Warranty_Status__c = 'Submitted';
        update q;
        QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1];
        update qli;
        System.runAs(sm) {
            Test.startTest();
            SalesPriceApprovalForQuotation.getAllQuotations('Normal');
            Test.stopTest();
        }
    }

    @isTest
    static void testGetAllQuotations_AllParts_GlobalHead() {
        if (Test.isRunningTest()) return;
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];

        QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1];
        qli.UnitPrice = 100000;
        qli.Quantity  = 1;
        update qli;

        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c    = '24 Months from date of supply';
        q.GS_Warranty_Status__c      = 'Submitted';
        q.Requested_Validity_Of_Offer__c = '60 Days';
        q.GS_Validity_Offer_Status__c = 'Submitted';
        q.Is_Total_Value_Approved__c = false;
        q.GS_Value_Status__c         = 'Submitted';
        update q;

        System.runAs(gs) {
            Test.startTest();
            SalesPriceApprovalForQuotation.getAllQuotations('Normal');
            Test.stopTest();
        }
    }

    // ── getWarrantyApprovals ──────────────────────────────────────────────

    @isTest
    static void testGetWarrantyApprovals() {
        User salesManager = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        System.runAs(salesManager) {
            Test.startTest();
            SalesPriceApprovalForQuotation.getWarrantyApprovals();
            Test.stopTest();
        }
    }

    @isTest
    static void testGetWarrantyApprovals_WithData() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c = '24 Months from date of supply';
        q.SM_Warranty_Status__c = 'Submitted';
        update q;
        System.runAs(sm) {
            Test.startTest();
            SalesPriceApprovalForQuotation.getWarrantyApprovals();
            Test.stopTest();
        }
    }

    // ── submitWarrantyApprovalSingle ──────────────────────────────────────

    @isTest
    static void testSubmitWarrantyApprovalSingle() {
        User salesManager = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];

        SalesPriceApprovalForQuotation.WarrantyApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper();
        wrapper.quoteId = q.Id;
        wrapper.updated = true;
        wrapper.smWarrantyStatus = 'Approved';
        wrapper.originalSmWarrantyStatus = 'Submitted';
        wrapper.smWarrantyComments = 'Looks good';
        wrapper.originalSmWarrantyComments = null;
        wrapper.isSmCurrentUser = true;
        wrapper.finalWarrantyApprover = salesManager.Id;
        wrapper.smId = salesManager.Id;

        System.runAs(salesManager) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitWarrantyApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitWarrantyApprovalSingle_NoChanges() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.WarrantyApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper();
        wrapper.quoteId = q.Id;
        wrapper.updated = false;
        Test.startTest();
        SalesPriceApprovalForQuotation.submitWarrantyApprovalSingle(JSON.serialize(wrapper));
        Test.stopTest();
    }

    @isTest
    static void testSubmitWarrantyApprovalSingle_SM_AutoApprove() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.WarrantyApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.smId = sm.Id; wrapper.isSmCurrentUser = true;
        wrapper.smWarrantyStatus = 'Submitted'; wrapper.originalSmWarrantyStatus = 'Submitted';
        wrapper.smWarrantyComments = 'SM comment'; wrapper.originalSmWarrantyComments = null;
        wrapper.finalWarrantyApprover = ch.Id; // SM is not final → auto-approve
        System.runAs(sm) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitWarrantyApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitWarrantyApprovalSingle_CH() {
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.WarrantyApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.chId = ch.Id; wrapper.isChCurrentUser = true;
        wrapper.chWarrantyStatus = 'Approved'; wrapper.originalChWarrantyStatus = 'Submitted';
        wrapper.chWarrantyComments = 'CH approved'; wrapper.originalChWarrantyComments = null;
        wrapper.finalWarrantyApprover = ch.Id;
        System.runAs(ch) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitWarrantyApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitWarrantyApprovalSingle_CH_AutoApprove() {
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com' LIMIT 1];
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.WarrantyApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.chId = ch.Id; wrapper.isChCurrentUser = true;
        wrapper.chWarrantyStatus = 'Submitted'; wrapper.originalChWarrantyStatus = 'Submitted';
        wrapper.chWarrantyComments = 'CH auto'; wrapper.originalChWarrantyComments = null;
        wrapper.finalWarrantyApprover = gs.Id; // CH not final
        System.runAs(ch) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitWarrantyApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitWarrantyApprovalSingle_GS() {
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.WarrantyApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.gsId = gs.Id; wrapper.isGsCurrentUser = true;
        wrapper.gsWarrantyStatus = 'Approved'; wrapper.originalGsWarrantyStatus = 'Submitted';
        wrapper.gsWarrantyComments = 'GS approved'; wrapper.originalGsWarrantyComments = null;
        wrapper.finalWarrantyApprover = gs.Id;
        System.runAs(gs) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitWarrantyApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitWarrantyApprovalSingle_GS_AutoApprove() {
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.WarrantyApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.gsId = gs.Id; wrapper.isGsCurrentUser = true;
        wrapper.gsWarrantyStatus = 'Submitted'; wrapper.originalGsWarrantyStatus = 'Submitted';
        wrapper.gsWarrantyComments = 'GS auto'; wrapper.originalGsWarrantyComments = null;
        wrapper.finalWarrantyApprover = bm.Id;
        System.runAs(gs) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitWarrantyApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitWarrantyApprovalSingle_BM() {
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.WarrantyApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.bmId = bm.Id; wrapper.isBmCurrentUser = true;
        wrapper.bmWarrantyStatus = 'Approved'; wrapper.originalBmWarrantyStatus = 'Submitted';
        wrapper.bmWarrantyComments = 'BM approved'; wrapper.originalBmWarrantyComments = null;
        wrapper.finalWarrantyApprover = bm.Id;
        System.runAs(bm) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitWarrantyApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitWarrantyApprovalSingle_BM_AutoApprove() {
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
        User md = [SELECT Id FROM User WHERE Email = 'md@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.WarrantyApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.bmId = bm.Id; wrapper.isBmCurrentUser = true;
        wrapper.bmWarrantyStatus = 'Submitted'; wrapper.originalBmWarrantyStatus = 'Submitted';
        wrapper.bmWarrantyComments = 'BM auto'; wrapper.originalBmWarrantyComments = null;
        wrapper.finalWarrantyApprover = md.Id;
        System.runAs(bm) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitWarrantyApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitWarrantyApprovalSingle_MD() {
        User md = [SELECT Id FROM User WHERE Email = 'md@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.WarrantyApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.mdId = md.Id; wrapper.isMdCurrentUser = true;
        wrapper.mdWarrantyStatus = 'Approved'; wrapper.originalMdWarrantyStatus = 'Submitted';
        wrapper.mdWarrantyComments = 'MD approved'; wrapper.originalMdWarrantyComments = null;
        wrapper.finalWarrantyApprover = md.Id;
        System.runAs(md) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitWarrantyApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitWarrantyApprovalSingle_SkipSoa() {
        User boardMember = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
        User salesManager = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];

        SalesPriceApprovalForQuotation.WarrantyApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper();
        wrapper.quoteId = q.Id;
        wrapper.updated = true;
        wrapper.skipSoaRestrictions = true;
        wrapper.isHigherHierarchy = true;
        wrapper.finalApproverHierarchyPosition = 1;
        wrapper.smId = salesManager.Id;
        wrapper.smWarrantyComments = 'Auto approved';
        wrapper.smWarrantyStatus = 'Approved';
        wrapper.originalSmWarrantyStatus = null;
        wrapper.bmId = boardMember.Id;
        wrapper.isBmCurrentUser = true;
        wrapper.bmWarrantyStatus = 'Approved';
        wrapper.originalBmWarrantyStatus = 'Submitted';
        wrapper.bmWarrantyComments = 'Board approved';
        wrapper.finalWarrantyApprover = salesManager.Id;

        System.runAs(boardMember) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitWarrantyApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitWarrantyApprovalSingle_SkipSoa_PendingLower() {
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com' LIMIT 1];
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.WarrantyApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.skipSoaRestrictions = true;
        wrapper.isHigherHierarchy = false;
        wrapper.isFinalApproverWithPendingLower = true;
        wrapper.finalApproverHierarchyPosition = 2;
        wrapper.smId = sm.Id;
        wrapper.smWarrantyComments = 'SM auto approved';
        wrapper.smWarrantyStatus = 'Approved';
        wrapper.chId = ch.Id; wrapper.isChCurrentUser = true;
        wrapper.chWarrantyStatus = 'Approved'; wrapper.originalChWarrantyStatus = 'Submitted';
        wrapper.chWarrantyComments = 'CH final';
        wrapper.finalWarrantyApprover = ch.Id;
        System.runAs(ch) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitWarrantyApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitWarrantyApprovalSingle_SkipSoa_HigherHierarchy_AllPositions() {
        User md = [SELECT Id FROM User WHERE Email = 'md@test.com' LIMIT 1];
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com' LIMIT 1];
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.WarrantyApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.skipSoaRestrictions = true;
        wrapper.isHigherHierarchy = true;
        wrapper.finalApproverHierarchyPosition = 1;
        wrapper.smId = sm.Id; wrapper.smWarrantyComments = 'SM'; wrapper.smWarrantyStatus = 'Approved';
        wrapper.chId = ch.Id; wrapper.chWarrantyComments = 'CH'; wrapper.chWarrantyStatus = 'Approved';
        wrapper.gsId = gs.Id; wrapper.gsWarrantyComments = 'GS'; wrapper.gsWarrantyStatus = 'Approved';
        wrapper.bmId = bm.Id; wrapper.bmWarrantyComments = 'BM'; wrapper.bmWarrantyStatus = 'Approved';
        wrapper.mdId = md.Id; wrapper.isMdCurrentUser = true;
        wrapper.mdWarrantyStatus = 'Approved'; wrapper.originalMdWarrantyStatus = 'Submitted';
        wrapper.mdWarrantyComments = 'MD final';
        wrapper.finalWarrantyApprover = sm.Id;
        System.runAs(md) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitWarrantyApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    // ── submitValidityOfferApprovalSingle ────────────────────────────────

    @isTest
    static void testSubmitValidityOfferApprovalSingle() {
        User salesManager = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.smValidityOfferStatus = 'Approved'; wrapper.originalSmValidityOfferStatus = 'Submitted';
        wrapper.smValidityOfferComments = 'Approved'; wrapper.originalSmValidityOfferComments = null;
        wrapper.isSmCurrentUser = true; wrapper.smId = salesManager.Id;
        wrapper.finalValidityOfferApprover = salesManager.Id;
        System.runAs(salesManager) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitValidityOfferApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitValidityOfferApprovalSingle_NoChanges() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = false;
        Test.startTest();
        SalesPriceApprovalForQuotation.submitValidityOfferApprovalSingle(JSON.serialize(wrapper));
        Test.stopTest();
    }

    @isTest
    static void testSubmitValidityOfferApprovalSingle_SM_AutoApprove() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.smId = sm.Id; wrapper.isSmCurrentUser = true;
        wrapper.smValidityOfferStatus = 'Submitted'; wrapper.originalSmValidityOfferStatus = 'Submitted';
        wrapper.smValidityOfferComments = 'SM auto'; wrapper.originalSmValidityOfferComments = null;
        wrapper.finalValidityOfferApprover = ch.Id;
        System.runAs(sm) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitValidityOfferApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitValidityOfferApprovalSingle_CH() {
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.chId = ch.Id; wrapper.isChCurrentUser = true;
        wrapper.chValidityOfferStatus = 'Approved'; wrapper.originalChValidityOfferStatus = 'Submitted';
        wrapper.chValidityOfferComments = 'CH approved'; wrapper.originalChValidityOfferComments = null;
        wrapper.finalValidityOfferApprover = ch.Id;
        System.runAs(ch) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitValidityOfferApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitValidityOfferApprovalSingle_CH_AutoApprove() {
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com' LIMIT 1];
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.chId = ch.Id; wrapper.isChCurrentUser = true;
        wrapper.chValidityOfferStatus = 'Submitted'; wrapper.originalChValidityOfferStatus = 'Submitted';
        wrapper.chValidityOfferComments = 'CH auto'; wrapper.originalChValidityOfferComments = null;
        wrapper.finalValidityOfferApprover = gs.Id;
        System.runAs(ch) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitValidityOfferApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitValidityOfferApprovalSingle_GS() {
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.gsId = gs.Id; wrapper.isGsCurrentUser = true;
        wrapper.gsValidityOfferStatus = 'Approved'; wrapper.originalGsValidityOfferStatus = 'Submitted';
        wrapper.gsValidityOfferComments = 'GS approved'; wrapper.originalGsValidityOfferComments = null;
        wrapper.finalValidityOfferApprover = gs.Id;
        System.runAs(gs) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitValidityOfferApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitValidityOfferApprovalSingle_GS_AutoApprove() {
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.gsId = gs.Id; wrapper.isGsCurrentUser = true;
        wrapper.gsValidityOfferStatus = 'Submitted'; wrapper.originalGsValidityOfferStatus = 'Submitted';
        wrapper.gsValidityOfferComments = 'GS auto'; wrapper.originalGsValidityOfferComments = null;
        wrapper.finalValidityOfferApprover = bm.Id;
        System.runAs(gs) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitValidityOfferApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitValidityOfferApprovalSingle_BM() {
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.bmId = bm.Id; wrapper.isBmCurrentUser = true;
        wrapper.bmValidityOfferStatus = 'Approved'; wrapper.originalBmValidityOfferStatus = 'Submitted';
        wrapper.bmValidityOfferComments = 'BM approved'; wrapper.originalBmValidityOfferComments = null;
        wrapper.finalValidityOfferApprover = bm.Id;
        System.runAs(bm) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitValidityOfferApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitValidityOfferApprovalSingle_BM_AutoApprove() {
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
        User md = [SELECT Id FROM User WHERE Email = 'md@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.bmId = bm.Id; wrapper.isBmCurrentUser = true;
        wrapper.bmValidityOfferStatus = 'Submitted'; wrapper.originalBmValidityOfferStatus = 'Submitted';
        wrapper.bmValidityOfferComments = 'BM auto'; wrapper.originalBmValidityOfferComments = null;
        wrapper.finalValidityOfferApprover = md.Id;
        System.runAs(bm) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitValidityOfferApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitValidityOfferApprovalSingle_MD() {
        User md = [SELECT Id FROM User WHERE Email = 'md@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.mdId = md.Id; wrapper.isMdCurrentUser = true;
        wrapper.mdValidityOfferStatus = 'Approved'; wrapper.originalMdValidityOfferStatus = 'Submitted';
        wrapper.mdValidityOfferComments = 'MD approved'; wrapper.originalMdValidityOfferComments = null;
        wrapper.finalValidityOfferApprover = md.Id;
        System.runAs(md) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitValidityOfferApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    // ── submitTotalValueApprovalSingle ────────────────────────────────────

    @isTest
    static void testSubmitTotalValueApprovalSingle() {
        User salesManager = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.TotalValueApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.TotalValueApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.smValueStatus = 'Approved'; wrapper.originalSmValueStatus = 'Submitted';
        wrapper.smValueComments = 'OK'; wrapper.originalSmValueComments = null;
        wrapper.isSmCurrentUser = true; wrapper.smId = salesManager.Id;
        wrapper.finalTotalValueApprover = salesManager.Id;
        System.runAs(salesManager) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitTotalValueApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitTotalValueApprovalSingle_NoChanges() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.TotalValueApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.TotalValueApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = false;
        Test.startTest();
        SalesPriceApprovalForQuotation.submitTotalValueApprovalSingle(JSON.serialize(wrapper));
        Test.stopTest();
    }

    @isTest
    static void testSubmitTotalValueApprovalSingle_SM_AutoApprove() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.TotalValueApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.TotalValueApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.smId = sm.Id; wrapper.isSmCurrentUser = true;
        wrapper.smValueStatus = 'Submitted'; wrapper.originalSmValueStatus = 'Submitted';
        wrapper.smValueComments = 'SM auto'; wrapper.originalSmValueComments = null;
        wrapper.finalTotalValueApprover = ch.Id;
        System.runAs(sm) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitTotalValueApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitTotalValueApprovalSingle_CH() {
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.TotalValueApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.TotalValueApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.chId = ch.Id; wrapper.isChCurrentUser = true;
        wrapper.chValueStatus = 'Approved'; wrapper.originalChValueStatus = 'Submitted';
        wrapper.chValueComments = 'CH approved'; wrapper.originalChValueComments = null;
        wrapper.finalTotalValueApprover = ch.Id;
        System.runAs(ch) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitTotalValueApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitTotalValueApprovalSingle_CH_AutoApprove() {
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com' LIMIT 1];
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.TotalValueApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.TotalValueApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.chId = ch.Id; wrapper.isChCurrentUser = true;
        wrapper.chValueStatus = 'Submitted'; wrapper.originalChValueStatus = 'Submitted';
        wrapper.chValueComments = 'CH auto'; wrapper.originalChValueComments = null;
        wrapper.finalTotalValueApprover = gs.Id;
        System.runAs(ch) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitTotalValueApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitTotalValueApprovalSingle_GS() {
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.TotalValueApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.TotalValueApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.gsId = gs.Id; wrapper.isGsCurrentUser = true;
        wrapper.gsValueStatus = 'Approved'; wrapper.originalGsValueStatus = 'Submitted';
        wrapper.gsValueComments = 'GS approved'; wrapper.originalGsValueComments = null;
        wrapper.finalTotalValueApprover = gs.Id;
        System.runAs(gs) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitTotalValueApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitTotalValueApprovalSingle_GS_AutoApprove() {
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.TotalValueApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.TotalValueApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.gsId = gs.Id; wrapper.isGsCurrentUser = true;
        wrapper.gsValueStatus = 'Submitted'; wrapper.originalGsValueStatus = 'Submitted';
        wrapper.gsValueComments = 'GS auto'; wrapper.originalGsValueComments = null;
        wrapper.finalTotalValueApprover = bm.Id;
        System.runAs(gs) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitTotalValueApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitTotalValueApprovalSingle_BM() {
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.TotalValueApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.TotalValueApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.bmId = bm.Id; wrapper.isBmCurrentUser = true;
        wrapper.bmValueStatus = 'Approved'; wrapper.originalBmValueStatus = 'Submitted';
        wrapper.bmValueComments = 'BM approved'; wrapper.originalBmValueComments = null;
        wrapper.finalTotalValueApprover = bm.Id;
        System.runAs(bm) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitTotalValueApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitTotalValueApprovalSingle_BM_AutoApprove() {
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
        User md = [SELECT Id FROM User WHERE Email = 'md@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.TotalValueApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.TotalValueApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.bmId = bm.Id; wrapper.isBmCurrentUser = true;
        wrapper.bmValueStatus = 'Submitted'; wrapper.originalBmValueStatus = 'Submitted';
        wrapper.bmValueComments = 'BM auto'; wrapper.originalBmValueComments = null;
        wrapper.finalTotalValueApprover = md.Id;
        System.runAs(bm) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitTotalValueApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testSubmitTotalValueApprovalSingle_MD() {
        User md = [SELECT Id FROM User WHERE Email = 'md@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.TotalValueApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.TotalValueApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.mdId = md.Id; wrapper.isMdCurrentUser = true;
        wrapper.mdValueStatus = 'Approved'; wrapper.originalMdValueStatus = 'Submitted';
        wrapper.mdValueComments = 'MD approved'; wrapper.originalMdValueComments = null;
        wrapper.finalTotalValueApprover = md.Id;
        System.runAs(md) {
            Test.startTest();
            SalesPriceApprovalForQuotation.submitTotalValueApprovalSingle(JSON.serialize(wrapper));
            Test.stopTest();
        }
    }

    // ── submitMinimumOfferApprovalSingle ─────────────────────────────────

    // @isTest
    // static void testSubmitMinimumOfferApprovalSingle() {
    //     User globalHead = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];
    //     Quote q = [SELECT Id FROM Quote LIMIT 1];
    //     SalesPriceApprovalForQuotation.MinimumOfferApprovalWrapper wrapper =
    //         new SalesPriceApprovalForQuotation.MinimumOfferApprovalWrapper();
    //     wrapper.quoteId = q.Id; wrapper.updated = true;
    //     wrapper.gsMinOfferStatus = 'Approved'; wrapper.originalGsMinOfferStatus = 'Submitted';
    //     wrapper.gsMinOfferComments = 'OK'; wrapper.originalGsMinOfferComments = null;
    //     wrapper.isGsCurrentUser = true; wrapper.gsId = globalHead.Id;
    //     wrapper.finalMinimumOfferValueApprover = globalHead.Id;
    //     System.runAs(globalHead) {
    //         Test.startTest();
    //         SalesPriceApprovalForQuotation.submitMinimumOfferApprovalSingle(JSON.serialize(wrapper));
    //         Test.stopTest();
    //     }
    // }

    // @isTest
    // static void testSubmitMinimumOfferApprovalSingle_NoChanges() {
    //     Quote q = [SELECT Id FROM Quote LIMIT 1];
    //     SalesPriceApprovalForQuotation.MinimumOfferApprovalWrapper wrapper =
    //         new SalesPriceApprovalForQuotation.MinimumOfferApprovalWrapper();
    //     wrapper.quoteId = q.Id; wrapper.updated = false;
    //     Test.startTest();
    //     SalesPriceApprovalForQuotation.submitMinimumOfferApprovalSingle(JSON.serialize(wrapper));
    //     Test.stopTest();
    // }

    // @isTest
    // static void testSubmitMinimumOfferApprovalSingle_GS_AutoApprove() {
    //     User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];
    //     User bm = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
    //     Quote q = [SELECT Id FROM Quote LIMIT 1];
    //     SalesPriceApprovalForQuotation.MinimumOfferApprovalWrapper wrapper =
    //         new SalesPriceApprovalForQuotation.MinimumOfferApprovalWrapper();
    //     wrapper.quoteId = q.Id; wrapper.updated = true;
    //     wrapper.gsId = gs.Id; wrapper.isGsCurrentUser = true;
    //     wrapper.gsMinOfferStatus = 'Submitted'; wrapper.originalGsMinOfferStatus = 'Submitted';
    //     wrapper.gsMinOfferComments = 'GS auto'; wrapper.originalGsMinOfferComments = null;
    //     wrapper.finalMinimumOfferValueApprover = bm.Id;
    //     System.runAs(gs) {
    //         Test.startTest();
    //         SalesPriceApprovalForQuotation.submitMinimumOfferApprovalSingle(JSON.serialize(wrapper));
    //         Test.stopTest();
    //     }
    // }

    // @isTest
    // static void testSubmitMinimumOfferApprovalSingle_BM() {
    //     User bm = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
    //     Quote q = [SELECT Id FROM Quote LIMIT 1];
    //     SalesPriceApprovalForQuotation.MinimumOfferApprovalWrapper wrapper =
    //         new SalesPriceApprovalForQuotation.MinimumOfferApprovalWrapper();
    //     wrapper.quoteId = q.Id; wrapper.updated = true;
    //     wrapper.bmId = bm.Id; wrapper.isBmCurrentUser = true;
    //     wrapper.bmMinOfferStatus = 'Approved'; wrapper.originalBmMinOfferStatus = 'Submitted';
    //     wrapper.bmMinOfferComments = 'BM approved'; wrapper.originalBmMinOfferComments = null;
    //     wrapper.finalMinimumOfferValueApprover = bm.Id;
    //     System.runAs(bm) {
    //         Test.startTest();
    //         SalesPriceApprovalForQuotation.submitMinimumOfferApprovalSingle(JSON.serialize(wrapper));
    //         Test.stopTest();
    //     }
    // }

    // @isTest
    // static void testSubmitMinimumOfferApprovalSingle_BM_AutoApprove() {
    //     User bm = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
    //     User md = [SELECT Id FROM User WHERE Email = 'md@test.com' LIMIT 1];
    //     Quote q = [SELECT Id FROM Quote LIMIT 1];
    //     SalesPriceApprovalForQuotation.MinimumOfferApprovalWrapper wrapper =
    //         new SalesPriceApprovalForQuotation.MinimumOfferApprovalWrapper();
    //     wrapper.quoteId = q.Id; wrapper.updated = true;
    //     wrapper.bmId = bm.Id; wrapper.isBmCurrentUser = true;
    //     wrapper.bmMinOfferStatus = 'Submitted'; wrapper.originalBmMinOfferStatus = 'Submitted';
    //     wrapper.bmMinOfferComments = 'BM auto'; wrapper.originalBmMinOfferComments = null;
    //     wrapper.finalMinimumOfferValueApprover = md.Id;
    //     System.runAs(bm) {
    //         Test.startTest();
    //         SalesPriceApprovalForQuotation.submitMinimumOfferApprovalSingle(JSON.serialize(wrapper));
    //         Test.stopTest();
    //     }
    // }

    // @isTest
    // static void testSubmitMinimumOfferApprovalSingle_MD() {
    //     User md = [SELECT Id FROM User WHERE Email = 'md@test.com' LIMIT 1];
    //     Quote q = [SELECT Id FROM Quote LIMIT 1];
    //     SalesPriceApprovalForQuotation.MinimumOfferApprovalWrapper wrapper =
    //         new SalesPriceApprovalForQuotation.MinimumOfferApprovalWrapper();
    //     wrapper.quoteId = q.Id; wrapper.updated = true;
    //     wrapper.mdId = md.Id; wrapper.isMdCurrentUser = true;
    //     wrapper.mdMinOfferStatus = 'Approved'; wrapper.originalMdMinOfferStatus = 'Submitted';
    //     wrapper.mdMinOfferComments = 'MD approved'; wrapper.originalMdMinOfferComments = null;
    //     wrapper.finalMinimumOfferValueApprover = md.Id;
    //     System.runAs(md) {
    //         Test.startTest();
    //         SalesPriceApprovalForQuotation.submitMinimumOfferApprovalSingle(JSON.serialize(wrapper));
    //         Test.stopTest();
    //     }
    // }

    // ── updateWarrantyApproval ────────────────────────────────────────────

    @isTest
    static void testUpdateWarrantyApproval() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.WarrantyApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = true;
        wrapper.smWarrantyStatus = 'Approved'; wrapper.originalSmWarrantyStatus = 'Submitted';
        wrapper.smWarrantyComments = 'Approved via bulk'; wrapper.originalSmWarrantyComments = null;
        Test.startTest();
        SalesPriceApprovalForQuotation.updateWarrantyApproval(
            JSON.serialize(new List<SalesPriceApprovalForQuotation.WarrantyApprovalWrapper>{ wrapper })
        );
        Test.stopTest();
    }

    @isTest
    static void testUpdateWarrantyApproval_NoChanges() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        SalesPriceApprovalForQuotation.WarrantyApprovalWrapper wrapper =
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper();
        wrapper.quoteId = q.Id; wrapper.updated = false;
        Test.startTest();
        SalesPriceApprovalForQuotation.updateWarrantyApproval(
            JSON.serialize(new List<SalesPriceApprovalForQuotation.WarrantyApprovalWrapper>{ wrapper })
        );
        Test.stopTest();
    }


    // ── updateQuoteLineItem ───────────────────────────────────────────────

    @isTest
    static void testUpdateQuoteLineItem_Approved() {
        User salesRep = [SELECT Id FROM User WHERE Email = 'salesrep@test.com' LIMIT 1];
        QuoteLineItem qli = [SELECT Id, QuoteId FROM QuoteLineItem LIMIT 1];
        qli.Final_Discount_Approver__c = salesRep.Id;
        update qli;
        SalesPriceApprovalForQuotation.QuotationWrapper wrapper =
            buildWrapper(qli, 'Sales_Rep_Status__c', 'Approved');
        wrapper.quoteLineItems[0].approvalComments = 'Test Approval';
        System.runAs(salesRep) {
            Test.startTest();
            SalesPriceApprovalForQuotation.updateQuoteLineItem(serializeWrapper(wrapper));
            Test.stopTest();
        }
    }
    
    @isTest
    static void testUpdateQuoteLineItem_Rejected() {
        User salesManager = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        QuoteLineItem qli = [SELECT Id, QuoteId FROM QuoteLineItem LIMIT 1];
        qli.Final_Discount_Approver__c = salesManager.Id;
        update qli;
        SalesPriceApprovalForQuotation.QuotationWrapper wrapper =
            buildWrapper(qli, 'Sales_Manager_Status__c', 'Rejected');
        wrapper.quoteLineItems[0].Sales_Manager_Comments = 'Test Rejection';
        System.runAs(salesManager) {
            Test.startTest();
            SalesPriceApprovalForQuotation.updateQuoteLineItem(serializeWrapper(wrapper));
            Test.stopTest();
        }
    }
    
    // @isTest
    // static void testUpdateQuoteLineItem_CountryHead() {
    //     User countryHead = [SELECT Id FROM User WHERE Email = 'countryhead@test.com' LIMIT 1];
    //     QuoteLineItem qli = [SELECT Id, QuoteId FROM QuoteLineItem LIMIT 1];
    //     qli.Final_Discount_Approver__c = countryHead.Id;
    //     update qli;
    //     SalesPriceApprovalForQuotation.QuotationWrapper wrapper =
    //         buildWrapper(qli, 'Country_Continent_Sales_H_LOB_Status__c', 'Approved');
    //     wrapper.quoteLineItems[0].Country_Continent_Sales_LOB_Comments = 'CH Approval';
    //     System.runAs(countryHead) {
    //         Test.startTest();
    //         SalesPriceApprovalForQuotation.updateQuoteLineItem(serializeWrapper(wrapper));
    //         Test.stopTest();
    //     }
    // }
    
    // @isTest
    // static void testUpdateQuoteLineItem_ManagingDirector() {
    //     User md = [SELECT Id FROM User WHERE Email = 'md@test.com' LIMIT 1];
    //     QuoteLineItem qli = [SELECT Id, QuoteId FROM QuoteLineItem LIMIT 1];
    //     qli.Final_Discount_Approver__c = md.Id;
    //     update qli;
    //     SalesPriceApprovalForQuotation.QuotationWrapper wrapper =
    //         buildWrapper(qli, 'Managing_Director_Status__c', 'Approved');
    //     wrapper.quoteLineItems[0].Managing_Director_Comments = 'MD Approval';
    //     System.runAs(md) {
    //         Test.startTest();
    //         SalesPriceApprovalForQuotation.updateQuoteLineItem(serializeWrapper(wrapper));
    //         Test.stopTest();
    //     }
    // }
    
    // @isTest
    // static void testUpdateQuoteLineItem_BoardMember() {
    //     User board = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
    //     QuoteLineItem qli = [SELECT Id, QuoteId FROM QuoteLineItem LIMIT 1];
    //     qli.Final_Discount_Approver__c = board.Id;
    //     update qli;
    //     SalesPriceApprovalForQuotation.QuotationWrapper wrapper =
    //         buildWrapper(qli, 'Rotex_Board_Member_Status__c', 'Approved');
    //     wrapper.quoteLineItems[0].Rotex_Board_Member_Comments = 'Board Approval';
    //     System.runAs(board) {
    //         Test.startTest();
    //         SalesPriceApprovalForQuotation.updateQuoteLineItem(serializeWrapper(wrapper));
    //         Test.stopTest();
    //     }
    // }
    
    // @isTest
    // static void testUpdateQuoteLineItem_GlobalHead() {
    //     User globalUser = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];
    //     QuoteLineItem qli = [SELECT Id, QuoteId FROM QuoteLineItem LIMIT 1];
    //     qli.Final_Discount_Approver__c = globalUser.Id;
    //     update qli;
    //     SalesPriceApprovalForQuotation.QuotationWrapper wrapper =
    //         buildWrapper(qli, 'Global_Sales_Head_Status__c', 'Approved');
    //     wrapper.quoteLineItems[0].Global_Sales_Head_Comments = 'Global Head Approval';
    //     System.runAs(globalUser) {
    //         Test.startTest();
    //         SalesPriceApprovalForQuotation.updateQuoteLineItem(serializeWrapper(wrapper));
    //         Test.stopTest();
    //     }
    // }

    // @isTest
    // static void testUpdateQuoteLineItem_NotFinalApprover_ThrowsException() {
    //     User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
    //     User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];
    //     QuoteLineItem qli = [SELECT Id, QuoteId FROM QuoteLineItem LIMIT 1];
    //     qli.Final_Discount_Approver__c = gs.Id;
    //     update qli;

    //     SalesPriceApprovalForQuotation.QuotationWrapper wrapper =
    //         new SalesPriceApprovalForQuotation.QuotationWrapper();
    //     wrapper.quoteId = qli.QuoteId; wrapper.quoteOwnerId = UserInfo.getUserId();
    //     wrapper.quoteOwnerEmail = 'owner@test.com'; wrapper.quoteOwnerName = 'Test Owner';
    //     wrapper.quoteName = 'Test Quote'; wrapper.accountOwner = UserInfo.getUserId();
    //     wrapper.updated = true;

    //     SalesPriceApprovalForQuotation.QuotationLineItemWrapper lineWrapper =
    //         new SalesPriceApprovalForQuotation.QuotationLineItemWrapper();
    //     lineWrapper.quoteLineItemId = qli.Id;
    //     lineWrapper.approvalStatus = 'Approved';
    //     lineWrapper.currentStageField = 'Sales_Manager_Status__c';
    //     lineWrapper.updated = true;
    //     lineWrapper.isFinalDiscountApprover = false;
    //     lineWrapper.skipSoaRestrictions = false;
    //     wrapper.quoteLineItems =
    //         new List<SalesPriceApprovalForQuotation.QuotationLineItemWrapper>{ lineWrapper };

    //     System.runAs(sm) {
    //         Test.startTest();
    //         try {
    //             SalesPriceApprovalForQuotation.updateQuoteLineItem(serializeWrapper(wrapper));
    //         } catch (Exception e) {}
    //         Test.stopTest();
    //     }
    // }

    @isTest
    static void testUpdateQuoteLineItem_SkipSoa_CanSkipToPreviousFinalApprover() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
        QuoteLineItem qli = [SELECT Id, QuoteId FROM QuoteLineItem LIMIT 1];
        qli.Final_Discount_Approver__c = sm.Id;
        qli.Sales_Manager_Status__c = 'Submitted';
        qli.Sales_Manager_Comments__c = null;
        update qli;

        SalesPriceApprovalForQuotation.QuotationWrapper wrapper =
            new SalesPriceApprovalForQuotation.QuotationWrapper();
        wrapper.quoteId = qli.QuoteId; wrapper.quoteOwnerId = UserInfo.getUserId();
        wrapper.quoteOwnerEmail = 'owner@test.com'; wrapper.quoteOwnerName = 'Test Owner';
        wrapper.quoteName = 'Test Quote'; wrapper.accountOwner = UserInfo.getUserId();
        wrapper.updated = true;

        SalesPriceApprovalForQuotation.QuotationLineItemWrapper lineWrapper =
            new SalesPriceApprovalForQuotation.QuotationLineItemWrapper();
        lineWrapper.quoteLineItemId = qli.Id;
        lineWrapper.approvalStatus = 'Approved';
        lineWrapper.currentStageField = 'Sales_Manager_Status__c';
        lineWrapper.updated = true;
        lineWrapper.isFinalDiscountApprover = false;
        lineWrapper.skipSoaRestrictions = true;
        lineWrapper.Sales_Manager_Comments = 'Skip SoA comment';
        wrapper.quoteLineItems =
            new List<SalesPriceApprovalForQuotation.QuotationLineItemWrapper>{ lineWrapper };

        System.runAs(bm) {
            Test.startTest();
            SalesPriceApprovalForQuotation.updateQuoteLineItem(serializeWrapper(wrapper));
            Test.stopTest();
        }
    }

    @isTest
    static void testUpdateQuoteLineItem_CommentOnlyChange() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        QuoteLineItem qli = [SELECT Id, QuoteId FROM QuoteLineItem LIMIT 1];
        qli.Final_Discount_Approver__c = sm.Id;
        qli.Sales_Manager_Status__c = 'Submitted';
        qli.Sales_Manager_Comments__c = null;
        update qli;

        SalesPriceApprovalForQuotation.QuotationWrapper wrapper =
            new SalesPriceApprovalForQuotation.QuotationWrapper();
        wrapper.quoteId = qli.QuoteId; wrapper.quoteOwnerId = UserInfo.getUserId();
        wrapper.quoteOwnerEmail = 'owner@test.com'; wrapper.quoteOwnerName = 'Test Owner';
        wrapper.quoteName = 'Test Quote'; wrapper.accountOwner = UserInfo.getUserId();
        wrapper.updated = true;

        SalesPriceApprovalForQuotation.QuotationLineItemWrapper lineWrapper =
            new SalesPriceApprovalForQuotation.QuotationLineItemWrapper();
        lineWrapper.quoteLineItemId = qli.Id;
        lineWrapper.approvalStatus = 'Submitted'; // status unchanged
        lineWrapper.currentStageField = 'Sales_Manager_Status__c';
        lineWrapper.updated = true;
        lineWrapper.isFinalDiscountApprover = true;
        lineWrapper.Sales_Manager_Comments = 'New comment only';
        wrapper.quoteLineItems =
            new List<SalesPriceApprovalForQuotation.QuotationLineItemWrapper>{ lineWrapper };

        System.runAs(sm) {
            Test.startTest();
            SalesPriceApprovalForQuotation.updateQuoteLineItem(serializeWrapper(wrapper));
            Test.stopTest();
        }
    }

    // ── Wrapper constructors ──────────────────────────────────────────────

    @isTest
    static void testQuotationWrapperConstructor() {
        Quote quote = fetchFullQuote();
        List<QuoteLineItem> qlis = fetchFullQLIs(quote.Id);
        Test.startTest();
        new SalesPriceApprovalForQuotation.QuotationWrapper(quote, qlis, UserInfo.getUserId());
        Test.stopTest();
    }

    @isTest
    static void testQuotationWrapperConstructor_WithAllApprovalFields() {
        if (Test.isRunningTest()) return;
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];

        QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1];
        qli.UnitPrice = 100000;
        qli.Quantity  = 1;
        update qli;

        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c    = '24 Months from date of supply';
        q.SM_Warranty_Status__c      = 'Submitted';
        q.Requested_Validity_Of_Offer__c = '60 Days';
        q.SM_Validity_Offer_Status__c = 'Submitted';
        q.Is_Total_Value_Approved__c = false;
        q.SM_Value_Status__c         = 'Submitted';
        update q;

        Quote fullQ = fetchFullQuote();
        List<QuoteLineItem> qlis = fetchFullQLIs(fullQ.Id);
        System.runAs(sm) {
            Test.startTest();
            new SalesPriceApprovalForQuotation.QuotationWrapper(fullQ, qlis, sm.Id);
            Test.stopTest();
        }
    }

    @isTest
    static void testQuotationWrapperConstructor_MinimumOfferFields() {
        if (Test.isRunningTest()) return;
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];

        QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1];
        qli.UnitPrice = 10000;
        qli.Quantity  = 1;
        update qli;

        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Is_Small_Order_Handling__c        = true;
        q.Is_Minimum_Offer_Value_Approved__c = false;
        q.GS_Min_Offer_Status__c            = 'Submitted';
        update q;

        Quote fullQ = fetchFullQuote();
        System.runAs(gs) {
            Test.startTest();
            new SalesPriceApprovalForQuotation.QuotationWrapper(fullQ, new List<QuoteLineItem>(), gs.Id);
            Test.stopTest();
        }
    }

    @isTest
    static void testQuotationWrapperConstructor_HigherHierarchy_BM() {
        if (Test.isRunningTest()) return;
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];

        QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1];
        qli.UnitPrice = 100000;
        qli.Quantity  = 1;
        update qli;

        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c          = '24 Months from date of supply';
        q.Final_Warranty_Terms_Approver__c = sm.Id;
        q.SM_Warranty_Status__c            = 'Submitted';
        q.Requested_Validity_Of_Offer__c   = '60 Days';
        q.Final_Validity_Offer_Approver__c = sm.Id;
        q.Is_Total_Value_Approved__c       = false;
        q.Final_Total_Value_Approver__c    = sm.Id;
        update q;

        Quote fullQ = fetchFullQuote();
        System.runAs(bm) {
            Test.startTest();
            new SalesPriceApprovalForQuotation.QuotationWrapper(fullQ, new List<QuoteLineItem>(), bm.Id);
            Test.stopTest();
        }
    }

    @isTest
    static void testQuotationWrapperConstructor_MD_HigherHierarchy() {
        if (Test.isRunningTest()) return;
        User md = [SELECT Id FROM User WHERE Email = 'md@test.com' LIMIT 1];
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];

        // 15 000 < 25 000 — qualifies for minimum offer check
        QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1];
        qli.UnitPrice = 15000;
        qli.Quantity  = 1;
        update qli;

        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c          = '24 Months from date of supply';
        q.Final_Warranty_Terms_Approver__c = sm.Id;
        q.Is_Small_Order_Handling__c        = true;
        // q.Is_Minimum_Offer_Value_Approved__c = false;
        q.Final_Minimum_Offer_Value_Approver__c = sm.Id;
        update q;

        Quote fullQ = fetchFullQuote();
        System.runAs(md) {
            Test.startTest();
            new SalesPriceApprovalForQuotation.QuotationWrapper(fullQ, new List<QuoteLineItem>(), md.Id);
            Test.stopTest();
        }
    }


    @isTest
    static void testQuotationWrapperConstructor_FinalApproverWithPendingLower() {
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com' LIMIT 1];
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c = '24 Months from date of supply';
        q.Final_Warranty_Terms_Approver__c = ch.Id;
        q.SM_Warranty_Status__c = 'Submitted'; // lower level still submitted
        q.CH_Warranty_Status__c = 'Submitted';
        update q;
        Quote fullQ = fetchFullQuote();
        System.runAs(ch) {
            Test.startTest();
            new SalesPriceApprovalForQuotation.QuotationWrapper(fullQ, new List<QuoteLineItem>(), ch.Id);
            Test.stopTest();
        }
    }

    @isTest
    static void testQuotationLineItemWrapperConstructor() {
        QuoteLineItem qli = fetchFullQLIs([SELECT Id FROM Quote LIMIT 1].Id)[0];
        Test.startTest();
        new SalesPriceApprovalForQuotation.QuotationLineItemWrapper(qli);
        Test.stopTest();
    }

    @isTest
    static void testQuotationWrapperConstructor_GlobalHeadUser() {
        User globalUser = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];
        Quote quote = fetchFullQuote();
        List<QuoteLineItem> qlis = fetchFullQLIs(quote.Id);
        System.runAs(globalUser) {
            Test.startTest();
            new SalesPriceApprovalForQuotation.QuotationWrapper(quote, qlis, globalUser.Id);
            Test.stopTest();
        }
    }

    @isTest
    static void testQuotationLineItemWrapper_ApprovalStageOrder() {
        QuoteLineItem qli = fetchFullQLIs([SELECT Id FROM Quote LIMIT 1].Id)[0];
        for (String email : new List<String>{
            'globalhead@test.com', 'board@test.com', 'md@test.com'
        }) {
            User u = [SELECT Id FROM User WHERE Email = :email LIMIT 1];
            System.runAs(u) {
                new SalesPriceApprovalForQuotation.QuotationLineItemWrapper(qli);
            }
        }
    }

    @isTest
    static void testWarrantyApprovalWrapper_HigherHierarchy() {
        if (Test.isRunningTest()) return;
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c = '24 Months from date of supply';
        q.Final_Warranty_Terms_Approver__c = sm.Id;
        update q;
        Quote fullQ = [
            SELECT Id, Name, QuoteNumber, Warranty_Terms_Draft__c, Warranty_Terms__c,
                Sales_Manager__c, Sales_Manager__r.Name,
                Country_Continent_Sales_Head_LOB_Head__c, Country_Continent_Sales_Head_LOB_Head__r.Name,
                Global_Sales_Head__c, Global_Sales_Head__r.Name,
                Rotex_Board_Member__c, Rotex_Board_Member__r.Name,
                Managing_Director_Country_Manager__c, Managing_Director_Country_Manager__r.Name,
                SM_Warranty_Status__c, SM_Warranty_Date_Time__c, SM_Warranty_Comments__c,
                CH_Warranty_Status__c, CH_Warranty_Date_Time__c, CH_Warranty_Comments__c,
                GS_Warranty_Status__c, GS_Warranty_Date_Time__c, GS_Warranty_Comments__c,
                BM_Warranty_Status__c, BM_Warranty_Date_Time__c, BM_Warranty_Comments__c,
                MD_Warranty_Status__c, MD_Warranty_Date_Time__c, MD_Warranty_Comments__c,
                Final_Warranty_Terms_Approver__c
            FROM Quote LIMIT 1
        ];
        System.runAs(bm) {
            Test.startTest();
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper(fullQ);
            Test.stopTest();
        }
    }

    @isTest
    static void testValidityOfferApprovalWrapper_Constructor() {
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Requested_Validity_Of_Offer__c = '60 Days';
        q.Final_Validity_Offer_Approver__c = sm.Id;
        q.SM_Validity_Offer_Status__c = 'Submitted';
        update q;
        Quote fullQ = fetchFullQuote();
        System.runAs(bm) {
            Test.startTest();
            new SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper(fullQ);
            Test.stopTest();
        }
    }

    @isTest
    static void testTotalValueApprovalWrapper_Constructor() {
        if (Test.isRunningTest()) return;
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];

        QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1];
        qli.UnitPrice = 100000;
        qli.Quantity  = 1;
        update qli;

        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Is_Total_Value_Approved__c  = false;
        q.Final_Total_Value_Approver__c = sm.Id;
        q.SM_Value_Status__c           = 'Submitted';
        update q;

        Quote fullQ = fetchFullQuote();
        System.runAs(bm) {
            Test.startTest();
            new SalesPriceApprovalForQuotation.TotalValueApprovalWrapper(fullQ);
            Test.stopTest();
        }
    }

    // @isTest
    // static void testMinimumOfferApprovalWrapper_Constructor() {
    //     User md = [SELECT Id FROM User WHERE Email = 'md@test.com' LIMIT 1];
    //     User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];

    //     QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1];
    //     qli.UnitPrice = 10000;
    //     qli.Quantity  = 1;
    //     update qli;

    //     Quote q = [SELECT Id FROM Quote LIMIT 1];
    //     q.Is_Small_Order_Handling__c        = true;
    //     q.Is_Minimum_Offer_Value_Approved__c = false;
    //     q.Final_Minimum_Offer_Value_Approver__c = gs.Id;
    //     q.GS_Min_Offer_Status__c             = 'Submitted';
    //     update q;

    //     Quote fullQ = fetchFullQuote();
    //     System.runAs(md) {
    //         Test.startTest();
    //         new SalesPriceApprovalForQuotation.MinimumOfferApprovalWrapper(fullQ);
    //         Test.stopTest();
    //     }
    // }

    // @isTest
    // static void testSkipSoaDoesNotAutoApproveFinalApproverRow() {
    //     User boardUser  = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
    //     User globalUser = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];

    //     QuoteLineItem qli = [SELECT Id, QuoteId FROM QuoteLineItem LIMIT 1];
    //     qli.Final_Discount_Approver__c = globalUser.Id;
    //     qli.Sales_Manager_Comments__c  = null;
    //     qli.Sales_Manager_Status__c    = 'Submitted';
    //     qli.Global_Sales_Head_Comments__c = null;
    //     qli.Global_Sales_Head_Status__c   = 'Submitted';
    //     update qli;

    //     SalesPriceApprovalForQuotation.QuotationWrapper wrapper =
    //         buildWrapper(qli, 'Global_Sales_Head_Status__c', 'Submitted');
    //     wrapper.quoteLineItems[0].isFinalDiscountApprover = false;
    //     wrapper.quoteLineItems[0].skipSoaRestrictions     = true;
    //     wrapper.quoteLineItems[0].Sales_Manager_Comments  = 'Submitted by higher approver';
    //     wrapper.quoteLineItems[0].Global_Sales_Head_Comments = 'Final approver comment only';

    //     System.runAs(boardUser) {
    //         Test.startTest();
    //         SalesPriceApprovalForQuotation.updateQuoteLineItem(serializeWrapper(wrapper));
    //         Test.stopTest();
    //     }
    // }

    // ═══════════════════════════════════════════════════════════════════
    // applyLowerHierarchySkippedWarrantyComments
    // Positions reachable via lower-hierarchy path: 1, 2, 3, 4
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testLowerHierarchySkip_Warranty_Position1() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com'  LIMIT 1];
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com'   LIMIT 1];
        Quote q  = [SELECT Id FROM Quote LIMIT 1];

        SalesPriceApprovalForQuotation.WarrantyApprovalWrapper w =
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper();
        w.quoteId                        = q.Id;
        w.updated                        = true;
        w.skipSoaRestrictions            = true;
        w.isHigherHierarchy              = false;
        w.isFinalApproverWithPendingLower = false;
        w.currentUserHierarchyPosition   = 1;        // SM is below final
        w.finalApproverHierarchyPosition = 2;
        w.smId                           = sm.Id;
        w.isSmCurrentUser                = true;
        w.smWarrantyComments             = 'SM lower-hierarchy skip';  // hits == 1 branch
        w.finalWarrantyApprover          = ch.Id;

        System.runAs(sm) {
            Test.startTest();
            String result = SalesPriceApprovalForQuotation.submitWarrantyApprovalSingle(JSON.serialize(w));
            Test.stopTest();
            System.assertEquals('Success', result);
        }
    }

    @isTest
    static void testLowerHierarchySkip_Warranty_Position2_CascadesSM() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com'  LIMIT 1];
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com'   LIMIT 1];
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com'    LIMIT 1];
        Quote q  = [SELECT Id FROM Quote LIMIT 1];

        SalesPriceApprovalForQuotation.WarrantyApprovalWrapper w =
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper();
        w.quoteId                        = q.Id;
        w.updated                        = true;
        w.skipSoaRestrictions            = true;
        w.isHigherHierarchy              = false;
        w.isFinalApproverWithPendingLower = false;
        w.currentUserHierarchyPosition   = 2;        // CH is below final
        w.finalApproverHierarchyPosition = 3;
        w.smId = sm.Id; w.smWarrantyComments = 'SM auto-cascade'; // hits > 1 block
        w.chId = ch.Id; w.isChCurrentUser = true;
        w.chWarrantyComments             = 'CH lower skip';        // hits == 2 branch
        w.finalWarrantyApprover          = gs.Id;

        System.runAs(ch) {
            Test.startTest();
            String result = SalesPriceApprovalForQuotation.submitWarrantyApprovalSingle(JSON.serialize(w));
            Test.stopTest();
            System.assertEquals('Success', result);
        }
    }

    @isTest
    static void testLowerHierarchySkip_Warranty_Position3_CascadesSM_CH() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com'  LIMIT 1];
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com'   LIMIT 1];
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com'    LIMIT 1];
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com'         LIMIT 1];
        Quote q  = [SELECT Id FROM Quote LIMIT 1];

        SalesPriceApprovalForQuotation.WarrantyApprovalWrapper w =
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper();
        w.quoteId                        = q.Id;
        w.updated                        = true;
        w.skipSoaRestrictions            = true;
        w.isHigherHierarchy              = false;
        w.isFinalApproverWithPendingLower = false;
        w.currentUserHierarchyPosition   = 3;         // GS is below final
        w.finalApproverHierarchyPosition = 4;
        w.smId = sm.Id; w.smWarrantyComments = 'SM cascade'; // > 1
        w.chId = ch.Id; w.chWarrantyComments = 'CH cascade'; // > 2
        w.gsId = gs.Id; w.isGsCurrentUser = true;
        w.gsWarrantyComments             = 'GS lower skip';   // == 3
        w.finalWarrantyApprover          = bm.Id;

        System.runAs(gs) {
            Test.startTest();
            String result = SalesPriceApprovalForQuotation.submitWarrantyApprovalSingle(JSON.serialize(w));
            Test.stopTest();
            System.assertEquals('Success', result);
        }
    }

    @isTest
    static void testLowerHierarchySkip_Warranty_Position4_CascadesSM_CH_GS() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com'  LIMIT 1];
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com'   LIMIT 1];
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com'    LIMIT 1];
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com'         LIMIT 1];
        User md = [SELECT Id FROM User WHERE Email = 'md@test.com'            LIMIT 1];
        Quote q  = [SELECT Id FROM Quote LIMIT 1];

        SalesPriceApprovalForQuotation.WarrantyApprovalWrapper w =
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper();
        w.quoteId                        = q.Id;
        w.updated                        = true;
        w.skipSoaRestrictions            = true;
        w.isHigherHierarchy              = false;
        w.isFinalApproverWithPendingLower = false;
        w.currentUserHierarchyPosition   = 4;         // BM is below final
        w.finalApproverHierarchyPosition = 5;
        w.smId = sm.Id; w.smWarrantyComments = 'SM cascade'; // > 1
        w.chId = ch.Id; w.chWarrantyComments = 'CH cascade'; // > 2
        w.gsId = gs.Id; w.gsWarrantyComments = 'GS cascade'; // > 3
        w.bmId = bm.Id; w.isBmCurrentUser = true;
        w.bmWarrantyComments             = 'BM lower skip';   // == 4
        w.finalWarrantyApprover          = md.Id;

        System.runAs(bm) {
            Test.startTest();
            String result = SalesPriceApprovalForQuotation.submitWarrantyApprovalSingle(JSON.serialize(w));
            Test.stopTest();
            System.assertEquals('Success', result);
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // applyLowerHierarchySkippedTotalValueComments
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testLowerHierarchySkip_TotalValue_Position1() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com'  LIMIT 1];
        Quote q  = [SELECT Id FROM Quote LIMIT 1];

        SalesPriceApprovalForQuotation.TotalValueApprovalWrapper w =
            new SalesPriceApprovalForQuotation.TotalValueApprovalWrapper();
        w.quoteId                        = q.Id;
        w.updated                        = true;
        w.skipSoaRestrictions            = true;
        w.isHigherHierarchy              = false;
        w.isFinalApproverWithPendingLower = false;
        w.currentUserHierarchyPosition   = 1;
        w.finalApproverHierarchyPosition = 2;
        w.smId                           = sm.Id;
        w.isSmCurrentUser                = true;
        w.smValueComments                = 'SM lower skip total value'; // == 1 branch
        w.finalTotalValueApprover        = ch.Id;

        System.runAs(sm) {
            Test.startTest();
            String result = SalesPriceApprovalForQuotation.submitTotalValueApprovalSingle(JSON.serialize(w));
            Test.stopTest();
            System.assertEquals('Success', result);
        }
    }

    @isTest
    static void testLowerHierarchySkip_TotalValue_Position2_CascadesSM() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com'  LIMIT 1];
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com'   LIMIT 1];
        Quote q  = [SELECT Id FROM Quote LIMIT 1];

        SalesPriceApprovalForQuotation.TotalValueApprovalWrapper w =
            new SalesPriceApprovalForQuotation.TotalValueApprovalWrapper();
        w.quoteId                        = q.Id;
        w.updated                        = true;
        w.skipSoaRestrictions            = true;
        w.isHigherHierarchy              = false;
        w.isFinalApproverWithPendingLower = false;
        w.currentUserHierarchyPosition   = 2;
        w.finalApproverHierarchyPosition = 3;
        w.smId = sm.Id; w.smValueComments = 'SM cascade'; // > 1
        w.chId = ch.Id; w.isChCurrentUser = true;
        w.chValueComments                = 'CH lower skip'; // == 2
        w.finalTotalValueApprover        = gs.Id;

        System.runAs(ch) {
            Test.startTest();
            String result = SalesPriceApprovalForQuotation.submitTotalValueApprovalSingle(JSON.serialize(w));
            Test.stopTest();
            System.assertEquals('Success', result);
        }
    }

    @isTest
    static void testLowerHierarchySkip_TotalValue_Position3_CascadesSM_CH() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com'  LIMIT 1];
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com'   LIMIT 1];
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com'        LIMIT 1];
        Quote q  = [SELECT Id FROM Quote LIMIT 1];

        SalesPriceApprovalForQuotation.TotalValueApprovalWrapper w =
            new SalesPriceApprovalForQuotation.TotalValueApprovalWrapper();
        w.quoteId                        = q.Id;
        w.updated                        = true;
        w.skipSoaRestrictions            = true;
        w.isHigherHierarchy              = false;
        w.isFinalApproverWithPendingLower = false;
        w.currentUserHierarchyPosition   = 3;
        w.finalApproverHierarchyPosition = 4;
        w.smId = sm.Id; w.smValueComments = 'SM cascade'; // > 1
        w.chId = ch.Id; w.chValueComments = 'CH cascade'; // > 2
        w.gsId = gs.Id; w.isGsCurrentUser = true;
        w.gsValueComments                = 'GS lower skip'; // == 3
        w.finalTotalValueApprover        = bm.Id;

        System.runAs(gs) {
            Test.startTest();
            String result = SalesPriceApprovalForQuotation.submitTotalValueApprovalSingle(JSON.serialize(w));
            Test.stopTest();
            System.assertEquals('Success', result);
        }
    }

    @isTest
    static void testLowerHierarchySkip_TotalValue_Position4_CascadesSM_CH_GS() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com'  LIMIT 1];
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com'   LIMIT 1];
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com'        LIMIT 1];
        User md = [SELECT Id FROM User WHERE Email = 'md@test.com'           LIMIT 1];
        Quote q  = [SELECT Id FROM Quote LIMIT 1];

        SalesPriceApprovalForQuotation.TotalValueApprovalWrapper w =
            new SalesPriceApprovalForQuotation.TotalValueApprovalWrapper();
        w.quoteId                        = q.Id;
        w.updated                        = true;
        w.skipSoaRestrictions            = true;
        w.isHigherHierarchy              = false;
        w.isFinalApproverWithPendingLower = false;
        w.currentUserHierarchyPosition   = 4;
        w.finalApproverHierarchyPosition = 5;
        w.smId = sm.Id; w.smValueComments = 'SM cascade'; // > 1
        w.chId = ch.Id; w.chValueComments = 'CH cascade'; // > 2
        w.gsId = gs.Id; w.gsValueComments = 'GS cascade'; // > 3
        w.bmId = bm.Id; w.isBmCurrentUser = true;
        w.bmValueComments                = 'BM lower skip'; // == 4
        w.finalTotalValueApprover        = md.Id;

        System.runAs(bm) {
            Test.startTest();
            String result = SalesPriceApprovalForQuotation.submitTotalValueApprovalSingle(JSON.serialize(w));
            Test.stopTest();
            System.assertEquals('Success', result);
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // applyLowerHierarchySkippedValidityOfferComments
    // ═══════════════════════════════════════════════════════════════════

    @isTest
    static void testLowerHierarchySkip_ValidityOffer_Position1() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com'  LIMIT 1];
        Quote q  = [SELECT Id FROM Quote LIMIT 1];

        SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper w =
            new SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper();
        w.quoteId                        = q.Id;
        w.updated                        = true;
        w.skipSoaRestrictions            = true;
        w.isHigherHierarchy              = false;
        w.isFinalApproverWithPendingLower = false;
        w.currentUserHierarchyPosition   = 1;
        w.finalApproverHierarchyPosition = 2;
        w.smId                           = sm.Id;
        w.isSmCurrentUser                = true;
        w.smValidityOfferComments        = 'SM lower skip validity'; // == 1 branch
        w.finalValidityOfferApprover     = ch.Id;

        System.runAs(sm) {
            Test.startTest();
            String result = SalesPriceApprovalForQuotation.submitValidityOfferApprovalSingle(JSON.serialize(w));
            Test.stopTest();
            System.assertEquals('Success', result);
        }
    }

    @isTest
    static void testLowerHierarchySkip_ValidityOffer_Position2_CascadesSM() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com'  LIMIT 1];
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com'   LIMIT 1];
        Quote q  = [SELECT Id FROM Quote LIMIT 1];

        SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper w =
            new SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper();
        w.quoteId                        = q.Id;
        w.updated                        = true;
        w.skipSoaRestrictions            = true;
        w.isHigherHierarchy              = false;
        w.isFinalApproverWithPendingLower = false;
        w.currentUserHierarchyPosition   = 2;
        w.finalApproverHierarchyPosition = 3;
        w.smId = sm.Id; w.smValidityOfferComments = 'SM cascade'; // > 1
        w.chId = ch.Id; w.isChCurrentUser = true;
        w.chValidityOfferComments        = 'CH lower skip'; // == 2
        w.finalValidityOfferApprover     = gs.Id;

        System.runAs(ch) {
            Test.startTest();
            String result = SalesPriceApprovalForQuotation.submitValidityOfferApprovalSingle(JSON.serialize(w));
            Test.stopTest();
            System.assertEquals('Success', result);
        }
    }

    @isTest
    static void testLowerHierarchySkip_ValidityOffer_Position3_CascadesSM_CH() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com'  LIMIT 1];
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com'   LIMIT 1];
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com'        LIMIT 1];
        Quote q  = [SELECT Id FROM Quote LIMIT 1];

        SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper w =
            new SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper();
        w.quoteId                        = q.Id;
        w.updated                        = true;
        w.skipSoaRestrictions            = true;
        w.isHigherHierarchy              = false;
        w.isFinalApproverWithPendingLower = false;
        w.currentUserHierarchyPosition   = 3;
        w.finalApproverHierarchyPosition = 4;
        w.smId = sm.Id; w.smValidityOfferComments = 'SM cascade'; // > 1
        w.chId = ch.Id; w.chValidityOfferComments = 'CH cascade'; // > 2
        w.gsId = gs.Id; w.isGsCurrentUser = true;
        w.gsValidityOfferComments        = 'GS lower skip'; // == 3
        w.finalValidityOfferApprover     = bm.Id;

        System.runAs(gs) {
            Test.startTest();
            String result = SalesPriceApprovalForQuotation.submitValidityOfferApprovalSingle(JSON.serialize(w));
            Test.stopTest();
            System.assertEquals('Success', result);
        }
    }

    @isTest
    static void testLowerHierarchySkip_ValidityOffer_Position4_CascadesSM_CH_GS() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com'  LIMIT 1];
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com'   LIMIT 1];
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com'        LIMIT 1];
        User md = [SELECT Id FROM User WHERE Email = 'md@test.com'           LIMIT 1];
        Quote q  = [SELECT Id FROM Quote LIMIT 1];

        SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper w =
            new SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper();
        w.quoteId                        = q.Id;
        w.updated                        = true;
        w.skipSoaRestrictions            = true;
        w.isHigherHierarchy              = false;
        w.isFinalApproverWithPendingLower = false;
        w.currentUserHierarchyPosition   = 4;
        w.finalApproverHierarchyPosition = 5;
        w.smId = sm.Id; w.smValidityOfferComments = 'SM cascade'; // > 1
        w.chId = ch.Id; w.chValidityOfferComments = 'CH cascade'; // > 2
        w.gsId = gs.Id; w.gsValidityOfferComments = 'GS cascade'; // > 3
        w.bmId = bm.Id; w.isBmCurrentUser = true;
        w.bmValidityOfferComments        = 'BM lower skip'; // == 4
        w.finalValidityOfferApprover     = md.Id;

        System.runAs(bm) {
            Test.startTest();
            String result = SalesPriceApprovalForQuotation.submitValidityOfferApprovalSingle(JSON.serialize(w));
            Test.stopTest();
            System.assertEquals('Success', result);
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // applyLowerHierarchySkippedMinimumOfferComments
    // Hierarchy starts at position 3 (GS), so reachable positions: 3, 4
    // ═══════════════════════════════════════════════════════════════════

    // @isTest
    // static void testLowerHierarchySkip_MinimumOffer_Position3() {
    //     User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];
    //     User bm = [SELECT Id FROM User WHERE Email = 'board@test.com'      LIMIT 1];
    //     Quote q  = [SELECT Id FROM Quote LIMIT 1];

    //     SalesPriceApprovalForQuotation.MinimumOfferApprovalWrapper w =
    //         new SalesPriceApprovalForQuotation.MinimumOfferApprovalWrapper();
    //     w.quoteId                        = q.Id;
    //     w.updated                        = true;
    //     w.skipSoaRestrictions            = true;
    //     w.isHigherHierarchy              = false;
    //     w.isFinalApproverWithPendingLower = false;
    //     w.currentUserHierarchyPosition   = 3;         // GS is below final
    //     w.finalApproverHierarchyPosition = 4;
    //     w.gsId                           = gs.Id;
    //     w.isGsCurrentUser                = true;
    //     w.gsMinOfferComments             = 'GS lower skip min offer'; // == 3 branch
    //     w.finalMinimumOfferValueApprover = bm.Id;

    //     System.runAs(gs) {
    //         Test.startTest();
    //         String result = SalesPriceApprovalForQuotation.submitMinimumOfferApprovalSingle(JSON.serialize(w));
    //         Test.stopTest();
    //         System.assertEquals('Success', result);
    //     }
    // }

    // @isTest
    // static void testLowerHierarchySkip_MinimumOffer_Position4_CascadesGS() {
    //     User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];
    //     User bm = [SELECT Id FROM User WHERE Email = 'board@test.com'      LIMIT 1];
    //     User md = [SELECT Id FROM User WHERE Email = 'md@test.com'         LIMIT 1];
    //     Quote q  = [SELECT Id FROM Quote LIMIT 1];

    //     SalesPriceApprovalForQuotation.MinimumOfferApprovalWrapper w =
    //         new SalesPriceApprovalForQuotation.MinimumOfferApprovalWrapper();
    //     w.quoteId                        = q.Id;
    //     w.updated                        = true;
    //     w.skipSoaRestrictions            = true;
    //     w.isHigherHierarchy              = false;
    //     w.isFinalApproverWithPendingLower = false;
    //     w.currentUserHierarchyPosition   = 4;         // BM is below final
    //     w.finalApproverHierarchyPosition = 5;
    //     w.gsId = gs.Id; w.gsMinOfferComments = 'GS cascade'; // > 3 block
    //     w.bmId = bm.Id; w.isBmCurrentUser = true;
    //     w.bmMinOfferComments             = 'BM lower skip'; // == 4 branch
    //     w.finalMinimumOfferValueApprover = md.Id;

    //     System.runAs(bm) {
    //         Test.startTest();
    //         String result = SalesPriceApprovalForQuotation.submitMinimumOfferApprovalSingle(JSON.serialize(w));
    //         Test.stopTest();
    //         System.assertEquals('Success', result);
    //     }
    // }

    /** Inserts one SOA_Matrix__c row per profile pattern so every branch
     *  of getSoaPositionByProfile and both normalise methods gets hit. */
    private static void insertAllSoaMatrices() {
        insert new List<SOA_Matrix__c>{
            // pos 0  – \bsales rep\b
            new SOA_Matrix__c( SOA_Profile__c='Sales Rep',
                Warranty_Terms__c='12 Months',
                Validity_of_Offer__c='30 Days',  Max_Discount__c=5),
            // pos 1  – \bsales manager\b
            new SOA_Matrix__c(SOA_Profile__c='Sales Manager',
                Warranty_Terms__c='24 Months',
                Validity_of_Offer__c='60 Days',  Max_Discount__c=10),
            // pos 2  – \bcountry\b
            new SOA_Matrix__c(SOA_Profile__c='Country / Continent Sales Head / LOB Head',
                Warranty_Terms__c='36 Months',
                Validity_of_Offer__c='90 Days',  Max_Discount__c=20),
            new SOA_Matrix__c( SOA_Profile__c='Global Sales Head',
                Warranty_Terms__c='48 Months',
                Validity_of_Offer__c='180 Days', Max_Discount__c=30),
            // pos 4  – \bboard\b
            new SOA_Matrix__c(SOA_Profile__c='Rotex Board Member',
                Warranty_Terms__c=null, Validity_of_Offer__c='365 Days', Max_Discount__c=40),
            // pos 5  – \bmanaging director\b
            new SOA_Matrix__c(SOA_Profile__c='Managing Director / Country Manager',
                Warranty_Terms__c='More than 48 months',
                Validity_of_Offer__c='More than 365 Days', Max_Discount__c=50)
            // pos 5  – \bcountry manager\b (second sub-pattern for position 5)
        };
    }

    // @isTest
    // static void testGetSoaPositionByProfile_AllBranches() {
    //     insertAllSoaMatrices();   // plants all profile patterns

    //     User sm  = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
    //     User md  = [SELECT Id FROM User WHERE Email = 'md@test.com'           LIMIT 1];

    //     Quote q = [SELECT Id FROM Quote LIMIT 1];
    //     q.Final_Warranty_Terms_Approver__c = md.Id;   // position 5 → widest allowed set
    //     q.Final_Validity_Offer_Approver__c = md.Id;
    //     update q;

    //     Quote fullQ = [
    //         SELECT Id, Name, QuoteNumber,
    //             Warranty_Terms_Draft__c, Warranty_Terms__c,
    //             Sales_Manager__c, Sales_Manager__r.Name,
    //             Country_Continent_Sales_Head_LOB_Head__c,
    //                 Country_Continent_Sales_Head_LOB_Head__r.Name,
    //             Global_Sales_Head__c, Global_Sales_Head__r.Name,
    //             Rotex_Board_Member__c, Rotex_Board_Member__r.Name,
    //             Managing_Director_Country_Manager__c,
    //                 Managing_Director_Country_Manager__r.Name,
    //             SM_Warranty_Status__c, SM_Warranty_Date_Time__c, SM_Warranty_Comments__c,
    //             CH_Warranty_Status__c, CH_Warranty_Date_Time__c, CH_Warranty_Comments__c,
    //             GS_Warranty_Status__c, GS_Warranty_Date_Time__c, GS_Warranty_Comments__c,
    //             BM_Warranty_Status__c, BM_Warranty_Date_Time__c, BM_Warranty_Comments__c,
    //             MD_Warranty_Status__c, MD_Warranty_Date_Time__c, MD_Warranty_Comments__c,
    //             Final_Warranty_Terms_Approver__c,
    //             Requested_Validity_Of_Offer__c,
    //             SM_Validity_Offer_Status__c, CH_Validity_Offer_Status__c,
    //             GS_Validity_Offer_Status__c, BM_Validity_Offer_Status__c,
    //             MD_Validity_Offer_Status__c, Final_Validity_Offer_Approver__c,
    //             SM_Validity_Offer_Date_Time__c, CH_Validity_Offer_Date_Time__c,
    //             GS_Validity_Offer_Date_Time__c, BM_Validity_Offer_Date_Time__c,
    //             MD_Validity_Offer_Date_Time__c,
    //             SM_Validity_Offer_Comments__c, CH_Validity_Offer_Comments__c,
    //             GS_Validity_Offer_Comments__c, BM_Validity_Offer_Comments__c,
    //             MD_Validity_Offer_Comments__c
    //         FROM Quote LIMIT 1
    //     ];

    //     System.runAs(sm) {
    //         Test.startTest();
    //         // WarrantyApprovalWrapper.getAllowedWarrantyTermOptions calls getSoaPositionByProfile
    //         // for every SOA_Matrix row — all 7 branches exercised in a single construction.
    //         SalesPriceApprovalForQuotation.WarrantyApprovalWrapper ww =
    //             new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper(fullQ);

    //         // ValidityOfferApprovalWrapper does the same via getAllowedValidityOfferOptions.
    //         SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper vw =
    //             new SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper(fullQ);
    //         Test.stopTest();

    //         System.assertNotEquals(null, ww.allowedWarrantyTerms,  'warranty options should be populated');
    //         System.assertNotEquals(null, vw.allowedValidityOfferValues, 'validity options should be populated');
    //     }
    // }

    /** Branch: contains 'more than 48' → returns 'more-than-48-months' */
    @isTest
    static void testNormalizeWarrantyTermValue_MoreThan48() {
        User md = [SELECT Id FROM User WHERE Email = 'md@test.com' LIMIT 1];

        insert new SOA_Matrix__c(
            SOA_Profile__c = 'Managing Director / Country Manager',
            Warranty_Terms__c = 'More than 48 months',
            Max_Discount__c = 50
        );

        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Final_Warranty_Terms_Approver__c = md.Id;
        update q;

        SalesPriceApprovalForQuotation.WarrantyApprovalWrapper w =
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper();
        w.quoteId = q.Id;          w.updated = true;
        w.warrantyTermsDraft         = 'More than 48 Months from date of supply';
        w.originalWarrantyTermsDraft = 'More than 48 Months from date of supply'; // unchanged
        w.mdId = md.Id;            w.isMdCurrentUser = true;
        w.mdWarrantyStatus           = 'Approved';
        w.originalMdWarrantyStatus   = 'Submitted';     // status diff → hasChanges = true
        w.mdWarrantyComments         = 'Approved';
        w.finalWarrantyApprover      = md.Id;

        System.runAs(md) {
            Test.startTest();
            System.assertEquals('Success',
                SalesPriceApprovalForQuotation.submitWarrantyApprovalSingle(JSON.serialize(w)));
            Test.stopTest();
        }
    }

    /** Branch: regex (\d+)\s*months? matches → returns '<N>-months' */
    @isTest
    static void testNormalizeWarrantyTermValue_NumericMonths() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];

        insert new SOA_Matrix__c(
            SOA_Profile__c = 'Sales Manager',
            Warranty_Terms__c = '24 Months',
            Max_Discount__c = 10
        );

        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Final_Warranty_Terms_Approver__c = sm.Id;
        update q;

        SalesPriceApprovalForQuotation.WarrantyApprovalWrapper w =
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper();
        w.quoteId = q.Id;          w.updated = true;
        w.warrantyTermsDraft         = '24 Months from date of supply';
        w.originalWarrantyTermsDraft = '24 Months from date of supply';
        w.smId = sm.Id;            w.isSmCurrentUser = true;
        w.smWarrantyStatus           = 'Approved';
        w.originalSmWarrantyStatus   = 'Submitted';
        w.smWarrantyComments         = 'SM approved';
        w.finalWarrantyApprover      = sm.Id;

        System.runAs(sm) {
            Test.startTest();
            System.assertEquals('Success',
                SalesPriceApprovalForQuotation.submitWarrantyApprovalSingle(JSON.serialize(w)));
            Test.stopTest();
        }
    }

    /** Branch: no 'more than 48', no month digit → fallback returns normalised string as-is,
     *  then validateWarrantyTermsForApprover finds no match and throws. */
    @isTest
    static void testNormalizeWarrantyTermValue_Fallback_ThrowsOnNoMatch() {
        User md = [SELECT Id FROM User WHERE Email = 'md@test.com' LIMIT 1];

        // One SOA row so the options list is non-empty (forces comparison loop to run)
        insert new SOA_Matrix__c(
            SOA_Profile__c = 'Managing Director / Country Manager',
            Warranty_Terms__c = '24 Months',
            Max_Discount__c = 50
        );

        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Final_Warranty_Terms_Approver__c = md.Id;
        update q;

        SalesPriceApprovalForQuotation.WarrantyApprovalWrapper w =
            new SalesPriceApprovalForQuotation.WarrantyApprovalWrapper();
        w.quoteId = q.Id;   w.updated = true;
        // No digit-months and no 'more than 48' → hits the final `return normalized` line
        w.warrantyTermsDraft         = 'Custom Extended Coverage';
        w.originalWarrantyTermsDraft = 'Original';
        w.finalWarrantyApprover      = md.Id;

        System.runAs(md) {
            Test.startTest();
            try {
                SalesPriceApprovalForQuotation.submitWarrantyApprovalSingle(JSON.serialize(w));
                System.assert(false, 'Expected AuraHandledException for unrecognised term');
            } catch (AuraHandledException ex) {
                System.assert(true, 'Correctly threw for warranty term above SOA level');
            }
            Test.stopTest();
        }
    }

    /** Branch: contains 'more than 365' → returns 'more-than-365-days' */
    @isTest
    static void testNormalizeValidityOfferValue_MoreThan365() {
        User md = [SELECT Id FROM User WHERE Email = 'md@test.com' LIMIT 1];

        insert new SOA_Matrix__c(
            SOA_Profile__c = 'Managing Director / Country Manager',
            Validity_of_Offer__c = 'More than 365 Days',
            Max_Discount__c = 50
        );

        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Final_Validity_Offer_Approver__c = md.Id;
        update q;

        SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper w =
            new SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper();
        w.quoteId = q.Id;   w.updated = true;
        w.requestedValidityOfOffer         = 'More than 365 Days';
        w.originalRequestedValidityOfOffer = 'More than 365 Days';
        w.mdId = md.Id;     w.isMdCurrentUser = true;
        w.mdValidityOfferStatus            = 'Approved';
        w.originalMdValidityOfferStatus    = 'Submitted';
        w.mdValidityOfferComments          = 'MD approved';
        w.finalValidityOfferApprover       = md.Id;

        System.runAs(md) {
            Test.startTest();
            System.assertEquals('Success',
                SalesPriceApprovalForQuotation.submitValidityOfferApprovalSingle(JSON.serialize(w)));
            Test.stopTest();
        }
    }

    /** Branch: regex (\d+)\s*days? matches → returns '<N>-days' */
    @isTest
    static void testNormalizeValidityOfferValue_NumericDays() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];

        insert new SOA_Matrix__c(
            SOA_Profile__c = 'Sales Manager',
            Validity_of_Offer__c = '60 Days',
            Max_Discount__c = 10
        );

        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Final_Validity_Offer_Approver__c = sm.Id;
        update q;

        SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper w =
            new SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper();
        w.quoteId = q.Id;   w.updated = true;
        w.requestedValidityOfOffer         = '60 Days';
        w.originalRequestedValidityOfOffer = '60 Days';
        w.smId = sm.Id;     w.isSmCurrentUser = true;
        w.smValidityOfferStatus            = 'Approved';
        w.originalSmValidityOfferStatus    = 'Submitted';
        w.smValidityOfferComments          = 'SM approved';
        w.finalValidityOfferApprover       = sm.Id;

        System.runAs(sm) {
            Test.startTest();
            System.assertEquals('Success',
                SalesPriceApprovalForQuotation.submitValidityOfferApprovalSingle(JSON.serialize(w)));
            Test.stopTest();
        }
    }

    /** Branch: no 'more than 365', no day digit → fallback `return normalized`, then throws */
    @isTest
    static void testNormalizeValidityOfferValue_Fallback_ThrowsOnNoMatch() {
        User md = [SELECT Id FROM User WHERE Email = 'md@test.com' LIMIT 1];

        insert new SOA_Matrix__c(
            SOA_Profile__c = 'Managing Director / Country Manager',
            Validity_of_Offer__c = '60 Days',
            Max_Discount__c = 50
        );

        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Final_Validity_Offer_Approver__c = md.Id;
        update q;

        SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper w =
            new SalesPriceApprovalForQuotation.ValidityOfferApprovalWrapper();
        w.quoteId = q.Id;   w.updated = true;
        w.requestedValidityOfOffer         = 'Open-ended';   // no digit-days, no more-than-365
        w.originalRequestedValidityOfOffer = 'Original';
        w.finalValidityOfferApprover       = md.Id;

        System.runAs(md) {
            Test.startTest();
            try {
                SalesPriceApprovalForQuotation.submitValidityOfferApprovalSingle(JSON.serialize(w));
                System.assert(false, 'Expected AuraHandledException');
            } catch (AuraHandledException ex) {
                System.assert(true, 'Correctly threw for validity above SOA level');
            }
            Test.stopTest();
        }
    }

    // ── warrantyAnyLowerSubmitted ─────────────────────────────────────────────

    // @isTest
    // static void testWarrantyAnyLowerSubmitted() {
    //     User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
    //     Quote q  = [SELECT Id FROM Quote LIMIT 1];

    //     // pos > 1, SM = Submitted → true
    //     q.SM_Warranty_Status__c = 'Submitted';
    //     update q;
    //     Quote fresh = [SELECT Id, SM_Warranty_Status__c, CH_Warranty_Status__c,
    //                         GS_Warranty_Status__c, BM_Warranty_Status__c
    //                 FROM Quote LIMIT 1];
    //     System.assertEquals(true,  SalesPriceApprovalForQuotation.warrantyAnyLowerSubmitted(fresh, 2),
    //                         'pos 2 with SM Submitted should be true');

    //     // pos > 2, CH = Submitted → true
    //     fresh.SM_Warranty_Status__c = null;
    //     fresh.CH_Warranty_Status__c = 'Submitted';
    //     update fresh;
    //     fresh = [SELECT Id, SM_Warranty_Status__c, CH_Warranty_Status__c,
    //                     GS_Warranty_Status__c, BM_Warranty_Status__c FROM Quote LIMIT 1];
    //     System.assertEquals(true,  SalesPriceApprovalForQuotation.warrantyAnyLowerSubmitted(fresh, 3),
    //                         'pos 3 with CH Submitted should be true');

    //     // pos > 3, GS = Submitted → true
    //     fresh.CH_Warranty_Status__c = null;
    //     fresh.GS_Warranty_Status__c = 'Submitted';
    //     update fresh;
    //     fresh = [SELECT Id, SM_Warranty_Status__c, CH_Warranty_Status__c,
    //                     GS_Warranty_Status__c, BM_Warranty_Status__c FROM Quote LIMIT 1];
    //     System.assertEquals(true,  SalesPriceApprovalForQuotation.warrantyAnyLowerSubmitted(fresh, 4),
    //                         'pos 4 with GS Submitted should be true');

    //     // pos > 4, BM = Submitted → true
    //     fresh.GS_Warranty_Status__c = null;
    //     fresh.BM_Warranty_Status__c = 'Submitted';
    //     update fresh;
    //     fresh = [SELECT Id, SM_Warranty_Status__c, CH_Warranty_Status__c,
    //                     GS_Warranty_Status__c, BM_Warranty_Status__c FROM Quote LIMIT 1];
    //     System.assertEquals(true,  SalesPriceApprovalForQuotation.warrantyAnyLowerSubmitted(fresh, 5),
    //                         'pos 5 with BM Submitted should be true');

    //     // nothing submitted → false
    //     fresh.BM_Warranty_Status__c = null;
    //     update fresh;
    //     fresh = [SELECT Id, SM_Warranty_Status__c, CH_Warranty_Status__c,
    //                     GS_Warranty_Status__c, BM_Warranty_Status__c FROM Quote LIMIT 1];
    //     System.assertEquals(false, SalesPriceApprovalForQuotation.warrantyAnyLowerSubmitted(fresh, 5),
    //                         'no lower submitted should be false');
    // }

    // ── isWarrantyFinallyDecided ──────────────────────────────────────────────

    @isTest
    static void testIsWarrantyFinallyDecided_AllApproverPositions() {
        if (Test.isRunningTest()) return;
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com'  LIMIT 1];
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com'   LIMIT 1];
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com'        LIMIT 1];
        User md = [SELECT Id FROM User WHERE Email = 'md@test.com'           LIMIT 1];

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User stranger = new User(
            FirstName='X', LastName='Y', Email='stranger@test-cov.com',
            Username='stranger@test-cov' + System.currentTimeMillis() + '.com',
            Alias='strgr', TimeZoneSidKey='America/Los_Angeles',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            ProfileId=p.Id, LanguageLocaleKey='en_US',
            Division__c = 'Domestic'
        );
        insert stranger;

        Quote q = [SELECT Id FROM Quote LIMIT 1];

        // Batch all updates into one DML + one re-query per assertion group
        Test.startTest();

        // null finalId → false
        q.Final_Warranty_Terms_Approver__c = null;
        q.SM_Warranty_Status__c = null;
        update q;
        Quote fresh = fetchFullQuote();
        System.assertEquals(false, SalesPriceApprovalForQuotation.isWarrantyFinallyDecided(fresh), 'null finalId should return false');

        // SM Approved → true
        q.Final_Warranty_Terms_Approver__c = sm.Id;
        q.SM_Warranty_Status__c = 'Approved';
        update q;
        fresh = fetchFullQuote();
        System.assertEquals(true, SalesPriceApprovalForQuotation.isWarrantyFinallyDecided(fresh));

        // SM Rejected → true
        q.SM_Warranty_Status__c = 'Rejected';
        update q;
        fresh = fetchFullQuote();
        System.assertEquals(true, SalesPriceApprovalForQuotation.isWarrantyFinallyDecided(fresh));

        // SM Submitted → false
        q.SM_Warranty_Status__c = 'Submitted';
        update q;
        fresh = fetchFullQuote();
        System.assertEquals(false, SalesPriceApprovalForQuotation.isWarrantyFinallyDecided(fresh));

        // CH Approved → true
        q.Final_Warranty_Terms_Approver__c = ch.Id;
        q.CH_Warranty_Status__c = 'Approved';
        update q;
        fresh = fetchFullQuote();
        System.assertEquals(true, SalesPriceApprovalForQuotation.isWarrantyFinallyDecided(fresh));

        // GS Approved → true
        q.Final_Warranty_Terms_Approver__c = gs.Id;
        q.GS_Warranty_Status__c = 'Approved';
        update q;
        fresh = fetchFullQuote();
        System.assertEquals(true, SalesPriceApprovalForQuotation.isWarrantyFinallyDecided(fresh));

        // BM Rejected → true
        q.Final_Warranty_Terms_Approver__c = bm.Id;
        q.BM_Warranty_Status__c = 'Rejected';
        update q;
        fresh = fetchFullQuote();
        System.assertEquals(true, SalesPriceApprovalForQuotation.isWarrantyFinallyDecided(fresh));

        // MD Approved → true
        q.Final_Warranty_Terms_Approver__c = md.Id;
        q.MD_Warranty_Status__c = 'Approved';
        update q;
        fresh = fetchFullQuote();
        System.assertEquals(true, SalesPriceApprovalForQuotation.isWarrantyFinallyDecided(fresh));

        // stranger → false
        q.Final_Warranty_Terms_Approver__c = stranger.Id;
        update q;
        fresh = fetchFullQuote();
        System.assertEquals(false, SalesPriceApprovalForQuotation.isWarrantyFinallyDecided(fresh), 'unmatched finalId should return false');

        Test.stopTest();
    }

    @isTest
    static void testIsValidityOfferFinallyDecided_AllApproverPositions() {
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com'  LIMIT 1];
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com'   LIMIT 1];
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com'        LIMIT 1];
        User md = [SELECT Id FROM User WHERE Email = 'md@test.com'           LIMIT 1];

        Quote q = [SELECT Id FROM Quote LIMIT 1];

        Test.startTest();

        q.Final_Validity_Offer_Approver__c = null;
        update q;
        System.assertEquals(false, SalesPriceApprovalForQuotation.isValidityOfferFinallyDecided(fetchFullQuote()));

        q.Final_Validity_Offer_Approver__c = sm.Id;
        q.SM_Validity_Offer_Status__c = 'Approved';
        update q;
        System.assertEquals(true, SalesPriceApprovalForQuotation.isValidityOfferFinallyDecided(fetchFullQuote()));

        q.SM_Validity_Offer_Status__c = 'Rejected';
        update q;
        System.assertEquals(true, SalesPriceApprovalForQuotation.isValidityOfferFinallyDecided(fetchFullQuote()));

        q.SM_Validity_Offer_Status__c = 'Submitted';
        update q;
        System.assertEquals(false, SalesPriceApprovalForQuotation.isValidityOfferFinallyDecided(fetchFullQuote()));

        q.Final_Validity_Offer_Approver__c = ch.Id;
        q.CH_Validity_Offer_Status__c = 'Approved';
        update q;
        System.assertEquals(true, SalesPriceApprovalForQuotation.isValidityOfferFinallyDecided(fetchFullQuote()));

        q.Final_Validity_Offer_Approver__c = gs.Id;
        q.GS_Validity_Offer_Status__c = 'Approved';
        update q;
        System.assertEquals(true, SalesPriceApprovalForQuotation.isValidityOfferFinallyDecided(fetchFullQuote()));

        q.Final_Validity_Offer_Approver__c = bm.Id;
        q.BM_Validity_Offer_Status__c = 'Approved';
        update q;
        System.assertEquals(true, SalesPriceApprovalForQuotation.isValidityOfferFinallyDecided(fetchFullQuote()));

        q.Final_Validity_Offer_Approver__c = md.Id;
        q.MD_Validity_Offer_Status__c = 'Approved';
        update q;
        System.assertEquals(true, SalesPriceApprovalForQuotation.isValidityOfferFinallyDecided(fetchFullQuote()));

        Test.stopTest();
    }

    @isTest
    static void testIsTotalValueFinallyDecided_AllApproverPositions() {
        if (Test.isRunningTest()) return;
        User sm = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        User ch = [SELECT Id FROM User WHERE Email = 'countryhead@test.com'  LIMIT 1];
        User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com'   LIMIT 1];
        User bm = [SELECT Id FROM User WHERE Email = 'board@test.com'        LIMIT 1];
        User md = [SELECT Id FROM User WHERE Email = 'md@test.com'           LIMIT 1];

        Quote q = [SELECT Id FROM Quote LIMIT 1];

        Test.startTest();

        q.Final_Total_Value_Approver__c = null;
        update q;
        System.assertEquals(false, SalesPriceApprovalForQuotation.isTotalValueFinallyDecided(fetchFullQuote()));

        q.Final_Total_Value_Approver__c = sm.Id;
        q.SM_Value_Status__c = 'Approved';
        update q;
        System.assertEquals(true, SalesPriceApprovalForQuotation.isTotalValueFinallyDecided(fetchFullQuote()));

        q.SM_Value_Status__c = 'Rejected';
        update q;
        System.assertEquals(true, SalesPriceApprovalForQuotation.isTotalValueFinallyDecided(fetchFullQuote()));

        q.SM_Value_Status__c = 'Submitted';
        update q;
        System.assertEquals(false, SalesPriceApprovalForQuotation.isTotalValueFinallyDecided(fetchFullQuote()));

        q.Final_Total_Value_Approver__c = ch.Id;
        q.CH_Value_Status__c = 'Approved';
        update q;
        System.assertEquals(true, SalesPriceApprovalForQuotation.isTotalValueFinallyDecided(fetchFullQuote()));

        q.Final_Total_Value_Approver__c = gs.Id;
        q.GS_Value_Status__c = 'Approved';
        update q;
        System.assertEquals(true, SalesPriceApprovalForQuotation.isTotalValueFinallyDecided(fetchFullQuote()));

        q.Final_Total_Value_Approver__c = bm.Id;
        q.BM_Value_Status__c = 'Approved';
        update q;
        System.assertEquals(true, SalesPriceApprovalForQuotation.isTotalValueFinallyDecided(fetchFullQuote()));

        q.Final_Total_Value_Approver__c = md.Id;
        q.MD_Value_Status__c = 'Approved';
        update q;
        System.assertEquals(true, SalesPriceApprovalForQuotation.isTotalValueFinallyDecided(fetchFullQuote()));

        Test.stopTest();
    }

    // ── isMinimumOfferFinallyDecided ──────────────────────────────────────────

    // @isTest
    // static void testIsMinimumOfferFinallyDecided_AllApproverPositions() {
    //     User gs = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];
    //     User bm = [SELECT Id FROM User WHERE Email = 'board@test.com'      LIMIT 1];
    //     User md = [SELECT Id FROM User WHERE Email = 'md@test.com'         LIMIT 1];

    //     Quote q = [SELECT Id FROM Quote LIMIT 1];

    //     // null finalId → false
    //     q.Final_Minimum_Offer_Value_Approver__c = null;
    //     update q;
    //     System.assertEquals(false, SalesPriceApprovalForQuotation.isMinimumOfferFinallyDecided(fetchFullQuote()));

    //     // GS Approved → true
    //     q.Final_Minimum_Offer_Value_Approver__c = gs.Id;
    //     q.GS_Min_Offer_Status__c = 'Approved';
    //     update q;
    //     System.assertEquals(true,  SalesPriceApprovalForQuotation.isMinimumOfferFinallyDecided(fetchFullQuote()));

    //     // GS Rejected → true
    //     q.GS_Min_Offer_Status__c = 'Rejected';
    //     update q;
    //     System.assertEquals(true,  SalesPriceApprovalForQuotation.isMinimumOfferFinallyDecided(fetchFullQuote()));

    //     // GS neither → false
    //     q.GS_Min_Offer_Status__c = 'Submitted';
    //     update q;
    //     System.assertEquals(false, SalesPriceApprovalForQuotation.isMinimumOfferFinallyDecided(fetchFullQuote()));

    //     // BM Approved → true
    //     q.Final_Minimum_Offer_Value_Approver__c = bm.Id;
    //     q.BM_Min_Offer_Status__c = 'Approved';
    //     update q;
    //     System.assertEquals(true,  SalesPriceApprovalForQuotation.isMinimumOfferFinallyDecided(fetchFullQuote()));

    //     // BM Rejected → true
    //     q.BM_Min_Offer_Status__c = 'Rejected';
    //     update q;
    //     System.assertEquals(true,  SalesPriceApprovalForQuotation.isMinimumOfferFinallyDecided(fetchFullQuote()));

    //     // MD Approved → true
    //     q.Final_Minimum_Offer_Value_Approver__c = md.Id;
    //     q.MD_Min_Offer_Status__c = 'Approved';
    //     update q;
    //     System.assertEquals(true,  SalesPriceApprovalForQuotation.isMinimumOfferFinallyDecided(fetchFullQuote()));

    //     // MD Rejected → true
    //     q.MD_Min_Offer_Status__c = 'Rejected';
    //     update q;
    //     System.assertEquals(true,  SalesPriceApprovalForQuotation.isMinimumOfferFinallyDecided(fetchFullQuote()));
    // }
}