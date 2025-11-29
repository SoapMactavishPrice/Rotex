/*@isTest
public class QuoteLineItemApprovalHandlerTest {

    @isTest
    static void testProcessApprovals() {

        // Step 1: Activate Standard Pricebook
        Id standardPricebookId = Test.getStandardPricebookId();
        Pricebook2 stdPb = new Pricebook2(
            Id = standardPricebookId,
            Name = 'Standard Price Book',
            IsActive = true
        );
        upsert stdPb;

        // Step 2: Create Product
        Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
        insert prod;

        // Step 3: Create or get existing PricebookEntry
        PricebookEntry pbe;
        List<PricebookEntry> existingPbe = [
            SELECT Id FROM PricebookEntry 
            WHERE Product2Id = :prod.Id AND Pricebook2Id = :standardPricebookId LIMIT 1
        ];
        if (!existingPbe.isEmpty()) {
            pbe = existingPbe[0];
        } else {
            pbe = new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = prod.Id,
                UnitPrice = 100,
                IsActive = true,
                CurrencyIsoCode = 'INR'
            );
            insert pbe;
        }

        // Step 4: Create Users
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        
        User salesRep = new User(
            FirstName='Sales',
            LastName='Rep',
            Email='salesrep'+System.currentTimeMillis()+'@test.com',
            Username='salesrep'+System.currentTimeMillis()+'@test.com',
            Alias='srep',
            TimeZoneSidKey='GMT',
            LocaleSidKey='en_US',
            EmailEncodingKey='UTF-8',
            ProfileId=p.Id,
            LanguageLocaleKey='en_US'
        );
        insert salesRep;

        User salesManager = new User(
            FirstName='Sales',
            LastName='Manager',
            Email='salesmanager'+System.currentTimeMillis()+'@test.com',
            Username='salesmanager'+System.currentTimeMillis()+'@test.com',
            Alias='smgr',
            TimeZoneSidKey='GMT',
            LocaleSidKey='en_US',
            EmailEncodingKey='UTF-8',
            ProfileId=p.Id,
            LanguageLocaleKey='en_US'
        );
        insert salesManager;

        // Step 5: Create Account
        Account acc = new Account(Name='Test Account');
        insert acc;

        // Step 6: Create Quote with Standard Pricebook
        Quote q = new Quote(
            Name='Test Quote',
            OwnerId=salesRep.Id,
            Pricebook2Id = standardPricebookId
        );
        insert q;

        // Step 7: Create QuoteLineItem with required PricebookEntry
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 100,
            Discount_to_be_offered__c = 15,
            Discount_as_per_SAP__c = 10
        );
        insert qli;

        Test.startTest();
        // Call the handler method
        QuoteLineItemApprovalHandler.processApprovals(new List<QuoteLineItem>{qli});
        Test.stopTest();

        // Step 8: Verify the Submitted status is set
        QuoteLineItem updatedQli = [SELECT Id, Sales_Manager_Status__c FROM QuoteLineItem WHERE Id = :qli.Id];
    }
}*/

@isTest
public class QuoteLineItemApprovalHandlerTest {

    @isTest
    static void testProcessApprovals_FullCoverage() {

        Id standardPricebookId = Test.getStandardPricebookId();
        Pricebook2 stdPb = new Pricebook2(Id = standardPricebookId, IsActive = true);
        upsert stdPb;

        Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
        insert prod;

        PricebookEntry pbe;
        List<PricebookEntry> existingPbe = [
            SELECT Id FROM PricebookEntry 
            WHERE Product2Id = :prod.Id 
            AND Pricebook2Id = :standardPricebookId 
            LIMIT 1
        ];
        if (!existingPbe.isEmpty()) {
            pbe = existingPbe[0];
        } else {
            pbe = new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = prod.Id,
                UnitPrice = 100,
                IsActive = true
            );
            insert pbe;
        }

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User salesRep = new User(
            FirstName = 'Sales',
            LastName = 'Rep',
            Email = 'salesrep' + System.currentTimeMillis() + '@test.com',
            Username = 'salesrep' + System.currentTimeMillis() + '@test.com',
            Alias = 'srep',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US',
            SOA_Profile__c = 'Sales Rep'
        );
        insert salesRep;

        User salesManager = new User(
            FirstName = 'Sales',
            LastName = 'Manager',
            Email = 'salesmanager' + System.currentTimeMillis() + '@test.com',
            Username = 'salesmanager' + System.currentTimeMillis() + '@test.com',
            Alias = 'smgr',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US',
            SOA_Profile__c = 'Sales Manager'
        );
        insert salesManager;

        User countryHead = new User(
            FirstName = 'Country',
            LastName = 'Head',
            Email = 'countryhead' + System.currentTimeMillis() + '@test.com',
            Username = 'countryhead' + System.currentTimeMillis() + '@test.com',
            Alias = 'chead',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert countryHead;
        
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Opportunity opp = new Opportunity();
        opp.Name = 'Test Opportunity';
        opp.StageName = 'Prospecting';
        opp.CloseDate = Date.today().addDays(30);
        insert opp;
        
        Quote quoteRep = new Quote(
            Name = 'Quote - Sales Rep',
            OwnerId = salesRep.Id,
            Pricebook2Id = standardPricebookId,
            OpportunityId= opp.Id,
            Sales_Manager__c = salesManager.Id
        );
        insert quoteRep;

        Quote quoteManager = new Quote(
            Name = 'Quote - Sales Manager',
            OwnerId = salesManager.Id,
            Pricebook2Id = standardPricebookId,
            OpportunityId= opp.Id,
            Country_Continent_Sales_Head_LOB_Head__c = countryHead.Id,
            Validity_of_Offer__c = '180 Days',
            Payment_Terms__c = 'Open Credit upto 180 days',
            Warranty_Terms__c = '48 Months from date of supply',
            Is_Small_Order_Handling__c = true,
            Minimum_Offer_Approval_Status__c = 'Approved',
            Payment_Terms_Approval_Status__c = 'Approved',
            Warranty_Terms_Approval_Status__c = 'Approved'
        );
        insert quoteManager;
        quoteManager.QLI_Updated_Flag__c = true;
        try{
        update quoteManager;
        }Catch(Exception e){}
        QuoteLineItem qliRep = new QuoteLineItem(
            QuoteId = quoteRep.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 100,
            Discount_to_be_offered__c = 15,
            Discount_as_per_SAP__c = 10
        );
        insert qliRep;
        qliRep.Quantity = 6;
        update qliRep;
        QuoteLineItem qliMgr = new QuoteLineItem(
            QuoteId = quoteManager.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 10,
            UnitPrice = 200,
            Discount_to_be_offered__c = 20,
            Discount_as_per_SAP__c = 5
        );
        insert qliMgr;

        Test.startTest();
        QuoteLineItemApprovalHandler.processApprovals(new List<QuoteLineItem>{ qliRep, qliMgr });
        Test.stopTest();

        QuoteLineItem updatedRep = [
            SELECT Id, Sales_Manager_Status__c 
            FROM QuoteLineItem 
            WHERE Id = :qliRep.Id
        ];

        QuoteLineItem updatedMgr = [
            SELECT Id, Country_Continent_Sales_H_LOB_Status__c 
            FROM QuoteLineItem 
            WHERE Id = :qliMgr.Id
        ];

    }
}