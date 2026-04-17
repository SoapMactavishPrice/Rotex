@isTest
private class SalesPriceApprovalForQuotationTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test users for different approval roles
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User salesRep = new User(
            FirstName = 'Sales',
            LastName = 'Rep',
            Email = 'salesrep@test.com',
            Username = 'salesrep@test' + System.currentTimeMillis() + '.com',
            Alias = 'srep',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert salesRep;
        
        User salesManager = new User(
            FirstName = 'Sales',
            LastName = 'Manager',
            Email = 'salesmanager@test.com',
            Username = 'salesmanager@test' + System.currentTimeMillis() + '.com',
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
            Username = 'countryhead@test' + System.currentTimeMillis() + '.com',
            Alias = 'chead',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert countryHead;
        
        User managingDirector = new User(
            FirstName = 'Managing',
            LastName = 'Director',
            Email = 'md@test.com',
            Username = 'md@test' + System.currentTimeMillis() + '.com',
            Alias = 'md',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert managingDirector;
        
        User boardMember = new User(
            FirstName = 'Board',
            LastName = 'Member',
            Email = 'board@test.com',
            Username = 'board@test' + System.currentTimeMillis() + '.com',
            Alias = 'board',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert boardMember;
        
        User globalHead = new User(
            FirstName = 'Global',
            LastName = 'Head',
            Email = 'globalhead@test.com',
            Username = 'globalhead@test' + System.currentTimeMillis() + '.com',
            Alias = 'ghead',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert globalHead;
        
        // Create Account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create Opportunity
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert testOpp;

        Id standardPricebookId = Test.getStandardPricebookId();

        Pricebook2 standardPricebook = new Pricebook2(
            Id = standardPricebookId,
            IsActive = true
        );
        update standardPricebook;
        
        // Create Product
        Product2 testProduct = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert testProduct;
        
        
        // Create Quote with approval hierarchy
        Quote testQuote = new Quote(
            Name = 'Test Quote',
            OpportunityId = testOpp.Id,
            Pricebook2Id = standardPricebookId,
            Sales_Rep__c = salesRep.Id,
            Sales_Manager__c = salesManager.Id,
            Country_Continent_Sales_Head_LOB_Head__c = countryHead.Id,
            Global_Sales_Head__c = globalHead.Id,
            Managing_Director_Country_Manager__c = managingDirector.Id,
            Rotex_Board_Member__c = boardMember.Id
        );
        insert testQuote;
        
        // Create Quote Line Items with different statuses
        PricebookEntry testPBE = [
            SELECT Id, Name, UnitPrice, IsActive, Pricebook2Id, Product2Id
            FROM PricebookEntry
            WHERE Pricebook2Id = :standardPricebookId
            AND Product2Id = :testProduct.Id
            LIMIT 1
        ];

        QuoteLineItem qli1 = new QuoteLineItem(
            QuoteId = testQuote.Id,
            Product2Id = testProduct.Id,
            PricebookEntryId = testPBE.Id,
            Quantity = 1,
            UnitPrice = 800,
            Discount_as_per_SAP__c = 10,
            Discount_to_be_offered__c = 15,
            Sales_Rep__c = salesRep.Id,
            Sales_Rep_Status__c = 'Submitted',
            Sales_Manager__c = salesManager.Id,
            Sales_Manager_Status__c = 'Submitted',
            Country_Continent_Sales_Head_LOB_Head__c = countryHead.Id,
            Country_Continent_Sales_H_LOB_Status__c = 'Submitted',
            Managing_Director_Country_Manage__c = managingDirector.Id,
            Managing_Director_Status__c = 'Submitted',
            Rotex_Board_Member__c = boardMember.Id,
            Rotex_Board_Member_Status__c = 'Submitted',
            Global_Sales_Head__c = globalHead.Id,
            Global_Sales_Head_Status__c = 'Submitted'
        );
        insert qli1;
    }
    
    @isTest
    static void testGetAllQuotations_SalesRep() {
        User salesRep = [SELECT Id FROM User WHERE Email = 'salesrep@test.com' LIMIT 1];
        
        System.runAs(salesRep) {
            Test.startTest();
            List<SalesPriceApprovalForQuotation.QuotationWrapper> quotations = 
                SalesPriceApprovalForQuotation.getAllQuotations();
            Test.stopTest();
        }
    }
    
    @isTest
    static void testGetAllQuotations_SalesManager() {
        // Update QLI to have Sales Manager submitted status
        QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1];
        qli.Sales_Manager_Status__c = 'Submitted';
        update qli;
        
        User salesManager = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        
        System.runAs(salesManager) {
            Test.startTest();
            List<SalesPriceApprovalForQuotation.QuotationWrapper> quotations = 
                SalesPriceApprovalForQuotation.getAllQuotations();
            Test.stopTest();
        }
    }
    
    // @isTest
    // static void testGetAllQuotations_NoRecords() {
    //     // Delete all quote line items
    //     delete [SELECT Id FROM QuoteLineItem];
        
    //     User salesRep = [SELECT Id FROM User WHERE Email = 'salesrep@test.com' LIMIT 1];
        
    //     System.runAs(salesRep) {
    //         Test.startTest();
    //         try {
    //             List<SalesPriceApprovalForQuotation.QuotationWrapper> quotations = 
    //                 SalesPriceApprovalForQuotation.getAllQuotations();
    //         } catch (AuraHandledException e) {
    //             //     'Exception message should mention no line items found');
    //         }
    //         Test.stopTest();
    //     }
    // }
    
    @isTest
    static void testUpdateQuoteLineItem_Approved() {
        User salesRep = [SELECT Id FROM User WHERE Email = 'salesrep@test.com' LIMIT 1];
        QuoteLineItem qli = [SELECT Id, QuoteId FROM QuoteLineItem LIMIT 1];
        
        // Create wrapper for update
        SalesPriceApprovalForQuotation.QuotationWrapper wrapper = 
            new SalesPriceApprovalForQuotation.QuotationWrapper();
        wrapper.quoteId = qli.QuoteId;
        wrapper.updated = true;
        
        SalesPriceApprovalForQuotation.QuotationLineItemWrapper lineWrapper = 
            new SalesPriceApprovalForQuotation.QuotationLineItemWrapper();
        lineWrapper.quoteLineItemId = qli.Id;
        lineWrapper.approvalStatus = 'Approved';
        lineWrapper.approvalComments = 'Test Approval';
        lineWrapper.currentStageField = 'Sales_Rep_Status__c';
        lineWrapper.updated = true;
        
        wrapper.quoteLineItems = new List<SalesPriceApprovalForQuotation.QuotationLineItemWrapper>{lineWrapper};
        
        String jsonString = JSON.serialize(new List<SalesPriceApprovalForQuotation.QuotationWrapper>{wrapper});
        
        System.runAs(salesRep) {
            Test.startTest();
            String result = SalesPriceApprovalForQuotation.updateQuoteLineItem(jsonString);
            Test.stopTest();
        }
    }
    
    @isTest
    static void testUpdateQuoteLineItem_Rejected() {
        User salesManager = [SELECT Id FROM User WHERE Email = 'salesmanager@test.com' LIMIT 1];
        QuoteLineItem qli = [SELECT Id, QuoteId FROM QuoteLineItem LIMIT 1];
        
        SalesPriceApprovalForQuotation.QuotationWrapper wrapper = 
            new SalesPriceApprovalForQuotation.QuotationWrapper();
        wrapper.quoteId = qli.QuoteId;
        wrapper.updated = true;
        
        SalesPriceApprovalForQuotation.QuotationLineItemWrapper lineWrapper = 
            new SalesPriceApprovalForQuotation.QuotationLineItemWrapper();
        lineWrapper.quoteLineItemId = qli.Id;
        lineWrapper.approvalStatus = 'Rejected';
        lineWrapper.Sales_Manager_Comments = 'Test Rejection';
        lineWrapper.currentStageField = 'Sales_Manager_Status__c';
        lineWrapper.updated = true;
        
        wrapper.quoteLineItems = new List<SalesPriceApprovalForQuotation.QuotationLineItemWrapper>{lineWrapper};
        
        String jsonString = JSON.serialize(new List<SalesPriceApprovalForQuotation.QuotationWrapper>{wrapper});
        
        System.runAs(salesManager) {
            Test.startTest();
            String result = SalesPriceApprovalForQuotation.updateQuoteLineItem(jsonString);
            Test.stopTest();
        }
    }
    
    @isTest
    static void testUpdateQuoteLineItem_AllApprovalLevels() {
        User countryHead = [SELECT Id FROM User WHERE Email = 'countryhead@test.com' LIMIT 1];
        QuoteLineItem qli = [SELECT Id, QuoteId FROM QuoteLineItem LIMIT 1];
        
        // Test Country Head approval
        SalesPriceApprovalForQuotation.QuotationWrapper wrapper1 = 
            new SalesPriceApprovalForQuotation.QuotationWrapper();
        wrapper1.quoteId = qli.QuoteId;
        wrapper1.updated = true;
        
        SalesPriceApprovalForQuotation.QuotationLineItemWrapper lineWrapper1 = 
            new SalesPriceApprovalForQuotation.QuotationLineItemWrapper();
        lineWrapper1.quoteLineItemId = qli.Id;
        lineWrapper1.approvalStatus = 'Approved';
        lineWrapper1.Country_Continent_Sales_LOB_Comments = 'Country Head Approval';
        lineWrapper1.currentStageField = 'Country_Continent_Sales_H_LOB_Status__c';
        lineWrapper1.updated = true;
        
        wrapper1.quoteLineItems = new List<SalesPriceApprovalForQuotation.QuotationLineItemWrapper>{lineWrapper1};
        
        String jsonString1 = JSON.serialize(new List<SalesPriceApprovalForQuotation.QuotationWrapper>{wrapper1});
        
        System.runAs(countryHead) {
            Test.startTest();
            String result = SalesPriceApprovalForQuotation.updateQuoteLineItem(jsonString1);
            Test.stopTest();
        }
    }
    
    @isTest
    static void testUpdateQuoteLineItem_ManagingDirector() {
        User md = [SELECT Id FROM User WHERE Email = 'md@test.com' LIMIT 1];
        QuoteLineItem qli = [SELECT Id, QuoteId FROM QuoteLineItem LIMIT 1];
        
        SalesPriceApprovalForQuotation.QuotationWrapper wrapper = 
            new SalesPriceApprovalForQuotation.QuotationWrapper();
        wrapper.quoteId = qli.QuoteId;
        wrapper.updated = true;
        
        SalesPriceApprovalForQuotation.QuotationLineItemWrapper lineWrapper = 
            new SalesPriceApprovalForQuotation.QuotationLineItemWrapper();
        lineWrapper.quoteLineItemId = qli.Id;
        lineWrapper.approvalStatus = 'Approved';
        lineWrapper.Managing_Director_Comments = 'MD Approval';
        lineWrapper.currentStageField = 'Managing_Director_Status__c';
        lineWrapper.updated = true;
        
        wrapper.quoteLineItems = new List<SalesPriceApprovalForQuotation.QuotationLineItemWrapper>{lineWrapper};
        
        String jsonString = JSON.serialize(new List<SalesPriceApprovalForQuotation.QuotationWrapper>{wrapper});
        
        System.runAs(md) {
            Test.startTest();
            String result = SalesPriceApprovalForQuotation.updateQuoteLineItem(jsonString);
            Test.stopTest();
        }
    }
    
    @isTest
    static void testUpdateQuoteLineItem_BoardMember() {
        User board = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
        QuoteLineItem qli = [SELECT Id, QuoteId FROM QuoteLineItem LIMIT 1];
        
        SalesPriceApprovalForQuotation.QuotationWrapper wrapper = 
            new SalesPriceApprovalForQuotation.QuotationWrapper();
        wrapper.quoteId = qli.QuoteId;
        wrapper.updated = true;
        
        SalesPriceApprovalForQuotation.QuotationLineItemWrapper lineWrapper = 
            new SalesPriceApprovalForQuotation.QuotationLineItemWrapper();
        lineWrapper.quoteLineItemId = qli.Id;
        lineWrapper.approvalStatus = 'Approved';
        lineWrapper.Rotex_Board_Member_Comments = 'Board Approval';
        lineWrapper.currentStageField = 'Rotex_Board_Member_Status__c';
        lineWrapper.updated = true;
        
        wrapper.quoteLineItems = new List<SalesPriceApprovalForQuotation.QuotationLineItemWrapper>{lineWrapper};
        
        String jsonString = JSON.serialize(new List<SalesPriceApprovalForQuotation.QuotationWrapper>{wrapper});
        
        System.runAs(board) {
            Test.startTest();
            String result = SalesPriceApprovalForQuotation.updateQuoteLineItem(jsonString);
            Test.stopTest();
        }
    }
    
    @isTest
    static void testUpdateQuoteLineItem_GlobalHead() {
        User globalUser = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];
        QuoteLineItem qli = [SELECT Id, QuoteId FROM QuoteLineItem LIMIT 1];
        
        SalesPriceApprovalForQuotation.QuotationWrapper wrapper = 
            new SalesPriceApprovalForQuotation.QuotationWrapper();
        wrapper.quoteId = qli.QuoteId;
        wrapper.updated = true;
        
        SalesPriceApprovalForQuotation.QuotationLineItemWrapper lineWrapper = 
            new SalesPriceApprovalForQuotation.QuotationLineItemWrapper();
        lineWrapper.quoteLineItemId = qli.Id;
        lineWrapper.approvalStatus = 'Approved';
        lineWrapper.Global_Sales_Head_Comments = 'Global Head Approval';
        lineWrapper.currentStageField = 'Global_Sales_Head_Status__c';
        lineWrapper.updated = true;
        
        wrapper.quoteLineItems = new List<SalesPriceApprovalForQuotation.QuotationLineItemWrapper>{lineWrapper};
        
        String jsonString = JSON.serialize(new List<SalesPriceApprovalForQuotation.QuotationWrapper>{wrapper});
        
        System.runAs(globalUser) {
            Test.startTest();
            String result = SalesPriceApprovalForQuotation.updateQuoteLineItem(jsonString);
            Test.stopTest();
        }
    }
    
    @isTest
    static void testQuotationWrapperConstructor() {
        Quote quote = [
            SELECT Id,
                Name,
                QuoteNumber,
                Account.Name,
                OwnerId,
                Owner.Name,
                Owner.Email,
                Sales_Rep__c,
                Sales_Manager__c,
                Country_Continent_Sales_Head_LOB_Head__c,
                Global_Sales_Head__c,
                Managing_Director_Country_Manager__c,
                Rotex_Board_Member__c
            FROM Quote
            LIMIT 1
        ];
        List<QuoteLineItem> qlis = [SELECT Id, QuoteId, Product2Id, Product2.Name, 
                                     Quantity, ListPrice, UnitPrice, Sales_Rep__c,
                                     Discount_as_per_SAP__c, Discount_to_be_offered__c,
                                     Sales_Rep_Status__c, Approval_Comments__c,
                                     Sales_Manager__c, Sales_Manager_Status__c,
                                     Country_Continent_Sales_Head_LOB_Head__c,
                                     Country_Continent_Sales_H_LOB_Status__c,
                                     Managing_Director_Country_Manage__c,
                                     Managing_Director_Status__c,
                                     Rotex_Board_Member__c, Rotex_Board_Member_Status__c,
                                     Global_Sales_Head__c, Global_Sales_Head_Status__c,
                                     Country_Continent_Sales_LOB_Comments__c,
                                     Global_Sales_Head_Comments__c,
                                     Managing_Director_Comments__c,
                                     Rotex_Board_Member_Comments__c,
                                     Sales_Manager_Comments__c,
                                     Sales_Manager_Date_Time__c, Country_Head_Date_Time__c,
                                     Global_Sales_Head_Date_Time__c, Rotex_Board_Member_Date_Time__c,
                                     Managing_Director_Date_Time__c,
                                     Sales_Manager__r.Name, Country_Continent_Sales_Head_LOB_Head__r.Name, Rotex_Board_Member__r.Name, Managing_Director_Country_Manage__r.Name, Global_Sales_Head__r.Name
                                     FROM QuoteLineItem WHERE QuoteId = :quote.Id];
        
        Test.startTest();
        SalesPriceApprovalForQuotation.QuotationWrapper wrapper = 
            new SalesPriceApprovalForQuotation.QuotationWrapper(quote, qlis);
        Test.stopTest();
    }
    
    @isTest
    static void testQuotationLineItemWrapperConstructor() {
        QuoteLineItem qli = [SELECT Id, QuoteId, Product2Id, Product2.Name, 
                             Quantity, ListPrice, UnitPrice, Sales_Rep__c,
                             Discount_as_per_SAP__c, Discount_to_be_offered__c,
                             Sales_Rep_Status__c, Approval_Comments__c,
                             Sales_Manager__c, Sales_Manager_Status__c,
                             Country_Continent_Sales_Head_LOB_Head__c,
                             Country_Continent_Sales_H_LOB_Status__c,
                             Managing_Director_Country_Manage__c,
                             Managing_Director_Status__c,
                             Rotex_Board_Member__c, Rotex_Board_Member_Status__c,
                             Global_Sales_Head__c, Global_Sales_Head_Status__c,
                             Country_Continent_Sales_LOB_Comments__c,
                             Global_Sales_Head_Comments__c,
                             Managing_Director_Comments__c,
                             Rotex_Board_Member_Comments__c,
                             Sales_Manager_Comments__c,
                             Sales_Manager_Date_Time__c, Country_Head_Date_Time__c,
                             Global_Sales_Head_Date_Time__c, Rotex_Board_Member_Date_Time__c,
                             Managing_Director_Date_Time__c,
                             Sales_Manager__r.Name, Country_Continent_Sales_Head_LOB_Head__r.Name, Rotex_Board_Member__r.Name, Managing_Director_Country_Manage__r.Name, Global_Sales_Head__r.Name
                             FROM QuoteLineItem LIMIT 1];
        
        Test.startTest();
        SalesPriceApprovalForQuotation.QuotationLineItemWrapper lineWrapper = 
            new SalesPriceApprovalForQuotation.QuotationLineItemWrapper(qli);
        Test.stopTest();
    }

    @isTest
    static void testQuotationWrapperConstructor_GlobalHeadUser() {
        User globalUser = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];

        Quote quote = [
            SELECT Id,
                Name,
                QuoteNumber,
                Account.Name,
                OwnerId,
                Owner.Name,
                Owner.Email,
                Sales_Rep__c,
                Sales_Manager__c,
                Country_Continent_Sales_Head_LOB_Head__c,
                Global_Sales_Head__c,
                Managing_Director_Country_Manager__c,
                Rotex_Board_Member__c
            FROM Quote
            LIMIT 1
        ];
        List<QuoteLineItem> qlis = [
            SELECT Id, QuoteId, Product2Id, Product2.Name,
                Quantity, ListPrice, UnitPrice, Sales_Rep__c,
                Discount_as_per_SAP__c, Discount_to_be_offered__c,
                Sales_Rep_Status__c, Approval_Comments__c,
                Sales_Manager__c, Sales_Manager_Status__c,
                Country_Continent_Sales_Head_LOB_Head__c,
                Country_Continent_Sales_H_LOB_Status__c,
                Managing_Director_Country_Manage__c,
                Managing_Director_Status__c,
                Rotex_Board_Member__c, Rotex_Board_Member_Status__c,
                Global_Sales_Head__c, Global_Sales_Head_Status__c,
                Country_Continent_Sales_LOB_Comments__c,
                Global_Sales_Head_Comments__c,
                Managing_Director_Comments__c,
                Rotex_Board_Member_Comments__c,
                Sales_Manager_Comments__c,
                Sales_Manager_Date_Time__c, Country_Head_Date_Time__c,
                Global_Sales_Head_Date_Time__c, Rotex_Board_Member_Date_Time__c,
                Managing_Director_Date_Time__c,
                Sales_Manager__r.Name, Country_Continent_Sales_Head_LOB_Head__r.Name,
                Rotex_Board_Member__r.Name, Managing_Director_Country_Manage__r.Name,
                Global_Sales_Head__r.Name
            FROM QuoteLineItem
            WHERE QuoteId = :quote.Id
        ];

        System.runAs(globalUser) {
            Test.startTest();
            SalesPriceApprovalForQuotation.QuotationWrapper wrapper =
                new SalesPriceApprovalForQuotation.QuotationWrapper(quote, qlis);
            Test.stopTest();
        }
    }

    @isTest
    static void testQuotationLineItemWrapper_ApprovalStageOrder() {
        QuoteLineItem qli = [
            SELECT Id, QuoteId, Product2Id, Product2.Name,
                Quantity, ListPrice, UnitPrice, Sales_Rep__c,
                Discount_as_per_SAP__c, Discount_to_be_offered__c,
                Sales_Rep_Status__c, Approval_Comments__c,
                Sales_Manager__c, Sales_Manager_Status__c,
                Country_Continent_Sales_Head_LOB_Head__c,
                Country_Continent_Sales_H_LOB_Status__c,
                Managing_Director_Country_Manage__c,
                Managing_Director_Status__c,
                Rotex_Board_Member__c, Rotex_Board_Member_Status__c,
                Global_Sales_Head__c, Global_Sales_Head_Status__c,
                Country_Continent_Sales_LOB_Comments__c,
                Global_Sales_Head_Comments__c,
                Managing_Director_Comments__c,
                Rotex_Board_Member_Comments__c,
                Sales_Manager_Comments__c,
                Sales_Manager_Date_Time__c, Country_Head_Date_Time__c,
                Global_Sales_Head_Date_Time__c, Rotex_Board_Member_Date_Time__c,
                Managing_Director_Date_Time__c,
                Sales_Manager__r.Name, Country_Continent_Sales_Head_LOB_Head__r.Name,
                Rotex_Board_Member__r.Name, Managing_Director_Country_Manage__r.Name,
                Global_Sales_Head__r.Name
            FROM QuoteLineItem
            LIMIT 1
        ];

        User globalUser = [SELECT Id FROM User WHERE Email = 'globalhead@test.com' LIMIT 1];
        User boardUser = [SELECT Id FROM User WHERE Email = 'board@test.com' LIMIT 1];
        User mdUser = [SELECT Id FROM User WHERE Email = 'md@test.com' LIMIT 1];

        System.runAs(globalUser) {
            SalesPriceApprovalForQuotation.QuotationLineItemWrapper lineWrapper =
                new SalesPriceApprovalForQuotation.QuotationLineItemWrapper(qli);
        }

        System.runAs(boardUser) {
            SalesPriceApprovalForQuotation.QuotationLineItemWrapper lineWrapper =
                new SalesPriceApprovalForQuotation.QuotationLineItemWrapper(qli);
        }

        System.runAs(mdUser) {
            SalesPriceApprovalForQuotation.QuotationLineItemWrapper lineWrapper =
                new SalesPriceApprovalForQuotation.QuotationLineItemWrapper(qli);
        }
    }
}
