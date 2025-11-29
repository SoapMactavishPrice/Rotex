trigger QuoteLineItemTrigger on QuoteLineItem (before insert, before update, after update, after insert, after delete) {
    
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        QuoteLineItemSequentialApprovalHandler.defineNextApprover(Trigger.new, Trigger.oldMap);
        
        Set<Id> quoteIds = new Set<Id>();
        List<QuoteLineItem> qliToProcess = new List<QuoteLineItem>();
        
        // Collect Quote IDs for new QLIs
        for (QuoteLineItem qli : Trigger.new) {
            if (qli.QuoteId != null) quoteIds.add(qli.QuoteId);
        }
        
        // Query parent Quotes
        Map<Id, Quote> quoteMap = new Map<Id, Quote>([
            SELECT Id, Sales_Rep__c, Sales_Manager__c,
            Country_Continent_Sales_Head_LOB_Head__c,
            Global_Sales_Head__c, Rotex_Board_Member__c,
            Managing_Director_Country_Manager__c
            FROM Quote WHERE Id IN :quoteIds
        ]);
        
        for (QuoteLineItem qli : Trigger.new) {
            
            // 1️⃣ Populate fields from parent Quote if blank (only for new QLI)
            if (Trigger.isInsert && quoteMap.containsKey(qli.QuoteId)) {
                Quote parentQuote = quoteMap.get(qli.QuoteId);
                
                if (qli.Sales_Rep__c == null) qli.Sales_Rep__c = parentQuote.Sales_Rep__c;
                if (qli.Sales_Manager__c == null) qli.Sales_Manager__c = parentQuote.Sales_Manager__c;
                if (qli.Country_Continent_Sales_Head_LOB_Head__c == null) qli.Country_Continent_Sales_Head_LOB_Head__c = parentQuote.Country_Continent_Sales_Head_LOB_Head__c;
                if (qli.Global_Sales_Head__c == null) qli.Global_Sales_Head__c = parentQuote.Global_Sales_Head__c;
                if (qli.Rotex_Board_Member__c == null) qli.Rotex_Board_Member__c = parentQuote.Rotex_Board_Member__c;
                if (qli.Managing_Director_Country_Manage__c == null) qli.Managing_Director_Country_Manage__c = parentQuote.Managing_Director_Country_Manager__c;
            }
            
            // 2️⃣ Determine which QLIs need approval processing
            if (Trigger.isInsert || (Trigger.isUpdate && qli.Discount_to_be_offered__c != Trigger.oldMap.get(qli.Id).Discount_to_be_offered__c)) {
                qliToProcess.add(qli);
            }
        }
        
        // 3️⃣ Call handler only for QLIs needing approval
        if (!qliToProcess.isEmpty()) {
            QuoteLineItemApprovalHandler.processApprovals(qliToProcess);
        }
    }
    
    if (Trigger.isAfter && Trigger.isUpdate) {
        QuoteLineItemSequentialApprovalHandler.processSequentialApprovals(Trigger.new);
    }
    
    Set<Id> quoteIds = new Set<Id>();
    
    if ( Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        for (QuoteLineItem qli : Trigger.new) {
            if (qli.QuoteId != null) {
                quoteIds.add(qli.QuoteId);
            }
        }
    }
    
    if (Trigger.isAfter && Trigger.isDelete) {
        for (QuoteLineItem qli : Trigger.old) {
            if (qli.QuoteId != null) {
                quoteIds.add(qli.QuoteId);
            }
        }
    }
    
    if (!quoteIds.isEmpty()) {
        QuoteLineItemHelper.updateSmallOrderFlag(quoteIds);
    } 
    
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        
        Set<Id> quoteIds = new Set<Id>();
        
        // Collect Quote Ids from new records
        for (QuoteLineItem qli : Trigger.new) {
            if (qli.QuoteId != null) {
                quoteIds.add(qli.QuoteId);
            }
        }
        
        // Query Quote with Customer State
        Map<Id, Quote> quoteMap = new Map<Id, Quote>(
            [SELECT Id, Customer_State__c FROM Quote WHERE Id IN :quoteIds]
        );
        
        for (Integer i = 0; i < Trigger.new.size(); i++) {
            
            QuoteLineItem newQLI = Trigger.new[i];
            QuoteLineItem oldQLI = Trigger.isUpdate ? Trigger.old[i] : null;
            Quote q = quoteMap.get(newQLI.QuoteId);
            
            if (q == null) continue;
            
            // Insert → Always apply tax logic
            // Update → Apply only when Quote Customer State changes
            Boolean shouldRecalculate = Trigger.isInsert ||
                (Trigger.isUpdate &&
                 q.Customer_State__c != null &&
                 (q.Customer_State__c != quoteMap.get(oldQLI.QuoteId).Customer_State__c));
            
            if (!shouldRecalculate) continue;
            
            // Reset fields
            newQLI.CGST__c = false;
            newQLI.SGST__c = false;
            newQLI.IGST__c = false;
            
            // Gujarat = CGST + SGST
            if (q.Customer_State__c == 'Gujarat') {
                newQLI.CGST__c = true;
                newQLI.SGST__c = true;
            } 
            // Other states = IGST
            else {
                newQLI.IGST__c = true;
            }
        }
        
    }
}