@isTest
public class ComplaintControllerTest {
    
    @testSetup
    static void setupTestData() {
        // Create an Account
        Account acc = new Account(Name = 'Test Partner Account');
        insert acc;
        
        // Create a Contact
        Contact con = new Contact(LastName = 'Test Contact', AccountId = acc.Id);
        insert con;
        
        // Create a Product
        Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
        insert prod;
        
        // Create a Case
        Case testCase = new Case(
            Subject = 'Test Case',
            Description = 'Test Description',
            AccountId = acc.Id,
            ContactId = con.Id,
            Status = 'New',
            Priority = 'High',
            Origin = 'CP Portal'
        );
        insert testCase;
        
        // Create a Case Comment
        CaseComment cc = new CaseComment(ParentId = testCase.Id, CommentBody = 'Test Comment');
        insert cc;
    }
    
    @isTest
    static void testGetMyCases() {
        Test.startTest();
        List<Case> cases = ComplaintController.getMyCases();
        Test.stopTest();
        
        System.assertNotEquals(null, cases, 'Cases list should not be null');
        System.assertEquals(1, cases.size(), 'Should return 1 case');
    }
    
    @isTest
    static void testGetCaseComments() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        List<CaseComment> comments = ComplaintController.getCaseComments(c.Id);
        Test.stopTest();
        
        System.assertEquals(1, comments.size(), 'Should return 1 case comment');
    }
    
    @isTest
    static void testCreateComplaint() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        Map<String, Object> caseData = new Map<String, Object>{
            'Subject' => 'New Test Case',
            'Description' => 'New Description',
            'Priority' => 'Low',
            'Status' => 'New',
            'AccountId' => acc.Id,
            'ContactId' => con.Id,
            'Resolution__c' => 'Test Resolution'
        };
        
        Test.startTest();
        Id caseId = ComplaintController.createComplaint(caseData);
        Test.stopTest();
        
        System.assertNotEquals(null, caseId, 'Case ID should not be null');
        Case createdCase = [SELECT Id, Subject, Resolution__c FROM Case WHERE Id = :caseId];
        System.assertEquals('New Test Case', createdCase.Subject, 'Subject should match');
        System.assertEquals('Test Resolution', createdCase.Resolution__c, 'Custom field should match');
    }
    
    @isTest
    static void testGetAllCasePicklists() {
        Test.startTest();
        Map<String, List<Map<String, String>>> picklists = ComplaintController.getAllCasePicklists();
        Test.stopTest();
        
        System.assertNotEquals(null, picklists, 'Picklists should not be null');
        System.assert(picklists.containsKey('Status'), 'Should contain Status picklist');
    }
    
    @isTest
    static void testGetAvailableAccountsAndContacts() {
        Test.startTest();
        List<Map<String, String>> accounts = ComplaintController.getAvailableAccounts();
        List<Map<String, String>> contacts = ComplaintController.getAvailableContacts();
        Test.stopTest();
        
        System.assert(accounts.size() > 0, 'Accounts list should not be empty');
        System.assert(contacts.size() > 0, 'Contacts list should not be empty');
    }
    
    @isTest
    static void testGetCategoryRelatedData() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        Map<String, List<Map<String, String>>> data = ComplaintController.getCategoryRelatedData(acc.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, data, 'Category data should not be null');
        System.assert(data.containsKey('Product'), 'Should contain Products');
    }
    
    @isTest
    static void testCaseNotes() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        // Add Note
        ComplaintController.NoteWrapper note = ComplaintController.addCaseNote(c.Id, 'This is a test note');
        
        // Get Note
        List<ComplaintController.NoteWrapper> notes = ComplaintController.getCaseNotes(c.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, note, 'Note should be created');
        System.assertEquals(1, notes.size(), 'Should retrieve 1 note');
    }
    
    @isTest
    static void testCaseAttachments() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        // Save Attachment
        ComplaintController.FileWrapper file = ComplaintController.saveCaseAttachment(c.Id, 'test.txt', 'VGVzdCBkYXRh');
        
        // Get Files
        List<ComplaintController.FileWrapper> files = ComplaintController.getCaseFiles(c.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, file, 'File should be created');
        System.assertEquals(1, files.size(), 'Should retrieve 1 file');
    }
    
    @isTest
    static void testExceptions() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        try {
            ComplaintController.addCaseNote(null, 'Test');
            System.assert(false, 'Exception expected');
        } catch (Exception e) {}
        
        try {
            ComplaintController.saveCaseAttachment(null, 'test.txt', 'VGVzdA==');
            System.assert(false, 'Exception expected');
        } catch (Exception e) {}
        
        // Test access denial
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1]; 
        User u = new User(Alias = 'standt', Email='standarduser3@testorg.com', 
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='standarduser3_' + Math.random() + '@testorg.com');
            
        System.runAs(u) {
            try {
                ComplaintController.addCaseNote(c.Id, 'Test');
                System.assert(false, 'Exception expected for unauthorized case operation');
            } catch (Exception e) {
                System.assert(e instanceof AuraHandledException, 'Expected AuraHandledException');
            }
        }
        Test.stopTest();
    }
}