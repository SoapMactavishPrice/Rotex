public class editDiscountQuantityController {
    @AuraEnabled(cacheable=true)
    public static List<QuoteLineItem> getQuoteLineItem(String qId) {
        return [SELECT Id, Discount_as_per_SAP__c, Discount_to_be_offered__c, Quantity, 
            UnitPrice, ListPrice, Customer_Part_No__c, Product2.Name, Product2Id, P_F_Charges__c, Final_Discount_Approver__c, Sales_Rep__c, Sales_Manager__c, 
            Country_Continent_Sales_Head_LOB_Head__c, Global_Sales_Head__c, Rotex_Board_Member__c, Managing_Director_Country_Manage__c
            FROM QuoteLineItem WHERE QuoteId = :qId
        ];
    }

    @AuraEnabled
    public static void updateQuoteLineItem(List<QuoteLineItem> quoteLineItems) {

        List<SOA_Matrix__c> matrixList = [
            SELECT SOA_Profile__c, Min_Discount__c, Max_Discount__c
            FROM SOA_Matrix__c
        ];

        for (QuoteLineItem qli : quoteLineItems) {
            if (qli.Discount_to_be_offered__c != null && qli.Discount_as_per_SAP__c != null && qli.Discount_to_be_offered__c > qli.Discount_as_per_SAP__c) {
                for (SOA_Matrix__c matrix : matrixList) {
                    if (qli.Discount_to_be_offered__c >= matrix.Min_Discount__c && qli.Discount_to_be_offered__c <= matrix.Max_Discount__c) {
                        if (matrix.SOA_Profile__c == 'Sales Rep') {
                            qli.Final_Discount_Approver__c = qli.Sales_Rep__c;
                        } else if (matrix.SOA_Profile__c == 'Sales Manager') {
                            qli.Final_Discount_Approver__c = qli.Sales_Manager__c;
                        } else if (matrix.SOA_Profile__c == 'Country / Continent Sales Head / LOB Head') {
                            qli.Final_Discount_Approver__c = qli.Country_Continent_Sales_Head_LOB_Head__c;
                        } else if (matrix.SOA_Profile__c == 'Global Sales Head') {
                            qli.Final_Discount_Approver__c = qli.Global_Sales_Head__c;
                        } else if (matrix.SOA_Profile__c == 'Rotex Board Member') {
                            qli.Final_Discount_Approver__c = qli.Rotex_Board_Member__c;
                        } else if (matrix.SOA_Profile__c == 'Managing Director / Country Manager') {
                            qli.Final_Discount_Approver__c = qli.Managing_Director_Country_Manage__c;
                        }
                        break;
                    }
                }
            }
        }

        update quoteLineItems;
    }

    @AuraEnabled
    public static void updateShiptoBilltoOnQuote(String qId, String shipto, String billto) {
        
        Quote q = [
            SELECT Id, Ship_To_Party_Code__c, Bill_To_Party_Code__c,
            BillingStreet, BillingCity, BillingCountry, BillingPostalCode, BillingStateCode,
            ShippingStreet, ShippingCity, ShippingCountry, ShippingPostalCode, ShippingStateCode,
            Bill_To_Street__c,Bill_To_City__c,Bill_To_District__c,Bill_To_Postal_Code__c,Bill_To_State__c,Bill_To_Country__c,
            Ship_To_Street__c,Ship_To_City__c,Ship_To_District__c,Ship_To_Postal_Code__c,Ship_To_State__c,Ship_To_Country__c
            FROM Quote WHERE Id = :qId
        ];
        System.debug('q-->'+q);
        System.debug('shipto-->'+shipto);
        System.debug('billto-->'+billto);
        
        Map<String, Object> shiptoMap = (Map<String, Object>)JSON.deserializeUntyped(shipto);
        Map<String, Object> billtoMap = (Map<String, Object>)JSON.deserializeUntyped(billto);

        System.debug('shiptoMap-->'+shiptoMap);
        System.debug('billtoMap-->'+billtoMap);

        q.Ship_To_Party_Code__c = (String)shiptoMap.get('Partner_No__c');
        q.Bill_To_Party_Code__c = (String)billtoMap.get('Partner_No__c');
        q.Bill_To_Street__c = (String)billtoMap.get('Street__c');
        q.Bill_To_City__c = (String)billtoMap.get('City__c');
        q.Bill_To_District__c = (String)billtoMap.get('District__c');
        q.Bill_To_Country__c = (String)billtoMap.get('Country__c');
        q.Bill_To_Postal_Code__c = (String)billtoMap.get('Postal_Code__c');
        q.Bill_To_State__c = (String)billtoMap.get('State__c');
        q.Ship_To_Street__c = (String)shiptoMap.get('Street__c');
        q.Ship_To_City__c = (String)shiptoMap.get('City__c');
        q.Ship_To_District__c = (String)shiptoMap.get('District__c');
        q.Ship_To_Country__c = (String)shiptoMap.get('Country__c');
        q.Ship_To_Postal_Code__c = (String)shiptoMap.get('Postal_Code__c');
        q.Ship_To_State__c = (String)shiptoMap.get('State__c');
        update q;
    }

}