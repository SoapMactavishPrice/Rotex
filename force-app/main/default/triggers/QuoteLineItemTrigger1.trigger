trigger QuoteLineItemTrigger1 on QuoteLineItem (before update) {

    for (QuoteLineItem newLine : Trigger.new) {

        QuoteLineItem oldLine = Trigger.oldMap.get(newLine.Id);
        if (oldLine == null) continue;

        String changedField;

        // 🔥 detect EXACT field change
        if (newLine.Quantity != oldLine.Quantity) {
            changedField = 'QuoteLineItem Quantity';
        }
        else if (newLine.UnitPrice != oldLine.UnitPrice) {
            changedField = 'QuoteLineItem UnitPrice';
        }
        else if (newLine.Discount_to_be_offered__c != oldLine.Discount_to_be_offered__c) {
            changedField = 'QuoteLineItem Discount_to_be_offered__c';
        }

        if (changedField != null) {
            QuoteChangeTracker.qliFieldByQuoteId.put(newLine.QuoteId, changedField);
        }
    }
}