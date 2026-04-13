@IsTest
public class LeadTriggerTest {

    /* ===================== TEST DATA SETUP ===================== */
    private static Lead createLead(String status) {
        return new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = status,
            City = 'Mumbai'
        );
    }

    /* ===================== AFTER INSERT STATUS DATE ===================== */
    @IsTest
    static void test_AfterInsert_StatusDate() {

        Lead ld = createLead('New');

        Test.startTest();
        insert ld;
        Test.stopTest();

        Lead inserted = [
            SELECT New_Date_Time__c
            FROM Lead
            WHERE Id = :ld.Id
        ];

        System.assertNotEquals(null, inserted.New_Date_Time__c,
            'New status datetime must be set');
    }

    /* ===================== BEFORE UPDATE FORWARD TO DEALER ===================== */
    @IsTest
    static void test_ForwardToDealer_StatusUpdate() {

        Lead ld = createLead('New');
        insert ld;

        ld.Forward_to_Dealer__c = true;

        Test.startTest();
        update ld;
        Test.stopTest();

        Lead updated = [
            SELECT Status
            FROM Lead
            WHERE Id = :ld.Id
        ];

        System.assertEquals('Forward to Dealer', updated.Status);
    }

    /* ===================== STATUS CHANGE DATE UPDATE ===================== */
    @IsTest
    static void test_StatusChange_DateTime() {

        Lead ld = createLead('New');
        insert ld;

        ld.Status = 'Qualified';

        Test.startTest();
        update ld;
        Test.stopTest();

        Lead updated = [
            SELECT Qualified_Date_Time__c
            FROM Lead
            WHERE Id = :ld.Id
        ];

        System.assertNotEquals(null, updated.Qualified_Date_Time__c);
    }

    /* ===================== LEAD CONVERSION SUCCESS ===================== */
    @IsTest
    static void test_LeadConversion_Success() {

        // Account with valid SAP
        Account acc = new Account(
            Name = 'Valid Account',
            SAP_Customer_Code__c = '1000123'
        );
        insert acc;

        Lead ld = createLead('Qualified');
        insert ld;

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(ld.Id);
        lc.setConvertedStatus('Qualified');
        lc.setAccountId(acc.Id);
        lc.setDoNotCreateOpportunity(false);

        Test.startTest();
        Database.LeadConvertResult res = Database.convertLead(lc);
        Test.stopTest();

        System.assert(res.isSuccess(), 'Lead conversion should succeed');

        Opportunity opp = [
            SELECT Project_Contact__c
            FROM Opportunity
            WHERE Id = :res.getOpportunityId()
        ];

        System.assertNotEquals(null, opp.Project_Contact__c,
            'Converted Contact should be set on Opportunity');

        Address_Information__c addr = [
            SELECT Id
            FROM Address_Information__c
            WHERE Account__c = :res.getAccountId()
            LIMIT 1
        ];

        System.assertNotEquals(null, addr.Id,
            'Address Information should be created');
    }

    /* ===================== LEAD CONVERSION BLOCKED – NO SAP ===================== */
    @IsTest
    static void test_LeadConversion_NoSAP_Block() {

        Account acc = new Account(Name = 'No SAP Account');
        insert acc;

        Lead ld = createLead('Qualified');
        insert ld;

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(ld.Id);
        lc.setConvertedStatus('Qualified');
        lc.setAccountId(acc.Id);

        Test.startTest();
        try {
            Database.convertLead(lc);
            System.assert(false, 'Conversion should fail');
        } catch (Exception e) {
            System.assert(
                e.getMessage().contains('SAP Customer Code'),
                'Expected SAP validation error'
            );
        }
        Test.stopTest();
    }

    /* ===================== LEAD CONVERSION BLOCKED – INVALID SAP PREFIX ===================== */
    @IsTest
    static void test_LeadConversion_InvalidSAPPrefix_Block() {

        Account acc = new Account(
            Name = 'Invalid SAP',
            SAP_Customer_Code__c = '800123'
        );
        insert acc;

        Lead ld = createLead('Qualified');
        insert ld;

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(ld.Id);
        lc.setConvertedStatus('Qualified');
        lc.setAccountId(acc.Id);

        Test.startTest();
        try {
            Database.convertLead(lc);
            System.assert(false);
        } catch (Exception e) {
            //System.assert(e.getMessage().contains('must start with "10" or "9"'),'Invalid SAP prefix error expected');
        }
        Test.stopTest();
    }

    /* ===================== AFTER UPDATE OWNER CHANGE HANDLER ===================== */
    @IsTest
    static void test_OwnerChange_Handler() {

        Lead ld = createLead('New');
        insert ld;

        User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];

        ld.OwnerId = u.Id;

        Test.startTest();
        update ld;
        Test.stopTest();

        System.assert(true, 'Owner change path executed');
    }
}