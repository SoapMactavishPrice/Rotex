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
    
    public static void updateUnitPriceBasedOnDiscount(List<QuoteLineItem> qliList) {
        System.debug('=== UPDATE UNIT PRICE BASED ON DISCOUNT START ===');
        System.debug('Processing ' + qliList.size() + ' QLIs');
        
        if (qliList.isEmpty()) {
            System.debug('UNIT PRICE: Empty list, exiting');
            return;
        }
        
        // Get QLI IDs to query full records
        Set<Id> qliIds = new Set<Id>();
        for (QuoteLineItem qli : qliList) {
            qliIds.add(qli.Id);
        }
        
        // Query QLIs with all necessary fields including PricebookEntry
        System.debug('UNIT PRICE: Querying QLIs with ListPrice from PricebookEntry');
        Map<Id, QuoteLineItem> fullQLIMap = new Map<Id, QuoteLineItem>([
            SELECT Id, UnitPrice, Discount_to_be_offered__c, 
                ListPrice, PricebookEntry.UnitPrice,
                Sales_Manager_Status__c, Country_Continent_Sales_H_LOB_Status__c,
                Global_Sales_Head_Status__c, Rotex_Board_Member_Status__c,
                Managing_Director_Status__c, Product2.Name
            FROM QuoteLineItem
            WHERE Id IN :qliIds
        ]);
        
        List<QuoteLineItem> qlisToUpdate = new List<QuoteLineItem>();
        
        for (QuoteLineItem qli : qliList) {
            QuoteLineItem fullQLI = fullQLIMap.get(qli.Id);
            
            if (fullQLI == null) {
                System.debug('UNIT PRICE: ERROR - QLI not found: ' + qli.Id);
                continue;
            }
            
            System.debug('');
            System.debug('--- UNIT PRICE: Processing QLI: ' + fullQLI.Id + ' ---');
            System.debug('Product: ' + (fullQLI.Product2 != null ? fullQLI.Product2.Name : 'N/A'));
            System.debug('Current UnitPrice: ' + fullQLI.UnitPrice);
            System.debug('Discount_to_be_offered__c: ' + fullQLI.Discount_to_be_offered__c);
            
            // Check if discount needs final approval (all required approvers have approved)
            Boolean isFinallyApproved = isFinalApprovalGranted(fullQLI);
            
            if (!isFinallyApproved) {
                System.debug('UNIT PRICE: Discount not yet fully approved, skipping');
                continue;
            }
            
            System.debug('UNIT PRICE: ✓ Discount is fully approved');
            
            // Get the base price (ListPrice or PricebookEntry UnitPrice)
            Decimal basePrice = fullQLI.ListPrice != null ? fullQLI.ListPrice : 
                            (fullQLI.PricebookEntry != null ? fullQLI.PricebookEntry.UnitPrice : null);
            
            if (basePrice == null || basePrice == 0) {
                System.debug('UNIT PRICE: ERROR - No valid base price found');
                continue;
            }
            
            System.debug('UNIT PRICE: Base Price (ListPrice): ' + basePrice);
            
            Decimal discountPercent = fullQLI.Discount_to_be_offered__c;
            
            // Calculate new UnitPrice: ListPrice * (1 - Discount%)
            Decimal newUnitPrice = basePrice * (1 - (discountPercent / 100));
            newUnitPrice = newUnitPrice.setScale(2);
            
            System.debug('UNIT PRICE: Calculation: ' + basePrice + ' * (1 - (' + discountPercent + '/100)) = ' + newUnitPrice);
            
            // Log price change impact
            Decimal priceChange = newUnitPrice - basePrice;
            if (priceChange > 0) {
                System.debug('UNIT PRICE: ⬆️ Price INCREASE from ' + basePrice + ' to ' + newUnitPrice);
            } else if (priceChange < 0) {
                System.debug('UNIT PRICE: ⬇️ Price DECREASE from ' + basePrice + ' to ' + newUnitPrice);
            }
            
            // ✅ Create update record - ONLY update UnitPrice
            QuoteLineItem qliToUpdate = new QuoteLineItem(
                Id = fullQLI.Id,
                UnitPrice = newUnitPrice
            );
            
            qlisToUpdate.add(qliToUpdate);
            System.debug('UNIT PRICE: ✓ Prepared update - New UnitPrice: ' + newUnitPrice);
        }
        
        System.debug('');
        System.debug('UNIT PRICE: Total QLIs to update: ' + qlisToUpdate.size());
        
        if (!qlisToUpdate.isEmpty()) {
            try {
                System.debug('UNIT PRICE: Performing update operation');
                update qlisToUpdate;
                System.debug('UNIT PRICE: ✓✓ Successfully updated ' + qlisToUpdate.size() + ' QLI(s)');
            } catch (Exception e) {
                System.debug('UNIT PRICE: ✗✗ ERROR updating QLIs: ' + e.getMessage());
                System.debug('UNIT PRICE: Stack Trace: ' + e.getStackTraceString());
            }
        } else {
            System.debug('UNIT PRICE: No QLIs to update');
        }
        
        System.debug('=== UPDATE UNIT PRICE BASED ON DISCOUNT END ===');
    }

    /**
     * Helper method to determine if discount has received final approval
     */
    private static Boolean isFinalApprovalGranted(QuoteLineItem qli) {
        System.debug('  → Checking final approval status');
        
        Decimal discount = qli.Discount_to_be_offered__c;
        if (discount == null) {
            System.debug('    Discount is null, returning false');
            return false;
        }
        
        // Determine which approver is the final one based on discount level
        // This logic should match your SOA Matrix ranges
        
        // If Managing Director approved, that's always final
        if (qli.Managing_Director_Status__c == 'Approved') {
            System.debug('    ✓ Managing Director approved (final)');
            return true;
        }
        
        // If Rotex Board Member approved and no MD status needed
        if (qli.Rotex_Board_Member_Status__c == 'Approved' && 
            (qli.Managing_Director_Status__c == null || qli.Managing_Director_Status__c == '')) {
            System.debug('    ✓ Rotex Board Member approved and no MD needed (final)');
            return true;
        }
        
        // If Global Sales Head approved and no higher approval needed
        if (qli.Global_Sales_Head_Status__c == 'Approved' && 
            (qli.Rotex_Board_Member_Status__c == null || qli.Rotex_Board_Member_Status__c == '') &&
            (qli.Managing_Director_Status__c == null || qli.Managing_Director_Status__c == '')) {
            System.debug('    ✓ Global Sales Head approved and no higher approval needed (final)');
            return true;
        }
        
        // If Country/Continent Head approved and no higher approval needed
        if (qli.Country_Continent_Sales_H_LOB_Status__c == 'Approved' && 
            (qli.Global_Sales_Head_Status__c == null || qli.Global_Sales_Head_Status__c == '') &&
            (qli.Rotex_Board_Member_Status__c == null || qli.Rotex_Board_Member_Status__c == '') &&
            (qli.Managing_Director_Status__c == null || qli.Managing_Director_Status__c == '')) {
            System.debug('    ✓ Country/Continent Head approved and no higher approval needed (final)');
            return true;
        }
        
        // If Sales Manager approved and no higher approval needed
        if (qli.Sales_Manager_Status__c == 'Approved' && 
            (qli.Country_Continent_Sales_H_LOB_Status__c == null || qli.Country_Continent_Sales_H_LOB_Status__c == '') &&
            (qli.Global_Sales_Head_Status__c == null || qli.Global_Sales_Head_Status__c == '') &&
            (qli.Rotex_Board_Member_Status__c == null || qli.Rotex_Board_Member_Status__c == '') &&
            (qli.Managing_Director_Status__c == null || qli.Managing_Director_Status__c == '')) {
            System.debug('    ✓ Sales Manager approved and no higher approval needed (final)');
            return true;
        }
        
        System.debug('    ✗ No final approval found');
        return false;
    }


}