trigger QuoteRevisionTrigger on Quote (before update) {
    
    for (Quote q : Trigger.new) {
        
        // If Total_GST_Amount__c has a value, copy it into Tax
        if (q.Total_GST_Amount__c != null) {
            q.Tax = q.Total_GST_Amount__c;
        }
    }
    
    
    // Track which quotes have field changes
    Set<Id> quoteFieldChangedIds = new Set<Id>();
    Set<Id> qliFieldChangedIds = new Set<Id>();
    
    // *************** TRACK QUOTE FIELDS ***************
    List<String> quoteFieldsToTrack = new List<String>{
        'Quote_Valid_Till__c',
            'ExpirationDate',
            'Transaction_Type__c',
            'Commission_Type__c',
            'Commission_Value__c',
            'Shipment__c',
            'Delivery_Location__c',
            'Transport_Details__c',
            'Liquidate_Terms__c',
            'Delivery_Period__c',
            'Validity_of_Offer__c',
            'Warranty_Terms__c',
            'Payment_Terms__c',
            'INCO_Terms__c',
            'Other_Terms_Conditions__c',
            'Special_Remarks__c'   
            };
                
                for(Quote newQ : Trigger.new){
                    Quote oldQ = Trigger.oldMap.get(newQ.Id);
                    
                    for(String f : quoteFieldsToTrack){
                        if(
                            (oldQ.get(f) == null && newQ.get(f) != null) ||
                            (oldQ.get(f) != null && newQ.get(f) != oldQ.get(f))
                        ){
                            quoteFieldChangedIds.add(newQ.Id);
                            break;
                        }
                    }
                }
    
    // If no quote values changed, we still need to check QLI
    Set<Id> allQuoteIds = new Set<Id>(Trigger.newMap.keySet());
    
    // *************** TRACK QUOTE LINE ITEM FIELDS ***************
    List<String> qliFieldsToTrack = new List<String>{
        'Quantity',
            'UnitPrice',
            'Discount_to_be_offered__c'
            };
                
                // Load QLI old and new values
                Map<Id, QuoteLineItem> oldQLIMap = new Map<Id, QuoteLineItem>(
                    [SELECT Id, QuoteId, Quantity, UnitPrice, Discount_to_be_offered__c
                     FROM QuoteLineItem
                     WHERE QuoteId IN :allQuoteIds]
                );
    
    List<QuoteLineItem> newQLIs = [
        SELECT Id, QuoteId, Quantity, UnitPrice, Discount_to_be_offered__c 
        FROM QuoteLineItem
        WHERE QuoteId IN :allQuoteIds
    ];
    
    for(QuoteLineItem newLine : newQLIs){
        QuoteLineItem oldLine = oldQLIMap.get(newLine.Id);
        
        if(oldLine == null) continue; // new record case
        
        for(String f : qliFieldsToTrack){
            if(
                (oldLine.get(f) == null && newLine.get(f) != null) ||
                (oldLine.get(f) != null && oldLine.get(f) != newLine.get(f))
            ){
                qliFieldChangedIds.add(newLine.QuoteId);
                break;
            }
        }
    }
    
    // *************** FINAL UPDATE RULE ***************
    // *************** FINAL UPDATE RULE ***************
    for(Quote q : Trigger.new){
        Quote oldQ = Trigger.oldMap.get(q.Id);
        
        Boolean quoteChanged = quoteFieldChangedIds.contains(q.Id);
        // Boolean lineChanged = qliFieldChangedIds.contains(q.Id);
        
        // Treat NULL revision as 0
        Integer oldRevision = (oldQ.Rev_No__c == null ? 0 : Integer.valueOf(oldQ.Rev_No__c));
        Integer newRevision = (q.Rev_No__c == null ? 0 : Integer.valueOf(q.Rev_No__c));
        
        // Increase only if actual field changed & revision not already incremented
        Boolean lineChanged = qliFieldChangedIds.contains(q.Id) || q.Qli_Updated_Flag__c;
        
        if((quoteChanged || lineChanged) && newRevision == oldRevision){
            q.Rev_No__c = oldRevision + 1;
            q.Rev_Date__c = system.today();
        }
        
        // Reset flag
        q.Qli_Updated_Flag__c = false;
        
    }
    
}