public class editDiscountQuantityController {
    @AuraEnabled(cacheable=true)
    public static List<QuoteLineItem> getQuoteLineItem(String qId) {
        return [SELECT Id, Discount_as_per_SAP__c, Discount_to_be_offered__c, Quantity,
            UnitPrice, ListPrice, Customer_Part_No__c, Product2.Name, Product2Id
            FROM QuoteLineItem WHERE QuoteId = :qId
        ];
    }

    @AuraEnabled
    public static void updateQuoteLineItem(List<QuoteLineItem> quoteLineItems) {
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