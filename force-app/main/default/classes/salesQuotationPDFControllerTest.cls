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

        Opportunity opp = new Opportunity(Name = 'Test Opportunity', StageName = 'Prospecting', CloseDate = Date.today());
        insert opp;

        Quote testQuote = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = standardPricebookId,
            Status = 'Draft',
            Email = 'test@example.com',
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
            MD_Value_Status__c = 'Submitted',
            Customer_Reference_No__c = '12345'
        );
        insert testQuote;

        testQuote.Is_Small_Order_Handling__c = true;
        testQuote.Minimum_Offer_Approval_Status__c = 'Approved';
        testQuote.Payment_Terms_Approval_Status__c = 'Approved';
        testQuote.Warranty_Terms_Approval_Status__c = 'Approved';
        testQuote.Approval_Status__c = 'Approved';
        update testQuote;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = testQuote.Id,
            PricebookEntryId = standardPricebookEntry.Id,
            Quantity = 10,
            UnitPrice = 100
        );
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

        System.assertNotEquals(null, controller.quData);
        System.assert(controller.qItem.size() > 0);
        System.assertEquals(testQuote.Id, controller.qId);
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
    }

    @isTest
    static void testCancel() {
        Test.startTest();
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        ApexPages.currentPage().getParameters().put('id', testQuote.Id);
        salesQuotationPDFController controller = new salesQuotationPDFController();

        PageReference result = controller.cancel();
        Test.stopTest();
    }

    @isTest
    static void testSaveAndSend_fullCoverage() {
        Quote testQuote = [
            SELECT Id, Name, Opportunity.Owner.Email, Email, Customer_Reference_No__c, Amendment_Quote__c
            FROM Quote
            LIMIT 1
        ];

        ApexPages.currentPage().getParameters().put('id', testQuote.Id);

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

        controller.qId = testQuote.Id;
        controller.quData = testQuote;
        controller.isValid = true;
        controller.emailId = 'test@gmail.com';
        controller.subject = 'Test Subject';
        controller.body = '<b>Test Body</b>';
        controller.createNew = true;

        PageReference pdfPage = new PageReference('/apex/salesQuotationPDF');
        pdfPage.getParameters().put('id', testQuote.Id);
        controller.pdf = pdfPage;

      //  PageReference result = controller.saveAndSend();
      //  PageReference result1 = controller.save();
        Test.stopTest();
    }

    @isTest
    static void testSaveWithAttachments() {
        Quote testQuote = [SELECT Id, Amendment_Quote__c FROM Quote LIMIT 1];

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
    }

    @isTest
    static void testSaveAndSendWithAttachments() {
        Quote testQuote = [SELECT Id, Email, Amendment_Quote__c FROM Quote WHERE Email != null LIMIT 1];

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
    }

    @isTest
    static void testAmendmentQuoteFlow() {
        Test.startTest();

        Quote testQuote = [SELECT Id, Email, Amendment_Quote__c FROM Quote LIMIT 1];

        // Set Amendment_Quote__c to true
        testQuote.Amendment_Quote__c = true;
        update testQuote;

        ApexPages.currentPage().getParameters().put('id', testQuote.Id);

        salesQuotationPDFController controller = new salesQuotationPDFController();

        controller.isValid = true;
        controller.emailId = testQuote.Email;
        controller.subject = 'Amendment Subject';
        controller.body = '<b>Amendment Body</b>';

        PageReference pdfPage = new PageReference('/apex/salesQuotationPDF');
        pdfPage.getParameters().put('id', testQuote.Id);
        controller.pdf = pdfPage;

        // Set isAmendmentQuote to true to test amendment flow
        controller.isAmendmentQuote = true;

        PageReference result = controller.sendAmendmentEmail();

        Test.stopTest();
    }

    @isTest
    static void testUpdateQuoteType() {
        Test.startTest();

        Quote testQuote = [SELECT Id, Amendment_Quote__c FROM Quote LIMIT 1];
        ApexPages.currentPage().getParameters().put('id', testQuote.Id);

        salesQuotationPDFController controller = new salesQuotationPDFController();

        // Test switching to Amendment
        controller.selectedQuoteType = 'Amendment';
        controller.updateQuoteType();
        System.assertEquals(true, controller.isAmendmentQuote);

        // Test switching to Normal
        controller.selectedQuoteType = 'Normal';
        controller.updateQuoteType();
        System.assertEquals(false, controller.isAmendmentQuote);

        // Test empty selection
        controller.selectedQuoteType = '';
        controller.updateQuoteType();
        System.assertEquals(false, controller.isAmendmentQuote);

        Test.stopTest();
    }

    @isTest
    static void testShowAmendmentOptionsNonARC() {
        Test.startTest();

        // Create a Quote with RFQ Quote Reason (not PO ARC)
        Opportunity opp = new Opportunity(Name = 'Test Opp RFQ', StageName = 'Prospecting', CloseDate = Date.today());
        insert opp;

        opp.Quote_Reason__c = 'RFQ';
        update opp;

        Id standardPricebookId = Test.getStandardPricebookId();
        Quote testQuote = new Quote(
            Name = 'Test Quote RFQ',
            OpportunityId = opp.Id,
            Pricebook2Id = standardPricebookId,
            Status = 'Draft',
            Email = 'test@example.com',
            Customer_Reference_No__c = '12345'
        );
        insert testQuote;

        ApexPages.currentPage().getParameters().put('id', testQuote.Id);

        salesQuotationPDFController controller = new salesQuotationPDFController();

        System.assertEquals(false, controller.showAmendmentOptions);

        Test.stopTest();
    }

    @isTest
    static void testSendAmendmentEmail() {
        Test.startTest();

        Quote testQuote = [SELECT Id, Email, Amendment_Quote__c FROM Quote WHERE Email != null LIMIT 1];

        ApexPages.currentPage().getParameters().put('id', testQuote.Id);

        salesQuotationPDFController controller = new salesQuotationPDFController();

        controller.isValid = true;
        controller.isAmendmentQuote = true;
        controller.emailId = testQuote.Email;
        controller.subject = 'Amendment Subject';
        controller.body = '<b>Amendment Body</b>';

        PageReference result = controller.sendAmendmentEmail();

        Test.stopTest();
    }

    @isTest
    static void testAmendmentQuoteSaveAndSend() {
        Test.startTest();

        Quote testQuote = [SELECT Id, Email, Amendment_Quote__c FROM Quote WHERE Email != null LIMIT 1];

        // Set Amendment_Quote__c to true
        testQuote.Amendment_Quote__c = true;
        update testQuote;

        ApexPages.currentPage().getParameters().put('id', testQuote.Id);

        salesQuotationPDFController controller = new salesQuotationPDFController();

        controller.isValid = true;
        controller.isAmendmentQuote = true;
        controller.emailId = testQuote.Email;
        controller.subject = 'Amendment Subject';
        controller.body = '<b>Amendment Body</b>';
        controller.createNew = true;

        PageReference pdfPage = new PageReference('/apex/salesQuotationPDF');
        pdfPage.getParameters().put('id', testQuote.Id);
        controller.pdf = pdfPage;

        PageReference result = controller.saveAndSend();

        Test.stopTest();
    }

    @isTest
    static void testNullQId() {
        Test.startTest();

        ApexPages.currentPage().getParameters().put('id', null);

        salesQuotationPDFController controller = new salesQuotationPDFController();

        System.assertNotEquals(null, controller);

        Test.stopTest();
    }
}