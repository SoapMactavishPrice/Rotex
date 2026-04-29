public class QuoteHierarchyHandler {
    
    public static void updateQuoteHierarchy(List<Quote> newList, Map<Id, Quote> oldMap) {
        
        Boolean isInsert = (oldMap == null);
        
        // 🔹 1. Identify records to process (V1 logic)
        Set<Id> accIds = new Set<Id>();
        Map<Id, Quote> quotesToProcess = new Map<Id, Quote>();
        
        for (Quote q : newList) {
            Boolean shouldRun = false;
            
            if (isInsert) {
                // Insert: run only if Account exists & Sales Rep not yet set
                shouldRun = (q.AccountId != null && q.Sales_Rep__c == null);
            } else {
                Quote oldQ = oldMap.get(q.Id);
                // Update: run if Account changed OR Sales Rep is blank
                shouldRun = (
                    q.AccountId != null &&
                    (q.Sales_Rep__c == null || q.AccountId != oldQ.AccountId)
                );
            }
            
            if (shouldRun) {
                quotesToProcess.put(q.Id, q);
                accIds.add(q.AccountId);
            }
        }
        
        if (quotesToProcess.isEmpty()) return;
        
        // 🔹 2. Fetch Accounts
        Map<Id, Account> accMap = new Map<Id, Account>(
            [SELECT Id, OwnerId FROM Account WHERE Id IN :accIds]
        );
        
        // 🔹 3. Collect Account Owner Ids
        Set<Id> ownerIds = new Set<Id>();
        for (Account acc : accMap.values()) {
            if (acc.OwnerId != null) {
                ownerIds.add(acc.OwnerId);
            }
        }
        if (ownerIds.isEmpty()) return;
        
        // 🔹 4. Fetch base Users
        Map<Id, User> hierarchyUsers = new Map<Id, User>(
            [SELECT Id, Name, ManagerId, SOA_Profile__c FROM User WHERE Id IN :ownerIds]
        );
        
        // 🔹 5. Fetch hierarchy up to 5 levels (CPU-safe)
        Set<Id> nextLevelIds = new Set<Id>();
        for (User u : hierarchyUsers.values()) {
            if (u.ManagerId != null) {
                nextLevelIds.add(u.ManagerId);
            }
        }
        
        Integer depth = 0;
        while (!nextLevelIds.isEmpty() && depth < 5) {
            List<User> managers = [
                SELECT Id, Name, ManagerId, SOA_Profile__c
                FROM User
                WHERE Id IN :nextLevelIds
            ];
            
            nextLevelIds.clear();
            
            for (User manager : managers) {
                if (!hierarchyUsers.containsKey(manager.Id)) {
                    hierarchyUsers.put(manager.Id, manager);
                    if (manager.ManagerId != null) {
                        nextLevelIds.add(manager.ManagerId);
                    }
                }
            }
            depth++;
        }
        
        // 🔹 6. Populate hierarchy fields on filtered Quotes
        Set<Id> quoteIdsToUpdateLineItems = new Set<Id>();
        Map<Id, Quote> hierarchyByQuoteId = new Map<Id, Quote>();
        
        for (Quote q : quotesToProcess.values()) {
            Account acc = accMap.get(q.AccountId);
            if (acc == null || acc.OwnerId == null) continue;
            
            User baseUser = hierarchyUsers.get(acc.OwnerId);
            if (baseUser == null) continue;
            
            // ✅ Sales Rep = Account Owner
            q.Sales_Rep__c = baseUser.Id;
            
            // 🔁 Traverse hierarchy
            User currentMgr = baseUser;
            Integer level = 0;
            
            while (currentMgr != null && level < 5) {
                currentMgr = (currentMgr.ManagerId != null)
                    ? hierarchyUsers.get(currentMgr.ManagerId)
                    : null;
                
                level++;
                
                if (currentMgr == null) break;
                
                switch on currentMgr.SOA_Profile__c {
                    when 'Sales Manager' {
                        if (q.Sales_Manager__c == null) {
                            q.Sales_Manager__c = currentMgr.Id;
                        }
                    }
                    when 'Country / Continent Sales Head / LOB Head' {
                        if (q.Country_Continent_Sales_Head_LOB_Head__c == null) {
                            q.Country_Continent_Sales_Head_LOB_Head__c = currentMgr.Id;
                        }
                    }
                    when 'Global Sales Head' {
                        if (q.Global_Sales_Head__c == null) {
                            q.Global_Sales_Head__c = currentMgr.Id;
                        }
                    }
                    when 'Rotex Board Member' {
                        if (q.Rotex_Board_Member__c == null) {
                            q.Rotex_Board_Member__c = currentMgr.Id;
                        }
                    }
                    when 'Managing Director / Country Manager' {
                        if (q.Managing_Director_Country_Manager__c == null) {
                            q.Managing_Director_Country_Manager__c = currentMgr.Id;
                        }
                    }
                    when else {}
                }
            }
            
            if (q.Id != null) {
                hierarchyByQuoteId.put(q.Id, q);
                quoteIdsToUpdateLineItems.add(q.Id);
            }
        }
        
        // 🔹 7. Sync hierarchy fields down to Quote Line Items (V2 logic)
        if (!quoteIdsToUpdateLineItems.isEmpty()) {
            List<QuoteLineItem> qliToUpdate = new List<QuoteLineItem>();
            
            for (QuoteLineItem qli : [
                SELECT Id, QuoteId, Sales_Rep__c, Sales_Manager__c,
                       Country_Continent_Sales_Head_LOB_Head__c,
                       Global_Sales_Head__c, Rotex_Board_Member__c,
                       Managing_Director_Country_Manage__c
                FROM QuoteLineItem
                WHERE QuoteId IN :quoteIdsToUpdateLineItems
            ]) {
                Quote parentQuote = hierarchyByQuoteId.get(qli.QuoteId);
                if (parentQuote == null) continue;
                
                Boolean hasLineChanges = false;
                
                if (qli.Sales_Rep__c == null && parentQuote.Sales_Rep__c != null) {
                    qli.Sales_Rep__c = parentQuote.Sales_Rep__c;
                    hasLineChanges = true;
                }
                if (qli.Sales_Manager__c == null && parentQuote.Sales_Manager__c != null) {
                    qli.Sales_Manager__c = parentQuote.Sales_Manager__c;
                    hasLineChanges = true;
                }
                if (qli.Country_Continent_Sales_Head_LOB_Head__c == null &&
                    parentQuote.Country_Continent_Sales_Head_LOB_Head__c != null) {
                    qli.Country_Continent_Sales_Head_LOB_Head__c = parentQuote.Country_Continent_Sales_Head_LOB_Head__c;
                    hasLineChanges = true;
                }
                if (qli.Global_Sales_Head__c == null && parentQuote.Global_Sales_Head__c != null) {
                    qli.Global_Sales_Head__c = parentQuote.Global_Sales_Head__c;
                    hasLineChanges = true;
                }
                if (qli.Rotex_Board_Member__c == null && parentQuote.Rotex_Board_Member__c != null) {
                    qli.Rotex_Board_Member__c = parentQuote.Rotex_Board_Member__c;
                    hasLineChanges = true;
                }
                if (qli.Managing_Director_Country_Manage__c == null &&
                    parentQuote.Managing_Director_Country_Manager__c != null) {
                    qli.Managing_Director_Country_Manage__c = parentQuote.Managing_Director_Country_Manager__c;
                    hasLineChanges = true;
                }
                
                if (hasLineChanges) {
                    qliToUpdate.add(qli);
                }
            }
            
            if (!qliToUpdate.isEmpty()) {
                update qliToUpdate;
            }
        }
    }
}