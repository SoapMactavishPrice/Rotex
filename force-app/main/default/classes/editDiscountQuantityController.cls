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
            ShippingStreet, ShippingCity, ShippingCountry, ShippingPostalCode, ShippingStateCode
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
        q.BillingStreet = (String)shiptoMap.get('Street__c');
        q.BillingCity = (String)shiptoMap.get('City__c');
        // q.BillingCountry = (String)shiptoMap.get('Country__c');
        q.BillingPostalCode = (String)shiptoMap.get('Postal_Code__c');
        // q.BillingStateCode = (String)shiptoMap.get('State__c');
        q.ShippingStreet = (String)billtoMap.get('Street__c');
        q.ShippingCity = (String)billtoMap.get('City__c');
        // q.ShippingCountry = (String)billtoMap.get('Country__c');
        q.ShippingPostalCode = (String)billtoMap.get('Postal_Code__c');
        // q.ShippingStateCode = (String)billtoMap.get('State__c');
        update q;
    }

}