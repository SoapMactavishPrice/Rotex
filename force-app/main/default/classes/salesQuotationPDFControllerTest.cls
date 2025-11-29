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
        Email = 'test@example.com' // Add non-null Email
    );
    insert testQuote;

    QuoteLineItem qli = new QuoteLineItem(QuoteId = testQuote.Id, PricebookEntryId = standardPricebookEntry.Id, Quantity = 10, UnitPrice = 100);
    insert qli;
}


    @isTest
    static void testInitialization() {
        Test.startTest();
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        ApexPages.currentPage().getParameters().put('id', testQuote.Id);
        salesQuotationPDFController controller = new salesQuotationPDFController();
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

        System.assertEquals('/' + testQuote.Id, result.getUrl(), 'Save should redirect to the Quote record page.');
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

        System.assertEquals('/' + testQuote.Id, result.getUrl(), 'Save and Send should redirect to the Quote record page.');
    }

    @isTest
    static void testCancel() {
        Test.startTest();
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        ApexPages.currentPage().getParameters().put('id', testQuote.Id);
        salesQuotationPDFController controller = new salesQuotationPDFController();

        PageReference result = controller.cancel();
        Test.stopTest();

        System.assertEquals('/' + testQuote.Id, result.getUrl(), 'Cancel should redirect to the Quote record page.');
    }
}