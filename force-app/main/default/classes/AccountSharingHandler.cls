public without sharing class AccountSharingHandler{

    public static void shareAccountWithChannelPartner(
        List<Account> newList,
        Map<Id, Account> oldMap
    ) {

        List<AccountShare> sharesToInsert = new List<AccountShare>();
        
        Set<Id> accountIds = new Set<Id>();
        Set<Id> userIds = new Set<Id>();
        
        for(Account acc : newList) {
            accountIds.add(acc.Id);
            
            if(acc.Channel_Partner_User__c != null){
                userIds.add(acc.Channel_Partner_User__c);
            }
        }
        
        // Existing shares
        Map<String, AccountShare> existingShares = new Map<String, AccountShare>();
        
        for(AccountShare sh : [SELECT Id,AccountId,UserOrGroupId FROM AccountShare WHERE AccountId IN :accountIds AND UserOrGroupId IN :userIds]) {
            existingShares.put(sh.AccountId + '-' + sh.UserOrGroupId, sh);
        }
        
        for(Account acc : newList) {
            
            Account oldAcc = oldMap.get(acc.Id);
            
            // Skip if lookup is blank
            if(acc.Channel_Partner_User__c == null) {
                continue;
            }
            
            // Skip if Channel Partner User hasn't changed
            if(oldAcc != null &&
               acc.Channel_Partner_User__c == oldAcc.Channel_Partner_User__c) {
                   continue;
               }
            
            String key = acc.Id + '-' + acc.Channel_Partner_User__c;
            
            // Skip if already shared
            if(existingShares.containsKey(key)) {
                continue;
            }
            
            AccountShare share = new AccountShare();
            share.AccountId = acc.Id;
            share.UserOrGroupId = acc.Channel_Partner_User__c;
            
            share.AccountAccessLevel = 'Read';
            share.OpportunityAccessLevel = 'Read';
            share.CaseAccessLevel = 'Read';
            
            // Optional (include if your org supports this field)
          //  share.ContactAccessLevel = 'Read';
            
            share.RowCause = Schema.AccountShare.RowCause.Manual;
            
            sharesToInsert.add(share);
        }
        
        if (!sharesToInsert.isEmpty()) {
            
            Database.SaveResult[] results = Database.insert(sharesToInsert, false);
            
            for (Integer i = 0; i < results.size(); i++) {
                
                if (!results[i].isSuccess()) {
                    
                    for (Database.Error err : results[i].getErrors()) {
                        
                        System.debug('Share Error : ' + err.getStatusCode());
                        System.debug('Share Message : ' + err.getMessage());
                        
                    }
                } else {
                    System.debug('Share Created : ' + results[i].getId());
                }
            }
        }
    }
}