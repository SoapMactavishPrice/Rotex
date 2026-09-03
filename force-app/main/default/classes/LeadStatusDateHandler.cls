/**
 * Stamps stage entry DateTime fields when Dealer Status changes.
 * Used by WIP (6-day) and Future Prospect (90-day) owner reminder emails.
 */
public without sharing class LeadStatusDateHandler {

    public static void applyStatusDates(List<Lead> newLeads, Map<Id, Lead> oldMap) {
        if (newLeads == null || newLeads.isEmpty()) {
            return;
        }
        Datetime nowDt = System.now();
        for (Lead ld : newLeads) {
            if (ld == null) {
                continue;
            }
            String newStatus = ld.Dealer_Status__c;
            String oldStatus = oldMap == null || oldMap.get(ld.Id) == null
                ? null
                : oldMap.get(ld.Id).Dealer_Status__c;

            Boolean isInsert = oldMap == null;
            Boolean statusChanged = isInsert || newStatus != oldStatus;
            if (!statusChanged) {
                continue;
            }

            if (newStatus == 'Work In Progress') {
                // Insert: keep caller-provided stamp if present (tests/migration)
                if (isInsert && ld.Work_In_Progress_Date_Time__c != null) {
                    // leave as-is
                } else {
                    ld.Work_In_Progress_Date_Time__c = nowDt;
                }
            } else if (newStatus == 'Future Prospect') {
                if (isInsert && ld.Future_Prospect_Date_Time__c != null) {
                    // leave as-is
                } else {
                    ld.Future_Prospect_Date_Time__c = nowDt;
                }
            } else if (newStatus == 'Contacted') {
                if (isInsert && ld.Contacted_Date_Time__c != null) {
                    // leave as-is
                } else {
                    ld.Contacted_Date_Time__c = nowDt;
                }
            } else if (newStatus == 'New') {
                if (isInsert && ld.New_Date_Time__c != null) {
                    // leave as-is
                } else {
                    ld.New_Date_Time__c = nowDt;
                }
            } else if (newStatus == 'Qualified') {
                if (isInsert && ld.Qualified_Date_Time__c != null) {
                    // leave as-is
                } else {
                    ld.Qualified_Date_Time__c = nowDt;
                }
            } else if (newStatus == 'Regret') {
                if (ld.Regret_Date_Time__c == null) {
                    ld.Regret_Date_Time__c = nowDt;
                }
            }
        }
    }
}