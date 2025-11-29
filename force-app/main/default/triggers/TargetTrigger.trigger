trigger TargetTrigger on Target__c (after insert, after update) {
    
    if(Trigger.isAfter && Trigger.isInsert) {
        List<Target__c> targetsToUpdate = new List<Target__c>();
        
        for (Target__c t : Trigger.new) {
            if (t.Sales_Rep__c != null && t.OwnerId != t.Sales_Rep__c) {
                Target__c targetUpdate = new Target__c(Id = t.Id, OwnerId = t.Sales_Rep__c);
                targetsToUpdate.add(targetUpdate);
            }
        }
        if (!targetsToUpdate.isEmpty()) {
            update targetsToUpdate;
        }
    }
    
    if(Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        
        List<Target__Share> sharesToInsert = new List<Target__Share>();
        
        for (Target__c t : Trigger.new) {
            Target__c oldT = Trigger.isUpdate ? Trigger.oldMap.get(t.Id) : null;
            Boolean shareRequired = false;
            
            // Share on insert or if Reporting_Manager__c is newly tagged/changed
            if ( Trigger.isInsert && t.Reporting_Manager__c != null ) {
                shareRequired = true;
            }
            else if(Trigger.isUpdate && t.Reporting_Manager__c != null 
                    && (oldT == null || t.Reporting_Manager__c != oldT.Reporting_Manager__c)) {
                        shareRequired = true;
                    }
            
            if (shareRequired) {
                Target__Share managerShare = new Target__Share();
                managerShare.ParentId = t.Id;
                managerShare.UserOrGroupId = t.Reporting_Manager__c;
                managerShare.AccessLevel = 'Edit';
                managerShare.RowCause = Schema.Target__Share.RowCause.Reporting_Manager__c;
                sharesToInsert.add(managerShare);
            }
        }
        if (!sharesToInsert.isEmpty()) {
            insert sharesToInsert;
        }        
    }
}