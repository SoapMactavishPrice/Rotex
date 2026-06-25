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

        List<QuoteLineItem> qliList = [SELECT Id, IsDeleted, LineNumber, CurrencyIsoCode, CreatedDate, CreatedById, LastModifiedDate, LastModifiedById, SystemModstamp, LastViewedDate, LastReferencedDate, QuoteId, PricebookEntryId, OpportunityLineItemId, Quantity, UnitPrice, Discount, Description, ServiceDate, Product2Id, SortOrder, ListPrice, Subtotal, TotalPrice, Item_Group__c, Item_Number__c, Item_Description__c, Specification__c, HSN_SAC_Code__c, Location_Code__c, Type_of_Packing__c, Customer_Part_No__c, Unit__c, Unit_of_Measure_Code__c, Units_per_Parcel__c, Plant__c, Discount_as_per_SAP__c, Insurance_Charges__c, EBDTA_Gain_Deficit__c, Estimated_Freight_Per_Kgs__c, Estimated_Commission_Per_Kgs__c, Estimated_Ocean_Freight_Per_Kgs__c, Estimated_Inspection_Fee_Per_Kgs__c, LC_Confirmation_Charges_Per_Kgs__c, Other_Incidental_Expenses_Per_Kgs__c, Unit_Price_Excl_VAT_Rate_per_Kgs__c, Line_Amount_Excl_VAT_Qty_Rate__c, Discount_to_be_offered__c, Discount_offered_SAP__c, Managing_Director_Country_Manage__c, Rotex_Board_Member__c, Global_Sales_Head__c, Country_Continent_Sales_Head_LOB_Head__c, Sales_Manager__c, Sales_Rep__c, Managing_Director_Status__c, Rotex_Board_Member_Status__c, Global_Sales_Head_Status__c, Country_Continent_Sales_H_LOB_Status__c, Sales_Manager_Status__c, Sales_Rep_Status__c, Approval_Comments__c, Approval_Status__c, Approver__c, Reject_Reason__c, Managing_Director_Comments__c, Rotex_Board_Member_Comments__c, Global_Sales_Head_Comments__c, Country_Continent_Sales_LOB_Comments__c, Sales_Manager_Comments__c, Owner_Role__c, Owner_Id__c, Sales_Manager_Date_Time__c, Country_Head_Date_Time__c, Global_Sales_Head_Date_Time__c, CGST_Amount__c, SGST_Amount__c, IGST_Amount__c, CGST__c, SGST__c, IGST__c, Item_Type__c, P_F_Charges__c, P_F_Charges_Amount__c, Total_Value__c, Grand_Total__c, Unit_Price__c, HSN_Code__c, Managing_Director_Date_Time__c, Final_Discount_Approver__c, Previous_Discount__c, Is_Discount_Approved__c, Prev_Sales_Manager_Comments__c, Prev_Country_Continent_Sales_Comments__c, Prev_Global_Sales_Head_Comments__c, Prev_Rotex_Board_Member_Comments__c, Prev_Managing_Director_Comments__c, Prev_Sales_Manager_Date_Time__c, Prev_Global_Sales_Head_Date_Time__c, Rotex_Board_Member_Date_time__c, Prev_Country_Head_Date_Time__c, Prev_Rotex_Board_Member_Date_time__c, Prev_Managing_Director_Date_Time__c, New_Discount_Entered__c, Do_not_proceed_approval__c FROM QuoteLineItem LIMIT 1];

        // Modify values
        qliList[0].Quantity = 5;
        qliList[0].Discount_to_be_offered__c = 20;

        Test.startTest();
        editDiscountQuantityController.updateQuoteLineItem(qliList[0].QuoteId, qliList, true);
        Test.stopTest();

        // Verify update
        QuoteLineItem updatedQli = [
            SELECT Quantity, Discount_to_be_offered__c, Do_not_proceed_approval__c
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

}

}