trigger LeadOwnerChangeSharingTrigger on Lead (after insert, after update) {
    
    if (Trigger.isAfter && Trigger.isUpdate) {
        LeadSharingHandler.handleOwnerChange(Trigger.new, Trigger.oldMap);
    }
    
    if (Trigger.isAfter && Trigger.isInsert) {
        
        try {
            // Fetch Code Master record
            Code_Master__c codem = [
                SELECT Id, Name, Current_Sequence__c, Starting_Sequence__c, Backend_Current_Sequence__c 
                FROM Code_Master__c 
                WHERE Name = 'Enquiry No' 
                LIMIT 1
                FOR UPDATE
            ];
            
            List<Lead> leadsToUpdate = new List<Lead>();
            
            // Handle numeric safely
            Integer sequence = 0;
            Integer length = 6; // padding length
            
            if (String.isNotBlank(codem.Backend_Current_Sequence__c) &&
                codem.Backend_Current_Sequence__c.isNumeric()) {
                    
                    sequence = Integer.valueOf(codem.Backend_Current_Sequence__c);
                    length = codem.Backend_Current_Sequence__c.length();
                } else {
                    sequence = 1;
                }
            
            for (Lead l : Trigger.new) {
                
                // Only update if Enq_No__c is null
                if (l.Enq_No__c == null) {
                    
                    String formatted = String.valueOf(sequence).leftPad(length, '0');
                    
                    Lead updLead = new Lead(
                        Id = l.Id,
                        Enq_No__c = 'SF' + formatted
                    );
                    
                    leadsToUpdate.add(updLead); 
                    sequence++;
                }
            }
            
            // Update leads
            if (!leadsToUpdate.isEmpty()) {
                update leadsToUpdate;
            }
            
            // ✅ Update correct field and keep only numeric value
            codem.Current_Sequence__c = sequence;
            update codem;
            
        } catch (Exception e) {
            System.debug('Exception in LeadEnquiryNumber Trigger: ' + e.getMessage());
        }
    }
}