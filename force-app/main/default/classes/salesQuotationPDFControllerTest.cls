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

    
    Opportunity opp = new Opportunity(Name = 'Test Opportunity', StageName = 'Prospecting', CloseDate = Date.today());
    insert opp;

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
        Payment_Terms__c = 'Open Credit upto 180 days'
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

}