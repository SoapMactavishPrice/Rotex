public class LeadSharingHandler {
    
    public static void handleOwnerChange(List<Lead> newList, Map<Id, Lead> oldMap) {
        
        List<LeadShare> sharesToInsert = new List<LeadShare>();
        
        for (Lead ld : newList) {
            Lead oldRec = oldMap.get(ld.Id);
            
            if (ld.OwnerId != oldRec.OwnerId) {
                
                Id creatorId = ld.CreatedById;
                
                if (creatorId != ld.OwnerId) {
                    LeadShare ls = new LeadShare();
                    ls.LeadId = ld.Id;
                    ls.UserOrGroupId = creatorId;
                    ls.LeadAccessLevel = 'Edit';
                    ls.RowCause = Schema.LeadShare.RowCause.Manual;
                    sharesToInsert.add(ls);
                }
            }
        }
        
        if (!sharesToInsert.isEmpty()) {
            insert sharesToInsert;
        }
    }
}