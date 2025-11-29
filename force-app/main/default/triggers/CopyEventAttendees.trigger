trigger CopyEventAttendees on Event (after insert) {
    
    List<Event_Attendee__c> eventAttendeeList = new List<Event_Attendee__c>();
    
    // Collect Event Ids
    Set<Id> eventIds = new Set<Id>();
    for (Event ev : Trigger.new) {
        eventIds.add(ev.Id);
    }
    
    // Query EventRelation to get attendees
    List<EventRelation> eventRelations = [SELECT EventId, RelationId, Relation.Type 
                                          FROM EventRelation 
                                          WHERE EventId IN :eventIds 
                                          AND Relation.Type = 'User'];
    
    for (EventRelation er : eventRelations) {
        Event_Attendee__c ea = new Event_Attendee__c();
        ea.Attendee__c = er.RelationId; // User lookup
        ea.Event_Id__c = er.EventId; // Text field for Event Id
        eventAttendeeList.add(ea);
    }
    
    // Insert new Event_Attendee__c records
    if (!eventAttendeeList.isEmpty()) {
        insert eventAttendeeList;
    }
}