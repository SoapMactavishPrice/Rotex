public class salesQuotationPDFController {
    public id qId {get;set;}
    public QuotedataWrapper quoteRecord {get;set;}
    public boolean showSaveQuote {get;set;}
    public Quote quData {get;set;}
    public boolean isValid{get;set;}
    public PageReference pdf {get; set;}
    public String pdfUrl {get; set;}
    public string pdfName {get;set;}
    public Boolean createNew {get; set;}
    public String body {get; set;}
    public string emailId{get;set;}
    public List<QuoteLineItem> qItem {get;set;}
    public string CC_Addresses{get; set;}
    public String subject {get; set;}
    public Decimal totalQuantity { get; set; }
    public Decimal totalValueINR{ get; set; }
    public string no2words {get;set;}
    public string INCOTerms {get;set;}
    public string PaymentTerms {get;set;}
    public string QuoteNumber {get;set;}
    public String shipToAddress { get; set; }

    public salesQuotationPDFController(){
        qId = ApexPages.currentPage().getparameters().get('id');
        System.debug('qId: ' + qId);
        if (qId == null) { 
            
            qId = '0Q0Hz0000012wHVKAY';
            /*     try {
// Query to get a sample quote ID
Quote sampleQuote = [SELECT Id FROM Quote LIMIT 1];
qId = sampleQuote.Id;
} catch (Exception e) {
System.debug('Error querying for sample quote ID: ' + e.getMessage());
ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'No Quote records found.'));
isValid = false;
return;
}*/
        }
        
        System.debug('Assigned qId: ' + qId);
        quoteRecord = new QuotedataWrapper();
        showSaveQuote = true;
        
        try {
            quData = [SELECT Id, Name, OpportunityId, Pricebook2Id, ContactId, QuoteNumber, IsSyncing, ShippingHandling, Tax, Status, 
                      ExpirationDate, Description, Subtotal, TotalPrice, LineItemCount, BillingStreet, BillingCity, BillingState, BillingPostalCode, 
                      BillingCountry, BillingStateCode, BillingCountryCode, BillingLatitude, BillingLongitude, BillingGeocodeAccuracy, BillingAddress, 
                      ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry, ShippingStateCode, ShippingCountryCode, 
                      ShippingLatitude, ShippingLongitude, ShippingGeocodeAccuracy, ShippingAddress, QuoteToStreet, QuoteToCity, QuoteToState, QuoteToPostalCode, 
                      QuoteToCountry, QuoteToStateCode, QuoteToCountryCode, QuoteToLatitude, QuoteToLongitude, QuoteToGeocodeAccuracy, QuoteToAddress, AdditionalStreet, 
                      AdditionalCity, AdditionalState, AdditionalPostalCode, AdditionalCountry, AdditionalStateCode, AdditionalCountryCode, AdditionalLatitude, 
                      AdditionalLongitude, AdditionalGeocodeAccuracy, AdditionalAddress, BillingName, ShippingName, QuoteToName, AdditionalName, Email, Phone, Fax, 
                      ContractId, AccountId, Discount, GrandTotal, CanCreateQuoteLineItems, Quote_Code__c, Quote_Type__c, Quote_Date__c, Quote_Valid_Till__c, 
                      Quote_Won_Lost_Reason__c, Total_Before_Discount__c, Quote_Value__c, Other_Terms_Conditions__c, Approval_Status__c, Transaction_Type__c, 
                      Shipment__c, Payment_Terms__c, INCO_Terms__c, Commission_Type__c, Commission_Value__c, Account__c,Account.Name,
                      Opportunity.Owner.Email,Rev_No__c,Rev_Date__c,RFQ_No__c,RFQ_Date__c,RFQ_Due_Date__c,Account.SAP_Customer_Code__c,
                      Account.Street__c,Account.City__c,Account.District__c,Account.Postal_Code__c,Account.State__c,Account.Country__c,
                      Account.GSTIN_No__c,Account.Email_Id__c,Warranty_Terms__c,Special_Remarks__c,Delivery_Period__c,Liquidate_Terms__c,
                      Transport_Details__c,Delivery_Location__c,Opportunity.Customer_Enquiry_Ref_No__c,Prices__c,Total_IGST_Amount__c,
                      Total_CGST_Amount__c,Total_SGST_Amount__c,Payment_Terms_Approval_Status__c,Warranty_Terms_Approval_Status__c,
                      Is_Small_Order_Handling__c,Minimum_Offer_Approval_Status__c,
                      Bill_To_Street__c,Bill_To_City__c,Bill_To_Postal_Code__c,Bill_To_State__c,Bill_To_Country__c,
                      Ship_To_Street__c,Ship_To_City__c,Ship_To_Postal_Code__c,Ship_To_State__c,Ship_To_Country__c,
                      Grand_Total__c,Customer_Reference_No__c,Project_Details__c
                      FROM Quote WHERE Id = :qId];
        } catch (Exception e) {
            System.debug('Error querying Quote data: ' + e.getMessage());
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error retrieving Quote data.'));
            isValid = false;
            return;
        }
        //quoteRecord.INCOTerms = quData.INCO_Terms__c;
        INCOTerms = quData.INCO_Terms__c;
        // PaymentTerms = quData.Payment_Terms__c;
        PaymentTerms = '';
        if (quData.Payment_Terms__c != null) {
            for (Schema.PicklistEntry p : Quote.Payment_Terms__c.getDescribe().getPicklistValues()) {
                if (p.getValue() == quData.Payment_Terms__c) {
                    PaymentTerms = p.getLabel();
                    break;
                }
            }
        }


        QuoteNumber = quData.QuoteNumber;
        pdf = Page.salesQuotationPDF;
        pdfUrl = '/apex/salesQuotationPDF?id=' + qId + '#toolbar=0';
        pdfName = quData.Name;
        //subject = 'Sales Quotation for Enquiry No: ' + quData.Opportunity.Customer_Enquiry_Ref_No__c + ' - ' + quData.Account.Name;
        subject = 'Sales Quotation for Customer Ref No: ' + quData.Customer_Reference_No__c + ' - ' + quData.Account.Name;
        // QuotationNo = qudata.QuoteNumber;
        
        isValid = true;
        createNew = true;
        body = 'Dear Sir/Madam, <br/><br/>Please find attached Quote PDF.';
        // Build Ship To Address – skip empty fields
        List<String> shipParts = new List<String>();
        
        if (String.isNotBlank(quData.Ship_To_Street__c))      shipParts.add(quData.Ship_To_Street__c);
        if (String.isNotBlank(quData.Ship_To_City__c))        shipParts.add(quData.Ship_To_City__c);
        if (String.isNotBlank(quData.Ship_To_State__c))       shipParts.add(quData.Ship_To_State__c);
        if (String.isNotBlank(quData.Ship_To_Postal_Code__c)) shipParts.add(quData.Ship_To_Postal_Code__c);
        if (String.isNotBlank(quData.Ship_To_Country__c))     shipParts.add(quData.Ship_To_Country__c);
        
        // Join address with comma
        shipToAddress = String.join(shipParts, ', ');

        if (String.isNotBlank(quData.Email)) {
            emailId = quData.Email;
        } else {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Please Fill Email'));
            isValid = false;
        }  
        if (quData.Warranty_Terms__c == null) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Please Fill Warranty Terms'
            ));
            isValid = false;
        }
        if (quData.Liquidate_Terms__c == null) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Please Fill Liquidate Terms'
            ));
            isValid = false;
        }
        // Small Order Handling condition
        if (quData.Is_Small_Order_Handling__c == true) {
            if (quData.Minimum_Offer_Approval_Status__c == 'Submitted') {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Minimum Offer approval is still in Submitted status (Pending Approval)'
                ));
                isValid = false;
            }
        }
        if (quData.Payment_Terms_Approval_Status__c == 'Submitted') {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Payment Terms approval is still in Submitted status (Pending Approval)'
            ));
            isValid = false;
        }
        if (quData.Warranty_Terms_Approval_Status__c == 'Submitted') {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Warranty Terms approval is still in Submitted status (Pending Approval)'
            ));
            isValid = false;
        }
        if (quData.Approval_Status__c == 'Submitted') {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Validity of Offer approval is still in Submitted status (Pending Approval)'
            ));
            isValid = false;
        }

        
        //quoteRecord.QuotationNo = quData.QuoteNumber;
        
        
        qItem = new List<QuoteLineItem>();
        try {
            qItem = [SELECT Id, LineNumber, CreatedDate, CreatedById, QuoteId, PricebookEntryId, OpportunityLineItemId, Quantity, 
                     UnitPrice, Discount, Description, ServiceDate, Product2Id, SortOrder, ListPrice, Subtotal, TotalPrice, Item_Group__c, 
                     Item_Number__c, Item_Description__c, Specification__c, HSN_SAC_Code__c, Location_Code__c, Type_of_Packing__c, Unit__c, Product2.name,
                     Unit_of_Measure_Code__c, Units_per_Parcel__c, Insurance_Charges__c, EBDTA_Gain_Deficit__c, Estimated_Freight_Per_Kgs__c, 
                     Estimated_Commission_Per_Kgs__c, Estimated_Ocean_Freight_Per_Kgs__c, Estimated_Inspection_Fee_Per_Kgs__c, LC_Confirmation_Charges_Per_Kgs__c, 
                     Other_Incidental_Expenses_Per_Kgs__c, Unit_Price_Excl_VAT_Rate_per_Kgs__c, Line_Amount_Excl_VAT_Qty_Rate__c, 
                     Product2.ProductCode,Product2.Base_UOM__c,Customer_Part_No__c,Sales_Rep_Status__c,Sales_Manager_Status__c,
                     Country_Continent_Sales_H_LOB_Status__c,Global_Sales_Head_Status__c,Rotex_Board_Member_Status__c,Managing_Director_Status__c,
                     Unit_Price__c,Total_Value__c,HSN_Code__c
                     FROM QuoteLineItem WHERE QuoteId = :quData.Id];
        } catch (Exception e) {
            System.debug('Error querying QuoteLineItems: ' + e.getMessage());
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error retrieving Quote Line Items.'));
            isValid = false;
            return;
        }
        
        System.debug('qItem size: ' + qItem.size());
        
        totalQuantity = 0;
        totalValueINR = 0;
        // ❗ Check if any QLI has approval still in Submitted status
        Boolean hasPendingSalesApproval = false;
        
        for (QuoteLineItem qli : qItem) {
            if (
                qli.Sales_Manager_Status__c == 'Submitted' ||
                qli.Sales_Rep_Status__c == 'Submitted' ||
                qli.Country_Continent_Sales_H_LOB_Status__c == 'Submitted' ||
                qli.Global_Sales_Head_Status__c == 'Submitted' ||
                qli.Rotex_Board_Member_Status__c == 'Submitted' ||
                qli.Managing_Director_Status__c == 'Submitted'
            ) {
                hasPendingSalesApproval = true;
                break;
            }
        }
        
        if (hasPendingSalesApproval) {
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Discount approval is still in Submitted status. Please wait until all approvals are completed.'
                )
            );
            isValid = false;
        }
        if (qItem.size() > 0) {
            for (QuoteLineItem qli : qItem) {
                QuoteLineItemWrapper ql = new QuoteLineItemWrapper();
                //ql.Line_Item_Id = qli.Id;
                ql.Name = qli.LineNumber;
                ql.ItemCode = qli.Product2.ProductCode;
                ql.GoodsDescription = qli.Product2.Name;              
                ql.HSNCODE = qli.HSN_Code__c;
                ql.Quantity = qli.Quantity;
                ql.UoM = qli.Product2.Base_UOM__c;
              //ql.Rate = qli.UnitPrice;
              ql.Rate = qli.Unit_Price__c;
                ql.Totalvalue = qli.Total_Value__c;
                ql.CustomerPartNo =qli.Customer_Part_No__c;
                totalQuantity += qli.Quantity;
                if (ql.Totalvalue != null) {
                    System.debug('Totalvalue: ' + ql.Totalvalue);
                    totalValueINR += ql.Totalvalue;
                    System.debug('totalValueINR: ' + totalValueINR);
                }
                
               /* Integer totalValueINRInt = totalValueINR.intValue(); // Convert to Integer if needed
                String totalValueINRWords = convertCurrencytowords.convert(totalValueINRInt);
                
                no2words = totalValueINRWords + ' Rupees Only.';*/
                // Convert Grand Total (including GST)
                Decimal gt = quData.Grand_Total__c != null ? quData.Grand_Total__c : 0;
                Integer gtInt = gt.intValue();   // Converter requires integer
                
                String grandTotalWords = convertCurrencytowords.convert(gtInt);
                no2words = grandTotalWords + ' Rupees Only.';
                
                System.debug(ql.GoodsDescription);
                quoteRecord.lineItems.add(ql); 
            }
            // === ALWAYS MOVE SMALL ORDER HANDLING TO LAST ===
            List<QuoteLineItemWrapper> normalItems = new List<QuoteLineItemWrapper>();
            List<QuoteLineItemWrapper> handlingItems = new List<QuoteLineItemWrapper>();
            
            for (QuoteLineItemWrapper li : quoteRecord.lineItems) {
                if (li.GoodsDescription != null &&
                    li.GoodsDescription.trim().toUpperCase() == 'SMALL ORDER HANDLING') {
                        handlingItems.add(li);
                    } else {
                        normalItems.add(li);
                    }
            }
            
            // Rebuild list: normal first, SOH last
            quoteRecord.lineItems.clear();
            quoteRecord.lineItems.addAll(normalItems);
            quoteRecord.lineItems.addAll(handlingItems);
        } else {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Before making a Quote PDF, please add at least one product.'));
            isValid = false;
        }	
    }
    public static String forceWrap(String s, Integer interval) {
    if (String.isBlank(s)) return s;
    String out = '';
    Integer cnt = 0;
    for (Integer i = 0; i < s.length(); i++) {
        out += s.substring(i, i+1);
        cnt++;
        if (cnt >= interval) {
            out += '<br/>';  // force line break
            cnt = 0;
        }
    }
    return out;
}

    public PageReference save() {
        if (!isValid) {
            return null;
        }
        
        String finalString = '%' + quData.Name + '%';
        List<ContentDocument> contentDocs = [SELECT Id, Title FROM ContentDocument WHERE Title LIKE :finalString ORDER BY CreatedDate DESC LIMIT 1];
        String version = '0';
        if (contentDocs.size() > 0)
            version = contentDocs[0].Title.substringAfterLast('_').substringBeforeLast('.');
        if (!createNew && contentDocs.size() > 0) {
            Database.delete(contentDocs, false);
        }
        
        ContentVersion contentVersion = new ContentVersion();
        contentVersion.ContentLocation = 'S';
        Integer newVersion = Integer.valueOf(version) + 1;
        contentVersion.PathOnClient = quData.Name + '_' + newVersion + '.pdf';
        contentVersion.Title = quData.Name + '_' + newVersion + '.pdf';
        contentVersion.isMajorVersion = false;
        if (Test.isRunningTest())
            contentVersion.VersionData = Blob.toPdf('test');
        else
            contentVersion.VersionData = pdf.getContentAsPDF();
        upsert contentVersion;
        
        contentVersion = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id];
        ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
        contentDocumentLink.ContentDocumentId = contentVersion.ContentDocumentId;
        contentDocumentLink.LinkedEntityId = quData.Id;
        contentDocumentLink.ShareType = 'V';
        upsert contentDocumentLink;
        
        PageReference pageRef = new PageReference('/' + qId);
        pageRef.setRedirect(true);
        return pageRef;    
    }
    
    public PageReference saveAndSend() {
        if (!isValid || String.isBlank(emailId) || String.isBlank(subject)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Email Id and subject are mandatory fields, please verify.'));
            return null;
        }
        
        String finalString = '%' + quData.Name + '%';
        List<ContentDocument> contentDocs = [SELECT Id, Title FROM ContentDocument WHERE Title LIKE :finalString ORDER BY CreatedDate DESC LIMIT 1];
        String version = '0';
        if (contentDocs.size() > 0)
            version = contentDocs[0].Title.substringAfterLast('_').substringBeforeLast('.');
        if (!createNew && contentDocs.size() > 0) {
            Database.delete(contentDocs, false);
        }
        
        List<ContentDocumentLink> cdls = new List<ContentDocumentLink>();
        if (qId != null)
            cdls = [SELECT Id, ContentDocument.LatestPublishedVersionId FROM ContentDocumentLink WHERE LinkedEntityId = :qId];
        Set<String> LatestPublishedVersionIds = new Set<String>();
        for (ContentDocumentLink cdl : cdls) {
            LatestPublishedVersionIds.add(cdl.ContentDocument.LatestPublishedVersionId);
        }
        
        ContentVersion contentVersion = new ContentVersion();
        contentVersion.ContentLocation = 'S';
        Integer newVersion = Integer.valueOf(version) + 1;
        contentVersion.PathOnClient = quData.Name + '_' + newVersion + '.pdf';
        contentVersion.Title = quData.Name + '_' + newVersion + '.pdf';
        contentVersion.isMajorVersion = false;
        if (Test.isRunningTest())
            contentVersion.VersionData = Blob.toPdf('test');
        else
            contentVersion.VersionData = pdf.getContentAsPDF();
        upsert contentVersion;
        
        contentVersion = [SELECT Id, ContentDocumentId, ContentDocument.LatestPublishedVersionId, Title, VersionData
                          FROM ContentVersion WHERE Id = :contentVersion.Id];
        ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
        contentDocumentLink.ContentDocumentId = contentVersion.ContentDocumentId;
        contentDocumentLink.LinkedEntityId = qId;
        contentDocumentLink.ShareType = 'V';
        upsert contentDocumentLink;
        
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[] { emailId });
        if (String.isNotBlank(CC_Addresses)) {
            CC_Addresses = CC_Addresses.replaceAll('[;,:]', ',');
            Set<String> CCEmails = new Set<String>();
            for (String str : CC_Addresses.split(',')) {
                if (String.isNotBlank(str))
                    CCEmails.add(str);
            }
            
            email.setCcAddresses(new List<String>(CCEmails));
            System.debug(CC_Addresses);
        }
        
       /* LatestPublishedVersionIds.add(contentVersion.ContentDocument.LatestPublishedVersionId);
        
        if (LatestPublishedVersionIds.size() > 0) {
            List<String> LatestPublishedVersionIdList = new List<String>();
            LatestPublishedVersionIdList.addAll(LatestPublishedVersionIds);
            email.setEntityAttachments(LatestPublishedVersionIdList);
        } */
        
        email.setEntityAttachments(new List<String>{ contentVersion.ContentDocument.LatestPublishedVersionId });

        
        if (String.isNotBlank(quData.Opportunity.Owner.Email)) {
            email.setReplyTo(quData.Opportunity.Owner.Email);
            email.setBccAddresses(new List<String> { quData.Opportunity.Owner.Email });
        }
        email.setSubject(subject);
        email.setHtmlBody(body);
        
        Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        
        PageReference pageRef = new PageReference('/' + qId);
        pageRef.setRedirect(true);
        return pageRef;
    }   
    
    public PageReference cancel() {
        PageReference pageRef = new PageReference('/' + qId);
        pageRef.setRedirect(true);
        return pageRef;
    }
    
    class QuotedataWrapper {
        public String CurrencyIsoCode {get;set;}
        // public String INCOTerms {get; set;}
        /*     public String PINo {get;set;}

public String CountryofOrigin {get;set;}
public String CountryofFinalDestination {get;set;}
public String PortofLoading {get;set;} 
public String PortofDischarge {get;set;}
public String FinalDestination {get;set;}
public Date Quotecreateddate {get;set;} 
public String IECNO {get;set;}
public String CustomsReg {get;set;}
public String CINNo {get;set;}
public String ADCode {get;set;}
public String PAN {get;set;}
public String GSTIN {get;set;}
public String BillingName {get;set;}
public String Baddress {get;set;}

public String AcntNo {get;set;}
public String BankName {get;set;}
public String Bankbranch {get;set;}
public String SwiftCode {get;set;}
public String CSwiftCode {get;set;}*/
        public List<QuoteLineItemWrapper> lineItems {get; set;}
        public QuotedataWrapper() {
            lineItems = new List<QuoteLineItemWrapper>();
        }
    }
    
    class QuoteLineItemWrapper {
        public String Name {get;set;}
        public String ItemCode {get;set;}
        public String GoodsDescription {get;set;}
        public String HSNCODE {get;set;}
        public Decimal Quantity {get;set;}
        public string CustomerPartNo {get;set;}
        public Decimal Rate {get;set;}
        public string UoM {get;set;}
        public Decimal Totalvalue {get;set;}
        public Decimal TotalvaluePlusGST {get;set;}
        // public Integer UnitPrice {get;set;}
        // public Integer Grand_Total_c {get;set;}
        // public String UnitPriceValue {get;set;}
        // public String Grand_TotalValue {get;set;}
        // public String HSN_Master_c {get;set;}
        // public Decimal CGST {get;set;}
        // public Decimal SGST {get;set;}
        // public Decimal IGST {get;set;}
        // public Decimal CGSTAMT {get;set;}
        // public Decimal SGSTAMT {get;set;}
        // public Decimal IGSTAMT {get;set;}
        // public String Display_Description {get;set;}
        //public String IECNO {get;set;}
        // public String CustomsReg {get;set;}
        // public String CINNo {get;set;}
        //  public String PAN {get;set;}
        //  public String GSTIN {get;set;}
        // public String Line_Item_Id {get;set;}
        // public String Part_No_c {get;set;}
        // public String Product_Description {get;set;}
        public String getWrappedDescription() {
    return salesQuotationPDFController.forceWrap(this.GoodsDescription, 20);
}

    }
}