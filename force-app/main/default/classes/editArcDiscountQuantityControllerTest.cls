@IsTest
public class editArcDiscountQuantityControllerTest {

    @testSetup
    static void setupData() {
        // Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Use Standard Pricebook
        Id standardPBId = Test.getStandardPricebookId();

        // Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(10),
            AccountId = acc.Id,
            Pricebook2Id = standardPBId
        );
        insert opp;

        // Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            ProductCode = '930000',
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

        // Customer ARC Pricing
        Customer_ARC_Pricing__c arcPrice = new Customer_ARC_Pricing__c(
            Customer__c = acc.Id,
            Material__c = prod.Id,
            Amount__c = 900
        );
        insert arcPrice;
    }

    @IsTest
    static void testGetQuoteAndLineItems() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];

        Test.startTest();
        editArcDiscountQuantityController.QuoteDataWrapper result = editArcDiscountQuantityController.getQuoteAndLineItems(q.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result wrapper should not be null');
        System.assertNotEquals(null, result.quoteRecord, 'Quote record should be returned');
        System.assertEquals(1, result.lineItems.size(), 'One QLI should be returned');
    }

    @IsTest
    static void testUpdateQuoteAndLineItems() {
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
        insert soaMatrixList;

        Quote q = [SELECT Id FROM Quote LIMIT 1];
        List<QuoteLineItem> qliList = [
            SELECT Id, IsDeleted, LineNumber, CurrencyIsoCode, CreatedDate, CreatedById, LastModifiedDate, LastModifiedById, SystemModstamp, LastViewedDate, LastReferencedDate, QuoteId, PricebookEntryId, OpportunityLineItemId, Quantity, UnitPrice, Discount, Description, ServiceDate, Product2Id, SortOrder, ListPrice, Subtotal, TotalPrice, Item_Group__c, Item_Number__c, Item_Description__c, Specification__c, HSN_SAC_Code__c, Location_Code__c, Type_of_Packing__c, Customer_Part_No__c, Unit__c, Unit_of_Measure_Code__c, Units_per_Parcel__c, Plant__c, Discount_as_per_SAP__c, Insurance_Charges__c, EBDTA_Gain_Deficit__c, Estimated_Freight_Per_Kgs__c, Estimated_Commission_Per_Kgs__c, Estimated_Ocean_Freight_Per_Kgs__c, Estimated_Inspection_Fee_Per_Kgs__c, LC_Confirmation_Charges_Per_Kgs__c, Other_Incidental_Expenses_Per_Kgs__c, Unit_Price_Excl_VAT_Rate_per_Kgs__c, Line_Amount_Excl_VAT_Qty_Rate__c, Discount_to_be_offered__c, Discount_offered_SAP__c, Managing_Director_Country_Manage__c, Rotex_Board_Member__c, Global_Sales_Head__c, Country_Continent_Sales_Head_LOB_Head__c, Sales_Manager__c, Sales_Rep__c, Managing_Director_Status__c, Rotex_Board_Member_Status__c, Global_Sales_Head_Status__c, Country_Continent_Sales_H_LOB_Status__c, Sales_Manager_Status__c, Sales_Rep_Status__c, Approval_Comments__c, Approval_Status__c, Approver__c, Reject_Reason__c, Managing_Director_Comments__c, Rotex_Board_Member_Comments__c, Global_Sales_Head_Comments__c, Country_Continent_Sales_LOB_Comments__c, Sales_Manager_Comments__c, Owner_Role__c, Owner_Id__c, Sales_Manager_Date_Time__c, Country_Head_Date_Time__c, Global_Sales_Head_Date_Time__c, CGST_Amount__c, SGST_Amount__c, IGST_Amount__c, CGST__c, SGST__c, IGST__c, Item_Type__c, P_F_Charges__c, P_F_Charges_Amount__c, Total_Value__c, Grand_Total__c, Unit_Price__c, HSN_Code__c, Managing_Director_Date_Time__c, Final_Discount_Approver__c, Previous_Discount__c, Is_Discount_Approved__c, Prev_Sales_Manager_Comments__c, Prev_Country_Continent_Sales_Comments__c, Prev_Global_Sales_Head_Comments__c, Prev_Rotex_Board_Member_Comments__c, Prev_Managing_Director_Comments__c, Prev_Sales_Manager_Date_Time__c, Prev_Global_Sales_Head_Date_Time__c, Rotex_Board_Member_Date_time__c, Prev_Country_Head_Date_Time__c, Prev_Rotex_Board_Member_Date_time__c, Prev_Managing_Director_Date_Time__c, New_Discount_Entered__c, Do_not_proceed_approval__c, Is_Discount_Only_Rejected__c, Is_QLI_Approved_going_for_Approval__c 
            FROM QuoteLineItem
        ];

        qliList[0].Discount_to_be_offered__c = 8;
        qliList[0].Potential_Value__c = 5000;
        qliList[0].Potential_Qty__c = 10;
        qliList[0].Valid_from__c = Date.today();
        qliList[0].Valid_Till__c = Date.today().addDays(30);

        Test.startTest();
        editArcDiscountQuantityController.updateQuoteAndLineItems(
            q.Id, 
            qliList, 
            true, 
            'Open Credit upto 30 days', 
            '12 Months from date of supply', 
            'FOB'
        );
        Test.stopTest();

        // Verify update on QLI
        QuoteLineItem updatedQli = [
            SELECT Quantity, Discount_as_per_SAP__c, Discount_to_be_offered__c, Potential_Value__c, Potential_Qty__c
            FROM QuoteLineItem 
            WHERE Id = :qliList[0].Id
        ];
        System.assertEquals(1, updatedQli.Quantity, 'Quantity should be set to 1');
        System.assertEquals(0, updatedQli.Discount_as_per_SAP__c, 'SAP discount should be set to 0');
        System.assertEquals(8, updatedQli.Discount_to_be_offered__c, 'Discount offered should be updated');
        System.assertEquals(5000, updatedQli.Potential_Value__c, 'Potential Value should be updated');
        System.assertEquals(10, updatedQli.Potential_Qty__c, 'Potential Qty should be updated');

        // Verify update on Quote
        Quote updatedQ = [
            SELECT Payment_Terms__c, Warranty_Terms_Draft__c, INCO_Terms__c, Status
            FROM Quote
            WHERE Id = :q.Id
        ];
        System.assertEquals('Open Credit upto 180 days', updatedQ.Payment_Terms__c, 'Payment terms should match');
        System.assertEquals('12 Months from date of supply', updatedQ.Warranty_Terms_Draft__c, 'Warranty should match');
        System.assertEquals('FOB', updatedQ.INCO_Terms__c, 'Incoterms should match');
        System.assertEquals('Need Revision', updatedQ.Status, 'Quote status should be set to Need Revision');
    }
}
