@IsTest
private class PushARCToSAPTest {

    @IsTest
    static void testPushARCToSAP() {

        Account acc = new Account(
            Name = 'Test SAP Account',
            SAP_Customer_Code__c = '100001'
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Pricebook2 pb = new Pricebook2(
            Name = 'Test Pricebook',
            IsActive = true,
            Distribution_Channel__c = '10'
        );
        insert pb;

        Product2 product = new Product2(
            Name = 'Test Product',
            ProductCode = 'MAT001',
            IsActive = true
        );
        insert product;

        PricebookEntry standardPbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = product.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert standardPbe;

        PricebookEntry customPbe = new PricebookEntry(
            Pricebook2Id = pb.Id,
            Product2Id = product.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert customPbe;

        Quote quote = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = pb.Id,
            ExpirationDate = Date.today().addDays(30)
        );
        insert quote;

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = quote.Id,
            PricebookEntryId = customPbe.Id,
            Quantity = 2,
            UnitPrice = 90,
            Discount_to_be_offered__c = 10,
            Valid_From__c = Date.today(),
            Valid_Till__c = Date.today().addDays(30)
        );
        insert qli;

        Test.startTest();

        String quoteData = PushARCToSAP.getQuoteLineItems(quote.Id);

        PushARCToSAP.LineItemWrapper wrapper =
            new PushARCToSAP.LineItemWrapper();

        wrapper.id = qli.Id;
        wrapper.productCode = product.ProductCode;
        wrapper.listPrice = qli.ListPrice;
        wrapper.salesPrice = qli.UnitPrice;
        wrapper.quantity = qli.Quantity;
        wrapper.validFrom = String.valueOf(qli.Valid_From__c);
        wrapper.validTill = String.valueOf(qli.Valid_Till__c);

        List<PushARCToSAP.LineItemWrapper> lineItems =
            new List<PushARCToSAP.LineItemWrapper>();

        lineItems.add(wrapper);

        Test.setMock(
            HttpCalloutMock.class,
            new PushARCToSAPMock()
        );

        String pushResult = PushARCToSAP.pushToSAP(
            quote.Id,
            lineItems
        );

        String emptyResult = PushARCToSAP.pushToSAP(
            quote.Id,
            new List<PushARCToSAP.LineItemWrapper>()
        );

        String nullResult = PushARCToSAP.pushToSAP(
            quote.Id,
            null
        );

        try {
            PushARCToSAP.getQuoteLineItems(
                '006000000000000AAA'
            );
        } catch (Exception e) {
        }

        String invalidPushResult = PushARCToSAP.pushToSAP(
            '006000000000000AAA',
            new List<PushARCToSAP.LineItemWrapper>()
        );

        Test.stopTest();
    }

    private class PushARCToSAPMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest request) {

            HttpResponse response = new HttpResponse();

            response.setStatusCode(200);
            response.setHeader(
                'Content-Type',
                'application/json'
            );
            response.setHeader(
                'x-csrf-token',
                'TEST_CSRF_TOKEN'
            );
            response.setHeader(
                'set-cookie',
                'SESSION=TEST_SESSION'
            );

            response.setBody(
                '[{"SalesQuotationNum":"500000001","Message":[{"MType":"S","Message1":"Quotation created successfully"}]}]'
            );

            return response;
        }
    }
}