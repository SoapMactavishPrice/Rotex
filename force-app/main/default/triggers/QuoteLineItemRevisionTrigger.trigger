trigger QuoteLineItemRevisionTrigger on QuoteLineItem (after update) {

    Set<Id> changedQuoteIds = new Set<Id>();

    List<String> qliFieldsToTrack = new List<String>{
        'Quantity',
        'UnitPrice',
        'Discount_to_be_offered__c'
    };

    for (QuoteLineItem newRec : Trigger.new) {
        QuoteLineItem oldRec = Trigger.oldMap.get(newRec.Id);

        for(String f : qliFieldsToTrack){
            if(
                (oldRec.get(f) == null && newRec.get(f) != null) ||
                (oldRec.get(f) != null && newRec.get(f) != oldRec.get(f))
            ){
                changedQuoteIds.add(newRec.QuoteId);
                break;
            }
        }
    }

    if(!changedQuoteIds.isEmpty()){
        List<Quote> quotesToUpdate = [
            SELECT Id, QLI_Updated_Flag__c 
            FROM Quote 
            WHERE Id IN :changedQuoteIds
        ];

        for(Quote q : quotesToUpdate){
            q.QLI_Updated_Flag__c = true;
        }
        update quotesToUpdate;
    }
}