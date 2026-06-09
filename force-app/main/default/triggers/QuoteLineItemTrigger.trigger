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
            System.debug('Trigger.isInsert ==> ' + Trigger.isInsert + ', Trigger.isUpdate ==> ' + Trigger.isUpdate + ', Discount_to_be_offered__c: ' + qli.Discount_to_be_offered__c + ', Old Discount: ' + (Trigger.isUpdate ? Trigger.oldMap.get(qli.Id).Discount_to_be_offered__c : null) + ', qli.Is_Edited_Through_Edit_Discount__c && qli.Is_Discount_Only_Rejected__c: ' + (qli.Is_Edited_Through_Edit_Discount__c && qli.Is_Discount_Only_Rejected_Static__c) + ', Do_not_proceed_approval__c: ' + qli.Do_not_proceed_approval__c);
            if (Trigger.isInsert || (Trigger.isUpdate && qli.Discount_to_be_offered__c != null && (qli.Discount_to_be_offered__c != Trigger.oldMap.get(qli.Id).Discount_to_be_offered__c || (qli.Is_Edited_Through_Edit_Discount__c && qli.Is_Discount_Only_Rejected_Static__c)) && !qli.Do_not_proceed_approval__c)) {
                System.debug('APPROVAL: QLI needs approval processing');
                System.debug('Discount_to_be_offered__c: ' + qli.Discount_to_be_offered__c);
                if (Trigger.isUpdate) {
                    System.debug('Old Discount: ' + Trigger.oldMap.get(qli.Id).Discount_to_be_offered__c);
                }
                // Blank the approval status fields for re-processing 
                qli.Is_Edited_Through_Edit_Discount__c = false;

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
        QuoteLineItemSequentialApprovalHandler.processSequentialApprovals(Trigger.new, Trigger.oldMap);
        System.debug('=== APPROVAL PROCESS: AFTER UPDATE TRIGGER END ===');
        if (!QuoteLineItemApprovalHandler.directDiscountUpdateInProgress) {
            QuoteLineItemApprovalHandler.applyDirectDiscountIfNoApprovalNeeded(Trigger.new, Trigger.oldMap);
        }
    }

    // ── AFTER INSERT: Apply Discount_to_be_offered__c to UnitPrice on creation ──────
    if (Trigger.isAfter && Trigger.isInsert) {
        Set<Id> insertedIds = new Set<Id>();
        for (QuoteLineItem qli : Trigger.new) {
            if (qli.Id != null) insertedIds.add(qli.Id);
        }

        if (!insertedIds.isEmpty()) {
            // Re-query so formula field Discount_to_be_offered__c is freshly calculated
            List<QuoteLineItem> freshInserted = [
                SELECT Id, ListPrice, Discount_to_be_offered__c, Item_Type__c
                FROM QuoteLineItem
                WHERE Id IN :insertedIds
            ];

            List<QuoteLineItem> toUpdate = new List<QuoteLineItem>();
            for (QuoteLineItem fresh : freshInserted) {
                if (fresh.ListPrice == null || fresh.ListPrice == 0 || fresh.Item_Type__c == 'ARC') continue;
                // Use 0% if Discount_to_be_offered__c is blank → UnitPrice = ListPrice
                Decimal disc = (fresh.Discount_to_be_offered__c != null) ? fresh.Discount_to_be_offered__c : 0;
                Decimal newUnitPrice = (fresh.ListPrice * (1 - disc / 100)).setScale(2);
                System.debug('INSERT DISCOUNT: QLI ' + fresh.Id +
                    ' → disc=' + disc + '%, UnitPrice=' + newUnitPrice);
                toUpdate.add(new QuoteLineItem(Id = fresh.Id, UnitPrice = newUnitPrice));
            }

            if (!toUpdate.isEmpty()) {
                update toUpdate;
                System.debug('INSERT DISCOUNT: Applied Discount_to_be_offered__c to UnitPrice for ' +
                    toUpdate.size() + ' QLI(s)');
            }
        }
    }
    // ─────────────────────────────────────────────────────────────────────────────
    
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

    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        System.debug('=== NEGATIVE DISCOUNT DIRECT PRICE UPDATE START ===');
        
        Set<Id> qliIds = new Set<Id>();
        for (QuoteLineItem qli : Trigger.new) {
            if (qli.Id != null) {
                qliIds.add(qli.Id);
            }
        }
        
        // Query full QLI details if needed (for updates)
        Map<Id, QuoteLineItem> existingQLIMap = new Map<Id, QuoteLineItem>();
        if (!qliIds.isEmpty()) {
            existingQLIMap = new Map<Id, QuoteLineItem>([
                SELECT Id, Discount_to_be_offered__c, ListPrice, PricebookEntry.UnitPrice
                FROM QuoteLineItem
                WHERE Id IN :qliIds
            ]);
        }
        
        for (QuoteLineItem qli : Trigger.new) {
            QuoteLineItem oldQLI = Trigger.isUpdate ? Trigger.oldMap.get(qli.Id) : null;
            
            // Check if Discount_to_be_offered__c changed or is being set
            Boolean discountChanged = Trigger.isInsert || 
                (Trigger.isUpdate && qli.Discount_to_be_offered__c != oldQLI.Discount_to_be_offered__c);
            
            if (!discountChanged || qli.Discount_to_be_offered__c == null) {
                continue;
            }
            
            System.debug('--- Processing QLI: ' + qli.Id + ' ---');
            System.debug('Discount_to_be_offered__c: ' + qli.Discount_to_be_offered__c);
            
            // ✅ Check if discount is NEGATIVE (markup)
            if (qli.Discount_to_be_offered__c < 0) {
                System.debug('✓ NEGATIVE DISCOUNT DETECTED: ' + qli.Discount_to_be_offered__c + '%');
                System.debug('NEGATIVE DISCOUNT: No approval needed, directly updating UnitPrice');
                
                // Get base price
                Decimal basePrice = qli.ListPrice;
                
                // For updates, query from database if ListPrice not in trigger context
                if (basePrice == null && Trigger.isUpdate && existingQLIMap.containsKey(qli.Id)) {
                    QuoteLineItem existingQLI = existingQLIMap.get(qli.Id);
                    basePrice = existingQLI.ListPrice != null ? existingQLI.ListPrice :
                            (existingQLI.PricebookEntry != null ? existingQLI.PricebookEntry.UnitPrice : null);
                }
                
                if (basePrice == null || basePrice == 0) {
                    System.debug('NEGATIVE DISCOUNT: ERROR - No valid base price found');
                    continue;
                }
                
                System.debug('NEGATIVE DISCOUNT: Base Price: ' + basePrice);
                
                // Calculate new UnitPrice with markup
                Decimal discountPercent = qli.Discount_to_be_offered__c;
                Decimal newUnitPrice = basePrice * (1 - (discountPercent / 100));
                newUnitPrice = newUnitPrice.setScale(2);
                
                System.debug('NEGATIVE DISCOUNT: Calculation: ' + basePrice + ' * (1 - (' + discountPercent + '/100)) = ' + newUnitPrice);
                System.debug('NEGATIVE DISCOUNT: Price INCREASE from ' + basePrice + ' to ' + newUnitPrice);
                
                // ✅ ONLY update UnitPrice (NOT the standard Discount field)
                qli.UnitPrice = newUnitPrice;
                
                System.debug('NEGATIVE DISCOUNT: ✓✓ UnitPrice updated directly to ' + newUnitPrice);
                
                // ✅ Clear all approval status fields (no approval needed)
                if (!qli.Do_not_proceed_approval__c) {
                    qli.Sales_Manager_Status__c = null;
                    qli.Country_Continent_Sales_H_LOB_Status__c = null;
                    qli.Global_Sales_Head_Status__c = null;
                    qli.Rotex_Board_Member_Status__c = null;
                    qli.Managing_Director_Status__c = null;
                }
                
                System.debug('NEGATIVE DISCOUNT: ✓ All approval status fields cleared');
            } else {
                System.debug('Positive discount: ' + qli.Discount_to_be_offered__c + '% - Normal approval flow will apply');
            }
        }
        
        System.debug('=== NEGATIVE DISCOUNT DIRECT PRICE UPDATE END ===');
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        System.debug('=== UNIT PRICE UPDATE: AFTER UPDATE TRIGGER START ===');
        
        List<QuoteLineItem> qlisToUpdatePrice = new List<QuoteLineItem>();
        
        for (QuoteLineItem qli : Trigger.new) {
            QuoteLineItem oldQLI = Trigger.oldMap.get(qli.Id);
            
            // Check if any approval status just changed to 'Approved'
            Boolean approvalJustGranted = (
                (qli.Sales_Manager_Status__c == 'Approved' && oldQLI.Sales_Manager_Status__c != 'Approved') ||
                (qli.Country_Continent_Sales_H_LOB_Status__c == 'Approved' && oldQLI.Country_Continent_Sales_H_LOB_Status__c != 'Approved') ||
                (qli.Global_Sales_Head_Status__c == 'Approved' && oldQLI.Global_Sales_Head_Status__c != 'Approved') ||
                (qli.Rotex_Board_Member_Status__c == 'Approved' && oldQLI.Rotex_Board_Member_Status__c != 'Approved') ||
                (qli.Managing_Director_Status__c == 'Approved' && oldQLI.Managing_Director_Status__c != 'Approved')
            );
            
            if (approvalJustGranted && qli.Discount_to_be_offered__c != null) {
                qlisToUpdatePrice.add(qli);
            }
        }
        
        if (!qlisToUpdatePrice.isEmpty()) {
            System.debug('UNIT PRICE UPDATE: Calling handler to recalculate prices for ' + qlisToUpdatePrice.size() + ' QLIs');
            QuoteLineItemHelper.updateUnitPriceBasedOnDiscount(qlisToUpdatePrice);
        }
        
        System.debug('=== UNIT PRICE UPDATE: AFTER UPDATE TRIGGER END ===');
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        QuoteFinalApprovalNotificationHandler.handleQuoteLineItemsAfterUpdate(Trigger.new, Trigger.oldMap);
        QuoteLineItemApprovalHandler.updateQLIUnitPrice(Trigger.new);
    }
}