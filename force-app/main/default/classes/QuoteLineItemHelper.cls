public class QuoteLineItemHelper {
   
    public static void updateSmallOrderFlag(Set<Id> quoteIds) {
        System.debug('=== SMALL ORDER FLAG UPDATE START ===');
        System.debug('Input Quote IDs: ' + quoteIds);
        System.debug('Number of Quote IDs to process: ' + quoteIds.size());
        
        if (quoteIds.isEmpty()) {
            System.debug('SMALL ORDER: No Quote IDs provided, exiting');
            return;
        }
        
        // Query to check if any QLI under these quotes has product code 27000002809
        System.debug('SMALL ORDER: Querying for special product code "27000002809"');
        Map<Id, Boolean> quoteHasSpecialProduct = new Map<Id, Boolean>();
        
        Integer recordCount = 0;
        for (AggregateResult ar : [
            SELECT QuoteId qId
            FROM QuoteLineItem
            WHERE QuoteId IN :quoteIds
            AND Product2.ProductCode = '27000002809'
            GROUP BY QuoteId
        ]) {
            Id quoteId = (Id)ar.get('qId');
            quoteHasSpecialProduct.put(quoteId, true);
            recordCount++;
            System.debug('  ✓ Quote has special product: ' + quoteId);
        }
        
        System.debug('SMALL ORDER: Found ' + recordCount + ' Quote(s) with special product code');
        System.debug('SMALL ORDER: Quotes with special product: ' + quoteHasSpecialProduct.keySet());
        
        System.debug('');
        System.debug('SMALL ORDER: Building Quote update list');
        List<Quote> quotesToUpdate = new List<Quote>();
        
        for (Id qId : quoteIds) {
            Boolean hasSpecialProduct = quoteHasSpecialProduct.containsKey(qId);
            
            System.debug('  Quote ID: ' + qId);
            System.debug('    Has special product: ' + hasSpecialProduct);
            System.debug('    Setting Is_Small_Order_Handling__c = ' + hasSpecialProduct);
            
            quotesToUpdate.add(new Quote(
                Id = qId,
                Is_Small_Order_Handling__c = hasSpecialProduct
            ));
        }
        
        System.debug('');
        System.debug('SMALL ORDER: Total Quotes to update: ' + quotesToUpdate.size());
        
        if (!quotesToUpdate.isEmpty()) {
            System.debug('SMALL ORDER: Performing update operation');
            try {
                update quotesToUpdate;
                System.debug('SMALL ORDER: ✓✓ Successfully updated ' + quotesToUpdate.size() + ' Quote(s)');
                
                // Log summary
                Integer trueCount = 0;
                Integer falseCount = 0;
                for (Quote q : quotesToUpdate) {
                    if (q.Is_Small_Order_Handling__c) {
                        trueCount++;
                    } else {
                        falseCount++;
                    }
                }
                System.debug('SMALL ORDER: Summary - Set to TRUE: ' + trueCount + ', Set to FALSE: ' + falseCount);
                
            } catch (Exception e) {
                System.debug('SMALL ORDER: ✗✗ ERROR updating Quotes: ' + e.getMessage());
                System.debug('SMALL ORDER: Error Type: ' + e.getTypeName());
                System.debug('SMALL ORDER: Stack Trace: ' + e.getStackTraceString());
            }
        } else {
            System.debug('SMALL ORDER: No Quotes to update (list is empty)');
        }
        
        System.debug('=== SMALL ORDER FLAG UPDATE END ===');
    }
}