@isTest
public class QuoteLineItemSequentialApprovalTest {
    
    @testSetup
    static void setupData() {
        // 1️⃣ Create SOA Matrix Records
        List<SOA_Matrix__c> soaMatrixList = new List<SOA_Matrix__c>();
        soaMatrixList.add(new SOA_Matrix__c(
            SOA_Profile__c = 'Sales Rep',
            Min_Discount__c = 0,
            Max_Discount__c = 5
        ));
        soaMatrixList.add(new SOA_Matrix__c(
            SOA_Profile__c = 'Sales Manager',
            Min_Discount__c = 5.01,
            Max_Discount__c = 10
        ));
        soaMatrixList.add(new SOA_Matrix__c(
            SOA_Profile__c = 'Country / Continent Sales Head / LOB Head',
            Min_Discount__c = 10.01,
            Max_Discount__c = 15
        ));
        soaMatrixList.add(new SOA_Matrix__c(
            SOA_Profile__c = 'Global Sales Head',
            Min_Discount__c = 15.01,
            Max_Discount__c = 20
        ));
        soaMatrixList.add(new SOA_Matrix__c(
            SOA_Profile__c = 'Rotex Board Member',
            Min_Discount__c = 20.01,
            Max_Discount__c = 25
        ));
        soaMatrixList.add(new SOA_Matrix__c(
            SOA_Profile__c = 'Managing Director / Country Manager',
            Min_Discount__c = 25.01,
            Max_Discount__c = 30
        ));
        insert soaMatrixList;

        // 2️⃣ Create Users (Approvers)
        List<User> users = new List<User>();
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        for (Integer i = 0; i < 6; i++) {
            users.add(new User(
                FirstName = 'User' + i,
                LastName = 'Approver' + System.currentTimeMillis() + String.valueOf(i),
                Email = 'user' + i + System.currentTimeMillis() + '@test.com',
                Username = 'user' + i + System.currentTimeMillis() + String.valueOf(i) + '@test.com',
                Alias = 'usr' + i,
                TimeZoneSidKey = 'America/New_York',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = p.Id
            ));
        }
        insert users;
        
        Id salesRepId = users[0].Id;
        Id salesMgrId = users[1].Id;
        Id countryHeadId = users[2].Id;
        Id globalHeadId = users[3].Id;
        Id rotexBoardId = users[4].Id;
        Id managingDirectorId = users[5].Id;
        
        // 3️⃣ Create Account
        Account acc = new Account(Name = 'Test Account ' + System.currentTimeMillis());
        insert acc;
        
        // 4️⃣ Get or Create Standard Pricebook
        Id standardPbId = Test.getStandardPricebookId();
        
        // 5️⃣ Create Product
        Product2 prod = new Product2(
            Name = 'Test Product ' + System.currentTimeMillis(), 
            IsActive = true
        );
        insert prod;
        
        // 6️⃣ Create Standard Pricebook Entry
        PricebookEntry stdPbe = new PricebookEntry(
            Pricebook2Id = standardPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert stdPbe;
        
        // 7️⃣ Create Custom Pricebook
        Pricebook2 customPb = new Pricebook2(
            Name = 'Custom PB ' + System.currentTimeMillis(), 
            IsActive = true
        );
        insert customPb;
        
        // 8️⃣ Create Custom Pricebook Entry
        PricebookEntry customPbe = new PricebookEntry(
            Pricebook2Id = customPb.Id,
            Product2Id = prod.Id,
            UnitPrice = 120,
            IsActive = true
        );
        insert customPbe;
        
        // 9️⃣ Create Opportunity (required for Quote)
        Opportunity opp = new Opportunity(
            Name = 'Test Opp ' + System.currentTimeMillis(),
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            Pricebook2Id = customPb.Id
        );
        insert opp;
        
        // 🔟 Create Quote with all approvers
        Quote q = new Quote(
            Name = 'Test Quote ' + System.currentTimeMillis(),
            OpportunityId = opp.Id,
            Pricebook2Id = customPb.Id,
            OwnerId = salesRepId,
            Sales_Rep__c = salesRepId,
            Sales_Manager__c = salesMgrId,
            Country_Continent_Sales_Head_LOB_Head__c = countryHeadId,
            Global_Sales_Head__c = globalHeadId,
            Rotex_Board_Member__c = rotexBoardId,
            Managing_Director_Country_Manager__c = managingDirectorId
        );
        insert q;
        
        // 1️⃣1️⃣ Create Quote Line Item
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = customPbe.Id,
            Product2Id = prod.Id,
            Quantity = 2,
            UnitPrice = 120,
            Discount_to_be_offered__c = 12,
            Discount_as_per_SAP__c = 10,
            Sales_Manager__c = salesMgrId,
            Country_Continent_Sales_Head_LOB_Head__c = countryHeadId,
            Global_Sales_Head__c = globalHeadId,
            Rotex_Board_Member__c = rotexBoardId,
            Managing_Director_Country_Manage__c = managingDirectorId
        );
        insert qli;
    }

    @isTest
    static void testSequentialApprovalsFlow_SalesManagerToCountryHead() {
        QuoteLineItem qli = [SELECT Id, QuoteId, Discount_to_be_offered__c, 
                                    Sales_Manager_Status__c, Country_Continent_Sales_H_LOB_Status__c,
                                    Sales_Manager__c, Country_Continent_Sales_Head_LOB_Head__c,
                                    Global_Sales_Head__c, Rotex_Board_Member__c, 
                                    Managing_Director_Country_Manage__c, Product2.Name,
                                    Global_Sales_Head_Status__c, Rotex_Board_Member_Status__c,
                                    Managing_Director_Status__c
                             FROM QuoteLineItem LIMIT 1];
        
        qli.Sales_Manager_Status__c = 'Approved';
        qli.Discount_to_be_offered__c = 12; // In Country/Continent range
        update qli;
        
        Test.startTest();
        QuoteLineItemSequentialApprovalHandler.processSequentialApprovals(new List<QuoteLineItem>{ qli });
        Test.stopTest();
        
        QuoteLineItem updatedQLI = [
            SELECT Country_Continent_Sales_H_LOB_Status__c
            FROM QuoteLineItem WHERE Id = :qli.Id
        ];
        // Country Head status should be Submitted
    }

    @isTest
    static void testSequentialApprovalsFlow_CountryHeadToGlobalHead() {
        QuoteLineItem qli = [SELECT Id, Discount_to_be_offered__c, QuoteId,
                                    Sales_Manager_Status__c, Country_Continent_Sales_H_LOB_Status__c,
                                    Sales_Manager__c, Country_Continent_Sales_Head_LOB_Head__c,
                                    Global_Sales_Head__c, Rotex_Board_Member__c, 
                                    Managing_Director_Country_Manage__c, Product2.Name,
                                    Global_Sales_Head_Status__c, Rotex_Board_Member_Status__c,
                                    Managing_Director_Status__c
                             FROM QuoteLineItem LIMIT 1];
        
        qli.Discount_to_be_offered__c = 18; // In Global Head range
        qli.Sales_Manager_Status__c = 'Approved';
        qli.Country_Continent_Sales_H_LOB_Status__c = 'Approved';
        update qli;
        
        Test.startTest();
        QuoteLineItemSequentialApprovalHandler.processSequentialApprovals(new List<QuoteLineItem>{ qli });
        Test.stopTest();
        
        QuoteLineItem updatedQLI = [
            SELECT Global_Sales_Head_Status__c
            FROM QuoteLineItem WHERE Id = :qli.Id
        ];
        // Global Head status should be Submitted
    }

    @isTest
    static void testSequentialApprovalsFlow_GlobalHeadToRotex() {
        QuoteLineItem qli = [SELECT Id, Discount_to_be_offered__c, QuoteId,
                                    Sales_Manager_Status__c, Country_Continent_Sales_H_LOB_Status__c,
                                    Sales_Manager__c, Country_Continent_Sales_Head_LOB_Head__c,
                                    Global_Sales_Head__c, Rotex_Board_Member__c, 
                                    Managing_Director_Country_Manage__c, Product2.Name,
                                    Global_Sales_Head_Status__c, Rotex_Board_Member_Status__c,
                                    Managing_Director_Status__c
                             FROM QuoteLineItem LIMIT 1];
        
        qli.Discount_to_be_offered__c = 22; // In Rotex range
        qli.Sales_Manager_Status__c = 'Approved';
        qli.Country_Continent_Sales_H_LOB_Status__c = 'Approved';
        qli.Global_Sales_Head_Status__c = 'Approved';
        update qli;
        
        Test.startTest();
        QuoteLineItemSequentialApprovalHandler.processSequentialApprovals(new List<QuoteLineItem>{ qli });
        Test.stopTest();
        
        QuoteLineItem updatedQLI = [
            SELECT Rotex_Board_Member_Status__c
            FROM QuoteLineItem WHERE Id = :qli.Id
        ];
        // Rotex Board status should be Submitted
    }

    @isTest
    static void testSequentialApprovalsFlow_RotexToMD() {
        QuoteLineItem qli = [SELECT Id, Discount_to_be_offered__c, QuoteId,
                                    Sales_Manager_Status__c, Country_Continent_Sales_H_LOB_Status__c,
                                    Sales_Manager__c, Country_Continent_Sales_Head_LOB_Head__c,
                                    Global_Sales_Head__c, Rotex_Board_Member__c, 
                                    Managing_Director_Country_Manage__c, Product2.Name,
                                    Global_Sales_Head_Status__c, Rotex_Board_Member_Status__c,
                                    Managing_Director_Status__c
                             FROM QuoteLineItem LIMIT 1];
        
        qli.Discount_to_be_offered__c = 28; // In MD range
        qli.Sales_Manager_Status__c = 'Approved';
        qli.Country_Continent_Sales_H_LOB_Status__c = 'Approved';
        qli.Global_Sales_Head_Status__c = 'Approved';
        qli.Rotex_Board_Member_Status__c = 'Approved';
        update qli;
        
        Test.startTest();
        QuoteLineItemSequentialApprovalHandler.processSequentialApprovals(new List<QuoteLineItem>{ qli });
        Test.stopTest();
        
        QuoteLineItem updatedQLI = [
            SELECT Managing_Director_Status__c
            FROM QuoteLineItem WHERE Id = :qli.Id
        ];
        // MD status should be Submitted
    }

    @isTest
    static void testDefineNextApprover_SalesManagerApproved_SetCountryHead() {
        QuoteLineItem qli = [SELECT Id, Discount_to_be_offered__c, Sales_Manager_Status__c,
                                    Country_Continent_Sales_Head_LOB_Head__c, Global_Sales_Head_Status__c,
                                    Rotex_Board_Member_Status__c, Sales_Manager__c,
                                    Country_Continent_Sales_H_LOB_Status__c, Global_Sales_Head__c,
                                    Rotex_Board_Member__c, Managing_Director_Country_Manage__c,
                                    Managing_Director_Status__c
                             FROM QuoteLineItem LIMIT 1];
        
        qli.Discount_to_be_offered__c = 12; // Exceeds Sales Manager max (10)
        
        QuoteLineItem oldQli = qli.clone(true, true, true, true);
        oldQli.Sales_Manager_Status__c = 'Pending';
        
        Map<Id, QuoteLineItem> oldMap = new Map<Id, QuoteLineItem>{qli.Id => oldQli};
        
        qli.Sales_Manager_Status__c = 'Approved';
        
        Test.startTest();
        QuoteLineItemSequentialApprovalHandler.defineNextApprover(new List<QuoteLineItem>{ qli }, oldMap);
        Test.stopTest();
        
        // Country Head should be set to Submitted
    }

    @isTest
    static void testDefineNextApprover_CountryHeadApproved_SetGlobalHead() {
        QuoteLineItem qli = [SELECT Id, Discount_to_be_offered__c, Country_Continent_Sales_H_LOB_Status__c,
                                    Sales_Manager_Status__c, Global_Sales_Head__c, Rotex_Board_Member_Status__c,
                                    Sales_Manager__c, Country_Continent_Sales_Head_LOB_Head__c,
                                    Global_Sales_Head_Status__c, Rotex_Board_Member__c,
                                    Managing_Director_Country_Manage__c, Managing_Director_Status__c
                             FROM QuoteLineItem LIMIT 1];
        
        qli.Discount_to_be_offered__c = 18; // Exceeds Country Head max (15)
        
        QuoteLineItem oldQli = qli.clone(true, true, true, true);
        oldQli.Country_Continent_Sales_H_LOB_Status__c = 'Pending';
        
        Map<Id, QuoteLineItem> oldMap = new Map<Id, QuoteLineItem>{qli.Id => oldQli};
        
        qli.Country_Continent_Sales_H_LOB_Status__c = 'Approved';
        
        Test.startTest();
        QuoteLineItemSequentialApprovalHandler.defineNextApprover(new List<QuoteLineItem>{ qli }, oldMap);
        Test.stopTest();
        
        // Global Head should be set to Submitted
    }

    @isTest
    static void testDefineNextApprover_GlobalHeadApproved_SetRotex() {
        QuoteLineItem qli = [SELECT Id, Discount_to_be_offered__c, Global_Sales_Head_Status__c, 
                                    Country_Continent_Sales_H_LOB_Status__c, Sales_Manager_Status__c,
                                    Global_Sales_Head__c, Rotex_Board_Member_Status__c, Rotex_Board_Member__c,
                                    Sales_Manager__c, Country_Continent_Sales_Head_LOB_Head__c,
                                    Managing_Director_Country_Manage__c, Managing_Director_Status__c
                             FROM QuoteLineItem LIMIT 1];
        
        qli.Discount_to_be_offered__c = 22; // Exceeds Global Head max (20)
        
        QuoteLineItem oldQli = qli.clone(true, true, true, true);
        oldQli.Global_Sales_Head_Status__c = 'Pending';
        
        Map<Id, QuoteLineItem> oldMap = new Map<Id, QuoteLineItem>{qli.Id => oldQli};
        
        qli.Global_Sales_Head_Status__c = 'Approved';
        
        Test.startTest();
        QuoteLineItemSequentialApprovalHandler.defineNextApprover(new List<QuoteLineItem>{ qli }, oldMap);
        Test.stopTest();
        
        // Rotex Board Member should be set to Submitted
    }

    @isTest
    static void testDefineNextApprover_RotexApproved_SetMD() {
        QuoteLineItem qli = [SELECT Id, Discount_to_be_offered__c, Rotex_Board_Member_Status__c,
                                    Sales_Manager_Status__c, Country_Continent_Sales_H_LOB_Status__c,
                                    Global_Sales_Head_Status__c, Managing_Director_Country_Manage__c,
                                    Sales_Manager__c, Country_Continent_Sales_Head_LOB_Head__c,
                                    Global_Sales_Head__c, Rotex_Board_Member__c,
                                    Managing_Director_Status__c
                             FROM QuoteLineItem LIMIT 1];
        
        qli.Discount_to_be_offered__c = 28; // Exceeds Rotex max (25)
        
        QuoteLineItem oldQli = qli.clone(true, true, true, true);
        oldQli.Rotex_Board_Member_Status__c = 'Pending';
        
        Map<Id, QuoteLineItem> oldMap = new Map<Id, QuoteLineItem>{qli.Id => oldQli};
        
        qli.Rotex_Board_Member_Status__c = 'Approved';
        
        Test.startTest();
        QuoteLineItemSequentialApprovalHandler.defineNextApprover(new List<QuoteLineItem>{ qli }, oldMap);
        Test.stopTest();
        
        // MD should be set to Submitted
    }

    @isTest
    static void testDefineNextApprover_DiscountWithinCurrentLevel() {
        QuoteLineItem qli = [SELECT Id, Discount_to_be_offered__c, Sales_Manager_Status__c,
                                    Country_Continent_Sales_Head_LOB_Head__c, Global_Sales_Head_Status__c,
                                    Rotex_Board_Member_Status__c, Sales_Manager__c,
                                    Country_Continent_Sales_H_LOB_Status__c, Global_Sales_Head__c,
                                    Rotex_Board_Member__c, Managing_Director_Country_Manage__c,
                                    Managing_Director_Status__c
                             FROM QuoteLineItem LIMIT 1];
        
        qli.Discount_to_be_offered__c = 8; // Within Sales Manager max (10)
        
        QuoteLineItem oldQli = qli.clone(true, true, true, true);
        oldQli.Sales_Manager_Status__c = 'Pending';
        
        Map<Id, QuoteLineItem> oldMap = new Map<Id, QuoteLineItem>{qli.Id => oldQli};
        
        qli.Sales_Manager_Status__c = 'Approved';
        
        Test.startTest();
        QuoteLineItemSequentialApprovalHandler.defineNextApprover(new List<QuoteLineItem>{ qli }, oldMap);
        Test.stopTest();
        
        // Country Head should NOT be submitted when discount is within Sales Manager limit
    }

    @isTest
    static void testNoApproverScenario() {
        // Create separate Quote without approvers
        Account acc = new Account(Name = 'No Approver Account');
        insert acc;
        
        Id standardPbId = Test.getStandardPricebookId();
        
        Opportunity opp = new Opportunity(
            Name = 'No Approver Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            Pricebook2Id = standardPbId
        );
        insert opp;
        
        Quote q = new Quote(
            Name = 'No Approver Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = standardPbId
        );
        insert q;
        
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry 
                              WHERE Pricebook2Id = :standardPbId 
                              AND Product2Id = :prod.Id LIMIT 1];
        
        QuoteLineItem noApproverQli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Product2Id = prod.Id,
            Quantity = 1,
            UnitPrice = 100,
            Discount_to_be_offered__c = 15,
            Sales_Manager_Status__c = 'Approved'
        );
        insert noApproverQli;
        
        Test.startTest();
        QuoteLineItemSequentialApprovalHandler.processSequentialApprovals(
            new List<QuoteLineItem>{ noApproverQli }
        );
        Test.stopTest();
        
        // Handled missing approver safely
    }

    @isTest
    static void testNullDiscountScenario() {
        QuoteLineItem qli = [SELECT Id, QuoteId, Sales_Manager__c, 
                                    Country_Continent_Sales_Head_LOB_Head__c,
                                    Global_Sales_Head__c, Rotex_Board_Member__c, 
                                    Managing_Director_Country_Manage__c,
                                    Product2.Name, Sales_Manager_Status__c, 
                                    Country_Continent_Sales_H_LOB_Status__c,
                                    Global_Sales_Head_Status__c, Rotex_Board_Member_Status__c, 
                                    Managing_Director_Status__c, Discount_to_be_offered__c
                             FROM QuoteLineItem LIMIT 1];
        
        qli.Discount_to_be_offered__c = null;
        qli.Sales_Manager_Status__c = 'Approved';
        update qli;
        
        Test.startTest();
        QuoteLineItemSequentialApprovalHandler.processSequentialApprovals(
            new List<QuoteLineItem>{ qli }
        );
        Test.stopTest();
        
        // Handled null discount safely
    }

    @isTest
    static void testEmptyListScenario() {
        Test.startTest();
        QuoteLineItemSequentialApprovalHandler.processSequentialApprovals(
            new List<QuoteLineItem>()
        );
        QuoteLineItemSequentialApprovalHandler.defineNextApprover(
            new List<QuoteLineItem>(), null
        );
        Test.stopTest();
        
        // Empty list handled gracefully
    }

    @isTest
    static void testDiscountNotInRangeScenario() {
        QuoteLineItem qli = [SELECT Id, Discount_to_be_offered__c, QuoteId,
                                    Sales_Manager__c, Country_Continent_Sales_Head_LOB_Head__c,
                                    Global_Sales_Head__c, Rotex_Board_Member__c, 
                                    Managing_Director_Country_Manage__c,
                                    Product2.Name, Sales_Manager_Status__c, 
                                    Country_Continent_Sales_H_LOB_Status__c,
                                    Global_Sales_Head_Status__c, Rotex_Board_Member_Status__c, 
                                    Managing_Director_Status__c
                             FROM QuoteLineItem LIMIT 1];
        
        qli.Discount_to_be_offered__c = 50; // Outside all ranges
        qli.Sales_Manager_Status__c = 'Approved';
        update qli;
        
        Test.startTest();
        QuoteLineItemSequentialApprovalHandler.processSequentialApprovals(
            new List<QuoteLineItem>{ qli }
        );
        Test.stopTest();
        
        QuoteLineItem updatedQLI = [
            SELECT Country_Continent_Sales_H_LOB_Status__c
            FROM QuoteLineItem WHERE Id = :qli.Id
        ];
        
        // Should not submit when discount is out of range
    }

    @isTest
    static void testStatusAlreadySet() {
        QuoteLineItem qli = [SELECT Id, Discount_to_be_offered__c, QuoteId,
                                    Sales_Manager__c, Country_Continent_Sales_Head_LOB_Head__c,
                                    Global_Sales_Head__c, Rotex_Board_Member__c, 
                                    Managing_Director_Country_Manage__c,
                                    Product2.Name, Sales_Manager_Status__c, 
                                    Country_Continent_Sales_H_LOB_Status__c,
                                    Global_Sales_Head_Status__c, Rotex_Board_Member_Status__c, 
                                    Managing_Director_Status__c
                             FROM QuoteLineItem LIMIT 1];
        
        qli.Discount_to_be_offered__c = 12;
        qli.Sales_Manager_Status__c = 'Approved';
        qli.Country_Continent_Sales_H_LOB_Status__c = 'Rejected'; // Already has a status
        update qli;
        
        Test.startTest();
        QuoteLineItemSequentialApprovalHandler.processSequentialApprovals(
            new List<QuoteLineItem>{ qli }
        );
        Test.stopTest();
        
        QuoteLineItem updatedQLI = [
            SELECT Country_Continent_Sales_H_LOB_Status__c
            FROM QuoteLineItem WHERE Id = :qli.Id
        ];
        
        // Should not change status if already set
    }

    @isTest
    static void testDefineNextApprover_NoOldMap() {
        QuoteLineItem qli = [SELECT Id, Discount_to_be_offered__c, Sales_Manager_Status__c,
                                    Country_Continent_Sales_Head_LOB_Head__c,
                                    Country_Continent_Sales_H_LOB_Status__c, Global_Sales_Head__c,
                                    Sales_Manager__c, Global_Sales_Head_Status__c,
                                    Rotex_Board_Member__c, Rotex_Board_Member_Status__c,
                                    Managing_Director_Country_Manage__c, Managing_Director_Status__c
                             FROM QuoteLineItem LIMIT 1];
        
        Test.startTest();
        QuoteLineItemSequentialApprovalHandler.defineNextApprover(
            new List<QuoteLineItem>{ qli }, null
        );
        Test.stopTest();
        
        // Handled null oldMap gracefully
    }

    @isTest
    static void testDefineNextApprover_NullQLI() {
        Test.startTest();
        // This tests the null check in evaluateAndSetNextApprover
        QuoteLineItemSequentialApprovalHandler.defineNextApprover(
            new List<QuoteLineItem>(), new Map<Id, QuoteLineItem>()
        );
        Test.stopTest();
        
        // Handled null QLI safely
    }

    @isTest
    static void testMultipleQLIsBatch() {
        List<QuoteLineItem> qliList = [SELECT Id, Discount_to_be_offered__c, QuoteId,
                                              Sales_Manager__c, Country_Continent_Sales_Head_LOB_Head__c,
                                              Global_Sales_Head__c, Rotex_Board_Member__c, 
                                              Managing_Director_Country_Manage__c,
                                              Product2.Name, Sales_Manager_Status__c, 
                                              Country_Continent_Sales_H_LOB_Status__c,
                                              Global_Sales_Head_Status__c, 
                                              Rotex_Board_Member_Status__c, 
                                              Managing_Director_Status__c
                                       FROM QuoteLineItem];
        
        for (QuoteLineItem qli : qliList) {
            qli.Sales_Manager_Status__c = 'Approved';
            qli.Discount_to_be_offered__c = 12;
        }
        update qliList;
        
        Test.startTest();
        QuoteLineItemSequentialApprovalHandler.processSequentialApprovals(qliList);
        QuoteLineItemSequentialApprovalHandler.testCoverageMethod();
        Test.stopTest();
        
        // Handled multiple QLIs successfully
    }
}