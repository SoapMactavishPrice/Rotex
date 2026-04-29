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

        List<QuoteLineItem> qliList = [SELECT Id, Discount_as_per_SAP__c, Discount_to_be_offered__c, Quantity, 
            UnitPrice, ListPrice, Customer_Part_No__c, Product2.Name, Product2Id, P_F_Charges__c, Final_Discount_Approver__c, Sales_Rep__c, Sales_Manager__c, 
            Country_Continent_Sales_Head_LOB_Head__c, Global_Sales_Head__c, Rotex_Board_Member__c, Managing_Director_Country_Manage__c
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
    @IsTest
static void testUpdateShiptoBilltoOnQuote() {

    // Fetch existing test quote created in @testSetup
    Quote q = [
        SELECT Id 
        FROM Quote 
        LIMIT 1
    ];

    // Create mock Ship-To JSON
    String shiptoJson = JSON.serialize(new Map<String, Object>{
        'Partner_No__c' => 'SHIP001',
        'Street__c' => 'Ship Street 123',
        'City__c' => 'ShipCity',
        'Postal_Code__c' => '111111'
    });

    // Create mock Bill-To JSON
    String billtoJson = JSON.serialize(new Map<String, Object>{
        'Partner_No__c' => 'BILL001',
        'Street__c' => 'Bill Street 987',
        'City__c' => 'BillCity',
        'Postal_Code__c' => '999999'
    });

    Test.startTest();
    editDiscountQuantityController.updateShiptoBilltoOnQuote(
        q.Id,
        shiptoJson,
        billtoJson
    );
    Test.stopTest();

    // Query updated quote fields
    Quote updatedQ = [
        SELECT Ship_To_Party_Code__c, Bill_To_Party_Code__c,
        BillingStreet, BillingCity, BillingPostalCode,
        ShippingStreet, ShippingCity, ShippingPostalCode,
        Bill_To_Street__c,Bill_To_City__c,Bill_To_Postal_Code__c,Bill_To_State__c,Bill_To_Country__c,
        Ship_To_Street__c,Ship_To_City__c,Ship_To_Postal_Code__c,Ship_To_State__c,Ship_To_Country__c
        FROM Quote
        WHERE Id = :q.Id
    ];

    // 🔥 Assertions for updated fields
    System.assertEquals('SHIP001', updatedQ.Ship_To_Party_Code__c);
    System.assertEquals('BILL001', updatedQ.Bill_To_Party_Code__c);

    System.assertEquals('Ship Street 123', updatedQ.Ship_To_Street__c);
    System.assertEquals('ShipCity', updatedQ.Ship_To_City__c);
    System.assertEquals('111111', updatedQ.Ship_To_Postal_Code__c);

    System.assertEquals('Bill Street 987', updatedQ.Bill_To_Street__c);
    System.assertEquals('BillCity', updatedQ.Bill_To_City__c);
    System.assertEquals('999999', updatedQ.Bill_To_Postal_Code__c);
}

}