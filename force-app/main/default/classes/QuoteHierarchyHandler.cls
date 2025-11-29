public class QuoteHierarchyHandler {

    public static void updateQuoteHierarchy(List<Quote> newList, Map<Id, Quote> oldMap) {
        // Collect owner IDs where owner changed or new record
        Set<Id> ownerIds = new Set<Id>();
        for (Quote q : newList) {
            if (oldMap == null || q.OwnerId != oldMap.get(q.Id).OwnerId) {
                ownerIds.add(q.OwnerId);
            }
        }
        if (ownerIds.isEmpty()) return;

        // Fetch all owner users
        Map<Id, User> hierarchyUsers = new Map<Id, User>(
            [SELECT Id, Name, ManagerId, SOA_Profile__c FROM User WHERE Id IN :ownerIds]
        );

        // Collect all manager IDs recursively
        Set<Id> allMgrIds = new Set<Id>();
        for (User u : hierarchyUsers.values()) {
            if (u.ManagerId != null) allMgrIds.add(u.ManagerId);
        }

        while (!allMgrIds.isEmpty()) {
            List<User> mgrs = [SELECT Id, Name, ManagerId, SOA_Profile__c FROM User WHERE Id IN :allMgrIds];
            allMgrIds.clear();
            for (User m : mgrs) {
                if (!hierarchyUsers.containsKey(m.Id)) {
                    hierarchyUsers.put(m.Id, m);
                    if (m.ManagerId != null) allMgrIds.add(m.ManagerId);
                }
            }
        }

        List<Quote> quotesToUpdate = new List<Quote>();
        Set<Id> quoteIdsToUpdateLineItems = new Set<Id>();

        // --- Update hierarchy fields on Quote ---
        for (Quote q : newList) {
            Quote oldQ = oldMap != null ? oldMap.get(q.Id) : null;
            User owner = hierarchyUsers.get(q.OwnerId);
            if (owner == null) continue;

            // Only update if owner is Sales Rep or Sales Manager
            if (!(owner.SOA_Profile__c == 'Sales Rep' || owner.SOA_Profile__c == 'Sales Manager')) continue;

            Quote qClone = new Quote(Id = q.Id);

            // Tag owner level
            if (owner.SOA_Profile__c == 'Sales Rep' && qClone.Sales_Rep__c == null) qClone.Sales_Rep__c = owner.Id;
            if (owner.SOA_Profile__c == 'Sales Manager' && qClone.Sales_Manager__c == null) qClone.Sales_Manager__c = owner.Id;

            // Traverse manager chain dynamically (up to 5 levels)
            User currentMgr = owner;
            Integer level = 0;
            while (currentMgr != null && level < 5) {
                currentMgr = (currentMgr.ManagerId != null) ? hierarchyUsers.get(currentMgr.ManagerId) : null;
                level++;
                if (currentMgr == null) break;

                switch on currentMgr.SOA_Profile__c {
                    when 'Sales Manager' {
                        if (qClone.Sales_Manager__c == null) qClone.Sales_Manager__c = currentMgr.Id;
                        System.debug('Sales Manager tagged: ' + currentMgr.Name);
                    }
                    when 'Country / Continent Sales Head / LOB Head' {
                        if (qClone.Country_Continent_Sales_Head_LOB_Head__c == null) qClone.Country_Continent_Sales_Head_LOB_Head__c = currentMgr.Id;
                        System.debug('Country/Continent Sales Head / LOB Head tagged: ' + currentMgr.Name);
                    }
                    when 'Global Sales Head' {
                        if (qClone.Global_Sales_Head__c == null) qClone.Global_Sales_Head__c = currentMgr.Id;
                        System.debug('Global Sales Head tagged: ' + currentMgr.Name);
                    }
                    when 'Rotex Board Member' {
                        if (qClone.Rotex_Board_Member__c == null) qClone.Rotex_Board_Member__c = currentMgr.Id;
                        System.debug('Rotex Board Member tagged: ' + currentMgr.Name);
                    }
                    when 'Managing Director / Country Manager' {
                        if (qClone.Managing_Director_Country_Manager__c == null) qClone.Managing_Director_Country_Manager__c = currentMgr.Id;
                        System.debug('Managing Director / Country Manager tagged: ' + currentMgr.Name);
                    }
                    when else {}
                }
            }

            quotesToUpdate.add(qClone);
            quoteIdsToUpdateLineItems.add(q.Id);
        }

        // Update Quotes
        if (!quotesToUpdate.isEmpty()) update quotesToUpdate;

        // --- Update Quote Line Items ---
        if (!quoteIdsToUpdateLineItems.isEmpty()) {
            // Map updated quotes by Id
            Map<Id, Quote> updatedQuoteMap = new Map<Id, Quote>();
            for (Quote q : quotesToUpdate) updatedQuoteMap.put(q.Id, q);

            List<QuoteLineItem> qliToUpdate = new List<QuoteLineItem>();

            for (QuoteLineItem qli : [
                SELECT Id, QuoteId, Sales_Rep__c, Sales_Manager__c, Country_Continent_Sales_Head_LOB_Head__c,
                       Global_Sales_Head__c, Rotex_Board_Member__c, Managing_Director_Country_Manage__c
                FROM QuoteLineItem
                WHERE QuoteId IN :quoteIdsToUpdateLineItems
            ]) {
                Quote parentQuote = updatedQuoteMap.get(qli.QuoteId);
                if (parentQuote == null) continue;

                if (qli.Sales_Rep__c == null) qli.Sales_Rep__c = parentQuote.Sales_Rep__c;
                if (qli.Sales_Manager__c == null) qli.Sales_Manager__c = parentQuote.Sales_Manager__c;
                if (qli.Country_Continent_Sales_Head_LOB_Head__c == null) qli.Country_Continent_Sales_Head_LOB_Head__c = parentQuote.Country_Continent_Sales_Head_LOB_Head__c;
                if (qli.Global_Sales_Head__c == null) qli.Global_Sales_Head__c = parentQuote.Global_Sales_Head__c;
                if (qli.Rotex_Board_Member__c == null) qli.Rotex_Board_Member__c = parentQuote.Rotex_Board_Member__c;
                if (qli.Managing_Director_Country_Manage__c == null) qli.Managing_Director_Country_Manage__c = parentQuote.Managing_Director_Country_Manager__c;

                qliToUpdate.add(qli);
            }

            if (!qliToUpdate.isEmpty()) update qliToUpdate;
        }
    }
}