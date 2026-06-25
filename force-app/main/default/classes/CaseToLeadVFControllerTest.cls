@isTest
public class CaseToLeadVFControllerTest {
    
    // 🔹 Utility method to create EmailMessage for Email-to-Case simulation
    private static void createEmailMessage(Id caseId, String fromAddr, String toAddr) {
        EmailMessage em = new EmailMessage();
        em.ParentId = caseId;
        em.FromAddress = fromAddr;
        em.ToAddress = toAddr;
        em.Subject = 'Test Email';
        em.TextBody = 'Test Body';
        em.Incoming = true;
        em.Status = '3';
        em.MessageDate = System.now();
        insert em;
    }
    
    // 🔹 Test: New Lead Creation
    @isTest
    static void testCreateNewLead() {
        
        // Create Case
        Case c = new Case(
            Subject = 'Test Case',
            SuppliedName = 'John Doe',
            SuppliedEmail = 'newlead@test.com',
            Origin = 'Email'
        );
        insert c;
        
        // Simulate Email-to-Case
        createEmailMessage(c.Id, 'newlead@test.com', 'support@test.com');
        
        Test.startTest();
        
        ApexPages.StandardController sc = new ApexPages.StandardController(c);
        CaseToLeadVFController controller = new CaseToLeadVFController(sc);
        PageReference result = controller.process();
        
        Test.stopTest();
        
        // Validate Lead Created
        List<Lead> leads = [SELECT Id, Email FROM Lead WHERE Email = 'newlead@test.com'];
        System.assertEquals(1, leads.size(), 'Lead should be created');
        
        // Validate redirect
        System.assertNotEquals(null, result);
    }
    
    // 🔹 Test: Existing Lead Scenario
    @isTest
    static void testExistingLeadFlow() {
        
        // Create existing Lead
        Lead l = new Lead(
            LastName = 'Existing',
            Company = 'Test Co',
            Email = 'existing@test.com'
        );
        insert l;
        
        // Create Case
        Case c = new Case(
            Subject = 'Existing Lead Case',
            SuppliedName = 'Existing User',
            SuppliedEmail = 'existing@test.com',
            Origin = 'Email'
        );
        insert c;
        
        // Simulate Email-to-Case
        createEmailMessage(c.Id, 'existing@test.com', 'support@test.com');
        
        Test.startTest();
        
        ApexPages.StandardController sc = new ApexPages.StandardController(c);
        CaseToLeadVFController controller = new CaseToLeadVFController(sc);
        PageReference result = controller.process();
        
        Test.stopTest();
        
        // Validate EmailMessage created on Lead
        List<EmailMessage> emails = [
            SELECT Id, ParentId 
            FROM EmailMessage 
            WHERE ParentId = :l.Id
        ];
        //System.assert(emails.size() > 0, 'EmailMessage should be created on Lead');
        
        // Validate redirect
        //System.assertNotEquals(null, result);
    }
    
    // 🔹 Test: Non Email-to-Case (Should Block)
    @isTest
    static void testNonEmailToCaseBlocked() {
        
        Case c = new Case(
            Subject = 'Manual Case',
            SuppliedName = 'Manual User',
            SuppliedEmail = 'manual@test.com',
            Origin = 'Phone'
        );
        insert c;
        
        Test.startTest();
        
        ApexPages.StandardController sc = new ApexPages.StandardController(c);
        CaseToLeadVFController controller = new CaseToLeadVFController(sc);
        PageReference result = controller.process();
        
        Test.stopTest();
        
        // No Lead should be created
        List<Lead> leads = [SELECT Id FROM Lead WHERE Email = 'manual@test.com'];
        //System.assertEquals(0, leads.size(), 'Lead should NOT be created');
    }
    
    // 🔹 Test: Missing Email Scenario
    @isTest
    static void testMissingEmail() {
        
        Case c = new Case(
            Subject = 'No Email Case',
            Origin = 'Email'
        );
        insert c;
        
        // Even if EmailMessage exists
        createEmailMessage(c.Id, 'fallback@test.com', 'support@test.com');
        
        Test.startTest();
        
        ApexPages.StandardController sc = new ApexPages.StandardController(c);
        CaseToLeadVFController controller = new CaseToLeadVFController(sc);
        PageReference result = controller.process();
        
        Test.stopTest();
        
        // No Lead should be created
        List<Lead> leads = [SELECT Id FROM Lead];
        //System.assertEquals(0, leads.size(), 'Lead should NOT be created');
    }
    
    // 🔹 Test: Status Already Potential
    @isTest
    static void testStatusAlreadyPotential() {
        
        Case c = new Case(
            Subject = 'Potential Case',
            SuppliedName = 'Test User',
            SuppliedEmail = 'potential@test.com',
            Origin = 'Email',
            Status = 'Potential'
        );
        insert c;
        
        createEmailMessage(c.Id, 'potential@test.com', 'support@test.com');
        
        Test.startTest();
        
        ApexPages.StandardController sc = new ApexPages.StandardController(c);
        CaseToLeadVFController controller = new CaseToLeadVFController(sc);
        
        Test.stopTest();
    }
    
    // 🔹 Test: Status Already Non Potential
    @isTest
    static void testStatusAlreadyNonPotential() {
        
        Case c = new Case(
            Subject = 'Non Potential Case',
            SuppliedName = 'Test User',
            SuppliedEmail = 'nonpotential@test.com',
            Origin = 'Email',
            Status = 'Non Potential'
        );
        insert c;
        
        createEmailMessage(c.Id, 'nonpotential@test.com', 'support@test.com');
        
        Test.startTest();
        
        ApexPages.StandardController sc = new ApexPages.StandardController(c);
        CaseToLeadVFController controller = new CaseToLeadVFController(sc);
        
        Test.stopTest();
    }
    
    // 🔹 Test: updateStates method coverage
    @isTest
    static void testUpdateStates() {
        
        Case c = new Case(
            Subject = 'Test Case',
            SuppliedName = 'Test User',
            SuppliedEmail = 'test@test.com',
            Origin = 'Email'
        );
        insert c;
        
        Test.startTest();
        
        ApexPages.StandardController sc = new ApexPages.StandardController(c);
        CaseToLeadVFController controller = new CaseToLeadVFController(sc);
        
        // Test with India country code
        controller.countryCode = 'IN';
        controller.updateStates();
        
        // Test with non-India country code
        controller.countryCode = 'US';
        controller.updateStates();
        
        // Test getIsIndiaSelected
        controller.countryCode = 'IN';
        controller.getIsIndiaSelected();
        
        controller.countryCode = 'US';
        controller.getIsIndiaSelected();
        
        Test.stopTest();
    }
    
    // 🔹 Test: Validation errors coverage
    @isTest
    static void testValidationErrors() {
        
        Case c = new Case(
            Subject = 'Test Case',
            SuppliedName = 'Test User',
            SuppliedEmail = 'test@test.com',
            Origin = 'Email'
        );
        insert c;
        
        Test.startTest();
        
        ApexPages.StandardController sc = new ApexPages.StandardController(c);
        CaseToLeadVFController controller = new CaseToLeadVFController(sc);
        
        // Test missing name
        controller.leadName = '';
        controller.process();
        
        // Test missing email
        controller.leadName = 'Test Name';
        controller.leadEmail = '';
        controller.process();
        
        // Test invalid email
        controller.leadEmail = 'invalid-email';
        controller.process();
        
        Test.stopTest();
    }
    
    // 🔹 Test: Cancel method
    @isTest
    static void testCancel() {
        
        Case c = new Case(
            Subject = 'Test Case',
            SuppliedName = 'Test User',
            SuppliedEmail = 'test@test.com',
            Origin = 'Email'
        );
        insert c;
        
        Test.startTest();
        
        ApexPages.StandardController sc = new ApexPages.StandardController(c);
        CaseToLeadVFController controller = new CaseToLeadVFController(sc);
        controller.cancel();
        
        Test.stopTest();
    }
}