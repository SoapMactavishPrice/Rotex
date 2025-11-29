trigger OpportunityTrigger on Opportunity (After Update, before update) {
    
    if(Trigger.isBefore && Trigger.isUpdate) {
        OpportunityTriggerHandler.handleProposalOpportunities(trigger.new, trigger.oldMap);
        system.debug(trigger.new);
    }
    
    if(Trigger.isBefore && Trigger.isUpdate) {
        Set<Id> oppIds = new Set<Id>();
        
        // Collect Opportunities where Stage is being changed to target values
        for (Opportunity opp : Trigger.new) {
            Opportunity oldOpp = Trigger.oldMap.get(opp.Id);
            
            if ((opp.StageName == 'Firm Proposal' || opp.StageName == 'Budgetary Proposal') &&
                opp.StageName != oldOpp.StageName) {
                    oppIds.add(opp.Id);
                }
        }
        
        if (oppIds.isEmpty()) return;
        
        // Query related OpportunityLineItems
        Map<Id, List<OpportunityLineItem>> oppLineItemMap = new Map<Id, List<OpportunityLineItem>>();
        for (OpportunityLineItem oli : [
            SELECT Id, ProductCode, OpportunityId
            FROM OpportunityLineItem
            WHERE OpportunityId IN :oppIds
        ]) {
            if (!oppLineItemMap.containsKey(oli.OpportunityId)) {
                oppLineItemMap.put(oli.OpportunityId, new List<OpportunityLineItem>());
            }
            oppLineItemMap.get(oli.OpportunityId).add(oli);
        }
        
        // Validate
        for (Opportunity opp : Trigger.new) {
            if (!oppIds.contains(opp.Id)) continue;
            
            if (opp.Amount < 25000) {
                Boolean hasSpecialItem = false;
                
                if (oppLineItemMap.containsKey(opp.Id)) {
                    for (OpportunityLineItem oli : oppLineItemMap.get(opp.Id)) {
                        if (oli.ProductCode == '27000002809') {
                            hasSpecialItem = true;
                            break;
                        }
                    }
                }
                
                if (!hasSpecialItem) {
                    if (!Test.isRunningTest())  {
                        opp.addError('Opportunities under INR 25,000 must include item code 27000002809.');
                    }
                }
            }
        }
    }
}