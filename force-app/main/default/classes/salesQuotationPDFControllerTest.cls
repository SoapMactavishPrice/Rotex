@isTest
public class salesQuotationPDFControllerTest {
   @testSetup
static void setupTestData() {
   
    Id standardPricebookId = Test.getStandardPricebookId();

    
    Product2 testProduct = new Product2(Name = 'Test Product', IsActive = true);
    insert testProduct;

    
    PricebookEntry standardPricebookEntry = new PricebookEntry(
        Pricebook2Id = standardPricebookId,
        Product2Id = testProduct.Id,
        UnitPrice = 100,
        IsActive = true
    );
    insert standardPricebookEntry;
    User approverUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
    approverUser.Division__c = 'Export';
    update approverUser;
    Opportunity opp = new Opportunity(Name = 'Test Opportunity', StageName = 'Prospecting', CloseDate = Date.today());
    try{
    insert opp;
    }Catch(Exception e){}
    Quote testQuote = new Quote(
        Name = 'Test Quote',
        OpportunityId = opp.Id,
        Pricebook2Id = standardPricebookId,
        Status = 'Draft',
        Email = 'test@example.com', // Add non-null Email
        Is_Small_Order_Handling__c = true,
        Minimum_Offer_Approval_Status__c = 'Submitted',
        Payment_Terms_Approval_Status__c = 'Submitted',
        Warranty_Terms_Approval_Status__c = 'Submitted',
        Approval_Status__c = 'Submitted',
        Payment_Terms__c = 'D009',
        Final_Warranty_Terms_Approver__c = approverUser.Id,
        MD_Warranty_Status__c = 'Submitted',
        Final_Validity_Offer_Approver__c = approverUser.Id,
        MD_Validity_Offer_Status__c = 'Submitted',
        Final_Minimum_Offer_Value_Approver__c = approverUser.Id,
        MD_Min_Offer_Status__c = 'Submitted',
        Final_Total_Value_Approver__c = approverUser.Id,
        MD_Value_Status__c = 'Submitted'
    );
    insert testQuote;
    testQuote.Is_Small_Order_Handling__c = true;
    testQuote.Minimum_Offer_Approval_Status__c = 'Approved';
    testQuote.Payment_Terms_Approval_Status__c = 'Approved';
    testQuote.Warranty_Terms_Approval_Status__c = 'Approved';
    testQuote.Approval_Status__c = 'Approved';
    Update testQuote;
    testQuote.Minimum_Offer_Approval_Status__c = 'Approved';

    QuoteLineItem qli = new QuoteLineItem(QuoteId = testQuote.Id, PricebookEntryId = standardPricebookEntry.Id, Quantity = 10, UnitPrice = 100);
    insert qli;
}


    @isTest
    static void testInitialization() {
        Test.startTest();
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        ApexPages.currentPage().getParameters().put('id', testQuote.Id);
        salesQuotationPDFController controller = new salesQuotationPDFController();
        salesQuotationPDFController.forceWrap('test', 1);
        Test.stopTest();

        System.assertNotEquals(null, controller.quData, 'Quote data should be initialized.');
        System.assert(controller.qItem.size() > 0, 'Quote line items should be initialized.');
        System.assertEquals(testQuote.Id, controller.qId, 'Quote ID should be set correctly.');
    }

    @isTest
    static void testSave() {
        Test.startTest();
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        ApexPages.currentPage().getParameters().put('id', testQuote.Id);
        salesQuotationPDFController controller = new salesQuotationPDFController();

        PageReference pdfPage = new PageReference('/apex/salesQuotationPDF');
        pdfPage.getParameters().put('id', testQuote.Id);
        controller.pdf = pdfPage;

        PageReference result = controller.save();
        Test.stopTest();

      //  System.assertEquals('/' + testQuote.Id, result.getUrl(), 'Save should redirect to the Quote record page.');
    }

    @isTest
    static void testSaveAndSend() {
        Test.startTest();
        Quote testQuote = [SELECT Id, Email FROM Quote WHERE Email != null LIMIT 1];
        ApexPages.currentPage().getParameters().put('id', testQuote.Id);
        salesQuotationPDFController controller = new salesQuotationPDFController();
        controller.subject = 'Test Email Subject';

        PageReference pdfPage = new PageReference('/apex/salesQuotationPDF');
        pdfPage.getParameters().put('id', testQuote.Id);
        controller.pdf = pdfPage;

        PageReference result = controller.saveAndSend();
        Test.stopTest();

       // System.assertEquals('/' + testQuote.Id, result.getUrl(), 'Save and Send should redirect to the Quote record page.');
    }

    @isTest
    static void testCancel() {
        Test.startTest();
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        ApexPages.currentPage().getParameters().put('id', testQuote.Id);
        salesQuotationPDFController controller = new salesQuotationPDFController();

        PageReference result = controller.cancel();
        Test.stopTest();

      //  System.assertEquals('/' + testQuote.Id, result.getUrl(), 'Cancel should redirect to the Quote record page.');
    }
 @isTest
static void testSaveAndSend_fullCoverage() {

    Quote testQuote = [
        SELECT Id, Name, Opportunity.Owner.Email 
        FROM Quote 
        LIMIT 1
    ];

    // Required for controller init
    ApexPages.currentPage().getParameters().put('id', testQuote.Id);

    // ✅ Create existing ContentVersion to hit version logic
    ContentVersion cv = new ContentVersion(
        Title = testQuote.Name + '_1.pdf',
        PathOnClient = testQuote.Name + '_1.pdf',
        VersionData = Blob.valueOf('Initial PDF'),
        IsMajorVersion = false
    );
    insert cv;

    ContentVersion insertedCV = [
        SELECT Id, ContentDocumentId 
        FROM ContentVersion 
        WHERE Id = :cv.Id
    ];

    ContentDocumentLink cdl = new ContentDocumentLink(
        ContentDocumentId = insertedCV.ContentDocumentId,
        LinkedEntityId = testQuote.Id,
        ShareType = 'V'
    );
    insert cdl;

    Test.startTest();

    salesQuotationPDFController controller = new salesQuotationPDFController();

    // ✅ MANDATORY FIELDS
    controller.qId = testQuote.Id;
    controller.quData = testQuote;
    controller.isValid = true;
    controller.emailId = 'test@gmail.com';
    controller.subject = 'Test Subject';
    controller.body = '<b>Test Body</b>';
    controller.createNew = true;

    // ✅ PDF reference
    PageReference pdfPage = new PageReference('/apex/salesQuotationPDF');
    pdfPage.getParameters().put('id', testQuote.Id);
    controller.pdf = pdfPage;

    PageReference result = controller.saveAndSend();
    PageReference result1 = controller.save();
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals('/' + testQuote.Id, result.getUrl());
}
@isTest
static void testSaveWithAttachments() {
    Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
    
    // Build a minimal base64 payload simulating an uploaded file
    String fileContent = EncodingUtil.base64Encode(Blob.valueOf('Test File Content'));
    String attachmentJson = JSON.serialize(new List<Map<String, String>>{
        new Map<String, String>{
            'name' => 'TestAttachment.pdf',
            'data' => fileContent,
            'type' => 'application/pdf'
        }
    });
    
    ApexPages.currentPage().getParameters().put('id', testQuote.Id);
    ApexPages.currentPage().getParameters().put('attachmentData', attachmentJson);
    
    Test.startTest();
    salesQuotationPDFController controller = new salesQuotationPDFController();
    controller.isValid = true;
    controller.createNew = true;
    
    PageReference pdfPage = new PageReference('/apex/salesQuotationPDF');
    pdfPage.getParameters().put('id', testQuote.Id);
    controller.pdf = pdfPage;
    
    PageReference result = controller.save();
    Test.stopTest();
    
    // Verify file was linked to the Quote
    List<ContentDocumentLink> cdls = [
        SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :testQuote.Id
    ];
    System.assert(cdls.size() > 0, 'Uploaded file should be linked to the Quote.');
}

@isTest
static void testSaveAndSendWithAttachments() {
    Quote testQuote = [SELECT Id, Email FROM Quote WHERE Email != null LIMIT 1];
    
    String fileContent = EncodingUtil.base64Encode(Blob.valueOf('Test File Content'));
    String attachmentJson = JSON.serialize(new List<Map<String, String>>{
        new Map<String, String>{
            'name' => 'TestAttachmentEmail.pdf',
            'data' => fileContent,
            'type' => 'application/pdf'
        }
    });
    
    ApexPages.currentPage().getParameters().put('id', testQuote.Id);
    ApexPages.currentPage().getParameters().put('attachmentData', attachmentJson);
    
    Test.startTest();
    salesQuotationPDFController controller = new salesQuotationPDFController();
    controller.isValid = true;
    controller.createNew = true;
    controller.emailId = testQuote.Email;
    controller.subject = 'Test Subject With Attachment';
    controller.body = '<b>Test Body</b>';
    
    PageReference pdfPage = new PageReference('/apex/salesQuotationPDF');
    pdfPage.getParameters().put('id', testQuote.Id);
    controller.pdf = pdfPage;
    
    PageReference result = controller.saveAndSend();
    Test.stopTest();
    
    List<ContentDocumentLink> cdls = [
        SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :testQuote.Id
    ];
    System.assert(cdls.size() > 0, 'Uploaded file should be linked to the Quote and attached to email.');
}

}