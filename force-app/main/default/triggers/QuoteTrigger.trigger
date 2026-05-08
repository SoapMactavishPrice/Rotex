trigger QuoteTrigger on Quote (before insert, before update) {
    System.debug('In QuoteTrigger');

    // BEFORE INSERT
    if (Trigger.isBefore && Trigger.isInsert) {
        System.debug('In BEFORE INSERT of QuoteTrigger');
        List<Quote> quotesToUpdate = new List<Quote>();
        
        for (Quote q : Trigger.new) {
            q.Warranty_Terms__c = '12 Months from date of supply';
            q.Warranty_Terms_Draft__c = '12 Months from date of supply';
        }
        
    }
    
    // BEFORE UPDATE
    if (Trigger.isBefore && Trigger.isUpdate) {
        
        for (Quote q : Trigger.new) {
            
            Quote oldQuote = Trigger.oldMap.get(q.Id);
            
            if (q.Quote_Validity_Extension__c == 'Yes' &&
                oldQuote.Quote_Validity_Extension__c != 'Yes') {
                    
                    q.OwnerId = q.CreatedById;
                }
            
            if (q.Quote_Validity_Extension__c == 'No' &&
                String.isBlank(q.Remark__c)) {
                    
                    q.addError('Remarks are required when Quote Validity Extension is No.');
                }
        }
        
        // Handle warranty approval process for quote updates
        QuoteWarrantyApprovalHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
}