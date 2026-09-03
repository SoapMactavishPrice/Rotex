public class QuoteLineItemHandler {
    
    private static Set<Id> hierarchyFromQuoteProcessedIds = new Set<Id>();

    public static void updateHierarchyFromQuote(List<QuoteLineItem> newList) {
        
        if (QuoteLineItemHandlerControl.isRunning) {
            return;
        }
        
        QuoteLineItemHandlerControl.isRunning = true;
        
        try {

        // Existing code stays exactly the same
        
        // 🔹 1. Collect Quote Ids not already processed this transaction
        Set<Id> quoteIds = new Set<Id>();
        for (QuoteLineItem qli : newList) {
            if (qli.QuoteId != null && !hierarchyFromQuoteProcessedIds.contains(qli.QuoteId)) {
                quoteIds.add(qli.QuoteId);
            }
        }
        
        if (quoteIds.isEmpty()) return;

        hierarchyFromQuoteProcessedIds.addAll(quoteIds);
        
        // 🔹 2. Fetch Quotes with hierarchy fields
        Map<Id, Quote> quoteMap = new Map<Id, Quote>(
            [SELECT Id,
             Sales_Rep__c, 
             Sales_Manager__c,
             Country_Continent_Sales_Head_LOB_Head__c,
             Global_Sales_Head__c,
             Rotex_Board_Member__c,
             Managing_Director_Country_Manager__c
             FROM Quote
             WHERE Id IN :quoteIds]
        );
        
        // 🔹 3. Prepare updates (only when needed)
        List<QuoteLineItem> qliToUpdate = new List<QuoteLineItem>();
        
        for (QuoteLineItem qli : newList) {
            
            Quote q = quoteMap.get(qli.QuoteId);
            if (q == null) continue;
            
            Boolean isChanged = false;
            
            QuoteLineItem qliUpd = new QuoteLineItem(Id = qli.Id);
            
            if (qli.Sales_Rep__c != q.Sales_Rep__c) {
                qliUpd.Sales_Rep__c = q.Sales_Rep__c;
                isChanged = true;
            }
            
            if (qli.Sales_Manager__c != q.Sales_Manager__c) {
                qliUpd.Sales_Manager__c = q.Sales_Manager__c;
                isChanged = true;
            }
            
            if (qli.Country_Continent_Sales_Head_LOB_Head__c != q.Country_Continent_Sales_Head_LOB_Head__c) {
                qliUpd.Country_Continent_Sales_Head_LOB_Head__c = q.Country_Continent_Sales_Head_LOB_Head__c;
                isChanged = true;
            }
            
            if (qli.Global_Sales_Head__c != q.Global_Sales_Head__c) {
                qliUpd.Global_Sales_Head__c = q.Global_Sales_Head__c;
                isChanged = true;
            }
            
            if (qli.Rotex_Board_Member__c != q.Rotex_Board_Member__c) {
                qliUpd.Rotex_Board_Member__c = q.Rotex_Board_Member__c;
                isChanged = true;
            }
            
            if (qli.Managing_Director_Country_Manage__c != q.Managing_Director_Country_Manager__c) {
                qliUpd.Managing_Director_Country_Manage__c = q.Managing_Director_Country_Manager__c;
                isChanged = true;
            }
            
            if (isChanged) {
                qliToUpdate.add(qliUpd);
            }
        }
        
        // 🔹 4. Update only if needed
        if (!qliToUpdate.isEmpty()) {
            update qliToUpdate;
        }
        } finally {
            QuoteLineItemHandlerControl.isRunning = false;
        }    
    }
}