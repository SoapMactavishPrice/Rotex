trigger QuoteRevisionTrigger on Quote (before update) {

    /* ---------------- TAX COPY ---------------- */
    for (Quote q : Trigger.new) {
        if (q.Total_GST_Amount__c != null) {
            q.Tax = q.Total_GST_Amount__c;
        }
    }

    /* ---------------- TRACK CHANGES ---------------- */
    Set<Id> quoteFieldChangedIds = new Set<Id>();
    Set<Id> qliFieldChangedIds   = new Set<Id>();
    Map<Id, String> quoteChangedFieldMap = new Map<Id, String>();
    /* --------- QUOTE FIELDS TO TRACK --------- */
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

    /* --------- QUOTE FIELD CHANGE CHECK --------- */
    for (Quote newQ : Trigger.new) {
        Quote oldQ = Trigger.oldMap.get(newQ.Id);

        for (String f : quoteFieldsToTrack) {
            Object oldVal = oldQ.get(f);
            Object newVal = newQ.get(f);

            // ✅ ONLY real change (NOT null → value)
            if (oldVal != null && newVal != null && oldVal != newVal) {
                quoteFieldChangedIds.add(newQ.Id);
                quoteChangedFieldMap.put(newQ.Id, f); // 🔥 store field name
                break;
            }
        }
    }

    /* --------- QUOTE LINE ITEM TRACKING --------- */
    Set<Id> quoteIds = Trigger.newMap.keySet();

    List<String> qliFieldsToTrack = new List<String>{
        'Quantity',
        'UnitPrice',
        'Discount_to_be_offered__c'
    };

    Map<Id, QuoteLineItem> oldQLIMap = new Map<Id, QuoteLineItem>(
        [SELECT Id, QuoteId, Quantity, UnitPrice, Discount_to_be_offered__c
         FROM QuoteLineItem
         WHERE QuoteId IN :quoteIds]
    );

    List<QuoteLineItem> newQLIs = [
        SELECT Id, QuoteId, Quantity, UnitPrice, Discount_to_be_offered__c
        FROM QuoteLineItem
        WHERE QuoteId IN :quoteIds
    ];

    for (QuoteLineItem newLine : newQLIs) {
        QuoteLineItem oldLine = oldQLIMap.get(newLine.Id);
        if (oldLine == null) continue;

        for (String f : qliFieldsToTrack) {
            Object oldVal = oldLine.get(f);
            Object newVal = newLine.get(f);

            // ✅ ONLY real change (NOT null → value)
            if (oldVal != null && newVal != null && oldVal != newVal) {
                qliFieldChangedIds.add(newLine.QuoteId);
                
                // 🔥 store QLI field name also
                if (!quoteChangedFieldMap.containsKey(newLine.QuoteId)) {
                    quoteChangedFieldMap.put(
                        newLine.QuoteId,
                        'QuoteLineItem ' + f
                    );
                }
                break;
            }
        }
    }
    /* ---------------- FINAL REVISION UPDATE ---------------- */
    for (Quote q : Trigger.new) {
        Quote oldQ = Trigger.oldMap.get(q.Id);

        Boolean quoteChanged = quoteFieldChangedIds.contains(q.Id);
        Boolean lineChanged  = qliFieldChangedIds.contains(q.Id) || q.Qli_Updated_Flag__c;

        Integer oldRevision = oldQ.Rev_No__c == null ? 0 : oldQ.Rev_No__c.intValue();
        Integer newRevision = q.Rev_No__c == null ? 0 : q.Rev_No__c.intValue();

        // ✅ Increase ONLY once per real change
        if ((quoteChanged || lineChanged) && newRevision == oldRevision) {
            
            Integer updatedRev = oldRevision + 1;
            Datetime nowDT = System.now();
            Date todayDate = nowDT.date();
            
            q.Rev_No__c  = updatedRev;
            q.Rev_Date__c = todayDate;
            
            // 🔥 GET FIELD NAME
            String changedField;
            
            if (quoteChangedFieldMap.containsKey(q.Id)) {
                changedField = 'Quote: ' + quoteChangedFieldMap.get(q.Id);
            }
            else if (QuoteChangeTracker.qliFieldByQuoteId.containsKey(q.Id)) {
                
                String qliField = QuoteChangeTracker.qliFieldByQuoteId.get(q.Id);
                
                // remove "QuoteLineItem " prefix
                String fieldOnly = qliField.replace('QuoteLineItem ', '');
                
                changedField = 'QuoteLineItem : ' + fieldOnly;
            }
            else {
                changedField = 'Unknown';
            }
            
            // 🔥 FORMAT DATE
            String formattedDateTime = nowDT.format('dd-MM-yyyy HH:mm:ss');
            
            // 🔥 CREATE ENTRY
            String newEntry = 'Rev No: ' + updatedRev + ' Date Time: ' + formattedDateTime + ' ' + changedField;
            
            // 🔥 APPEND HISTORY
            if (oldQ.Rev_History_Tracking__c != null) {
                q.Rev_History_Tracking__c = oldQ.Rev_History_Tracking__c + '\n' + newEntry;
            } else {
                q.Rev_History_Tracking__c = newEntry;
            }
        }
        // ✅ reset flag
        q.Qli_Updated_Flag__c = false;
    }
}