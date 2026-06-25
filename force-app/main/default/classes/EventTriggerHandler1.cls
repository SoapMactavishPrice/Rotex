public class EventTriggerHandler1 {
    
    public static void createFollowupTasks(List<Event> newEvents,Map<Id, Event> oldMap) {
        
        List<Task> tasksToInsert = new List<Task>();
        
        for (Event ev : newEvents) {
            
            Event oldEv = oldMap.get(ev.Id);
            
            // Create task only when Visit Status changes to Completed
            if (ev.Visit_Status__c == 'Completed' && oldEv.Visit_Status__c != 'Completed' && ev.Next_Action_Applicable__c == 'Yes' && oldEv.Next_Action_Applicable__c != 'Yes'){
                Task t = new Task();
            
            // Subject from Event
            t.Subject = ev.Subject;
            
            // Assign to logged in user
            // t.OwnerId = UserInfo.getUserId();
            t.OwnerId = ev.OwnerId;
            // Fixed values
            t.Priority = 'Normal';
            t.Status = 'Open';
            
            // Due Date from Event Next Action Date
            t.ActivityDate = ev.Next_Action_Date__c;
            
            // Comments from Event Description
            t.Description = ev.Description;
            t.Task_Type__c ='Visit Task';
            tasksToInsert.add(t);
        }
    }
    
    if (!tasksToInsert.isEmpty()) {
        insert tasksToInsert;
    }
}
}