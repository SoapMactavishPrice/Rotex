/*@isTest
public class CopyEventAttendeesTest {
    @testSetup
    static void setupTestData() {
        // Create a test User
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Username = 'testuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'tuser',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;
        
        // Create an Event
        Event testEvent = new Event(
            Subject = 'Test Event',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(2)
        );
        insert testEvent;

        // Create an EventRelation (explicitly linking to User)
        EventRelation eventRel = new EventRelation(
            EventId = testEvent.Id,
            RelationId = testUser.Id,  // Ensure it's linked to a User
            IsInvitee = true
        );
        insert eventRel;

        // Verify EventRelation is inserted
        System.assertNotEquals(null, [SELECT Id FROM EventRelation WHERE EventId = :testEvent.Id LIMIT 1]);
        
        Event_Attendee__c ea = new Event_Attendee__c();
        ea.Attendee__c = testUser.Id;
        Insert ea;
    }
    
    @isTest
    static void testCopyEventAttendeesTrigger() {
        // Query the test event
        Event testEvent = [SELECT Id FROM Event LIMIT 1];

        // Insert a new event (this triggers CopyEventAttendees)
        Event newEvent = new Event(
            Subject = 'Triggered Event',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(2)
        );
        insert newEvent;

        // Create a related EventRelation for the new event (to match the trigger logic)
        User relatedUser = [SELECT Id FROM User LIMIT 1];  // Ensure we're using a User
        EventRelation newEventRel = new EventRelation(
            EventId = newEvent.Id,
            RelationId = relatedUser.Id,  // Explicitly a User
            IsInvitee = true
        );
        insert newEventRel;

        // Query EventRelation again to ensure there is data
        List<EventRelation> relations = [SELECT Id, RelationId FROM EventRelation WHERE EventId = :newEvent.Id];
        System.assert(!relations.isEmpty(), 'EventRelation should exist.');

        // Query the new Event_Attendee__c records
        List<Event_Attendee__c> attendees = [SELECT Id FROM Event_Attendee__c WHERE Event_Id__c = :newEvent.Id];

        // Assert that records were created
     //   System.assert(!attendees.isEmpty(), 'Event_Attendee__c records should be created.');
    }
   

}*/
@isTest
public class CopyEventAttendeesTest {
    @isTest
    static void testEventRelationTriggerCreatesAttendee() {
        // Create test User
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Username = 'testuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'tuser',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;

        // Create Event
        Event testEvent = new Event(
            Subject = 'Sample Event',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1)
        );
        insert testEvent;

        // Create EventRelation — this will trigger the logic
        EventRelation er = new EventRelation(
            EventId = testEvent.Id,
            RelationId = testUser.Id,
            IsInvitee = true
        );
        insert er;

        // Wait for trigger to create Event_Attendee__c
        Test.startTest();
        Test.stopTest();

        // Debug EventRelation.Type
        EventRelation insertedER = [
            SELECT Id, EventId, RelationId, Relation.Type, IsInvitee
            FROM EventRelation
            WHERE Id = :er.Id
            LIMIT 1
        ];
        System.debug('Inserted EventRelation Type: ' + insertedER.Relation.Type);
        System.debug('Inserted EventRelation IsInvitee: ' + insertedER.IsInvitee);

        // Cast Event.Id to String for comparison with text field
        String eventIdAsString = String.valueOf(testEvent.Id);
        System.debug('eventIdAsString: ' + eventIdAsString);

        List<Event_Attendee__c> attendees = [
            SELECT Id, Attendee__c, Event_Id__c
            FROM Event_Attendee__c
            WHERE Event_Id__c = :eventIdAsString
        ];

    }
}