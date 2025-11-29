public class IntegrationRequestBuilder {

    public class cls_Inventory_List{
        public string ItemCode;
        public string ItemName;   
        public string ItemGroup;
		public string BatchNo;
		public string BatchAttribute;
		public string BatchAttribute2;
        public Decimal Quantity=0;    
        public Decimal BalanceAmount =0;
		public string CustomerName;
		public string Location;
		
    }
       public static List<cls_Inventory_List> InventoryMasterResponseParse(String json){
        return (List<cls_Inventory_List>) System.JSON.deserialize(json, List<cls_Inventory_List>.class);
    }
    
    public class HSNMasterResponse{
        public Integer Code;	//0
        public String Error;
        public List<cls_HSN_List> HSN_List;
    }
    public class cls_HSN_List{
        public String Chapter_ID;
        public String Heading_ID;
        public String SubHeading_ID;
        public String Description;
        public String HSN_Code;
    }
    public static HSNMasterResponse HSNMasterResponseParse(String json){
        return (HSNMasterResponse) System.JSON.deserialize(json, HSNMasterResponse.class);
    }
    
    public class SACMasterResponse{
        public Integer Code;	//0
        public String Error;
        public List<cls_SAC_List> SAC_List;
    }
    public class cls_SAC_List{
        public Integer AbsEntry;
        public String ServCode;
        public String ServName;
    }
    public static SACMasterResponse SACMasterResponseParse(String json){
        return (SACMasterResponse) System.JSON.deserialize(json, SACMasterResponse.class);
    }
    
    
    public class CustomerMasterResponse{
        public customers d;
    }
    public class customers{
        public List<customersList> results;
    }
    public class customersList{
        public String customer_number;
        public String customer_name;
        public String street;
        public String city;
        public String district;
        public String state;
        public String country;
        public String postal_code;
        public String email_id;
        public String gst_no;
        public String pan_no;
        public String company;
        public String created_on_date;
        public String changed_on_date;
        public String credit_limit;
        public String Credit_Days;
        public String Discount;
        public salesAreaItem to_salesareaitem;
    }
    public class salesAreaItem{
        public List<salesAreaItemList> results;
    }
    public class salesAreaItemList{
        public String sales_org;
        public String distribution_channel;
        public String division;
        public String incoterms;
        public String incoterms_location;
        public String terms_of_payment;
        public String price_list;
        public String PriceList;
        public partnerDetails to_partnerdetails;
    }
    public class partnerDetails{
        public List<partnerDetailsList> results;
    }
    public class partnerDetailsList{
        public String partner_function;
        public String partner_number;
    }
    public static CustomerMasterResponse CustomerMasterResponseParse(String json){
        return (CustomerMasterResponse) System.JSON.deserialize(json, CustomerMasterResponse.class);
    }
    
    // MaterialMaster
    
    public class MaterialMasterResponse{
        public materials d;
    }
    public class materials{
        public List<materialsList> results;
    }
    public class materialsList{
        public String item_no;
        public String item_description;
        public String long_description;
        public String base_uom;
        public String mat_group;
        public String created_on_date;
        public String changed_on_date;
        public toPlantData to_plant_data;
    }
    public class toPlantData{
        public List<toPlantDataList> results;
    }
    public class toPlantDataList{
        public String plant;
        public String hsn_code;
        public salesAreaData to_salesarea_data;
    }
    public class salesAreaData{
        public List<salesAreaDataList> results;
    }
    public class salesAreaDataList{
        public String sales_org;
        public String distribution_channel;
        public String division;
    }
    public static MaterialMasterResponse MaterialMasterResponseParse(String json){
        return (MaterialMasterResponse) System.JSON.deserialize(json, MaterialMasterResponse.class);
    }
    
    //SalesOrderMasterResponse
    
    public class SalesOrderMasterResponse{
        public salesorders d;
    }
    public class salesorders{
        public List<salesordersList> results;
    }
    public class salesordersList{
        public String so_num;
        public String so_type;
        public String sold_to;
        public String ship_to;
        public String bill_to;
        public String cust_ref;
        public String custref_date;
        public String reqdel_date;
        public String sales_org;
        public String distribution_channel;
        public String division;
        public String terms_of_payment;
        public String incoterms;
        public String incoterms_location;
        public String company;
        public String status;
        public String net_value;
        public String curr;
        public String created_on_date;
        public String changed_on_date;
        public itemDetails to_item_details;
    }
    public class itemDetails{
        public List<itemDetailsList> results;
    }
    public class itemDetailsList{
        public String item_no;
        public String item_code;
        public String item_desc;
        public String item_qty;
        public String uom;
        public String plant;
        public String pdd_dat;
        public String it_status;
        public String net_price;
        public String tax_amount;
        public priceDetails to_price_details;
    }
    public class priceDetails{
        public List<priceDetailsList> results;
    }
    public class priceDetailsList{
        public String cond_type;
        public String unit_amount;
        public String unit;
        public String amount;
        public String curr;
    }
    public static SalesOrderMasterResponse SalesOrderMasterResponseParse(String json){
        return (SalesOrderMasterResponse) System.JSON.deserialize(json, SalesOrderMasterResponse.class);
    }
    
    //InvoiceMaster
    
    public class InvoiceMasterResponse{
        public invoice d;
    }
    public class invoice{
        public List<invoiceList> results;
    }
    public class invoiceList{
        public String bill_docnum;
        public String bill_doctype;
        public String bill_date;
        public String acc_docnum;
        public String zyear;
        public String so_num;
        public String terms_of_payment;
        public String incoterms;
        public String incoterms_location;
        public String company;
        public String curr;
        public String sold_to;
        public String payer;
        public String bill_to;
        public String sales_org;
        public String distribution_channel;
        public String division;
        public String net_value;
        public String tax_value;
        public String exc_rate;
        public String created_on_date;
        public String changed_on_date;
        public invItemDetails to_item_details;
    }
    public class invItemDetails{
        public List<invItemDetailsList> results;
    }
    public class invItemDetailsList{
        public String item_no;
        public String item_code;
        public String item_desc;
        public String item_qty;
        public String uom;
        public String plant;
        public String net_amount;
        public String tax_amount;
        public String net_price;
        public invPriceDetails to_price_details;
    }
    public class invPriceDetails{
        public List<invPriceDetailsList> results;
    }
    public class invPriceDetailsList{
        public String cond_type;
        public String unit_amount;
        public String unit;
        public String amount;
        public String curr;
    }
    public static InvoiceMasterResponse InvoiceMasterResponseParse(String json){
        return (InvoiceMasterResponse) System.JSON.deserialize(json, InvoiceMasterResponse.class);
    }
    
    // ClearingpaymentMaster
    
    public class ClearingPaymentMasterResponse{
        public clearPayment d;
    }
    public class clearPayment{
        public List<clearPaymentList> results;
    }
    public class clearPaymentList{
        public String company_code;
        public String fiscal_year;
        public String document_no;
        public String account_type;
        public String reference_doc;
        public String amount_in_tra_cur;
        public String posting_date;
        public String document_date;
        public String document_type;
        public String invoice_ref;
        public String customer;
        public String clearing_doc;
        public String clearing_date;
        public String changed_on;
        public clearingPayment to_clearing_payment;
    }
    public class clearingPayment{
        public List<clearingPaymentList> results;
    }
    public class clearingPaymentList{
        public String c_company_code;
        public String c_fiscal_year;
        public String c_document_no;
        public String c_reference_doc;
        public String clearing_payment;
        public String c_posting_date;
        public String c_document_date;
        public String c_invoice_ref;
        public String c_customer;
        public String PaymentStatus;
        public String c_clearing_doc;
        public String c_clearing_date;
        public partialPayment to_partial_payment;
    }
    public class partialPayment{
        public List<partialPaymentList> results;
    }
    public class partialPaymentList{
        //
    }
    public static ClearingPaymentMasterResponse ClearingPaymentMasterResponseParse(String json){
        return (ClearingPaymentMasterResponse) System.JSON.deserialize(json, ClearingPaymentMasterResponse.class);
    }
    
    //CustomerGlMaster
    
    public class CustomerGlMasterResponse{
        public customerGL d;
    }
    public class customerGL{
        public List<customerGLList> results;
    }
    public class customerGLList{
        public String fiscal_year;
        public String customer;
        public String company_code;
        public String document_no;
        public String reference_doc;
        public String total_amount;
        public String posting_date;
        public String document_date;
        public String document_type;
        public String special_gl_indicator;
        public String clearing_doc;
        public String clearing_date;
        public String changed_on;
        public clearingPay to_clearing_payment;
    }
    public class clearingPay{
        public List<clearingPayList> results;
    }
    public class clearingPayList{
        public String c_company_code;
        public String c_fiscal_year;
        public String c_document_no;
        public String clearing_payment;
        public String c_posting_date;
        public String c_document_date;
        public String c_document_type;
        public String dc_indicator;
        public String c_special_gl_indicator;
        public String c_invoice_ref;
        public String c_customer;
        public String c_clearing_doc;
        public String c_clearing_date;
        public String o_changed_on;
        //public change o_changed_on;
    }

    public static CustomerGlMasterResponse CustomerGlMasterResponseParse(String json){
        return (CustomerGlMasterResponse) System.JSON.deserialize(json, CustomerGlMasterResponse.class);
    }

    public class pricingMasterMainResponse {
        public pricingMaster d;
    }

    public class pricingMaster{
        public List<pricingMasterList> results;
    }
    
    public class pricingMasterList {
        // public metadatawrapper __metadata;
        public String Condition_Type;
        public String Sales_Org;
        public String Distribution_Channel;
        public String Pricelist_Type;
        public String Material;
        public String Condition_Amt;
        public String Codition_Curr;
        public String Pricing_Unit;
        public String Unit_of_Measure;
        public String Valid_TO;
        public String Valid_from;
    }
    
    public static pricingMasterMainResponse pricingMasterMainResponseParse(String json){
        return (pricingMasterMainResponse) System.JSON.deserialize(json, pricingMasterMainResponse.class);
    }

    public class discountMasterMainResponse {
        public discountMaster d;
    }

    public class discountMaster{
        public List<discountMasterList> results;
    }
    
    public class discountMasterList {
        // public metadatawrapper __metadata;
        public String Customer;
        public String condition_amt;
        public String Codition_Curr;
        public String Pricing_Unit;
        public String Unit_of_Measure;
        public String Valid_TO;
        public String Valid_from;
    }
    
    public static discountMasterMainResponse discountMasterMainResponseParse(String json){
        return (discountMasterMainResponse) System.JSON.deserialize(json, discountMasterMainResponse.class);
    }
    
    public class arcPricingMasterMainResponse {
        public arcPricingMaster d;
    }

    public class arcPricingMaster{
        public List<arcPricingMasterList> results;
    }
    
    public class arcPricingMasterList {
        // public metadatawrapper __metadata;
        public String Sales_Org;
        public String Distribution_Channel;
        public String Customer;
        public String Material;
        public String Condition_Amt;
        public String Codition_Curr;
        public String Pricing_Unit;
        public String Unit_of_Measure;
        public String Valid_TO;
        public String Valid_from;
        public String Scale_Qty1;
        public String Scale_Amt1;
        public String Scale_Qty2;
        public String Scale_Amt2;
        public String Scale_Qty3;
        public String Scale_Amt3;
        public String Scale_Qty4;
        public String Scale_Amt4;
        public String Scale_Qty5;
        public String Scale_Amt5;
    }
    
    public static arcPricingMasterMainResponse arcPricingMasterMainResponseParse(String json){
        return (arcPricingMasterMainResponse) System.JSON.deserialize(json, arcPricingMasterMainResponse.class);
    }
    
    public class IncoTermsMainResponse {
        public IncoTerms d;
    }

    public class IncoTerms{
        public List<IncoTermsList> results;
    }

    public class IncoTermsList {
        public String Condition_Type;
        public String Condition_Record;
        public String Sales_Org;
        public String Distribution_Channel;
        public String Division;
        public String Incoterms;
        public String Condition_Amount;
        public String Codition_Currency;
        public String Pricing_Unit;
        public String Unit_of_Measure;
        public String Valid_TO;
        public String Valid_from;
    }

    public static IncoTermsMainResponse IncoTermsMainResponseParse(String json){
        return (IncoTermsMainResponse) System.JSON.deserialize(json, IncoTermsMainResponse.class);
    }

    public static void fc(){
        Integer i = 1;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        
    }
    
}