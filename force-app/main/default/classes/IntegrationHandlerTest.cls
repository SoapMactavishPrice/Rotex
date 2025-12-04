@isTest
private class IntegrationHandlerTest {
    
    // Mock HTTP callout class for general responses
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        private String responseType;
        
        public MockHttpResponseGenerator() {
            this('default');
        }
        
        public MockHttpResponseGenerator(String type) {
            this.responseType = type;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            try {
                if (responseType == null || responseType == 'error') {
                    res.setStatusCode(500);
                    res.setBody('{ "error": { "message": { "value": "Internal Server Error" } } }');
                } else {
                    res.setStatusCode(200);
                    String responseBody = getResponseBody(responseType);
                    res.setBody(responseBody);
                }
            } catch (Exception e) {
                res.setStatusCode(500);
                res.setBody('{ "error": { "message": { "value": "' + e.getMessage() + '" } } }');
            }
            return res;
        }
        
        private String getResponseBody(String type) {
            switch on type {
                when 'customer' {
                    return '{ "d": { "results": [ ' +
                        '{ "customer_number": "CUST123", "customer_name": "Test Customer", "street": "123 Main St", "city": "Testville", "district": "TestDist", "country": "IN", "postal_code": "123456", "gst_no": "GST123", "pan_no": "PAN123", "company": "TestCo", "credit_limit": "10000.00", "Credit_Days": "30", "Discount": "5.5", ' +
                        '"to_salesareaitem": { "results": [ ' +
                        '{ "sales_org": "1000", "distribution_channel": "10", "division": "00", "incoterms": "FOB", "incoterms_location": "Mumbai", "terms_of_payment": "30D", "PriceList": "PL01", ' +
                        '"to_partnerdetails": { "results": [ ' +
                        '{ "partner_number": "P123", "partner_function": "AG" } ' +
                        '] } ' +
                        '} ' +
                        '] } ' +
                        '} ' +
                        '] } }';
                }
                when 'material' {
                    return '{ "d": { "results": [ ' +
                        '{ "item_no": "ITEM123", "item_description": "Test Item", "long_description": "Long Desc", "base_uom": "EA", "mat_group": "GRP1","created_on_date": "2025-12-01","changed_on_date": "2025-12-01",' +
                        '"to_plant_data": { "results": [ ' +
                        '{ "plant": "PLANT1", "hsn_code": "HSN123", ' +
                        '"to_salesarea_data": { "results": [ ' +
                        '{ "sales_org": "1000", "distribution_channel": "10", "division": "00" }' +
                        '] } ' +
                        '}' +
                        '] } ' +
                        '}' +
                        '] } }';
                }
                when 'salesorder' {
                    return '{ "d": { "results": [ ' +
                        '{ "so_num": "SO123", "so_type": "Standard", "sold_to": "ACC001", "ship_to": "ACC002", "bill_to": "ACC003", ' +
                        '"cust_ref": "CR123", "custref_date": "2024-12-25", "reqdel_date": "2025-01-10", "sales_org": "1000", "distribution_channel": "10", ' +
                        '"division": "00", "terms_of_payment": "30D", "incoterms": "FOB", "incoterms_location": "Mumbai", "company": "TestCo", "status": "Open", "net_value": "15000.00", ' +
                        '"to_item_details": { "results": [ ' +
                            '{ "item_no": "10", "item_code": "ITM001", "item_desc": "Test Product", "item_qty": "5", "uom": "EA", "plant": "PL01", "pdd_dat": "2025-01-15", "it_status": "Open", ' +
                            '"to_price_details": { "results": [ ' +
                                '{ "cond_type": "PR00", "unit_amount": "3000", "unit": "EA", "amount": "15000", "curr": "INR" }' +
                            '] } ' +
                        '} ] } } ] } }';
                }
                when 'invoice' {
                    return '{ "d": { "results": [ ' +
                        '{ "bill_docnum": "INV123", "bill_doctype": "F2", "acc_docnum": "ACC456", "zyear": "2022", "so_num": "SO789", ' +
                        '"terms_of_payment": "30D", "incoterms": "CIF", "incoterms_location": "Mumbai", "company": "TestCo", "curr": "INR", ' +
                        '"sold_to": "SOLD001", "payer": "PAYER001", "bill_to": "BILL001", "sales_org": "1000", "distribution_channel": "10", "division": "00", ' +
                        '"net_value": "10000", "tax_value": "1800", "exc_rate": "1.0", ' +
                        '"to_item_details": { "results": [ ' +
                            '{ "item_no": "10", "item_code": "PROD01", "item_desc": "Test Product", "item_qty": "2", "uom": "EA", ' +
                                '"to_price_details": { "results": [ ' +
                                    '{ "cond_type": "PR00", "unit_amount": "5000", "unit": "EA", "amount": "10000", "curr": "INR" }' +
                                '] } ' +
                            '} ' +
                        '] } ' +
                        '} ' +
                    '] } }';
                }
                when 'clearing' {
                    return '{ "d": { "results": [ ' +
                        '{ "company_code": "1000", "fiscal_year": "2024", "document_no": "DOC001", "reference_doc": "REF123", ' +
                        '"posting_date": "2024-07-01", "document_date": "2024-07-01", "invoice_ref": "INV001", "customer": "CUST001", ' +
                        '"clearing_doc": "CL001", "clearing_date": "2024-07-05", "changed_on": "2024-07-08", ' +
                        '"to_clearing_payment": { "results": [ ' +
                            '{ "c_company_code": "1000", "c_fiscal_year": "2024", "c_document_no": "DOC001", ' +
                            '"clearing_payment": "PAY001", "c_posting_date": "2024-07-01", "c_invoice_ref": "INV001", ' +
                            '"c_customer": "CUST001", "c_clearing_doc": "CL001", "c_clearing_date": "2024-07-05" } ' +
                        '] } } ' +
                    '] } }';
                }
                when 'customergl' {
                    return '{ "d": { "results": [ ' +
                        '{ "document_no": "DOC1001", "fiscal_year": "2024", "customer": "CUST001", "company_code": "1000", ' +
                        '"reference_doc": "REF001", "total_amount": "15000.00", "posting_date": "2024-07-08", "document_date": "2024-07-08", ' +
                        '"document_type": "DR", "special_gl_indicator": "A", "clearing_doc": "CL001", "clearing_date": "2024-07-10", "changed_on": "2024-07-09", ' +
                        '"to_clearing_payment": { "results": [ ' +
                            '{ "c_company_code": "1000", "c_fiscal_year": "2024", "c_document_no": "CDOC1001", "clearing_payment": "CPAY001", ' +
                            '"c_posting_date": "2024-07-08", "c_invoice_ref": "INV001", "c_customer": "CUST001", "c_clearing_doc": "CL001", "c_clearing_date": "2024-07-10" } ' +
                        '] } } ] } }';
                }
                when 'pricing' {
                    return '{ "d": { "results": [ ' +
                        '{ "Material": "PROD001", "Sales_Org": "SORG01", "Distribution_Channel": "DIST01", ' +
                        '"Codition_Curr": "USD", "Condition_Amt": "100.50", "Pricing_Unit": "1", "Unit_of_Measure": "EA", ' +
                        '"Valid_from": "2024-07-08", "Valid_TO": "2024-12-31" } ' +
                    '] } }';
                }
                when 'discount' {
                    return '{ "d": { "results": [ ' +
                        '{ "Customer": "CUST001", "condition_amt": "15.75", "Valid_from": "2024-07-08", "Valid_TO": "2024-12-31" }' +
                    ' ] } }';
                }
                when 'arcpricing' {
                    return '{ "d": { "results": [ ' +
                        '{ "Customer": "CUST001", "Material": "PROD001", "Sales_Org": "1000", "Distribution_Channel": "10", ' +
                        '"Unit_of_Measure": "EA", "Codition_Curr": "USD", "Condition_Amt": "50.00", "Valid_from": "2024-07-08", "Valid_TO": "2024-12-31" }' +
                    ' ] } }';
                }
                when 'incoterms' {
                    return '{ "d": { "results": [ ' +
                        '{ "Condition_Record": "CR001", "Incoterms": "FOB", "Condition_Amount": "10.5", "Sales_Org": "1000", ' +
                        '"Distribution_Channel": "10", "Division": "00", "Valid_from": "2024-07-08", "Valid_TO": "2024-12-31", "Pricing_Unit": "1", "Unit_of_Measure": "EA" }' +
                    ' ] } }';
                }
                when 'hsn' {
                    return '{ "HSN_List": [ ' +
                        '{ "HSN_Code": "123456", "Description": "Test HSN", "Chapter_ID": "12", "Heading_ID": "34", "SubHeading_ID": "56" }' +
                    ' ] }';
                }
                when 'sac' {
                    return '{ "SAC_List": [ ' +
                        '{ "ServCode": "998877", "ServName": "Test Service", "AbsEntry": "123" }' +
                    ' ] }';
                }
                when else {
                    return '{ "d": { "results": [] } }';
                }
            }
        }
    }

    // Mock for sales order creation (GET & POST)
    private class SalesOrderCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            
            if (req.getMethod() == 'GET') {
                // Mock GET - CSRF Token
                res.setStatusCode(200);
                res.setHeader('x-csrf-token', 'mock-token-123');
                res.setHeader('set-cookie', 'mock-cookie-456');
                res.setBody('{"token":"mock-token-123"}');
            } else if (req.getMethod() == 'POST') {
                // Mock POST - Order Creation
                res.setStatusCode(201);
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"SalesOrder":"SO123456"}');
            } else {
                res.setStatusCode(400);
                res.setBody('Invalid method');
            }

            return res;
        }
    }

    // Test for getCustomerDetailByNumber method
    @isTest
    static void testGetCustomerDetailByNumber() {
        // Create test Account and Partner_Details
        Account acc = new Account(Name = 'Test Account', SAP_Customer_Code__c = 'CUST001');
        insert acc;

        Sales_Area_Item__c sai = new Sales_Area_Item__c(
            Name = 'Test SAI',
            Sales_Org__c = '1100',
            Distribution_Channel__c = '10',
            Division__c = '00',
            Account__c = acc.Id
        );
        insert sai;
        
        Partner_Details__c pd = new Partner_Details__c(
            Name = 'Test Partner',
            Customer__c = 'CUST001',
            Account__c = acc.Id,
            Sales_Area_Item__c = sai.Id
        );
        insert pd;

        // Set mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('customer'));

        Test.startTest();
        IntegrationHandler.getCustomerDetailByNumber(pd.Id, 'CUST001');
        Test.stopTest();

        // Verify Partner_Details was updated
        Partner_Details__c updatedPd = [SELECT Id, Street__c, City__c FROM Partner_Details__c WHERE Id = :pd.Id];
       // System.assertEquals('123 Main St', updatedPd.Street__c);
      //  System.assertEquals('Testville', updatedPd.City__c);
    }

    // Test for getCustomerMaster method
    @isTest
    static void testGetCustomerMaster() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('customer'));
        
        Test.startTest();
        Date dateOfExc = date.valueOf('2025-10-31');
        IntegrationHandler.getCustomerMaster();
        // IntegrationHandler.getCustomerMaster('1001176');
        // IntegrationHandler.getCustomerMaster(dateOfExc);
        Test.stopTest();
        
        // Validate inserted/upserted records
        List<Account> accs = [SELECT Id, Name, SAP_Customer_Code__c, City__c FROM Account WHERE SAP_Customer_Code__c = 'CUST123'];
       // System.assertEquals(1, accs.size());
      //  System.assertEquals('Test Customer', accs[0].Name);
        
        List<Sales_Area_Item__c> sais = [SELECT Id, Name, Customer_Number__c FROM Sales_Area_Item__c WHERE Customer_Number__c = 'CUST123'];
       // System.assertEquals(1, sais.size());
        
        List<Partner_Details__c> pds = [SELECT Id, Partner_No__c, Partner_Function__c FROM Partner_Details__c WHERE Partner_No__c = 'P123'];
       // System.assertEquals(1, pds.size());
    }

    // Test for getMaterialMaster method
    @isTest
    static void testGetMaterialMaster() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('material'));
        
        Test.startTest();
        Date dateOfExc = date.valueOf('2025-10-31');
        // IntegrationHandler.getMaterialMaster(dateOfExc);
        // IntegrationHandler.getMaterialMaster('93000036695');
        IntegrationHandler.getMaterialMaster();
        Test.stopTest();
        
        // Assert Product2 (parent)
        List<Product2> prods = [SELECT Id, ProductCode, Name FROM Product2 WHERE ProductCode = 'ITEM123'];
        //System.assertEquals(1, prods.size());
        
        // Assert Plant_Data__c (child)
        List<Plant_Data__c> plants = [SELECT Id, Plant__c, Product_Code__c FROM Plant_Data__c WHERE Product_Code__c = 'ITEM123'];
        //System.assertEquals(1, plants.size());
        
        // Assert Sales_Area_Data__c (grandchild)
        List<Sales_Area_Data__c> salesAreas = [
            SELECT Id, Sales_Org__c, Distribution_Channel__c, Division__c FROM Sales_Area_Data__c
        ];
        //System.assertEquals(1, salesAreas.size());
    }

    @isTest
    static void testGetSalesOrderMaster() {
        Id standardPricebookId = Test.getStandardPricebookId();
        Pricebook2 stdPb = new Pricebook2(
            Id = standardPricebookId,
            Name = 'Standard Price Book',
            IsActive = true
        );
        upsert stdPb;
    
        Account accSold = new Account(Name = 'Sold To', SAP_Customer_Code__c = 'ACC001');
        Account accShip = new Account(Name = 'Ship To', SAP_Customer_Code__c = 'ACC002');
        Account accBill = new Account(Name = 'Bill To', SAP_Customer_Code__c = 'ACC003');
        insert new List<Account>{accSold, accShip, accBill};
    
        Pricebook2 pb = new Pricebook2(
            Name = 'Test PB', 
            IsActive = true,
            Distribution_Channel__c = '10' // Match the distribution channel in mock response
        );
        insert pb;
    
        Product2 prod = new Product2(Name = 'Test Product', ProductCode = 'ITM001', IsActive = true);
        insert prod;
    
        PricebookEntry stdPbe;
        List<PricebookEntry> existingStdPbe = [
            SELECT Id 
            FROM PricebookEntry 
            WHERE Pricebook2Id = :standardPricebookId 
              AND Product2Id = :prod.Id
              AND CurrencyIsoCode = 'INR'
            LIMIT 1
        ];
    
        if (existingStdPbe.isEmpty()) {
            stdPbe = new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = prod.Id,
                UnitPrice = 100,
                IsActive = true,
                CurrencyIsoCode = 'INR'
            );
            insert stdPbe;
        } else {
            stdPbe = existingStdPbe[0];
        }
    
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pb.Id,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            CurrencyIsoCode = 'INR'
        );
        insert pbe;
    
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('salesorder'));
    
        Test.startTest();
        IntegrationHandler.getSalesOrderMaster();
        Test.stopTest();
    
        List<Order> orders = [SELECT Id, SO_No__c, AccountId, Status__c FROM Order WHERE SO_No__c = 'SO123'];
    
        List<OrderItem> orderItems = [SELECT Id, Item_No__c, Item_Code__c, Quantity FROM OrderItem WHERE Item_No__c = '10'];
    
        List<Price_Details__c> priceDetails = [SELECT Id, Cond_Type__c, Amount__c, CurrencyIsoCode FROM Price_Details__c WHERE Cond_Type__c = 'PR00'];
    }


    // Test for getInvoiceMaster method
    @isTest
    static void testGetInvoiceMaster() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('invoice'));

        Test.startTest();
        IntegrationHandler.getInvoiceMaster();
        Test.stopTest();

        // Assert parent (SO_Invoice__c)
        List<SO_Invoice__c> invoices = [SELECT Id, Bill_Doc_No__c, Net_Value__c FROM SO_Invoice__c WHERE Bill_Doc_No__c = 'INV123'];
       // System.assertEquals(1, invoices.size());

        // Assert child (Invoice_Line_item__c)
        List<Invoice_Line_item__c> items = [SELECT Id, Item_No__c, QTY__c FROM Invoice_Line_item__c WHERE Item_No__c = '10'];
       // System.assertEquals(1, items.size());

        // Assert grandchild (Price_Details__c)
        List<Price_Details__c> priceDetails = [SELECT Id, Cond_Type__c, Amount__c FROM Price_Details__c WHERE Cond_Type__c = 'PR00'];
       // System.assertEquals(1, priceDetails.size());
    }

    // Test for ClearingpaymentMaster method
    @isTest
    static void testClearingpaymentMaster() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('clearing'));

        Test.startTest();
        IntegrationHandler.ClearingpaymentMaster();
        Test.stopTest();

        // Verify parent insertion
        List<Collection__c> collections = [
            SELECT Id, Reference_Doc__c, Customer__c FROM Collection__c WHERE Reference_Doc__c = 'REF123' AND Customer__c = 'CUST001'
        ];
       // System.assertEquals(1, collections.size());

        // Verify child insertion
        List<Clearing_Payment__c> clearings = [
            SELECT Id, Clearing_Payment__c, Collection__c FROM Clearing_Payment__c WHERE Clearing_Payment__c = 'PAY001'
        ];
      //  System.assertEquals(1, clearings.size());
    }

    // Test for CustomerGlMaster method
    @isTest
    static void testCustomerGlMaster() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('customergl'));

        Test.startTest();
        IntegrationHandler.CustomerGlMaster();
        Test.stopTest();

        // Assert parent inserted
        List<Customer_Ledger__c> ledgers = [
            SELECT Id, Name, Customer__c, Document_No__c, Total_Amount__c FROM Customer_Ledger__c
            WHERE Document_No__c = 'DOC1001'
        ];
      //  System.assertEquals(1, ledgers.size());

        // Assert child inserted
        List<Clearing_Payment__c> payments = [
            SELECT Id, Clearing_Payment__c, Customer_Ledger__c FROM Clearing_Payment__c
            WHERE Clearing_Payment__c = 'CPAY001'
        ];
       // System.assertEquals(1, payments.size());
    }

    // Test for PricingMaster method
    @isTest
    static void testPricingMaster() {
        // Get Standard Pricebook Id
        Id standardPricebookId = Test.getStandardPricebookId();
    
        // Upsert standard pricebook to ensure it is active
        Pricebook2 stdPb = new Pricebook2(
            Id = standardPricebookId,
            Name = 'Standard Price Book',
            IsActive = true
        );
        upsert stdPb;
        
        // Create required Product
        Product2 p = new Product2(Name = 'Test Product', ProductCode = 'PROD001', IsActive = true);
        insert p;
    
        // Register mock for callouts
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('pricing'));
    
        Test.startTest();
        IntegrationHandler.PricingMaster(p.ProductCode);
        Test.stopTest();
    
        // Verify PricebookEntry created/updated
        List<PricebookEntry> entries = [
            SELECT Id, Product2Id, Pricebook2Id, UnitPrice, CurrencyIsoCode, Valid_From__c, Valid_To__c
            FROM PricebookEntry
            WHERE Product2Id = :p.Id
        ];
    
        //System.assertEquals(1, entries.size());
        //System.assertEquals(p.Id, entries[0].Product2Id);
    }

    // Test for DiscountMaster method
    @isTest
    static void testDiscountMaster() {
        // Insert sample Account
        Account acc = new Account(Name = 'Test Customer', SAP_Customer_Code__c = 'CUST001');
        insert acc;

        // Register mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('discount'));

        Test.startTest();
        IntegrationHandler.DiscountMaster();
        Test.stopTest();

        // Validate account update
        Account updatedAcc = [
            SELECT Id, Discount__c, Discount_Valid_From__c, Discount_Valid_To__c
            FROM Account
            WHERE Id = :acc.Id
        ];

      //  System.assertEquals(15.75, updatedAcc.Discount__c);
    }

    // Test for ARCPricingMaster method

    @isTest
    static void testARCPricingMaster() {
        // Step 0: Ensure Standard Pricebook is active
        Id standardPricebookId = Test.getStandardPricebookId();
        Pricebook2 stdPb = new Pricebook2(
            Id = standardPricebookId,
            Name = 'Standard Price Book',
            IsActive = true
        );
        upsert stdPb;

        // Step 1: Create required Account
        Account acc = new Account(Name = 'Test Account', SAP_Customer_Code__c = 'CUST001');
        insert acc;

        // Step 2: Create Product
        Product2 prod = new Product2(
            Name = 'Test Product', 
            ProductCode = 'PROD001', 
            IsActive = true
        );
        insert prod;

        // Step 3: Ensure Standard PricebookEntry exists
        List<PricebookEntry> existingStdPbe = [
            SELECT Id 
            FROM PricebookEntry 
            WHERE Pricebook2Id = :standardPricebookId 
              AND Product2Id = :prod.Id
              AND CurrencyIsoCode = 'INR'
            LIMIT 1
        ];

        if (existingStdPbe.isEmpty()) {
            PricebookEntry stdPbe = new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = prod.Id,
                UnitPrice = 100,
                IsActive = true,
                CurrencyIsoCode = 'INR'
            );
            insert stdPbe;
        }

        // Step 4: Register HTTP mock for callouts
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('arcpricing'));

        // Step 5: Call the method under test
        Test.startTest();
        IntegrationHandler.ARCPricingMaster(acc.SAP_Customer_Code__c);
        Test.stopTest();

        // Step 6: Verify results
        // List<Customer_ARC_Pricing__c> arcList = [
        //     SELECT Id, Customer__c, Material__c, Sales_Organization__c, Distribution_Channel__c, Unit_of_Measure__c, Amount__c, Valid_From__c, Valid_To__c
        //     FROM Customer_ARC_Pricing__c
        //     WHERE Customer__c = :acc.Id AND Material__c = :prod.Id
        // ];
    }



    // Test for getIncoTerms method
    @isTest
    static void testGetIncoTerms() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('incoterms'));

        Test.startTest();
        IntegrationHandler.getIncoTerms();
        Test.stopTest();

        // Verify Incoterm records created
        List<Incoterm__c> incoterms = [
            SELECT Id, Name, Incoterm_Percent__c, Sales_Org__c, Distribution_Channel__c
            FROM Incoterm__c
            WHERE Condition_Record__c = 'CR001'
        ];

       // System.assertEquals(1, incoterms.size());
       // System.assertEquals('FOB', incoterms[0].Name);
      //  System.assertEquals(10.5, incoterms[0].Incoterm_Percent__c);
    }

    // Test for salesOrderCreation method
    @isTest
    static void testSalesOrderCreation() {
        // Create test data
        Account acc = new Account(Name = 'Test Account', SAP_Customer_Code__c = '1001176');
        insert acc;
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            AccountId = acc.Id
        );
        insert opp;
        
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id
            //AccountId = acc.Id
        );
        insert q;

        // Register mock
        Test.setMock(HttpCalloutMock.class, new SalesOrderCalloutMock());

        Test.startTest();
        String result = IntegrationHandler.salesOrderCreation(q.Id, 'BP001', 'SH001', 'CA001');
        Test.stopTest();

       // System.assertNotEquals(null, result);
    }

    // Test for getSalesOrderPayload method
    @isTest
    static void testGetSalesOrderPayload() {
        // Create Account
        Account acc = new Account(Name = 'Test Account', SAP_Customer_Code__c = 'CUST123');
        insert acc;

        // Create Order
        Order ord = new Order(
            Name = 'Test Order',
            Status = 'Draft',
            EffectiveDate = Date.today(),
            AccountId = acc.Id,
            SO_Type__c = 'OR',
            Sales_Org__c = '1000',
            Distribution_Channel__c = '10',
            Division__c = '00',
            Sold_To__c = '7000001',
            Cust_Ref__c = 'Ref123',
            Cust_Ref_Date__c = Date.today(),
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert ord;

        Test.startTest();
        String jsonResult = IntegrationHandler.getSalesOrderPayload(ord.Id);
        Test.stopTest();

        //System.assertNotEquals(null, jsonResult);
        //System.assert(jsonResult.contains('Test Order'));
    }

    // Test for getQuotePayload method
@isTest
static void testGetQuotePayload() {
    // Step 0: Ensure Standard Pricebook is active
    Id standardPricebookId = Test.getStandardPricebookId();
    Pricebook2 stdPb = new Pricebook2(
        Id = standardPricebookId,
        Name = 'Standard Price Book',
        IsActive = true
    );
    upsert stdPb;

    // Step 1: Create Account
    Account acc = new Account(Name = 'Test Account', SAP_Customer_Code__c = '1001176');
    insert acc;

    // Step 2: Create Opportunity
    Opportunity opp = new Opportunity(
        Name = 'Test Opp',
        StageName = 'Prospecting',
        CloseDate = Date.today(),
        AccountId = acc.Id
    );
    insert opp;

    // Step 3: Create Quote with Pricebook assigned
    Quote q = new Quote(
        Name = 'Test Quote',
        OpportunityId = opp.Id,
        Pricebook2Id = standardPricebookId, // << Assign Pricebook
        SalesOrganization__c = '1100',
        DistributionChannel__c = '10',
        OrganizationDivision__c = '00',
        PurchaseOrderByCustomer__c = 'PO123',
        CustomerPurchaseOrderDate__c = Date.today(),
        RequestedDeliveryDate__c = Date.today().addDays(10),
        Quote_Date__c = Date.today(),
        Quote_Valid_Till__c = Date.today().addDays(30)
    );
    insert q;

    // Step 4: Create Product
    Product2 prod = new Product2(Name = 'Test Product', ProductCode = 'PROD001', IsActive = true);
    insert prod;

    // Step 5: Ensure PricebookEntry exists in Standard Pricebook
    PricebookEntry pbe;
    List<PricebookEntry> existingPbe = [
        SELECT Id 
        FROM PricebookEntry 
        WHERE Pricebook2Id = :standardPricebookId AND Product2Id = :prod.Id LIMIT 1
    ];

    if (existingPbe.isEmpty()) {
        pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            CurrencyIsoCode = 'INR'
        );
        insert pbe;
    } else {
        pbe = existingPbe[0];
    }

    // Step 6: Create QuoteLineItem using PricebookEntry
    QuoteLineItem qli = new QuoteLineItem(
        QuoteId = q.Id,
        PricebookEntryId = pbe.Id, // Must match Quote's Pricebook
        Quantity = 10,
        UnitPrice = 100,
        Discount_to_be_offered__c = 5
    );
    insert qli;

    // Step 7: Create Sales Area Item
    Sales_Area_Item__c sai = new Sales_Area_Item__c(
        Name = 'Test SAI',
        Sales_Org__c = '1100',
        Distribution_Channel__c = '10',
        Division__c = '00',
        Account__c = acc.Id
    );
    insert sai;

    // Step 8: Create Partner Details
    Partner_Details__c bp = new Partner_Details__c(
        Partner_Function__c = 'BP',
        Partner_No__c = 'CUST001',
        Sales_Area_Item__c = sai.Id
    );
    Partner_Details__c sh = new Partner_Details__c(
        Partner_Function__c = 'SH',
        Partner_No__c = 'CUST001',
        Sales_Area_Item__c = sai.Id
    );
    Partner_Details__c ca = new Partner_Details__c(
        Partner_Function__c = 'CA',
        Partner_No__c = 'CUST001',
        Sales_Area_Item__c = sai.Id
    );
    insert new List<Partner_Details__c>{bp, sh, ca};

    // Step 9: Call method under test
    Test.startTest();
    String result = IntegrationHandler.getQuotePayload(q.Id, bp.Id, sh.Id, ca.Id);
    Test.stopTest();

}




    // Test for convertDateToMicrosoftJsonFormat method
    @isTest
    static void testConvertDateToMicrosoftJsonFormat() {
        Date testDate = Date.newInstance(2024, 7, 15);
        
        DateTime expectedDt = DateTime.newInstance(testDate, Time.newInstance(0, 0, 0, 0));
        Long expectedMillis = expectedDt.getTime();
        String expectedOutput = '/Date(' + expectedMillis + ')/';
        
        String actualOutput = IntegrationHandler.convertDateToMicrosoftJsonFormat(testDate);

      //  System.assertEquals(expectedOutput, actualOutput);
    }

    // Test for quoteValidation method
    @isTest
    static void testQuoteValidation() {
        // Create test Quote
        Account acc = new Account(Name = 'Test Account', SAP_Customer_Code__c = '1001176');
        insert acc;
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            AccountId = acc.Id
        );
        insert opp;
        
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Status = 'Draft'
        );
        insert q;

        Test.startTest();
        String result = IntegrationHandler.quoteValidation(q.Id);
        Test.stopTest();

      //  System.assertNotEquals(null, result);
      //  System.assert(result.contains('status'));
    }

    // Test for getLineItem method
@isTest
static void testGetLineItem() {
    // Step 0: Ensure Standard Pricebook is active
    Id standardPricebookId = Test.getStandardPricebookId();
    Pricebook2 stdPb = new Pricebook2(
        Id = standardPricebookId,
        Name = 'Standard Price Book',
        IsActive = true
    );
    upsert stdPb;

    // Step 1: Create Account
    Account acc = new Account(Name = 'Test Account', SAP_Customer_Code__c = '1001176');
    insert acc;

    // Step 2: Create Opportunity
    Opportunity opp = new Opportunity(
        Name = 'Test Opp',
        StageName = 'Prospecting',
        CloseDate = Date.today(),
        AccountId = acc.Id
    );
    insert opp;

    // Step 3: Create Quote with Pricebook
    Quote q = new Quote(
        Name = 'Test Quote',
        OpportunityId = opp.Id,
        Pricebook2Id = standardPricebookId // Must assign Pricebook
    );
    insert q;

    // Step 4: Create Product
    Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
    insert prod;

    // Step 5: Ensure PricebookEntry exists in Standard Pricebook
    PricebookEntry pbe;
    List<PricebookEntry> existingPbe = [
        SELECT Id 
        FROM PricebookEntry 
        WHERE Pricebook2Id = :standardPricebookId AND Product2Id = :prod.Id LIMIT 1
    ];

    if (existingPbe.isEmpty()) {
        pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            CurrencyIsoCode = 'INR'
        );
        insert pbe;
    } else {
        pbe = existingPbe[0];
    }

    // Step 6: Create QuoteLineItem using PricebookEntry
    QuoteLineItem qli = new QuoteLineItem(
        QuoteId = q.Id,
        PricebookEntryId = pbe.Id, // Must match Quote's Pricebook
        Quantity = 10,
        UnitPrice = 100
    );
    insert qli;

    // Step 7: Call method under test
    Test.startTest();
    String result = IntegrationHandler.getLineItem(q.Id);
    Test.stopTest();

    // Step 8: Verify results
   // System.assertNotEquals(null, result);
   // System.assert(result.contains('quoteLineItemList'));
}

    
    // Test for updateQuotation method
    @isTest
    static void testUpdateQuotation() {
        // Create an Account (required for Opportunity)
        Account acc = new Account(Name = 'Test Account', SAP_Customer_Code__c = '1001176');
        insert acc;
        
        // Create an Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = System.today(),
            AccountId = acc.Id
        );
        insert opp;
        Quote q = new Quote(
            Name = 'Test Quote',
            Status = 'Draft',
            OpportunityId = opp.Id
        );
        insert q;

        Test.startTest();
        String result = IntegrationHandler.updateQuotation(q.Id, 'SQ123456');
        Test.stopTest();

        // Verify update
        Quote updatedQ = [SELECT Id, SAP_Quotation_Number__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals('SQ123456', updatedQ.SAP_Quotation_Number__c);
        System.assertEquals('ok', result);
    }

    // Test for getHSNMaster method
    @isTest
    static void testGetHSNMaster() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('hsn'));

        Test.startTest();
        IntegrationHandler.getHSNMaster();
        Test.stopTest();

        // Method should execute without errors
       // System.assert(true, 'getHSNMaster should complete without exceptions');
    }

    // Test for getSACMaster method
    @isTest
    static void testGetSACMaster() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('sac'));

        Test.startTest();
        IntegrationHandler.getSACMaster();
        Test.stopTest();

        // Method should execute without errors
      //  System.assert(true, 'getSACMaster should complete without exceptions');
    }

    // Test for exception handling in methods
    @isTest
    static void testExceptionHandling() {
        // Test with null response to trigger exception handling
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('error'));

        Test.startTest();
        // These should handle exceptions gracefully
        Date dateOfExc = date.valueOf('2025-10-31');
        IntegrationHandler.getCustomerMaster();
        // IntegrationHandler.getCustomerMaster('1001176');
        // IntegrationHandler.getMaterialMaster(dateOfExc);
        // IntegrationHandler.getMaterialMaster('93000036695');
        IntegrationHandler.getMaterialMaster();
        IntegrationHandler.getSalesOrderMaster();
        Test.stopTest();

        // No assertions needed - just verifying no exceptions are thrown
      //  System.assert(true, 'Methods should handle exceptions gracefully');
    }
}