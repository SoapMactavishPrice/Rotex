public with sharing class EventTriggerHandler {

    public static void handleAfterUpdate(List<Event> newList, Map<Id, Event> oldMap) {

        Set<Id> salesRepIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();

        // Collect Events changed from NOT Completed → Completed
        List<Event> completedEvents = new List<Event>();

        for (Event e : newList) {
            Event oldE = oldMap.get(e.Id);

            if (oldE.Visit_Status__c != 'Completed' &&
                e.Visit_Status__c == 'Completed' &&
                e.OwnerId != null &&
                e.WhatId != null) {

                completedEvents.add(e);
                salesRepIds.add(e.OwnerId);
                accountIds.add(e.WhatId);
            }
        }

        if (completedEvents.isEmpty()) return;

        // Query all matching Targets
        Map<String, Target__c> keyToTarget = new Map<String, Target__c>();

        for (Target__c t : [
            SELECT Id, Sales_Rep__c, Customer_Name__c, Actual_Visits_Per_Year__c
            FROM Target__c
            WHERE Sales_Rep__c IN :salesRepIds
            AND Customer_Name__c IN :accountIds
        ]) {
            String key = t.Sales_Rep__c + '_' + t.Customer_Name__c;
            keyToTarget.put(key, t);
        }

        // To avoid duplicates → use Maps
        Map<Id, Target__c> targetsToUpdate = new Map<Id, Target__c>();
        Map<Id, Event> eventsToUpdate = new Map<Id, Event>();

        // Process each completed Event
        for (Event e : completedEvents) {

            String key = e.OwnerId + '_' + e.WhatId;

            if (!keyToTarget.containsKey(key)) continue;

            Target__c tgt = keyToTarget.get(key);

            // Ensure uniqueness of Target updates
            if (!targetsToUpdate.containsKey(tgt.Id)) {
                Target__c tUpdated = tgt.clone(false,false,false,false);
                tUpdated.Id = tgt.Id;
                Integer cur = tUpdated.Actual_Visits_Per_Year__c == null ? 0 :
                              Integer.valueOf(tUpdated.Actual_Visits_Per_Year__c);
                tUpdated.Actual_Visits_Per_Year__c = cur + 1;
                targetsToUpdate.put(tgt.Id, tUpdated);
            } else {
                Target__c tUpdated = targetsToUpdate.get(tgt.Id);
                Decimal cur = tUpdated.Actual_Visits_Per_Year__c;
                tUpdated.Actual_Visits_Per_Year__c = cur + 1;
            }

            // Ensure uniqueness of Event updates
            eventsToUpdate.put(e.Id, new Event(
                Id = e.Id,
                Target__c = tgt.Id
            ));
        }

        // DML
        if (!targetsToUpdate.isEmpty()) update targetsToUpdate.values();
        if (!eventsToUpdate.isEmpty()) update eventsToUpdate.values();
    }
}