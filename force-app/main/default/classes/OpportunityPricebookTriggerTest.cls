@isTest
public class OpportunityPricebookTriggerTest {

    @testSetup
    static void setupData() {

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Pricebook2 domesticPB = new Pricebook2(
            Name = 'Domestic PB',
            IsActive = true,
            Distribution_Channel__c = '10'
        );
        insert domesticPB;

        Pricebook2 exportPB = new Pricebook2(
            Name = 'Export PB',
            IsActive = true,
            Distribution_Channel__c = '20'
        );
        insert exportPB;

        Sales_Area_Item__c saiDomestic = new Sales_Area_Item__c(
            Account__c = acc.Id,
            Sales_Org__c = '1100',
            Division__c = '10',
            Distribution_Channel__c = '10',
            CurrencyIsoCode = 'INR'
        );
        insert saiDomestic;

        Sales_Area_Item__c saiExport = new Sales_Area_Item__c(
            Account__c = acc.Id,
            Sales_Org__c = '1100',
            Division__c = '10',
            Distribution_Channel__c = '20',
            CurrencyIsoCode = 'EUR'
        );
        insert saiExport;
    }

    @isTest
    static void testDomesticUserPricebookAssignment() {

        User u = [SELECT Id, Division__c FROM User WHERE Id = :UserInfo.getUserId()];
        u.Division__c = 'Domestic';
        update u;

        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();

        Opportunity opp = new Opportunity(
            Name = 'Domestic Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today()
        );
        insert opp;

        Test.stopTest();
    }

    @isTest
    static void testExportUserPricebookAssignment() {

        User u = [SELECT Id, Division__c FROM User WHERE Id = :UserInfo.getUserId()];
        u.Division__c = 'Export';
        update u;

        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();

        Opportunity opp = new Opportunity(
            Name = 'Export Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today()
        );
        insert opp;

        Test.stopTest();
    }

    @isTest
    static void testBlankDivision() {

        User u = [SELECT Id, Division__c FROM User WHERE Id = :UserInfo.getUserId()];
        u.Division__c = null;
        update u;

        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();

        Opportunity opp = new Opportunity(
            Name = 'Blank Division',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today()
        );

        try {
            insert opp;
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    @isTest
    static void testNoSalesAreaItem() {

        User u = [SELECT Id, Division__c FROM User WHERE Id = :UserInfo.getUserId()];
        u.Division__c = 'Domestic';
        update u;

        Account acc = new Account(Name = 'No SAI');
        insert acc;

        Test.startTest();

        Opportunity opp = new Opportunity(
            Name = 'No SAI Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today()
        );

        try {
            insert opp;
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    @isTest
    static void testAlreadyHasPricebook() {

        User u = [SELECT Id, Division__c FROM User WHERE Id = :UserInfo.getUserId()];
        u.Division__c = 'Domestic';
        update u;

        Account acc = [SELECT Id FROM Account LIMIT 1];

        Pricebook2 pb = [
            SELECT Id
            FROM Pricebook2
            WHERE Distribution_Channel__c = '10'
            LIMIT 1
        ];

        Test.startTest();

        Opportunity opp = new Opportunity(
            Name = 'Already PB',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            Pricebook2Id = pb.Id
        );

        insert opp;

        Test.stopTest();
    }
}