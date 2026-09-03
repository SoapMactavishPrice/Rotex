/**
 * Stamps Dealer stage entry DateTime fields when Dealer_Status__c changes.
 * Separate from LeadStatusDateHandler (owner reminder fields).
 */
public without sharing class LeadDealerStatusDateHandler {

    public static void applyDealerStatusDates(List<Lead> newLeads, Map<Id, Lead> oldMap) {
        if (newLeads == null || newLeads.isEmpty()) {
            return;
        }

        Datetime nowDt = System.now();
        Boolean isInsert = oldMap == null;

        for (Lead ld : newLeads) {
            if (ld == null) {
                continue;
            }

            String newStatus = ld.Dealer_Status__c;
            String oldStatus = isInsert || oldMap.get(ld.Id) == null
                ? null
                : oldMap.get(ld.Id).Dealer_Status__c;

            Boolean statusChanged = isInsert || newStatus != oldStatus;
            if (!statusChanged) {
                continue;
            }

            if (newStatus == 'Work In Progress') {
                if (!(isInsert && ld.Dealer_Work_In_Progress_Date_Time__c != null)) {
                    ld.Dealer_Work_In_Progress_Date_Time__c = nowDt;
                }
            } else if (newStatus == 'Future Prospect') {
                if (!(isInsert && ld.Dealer_Future_Prospect_Date_Time__c != null)) {
                    ld.Dealer_Future_Prospect_Date_Time__c = nowDt;
                }
            } else if (newStatus == 'Contacted') {
                if (!(isInsert && ld.Dealer_Contacted_Date_Time__c != null)) {
                    ld.Dealer_Contacted_Date_Time__c = nowDt;
                }
            } else if (newStatus == 'New') {
                if (!(isInsert && ld.Dealer_New_Date_Time__c != null)) {
                    ld.Dealer_New_Date_Time__c = nowDt;
                }
            } else if (newStatus == 'Qualified') {
                if (!(isInsert && ld.Dealer_Qualified_Date_Time__c != null)) {
                    ld.Dealer_Qualified_Date_Time__c = nowDt;
                }
            } else if (newStatus == 'Regret') {
                if (ld.Dealer_Regret_Date_Time__c == null) {
                    ld.Dealer_Regret_Date_Time__c = nowDt;
                }
            }
        }
    }
}