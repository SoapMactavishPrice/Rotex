public class LeadTaskBatch implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
    
    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id, Name, OwnerId, Status, New_Date_Time__c, Contacted_Date_Time__c, Work_In_Progress_Date_Time__c 
            FROM Lead 
            WHERE (Status = 'New' AND New_Date_Time__c != null) 
            OR (Status = 'Contacted' AND Contacted_Date_Time__c != null)
            OR (Status = 'Work In Progress' AND Work_In_Progress_Date_Time__c != null)
        ]);
    }
    
    public void execute(Database.BatchableContext context, List<SObject> scope) {
        
        List<Task> tasks = new List<Task>();
        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.EmailHeader.triggerUserEmail = true; // Ensure notifications are sent
        
        for (Lead lead : (List<Lead>) scope) {
            Date today = Date.today();
            Boolean createTask = false;
            
            if (lead.Status == 'New' && lead.New_Date_Time__c != null) {
                Integer daysDifference = lead.New_Date_Time__c.date().daysBetween(today);
                system.debug('New daysDifference -> '+daysDifference);
                createTask = (daysDifference == 1);
            } else if (lead.Status == 'Contacted' && lead.Contacted_Date_Time__c != null) {
                Integer daysDifference = lead.Contacted_Date_Time__c.date().daysBetween(today);
                system.debug('Contacted daysDifference -> '+daysDifference);
                createTask = (daysDifference == 3);
            } else if (lead.Status == 'Work In Progress' && lead.Work_In_Progress_Date_Time__c != null) {
                Integer daysDifference = lead.Work_In_Progress_Date_Time__c.date().daysBetween(today);
                system.debug('Work In Progress daysDifference -> '+daysDifference);
                createTask = (daysDifference == 3);
            }
            
            if (createTask) {  
                tasks.add(new Task(  OwnerId = lead.OwnerId,
                                   WhoId = lead.Id,
                                   //Subject = 'Follow up on lead - ' + lead.Name,
                                   Subject = 'Follow up on lead - ' + lead.Name + ' [' + lead.Status + ']',
                                   Priority = 'High',
                                   Status = 'Open',
                                   ActivityDate = Date.today()
                                  ));
            }
        }
        
        if (!tasks.isEmpty()) {  Database.insert(tasks, dmlOptions);
                               // Insert with notification trigger
                              }
    }
    
    public void finish(Database.BatchableContext context) {
        // Optional: Add any post-batch processing or notifications here.
    }
    
    // Implement Schedulable interface
    public void execute(SchedulableContext sc) {
        // Execute the batch job
        Database.executeBatch(new LeadTaskBatch());
    }
}