public class AccountTriggerHandler {
    public static void updateAccountOwner(List<Account> newAccounts, Map<Id, Account> oldAccountMap) {
        try {
            Set<Id> channelPartnerIds = new Set<Id>();
            Map<Id, Account> accountsToUpdate = new Map<Id, Account>();

            // Step 1: Identify records where Channel_Partner__c has changed OR where Owner needs to be updated
            for (Account acc : newAccounts) {
                if (acc.Channel_Partner__c != null) {
                    // Check if Channel_Partner__c has changed
                    Boolean isChannelPartnerChanged = (oldAccountMap == null || !oldAccountMap.containsKey(acc.Id) || 
                        oldAccountMap.get(acc.Id).Channel_Partner__c != acc.Channel_Partner__c);

                    // If either of these conditions is met, we process this record
                    if (isChannelPartnerChanged) {
                        channelPartnerIds.add(acc.Channel_Partner__c);
                        accountsToUpdate.put(acc.Id, acc);
                    }
                }
            }

            // Exit early if there are no relevant updates
            if (accountsToUpdate.isEmpty()) {
                System.debug('No relevant updates, exiting trigger.');
                return;
            }

            // Step 2: Fetch OwnerId of Channel_Partner__c
            Map<Id, Account> channelPartnerMap = new Map<Id, Account>(
                [SELECT Id, OwnerId FROM Account WHERE Id IN :channelPartnerIds]
            );

            Map<Id, Id> updatedOwners = new Map<Id, Id>();

            // Step 3: Update Account Owner only if different from Channel Partner Owner
            for (Account acc : accountsToUpdate.values()) {
                if (channelPartnerMap.containsKey(acc.Channel_Partner__c)) {
                    Id channelPartnerOwnerId = channelPartnerMap.get(acc.Channel_Partner__c).OwnerId;
                    
                    // Only update if Account's Owner is different from Channel Partner's Owner
                    if (acc.OwnerId != channelPartnerOwnerId) {
                        acc.OwnerId = channelPartnerOwnerId;
                        updatedOwners.put(acc.Id, channelPartnerOwnerId);
                    }
                }
            }

            // Step 4: Debugging & Logging
            if (!updatedOwners.isEmpty()) {
                System.debug('Updated Account Owners: ' + updatedOwners);
            } else {
                System.debug('No owner changes required.');
            }

        } catch (Exception e) {
            System.debug('Exception in updateAccountOwner: ' + e.getMessage());
        }
    }
}