@IsTest
private class SyncSapToSfTest {
    private class SyncMock implements HttpCalloutMock {
        private String apiName;
        private String expectedFilter;

        SyncMock(String apiName, String expectedFilter) {
            this.apiName = apiName;
            this.expectedFilter = expectedFilter;
        }

        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('GET', req.getMethod());
            System.assert(req.getEndpoint().contains(expectedFilter), 'Expected endpoint filter: ' + expectedFilter + ', actual: ' + req.getEndpoint());

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            if (apiName == 'customer') {
                res.setBody(customerResponse());
            } else if (apiName == 'existingCustomer') {
                res.setBody(existingCustomerResponse());
            } else if (apiName == 'emptyCustomer' || apiName == 'emptyMaterial') {
                res.setBody('{ "d": { "results": [] } }');
            } else if (apiName == 'existingMaterial') {
                res.setBody(existingMaterialResponse());
            } else {
                res.setBody(materialResponse());
            }

            return res;
        }
    }

    @TestSetup
    static void setupExistingRecords() {
        insert new Account(Name = 'Existing Customer', SAP_Customer_Code__c = 'CUSTEXIST');
        insert new Product2(Name = 'Existing Material', ProductCode = 'MATEXIST', IsActive = true);
    }

    @IsTest
    static void syncCustomerUsesCustomerCodeFilterAndUpsertsRecords() {
        Test.setMock(HttpCalloutMock.class, new SyncMock('customer', 'customer_number%20eq%20%27CUST123%27'));

        Test.startTest();
        SyncSapToSf.SyncResult result = SyncSapToSf.syncCustomer('CUST123');
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals('success', result.variant);
        System.assert(result.message.contains('Records synced: 1'));
        System.assertEquals(1, [SELECT COUNT() FROM Account WHERE SAP_Customer_Code__c = 'CUST123']);
        System.assertEquals(1, [SELECT COUNT() FROM Sales_Area_Item__c WHERE Customer_Number__c = 'CUST123']);
        System.assertEquals(1, [SELECT COUNT() FROM Partner_Details__c WHERE Partner_No__c = 'P123']);
    }

    @IsTest
    static void getMaterialMasterUsesItemNumberFilterAndUpsertsRecords() {
        Test.setMock(HttpCalloutMock.class, new SyncMock('material', 'item_no%20eq%20%2791000005408%27'));

        Test.startTest();
        SyncSapToSf.SyncResult result = SyncSapToSf.getMaterialMaster('91000005408');
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals('success', result.variant);
        System.assert(result.message.contains('Records synced: 1'));
        System.assertEquals(1, [SELECT COUNT() FROM Product2 WHERE ProductCode = '91000005408']);
        System.assertEquals(1, [SELECT COUNT() FROM Plant_Data__c WHERE Product_Code__c = '91000005408']);
        System.assertEquals(1, [
            SELECT COUNT()
            FROM Sales_Area_Data__c
            WHERE Plant_Data__r.Product_Code__c = '91000005408'
        ]);
    }

    @IsTest
    static void syncCustomerThrowsErrorWhenSapReturnsNoResults() {
        Test.setMock(HttpCalloutMock.class, new SyncMock('emptyCustomer', 'customer_number%20eq%20%27INVALID%27'));

        Test.startTest();
        try {
            SyncSapToSf.syncCustomer('INVALID');
            System.assert(false, 'Expected invalid customer code error');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void getMaterialMasterThrowsErrorWhenSapReturnsNoResults() {
        Test.setMock(HttpCalloutMock.class, new SyncMock('emptyMaterial', 'item_no%20eq%20%27INVALID%27'));

        Test.startTest();
        try {
            SyncSapToSf.getMaterialMaster('INVALID');
            System.assert(false, 'Expected invalid material code error');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void syncCustomerReturnsInfoWhenCustomerAlreadyPresent() {
        Test.setMock(HttpCalloutMock.class, new SyncMock('existingCustomer', 'customer_number%20eq%20%27CUSTEXIST%27'));

        Test.startTest();
        SyncSapToSf.SyncResult result = SyncSapToSf.syncCustomer('CUSTEXIST');
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals('info', result.variant);
        System.assertEquals('This customer is already present.', result.message);
        System.assertEquals(1, [SELECT COUNT() FROM Account WHERE SAP_Customer_Code__c = 'CUSTEXIST']);
    }

    @IsTest
    static void getMaterialMasterReturnsInfoWhenMaterialAlreadyPresent() {
        Test.setMock(HttpCalloutMock.class, new SyncMock('existingMaterial', 'item_no%20eq%20%27MATEXIST%27'));

        Test.startTest();
        SyncSapToSf.SyncResult result = SyncSapToSf.getMaterialMaster('MATEXIST');
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals('info', result.variant);
        System.assertEquals('This material is already present.', result.message);
        System.assertEquals(1, [SELECT COUNT() FROM Product2 WHERE ProductCode = 'MATEXIST']);
    }

    private static String customerResponse() {
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

    private static String existingCustomerResponse() {
        return customerResponse().replace('CUST123', 'CUSTEXIST');
    }

    private static String materialResponse() {
        return '{ "d": { "results": [ ' +
            '{ "item_no": "91000005408", "item_description": "Test Material", "long_description": "Long Desc", "base_uom": "EA", "mat_group": "GRP1", "created_on_date": "2025-12-01", "changed_on_date": "2025-12-02", ' +
            '"to_plant_data": { "results": [ ' +
            '{ "plant": "PLANT1", "hsn_code": "HSN123", ' +
            '"to_salesarea_data": { "results": [ ' +
            '{ "sales_org": "1000", "distribution_channel": "10", "division": "00" }' +
            '] } ' +
            '} ' +
            '] } ' +
            '} ' +
            '] } }';
    }

    private static String existingMaterialResponse() {
        return materialResponse().replace('91000005408', 'MATEXIST');
    }
}
