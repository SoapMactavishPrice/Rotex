trigger LeadTrigger on Lead (after insert, after update, before update) {
    
    if(Trigger.isAfter && Trigger.isUpdate) {
        
        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        
        for (Lead ld : Trigger.new) {
            Lead oldLead = Trigger.oldMap.get(ld.Id);
            
            // Check if the lead was just converted
            if (ld.IsConverted && !oldLead.IsConverted) {
                if (ld.ConvertedOpportunityId != null && ld.ConvertedContactId != null) {
                    Opportunity opp = new Opportunity( Id = ld.ConvertedOpportunityId, Project_Contact__c  = ld.ConvertedContactId
                                                     ); oppsToUpdate.add(opp);
                }
            }
        }
        
        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }
    }
    
    if(Trigger.isAfter && Trigger.isUpdate) {
        
        // Query all State__c records and create a map from state names to state IDs
        Map<String, Id> stateMap = new Map<String, Id>();
        Map<String, Id> countryMap = new Map<String, Id>();
        /*for (State__c state : [SELECT Id, Name FROM State__c]) {
stateMap.put(state.Name, state.Id);
}
for (Country__c country :[SELECT Id, Name FROM Country__c]){
countryMap.put(country.Name, country.Id);
}*/
        List<Address_Information__c> addressInformationList = new List<Address_Information__c>();
        
        for (Lead lead : Trigger.new) {
            if (lead.IsConverted && lead.ConvertedAccountId != null) {
                Address_Information__c addressInfo = new Address_Information__c();
                addressInfo.Account__c = lead.ConvertedAccountId;
                addressInfo.Name = 'Bill to -'+ lead.City;
                addressInfo.City__c = lead.City;
                //addressInfo.Zip_Code__c = decimal.valueof(lead.PostalCode);
                //addressInfo.State__c = lead.State;
                //addressInfo.Country__c = lead.Country;
                
                
                // Use the stateMap to set the Billing_State__c
                /*if (stateMap.containsKey(lead.State)) {
addressInfo.Bill_to_State__c = stateMap.get(lead.State);
system.debug(stateMap.get(lead.State));
}*/
                
                /* if (countryMap.containsKey(lead.country)) {
addressInfo.Bill_to_country__c = countryMap.get(lead.Country);
system.debug(countryMap.get(lead.Country));
}*/
                
                // Add the new Address Information to the list to insert
                addressInformationList.add(addressInfo);
            }
        }
        
        // Insert the new Address Information records
        if (!addressInformationList.isEmpty()) {
            insert addressInformationList;
        }
    }
    
    if(Trigger.isBefore && Trigger.isUpdate) {
        
        for (Lead lead : Trigger.new) {
            if (lead.Forward_to_Dealer__c == true && Trigger.oldMap.get(lead.Id).Forward_to_Dealer__c == false) {
                lead.Status = 'Forward to Dealer';
            }
        }
    }
    
    if(Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        
        // Map to store status-specific DateTime fields
        Map<String, String> statusFieldMap = new Map<String, String>{
            'New' => 'New_Date_Time__c',
                'Contacted' => 'Contacted_Date_Time__c',
                'Forward to Dealer' => 'Forward_to_Dealer_Date_Time__c',
                'Work In Progress' => 'Work_In_Progress_Date_Time__c',
                'Qualified' => 'Qualified_Date_Time__c',
                'Future Prospect' => 'Future_Prospect_Date_Time__c',
                'Regret' => 'Regret_Date_Time__c'
                };
                    
                    // List to hold leads for update
                    List<Lead> leadsToUpdate = new List<Lead>();
        
        for (Lead lead : Trigger.new) {
            Lead oldLead = Trigger.isUpdate ? Trigger.oldMap.get(lead.Id) : null;
            
            // Update Date/Time field if the status is newly inserted or changed
            if (statusFieldMap.containsKey(lead.Status) && 
                (Trigger.isInsert || (Trigger.isUpdate && lead.Status != oldLead.Status))) {
                    
                    Lead updatedLead = new Lead(Id = lead.Id);
                    
                    // Update the appropriate Date/Time field
                    String fieldName = statusFieldMap.get(lead.Status);
                    updatedLead.put(fieldName, DateTime.now());
                    
                    leadsToUpdate.add(updatedLead);
                }
        }
        
        // Perform DML to update leads
        if (!leadsToUpdate.isEmpty()) {
            update leadsToUpdate;
        }        
    }
    
    if (Trigger.isAfter && Trigger.isUpdate) {
        LeadSharingHandler.handleOwnerChange(Trigger.new, Trigger.oldMap);
    }
    
    if(Trigger.isBefore && Trigger.isUpdate) {
        
        Set<Id> convertedAccountIds = new Set<Id>();
        
        // 1️⃣ Identify Leads being converted
        for (Lead ld : Trigger.new) {
            Lead oldLd = Trigger.oldMap.get(ld.Id);
            
            if (!oldLd.IsConverted && ld.IsConverted && ld.ConvertedAccountId != null) {
                convertedAccountIds.add(ld.ConvertedAccountId);
            }
        }
        
        if (convertedAccountIds.isEmpty()) return;
        
        // 2️⃣ Fetch selected Accounts
        Map<Id, Account> accMap = new Map<Id, Account>(
            [
                SELECT Id, SAP_Customer_Code__c
                FROM Account
                WHERE Id IN :convertedAccountIds
            ]
        );
        
        // 3️⃣ Validate SAP code prefix
        for (Lead ld : Trigger.new) {
            Lead oldLd = Trigger.oldMap.get(ld.Id);
            
            if (!oldLd.IsConverted && ld.IsConverted && ld.ConvertedAccountId != null) {
                
                Account acc = accMap.get(ld.ConvertedAccountId);
                
                // 🚫 New Account OR missing SAP
                if (acc == null || String.isBlank(acc.SAP_Customer_Code__c)) {
                    ld.addError(
                        'Lead conversion blocked. Please select an existing Account with a SAP Customer Code that starts with "10" or "9".'
                    );
                    continue;
                }
                
                String sapCode = acc.SAP_Customer_Code__c.trim();
                
                // 🚫 Must start with "10" OR "9"
                if (!(sapCode.startsWith('10') || sapCode.startsWith('9'))) {
                    ld.addError(
                        'Lead conversion blocked. Selected Account SAP Customer Code must start with "10" or "9".'
                    );
                }
            }
        }
    }
    
}