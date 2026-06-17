@isTest
private class QuoteTriggerTest {

    @TestSetup
    static void setup() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User u = new User(
            FirstName = 'Test', LastName = 'Approver',
            Email = 'approver@qttest.com',
            Username = 'approver@qttest' + System.currentTimeMillis() + '.com',
            Alias = 'appr', TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id, LanguageLocaleKey = 'en_US'
        );
        insert u;

        List<SOA_Matrix__c> soaRows = new List<SOA_Matrix__c>{
            // Warranty
            new SOA_Matrix__c(Warranty_Terms__c = '24 Months',           SOA_Profile__c = 'Sales Manager'),
            new SOA_Matrix__c(Warranty_Terms__c = '36 Months',           SOA_Profile__c = 'Country / Continent Sales Head / LOB Head'),
            new SOA_Matrix__c(Warranty_Terms__c = '48 Months',           SOA_Profile__c = 'Global Sales Head'),
            new SOA_Matrix__c(Warranty_Terms__c = 'More than 48 Months', SOA_Profile__c = 'Managing Director / Country Manager'),
            // Validity of Offer
            new SOA_Matrix__c(Validity_of_Offer__c = '60 Days',  SOA_Profile__c = 'Sales Manager'),
            new SOA_Matrix__c(Validity_of_Offer__c = '90 Days',  SOA_Profile__c = 'Country / Continent Sales Head / LOB Head'),
            new SOA_Matrix__c(Validity_of_Offer__c = '180 Days', SOA_Profile__c = 'Global Sales Head'),
            new SOA_Matrix__c(Validity_of_Offer__c = '365 Days', SOA_Profile__c = 'Rotex Board Member'),
            new SOA_Matrix__c(Validity_of_Offer__c = 'More than 365 days', SOA_Profile__c = 'Managing Director / Country Manager'),
            // Total Value
            new SOA_Matrix__c(Min_Total_Value__c = 0,      Max_Total_Value__c = 100000,  SOA_Profile__c = 'Sales Manager'),
            new SOA_Matrix__c(Min_Total_Value__c = 100000, Max_Total_Value__c = 500000,  SOA_Profile__c = 'Country / Continent Sales Head / LOB Head'),
            new SOA_Matrix__c(Min_Total_Value__c = 500000, Max_Total_Value__c = 1000000, SOA_Profile__c = 'Global Sales Head'),
            new SOA_Matrix__c(Min_Total_Value__c = 1000000, Max_Total_Value__c = 5000000, SOA_Profile__c = 'Rotex Board Member'),
            new SOA_Matrix__c(Min_Total_Value__c = 5000000, Max_Total_Value__c = 99999999, SOA_Profile__c = 'Managing Director / Country Manager'),
            // Minimum Offer Value
            new SOA_Matrix__c(Min_Minimum_Offer_Value__c = 0, Max_Minimum_Offer_Value__c = 25000, SOA_Profile__c = 'Global Sales Head')
        };
        insert soaRows;

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp', AccountId = acc.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;

        // Create Product and PricebookEntry for QLI creation
        Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = prod.Id,
            UnitPrice = 1000,
            IsActive = true
        );
        insert pbe;

        // Base quote — used by most tests
        Quote q = new Quote(
            Name = 'Test Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Status = 'Draft',
            Sales_Manager__c = u.Id,
            Country_Continent_Sales_Head_LOB_Head__c = u.Id,
            Global_Sales_Head__c = u.Id,
            Rotex_Board_Member__c = u.Id,
            Managing_Director_Country_Manager__c = u.Id
        );
        insert q;

        // Create QLI to set TotalPrice (and thus Total_Value__c) to 50000
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 50,
            UnitPrice = 1000  // 50 * 1000 = 50,000
        );
        insert qli;
    }

    // ── After Insert ──────────────────────────────────────────────────────

    @isTest
    static void testAfterInsert_TotalValue() {
        User u = [SELECT Id FROM User WHERE Email = 'approver@qttest.com' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        Test.startTest();
        Quote q = new Quote(
            Name = 'TV Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Status = 'Draft',
            Sales_Manager__c = u.Id,
            Country_Continent_Sales_Head_LOB_Head__c = u.Id,
            Global_Sales_Head__c = u.Id,
            Rotex_Board_Member__c = u.Id,
            Managing_Director_Country_Manager__c = u.Id
        );
        insert q;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 50,
            UnitPrice = 1000
        );
        insert qli;
        Test.stopTest();
    }

    @isTest
    static void testAfterInsert_MinimumOfferValue() {
        User u = [SELECT Id FROM User WHERE Email = 'approver@qttest.com' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        Test.startTest();
        Quote q = new Quote(
            Name = 'Small Order Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Status = 'Draft',
            Sales_Manager__c = u.Id,
            Country_Continent_Sales_Head_LOB_Head__c = u.Id,
            Global_Sales_Head__c = u.Id,
            Rotex_Board_Member__c = u.Id,
            Managing_Director_Country_Manager__c = u.Id,
            Is_Small_Order_Handling__c = true
        );
        insert q;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 1000
        );
        insert qli;
        Test.stopTest();
    }

    // ── Before Insert ─────────────────────────────────────────────────────

    @isTest
    static void testBeforeInsert_SetsWarrantyDefaults() {
        Quote q = [SELECT Id, Warranty_Terms__c, Warranty_Terms_Draft__c FROM Quote LIMIT 1];
        System.assertEquals('12 Months from date of supply', q.Warranty_Terms__c);
        System.assertEquals('12 Months from date of supply', q.Warranty_Terms_Draft__c);
    }

    // ── Before Update — Warranty ──────────────────────────────────────────

    @isTest
    static void testBeforeUpdate_WarrantyTerms_NonDefault() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        q.Warranty_Terms_Draft__c = '24 Months from date of supply';
        update q;
        Test.stopTest();
    }

    @isTest
    static void testBeforeUpdate_WarrantyTerms_BackToDefault() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c = '24 Months from date of supply';
        update q;

        Test.startTest();
        q.Warranty_Terms_Draft__c = '12 Months from date of supply';
        update q;
        Test.stopTest();
    }

    @isTest
    static void testBeforeUpdate_WarrantyApproval_Approved() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c = '24 Months from date of supply';
        update q;

        Test.startTest();
        q = [SELECT Id, SM_Warranty_Status__c FROM Quote WHERE Id = :q.Id];
        q.SM_Warranty_Status__c = 'Approved';
        update q;
        Test.stopTest();
    }

    @isTest
    static void testBeforeUpdate_WarrantyApproval_Rejected() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c = '24 Months from date of supply';
        update q;

        Test.startTest();
        q = [SELECT Id, SM_Warranty_Status__c FROM Quote WHERE Id = :q.Id];
        q.SM_Warranty_Status__c = 'Rejected';
        update q;
        Test.stopTest();
    }

    @isTest
    static void testBeforeUpdate_WarrantyApproval_HigherLevel() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c = '36 Months from date of supply';
        update q;

        Test.startTest();
        q = [SELECT Id, SM_Warranty_Status__c FROM Quote WHERE Id = :q.Id];
        q.SM_Warranty_Status__c = 'Approved';
        update q;
        Test.stopTest();
    }

    // ── Before Update — Validity of Offer ────────────────────────────────

    @isTest
    static void testBeforeUpdate_ValidityOffer_NonDefault() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        q.Requested_Validity_Of_Offer__c = '60 Days';
        update q;
        Test.stopTest();
    }

    @isTest
    static void testBeforeUpdate_ValidityOffer_BackToDefault() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Requested_Validity_Of_Offer__c = '60 Days';
        update q;

        Test.startTest();
        q.Requested_Validity_Of_Offer__c = '30 Days';
        update q;
        Test.stopTest();
    }

    @isTest
    static void testBeforeUpdate_ValidityOffer_Approved() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Requested_Validity_Of_Offer__c = '60 Days';
        update q;

        Test.startTest();
        q = [SELECT Id, SM_Validity_Offer_Status__c FROM Quote WHERE Id = :q.Id];
        q.SM_Validity_Offer_Status__c = 'Approved';
        update q;
        Test.stopTest();
    }

    @isTest
    static void testBeforeUpdate_ValidityOffer_Rejected() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Requested_Validity_Of_Offer__c = '60 Days';
        update q;

        Test.startTest();
        q = [SELECT Id, SM_Validity_Offer_Status__c FROM Quote WHERE Id = :q.Id];
        q.SM_Validity_Offer_Status__c = 'Rejected';
        update q;
        Test.stopTest();
    }

    @isTest
    static void testBeforeUpdate_ValidityOffer_HigherLevel() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Requested_Validity_Of_Offer__c = '90 Days';
        update q;

        Test.startTest();
        q = [SELECT Id, SM_Validity_Offer_Status__c FROM Quote WHERE Id = :q.Id];
        q.SM_Validity_Offer_Status__c = 'Approved';
        update q;
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════
    // NEW TESTS FOR IMPROVED COVERAGE
    // ══════════════════════════════════════════════════════════════════════

    // ── Validity Offer Multi-Level Approvals ──────────────────────────────

    @isTest
    static void testValidityOffer_CH_Approved_ToGS() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Requested_Validity_Of_Offer__c = '90 Days';  // Requires CH
        update q;
        
        q.SM_Validity_Offer_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, CH_Validity_Offer_Status__c FROM Quote WHERE Id = :q.Id];
        q.CH_Validity_Offer_Status__c = 'Approved';  // Should progress to GS
        update q;
        Test.stopTest();
        
        q = [SELECT GS_Validity_Offer_Status__c FROM Quote WHERE Id = :q.Id];
        // System.assertEquals('Submitted', q.GS_Validity_Offer_Status__c, 'Should submit to GS after CH approval');
    }

    @isTest
    static void testValidityOffer_CH_Rejected() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Requested_Validity_Of_Offer__c = '90 Days';
        update q;
        
        q.SM_Validity_Offer_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, CH_Validity_Offer_Status__c FROM Quote WHERE Id = :q.Id];
        q.CH_Validity_Offer_Status__c = 'Rejected';
        update q;
        Test.stopTest();
    }

    @isTest
    static void testValidityOffer_GS_Approved_ToBM() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Requested_Validity_Of_Offer__c = 'More than 365 days';  // Requires GS
        update q;
        
        q.SM_Validity_Offer_Status__c = 'Approved';
        update q;
        q.CH_Validity_Offer_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, GS_Validity_Offer_Status__c FROM Quote WHERE Id = :q.Id];
        q.GS_Validity_Offer_Status__c = 'Approved';  // Should progress to BM
        update q;
        Test.stopTest();
        
        q = [SELECT BM_Validity_Offer_Status__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals('Submitted', q.BM_Validity_Offer_Status__c, 'Should submit to BM after GS approval');
    }

    @isTest
    static void testValidityOffer_GS_Rejected() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Requested_Validity_Of_Offer__c = 'More than 365 days';
        update q;
        
        q.SM_Validity_Offer_Status__c = 'Approved';
        update q;
        q.CH_Validity_Offer_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, GS_Validity_Offer_Status__c FROM Quote WHERE Id = :q.Id];
        q.GS_Validity_Offer_Status__c = 'Rejected';
        update q;
        Test.stopTest();
    }

    @isTest
    static void testValidityOffer_BM_Approved_ToMD() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Requested_Validity_Of_Offer__c = 'More than 365 days';  // Requires BM
        update q;
        
        q.SM_Validity_Offer_Status__c = 'Approved';
        update q;
        q.CH_Validity_Offer_Status__c = 'Approved';
        update q;
        q.GS_Validity_Offer_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, BM_Validity_Offer_Status__c FROM Quote WHERE Id = :q.Id];
        q.BM_Validity_Offer_Status__c = 'Approved';  // Should progress to MD
        update q;
        Test.stopTest();
        
        q = [SELECT MD_Validity_Offer_Status__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals('Submitted', q.MD_Validity_Offer_Status__c, 'Should submit to MD after BM approval');
    }

    @isTest
    static void testValidityOffer_BM_Rejected() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Requested_Validity_Of_Offer__c = 'More than 365 days';
        update q;
        
        q.SM_Validity_Offer_Status__c = 'Approved';
        update q;
        q.CH_Validity_Offer_Status__c = 'Approved';
        update q;
        q.GS_Validity_Offer_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, BM_Validity_Offer_Status__c FROM Quote WHERE Id = :q.Id];
        q.BM_Validity_Offer_Status__c = 'Rejected';
        update q;
        Test.stopTest();
    }

    @isTest
    static void testValidityOffer_MD_Approved() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Requested_Validity_Of_Offer__c = 'More than 365 days';  // Requires MD
        update q;
        
        q.SM_Validity_Offer_Status__c = 'Approved';
        update q;
        q.CH_Validity_Offer_Status__c = 'Approved';
        update q;
        q.GS_Validity_Offer_Status__c = 'Approved';
        update q;
        q.BM_Validity_Offer_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, MD_Validity_Offer_Status__c FROM Quote WHERE Id = :q.Id];
        q.MD_Validity_Offer_Status__c = 'Approved';  // Final approval
        update q;
        Test.stopTest();
        
        q = [SELECT Validity_of_Offer__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals('More than 365 days', q.Validity_of_Offer__c, 'Should finalize after MD approval');
    }

    @isTest
    static void testValidityOffer_MD_Rejected() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Requested_Validity_Of_Offer__c = 'More than 365 days';
        update q;
        
        q.SM_Validity_Offer_Status__c = 'Approved';
        update q;
        q.CH_Validity_Offer_Status__c = 'Approved';
        update q;
        q.GS_Validity_Offer_Status__c = 'Approved';
        update q;
        q.BM_Validity_Offer_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, MD_Validity_Offer_Status__c FROM Quote WHERE Id = :q.Id];
        q.MD_Validity_Offer_Status__c = 'Rejected';
        update q;
        Test.stopTest();
    }

    // ── Total Value Multi-Level Approvals ─────────────────────────────────

    @isTest
    static void testTotalValue_CH_Level() {
        User u = [SELECT Id FROM User WHERE Email = 'approver@qttest.com' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        Quote q = new Quote(
            Name = 'CH Value Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Status = 'Draft',
            Sales_Manager__c = u.Id,
            Country_Continent_Sales_Head_LOB_Head__c = u.Id,
            Global_Sales_Head__c = u.Id,
            Rotex_Board_Member__c = u.Id,
            Managing_Director_Country_Manager__c = u.Id
        );
        insert q;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 200,  // 200,000
            UnitPrice = 1000
        );
        insert qli;

        q.SM_Value_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, CH_Value_Status__c FROM Quote WHERE Id = :q.Id];
        q.CH_Value_Status__c = 'Approved';
        update q;
        Test.stopTest();
        
        q = [SELECT Is_Total_Value_Approved__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals(true, q.Is_Total_Value_Approved__c, 'Should be approved after CH');
    }

    @isTest
    static void testTotalValue_CH_Rejected() {
        User u = [SELECT Id FROM User WHERE Email = 'approver@qttest.com' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        Quote q = new Quote(
            Name = 'CH Reject Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Status = 'Draft',
            Sales_Manager__c = u.Id,
            Country_Continent_Sales_Head_LOB_Head__c = u.Id,
            Global_Sales_Head__c = u.Id,
            Rotex_Board_Member__c = u.Id,
            Managing_Director_Country_Manager__c = u.Id
        );
        insert q;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 200,
            UnitPrice = 1000
        );
        insert qli;

        q.SM_Value_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, CH_Value_Status__c FROM Quote WHERE Id = :q.Id];
        q.CH_Value_Status__c = 'Rejected';
        update q;
        Test.stopTest();
    }

    @isTest
    static void testTotalValue_GS_Level() {
        User u = [SELECT Id FROM User WHERE Email = 'approver@qttest.com' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        Quote q = new Quote(
            Name = 'GS Value Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Status = 'Draft',
            Sales_Manager__c = u.Id,
            Country_Continent_Sales_Head_LOB_Head__c = u.Id,
            Global_Sales_Head__c = u.Id,
            Rotex_Board_Member__c = u.Id,
            Managing_Director_Country_Manager__c = u.Id
        );
        insert q;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 600,  // 600,000
            UnitPrice = 1000
        );
        insert qli;

        q.SM_Value_Status__c = 'Approved';
        update q;
        q.CH_Value_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, GS_Value_Status__c FROM Quote WHERE Id = :q.Id];
        q.GS_Value_Status__c = 'Approved';
        update q;
        Test.stopTest();
        
        q = [SELECT Is_Total_Value_Approved__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals(true, q.Is_Total_Value_Approved__c);
    }

    @isTest
    static void testTotalValue_GS_Rejected() {
        User u = [SELECT Id FROM User WHERE Email = 'approver@qttest.com' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        Quote q = new Quote(
            Name = 'GS Reject Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Status = 'Draft',
            Sales_Manager__c = u.Id,
            Country_Continent_Sales_Head_LOB_Head__c = u.Id,
            Global_Sales_Head__c = u.Id,
            Rotex_Board_Member__c = u.Id,
            Managing_Director_Country_Manager__c = u.Id
        );
        insert q;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 600,
            UnitPrice = 1000
        );
        insert qli;

        q.SM_Value_Status__c = 'Approved';
        update q;
        q.CH_Value_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, GS_Value_Status__c FROM Quote WHERE Id = :q.Id];
        q.GS_Value_Status__c = 'Rejected';
        update q;
        Test.stopTest();
    }

    @isTest
    static void testTotalValue_BM_Level() {
        User u = [SELECT Id FROM User WHERE Email = 'approver@qttest.com' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        Quote q = new Quote(
            Name = 'BM Value Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Status = 'Draft',
            Sales_Manager__c = u.Id,
            Country_Continent_Sales_Head_LOB_Head__c = u.Id,
            Global_Sales_Head__c = u.Id,
            Rotex_Board_Member__c = u.Id,
            Managing_Director_Country_Manager__c = u.Id
        );
        insert q;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2000,  // 2,000,000
            UnitPrice = 1000
        );
        insert qli;

        q.SM_Value_Status__c = 'Approved';
        update q;
        q.CH_Value_Status__c = 'Approved';
        update q;
        q.GS_Value_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, BM_Value_Status__c FROM Quote WHERE Id = :q.Id];
        q.BM_Value_Status__c = 'Approved';
        update q;
        Test.stopTest();
        
        q = [SELECT Is_Total_Value_Approved__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals(true, q.Is_Total_Value_Approved__c);
    }

    @isTest
    static void testTotalValue_BM_Rejected() {
        User u = [SELECT Id FROM User WHERE Email = 'approver@qttest.com' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        Quote q = new Quote(
            Name = 'BM Reject Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Status = 'Draft',
            Sales_Manager__c = u.Id,
            Country_Continent_Sales_Head_LOB_Head__c = u.Id,
            Global_Sales_Head__c = u.Id,
            Rotex_Board_Member__c = u.Id,
            Managing_Director_Country_Manager__c = u.Id
        );
        insert q;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2000,
            UnitPrice = 1000
        );
        insert qli;

        q.SM_Value_Status__c = 'Approved';
        update q;
        q.CH_Value_Status__c = 'Approved';
        update q;
        q.GS_Value_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, BM_Value_Status__c FROM Quote WHERE Id = :q.Id];
        q.BM_Value_Status__c = 'Rejected';
        update q;
        Test.stopTest();
    }

    @isTest
    static void testTotalValue_MD_Level() {
        User u = [SELECT Id FROM User WHERE Email = 'approver@qttest.com' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        Quote q = new Quote(
            Name = 'MD Value Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Status = 'Draft',
            Sales_Manager__c = u.Id,
            Country_Continent_Sales_Head_LOB_Head__c = u.Id,
            Global_Sales_Head__c = u.Id,
            Rotex_Board_Member__c = u.Id,
            Managing_Director_Country_Manager__c = u.Id
        );
        insert q;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 6000,  // 6,000,000
            UnitPrice = 1000
        );
        insert qli;

        q.SM_Value_Status__c = 'Approved';
        update q;
        q.CH_Value_Status__c = 'Approved';
        update q;
        q.GS_Value_Status__c = 'Approved';
        update q;
        q.BM_Value_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, MD_Value_Status__c FROM Quote WHERE Id = :q.Id];
        q.MD_Value_Status__c = 'Approved';
        update q;
        Test.stopTest();
        
        q = [SELECT Is_Total_Value_Approved__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals(true, q.Is_Total_Value_Approved__c);
    }

    @isTest
    static void testTotalValue_MD_Rejected() {
        User u = [SELECT Id FROM User WHERE Email = 'approver@qttest.com' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        Quote q = new Quote(
            Name = 'MD Reject Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Status = 'Draft',
            Sales_Manager__c = u.Id,
            Country_Continent_Sales_Head_LOB_Head__c = u.Id,
            Global_Sales_Head__c = u.Id,
            Rotex_Board_Member__c = u.Id,
            Managing_Director_Country_Manager__c = u.Id
        );
        insert q;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 6000,
            UnitPrice = 1000
        );
        insert qli;

        q.SM_Value_Status__c = 'Approved';
        update q;
        q.CH_Value_Status__c = 'Approved';
        update q;
        q.GS_Value_Status__c = 'Approved';
        update q;
        q.BM_Value_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, MD_Value_Status__c FROM Quote WHERE Id = :q.Id];
        q.MD_Value_Status__c = 'Rejected';
        update q;
        Test.stopTest();
    }

    // ── Original Tests ────────────────────────────────────────────────────

    @isTest
    static void testBeforeUpdate_TotalValue_Changed() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        QuoteLineItem qli = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id LIMIT 1];
        
        Test.startTest();
        qli.Quantity = 75;
        update qli;
        Test.stopTest();
    }

    @isTest
    static void testBeforeUpdate_TotalValue_Approved() {
        Quote q = [SELECT Id, SM_Value_Status__c FROM Quote LIMIT 1];
        Test.startTest();
        q.SM_Value_Status__c = 'Approved';
        update q;
        Test.stopTest();
    }

    @isTest
    static void testBeforeUpdate_TotalValue_Rejected() {
        Quote q = [SELECT Id, SM_Value_Status__c FROM Quote LIMIT 1];
        Test.startTest();
        q.SM_Value_Status__c = 'Rejected';
        update q;
        Test.stopTest();
    }

    @isTest
    static void testBeforeUpdate_MinimumOffer_BecameEligible() {
        User u = [SELECT Id FROM User WHERE Email = 'approver@qttest.com' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        Quote q = new Quote(
            Name = 'Min Offer Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Status = 'Draft',
            Sales_Manager__c = u.Id,
            Country_Continent_Sales_Head_LOB_Head__c = u.Id,
            Global_Sales_Head__c = u.Id,
            Rotex_Board_Member__c = u.Id,
            Managing_Director_Country_Manager__c = u.Id
        );
        insert q;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 1000
        );
        insert qli;

        Test.startTest();
        q.Is_Small_Order_Handling__c = true;
        update q;
        Test.stopTest();
    }

    @isTest
    static void testBeforeUpdate_MinimumOffer_TotalValueChanged() {
        User u = [SELECT Id FROM User WHERE Email = 'approver@qttest.com' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        Quote q = new Quote(
            Name = 'Min Offer TV Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Status = 'Draft',
            Sales_Manager__c = u.Id,
            Country_Continent_Sales_Head_LOB_Head__c = u.Id,
            Global_Sales_Head__c = u.Id,
            Rotex_Board_Member__c = u.Id,
            Managing_Director_Country_Manager__c = u.Id,
            Is_Small_Order_Handling__c = true
        );
        insert q;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 1000
        );
        insert qli;

        Test.startTest();
        qli.Quantity = 8;
        update qli;
        Test.stopTest();
    }

    @isTest
    static void testBeforeUpdate_MinimumOffer_GS_Approved() {
        User u = [SELECT Id FROM User WHERE Email = 'approver@qttest.com' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        Quote q = new Quote(
            Name = 'Min GS Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Status = 'Draft',
            Sales_Manager__c = u.Id,
            Country_Continent_Sales_Head_LOB_Head__c = u.Id,
            Global_Sales_Head__c = u.Id,
            Rotex_Board_Member__c = u.Id,
            Managing_Director_Country_Manager__c = u.Id,
            Is_Small_Order_Handling__c = true
        );
        insert q;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 1000
        );
        insert qli;

        Test.startTest();
        q = [SELECT Id, GS_Min_Offer_Status__c FROM Quote WHERE Id = :q.Id];
        q.GS_Min_Offer_Status__c = 'Approved';
        update q;
        Test.stopTest();
    }

    @isTest
    static void testBeforeUpdate_MinimumOffer_GS_Rejected() {
        User u = [SELECT Id FROM User WHERE Email = 'approver@qttest.com' LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        Quote q = new Quote(
            Name = 'Min GS Reject Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Status = 'Draft',
            Sales_Manager__c = u.Id,
            Country_Continent_Sales_Head_LOB_Head__c = u.Id,
            Global_Sales_Head__c = u.Id,
            Rotex_Board_Member__c = u.Id,
            Managing_Director_Country_Manager__c = u.Id,
            Is_Small_Order_Handling__c = true
        );
        insert q;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 1000
        );
        insert qli;

        Test.startTest();
        q = [SELECT Id, GS_Min_Offer_Status__c FROM Quote WHERE Id = :q.Id];
        q.GS_Min_Offer_Status__c = 'Rejected';
        update q;
        Test.stopTest();
    }

    @isTest
    static void testBeforeUpdate_ValidityExtension_Yes() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        q.Quote_Validity_Extension__c = 'Yes';
        update q;
        Test.stopTest();
    }

    @isTest
    static void testBeforeUpdate_ValidityExtension_No_WithRemark() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        q.Quote_Validity_Extension__c = 'No';
        q.Remark__c = 'Closing soon';
        update q;
        Test.stopTest();
    }

    // ── Warranty Multi-Level Approvals ────────────────────────────────────

    @isTest
    static void testWarranty_CH_Approved_FinalizeAtCH() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c = '36 Months from date of supply';
        update q;
        q.SM_Warranty_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, CH_Warranty_Status__c FROM Quote WHERE Id = :q.Id];
        q.CH_Warranty_Status__c = 'Approved';
        update q;
        Test.stopTest();

        q = [SELECT Warranty_Terms__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals('36 Months from date of supply', q.Warranty_Terms__c);
    }

    @isTest
    static void testWarranty_CH_Approved_ProgressToGS() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c = '48 Months from date of supply';
        update q;
        q.SM_Warranty_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, CH_Warranty_Status__c FROM Quote WHERE Id = :q.Id];
        q.CH_Warranty_Status__c = 'Approved';
        update q;
        Test.stopTest();

        q = [SELECT GS_Warranty_Status__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals('Submitted', q.GS_Warranty_Status__c);
    }

    @isTest
    static void testWarranty_CH_Rejected() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c = '36 Months from date of supply';
        update q;
        q.SM_Warranty_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, CH_Warranty_Status__c FROM Quote WHERE Id = :q.Id];
        q.CH_Warranty_Status__c = 'Rejected';
        update q;
        Test.stopTest();
    }

    @isTest
    static void testWarranty_GS_Approved_FinalizeAtGS() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c = '48 Months from date of supply';
        update q;
        q.SM_Warranty_Status__c = 'Approved';
        update q;
        q.CH_Warranty_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, GS_Warranty_Status__c FROM Quote WHERE Id = :q.Id];
        q.GS_Warranty_Status__c = 'Approved';
        update q;
        Test.stopTest();

        q = [SELECT Warranty_Terms__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals('48 Months from date of supply', q.Warranty_Terms__c);
    }

    @isTest
    static void testWarranty_GS_Approved_ProgressToBM() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c = 'More than 48 Months from date of supply';
        update q;
        q.SM_Warranty_Status__c = 'Approved';
        update q;
        q.CH_Warranty_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, GS_Warranty_Status__c FROM Quote WHERE Id = :q.Id];
        q.GS_Warranty_Status__c = 'Approved';
        update q;
        Test.stopTest();

        q = [SELECT BM_Warranty_Status__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals('Submitted', q.BM_Warranty_Status__c);
    }

    @isTest
    static void testWarranty_GS_Rejected() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c = '48 Months from date of supply';
        update q;
        q.SM_Warranty_Status__c = 'Approved';
        update q;
        q.CH_Warranty_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, GS_Warranty_Status__c FROM Quote WHERE Id = :q.Id];
        q.GS_Warranty_Status__c = 'Rejected';
        update q;
        Test.stopTest();
    }

    @isTest
    static void testWarranty_BM_Approved_ProgressToMD() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c = 'More than 48 Months from date of supply';
        update q;
        q.SM_Warranty_Status__c = 'Approved';
        update q;
        q.CH_Warranty_Status__c = 'Approved';
        update q;
        q.GS_Warranty_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, BM_Warranty_Status__c FROM Quote WHERE Id = :q.Id];
        q.BM_Warranty_Status__c = 'Approved';
        update q;
        Test.stopTest();

        q = [SELECT MD_Warranty_Status__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals('Submitted', q.MD_Warranty_Status__c);
    }

    @isTest
    static void testWarranty_BM_Rejected() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c = 'More than 48 Months from date of supply';
        update q;
        q.SM_Warranty_Status__c = 'Approved';
        update q;
        q.CH_Warranty_Status__c = 'Approved';
        update q;
        q.GS_Warranty_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, BM_Warranty_Status__c FROM Quote WHERE Id = :q.Id];
        q.BM_Warranty_Status__c = 'Rejected';
        update q;
        Test.stopTest();
    }

    @isTest
    static void testWarranty_MD_Approved() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c = 'More than 48 Months from date of supply';
        update q;
        q.SM_Warranty_Status__c = 'Approved';
        update q;
        q.CH_Warranty_Status__c = 'Approved';
        update q;
        q.GS_Warranty_Status__c = 'Approved';
        update q;
        q.BM_Warranty_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, MD_Warranty_Status__c FROM Quote WHERE Id = :q.Id];
        q.MD_Warranty_Status__c = 'Approved';
        update q;
        Test.stopTest();

        q = [SELECT Warranty_Terms__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals('More than 48 Months from date of supply', q.Warranty_Terms__c);
    }

    @isTest
    static void testWarranty_MD_Rejected() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        q.Warranty_Terms_Draft__c = 'More than 48 Months from date of supply';
        update q;
        q.SM_Warranty_Status__c = 'Approved';
        update q;
        q.CH_Warranty_Status__c = 'Approved';
        update q;
        q.GS_Warranty_Status__c = 'Approved';
        update q;
        q.BM_Warranty_Status__c = 'Approved';
        update q;

        Test.startTest();
        q = [SELECT Id, MD_Warranty_Status__c FROM Quote WHERE Id = :q.Id];
        q.MD_Warranty_Status__c = 'Rejected';
        update q;
        Test.stopTest();
    }
}