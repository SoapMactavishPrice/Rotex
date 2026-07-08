trigger OpportunityPricebookTrigger on Opportunity (before insert) {
    
    // Collect opportunities that need processing
    List<Opportunity> oppsToProcess = new List<Opportunity>();
    for(Opportunity opp : Trigger.new) {
        if(opp.Pricebook2Id == null) {
            oppsToProcess.add(opp);
        }
    }
    
    if(!oppsToProcess.isEmpty()) {
        
        // Get current user with Division
        User currentUser = [SELECT Id, Division__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        
        // Check if User has Division__c set
        if(String.isBlank(currentUser.Division__c)) {
            for(Opportunity opp : oppsToProcess) {
                opp.addError('User Division is not set. Please contact your Administrator.');
            }
            return;
        }
        
        // Get all Account IDs from Opportunities
        Set<Id> accountIds = new Set<Id>();
        for(Opportunity opp : oppsToProcess) {
            if(opp.AccountId != null) {
                accountIds.add(opp.AccountId);
            }
        }
        
        if(!accountIds.isEmpty()) {
            
            // Get Account with Sales Area Items
            Map<Id, Account> accountMap = new Map<Id, Account>([
                SELECT Id, (SELECT Id, Sales_Org__c, Distribution_Channel__c, Division__c, CurrencyIsoCode
                            FROM Sales_Area_Item__r 
                            WHERE Sales_Org__c = '1100' 
                            AND Division__c = '10')
                FROM Account 
                WHERE Id IN :accountIds
            ]);
            
            // Get Pricebooks based on Distribution Channel
            Map<String, Id> pricebookMap = new Map<String, Id>();
            for(Pricebook2 pb : [SELECT Id, Distribution_Channel__c FROM Pricebook2 
                                 WHERE IsActive = true 
                                 AND Distribution_Channel__c IN ('10', '20')]) {
                if(pb.Distribution_Channel__c != null) {
                    pricebookMap.put(pb.Distribution_Channel__c, pb.Id);
                }
            }
            
            // Process each opportunity
            for(Opportunity opp : oppsToProcess) {
                if(opp.AccountId == null) continue;
                
                Account acc = accountMap.get(opp.AccountId);
                if(acc == null || acc.Sales_Area_Item__r == null || acc.Sales_Area_Item__r.isEmpty()) continue;
                
                String userDivision = currentUser.Division__c;
                Boolean pricebookSet = false;
                
                // Domestic and Both: Only accept DC=10
                if(userDivision == 'Domestic' || userDivision == 'Both') {
                    for(Sales_Area_Item__c salesArea : acc.Sales_Area_Item__r) {
                        if(salesArea.Distribution_Channel__c == '10') {
                            Id pbId = pricebookMap.get('10');
                            if(pbId != null) {
                                opp.Pricebook2Id = pbId;
                                if(salesArea.CurrencyIsoCode != null) {
                                    opp.CurrencyIsoCode = salesArea.CurrencyIsoCode;
                                }
                                pricebookSet = true;
                                break;
                            }
                        }
                    }
                    
                    if(!pricebookSet) {
                        opp.addError('No Sales Area Item found.');
                    }
                } 
                // Export: Only accept DC=20
                else if(userDivision == 'Export') {
                    for(Sales_Area_Item__c salesArea : acc.Sales_Area_Item__r) {
                        if(salesArea.Distribution_Channel__c == '20') {
                            Id pbId = pricebookMap.get('20');
                            if(pbId != null) {
                                opp.Pricebook2Id = pbId;
                                if(salesArea.CurrencyIsoCode != null) {
                                    opp.CurrencyIsoCode = salesArea.CurrencyIsoCode;
                                }
                                pricebookSet = true;
                                break;
                            }
                        }
                    }
                    
                    if(!pricebookSet) {
                        opp.addError('No Sales Area Item found');
                    }
                }
            }
        }
    }
}