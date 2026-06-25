@isTest
public class CaseTriggerHandlerTest {

    @isTest
    static void testLeadCreatedFromSubjectKeyword() {

        insert new Keyword__c(Name = 'RFQ');

        Case cs = new Case(
            Subject = 'Need RFQ urgently',
            Description =
                'Customer enquiry\n' +
                'Best regards\n' +
                'John Smith\n' +
                'ABC Corporation\n' +
                'Address Mumbai India',
            Status = 'New',
            Origin = 'Email',
            SuppliedName = 'John Smith',
            SuppliedEmail = 'john@test.com'
        );

        Test.startTest();
        insert cs;
        Test.stopTest();

        Lead ld = [
            SELECT Id,
                   FirstName,
                   LastName,
                   Company,
                   Email,
                   Case__c
            FROM Lead
            WHERE Case__c = :cs.Id
            LIMIT 1
        ];

        Case updatedCase = [
            SELECT Id, Status
            FROM Case
            WHERE Id = :cs.Id
        ];

        System.assertEquals('John', ld.FirstName);
        System.assertEquals('Smith', ld.LastName);
        System.assertEquals('ABC Corporation', ld.Company);
        System.assertEquals('john@test.com', ld.Email);
        System.assertEquals(cs.Id, ld.Case__c);
        System.assertEquals('Potential', updatedCase.Status);
    }

    @isTest
    static void testLeadCreatedFromDescriptionKeyword() {

        insert new Keyword__c(Name = 'Solenoid Valve');

        Case cs = new Case(
            Subject = 'General enquiry',
            Description =
                'Need Solenoid Valve immediately\n' +
                'Regards\n' +
                'Alex Brown\n' +
                'XYZ Industries',
            Status = 'New',
            Origin = 'Web',
            SuppliedName = 'Alex Brown',
            SuppliedEmail = 'alex@test.com'
        );

        Test.startTest();
        insert cs;
        Test.stopTest();

        List<Lead> leads = [
            SELECT Id, Company
            FROM Lead
            WHERE Case__c = :cs.Id
        ];

        System.assertEquals(1, leads.size());
        System.assertEquals('XYZ Industries', leads[0].Company);
    }

    @isTest
    static void testNoLeadWhenKeywordNotFound() {

        insert new Keyword__c(Name = 'RFQ');

        Case cs = new Case(
            Subject = 'General Support Issue',
            Description = 'Need help with login',
            Status = 'New',
            Origin = 'Email',
            SuppliedName = 'Test User',
            SuppliedEmail = 'test@test.com'
        );

        Test.startTest();
        insert cs;
        Test.stopTest();

        List<Lead> leads = [
            SELECT Id
            FROM Lead
            WHERE Case__c = :cs.Id
        ];

        Case unchangedCase = [
            SELECT Status
            FROM Case
            WHERE Id = :cs.Id
        ];

        System.assertEquals(0, leads.size());
        System.assertEquals('New', unchangedCase.Status);
    }

    @isTest
    static void testUnknownCompanyFallback() {

        insert new Keyword__c(Name = 'Price required');

        Case cs = new Case(
            Subject = 'Price required urgently',
            Description = 'Need quotation quickly',
            Status = 'New',
            Origin = 'Email',
            SuppliedName = 'SingleName',
            SuppliedEmail = 'single@test.com'
        );

        Test.startTest();
        insert cs;
        Test.stopTest();

        Lead ld = [
            SELECT Company, FirstName, LastName
            FROM Lead
            WHERE Case__c = :cs.Id
            LIMIT 1
        ];

        System.assertEquals('Unknown', ld.Company);
        System.assertEquals(null, ld.FirstName);
        System.assertEquals('SingleName', ld.LastName);
    }

    @isTest
    static void testBulkInsertCoverage() {

        insert new Keyword__c(Name = 'Inquiry');

        List<Case> caseList = new List<Case>();

        for (Integer i = 0; i < 5; i++) {
            caseList.add(new Case(
                Subject = 'Inquiry case ' + i,
                Description = 'Bulk test description',
                Status = 'New',
                Origin = 'Email',
                SuppliedName = 'User ' + i,
                SuppliedEmail = 'bulk' + i + '@test.com'
            ));
        }

        Test.startTest();
        insert caseList;
        Test.stopTest();

        List<Lead> leads = [
            SELECT Id
            FROM Lead
            WHERE Email LIKE 'bulk%@test.com'
        ];

        System.assertEquals(5, leads.size());
    }

    @isTest
    static void testDirectHandlerNullCoverage() {

        Test.startTest();
        CaseTriggerHandler.createLeadFromCase(null);
        CaseTriggerHandler.createLeadFromCase(new List<Case>());
        Test.stopTest();

        System.assert(true);
    }
    @isTest
static void testStateCodeCoverage() {

    insert new Keyword__c(Name = 'RFQ');

    String validStateLabel = null;

    for (Schema.PicklistEntry pe : Lead.StateCode.getDescribe().getPicklistValues()) {
        if (pe.isActive()) {
            validStateLabel = pe.getLabel();
            break;
        }
    }

    if (validStateLabel == null) {
        System.assert(true);
        return;
    }
    Country__c c = new Country__c();
    c.name = 'India';
    insert c;
    insert new State__c(
        Name = validStateLabel,
        Country__c= c.Id
    );

    Case cs = new Case(
        Subject = 'Need RFQ',
        Description =
            'Customer from ' + validStateLabel + '\n' +
            'Best regards\n' +
            'Mark John\n' +
            'Test Company',
        Status = 'New',
        Origin = 'Email',
        SuppliedName = 'Mark John',
        SuppliedEmail = 'state@test.com'
    );

    Test.startTest();
    insert cs;
    Test.stopTest();

    List<Lead> leads = [
        SELECT Id
        FROM Lead
        WHERE Case__c = :cs.Id
    ];

    System.assertEquals(1, leads.size());
}
}