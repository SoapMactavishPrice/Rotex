public class QuoteCloner {
    
    @AuraEnabled
    public static Id cloneQuoteWithLineItems(Id quoteId) {
        Quote originalQuote = [
            SELECT Id, OwnerId, IsDeleted, Name, CurrencyIsoCode, CreatedDate, CreatedById, LastModifiedDate, LastModifiedById, 
            SystemModstamp, LastViewedDate, LastReferencedDate, OpportunityId, Pricebook2Id, ContactId, QuoteNumber, IsSyncing, 
            ShippingHandling, Tax, ExpirationDate, Description, Subtotal, TotalPrice, LineItemCount, BillingStreet, BillingCity, 
            BillingState, BillingPostalCode, BillingCountry, BillingStateCode, BillingCountryCode, BillingLatitude, BillingLongitude, 
            BillingGeocodeAccuracy, BillingAddress, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry, 
            ShippingStateCode, ShippingCountryCode, ShippingLatitude, ShippingLongitude, ShippingGeocodeAccuracy, ShippingAddress, 
            QuoteToStreet, QuoteToCity, QuoteToState, QuoteToPostalCode, QuoteToCountry, QuoteToStateCode, QuoteToCountryCode, QuoteToLatitude, 
            QuoteToLongitude, QuoteToGeocodeAccuracy, QuoteToAddress, AdditionalStreet, AdditionalCity, AdditionalState, AdditionalPostalCode, 
            AdditionalCountry, AdditionalStateCode, AdditionalCountryCode, AdditionalLatitude, AdditionalLongitude, AdditionalGeocodeAccuracy, 
            AdditionalAddress, BillingName, ShippingName, QuoteToName, AdditionalName, Email, Phone, Fax, ContractId, AccountId, QuoteAccountId, 
            Discount, GrandTotal, CanCreateQuoteLineItems, Quote_Code__c, Quote_Type__c, Quote_Date__c, Quote_Valid_Till__c, SalesOrganization__c, 
            DistributionChannel__c, Quote_Won_Lost_Reason__c, OrganizationDivision__c, Total_Before_Discount__c, SoldToParty__c, Quote_Value__c, 
            PurchaseOrderByCustomer__c, CustomerPurchaseOrderDate__c, RequestedDeliveryDate__c, Other_Terms_Conditions__c, Approval_Status__c, 
            Transaction_Type__c, Shipment__c, Payment_Terms__c, INCO_Terms__c, Commission_Type__c, Commission_Value__c, SAP_Quotation_Number__c, 
            Account__c, Customer_Reference_No__c, Customer_Reference_Date__c, Validity_of_Offer__c, Managing_Director_Country_Manager__c, 
            Rotex_Board_Member__c, Global_Sales_Head__c, Country_Continent_Sales_Head_LOB_Head__c, Sales_Manager__c, Sales_Rep__c, Sales_Rep_Status__c, 
            Sales_Manager_Status__c, Country_Continent_Sales_H_LOB_Status__c, Global_Sales_Head_Status__c, Rotex_Board_Member_Status__c, 
            Managing_Director_Status__c, L1_Approved__c, L2_Approved__c, L3_Approved__c, L4_Approved__c, Warranty_Terms__c, Payment_Terms_Approval_Status__c, 
            Warranty_Terms_Approval_Status__c, Warranty_Terms_L1_Approved__c, Warranty_Terms_L2_Approved__c, Warranty_Terms_L3_Approved__c, 
            Warranty_Terms_L4_Approved__c, Warranty_Terms_L5_Approved__c, Payment_Terms_L1_Approved__c, Payment_Terms_L2_Approved__c, Payment_Terms_L3_Approved__c, 
            Payment_Terms_L4_Approved__c, Payment_Terms_L5_Approved__c, L5_Approved__c, Is_Small_Order_Handling__c, Minimum_Offer_L1_Approved__c, 
            Minimum_Offer_L2_Approved__c, Minimum_Offer_L3_Approved__c, Minimum_Offer_L4_Approved__c, Minimum_Offer_L5_Approved__c, Minimum_Offer_Approval_Status__c, 
            Final_Approval_Flag__c, Bill_To_Party_Code__c, Rev_Date__c, RFQ_No__c, RFQ_Date__c, RFQ_Due_Date__c, Special_Remarks__c, Delivery_Location__c, Transport_Details__c, 
            Liquidate_Terms__c, Delivery_Period__c, Prices__c, Rev_No__c, Qli_Updated_Flag__c, Customer_State__c, Total_CGST_Amount__c, Total_SGST_Amount__c, Total_IGST_Amount__c, 
            Total_GST_Amount__c, Ship_To_Party_Code__c, Bill_To_Street__c, Bill_To_District__c, Bill_To_City__c, Bill_To_Postal_Code__c, Bill_To_State__c, Bill_To_Country__c, 
            Ship_To_Street__c, Ship_To_District__c, Ship_To_City__c, Ship_To_Postal_Code__c, Ship_To_State__c, Ship_To_Country__c, Total_P_F_Charges_Amount__c, Total_Value__c, 
            Grand_Total__c, Project_Details__c, Quote_Validity_Extension__c, Remark__c, Quote_Submitted__c 
            FROM Quote 
            WHERE Id = :quoteId 
            LIMIT 1
        ];
        
        Quote clonedQuote = originalQuote.clone(false, true, false, false);
        
        clonedQuote.Name = originalQuote.Name + ' - Clone';
        clonedQuote.Status = 'Draft';
        
        insert clonedQuote;
        
        List<QuoteLineItem> originalLineItems = [
            SELECT Id, IsDeleted, LineNumber, CurrencyIsoCode, CreatedDate, CreatedById, LastModifiedDate, LastModifiedById, SystemModstamp, 
            LastViewedDate, LastReferencedDate, QuoteId, PricebookEntryId, OpportunityLineItemId, Quantity, UnitPrice, Discount, Description, 
            ServiceDate, Product2Id, SortOrder, ListPrice, Subtotal, TotalPrice, Item_Group__c, Item_Number__c, Item_Description__c, Specification__c, 
            HSN_SAC_Code__c, Location_Code__c, Type_of_Packing__c, Customer_Part_No__c, Unit__c, Unit_of_Measure_Code__c, Units_per_Parcel__c, Plant__c, 
            Discount_as_per_SAP__c, Insurance_Charges__c, EBDTA_Gain_Deficit__c, Estimated_Freight_Per_Kgs__c, Estimated_Commission_Per_Kgs__c, 
            Estimated_Ocean_Freight_Per_Kgs__c, Estimated_Inspection_Fee_Per_Kgs__c, LC_Confirmation_Charges_Per_Kgs__c, Other_Incidental_Expenses_Per_Kgs__c, 
            Unit_Price_Excl_VAT_Rate_per_Kgs__c, Line_Amount_Excl_VAT_Qty_Rate__c, Discount_offered_SAP__c, 
            Managing_Director_Country_Manage__c, Rotex_Board_Member__c, Global_Sales_Head__c, Country_Continent_Sales_Head_LOB_Head__c, Sales_Manager__c, Sales_Rep__c, 
            Approval_Comments__c, Approval_Status__c, Approver__c, Reject_Reason__c, Owner_Role__c, Owner_Id__c, 
            CGST_Amount__c, SGST_Amount__c, IGST_Amount__c, CGST__c, SGST__c, IGST__c, 
            Item_Type__c, P_F_Charges__c, P_F_Charges_Amount__c, Total_Value__c, Grand_Total__c, Unit_Price__c, HSN_Code__c 
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
        ];
        
        if (!originalLineItems.isEmpty()) {
            List<QuoteLineItem> clonedLineItems = new List<QuoteLineItem>();
            
            for (QuoteLineItem lineItem : originalLineItems) {
                QuoteLineItem clonedLineItem = lineItem.clone(false, true, false, false);
                
                clonedLineItem.QuoteId = clonedQuote.Id;
                clonedLineItem.UnitPrice = lineItem.ListPrice; // Reset UnitPrice to ListPrice for the cloned line item
                
                clonedLineItems.add(clonedLineItem);
            }
            
            insert clonedLineItems;
        }
        
        return clonedQuote.Id;
    }

}