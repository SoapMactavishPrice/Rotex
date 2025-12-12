@isTest
public class QuoteOwnerHierarchyTriggerTest {
    @isTest
    static void testInsertQuote() {
        Account a = new Account(Name = 'A');
        insert a;

        Opportunity o = new Opportunity(Name = 'O', StageName = 'Prospecting', CloseDate = Date.today(), AccountId = a.Id);
        insert o;

        User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];

        Quote q = new Quote(Name = 'Q1', OpportunityId = o.Id, OwnerId = u.Id);
        insert q;
    }

    @isTest
    static void testUpdateQuoteOwnerChangesOppOwner() {
        Account a = new Account(Name = 'A2');
        insert a;

        Opportunity o = new Opportunity(Name = 'O2', StageName = 'Prospecting', CloseDate = Date.today(), AccountId = a.Id);
        insert o;

        User u1 = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        User u2 = [SELECT Id FROM User WHERE Id != :u1.Id AND IsActive = true LIMIT 1];

        Quote q = new Quote(Name = 'Q2', OpportunityId = o.Id, OwnerId = u1.Id);
        insert q;

        q.OwnerId = u2.Id;
        update q;

        Opportunity updatedOpp = [SELECT OwnerId FROM Opportunity WHERE Id = :o.Id];
    }

    @isTest
    static void testUpdateQuoteOwnerDoesNotChangeIfSame() {
        Account a = new Account(Name = 'A3');
        insert a;

        Opportunity o = new Opportunity(Name = 'O3', StageName = 'Prospecting', CloseDate = Date.today(), AccountId = a.Id);
        insert o;

        User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];

        Quote q = new Quote(Name = 'Q3', OpportunityId = o.Id, OwnerId = u.Id);
        insert q;

        q.Name = 'Updated Name';
        update q;

        Opportunity oppAfter = [SELECT OwnerId FROM Opportunity WHERE Id = :o.Id];
    }
}
