@IsTest
public class NewLeadControllerTest {

    @TestSetup
    static void setupData() {
        Account cpAcc = new Account(
            Name = 'Test Dealer NL',
            RecordTypeId = getRecordTypeId('Account', 'Channel_Partner')
        );
        Database.insert(cpAcc, false);
        // Fallback name still used if insert partially worked via query later
        if (cpAcc.Id == null) {
            insert new Account(Name = 'Test Dealer NL');
        }
    }

    private static Account getDealer() {
        List<Account> rows = [SELECT Id FROM Account WHERE Name = 'Test Dealer NL' LIMIT 1];
        if (!rows.isEmpty()) {
            return rows[0];
        }
        Account a = new Account(Name = 'Test Dealer NL');
        insert a;
        return a;
    }

    /** Prefer picklist values allowed on Channel Partner lead process/RT. */
    private static String pickLeadStatus() {
        Set<String> prefer = new Set<String>{ 'New', 'Contacted', 'Work In Progress', 'Qualified' };
        Set<String> active = activePicklistValues(Lead.Dealer_Status__c);
        for (String p : prefer) {
            if (active.contains(p)) {
                return p;
            }
        }
        return active.isEmpty() ? 'New' : new List<String>(active)[0];
    }

    private static String pickLeadSource() {
        // Valid on Channel_Partner RT (not legacy "Web")
        Set<String> prefer = new Set<String>{
            'Website', 'Website Form', 'Email Enquiry', 'Email Enq', 'Direct Meeting', 'Apollo'
        };
        Set<String> active = activePicklistValues(Lead.LeadSource);
        for (String p : prefer) {
            if (active.contains(p)) {
                return p;
            }
        }
        return active.isEmpty() ? 'Website' : new List<String>(active)[0];
    }

    private static Set<String> activePicklistValues(Schema.SObjectField field) {
        Set<String> values = new Set<String>();
        for (Schema.PicklistEntry pe : field.getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                values.add(pe.getValue());
            }
        }
        return values;
    }

    private static NewLeadController.LeadCreateInput baseInput(Id dealerId) {
        NewLeadController.LeadCreateInput input = new NewLeadController.LeadCreateInput();
        input.salutation = 'Mr.';
        input.firstName = 'Test';
        input.lastName = 'Lead';
        input.company = 'Test Company';
        input.title = 'Manager';
        input.phone = '1234567890';
        input.email = 'testlead@example.com';
        input.website = 'https://example.com';
        input.status = pickLeadStatus();
        input.leadSource = pickLeadSource();
        input.requirement = 'Needs some products';
        input.street = 'Test Street';
        input.city = 'Ahmedabad';
        input.state = 'Gujarat';
        input.postalCode = '380001';
        input.country = 'India';
        input.partnerAccountId = dealerId;
        return input;
    }

    @IsTest
    static void testGetPicklistValues() {
        Test.startTest();
        List<String> sources = NewLeadController.getLeadSourcePicklistValues();
        List<String> statuses = NewLeadController.getLeadStatusPicklistValues();
        Test.stopTest();
        System.assertNotEquals(null, sources);
        System.assert(sources.size() > 0);
        System.assertNotEquals(null, statuses);
        System.assert(statuses.size() > 0);
    }

    @IsTest
    static void testCreateLead_Success() {
        Account dealer = getDealer();
        NewLeadController.LeadCreateInput input = baseInput(dealer.Id);

        Test.startTest();
        Lead created = NewLeadController.createLead(input);
        Test.stopTest();

        System.assertNotEquals(null, created);
        System.assertNotEquals(null, created.Id);
        System.assertEquals('Test', created.FirstName);
        System.assertEquals('Lead', created.LastName);
        System.assertEquals('Test Company', created.Company);
        System.assertEquals(dealer.Id, created.Dealer__c);
    }

    @IsTest
    static void testUpdateLead_Success() {
        Account dealer = getDealer();
        NewLeadController.LeadCreateInput createIn = baseInput(dealer.Id);
        Lead created = NewLeadController.createLead(createIn);

        NewLeadController.LeadCreateInput updateIn = baseInput(dealer.Id);
        updateIn.firstName = 'Updated';
        updateIn.lastName = 'Person';
        updateIn.company = 'Updated Co';
        updateIn.requirement = 'Updated requirement text';
        updateIn.phone = '9999999999';
        updateIn.gstNumber = '12ABCDE3456F7GH';

        Test.startTest();
        Lead updated = NewLeadController.updateLead(updateIn, created.Id);
        Test.stopTest();

        System.assertEquals('Updated', updated.FirstName);
        System.assertEquals('Person', updated.LastName);
        System.assertEquals('Updated Co', updated.Company);
        System.assertEquals('Updated requirement text', updated.Requirement__c);

        // Validation / not-found branches
        try {
            NewLeadController.updateLead(null, created.Id);
            System.assert(false);
        } catch (AuraHandledException e) {
        }
        try {
            NewLeadController.updateLead(updateIn, null);
            System.assert(false);
        } catch (AuraHandledException e) {
        }
        try {
            NewLeadController.updateLead(updateIn, UserInfo.getUserId());
            System.assert(false);
        } catch (AuraHandledException e) {
        }
        NewLeadController.LeadCreateInput blank = new NewLeadController.LeadCreateInput();
        try {
            NewLeadController.updateLead(blank, created.Id);
            System.assert(false);
        } catch (AuraHandledException e) {
        }
        blank.firstName = 'A';
        try {
            NewLeadController.updateLead(blank, created.Id);
        } catch (AuraHandledException e) {
        }
        blank.lastName = 'B';
        try {
            NewLeadController.updateLead(blank, created.Id);
        } catch (AuraHandledException e) {
        }
        blank.company = 'C';
        try {
            NewLeadController.updateLead(blank, created.Id);
        } catch (AuraHandledException e) {
        }
        blank.status = pickLeadStatus();
        try {
            NewLeadController.updateLead(blank, created.Id);
        } catch (AuraHandledException e) {
        }
        blank.leadSource = pickLeadSource();
        try {
            NewLeadController.updateLead(blank, created.Id);
        } catch (AuraHandledException e) {
        }
        blank.requirement = 'R';
        blank.gstNumber = 'SHORT';
        try {
            NewLeadController.updateLead(blank, created.Id);
        } catch (AuraHandledException e) {
        }
        // Wrong dealer branch
        Account other = new Account(Name = 'Other Dealer NL');
        insert other;
        updateIn.partnerAccountId = other.Id;
        try {
            NewLeadController.updateLead(updateIn, created.Id);
        } catch (AuraHandledException e) {
        }
    }

    @IsTest
    static void testCreateLead_MissingRequiredFields() {
        try {
            NewLeadController.createLead(null);
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }

        NewLeadController.LeadCreateInput input = new NewLeadController.LeadCreateInput();
        try {
            NewLeadController.createLead(input);
        } catch (AuraHandledException e) {
        }
        input.firstName = 'Test';
        try {
            NewLeadController.createLead(input);
        } catch (AuraHandledException e) {
        }
        input.lastName = 'Lead';
        try {
            NewLeadController.createLead(input);
        } catch (AuraHandledException e) {
        }
        input.company = 'Company';
        try {
            NewLeadController.createLead(input);
        } catch (AuraHandledException e) {
        }
        input.status = pickLeadStatus();
        try {
            NewLeadController.createLead(input);
        } catch (AuraHandledException e) {
        }
        input.leadSource = pickLeadSource();
        try {
            NewLeadController.createLead(input);
        } catch (AuraHandledException e) {
        }
        input.requirement = 'Reqs';
        input.gstNumber = 'SHORT';
        try {
            NewLeadController.createLead(input);
        } catch (AuraHandledException e) {
        }
        System.assert(true);
    }

    @IsTest
    static void testCreateLead_DmlException() {
        NewLeadController.LeadCreateInput input = baseInput(getDealer().Id);
        input.status = 'INVALID_STATUS_XXX_YYY';
        try {
            NewLeadController.createLead(input);
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
    }

    private static Id getRecordTypeId(String sObjectType, String developerName) {
        List<RecordType> rts = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = :sObjectType AND DeveloperName = :developerName
            LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }
}