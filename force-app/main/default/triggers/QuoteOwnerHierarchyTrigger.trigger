trigger QuoteOwnerHierarchyTrigger on Quote (before insert, before update, after update) {
    
    if (Trigger.isBefore) {
        QuoteHierarchyHandler.updateQuoteHierarchy(Trigger.new, Trigger.oldMap);
    }
    
    if (Trigger.isAfter && Trigger.isUpdate) {
        Map<Id, Quote> quotesByOpportunityId = new Map<Id, Quote>();
        
        for (Quote quote : Trigger.new) {
            Quote oldQuote = Trigger.oldMap.get(quote.Id);
            
            if (quote.OpportunityId != null && quote.OwnerId != oldQuote.OwnerId) {
                quotesByOpportunityId.put(quote.OpportunityId, quote);
            }
        }
        
        if (quotesByOpportunityId.isEmpty()) {
            return;
        }
        
        List<Opportunity> opportunities = new List<Opportunity>();
        for (Id opportunityId : quotesByOpportunityId.keySet()) {
            opportunities.add(new Opportunity(
                Id = opportunityId,
                OwnerId = quotesByOpportunityId.get(opportunityId).OwnerId
            ));
        }
        
        update opportunities;
    }
}
