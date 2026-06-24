public class QuoteTriggerHandler {

    public static void updateOpportunityStageOnQuoteApproval(List<Quote> newQuotes,Map<Id, Quote> oldQuoteMap) {

        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        for (Quote q : newQuotes) {

            Quote oldQ = oldQuoteMap.get(q.Id);

            // APPROVED
            if (q.Status == 'Approved'
                && oldQ.Status != 'Approved'
                && q.OpportunityId != null) {

                oppsToUpdate.add(
                    new Opportunity(
                        Id = q.OpportunityId,
                        StageName = 'Closed-Won'
                    )
                );
            }

            // REJECTED
            if (q.Status == 'Rejected'
                && oldQ.Status != 'Rejected'
                && q.OpportunityId != null) {

                oppsToUpdate.add(
                    new Opportunity(
                        Id = q.OpportunityId,
                        StageName = 'Closed Lost',
                        Loss_Reason__c = q.Rejected_Reason__c
                    )
                );
            }
        }

        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }
    }

    public static void validateRejectedReason(List<Quote> newQuotes,Map<Id, Quote> oldQuoteMap) {

        for (Quote q : newQuotes) {

            Quote oldQ = oldQuoteMap.get(q.Id);

            if (q.Status == 'Rejected'
                && oldQ.Status != 'Rejected'
                && String.isBlank(q.Rejected_Reason__c)) {

                q.addError('Rejected Reason is mandatory when Quote Status is Rejected.');
            }
        }
    }
    public static void updateOpportunityCloseDateFromQuote(List<Quote> newQuotes,Map<Id, Quote> oldQuoteMap) {
        
        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        
        for (Quote q : newQuotes) {
            
            if (q.OpportunityId == null || q.Quote_Valid_Till__c == null) {
                continue;
            }
            
            // DO NOT update Opportunity on Quote Insert
            if (oldQuoteMap == null) {
                continue;
            }
            
            Quote oldQ = oldQuoteMap.get(q.Id);
            
            Boolean closeDateChanged =
                oldQ != null &&
                oldQ.Quote_Valid_Till__c != q.Quote_Valid_Till__c;
            
            Boolean projectDetailsChanged =
                oldQ != null &&
                oldQ.Project_Details__c != q.Project_Details__c;
            
            if (closeDateChanged || projectDetailsChanged) {
                
                Opportunity opp = new Opportunity(
                    Id = q.OpportunityId
                );
                
                if (closeDateChanged) {
                    opp.CloseDate = q.Quote_Valid_Till__c;
                }
                
                if (projectDetailsChanged) {
                    opp.Project_Name__c = q.Project_Details__c;
                }
                
                oppsToUpdate.add(opp);
            }
        }
        
        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }
    }
}