public class QuoteLineItemHelper {
   
    public static void updateSmallOrderFlag(Set<Id> quoteIds) {
        // Query to check if any QLI under these quotes has product code 27000002809
        Map<Id, Boolean> quoteHasSpecialProduct = new Map<Id, Boolean>();
        
        for (AggregateResult ar : [
            SELECT QuoteId qId
            FROM QuoteLineItem
            WHERE QuoteId IN :quoteIds
            AND Product2.ProductCode = '27000002809'
            GROUP BY QuoteId
        ]) {
            quoteHasSpecialProduct.put((Id)ar.get('qId'), true);
        }
        
        List<Quote> quotesToUpdate = new List<Quote>();
        for (Id qId : quoteIds) {
            Boolean hasSpecialProduct = quoteHasSpecialProduct.containsKey(qId);
            quotesToUpdate.add(new Quote(
                Id = qId,
                Is_Small_Order_Handling__c = hasSpecialProduct
            ));
        }
        
        if (!quotesToUpdate.isEmpty()) {
            update quotesToUpdate;
        }
    }
}