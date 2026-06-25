trigger CopyAddressNew on Address_Information__c (before insert, before update) {
    
    if(Trigger.isBefore){
        
        if(Trigger.isInsert || Trigger.isUpdate){
            CopyAddressNewHandler.copyAddressToRecord(Trigger.new);
            CopyAddressNewHandler.copySoldAddressToRecord(Trigger.new);
        }
    }
    
}