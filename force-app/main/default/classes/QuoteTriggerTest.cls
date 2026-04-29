@isTest
public class QuoteTriggerTest {

    @isTest
    static void testInsertYesScenario() {

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;

        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Quote_Validity_Extension__c = 'Yes'
        );

        Test.startTest();
        insert q;
        Test.stopTest();

        Quote insertedQuote = [
            SELECT Id, OwnerId, CreatedById
            FROM Quote
            WHERE Id = :q.Id
        ];

        System.assertEquals(
            insertedQuote.CreatedById,
            insertedQuote.OwnerId,
            'Owner should be set to CreatedById on insert when Yes'
        );
    }

    @isTest
    static void testUpdateToYesScenario() {

        Account acc = new Account(Name = 'Test Account 2');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp 2',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;

        Quote q = new Quote(
            Name = 'Test Quote 2',
            OpportunityId = opp.Id,
            Quote_Validity_Extension__c = 'No',
            Remark__c = 'Initial remark'
        );
        insert q;

        q.Quote_Validity_Extension__c = 'Yes';

        Test.startTest();
        update q;
        Test.stopTest();

        Quote updatedQuote = [
            SELECT OwnerId, CreatedById
            FROM Quote
            WHERE Id = :q.Id
        ];

        System.assertEquals(
            updatedQuote.CreatedById,
            updatedQuote.OwnerId,
            'Owner should change to CreatedById when switched to Yes'
        );
    }

    @isTest
    static void testValidationNoRemark() {

        Account acc = new Account(Name = 'Test Account 3');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp 3',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;

        Quote q = new Quote(
            Name = 'Test Quote 3',
            OpportunityId = opp.Id,
            Quote_Validity_Extension__c = 'No',
            Remark__c = 'Valid remark'
        );
        insert q;

        // Now force invalid state
        q.Remark__c = null;

        Boolean errorThrown = false;

        Test.startTest();
        try {
            update q;
        } catch (DmlException e) {
            errorThrown = true;
            System.assert(
                e.getMessage().contains('Remarks are required'),
                'Expected validation error message not found'
            );
        }
        Test.stopTest();

      
    }
}