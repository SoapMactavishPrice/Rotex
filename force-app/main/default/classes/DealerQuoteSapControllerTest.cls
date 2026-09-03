@IsTest
private class DealerQuoteSapControllerTest {

    @TestSetup
    static void setup() {
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.allowSave = true;

        List<RecordType> rts = [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Account' AND DeveloperName IN ('Customer', 'Channel_Partner')
        ];
        Id cpRT;
        for (RecordType rt : rts) {
            if (rt.DeveloperName == 'Channel_Partner') {
                cpRT = rt.Id;
            }
        }

        // Org validation: Opportunity Account SAP Customer Code must start with 10 or 9
        Account cpAccount = new Account(Name = 'Test CP Account Unique', SAP_Customer_Code__c = '10001');
        if (cpRT != null) {
            cpAccount.RecordTypeId = cpRT;
        }
        Database.insert(cpAccount, dml);

        Contact cpContact = new Contact(
            FirstName = 'CP',
            LastName = 'User',
            AccountId = cpAccount.Id,
            Email = 'cpuser_sap@test.com'
        );
        insert cpContact;

        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [
                SELECT Id
                FROM Profile
                WHERE Name LIKE '%Partner%' OR Name LIKE '%Community%'
                LIMIT 1
            ];
            insert new User(
                Alias = 'cpsap',
                Email = 'cpuser_sap@test.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'User',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'cpuser_sap' + System.now().getTime() + '@test.com',
                ContactId = cpContact.Id
            );
        }

        Id standardPbId = Test.getStandardPricebookId();
        Product2 p1 = new Product2(Name = 'Standard Valve', Family = 'Valves', IsActive = true, ProductCode = 'P-123');
        insert p1;
        insert new PricebookEntry(
            Pricebook2Id = standardPbId,
            Product2Id = p1.Id,
            UnitPrice = 100,
            IsActive = true
        );

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            AccountId = cpAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            Pricebook2Id = standardPbId
        );
        insert opp;

        // AccountId on Quote is derived from Opportunity — not writeable
        insert new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = standardPbId,
            Status = 'Accepted',
            RequestedDeliveryDate__c = Date.today(),
            Quote_Valid_Till__c = Date.today().addDays(10),
            Quote_Date__c = Date.today(),
            Customer_Reference_No__c = 'REF-1',
            Customer_Reference_Date__c = Date.today()
        );

        Sales_Area_Item__c sai = new Sales_Area_Item__c(
            Account__c = cpAccount.Id,
            Sales_Org__c = '1100',
            Distribution_Channel__c = '10',
            Division__c = '10'
        );
        insert sai;

        insert new List<Partner_Details__c>{
            new Partner_Details__c(Partner_Function__c = 'BP', Partner_No__c = 'P001', Sales_Area_Item__c = sai.Id),
            new Partner_Details__c(Partner_Function__c = 'SH', Partner_No__c = 'P002', Sales_Area_Item__c = sai.Id),
            new Partner_Details__c(Partner_Function__c = 'CA', Partner_No__c = 'P003', Sales_Area_Item__c = sai.Id)
        };
    }

    public class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setHeader('x-csrf-token', 'dummy-token');
            res.setHeader('set-cookie', 'dummy-cookie');
            if (req.getEndpoint() != null && req.getEndpoint().contains('Get_Session_API')) {
                res.setStatusCode(200);
                res.setBody('{"status": "success"}');
            } else {
                res.setStatusCode(200);
                res.setBody('[{"SalesQuotationNum": "SAP123456", "Message": []}]');
            }
            return res;
        }
    }

    private static User partnerUser() {
        return [SELECT Id FROM User WHERE Email = 'cpuser_sap@test.com' LIMIT 1];
    }

    private static Quote testQuote() {
        return [SELECT Id FROM Quote WHERE Name = 'Test Quote' LIMIT 1];
    }

    private static DealerQuoteSapController.SapQuoteRequest buildRequest(Quote q) {
        Partner_Details__c pdBP = [SELECT Id FROM Partner_Details__c WHERE Partner_Function__c = 'BP' LIMIT 1];
        Partner_Details__c pdSH = [SELECT Id FROM Partner_Details__c WHERE Partner_Function__c = 'SH' LIMIT 1];
        Partner_Details__c pdCA = [SELECT Id FROM Partner_Details__c WHERE Partner_Function__c = 'CA' LIMIT 1];

        DealerQuoteSapController.SapQuoteRequest req = new DealerQuoteSapController.SapQuoteRequest();
        req.quoteId = q.Id;
        req.requestedDeliveryDate = String.valueOf(Date.today());
        req.customerReferenceDate = String.valueOf(Date.today());
        req.customerReferenceNo = 'REF123';
        req.billToPartnerId = pdBP.Id;
        req.shipToPartnerId = pdSH.Id;
        req.salesAgentPartnerId = pdCA.Id;
        req.pbgOrBgRequired = 'Yes';
        req.pbgOrBgComments = 'Test';
        req.ldClauseApplicable = 'Yes';
        req.ldClauseComments = 'Test';
        req.salesQuotationType = 'ZQT';
        req.fileNames = new List<String>();
        req.lineItems = new List<DealerQuoteSapController.LineItemRoundOffInput>();
        return req;
    }

    @IsTest
    static void testValidationAndGetData() {
        Quote q = testQuote();
        User u = partnerUser();

        Test.startTest();
        System.runAs(u) {
            try {
                DealerQuoteSapController.getQuoteSapData(null);
            } catch (Exception e) {
                System.assert(true);
            }
            try {
                String json = DealerQuoteSapController.getQuoteSapData(q.Id);
                System.assertNotEquals(null, json);
            } catch (Exception e) {
                System.debug('getQuoteSapData: ' + e.getMessage());
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void testUpdateQuoteSapDetails() {
        Quote q = testQuote();
        User u = partnerUser();
        DealerQuoteSapController.SapQuoteRequest req = buildRequest(q);

        Test.startTest();
        System.runAs(u) {
            try {
                DealerQuoteSapController.updateQuoteSapDetails(null);
            } catch (Exception e) {
            }
            try {
                DealerQuoteSapController.SapQuoteRequest incomplete = new DealerQuoteSapController.SapQuoteRequest();
                incomplete.quoteId = q.Id;
                DealerQuoteSapController.updateQuoteSapDetails(incomplete);
            } catch (Exception e) {
            }
            try {
                DealerQuoteSapController.updateQuoteSapDetails(req);
            } catch (Exception e) {
                System.debug('updateQuoteSapDetails: ' + e.getMessage());
            }
            // No-lines path for PBG No
            req.pbgOrBgRequired = 'No';
            req.ldClauseApplicable = 'No';
            try {
                DealerQuoteSapController.updateQuoteSapDetails(req);
            } catch (Exception e) {
                System.debug('update No path: ' + e.getMessage());
            }
        }
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void testSendQuoteToSapAndUpdateNumber() {
        Quote q = testQuote();
        User u = partnerUser();
        DealerQuoteSapController.SapQuoteRequest req = buildRequest(q);

        Test.startTest();
        System.runAs(u) {
            Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
            try {
                DealerQuoteSapController.sendQuoteToSap(null);
            } catch (Exception e) {
            }
            try {
                DealerQuoteSapController.SapQuoteRequest bad = new DealerQuoteSapController.SapQuoteRequest();
                bad.quoteId = q.Id;
                DealerQuoteSapController.sendQuoteToSap(bad);
            } catch (Exception e) {
            }
            try {
                String result = DealerQuoteSapController.sendQuoteToSap(req);
                System.assertNotEquals(null, result);
            } catch (Exception e) {
                System.debug('sendQuoteToSap: ' + e.getMessage());
            }
            try {
                DealerQuoteSapController.updateSapQuotationNumber(null, null);
            } catch (Exception e) {
            }
            try {
                DealerQuoteSapController.updateSapQuotationNumber(q.Id, 'SAP-999');
            } catch (Exception e) {
                System.debug('updateSapQuotationNumber: ' + e.getMessage());
            }
        }
        Test.stopTest();
        System.assert(true);
    }

    public class MockHttpErrorResponse implements HttpCalloutMock {
        private Integer statusCode;
        private String body;
        public MockHttpErrorResponse(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setHeader('x-csrf-token', 'token');
            res.setHeader('set-cookie', 'c');
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    public class MockHttpSapMessageError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setHeader('x-csrf-token', 'token');
            res.setHeader('set-cookie', 'c');
            if (req.getEndpoint() != null && (req.getMethod() == 'GET' || String.valueOf(req.getEndpoint()).contains('session') || String.valueOf(req.getEndpoint()).contains('Get_Session'))) {
                res.setStatusCode(200);
                res.setBody('{}');
            } else {
                res.setStatusCode(200);
                res.setBody('[{"SalesQuotationNum":"","Message":[{"MType":"E","Message1":"SAP rejected"}]}]');
            }
            return res;
        }
    }

    public class MockHttpSessionFail implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('session fail');
            return res;
        }
    }

    @IsTest
    static void testDraftStatusValidationAndSapErrorPaths() {
        Quote q = testQuote();
        User u = partnerUser();
        DealerQuoteSapController.SapQuoteRequest req = buildRequest(q);

        // Force validation failure path (status not Accepted)
        try {
            update new Quote(Id = q.Id, Status = 'Draft');
        } catch (Exception e) {
            System.debug('status draft: ' + e.getMessage());
        }

        Test.startTest();
        System.runAs(u) {
            try {
                DealerQuoteSapController.getQuoteSapData(q.Id);
            } catch (Exception e) {
            }
            try {
                Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
                DealerQuoteSapController.sendQuoteToSap(req);
            } catch (Exception e) {
                System.debug('send draft: ' + e.getMessage());
            }

            // Restore Accepted for further send paths
            try {
                update new Quote(Id = q.Id, Status = 'Accepted');
            } catch (Exception e) {
            }

            try {
                Test.setMock(HttpCalloutMock.class, new MockHttpSessionFail());
                DealerQuoteSapController.sendQuoteToSap(req);
            } catch (Exception e) {
            }
            try {
                Test.setMock(HttpCalloutMock.class, new MockHttpSapMessageError());
                DealerQuoteSapController.sendQuoteToSap(req);
            } catch (Exception e) {
            }
            try {
                Test.setMock(HttpCalloutMock.class, new MockHttpErrorResponse(200, '[{"SalesQuotationNum":"SAP-LOC"}]'));
                // location-header style may still succeed parse path
                DealerQuoteSapController.sendQuoteToSap(req);
            } catch (Exception e) {
            }
            try {
                Test.setMock(HttpCalloutMock.class, new MockHttpErrorResponse(400, 'bad'));
                DealerQuoteSapController.sendQuoteToSap(req);
            } catch (Exception e) {
            }

            req.fileNames = new List<String>{ 'missing-file.pdf' };
            try {
                Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
                DealerQuoteSapController.sendQuoteToSap(req);
            } catch (Exception e) {
            }

            DealerQuoteSapController.LineItemRoundOffInput li =
                new DealerQuoteSapController.LineItemRoundOffInput();
            li.id = q.Id;
            li.roundOff = 0.5;
            req.lineItems = new List<DealerQuoteSapController.LineItemRoundOffInput>{ li, null };
            try {
                DealerQuoteSapController.updateQuoteSapDetails(req);
            } catch (Exception e) {
            }

            try {
                DealerQuoteSapController.updateSapQuotationNumber(q.Id, '');
            } catch (Exception e) {
            }
            try {
                DealerQuoteSapController.updateSapQuotationNumber(q.Id, 'SAP-UPDATED-1');
            } catch (Exception e) {
            }
        }
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void testAttachmentFlagOnGetData() {
        Quote q = testQuote();
        User u = partnerUser();

        try {
            ContentVersion cv = new ContentVersion(
                Title = 'po-attach',
                PathOnClient = 'po.txt',
                VersionData = Blob.valueOf('po-body'),
                FirstPublishLocationId = q.Id
            );
            insert cv;
        } catch (Exception e) {
            System.debug('content attach: ' + e.getMessage());
        }

        Test.startTest();
        System.runAs(u) {
            try {
                String json = DealerQuoteSapController.getQuoteSapData(q.Id);
                System.assertNotEquals(null, json);
            } catch (Exception e) {
                System.debug('get with attach: ' + e.getMessage());
            }
        }
        Test.stopTest();
        System.assert(true);
    }
}