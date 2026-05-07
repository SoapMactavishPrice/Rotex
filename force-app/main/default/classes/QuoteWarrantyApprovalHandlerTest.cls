/**
 * @description Test class for QuoteWarrantyApprovalHandler
 */
@isTest
private class QuoteWarrantyApprovalHandlerTest {
    
    /**
     * @description Creates test data for approval process testing
     */
    @testSetup
    static void setupTestData() {
        // Create test users for approval hierarchy
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User salesManager = new User(
            FirstName = 'Sales',
            LastName = 'Manager',
            Email = 'salesmanager@test.com',
            Username = 'salesmanager@test.rotex.com',
            Alias = 'smgr',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert salesManager;
        
        User countryHead = new User(
            FirstName = 'Country',
            LastName = 'Head',
            Email = 'countryhead@test.com',
            Username = 'countryhead@test.rotex.com',
            Alias = 'chead',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert countryHead;
        
        User globalSalesHead = new User(
            FirstName = 'Global',
            LastName = 'SalesHead',
            Email = 'globalsales@test.com',
            Username = 'globalsales@test.rotex.com',
            Alias = 'gshead',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert globalSalesHead;
        
        User boardMember = new User(
            FirstName = 'Board',
            LastName = 'Member',
            Email = 'boardmember@test.com',
            Username = 'boardmember@test.rotex.com',
            Alias = 'bmember',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert boardMember;
        
        // Create SOA Matrix records
        List<SOA_Matrix__c> soaMatrixList = new List<SOA_Matrix__c>();
        
        soaMatrixList.add(new SOA_Matrix__c(
            SOA_Profile__c = 'Sales Manager',
            Warranty_Terms__c = '24 Months from date of supply'
        ));
        
        soaMatrixList.add(new SOA_Matrix__c(
            SOA_Profile__c = 'Country / Continent Sales Head / LOB Head',
            Warranty_Terms__c = '30 Months from date of supply'
        ));
        
        soaMatrixList.add(new SOA_Matrix__c(
            SOA_Profile__c = 'Global Sales Head',
            Warranty_Terms__c = '36 Months from date of supply'
        ));
        
        soaMatrixList.add(new SOA_Matrix__c(
            SOA_Profile__c = 'Rotex Board Member',
            Warranty_Terms__c = '48 Months from date of supply'
        ));
        
        insert soaMatrixList;
        
        // Create test Account and Opportunity
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert testOpp;
    }
    
    /**
     * @description Tests quote creation with 12 months warranty (no approval needed)
     */
    @isTest
    static void testQuoteWithDefaultWarrantyTerms() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        Quote testQuote = new Quote(
            Name = 'Test Quote',
            OpportunityId = testOpp.Id,
            Warranty_Terms_Draft__c = '12 Months from date of supply'
        );
        insert testQuote;
        Test.stopTest();
        
        Quote result = [SELECT Id, Warranty_Terms__c, SM_Warranty_Status__c, 
                        Final_Warranty_Terms_Approver__c 
                        FROM Quote WHERE Id = :testQuote.Id];
        
        System.assertEquals('12 Months from date of supply', result.Warranty_Terms__c, 
                          'Warranty terms should be set directly for 12 months');
        System.assertEquals(null, result.SM_Warranty_Status__c, 
                          'No approval should be initiated for 12 months');
    }
    
    /**
     * @description Tests quote creation with 24 months warranty requiring approval
     */
    @isTest
    static void testQuoteWith24MonthsWarrantyTerms() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        User salesManager = [SELECT Id FROM User WHERE Username = 'salesmanager@test.rotex.com' LIMIT 1];
        
        Test.startTest();
        Quote testQuote = new Quote(
            Name = 'Test Quote 24M',
            OpportunityId = testOpp.Id,
            Warranty_Terms_Draft__c = '24 Months from date of supply',
            Sales_Manager__c = salesManager.Id
        );
        insert testQuote;
        Test.stopTest();
        
        Quote result = [SELECT Id, Warranty_Terms__c, SM_Warranty_Status__c, 
                        Final_Warranty_Terms_Approver__c, SM_Warranty_Date_Time__c
                        FROM Quote WHERE Id = :testQuote.Id];
        
        System.assertEquals('Submitted', result.SM_Warranty_Status__c, 
                          'Sales Manager approval should be submitted');
        System.assertEquals('Sales Manager', result.Final_Warranty_Terms_Approver__c,
                          'Final approver should be Sales Manager for 24 months');
        System.assertNotEquals(null, result.SM_Warranty_Date_Time__c,
                             'Date time should be set');
    }
    
    /**
     * @description Tests approval progression from Sales Manager to Country Head
     */
    @isTest
    static void testApprovalProgressionTo30Months() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        User salesManager = [SELECT Id FROM User WHERE Username = 'salesmanager@test.rotex.com' LIMIT 1];
        User countryHead = [SELECT Id FROM User WHERE Username = 'countryhead@test.rotex.com' LIMIT 1];
        
        Quote testQuote = new Quote(
            Name = 'Test Quote 30M',
            OpportunityId = testOpp.Id,
            Warranty_Terms_Draft__c = '30 Months from date of supply',
            Sales_Manager__c = salesManager.Id,
            Country_Continent_Sales_Head_LOB_Head__c = countryHead.Id
        );
        insert testQuote;
        
        Test.startTest();
        // Approve by Sales Manager
        testQuote.SM_Warranty_Status__c = 'Approved';
        update testQuote;
        Test.stopTest();
        
        Quote result = [SELECT Id, SM_Warranty_Status__c, CH_Warranty_Status__c,
                        CH_Warranty_Date_Time__c, Final_Warranty_Terms_Approver__c
                        FROM Quote WHERE Id = :testQuote.Id];
        
        System.assertEquals('Approved', result.SM_Warranty_Status__c,
                          'Sales Manager should be approved');
        System.assertEquals('Submitted', result.CH_Warranty_Status__c,
                          'Country Head approval should be submitted');
        System.assertEquals('Country / Continent Sales Head / LOB Head', 
                          result.Final_Warranty_Terms_Approver__c,
                          'Final approver should be Country Head for 30 months');
    }
    
    /**
     * @description Tests complete approval chain for 48 months warranty
     */
    @isTest
    static void testCompleteApprovalChainFor48Months() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        User salesManager = [SELECT Id FROM User WHERE Username = 'salesmanager@test.rotex.com' LIMIT 1];
        User countryHead = [SELECT Id FROM User WHERE Username = 'countryhead@test.rotex.com' LIMIT 1];
        User globalSalesHead = [SELECT Id FROM User WHERE Username = 'globalsales@test.rotex.com' LIMIT 1];
        User boardMember = [SELECT Id FROM User WHERE Username = 'boardmember@test.rotex.com' LIMIT 1];
        
        Quote testQuote = new Quote(
            Name = 'Test Quote 48M',
            OpportunityId = testOpp.Id,
            Warranty_Terms_Draft__c = '48 Months from date of supply',
            Sales_Manager__c = salesManager.Id,
            Country_Continent_Sales_Head_LOB_Head__c = countryHead.Id,
            Global_Sales_Head__c = globalSalesHead.Id,
            Rotex_Board_Member__c = boardMember.Id
        );
        insert testQuote;
        
        Test.startTest();
        
        // Sales Manager approves
        testQuote.SM_Warranty_Status__c = 'Approved';
        update testQuote;
        
        testQuote = [SELECT Id, CH_Warranty_Status__c FROM Quote WHERE Id = :testQuote.Id];
        System.assertEquals('Submitted', testQuote.CH_Warranty_Status__c);
        
        // Country Head approves
        testQuote.CH_Warranty_Status__c = 'Approved';
        update testQuote;
        
        testQuote = [SELECT Id, GS_Warranty_Status__c FROM Quote WHERE Id = :testQuote.Id];
        System.assertEquals('Submitted', testQuote.GS_Warranty_Status__c);
        
        // Global Sales Head approves
        testQuote.GS_Warranty_Status__c = 'Approved';
        update testQuote;
        
        testQuote = [SELECT Id, BM_Warranty_Status__c FROM Quote WHERE Id = :testQuote.Id];
        System.assertEquals('Submitted', testQuote.BM_Warranty_Status__c);
        
        // Board Member (final approver) approves
        testQuote.BM_Warranty_Status__c = 'Approved';
        update testQuote;
        
        Test.stopTest();
        
        Quote result = [SELECT Id, Warranty_Terms__c, Warranty_Terms_Draft__c,
                        BM_Warranty_Status__c FROM Quote WHERE Id = :testQuote.Id];
        
        System.assertEquals('Approved', result.BM_Warranty_Status__c,
                          'Board Member should be approved');
        System.assertEquals(result.Warranty_Terms_Draft__c, result.Warranty_Terms__c,
                          'Warranty Terms should be finalized after final approval');
    }
    
    /**
     * @description Tests rejection at Sales Manager level
     */
    @isTest
    static void testRejectionAtSalesManagerLevel() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        User salesManager = [SELECT Id FROM User WHERE Username = 'salesmanager@test.rotex.com' LIMIT 1];
        
        Quote testQuote = new Quote(
            Name = 'Test Quote Reject',
            OpportunityId = testOpp.Id,
            Warranty_Terms_Draft__c = '36 Months from date of supply',
            Sales_Manager__c = salesManager.Id
        );
        insert testQuote;
        
        Test.startTest();
        testQuote.SM_Warranty_Status__c = 'Rejected';
        testQuote.SM_Warranty_Comments__c = 'Not approved due to policy';
        update testQuote;
        Test.stopTest();
        
        Quote result = [SELECT Id, Warranty_Terms__c, SM_Warranty_Status__c,
                        CH_Warranty_Status__c FROM Quote WHERE Id = :testQuote.Id];
        
        System.assertEquals('Rejected', result.SM_Warranty_Status__c,
                          'Sales Manager should have rejected');
        System.assertEquals(null, result.CH_Warranty_Status__c,
                          'Should not progress to Country Head after rejection');
        System.assertNotEquals(result.Warranty_Terms_Draft__c, result.Warranty_Terms__c,
                             'Warranty Terms should not be finalized after rejection');
    }
    
    /**
     * @description Tests resetting approval when warranty terms draft changes
     */
    @isTest
    static void testResetApprovalOnWarrantyTermsChange() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        User salesManager = [SELECT Id FROM User WHERE Username = 'salesmanager@test.rotex.com' LIMIT 1];
        
        Quote testQuote = new Quote(
            Name = 'Test Quote Change',
            OpportunityId = testOpp.Id,
            Warranty_Terms_Draft__c = '24 Months from date of supply',
            Sales_Manager__c = salesManager.Id
        );
        insert testQuote;
        
        // Approve by Sales Manager
        testQuote.SM_Warranty_Status__c = 'Approved';
        update testQuote;
        
        Test.startTest();
        // Change warranty terms to 36 months
        testQuote.Warranty_Terms_Draft__c = '36 Months from date of supply';
        update testQuote;
        Test.stopTest();
        
        Quote result = [SELECT Id, SM_Warranty_Status__c, Final_Warranty_Terms_Approver__c
                        FROM Quote WHERE Id = :testQuote.Id];
        
        System.assertEquals('Submitted', result.SM_Warranty_Status__c,
                          'Approval should be reset and resubmitted');
        System.assertEquals('Global Sales Head', result.Final_Warranty_Terms_Approver__c,
                          'Final approver should be updated for 36 months');
    }
    
    /**
     * @description Tests changing warranty terms back to 12 months
     */
    @isTest
    static void testChangeToDefaultWarrantyTerms() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        User salesManager = [SELECT Id FROM User WHERE Username = 'salesmanager@test.rotex.com' LIMIT 1];
        
        Quote testQuote = new Quote(
            Name = 'Test Quote Default Change',
            OpportunityId = testOpp.Id,
            Warranty_Terms_Draft__c = '24 Months from date of supply',
            Sales_Manager__c = salesManager.Id
        );
        insert testQuote;
        
        Test.startTest();
        // Change warranty terms to 12 months
        testQuote.Warranty_Terms_Draft__c = '12 Months from date of supply';
        update testQuote;
        Test.stopTest();
        
        Quote result = [SELECT Id, Warranty_Terms__c, SM_Warranty_Status__c,
                        Final_Warranty_Terms_Approver__c FROM Quote WHERE Id = :testQuote.Id];
        
        System.assertEquals('12 Months from date of supply', result.Warranty_Terms__c,
                          'Warranty terms should be set directly for 12 months');
        System.assertEquals(null, result.SM_Warranty_Status__c,
                          'All approval fields should be reset');
        System.assertEquals(null, result.Final_Warranty_Terms_Approver__c,
                          'Final approver should be null');
    }
}