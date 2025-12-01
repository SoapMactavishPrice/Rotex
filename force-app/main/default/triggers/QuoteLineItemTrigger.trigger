trigger QuoteLineItemTrigger on QuoteLineItem (before insert, before update, after update, after insert, after delete) {
    
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        System.debug('=== APPROVAL PROCESS: BEFORE TRIGGER START ===');
        System.debug('Trigger Context: ' + (Trigger.isInsert ? 'INSERT' : 'UPDATE'));
        System.debug('Number of QLIs: ' + Trigger.new.size());
        
        QuoteLineItemSequentialApprovalHandler.defineNextApprover(Trigger.new, Trigger.oldMap);
        
        Set<Id> quoteIds = new Set<Id>();
        List<QuoteLineItem> qliToProcess = new List<QuoteLineItem>();
        
        // Collect Quote IDs for new QLIs
        for (QuoteLineItem qli : Trigger.new) {
            if (qli.QuoteId != null) quoteIds.add(qli.QuoteId);
        }
        System.debug('Collected Quote IDs: ' + quoteIds);
        
        // Query parent Quotes
        Map<Id, Quote> quoteMap = new Map<Id, Quote>([
            SELECT Id, Sales_Rep__c, Sales_Manager__c,
            Country_Continent_Sales_Head_LOB_Head__c,
            Global_Sales_Head__c, Rotex_Board_Member__c,
            Managing_Director_Country_Manager__c
            FROM Quote WHERE Id IN :quoteIds
        ]);
        System.debug('Queried ' + quoteMap.size() + ' parent Quotes');
        
        for (QuoteLineItem qli : Trigger.new) {
            System.debug('--- Processing QLI ID: ' + qli.Id);
            
            // 1️⃣ Populate fields from parent Quote if blank (only for new QLI)
            if (Trigger.isInsert && quoteMap.containsKey(qli.QuoteId)) {
                System.debug('APPROVAL: Populating approver fields from parent Quote');
                Quote parentQuote = quoteMap.get(qli.QuoteId);
                
                if (qli.Sales_Rep__c == null) {
                    qli.Sales_Rep__c = parentQuote.Sales_Rep__c;
                    System.debug('Set Sales_Rep__c: ' + qli.Sales_Rep__c);
                }
                if (qli.Sales_Manager__c == null) {
                    qli.Sales_Manager__c = parentQuote.Sales_Manager__c;
                    System.debug('Set Sales_Manager__c: ' + qli.Sales_Manager__c);
                }
                if (qli.Country_Continent_Sales_Head_LOB_Head__c == null) {
                    qli.Country_Continent_Sales_Head_LOB_Head__c = parentQuote.Country_Continent_Sales_Head_LOB_Head__c;
                    System.debug('Set Country_Continent_Sales_Head_LOB_Head__c: ' + qli.Country_Continent_Sales_Head_LOB_Head__c);
                }
                if (qli.Global_Sales_Head__c == null) {
                    qli.Global_Sales_Head__c = parentQuote.Global_Sales_Head__c;
                    System.debug('Set Global_Sales_Head__c: ' + qli.Global_Sales_Head__c);
                }
                if (qli.Rotex_Board_Member__c == null) {
                    qli.Rotex_Board_Member__c = parentQuote.Rotex_Board_Member__c;
                    System.debug('Set Rotex_Board_Member__c: ' + qli.Rotex_Board_Member__c);
                }
                if (qli.Managing_Director_Country_Manage__c == null) {
                    qli.Managing_Director_Country_Manage__c = parentQuote.Managing_Director_Country_Manager__c;
                    System.debug('Set Managing_Director_Country_Manage__c: ' + qli.Managing_Director_Country_Manage__c);
                }
            }
            
            // 2️⃣ Determine which QLIs need approval processing
            if (Trigger.isInsert || (Trigger.isUpdate && qli.Discount_to_be_offered__c != Trigger.oldMap.get(qli.Id).Discount_to_be_offered__c)) {
                System.debug('APPROVAL: QLI needs approval processing');
                System.debug('Discount_to_be_offered__c: ' + qli.Discount_to_be_offered__c);
                if (Trigger.isUpdate) {
                    System.debug('Old Discount: ' + Trigger.oldMap.get(qli.Id).Discount_to_be_offered__c);
                }
                qliToProcess.add(qli);
            } else {
                System.debug('APPROVAL: QLI does NOT need approval processing (discount unchanged)');
            }
        }
        
        // 3️⃣ Call handler only for QLIs needing approval
        if (!qliToProcess.isEmpty()) {
            System.debug('=== APPROVAL: Calling QuoteLineItemApprovalHandler.processApprovals ===');
            System.debug('Number of QLIs to process: ' + qliToProcess.size());
            QuoteLineItemApprovalHandler.processApprovals(qliToProcess);
        } else {
            System.debug('=== APPROVAL: No QLIs need approval processing ===');
        }
        
        System.debug('=== APPROVAL PROCESS: BEFORE TRIGGER END ===');
    }
    
    if (Trigger.isAfter && Trigger.isUpdate) {
        System.debug('=== APPROVAL PROCESS: AFTER UPDATE TRIGGER START ===');
        System.debug('Calling Sequential Approval Handler');
        QuoteLineItemSequentialApprovalHandler.processSequentialApprovals(Trigger.new);
        System.debug('=== APPROVAL PROCESS: AFTER UPDATE TRIGGER END ===');
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