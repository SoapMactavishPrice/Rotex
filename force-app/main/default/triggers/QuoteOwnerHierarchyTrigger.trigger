trigger QuoteOwnerHierarchyTrigger on Quote (after insert, after update) {
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        QuoteHierarchyHandler.updateQuoteHierarchy(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        Map<String, Quote> opportunityMap = new Map<String, Quote>();
        for (Quote quote:Trigger.new) {
            if (quote.OwnerId != Trigger.oldMap.get(quote.Id).OwnerId){
                opportunityMap.put(quote.OpportunityId, quote);
            }
        }

        List<Opportunity> opportunities = new List<Opportunity>();
        for (String eachOppId:opportunityMap.keySet()) {
            Opportunity opp = new Opportunity();
            opp.Id = eachOppId;
            opp.OwnerId = opportunityMap.get(eachOppId).OwnerId;
            opportunities.add(opp);
        }

        UPDATE opportunities;
    }
}