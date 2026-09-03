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

    public String userSignature { get; set; }
    public String attachmentData { get; set; }
    public List<Map<String, String>> attachedFiles { get; set; }
    
    // New properties for Amendment Quote functionality
    public Boolean showAmendmentOptions { get; set; }
    public String selectedQuoteType { get; set; }
    public Boolean isAmendmentQuote { get; set; }
    public List<SelectOption> quoteTypeOptions { get; set; }
    
    public salesQuotationPDFController(){
        qId = ApexPages.currentPage().getparameters().get('id');
        System.debug('===== START salesQuotationPDFController Constructor =====');
        System.debug('qId: ' + qId);
        if (qId == null) { 
            qId = '0Q0Hz0000012wHVKAY';
        }
        
        System.debug('Assigned qId: ' + qId);
        quoteRecord = new QuotedataWrapper();
        showSaveQuote = true;
        showAmendmentOptions = false;
        isAmendmentQuote = false;
        quoteTypeOptions = new List<SelectOption>();
        quoteTypeOptions.add(new SelectOption('', '-- Select --'));
        quoteTypeOptions.add(new SelectOption('Normal', 'Normal Quote'));
        quoteTypeOptions.add(new SelectOption('Amendment', 'Amendment Quote'));
        selectedQuoteType = '';  // Set to empty initially
        
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
                      Is_Small_Order_Handling__c,Minimum_Offer_Approval_Status__c, Opportunity.Project_Contact__r.Name,
                      Bill_To_Street__c,Bill_To_City__c,Bill_To_District__c,Bill_To_Postal_Code__c,Bill_To_State__c,Bill_To_Country__c,
                      Ship_To_Street__c,Ship_To_City__c,Ship_To_Postal_Code__c,Ship_To_State__c,Ship_To_Country__c,
                      Grand_Total__c,Customer_Reference_No__c,Project_Details__c,
                      Final_Warranty_Terms_Approver__c,MD_Warranty_Status__c,BM_Warranty_Status__c,GS_Warranty_Status__c,CH_Warranty_Status__c,SM_Warranty_Status__c,
                      Final_Validity_Offer_Approver__c,MD_Validity_Offer_Status__c,BM_Validity_Offer_Status__c,GS_Validity_Offer_Status__c,CH_Validity_Offer_Status__c,SM_Validity_Offer_Status__c,
                      Final_Minimum_Offer_Value_Approver__c,MD_Min_Offer_Status__c,BM_Min_Offer_Status__c,GS_Min_Offer_Status__c,CH_Min_Offer_Status__c,SM_Min_Offer_Status__c,
                      Final_Total_Value_Approver__c,MD_Value_Status__c,BM_Value_Status__c,GS_Value_Status__c,CH_Value_Status__c,SM_Value_Status__c,
                      owner.email, Opportunity.Quote_Reason__c, Amendment_Quote__c
                      FROM Quote WHERE Id = :qId];
        } catch (Exception e) {
            System.debug('Error querying Quote data: ' + e.getMessage());
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error retrieving Quote data.'));
            isValid = false;
            return;
        }
        
        // Check if Quote Reason is PO ARC or PO Non ARC
        String quoteReason = quData.Opportunity.Quote_Reason__c;
        System.debug('===== QUOTE REASON CHECK =====');
        System.debug('Quote Reason from Opportunity: ' + quoteReason);
        System.debug('Is Quote Reason NULL or Empty? ' + String.isBlank(quoteReason));
        
        if (quoteReason == 'PO ARC' || quoteReason == 'PO Non ARC') {
            showAmendmentOptions = true;
            System.debug('✅ showAmendmentOptions set to TRUE (Quote Reason is PO ARC or PO Non ARC)');
        } else {
            showAmendmentOptions = false;
            System.debug('❌ showAmendmentOptions set to FALSE (Quote Reason is NOT PO ARC or PO Non ARC)');
            System.debug('   Current Quote Reason value: "' + quoteReason + '"');
        }
        System.debug('showAmendmentOptions final value: ' + showAmendmentOptions);
        
        // If Amendment_Quote__c is true, set selectedQuoteType to Amendment
        System.debug('===== AMENDMENT QUOTE CHECK =====');
        System.debug('Amendment_Quote__c value: ' + quData.Amendment_Quote__c);
        if (quData.Amendment_Quote__c == true) {
            selectedQuoteType = 'Amendment';
            isAmendmentQuote = true;
            System.debug('✅ Amendment_Quote__c is true, setting to Amendment');
        } else {
            System.debug('❌ Amendment_Quote__c is false or null, keeping as Normal');
        }
        System.debug('selectedQuoteType: ' + selectedQuoteType);
        System.debug('isAmendmentQuote: ' + isAmendmentQuote);
        
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
        
        // Set subject based on Amendment status
        updateSubject();
        System.debug('===== INITIAL SUBJECT =====');
        System.debug('Initial subject: ' + subject);
        
        isValid = true;
        createNew = true;
        body = 'Dear Sir/Madam, <br/><br/>Please find attached Quote PDF.';
        try {
            User currentUser = [SELECT EmailEncodingKey, Email, Signature FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            userSignature = String.isNotBlank(currentUser.Signature) 
            ? currentUser.Signature.replace('\n', '<br/>') 
            : '';
        } catch (Exception e) {
            userSignature = '';
        }
        
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
        
        if (quData.Final_Warranty_Terms_Approver__c != null && (
            quData.MD_Warranty_Status__c == 'Submitted' ||
            quData.BM_Warranty_Status__c == 'Submitted' ||
            quData.GS_Warranty_Status__c == 'Submitted' ||
            quData.CH_Warranty_Status__c == 'Submitted' ||
            quData.SM_Warranty_Status__c == 'Submitted'
        )
           ) {
               ApexPages.addMessage(new ApexPages.Message(
                   ApexPages.Severity.ERROR,
                   'Warranty Terms Approval Is Still In Submitted Status (Pending Approval)'
               ));
               isValid = false;
           }
        if (quData.Final_Validity_Offer_Approver__c != null && (
            quData.MD_Validity_Offer_Status__c == 'Submitted' ||
            quData.BM_Validity_Offer_Status__c == 'Submitted' ||
            quData.GS_Validity_Offer_Status__c == 'Submitted' ||
            quData.CH_Validity_Offer_Status__c == 'Submitted' ||
            quData.SM_Validity_Offer_Status__c == 'Submitted'
        )
           ) {
               ApexPages.addMessage(new ApexPages.Message(
                   ApexPages.Severity.ERROR,
                   'Validity Of Offer Approval Is Still In Submitted Status (Pending Approval)'
               ));
               isValid = false;
           }
        
        /*if (quData.Payment_Terms_Approval_Status__c == 'Submitted') {
ApexPages.addMessage(new ApexPages.Message(
ApexPages.Severity.ERROR,
'Payment Terms approval is still in Submitted status (Pending Approval)'
));
isValid = false;
}*/
        
        if (quData.Final_Minimum_Offer_Value_Approver__c != null && (
            quData.MD_Min_Offer_Status__c == 'Submitted' ||
            quData.BM_Min_Offer_Status__c == 'Submitted' ||
            quData.GS_Min_Offer_Status__c == 'Submitted' ||
            quData.CH_Min_Offer_Status__c == 'Submitted' ||
            quData.SM_Min_Offer_Status__c == 'Submitted'
        )
           ) {
               ApexPages.addMessage(new ApexPages.Message(
                   ApexPages.Severity.ERROR,
                   'Minimum Offer Approval Is Still In Submitted Status (Pending Approval)'
               ));
               isValid = false;
           }
        if (quData.Final_Total_Value_Approver__c != null && (
            quData.MD_Value_Status__c == 'Submitted' ||
            quData.BM_Value_Status__c == 'Submitted' ||
            quData.GS_Value_Status__c == 'Submitted' ||
            quData.CH_Value_Status__c == 'Submitted' ||
            quData.SM_Value_Status__c == 'Submitted'
        )
           ) {
               ApexPages.addMessage(new ApexPages.Message(
                   ApexPages.Severity.ERROR,
                   'Total Quote Value Approval Is Still In Submitted Status (Pending Approval)'
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
                     Product2.ProductCode,Product2.Base_UOM__c,Customer_Part_No__c,Sales_Rep_Status__c,
                     Unit_Price__c,Total_Value__c,HSN_Code__c,
                     Final_Discount_Approver__c,Managing_Director_Status__c,Rotex_Board_Member_Status__c,Global_Sales_Head_Status__c,Country_Continent_Sales_H_LOB_Status__c,
                     Sales_Manager_Status__c
                     FROM QuoteLineItem WHERE QuoteId = :quData.Id order by SortOrder asc];
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
        for (QuoteLineItem qli : qItem) {
            if (
                qli.Final_Discount_Approver__c != null &&
                (
                    qli.Managing_Director_Status__c == 'Submitted' ||
                    qli.Rotex_Board_Member_Status__c == 'Submitted' ||
                    qli.Global_Sales_Head_Status__c == 'Submitted' ||
                    qli.Country_Continent_Sales_H_LOB_Status__c == 'Submitted' ||
                    qli.Sales_Manager_Status__c == 'Submitted'
                )
            ) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Discount approval is still in Submitted status (Pending Approval)'
                ));
                isValid = false;
                break;
            }
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
        
        System.debug('===== END salesQuotationPDFController Constructor =====');
        System.debug('Final showAmendmentOptions: ' + showAmendmentOptions);
        System.debug('Final selectedQuoteType: ' + selectedQuoteType);
        System.debug('Final isAmendmentQuote: ' + isAmendmentQuote);
        System.debug('Final subject: ' + subject);
    }
    
    // New method to update subject based on Amendment status
    private void updateSubject() {
        System.debug('===== updateSubject() called =====');
        System.debug('isAmendmentQuote: ' + isAmendmentQuote);
        
        String customerRef = quData.Customer_Reference_No__c;
        String accountName = quData.Account.Name;
        
        System.debug('Customer_Reference_No__c: ' + customerRef);
        System.debug('Account.Name: ' + accountName);
        
        // Handle null/empty values
        if (String.isBlank(customerRef)) {
            customerRef = 'N/A';
            System.debug('Customer_Reference_No__c is blank, using N/A');
        }
        if (String.isBlank(accountName)) {
            accountName = 'Unknown';
            System.debug('Account.Name is blank, using Unknown');
        }
        
        if (isAmendmentQuote) {
            subject = 'Amendment for Customer Ref No: ' + customerRef + ' - ' + accountName;
            System.debug('✅ Amendment Quote - Subject set to: ' + subject);
        } else {
            subject = 'Sales Quotation for Customer Ref No: ' + customerRef + ' - ' + accountName;
            System.debug('✅ Normal Quote - Subject set to: ' + subject);
        }
        System.debug('===== end updateSubject() =====');
    }
    
    // Method to handle quote type selection change
    public void updateQuoteType() {
        System.debug('===== updateQuoteType() called =====');
        System.debug('selectedQuoteType received: ' + selectedQuoteType);
        
        if (selectedQuoteType == 'Amendment') {
            isAmendmentQuote = true;
            System.debug('✅ Setting isAmendmentQuote to TRUE');
        } else if (selectedQuoteType == 'Normal') {
            isAmendmentQuote = false;
            System.debug('✅ Setting isAmendmentQuote to FALSE (Normal)');
        } else {
            // If empty selection, default to false
            isAmendmentQuote = false;
            System.debug('⚠️ Empty selection, setting isAmendmentQuote to FALSE');
        }
        updateSubject();
        System.debug('Quote type changed to: ' + selectedQuoteType);
        System.debug('Is Amendment: ' + isAmendmentQuote);
        System.debug('===== end updateQuoteType() =====');
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
    
    // Modified save method to handle Amendment Quote checkbox
    public PageReference save() {
        System.debug('===== save() called =====');
        attachmentData = ApexPages.currentPage().getParameters().get('attachmentData');
        if (!isValid) {
            System.debug('❌ isValid is false, returning null');
            return null;
        }
        
        // Update Amendment_Quote__c checkbox
        System.debug('isAmendmentQuote: ' + isAmendmentQuote);
        System.debug('quData.Amendment_Quote__c: ' + quData.Amendment_Quote__c);
        if (isAmendmentQuote != quData.Amendment_Quote__c) {
            Quote qUpdate = new Quote(Id = quData.Id, Amendment_Quote__c = isAmendmentQuote);
            update qUpdate;
            quData.Amendment_Quote__c = isAmendmentQuote;
            System.debug('✅ Updated Amendment_Quote__c to: ' + isAmendmentQuote);
        } else {
            System.debug('⚠️ Amendment_Quote__c unchanged');
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
       // Integer newVersion = Integer.valueOf(version) + 1;
        Integer newVersion = 1;
        
        try {
            newVersion = Integer.valueOf(version) + 1;
        } catch (Exception e) {
            System.debug('Invalid version found in file title: ' + version);
            newVersion = 1;
        }
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

        // Save user-uploaded files to Quote record
        if (String.isNotBlank(attachmentData)) {
            try {
                List<Object> fileList = (List<Object>) JSON.deserializeUntyped(attachmentData);
                List<ContentVersion> uploadedCVs = new List<ContentVersion>();

                for (Object fileObj : fileList) {
                    Map<String, Object> fileMap = (Map<String, Object>) fileObj;
                    String fileName   = (String) fileMap.get('name');
                    String fileBase64 = (String) fileMap.get('data');

                    ContentVersion cv = new ContentVersion();
                    cv.ContentLocation = 'S';
                    cv.PathOnClient    = fileName;
                    cv.Title           = fileName;
                    cv.isMajorVersion  = false;
                    cv.VersionData     = EncodingUtil.base64Decode(fileBase64);
                    uploadedCVs.add(cv);
                }

                if (!uploadedCVs.isEmpty()) {
                    insert uploadedCVs;

                    Set<Id> cvIds = new Set<Id>();
                    for (ContentVersion cv : uploadedCVs) cvIds.add(cv.Id);

                    List<ContentVersion> insertedCVs = [
                        SELECT Id, ContentDocumentId
                        FROM ContentVersion
                        WHERE Id IN :cvIds
                    ];

                    List<ContentDocumentLink> cdls = new List<ContentDocumentLink>();
                    for (ContentVersion cv : insertedCVs) {
                        ContentDocumentLink cdl = new ContentDocumentLink();
                        cdl.ContentDocumentId = cv.ContentDocumentId;
                        cdl.LinkedEntityId    = qId;
                        cdl.ShareType         = 'V';
                        cdls.add(cdl);
                    }
                    insert cdls;
                }
            } catch (Exception e) {
                System.debug('Error saving uploaded attachments: ' + e.getMessage());
            }
        }
        /*
        PageReference pageRef = new PageReference('/' + qId);
        pageRef.setRedirect(true);
        System.debug('===== end save() =====');
        return pageRef;  
        */
        // ============================================================
        // UPDATE QUOTE STATUS TO SUBMITTED
        // Only update when current status is:
        // Draft
        // Under Review by Sales Rep
        // Submit for SOA Approval
        // ============================================================
        
        if (
            quData.Status == 'Draft' ||
            quData.Status == 'Under Review by Sales Rep' ||
            quData.Status == 'Submit for SOA Approval'
        ) {
            Quote qToUpdate = new Quote(
                Id = quData.Id,
                Status = 'Submitted'
            );
            
            update qToUpdate;
            
            System.debug(
                '✅ Quote Status updated from ' +
                quData.Status +
                ' to Submitted'
            );
        } else {
            System.debug(
                '⚠️ Quote Status is ' +
                quData.Status +
                '. Status update skipped.'
            );
        }
        
        
        // ============================================================
        // REDIRECT TO QUOTE
        // ============================================================
        
        PageReference pageRef = new PageReference('/' + qId);
        pageRef.setRedirect(true);
        
        System.debug('===== end save() =====');
        
        return pageRef;
    }
    
    // Modified saveAndSend method to handle Amendment Quote
    public PageReference saveAndSend() {
        System.debug('===== saveAndSend() called =====');
        attachmentData = ApexPages.currentPage().getParameters().get('attachmentData');
        if (!isValid || String.isBlank(emailId) || String.isBlank(subject)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Email Id and subject are mandatory fields, please verify.'));
            System.debug('❌ Validation failed: isValid=' + isValid + ', emailId=' + emailId + ', subject=' + subject);
            return null;
        }
        
        // Update Amendment_Quote__c checkbox
        System.debug('isAmendmentQuote: ' + isAmendmentQuote);
        System.debug('quData.Amendment_Quote__c: ' + quData.Amendment_Quote__c);
        if (isAmendmentQuote != quData.Amendment_Quote__c) {
            Quote qUpdate = new Quote(Id = quData.Id, Amendment_Quote__c = isAmendmentQuote);
            update qUpdate;
            quData.Amendment_Quote__c = isAmendmentQuote;
            System.debug('✅ Updated Amendment_Quote__c to: ' + isAmendmentQuote);
        }
        
        // For Amendment Quote, only send email without PDF
        if (isAmendmentQuote) {
            System.debug('✅ Amendment Quote - Sending email without PDF');
            // Update subject for amendment
            updateSubject();
            
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
            }
            
            if (String.isNotBlank(quData.Opportunity.Owner.Email)) {
                email.setReplyTo(quData.Opportunity.Owner.Email);
                email.setBccAddresses(new List<String> { quData.Opportunity.Owner.Email });
            }
            email.setSubject(subject);
            email.setHtmlBody(body);
            email.setUseSignature(true);
            email.setSaveAsActivity(true);
            email.setWhatId(quData.Id);
            
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            /*
            if(results != null && results.size() > 0 && results[0].isSuccess()) {
                Quote qToUpdate = new Quote(
                    Id = quData.Id,
                    Status = 'In Review with Customer',
                    In_Review_with_Customer_Date_Time__c = System.now()
                );
                update qToUpdate;
                System.debug('✅ Email sent successfully for Amendment Quote');
            } else {
                System.debug('❌ Email sending failed for Amendment Quote');
            }
            */
            if(results != null && results.size() > 0 && results[0].isSuccess()) {
                
                // ============================================================
                // UPDATE QUOTE STATUS AFTER SUCCESSFUL SAVE & SEND
                //
                // Only these active statuses should move to Submitted:
                // Draft
                // Under Review by Sales Rep
                // Submit for SOA Approval
                //
                // All other active Quote statuses remain unchanged.
                // ============================================================
                
                if (
                    quData.Status == 'Draft' ||
                    quData.Status == 'Under Review by Sales Rep' ||
                    quData.Status == 'Submit for SOA Approval'
                ) {
                    
                    Quote qToUpdate = new Quote(
                        Id = quData.Id,
                        Status = 'Submitted'
                    );
                    
                    update qToUpdate;
                    
                    System.debug(
                        '✅ Quote Status updated from ' +
                        quData.Status +
                        ' to Submitted'
                    );
                    
                } else {
                    
                    System.debug(
                        '⚠️ Quote Status is ' +
                        quData.Status +
                        '. Status update skipped.'
                    );
                }
                
                System.debug('✅ Email sent successfully for Normal Quote');
                
            } else {
                
                System.debug('❌ Email sending failed for Normal Quote');
            }
            PageReference pageRef = new PageReference('/' + qId);
            pageRef.setRedirect(true);
            System.debug('===== end saveAndSend() (Amendment) =====');
            return pageRef;
        }
        
        // Original saveAndSend logic for Normal Quote (with PDF)
        System.debug('✅ Normal Quote - Sending email with PDF');
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
        Integer newVersion = 1;
        
        try {
            newVersion = Integer.valueOf(version) + 1;
        } catch (Exception e) {
            System.debug('Invalid version found in file title: ' + version);
            newVersion = 1;
        }
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
        }
        
        List<String> attachmentIds = new List<String>();
        attachmentIds.add(contentVersion.ContentDocument.LatestPublishedVersionId);

        if (String.isNotBlank(attachmentData)) {
            try {
                List<Object> fileList = (List<Object>) JSON.deserializeUntyped(attachmentData);
                List<ContentVersion> uploadedCVs = new List<ContentVersion>();
                for (Object fileObj : fileList) {
                    Map<String, Object> fileMap = (Map<String, Object>) fileObj;
                    String fileName   = (String) fileMap.get('name');
                    String fileBase64 = (String) fileMap.get('data');

                    ContentVersion cv = new ContentVersion();
                    cv.ContentLocation = 'S';
                    cv.PathOnClient    = fileName;
                    cv.Title           = fileName;
                    cv.isMajorVersion  = false;
                    cv.VersionData     = EncodingUtil.base64Decode(fileBase64);
                    uploadedCVs.add(cv);
                }

                if (!uploadedCVs.isEmpty()) {
                    insert uploadedCVs;
                    Set<Id> cvIds = new Set<Id>();
                    for (ContentVersion cv : uploadedCVs) cvIds.add(cv.Id);

                    List<ContentVersion> insertedCVs = [
                        SELECT Id, ContentDocumentId, ContentDocument.LatestPublishedVersionId
                        FROM ContentVersion
                        WHERE Id IN :cvIds
                    ];

                    List<ContentDocumentLink> cdlsList = new List<ContentDocumentLink>();
                    for (ContentVersion cv : insertedCVs) {
                        ContentDocumentLink cdl = new ContentDocumentLink();
                        cdl.ContentDocumentId = cv.ContentDocumentId;
                        cdl.LinkedEntityId    = qId;
                        cdl.ShareType         = 'V';
                        cdlsList.add(cdl);
                        attachmentIds.add(cv.ContentDocument.LatestPublishedVersionId);
                    }
                    insert cdlsList;
                }
            } catch (Exception e) {
                System.debug('Error processing uploaded attachments: ' + e.getMessage());
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.WARNING,
                    'Quote PDF saved but some attachments could not be processed: ' + e.getMessage()
                ));
            }
        }

        email.setEntityAttachments(attachmentIds);
        
        if (String.isNotBlank(quData.Opportunity.Owner.Email)) {
            email.setReplyTo(quData.Opportunity.Owner.Email);
            email.setBccAddresses(new List<String> { quData.Opportunity.Owner.Email });
        }
        email.setSubject(subject);
        email.setHtmlBody(body);
        email.setUseSignature(true);
        email.setSaveAsActivity(true);
        email.setWhatId(quData.Id);
        
        Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        /*
        if(results != null && results.size() > 0 && results[0].isSuccess()) {
            Quote qToUpdate = new Quote(
                Id = quData.Id,
                Status = 'In Review with Customer',
                In_Review_with_Customer_Date_Time__c = System.now()
            );
            update qToUpdate;
            System.debug('✅ Email sent successfully for Normal Quote');
        } else {
            System.debug('❌ Email sending failed for Normal Quote');
        }
        */
        if(results != null && results.size() > 0 && results[0].isSuccess()) {
            
            if (
                quData.Status == 'Draft' ||
                quData.Status == 'Under Review by Sales Rep' ||
                quData.Status == 'Submit for SOA Approval'
            ) {
                
                Quote qToUpdate = new Quote(
                    Id = quData.Id,
                    Status = 'Submitted'
                );
                
                update qToUpdate;
                
                System.debug(
                    '✅ Quote Status updated from ' +
                    quData.Status +
                    ' to Submitted'
                );
                
            } else {
                
                System.debug(
                    '⚠️ Quote Status is ' +
                    quData.Status +
                    '. Status update skipped.'
                );
            }
            
            System.debug('✅ Email sent successfully for Normal Quote');
            
        } else {
            
            System.debug('❌ Email sending failed for Normal Quote');
        }
        PageReference pageRef = new PageReference('/' + qId);
        pageRef.setRedirect(true);
        System.debug('===== end saveAndSend() (Normal) =====');
        return pageRef;
    }
    
    // New method for Amendment Send (without PDF)
    public PageReference sendAmendmentEmail() {
        System.debug('===== sendAmendmentEmail() called =====');
        if (!isValid || String.isBlank(emailId) || String.isBlank(subject)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Email Id and subject are mandatory fields, please verify.'));
            System.debug('❌ Validation failed: isValid=' + isValid + ', emailId=' + emailId + ', subject=' + subject);
            return null;
        }
        
        System.debug('Sending Amendment Email without PDF');
        System.debug('Email ID: ' + emailId);
        System.debug('Subject: ' + subject);
        System.debug('CC Addresses: ' + CC_Addresses);
        
        // Update Amendment_Quote__c checkbox
        System.debug('isAmendmentQuote: ' + isAmendmentQuote);
        System.debug('quData.Amendment_Quote__c: ' + quData.Amendment_Quote__c);
        if (isAmendmentQuote != quData.Amendment_Quote__c) {
            Quote qUpdate = new Quote(Id = quData.Id, Amendment_Quote__c = isAmendmentQuote);
            update qUpdate;
            quData.Amendment_Quote__c = isAmendmentQuote;
            System.debug('✅ Updated Amendment_Quote__c to: ' + isAmendmentQuote);
        }
        
        // Update subject for amendment
        updateSubject();
        System.debug('Updated subject: ' + subject);
        
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
        }
        
        if (String.isNotBlank(quData.Opportunity.Owner.Email)) {
            email.setReplyTo(quData.Opportunity.Owner.Email);
            email.setBccAddresses(new List<String> { quData.Opportunity.Owner.Email });
        }
        email.setSubject(subject);
        email.setHtmlBody(body);
        email.setUseSignature(true);
        email.setSaveAsActivity(true);
        email.setWhatId(quData.Id);
        
        Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        /*
        if(results != null && results.size() > 0 && results[0].isSuccess()) {
            Quote qToUpdate = new Quote(
                Id = quData.Id,
                Status = 'In Review with Customer',
                In_Review_with_Customer_Date_Time__c = System.now()
            );
            update qToUpdate;
            System.debug('✅ Amendment Email sent successfully');
        } else {
            System.debug('❌ Amendment Email sending failed');
        }
        */
        if(results != null && results.size() > 0 && results[0].isSuccess()) {
            
            // ============================================================
            // UPDATE QUOTE STATUS AFTER SUCCESSFUL SAVE & SEND
            //
            // Only these statuses move to Submitted:
            // Draft
            // Under Review by Sales Rep
            // Submit for SOA Approval
            //
            // All other statuses remain unchanged.
            // ============================================================
            
            if (
                quData.Status == 'Draft' ||
                quData.Status == 'Under Review by Sales Rep' ||
                quData.Status == 'Submit for SOA Approval'
            ) {
                
                Quote qToUpdate = new Quote(
                    Id = quData.Id,
                    Status = 'Submitted'
                );
                
                update qToUpdate;
                
                System.debug(
                    '✅ Quote Status updated from ' +
                    quData.Status +
                    ' to Submitted'
                );
                
            } else {
                
                System.debug(
                    '⚠️ Quote Status is ' +
                    quData.Status +
                    '. Status update skipped.'
                );
            }
            
            System.debug('✅ Email sent successfully for Normal Quote');
            
        } else {
            
            System.debug('❌ Email sending failed for Normal Quote');
        }
        PageReference pageRef = new PageReference('/' + qId);
        pageRef.setRedirect(true);
        System.debug('===== end sendAmendmentEmail() =====');
        return pageRef;
    }
    
    public PageReference cancel() {
        System.debug('===== cancel() called =====');
        PageReference pageRef = new PageReference('/' + qId);
        pageRef.setRedirect(true);
        System.debug('===== end cancel() =====');
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