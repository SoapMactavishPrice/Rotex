trigger QuoteTrigger on Quote (before insert, before update, after insert) {
    System.debug('In QuoteTrigger');

    // BEFORE INSERT
    if (Trigger.isBefore && Trigger.isInsert) {
        System.debug('In BEFORE INSERT of QuoteTrigger');
        for (Quote q : Trigger.new) {
            q.Warranty_Terms__c = '12 Months from date of supply';
            q.Warranty_Terms_Draft__c = '12 Months from date of supply';
        }
    }
    
    if (Trigger.isAfter && Trigger.isInsert) {
        QuoteTotalValueApprovalHandler.handleAfterInsert(Trigger.new);
        QuoteMinimumOfferValueApprovalHandler.handleAfterInsert(Trigger.new);
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
        
        // Handle validity of offer approval process for quote updates
        QuoteValidityOfferApprovalHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);

        // Handle total value approval process for quote updates
        QuoteTotalValueApprovalHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);

        // Handle minimum offer value approval process for quote updates
        QuoteMinimumOfferValueApprovalHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
}