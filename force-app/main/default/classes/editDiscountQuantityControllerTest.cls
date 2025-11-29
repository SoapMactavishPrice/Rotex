@IsTest
public class editDiscountQuantityControllerTest {

    @testSetup
    static void setupData() {

        // Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;

        // Use Standard Pricebook
        Id standardPBId = Test.getStandardPricebookId();

        // Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert prod;

        // Pricebook Entry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPBId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        // Quote
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = standardPBId
        );
        insert q;

        // Quote Line Item
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 100,
            Discount_as_per_SAP__c = 5,
            Discount_to_be_offered__c = 10
        );
        insert qli;
    }

    @IsTest
    static void testGetQuoteLineItem() {
        
        // Get Quote Id
        Quote q = [SELECT Id FROM Quote LIMIT 1];

        Test.startTest();
        List<QuoteLineItem> result = editDiscountQuantityController.getQuoteLineItem(q.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(1, result.size(), 'One QLI should be returned');

        QuoteLineItem qli = result[0];
        System.assertEquals(2, qli.Quantity);
        System.assertEquals(5, qli.Discount_as_per_SAP__c);
        System.assertEquals(10, qli.Discount_to_be_offered__c);
    }

    @IsTest
    static void testUpdateQuoteLineItem() {

        List<QuoteLineItem> qliList = [SELECT Id, Quantity, Discount_to_be_offered__c 
                                       FROM QuoteLineItem LIMIT 1];

        // Modify values
        qliList[0].Quantity = 5;
        qliList[0].Discount_to_be_offered__c = 20;

        Test.startTest();
        editDiscountQuantityController.updateQuoteLineItem(qliList);
        Test.stopTest();

        // Verify update
        QuoteLineItem updatedQli = [
            SELECT Quantity, Discount_to_be_offered__c 
            FROM QuoteLineItem 
            WHERE Id = :qliList[0].Id
        ];

        System.assertEquals(5, updatedQli.Quantity, 'Quantity should be updated');
        System.assertEquals(20, updatedQli.Discount_to_be_offered__c, 'Discount should be updated');
    }
}