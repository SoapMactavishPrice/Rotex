@isTest
public class IntegrationRequestBuilderTest {

    @isTest
    static void testInventoryMasterResponseParse() {
        String json = '[{"ItemCode":"A001","ItemName":"Item1","ItemGroup":"Group1","BatchNo":"B001","BatchAttribute":"Attr1","BatchAttribute2":"Attr2","Quantity":10,"BalanceAmount":100.0,"CustomerName":"Customer1","Location":"Location1"}]';
        
        Test.startTest();
        List<IntegrationRequestBuilder.cls_Inventory_List> result = IntegrationRequestBuilder.InventoryMasterResponseParse(json);
        IntegrationRequestBuilder.fc();
        Test.stopTest();

       
    }

    @isTest
    static void testHSNMasterResponseParse() {
        String json = '{"Code":0,"Error":"None","HSN_List":[{"Chapter_ID":"01","Heading_ID":"01.01","SubHeading_ID":"01.01.01","Description":"Description1","HSN_Code":"HSN001"}]}';
        
        Test.startTest();
        IntegrationRequestBuilder.HSNMasterResponse result = IntegrationRequestBuilder.HSNMasterResponseParse(json);
        IntegrationRequestBuilder.fc();
        Test.stopTest();

       
    }

    @isTest
    static void testSACMasterResponseParse() {
        String json = '{"Code":0,"Error":"None","SAC_List":[{"AbsEntry":1,"ServCode":"SAC001","ServName":"Service1"}]}';
        
        Test.startTest();
        IntegrationRequestBuilder.SACMasterResponse result = IntegrationRequestBuilder.SACMasterResponseParse(json);
        IntegrationRequestBuilder.fc();
        Test.stopTest();

        
    }

   @isTest
static void testCustomerMasterResponseParse() {
    String json = '{"d":{"results":[{"customer_number":"C001","customer_name":"Customer1","street":"Street1","city":"City1","state":"State1","country":"Country1","postal_code":"12345","email_id":"customer1@example.com","gst_no":"GST123","pan_no":"PAN123","company":"Company1","created_on_date":"2023-01-01","changed_on_date":"2023-01-02","to_salesareaitem":{"results":[{"sales_org":"SO001","distribution_channel":"DC001","division":"D001","incoterms":"INCO001","incoterms_location":"Loc1","terms_of_payment":"Net 30","price_list":"PL001","to_partnerdetails":{"results":[{"partner_function":"Function1","partner_number":"P001"}]}}]}}]}}';

    Test.startTest();
    IntegrationRequestBuilder.CustomerMasterResponse result = IntegrationRequestBuilder.CustomerMasterResponseParse(json);
    IntegrationRequestBuilder.fc();
    Test.stopTest();

    
}

    @isTest
    static void testMaterialMasterResponseParse() {
        String json = '{"d":{"results":[{"item_no":"M001","item_description":"Material1","long_description":"Long description","base_uom":"KG","mat_group":"MG001","created_on_date":"2023-01-01","changed_on_date":"2023-01-02","to_plant_data":{"results":[{"plant":"Plant1","hsn_code":"HSN001","to_salesarea_data":{"results":[{"sales_org":"SO001","distribution_channel":"DC001","division":"D001"}]}}]}}]}}';
        
        Test.startTest();
        IntegrationRequestBuilder.MaterialMasterResponse result = IntegrationRequestBuilder.MaterialMasterResponseParse(json);
        IntegrationRequestBuilder.fc();
        Test.stopTest();

      
    }

    @isTest
    static void testSalesOrderMasterResponseParse() {
        String json = '{"d":{"results":[{"so_num":"SO001","so_type":"Type1","sold_to":"C001","ship_to":"C002","bill_to":"C003","cust_ref":"REF001","custref_date":"2023-01-01","reqdel_date":"2023-01-10","sales_org":"SO001","distribution_channel":"DC001","division":"D001","terms_of_payment":"Net 30","incoterms":"INCO001","incoterms_location":"Loc1","company":"Company1","status":"Open","net_value":"1000","created_on_date":"2023-01-01","changed_on_date":"2023-01-02","to_item_details":{"results":[{"item_no":"M001","item_code":"A001","item_desc":"Item1","item_qty":"10","uom":"KG","plant":"Plant1","pdd_dat":"2023-01-15","it_status":"Open","to_price_details":{"results":[{"cond_type":"CT01","unit_amount":"100","unit":"KG","amount":"1000","curr":"INR"}]}}]}}]}}';
        
        Test.startTest();
        IntegrationRequestBuilder.SalesOrderMasterResponse result = IntegrationRequestBuilder.SalesOrderMasterResponseParse(json);
        IntegrationRequestBuilder.fc();
        Test.stopTest();

       
    }

    @isTest
    static void testInvoiceMasterResponseParse() {
        String json = '{"d":{"results":[{"bill_docnum":"INV001","bill_doctype":"Type1","bill_date":"2023-01-01","acc_docnum":"ACC001","zyear":"2023","so_num":"SO001","terms_of_payment":"Net 30","incoterms":"INCO001","incoterms_location":"Loc1","company":"Company1","curr":"INR","sold_to":"C001","payer":"Payer1","bill_to":"B001","sales_org":"SO001","distribution_channel":"DC001","division":"D001","net_value":"1000","tax_value":"100","exc_rate":"1.0","created_on_date":"2023-01-01","changed_on_date":"2023-01-02","to_item_details":{"results":[{"item_no":"M001","item_code":"A001","item_desc":"Item1","item_qty":"10","uom":"KG","plant":"Plant1","to_price_details":{"results":[{"cond_type":"CT01","unit_amount":"100","unit":"KG","amount":"1000","curr":"INR"}]}}]}}]}}';
        
        Test.startTest();
        IntegrationRequestBuilder.InvoiceMasterResponse result = IntegrationRequestBuilder.InvoiceMasterResponseParse(json);
        IntegrationRequestBuilder.fc();
        Test.stopTest();

      
    }

    @isTest
    static void testClearingPaymentMasterResponseParse() {
        String json = '{"d":{"results":[{"company_code":"CC001","fiscal_year":"2023","document_no":"DOC001","account_type":"Account1","reference_doc":"REF001","amount_in_tra_cur":"1000","posting_date":"2023-01-01","document_date":"2023-01-02","document_type":"Invoice","invoice_ref":"INV001","customer":"C001","clearing_doc":"CL001","clearing_date":"2023-01-03"}]}}';
        
        Test.startTest();
        IntegrationRequestBuilder.ClearingPaymentMasterResponse result = IntegrationRequestBuilder.ClearingPaymentMasterResponseParse(json);
        IntegrationRequestBuilder.fc();
        Test.stopTest();

       
    }

    @isTest
    static void testCustomerGlMasterResponseParse() {
        String json = '{"d":{"results":[{"fiscal_year":"2023","customer":"C001","company_code":"CC001","document_no":"DOC001","reference_doc":"REF001","total_amount":"1000","posting_date":"2023-01-01","document_date":"2023-01-02","document_type":"Invoice","special_gl_indicator":"SGL001","clearing_doc":"CL001","clearing_date":"2023-01-03"}]}}';
        
        Test.startTest();
        IntegrationRequestBuilder.CustomerGlMasterResponse result = IntegrationRequestBuilder.CustomerGlMasterResponseParse(json);
        IntegrationRequestBuilder.fc();
        Test.stopTest();

       
    }
}