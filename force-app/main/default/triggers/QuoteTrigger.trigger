trigger QuoteTrigger on Quote (after insert, before update) {
    
    // AFTER INSERT
    if (Trigger.isAfter && Trigger.isInsert) {
        
        List<Quote> quotesToUpdate = new List<Quote>();
        
        for (Quote q : Trigger.new) {
            
            if (q.Quote_Validity_Extension__c == 'Yes') {
                
                Quote qUpdate = new Quote();
                qUpdate.Id = q.Id;
                qUpdate.OwnerId = q.CreatedById;
                
                quotesToUpdate.add(qUpdate);
            }
        }
        
        if (!quotesToUpdate.isEmpty()) {
            update quotesToUpdate;
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
    }
}