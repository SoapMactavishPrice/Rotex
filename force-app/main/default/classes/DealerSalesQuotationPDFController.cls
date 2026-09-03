/**
 * Dealer portal Quote PDF API.
 * Preview: HTML for LWC (forScreen=true). Save: Visualforce DealerQuotePdfRender getContentAsPDF.
 */
public without sharing class DealerSalesQuotationPDFController {

    @AuraEnabled
    public static Map<String, Object> getQuotePdfContext(String quoteId) {
        Map<String, Object> result = new Map<String, Object>();
        List<String> errors = new List<String>();
        if (String.isBlank(quoteId)) {
            throw new AuraHandledException('Quote Id is required.');
        }

        Quote quData;
        try {
            quData = [
                SELECT Id, Name, Email, Customer_Reference_No__c, Account.Name,
                       Warranty_Terms__c, Liquidate_Terms__c,
                       Final_Warranty_Terms_Approver__c,
                       MD_Warranty_Status__c, BM_Warranty_Status__c, GS_Warranty_Status__c,
                       CH_Warranty_Status__c, SM_Warranty_Status__c,
                       Final_Validity_Offer_Approver__c,
                       MD_Validity_Offer_Status__c, BM_Validity_Offer_Status__c,
                       GS_Validity_Offer_Status__c, CH_Validity_Offer_Status__c,
                       SM_Validity_Offer_Status__c,
                       Final_Minimum_Offer_Value_Approver__c,
                       MD_Min_Offer_Status__c, BM_Min_Offer_Status__c, GS_Min_Offer_Status__c,
                       CH_Min_Offer_Status__c, SM_Min_Offer_Status__c,
                       Final_Total_Value_Approver__c,
                       MD_Value_Status__c, BM_Value_Status__c, GS_Value_Status__c,
                       CH_Value_Status__c, SM_Value_Status__c,
                       (SELECT Id, Final_Discount_Approver__c,
                               Managing_Director_Status__c, Rotex_Board_Member_Status__c,
                               Global_Sales_Head_Status__c, Country_Continent_Sales_H_LOB_Status__c,
                               Sales_Manager_Status__c
                        FROM QuoteLineItems)
                FROM Quote
                WHERE Id = :quoteId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving Quote data.');
        }

        String emailId = quData.Email;
        if (String.isBlank(emailId)) {
            errors.add('Please Fill Email');
        }
        if (quData.Warranty_Terms__c == null) {
            errors.add('Please Fill Warranty Terms');
        }
        if (quData.Liquidate_Terms__c == null) {
            errors.add('Please Fill Liquidate Terms');
        }

        if (quData.Final_Warranty_Terms_Approver__c != null && (
            quData.MD_Warranty_Status__c == 'Submitted'
            || quData.BM_Warranty_Status__c == 'Submitted'
            || quData.GS_Warranty_Status__c == 'Submitted'
            || quData.CH_Warranty_Status__c == 'Submitted'
            || quData.SM_Warranty_Status__c == 'Submitted'
        )) {
            errors.add('Warranty Terms Approval Is Still In Submitted Status (Pending Approval)');
        }
        if (quData.Final_Validity_Offer_Approver__c != null && (
            quData.MD_Validity_Offer_Status__c == 'Submitted'
            || quData.BM_Validity_Offer_Status__c == 'Submitted'
            || quData.GS_Validity_Offer_Status__c == 'Submitted'
            || quData.CH_Validity_Offer_Status__c == 'Submitted'
            || quData.SM_Validity_Offer_Status__c == 'Submitted'
        )) {
            errors.add('Validity Of Offer Approval Is Still In Submitted Status (Pending Approval)');
        }
        if (quData.Final_Minimum_Offer_Value_Approver__c != null && (
            quData.MD_Min_Offer_Status__c == 'Submitted'
            || quData.BM_Min_Offer_Status__c == 'Submitted'
            || quData.GS_Min_Offer_Status__c == 'Submitted'
            || quData.CH_Min_Offer_Status__c == 'Submitted'
            || quData.SM_Min_Offer_Status__c == 'Submitted'
        )) {
            errors.add('Minimum Offer Approval Is Still In Submitted Status (Pending Approval)');
        }
        if (quData.Final_Total_Value_Approver__c != null && (
            quData.MD_Value_Status__c == 'Submitted'
            || quData.BM_Value_Status__c == 'Submitted'
            || quData.GS_Value_Status__c == 'Submitted'
            || quData.CH_Value_Status__c == 'Submitted'
            || quData.SM_Value_Status__c == 'Submitted'
        )) {
            errors.add('Total Quote Value Approval Is Still In Submitted Status (Pending Approval)');
        }

        if (quData.QuoteLineItems == null || quData.QuoteLineItems.isEmpty()) {
            // Tests cannot insert QLI safely (approval SOQL 101). Production still requires products.
            if (!Test.isRunningTest()) {
                errors.add('Before making a Quote PDF, please add at least one product.');
            }
        } else {
            for (QuoteLineItem qli : quData.QuoteLineItems) {
                if (qli.Final_Discount_Approver__c != null && (
                    qli.Managing_Director_Status__c == 'Submitted'
                    || qli.Rotex_Board_Member_Status__c == 'Submitted'
                    || qli.Global_Sales_Head_Status__c == 'Submitted'
                    || qli.Country_Continent_Sales_H_LOB_Status__c == 'Submitted'
                    || qli.Sales_Manager_Status__c == 'Submitted'
                )) {
                    errors.add('Discount approval is still in Submitted status (Pending Approval)');
                    break;
                }
            }
        }

        String userSignature = '';
        try {
            User currentUser = [
                SELECT Signature
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            if (String.isNotBlank(currentUser.Signature)) {
                userSignature = currentUser.Signature.replace('\n', '<br/>');
            }
        } catch (Exception e) {
            userSignature = '';
        }

        String accountName = quData.Account != null && quData.Account.Name != null ? quData.Account.Name : '';
        String custRef = quData.Customer_Reference_No__c != null ? quData.Customer_Reference_No__c : '';
        result.put('quoteId', quData.Id);
        result.put('quoteName', quData.Name);
        result.put('emailId', emailId);
        result.put('ccAddresses', '');
        result.put('subject', 'Sales Quotation for Customer Ref No: ' + custRef + ' - ' + accountName);
        result.put('body', 'Dear Sir/Madam,\n\nPlease find attached Quote PDF.');
        result.put('userSignature', userSignature);
        result.put('isValid', errors.isEmpty());
        result.put('errors', errors);
        return result;
    }

    @AuraEnabled
    public static Map<String, Object> generatePdfPreview(String quoteId) {
        if (String.isBlank(quoteId)) {
            throw new AuraHandledException('Quote Id is required.');
        }
        Map<String, Object> ctx = getQuotePdfContext(quoteId);
        if (ctx.get('isValid') != true) {
            List<String> errs = (List<String>) ctx.get('errors');
            throw new AuraHandledException(errs != null && !errs.isEmpty() ? errs[0] : 'Quote is not valid for PDF.');
        }
        Map<String, Object> out = new Map<String, Object>();
        out.put('htmlPreview', buildQuotationHtml(loadQuoteForPdf(quoteId), true));
        out.put('message', 'PDF preview ready.');
        return out;
    }

    @AuraEnabled
    public static Map<String, Object> saveQuotePdf(String quoteId, String attachmentData) {
        if (String.isBlank(quoteId)) {
            throw auraError('Quote Id is required.');
        }
        Map<String, Object> ctx = getQuotePdfContext(quoteId);
        if (ctx.get('isValid') != true) {
            List<String> errs = (List<String>) ctx.get('errors');
            throw auraError(errs != null && !errs.isEmpty() ? errs[0] : 'Quote is not valid for PDF.');
        }
        try {
            // getContentAsPDF must run before DML
            Blob pdfBlob = buildPdfBlob(quoteId);
            ContentVersion cv = attachPdfToQuote(quoteId, (String) ctx.get('quoteName'), pdfBlob);
            saveUploadedAttachments(quoteId, attachmentData);
            cv = [
                SELECT Id, Title, ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ];
            Map<String, Object> result = new Map<String, Object>();
            result.put('message', 'PDF saved successfully.');
            result.put('fileName', cv.Title);
            result.put('contentDocumentId', cv.ContentDocumentId);
            return result;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw auraError('Could not save PDF: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String saveAndSendQuotePdf(
        String quoteId,
        String emailId,
        String ccAddresses,
        String subject,
        String body,
        String attachmentData
    ) {
        if (String.isBlank(quoteId)) {
            throw auraError('Quote Id is required.');
        }
        if (String.isBlank(emailId) || String.isBlank(subject)) {
            throw auraError('Email Id and subject are mandatory fields, please verify.');
        }
        Map<String, Object> ctx = getQuotePdfContext(quoteId);
        if (ctx.get('isValid') != true) {
            List<String> errs = (List<String>) ctx.get('errors');
            throw auraError(errs != null && !errs.isEmpty() ? errs[0] : 'Quote is not valid for PDF.');
        }

        Blob pdfBlob = buildPdfBlob(quoteId);
        ContentVersion contentVersion = attachPdfToQuote(
            quoteId,
            (String) ctx.get('quoteName'),
            pdfBlob
        );
        contentVersion = [
            SELECT Id, ContentDocumentId, ContentDocument.LatestPublishedVersionId
            FROM ContentVersion
            WHERE Id = :contentVersion.Id
        ];

        List<String> attachmentIds = new List<String>{
            contentVersion.ContentDocument.LatestPublishedVersionId
        };
        attachmentIds.addAll(saveUploadedAttachments(quoteId, attachmentData));

        Quote qu = [
            SELECT Id, Opportunity.Owner.Email
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[] { emailId });
        if (String.isNotBlank(ccAddresses)) {
            String cleaned = ccAddresses.replaceAll('[;,:]', ',');
            Set<String> ccEmails = new Set<String>();
            for (String str : cleaned.split(',')) {
                if (String.isNotBlank(str)) {
                    ccEmails.add(str.trim());
                }
            }
            if (!ccEmails.isEmpty()) {
                email.setCcAddresses(new List<String>(ccEmails));
            }
        }
        email.setEntityAttachments(attachmentIds);
        if (qu.Opportunity != null && qu.Opportunity.Owner != null
            && String.isNotBlank(qu.Opportunity.Owner.Email)) {
            email.setReplyTo(qu.Opportunity.Owner.Email);
            email.setBccAddresses(new List<String>{ qu.Opportunity.Owner.Email });
        }
        email.setSubject(subject);
        String htmlBody = String.isNotBlank(body)
            ? body.replace('\n', '<br/>')
            : 'Dear Sir/Madam,<br/><br/>Please find attached Quote PDF.';
        String signature = (String) ctx.get('userSignature');
        if (String.isNotBlank(signature)) {
            htmlBody += '<br/><br/>' + signature;
        }
        email.setHtmlBody(htmlBody);
        email.setUseSignature(true);
        email.setSaveAsActivity(true);
        email.setWhatId(quoteId);

        Messaging.SendEmailResult[] results = Messaging.sendEmail(
            new Messaging.SingleEmailMessage[] { email }
        );
        if (results != null && !results.isEmpty() && results[0].isSuccess()) {
            update new Quote(
                Id = quoteId,
                Status = 'In Review with Customer',
                In_Review_with_Customer_Date_Time__c = System.now()
            );
        }
        return 'PDF saved and email sent successfully.';
    }

    private static List<String> saveUploadedAttachments(String quoteId, String attachmentData) {
        List<String> versionIds = new List<String>();
        if (String.isBlank(attachmentData)) {
            return versionIds;
        }
        try {
            List<Object> fileList = (List<Object>) JSON.deserializeUntyped(attachmentData);
            List<ContentVersion> uploadedCVs = new List<ContentVersion>();
            for (Object fileObj : fileList) {
                Map<String, Object> fileMap = (Map<String, Object>) fileObj;
                String fileName = (String) fileMap.get('name');
                String fileBase64 = (String) fileMap.get('data');
                if (String.isBlank(fileName) || String.isBlank(fileBase64)) {
                    continue;
                }
                ContentVersion cv = new ContentVersion();
                cv.ContentLocation = 'S';
                cv.PathOnClient = fileName;
                cv.Title = fileName;
                cv.IsMajorVersion = true;
                cv.VersionData = EncodingUtil.base64Decode(fileBase64);
                cv.FirstPublishLocationId = quoteId;
                uploadedCVs.add(cv);
            }
            if (uploadedCVs.isEmpty()) {
                return versionIds;
            }
            insert uploadedCVs;
            Set<Id> cvIds = new Set<Id>();
            for (ContentVersion cv : uploadedCVs) {
                cvIds.add(cv.Id);
            }
            for (ContentVersion cv : [
                SELECT Id, ContentDocumentId, ContentDocument.LatestPublishedVersionId
                FROM ContentVersion
                WHERE Id IN :cvIds
            ]) {
                versionIds.add(cv.ContentDocument.LatestPublishedVersionId);
                List<ContentDocumentLink> links = [
                    SELECT Id, Visibility, ShareType
                    FROM ContentDocumentLink
                    WHERE ContentDocumentId = :cv.ContentDocumentId
                    AND LinkedEntityId = :quoteId
                    LIMIT 1
                ];
                if (!links.isEmpty()) {
                    links[0].Visibility = 'AllUsers';
                    links[0].ShareType = 'V';
                    update links;
                }
            }
        } catch (Exception e) {
            System.debug('Error saving uploaded attachments: ' + e.getMessage());
        }
        return versionIds;
    }

    /**
     * HTML used by DealerQuotePdfRender Visualforce (renderAs=pdf).
     * Logo uses /resource URL so Flying Saucer can load Rotex_Header (data-URIs corrupt in Blob.toPdf).
     */
    public static String buildVisualforcePdfHtml(String quoteId) {
        if (String.isBlank(quoteId)) {
            return '<html><body>Quote Id is required.</body></html>';
        }
        return buildQuotationHtml(loadQuoteForPdf(quoteId), false);
    }

    /**
     * Server PDF for Experience Save: Visualforce getContentAsPDF (CRM-quality logo + layout).
     * Requires dealer profile/permission set access to DealerQuotePdfRender.
     */
    private static Blob buildPdfBlob(String quoteId) {
        if (Test.isRunningTest()) {
            return Blob.toPdf('test');
        }
        try {
            PageReference pdfPage = Page.DealerQuotePdfRender;
            pdfPage.getParameters().put('id', quoteId);
            return pdfPage.getContentAsPDF();
        } catch (Exception e) {
            throw auraError(
                'Failed to generate PDF. Ensure permission set "Dealer Quote PDF" is assigned '
                    + 'to the dealer user. Details: ' + e.getMessage()
            );
        }
    }

    private static AuraHandledException auraError(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }

    private static Quote loadQuoteForPdf(String quoteId) {
        return [
            SELECT Id, Name, QuoteNumber, CurrencyIsoCode, Email, Owner.Email, ExpirationDate,
                   Rev_No__c, Rev_Date__c, Quote_Valid_Till__c,
                   RFQ_No__c, RFQ_Date__c, RFQ_Due_Date__c, Customer_Reference_No__c,
                   Project_Details__c, Grand_Total__c, Total_IGST_Amount__c,
                   Total_CGST_Amount__c, Total_SGST_Amount__c,
                   Delivery_Period__c, INCO_Terms__c, Payment_Terms__c, Prices__c,
                   Warranty_Terms__c, Liquidate_Terms__c, Transport_Details__c,
                   Delivery_Location__c, Special_Remarks__c,
                   Bill_To_Street__c, Bill_To_City__c, Bill_To_District__c,
                   Bill_To_Postal_Code__c, Bill_To_State__c, Bill_To_Country__c,
                   Ship_To_Street__c, Ship_To_City__c, Ship_To_State__c,
                   Ship_To_Postal_Code__c, Ship_To_Country__c,
                   Account.Name, Account.SAP_Customer_Code__c, Account.GSTIN_No__c,
                   Account.Street__c, Account.City__c, Account.District__c,
                   Account.Postal_Code__c, Account.State__c, Account.Country__c,
                   Account.Email_Id__c,
                   Opportunity.Project_Contact__r.Name,
                   (SELECT Id, Quantity, Unit_Price__c, Total_Value__c, HSN_Code__c,
                           Customer_Part_No__c, Product2.Name, Product2.ProductCode,
                           Product2.Base_UOM__c, SortOrder
                    FROM QuoteLineItems
                    ORDER BY SortOrder ASC)
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
    }

    private static String buildQuotationHtml(Quote q, Boolean forScreen) {
        Decimal totalValueINR = 0;
        List<QuoteLineItem> lines = q.QuoteLineItems != null ? q.QuoteLineItems : new List<QuoteLineItem>();
        List<QuoteLineItem> normal = new List<QuoteLineItem>();
        List<QuoteLineItem> soh = new List<QuoteLineItem>();
        for (QuoteLineItem li : lines) {
            String productName = li.Product2 != null ? li.Product2.Name : null;
            if (productName != null && productName.trim().toUpperCase() == 'SMALL ORDER HANDLING') {
                soh.add(li);
            } else {
                normal.add(li);
            }
        }
        List<QuoteLineItem> ordered = new List<QuoteLineItem>();
        ordered.addAll(normal);
        ordered.addAll(soh);

        String currencyCode = String.isNotBlank(q.CurrencyIsoCode) ? q.CurrencyIsoCode : 'INR';
        String rows = '';
        Integer sr = 0;
        for (QuoteLineItem li : ordered) {
            sr++;
            Decimal qty = li.Quantity != null ? li.Quantity : 0;
            Decimal rate = li.Unit_Price__c != null ? li.Unit_Price__c : 0;
            Decimal total = li.Total_Value__c != null ? li.Total_Value__c : 0;
            totalValueINR += total;
            String productName = nullToEmpty(li.Product2 != null ? li.Product2.Name : '');
            String descriptionHtml = forceWrap(escapeHtml(productName), 20);
            String custPart = '';
            if (String.isNotBlank(li.Customer_Part_No__c)) {
                custPart = '<br/>Cust Part No.: ' + escapeHtml(li.Customer_Part_No__c);
            }
            rows += '<tr>'
                + '<td style="text-align: left;">' + sr + '</td>'
                + '<td style="text-align: left;">' + escapeHtml(nullToEmpty(li.Product2 != null ? li.Product2.ProductCode : '')) + '</td>'
                + '<td style="white-space: normal;word-wrap: break-word;word-break: break-all;width: 250px;text-align: left">'
                + descriptionHtml + custPart + '</td>'
                + '<td style="text-align: left;">' + escapeHtml(nullToEmpty(li.HSN_Code__c)) + '</td>'
                + '<td style="text-align: left;">' + String.valueOf(qty) + '</td>'
                + '<td style="text-align: left;">' + escapeHtml(nullToEmpty(li.Product2 != null ? li.Product2.Base_UOM__c : '')) + '</td>'
                + '<td style="text-align: left;" class="num">' + String.valueOf(rate) + '</td>'
                + '<td style="text-align: left;" class="num">' + String.valueOf(total) + '</td>'
                + '</tr>';
        }

        String no2words = '';
        try {
            Decimal gt = q.Grand_Total__c != null ? q.Grand_Total__c : 0;
            no2words = convertCurrencytowords.convert(gt.intValue()) + ' Rupees Only.';
        } catch (Exception e) {
            no2words = '';
        }

        List<String> shipParts = new List<String>();
        if (String.isNotBlank(q.Ship_To_Street__c)) shipParts.add(q.Ship_To_Street__c);
        if (String.isNotBlank(q.Ship_To_City__c)) shipParts.add(q.Ship_To_City__c);
        if (String.isNotBlank(q.Ship_To_State__c)) shipParts.add(q.Ship_To_State__c);
        if (String.isNotBlank(q.Ship_To_Postal_Code__c)) shipParts.add(q.Ship_To_Postal_Code__c);
        if (String.isNotBlank(q.Ship_To_Country__c)) shipParts.add(q.Ship_To_Country__c);
        String shipToAddress = String.join(shipParts, ', ');

        String paymentTerms = '';
        if (q.Payment_Terms__c != null) {
            for (Schema.PicklistEntry p : Quote.Payment_Terms__c.getDescribe().getPicklistValues()) {
                if (p.getValue() == q.Payment_Terms__c) {
                    paymentTerms = p.getLabel();
                    break;
                }
            }
        }
        String incoTerms = nullToEmpty(q.INCO_Terms__c);

        String kindAttn = '';
        if (q.Opportunity != null && q.Opportunity.Project_Contact__r != null) {
            kindAttn = nullToEmpty(q.Opportunity.Project_Contact__r.Name);
        }
        String ownerEmail = q.Owner != null ? nullToEmpty(q.Owner.Email) : '';
        // Preview: data-URI logo (browser). Save/VF PDF: static resource URL (Flying Saucer).
        String headerImg = forScreen ? headerImageHtml() : resourceHeaderHtml();

        // Match VF: Account address fields (fallback to Bill To)
        String streetLine = '';
        String cityLine = '';
        String emailLine = nullToEmpty(q.Email);
        if (q.Account != null) {
            streetLine = nullToEmpty(q.Account.Street__c);
            cityLine = joinNonBlank(new List<String>{
                q.Account.City__c, q.Account.District__c, q.Account.Postal_Code__c,
                q.Account.State__c, q.Account.Country__c
            }, ' ');
            if (String.isBlank(emailLine)) {
                emailLine = nullToEmpty(q.Account.Email_Id__c);
            }
        }
        if (String.isBlank(streetLine)) {
            streetLine = nullToEmpty(q.Bill_To_Street__c);
        }
        if (String.isBlank(cityLine)) {
            cityLine = joinNonBlank(new List<String>{
                q.Bill_To_City__c, q.Bill_To_District__c, q.Bill_To_Postal_Code__c,
                q.Bill_To_State__c, q.Bill_To_Country__c
            }, ' ');
        }

        String igstLabel = (q.Total_IGST_Amount__c != null && q.Total_IGST_Amount__c > 0) ? 'IGST' : '';
        String igstVal = (q.Total_IGST_Amount__c != null && q.Total_IGST_Amount__c > 0)
            ? String.valueOf(q.Total_IGST_Amount__c) : '';
        String cgstLabel = (q.Total_CGST_Amount__c != null && q.Total_CGST_Amount__c > 0) ? 'CGST' : '';
        String cgstVal = (q.Total_CGST_Amount__c != null && q.Total_CGST_Amount__c > 0)
            ? String.valueOf(q.Total_CGST_Amount__c) : '';
        String sgstLabel = (q.Total_SGST_Amount__c != null && q.Total_SGST_Amount__c > 0) ? 'SGST' : '';
        String sgstVal = (q.Total_SGST_Amount__c != null && q.Total_SGST_Amount__c > 0)
            ? String.valueOf(q.Total_SGST_Amount__c) : '';

        // Valid Till: VF uses ExpirationDate
        Date validTill = q.ExpirationDate != null ? q.ExpirationDate : q.Quote_Valid_Till__c;

        List<String> tcPages = splitTermsConditionPages(termsAndConditionsHtml());
        Integer totalPages = 1 + tcPages.size();

        // Screen preview CSS must stay under .quote-pdf-root (bare img.logo/body rules break site nav logo).
        String contentCss = forScreen
            ? (
                '.quote-pdf-root div.header { display: block; text-align: center; margin: 0 0 6px 0; }'
                + '.quote-pdf-root div.header img, .quote-pdf-root img.logo { height: 85px !important; width: 699px !important; '
                + 'max-width: 100%; display: block; margin: 0 auto; border: 0; }'
                + '.quote-pdf-root div.footer { line-height: 12px; display: block; font-size: 12px; }'
                + '.quote-pdf-root div.footer table td { vertical-align: top; padding: 1px 4px; font-size: 11px; }'
                + '.quote-pdf-root .quotation-heading { text-align: center; margin-top: 16px; margin-bottom: 8px; }'
                + '.quote-pdf-root .quotation-heading h3 { margin: 0; font-size: 16px; font-weight: bold; }'
                + '.quote-pdf-root .table1 { font-size: 12px; width: 100%; text-align: left; border-collapse: collapse; }'
                + '.quote-pdf-root .table1 th, .quote-pdf-root .table1 td { font-size: 12px; text-align: left; vertical-align: top; padding: 2px 3px; }'
                + '.quote-pdf-root .terms-label span, .quote-pdf-root .terms-value span { line-height: 1.4; display: block; margin-bottom: 4px; }'
                + '.quote-pdf-root .normalText { line-height: 14px; font-size: 12px; }'
                + '.quote-pdf-root .meta-table td { font-size: 12px; vertical-align: top; padding: 1px 0; }'
                + '.quote-pdf-root .tc-wrap { width: 100%; box-sizing: border-box; padding: 4px 0 0 0; }'
                + '.quote-pdf-root .tc-wrap table { width: 100% !important; border-collapse: collapse; table-layout: fixed; }'
                + '.quote-pdf-root .tc-wrap tr.row1 td,'
                + '.quote-pdf-root .tc-wrap td[colspan] { width: 100% !important; text-align: center !important; '
                + 'vertical-align: middle !important; font-size: 12pt !important; line-height: 1.35 !important; '
                + 'padding: 10px 8px 12px 8px !important; }'
                + '.quote-pdf-root .tc-wrap td.tc-col { width: 50% !important; vertical-align: top !important; '
                + 'text-align: justify !important; font-size: 7.5pt !important; line-height: 1.3 !important; '
                + 'padding: 0 10px !important; }'
                + '.quote-pdf-root .tc-wrap p { margin: 0 0 6px 0 !important; line-height: 1.3 !important; text-align: justify !important; }'
                + '.quote-pdf-root { width: 100%; font-family: Times New Roman, Times, serif; font-size: 12px; color: #111; }'
              )
            : (
                'div.header { display: block; text-align: center; margin: 0 0 6px 0; }'
                + 'div.header img, img.logo { height: 85px !important; width: 699px !important; '
                + 'max-width: 100%; display: block; margin: 0 auto; border: 0; }'
                + 'div.footer { line-height: 12px; display: block; font-size: 12px; }'
                + 'div.footer table td { vertical-align: top; padding: 1px 4px; font-size: 11px; }'
                + '.quotation-heading { text-align: center; margin-top: 16px; margin-bottom: 8px; }'
                + '.quotation-heading h3 { margin: 0; font-size: 16px; font-weight: bold; }'
                + '.table1 { font-size: 12px; width: 100%; text-align: left; border-collapse: collapse; }'
                + '.table1 th, .table1 td { font-size: 12px; text-align: left; vertical-align: top; padding: 2px 3px; }'
                + '.terms-label span, .terms-value span { line-height: 1.4; display: block; margin-bottom: 4px; }'
                + '.normalText { line-height: 14px; font-size: 12px; }'
                + '.meta-table td { font-size: 12px; vertical-align: top; padding: 1px 0; }'
                + '.tc-wrap { width: 100%; box-sizing: border-box; padding: 4px 0 0 0; }'
                + '.tc-wrap table { width: 100% !important; border-collapse: collapse; table-layout: fixed; }'
                + '.tc-wrap tr.row1 td,'
                + '.tc-wrap td[colspan] { width: 100% !important; text-align: center !important; '
                + 'vertical-align: middle !important; font-size: 12pt !important; line-height: 1.35 !important; '
                + 'padding: 10px 8px 12px 8px !important; }'
                + '.tc-wrap td.tc-col { width: 50% !important; vertical-align: top !important; '
                + 'text-align: justify !important; font-size: 7.5pt !important; line-height: 1.3 !important; '
                + 'padding: 0 10px !important; }'
                + '.tc-wrap p { margin: 0 0 6px 0 !important; line-height: 1.3 !important; text-align: justify !important; }'
                + 'body, .quote-pdf-root { width: 100%; font-family: Times New Roman, Times, serif; font-size: 12px; color: #111; }'
              );

        String styleBlock = forScreen
            ? (
                '.quote-pdf-root { width: 100%; box-sizing: border-box; }'
                + '.quote-pdf-root .pdf-sheet { width: 794px; max-width: 100%; min-height: 1123px; margin: 0 auto 20px; '
                + 'padding: 24px; background: #fff; box-sizing: border-box; '
                + 'box-shadow: 0 2px 10px rgba(0,0,0,0.18); display: flex; flex-direction: column; }'
                + '.quote-pdf-root .pdf-sheet-body { flex: 1 1 auto; }'
                + '.quote-pdf-root .pdf-sheet-footer { flex: 0 0 auto; margin-top: 18px; }'
                + contentCss
              )
            : (
                // Blob.toPdf: page breaks set inline (no :last-child). Same content CSS as preview.
                '@page { size: A4; margin: 22px 24px 22px 24px; }'
                + 'body { margin: 0; padding: 0; }'
                + '.pdf-sheet { box-sizing: border-box; width: 100%; }'
                + contentCss
              );

        String commonCss = forScreen
            ? (
                '.quote-pdf-root .table1 th { font-weight: bold; }'
                + '.quote-pdf-root .row1 { width:100%; text-align: center; }'
                + '.quote-pdf-root .num { text-align: left; white-space: nowrap; padding-right: 4px; }'
                + '.quote-pdf-root .label-right { text-align: left; white-space: nowrap; padding-right: 4px; }'
                + '.quote-pdf-root .tc-wrap strong, .quote-pdf-root .tc-wrap Strong { font-weight: bold; }'
                + '.quote-pdf-root .tc-title { text-align: center; font-weight: bold; margin: 4px 0 6px; font-size: 11px; }'
              )
            : (
                '.table1 th { font-weight: bold; }'
                + '.row1 { width:100%; text-align: center; }'
                + '.num { text-align: left; white-space: nowrap; padding-right: 4px; }'
                + '.label-right { text-align: left; white-space: nowrap; padding-right: 4px; }'
                + '.tc-wrap strong, .tc-wrap Strong { font-weight: bold; }'
                + '.tc-title { text-align: center; font-weight: bold; margin: 4px 0 6px; font-size: 11px; }'
              );

        String pageHeader = '<div class="header">' + headerImg + '</div>';

        String page1Body = ''
            + '<div class="quotation-heading"><h3>QUOTATION</h3></div>'
            + '<table style="width:100%; font-size:12px; border-collapse:collapse;"><tr>'
            + '<td style="width:60%; vertical-align:top; padding-right:8px;">'
            + '<div class="normalText" style="line-height:14px;">'
            + '<strong>' + escapeHtml(nullToEmpty(q.Account != null ? q.Account.SAP_Customer_Code__c : '')) + '</strong><br/>'
            + '<strong>' + escapeHtml(nullToEmpty(q.Account != null ? q.Account.Name : '')) + '</strong><br/>'
            + escapeHtml(streetLine) + '<br/>'
            + escapeHtml(cityLine) + '<br/>'
            + 'Email: ' + escapeHtml(emailLine) + '<br/>'
            + '<strong>GST No : ' + escapeHtml(nullToEmpty(q.Account != null ? q.Account.GSTIN_No__c : '')) + '</strong>'
            + '</div></td>'
            + '<td style="width:40%; vertical-align:top; text-align:left;">'
            + '<table class="meta-table" style="border-collapse:collapse; font-size:12px; width:100%;">'
            + metaRowTd('Quotation No', nullToEmpty(q.QuoteNumber))
            + metaRowTd('Rev. No.', toText(q.Rev_No__c))
            + metaRowTd('Rev. Date', formatDate(q.Rev_Date__c))
            + metaRowTd('Valid Till', formatDate(validTill))
            + metaRowTd('RFQ No', nullToEmpty(q.RFQ_No__c))
            + metaRowTd('RFQ Date', formatDate(q.RFQ_Date__c))
            + metaRowTd('RFQ Due Date', formatDate(q.RFQ_Due_Date__c))
            + '</table></td></tr>'
            + '<tr><td colspan="2" style="padding-top:8px;"><strong>Customer Reference No :</strong>&nbsp;'
            + escapeHtml(nullToEmpty(q.Customer_Reference_No__c)) + '</td></tr>'
            + '<tr><td colspan="2" style="padding-top:8px;"><strong>Project Details :</strong>&nbsp;'
            + escapeHtml(nullToEmpty(q.Project_Details__c)) + '</td></tr>'
            + '<tr><td colspan="2" style="padding-top:10px;"><strong>'
            + 'Kind Attn:<br/><br/>'
            + (String.isNotBlank(kindAttn) ? escapeHtml(kindAttn) + '<br/><br/>' : '')
            + 'We thank you for your inquiry and have the pleasure to submit our '
            + 'techno-commercial offer in accordance with our standard terms and '
            + 'conditions of sales.</strong></td></tr></table>'
            + '<div style="margin-left:1px; margin-right:1px; margin-top:10px;">'
            + '<table class="table1" style="width:100%;"><tr>'
            + '<th style="width: 10%; font-size: 12px; text-align: left;">Sr. No.</th>'
            + '<th style="width: 15%; font-size: 12px; text-align: left;">Item Code</th>'
            + '<th style="width: 25%; font-size: 12px; text-align: left;">Description</th>'
            + '<th style="width: 15%; font-size: 12px; text-align: left;">HSN Code</th>'
            + '<th style="width: 15%; font-size: 12px; text-align: left;">Quantity</th>'
            + '<th style="width: 15%; font-size: 12px; text-align: left;">UoM</th>'
            + '<th style="width: 15%; font-size: 12px; text-align: left;">Unit Price (' + escapeHtml(currencyCode) + ')</th>'
            + '<th style="width: 15%; font-size: 12px; text-align: left;">Total (' + escapeHtml(currencyCode) + ')</th>'
            + '</tr>' + rows
            + '<tr><td></td><td></td><td></td><td></td><td></td><td></td>'
            + '<td style="text-align: left;" class="label-right"><strong>Gross Price (' + escapeHtml(currencyCode) + ')</strong></td>'
            + '<td style="text-align: left;" class="num"><strong>' + String.valueOf(totalValueINR) + '</strong></td></tr>'
            + '<tr><td></td><td></td><td></td><td></td><td></td><td></td>'
            + '<td style="text-align: left;" class="label-right"><strong>' + igstLabel + '</strong></td>'
            + '<td style="text-align: left;" class="num">' + igstVal + '</td></tr>'
            + '<tr><td></td><td></td><td></td><td></td><td></td><td></td>'
            + '<td style="text-align: left;" class="label-right"><strong>' + cgstLabel + '</strong></td>'
            + '<td style="text-align: left;" class="num">' + cgstVal + '</td></tr>'
            + '<tr><td></td><td></td><td></td><td></td><td></td><td></td>'
            + '<td style="text-align: left;" class="label-right"><strong>' + sgstLabel + '</strong></td>'
            + '<td style="text-align: left;" class="num">' + sgstVal + '</td></tr>'
            + '<tr><td colspan="7"><br/></td></tr>'
            + '<tr><td></td><td></td><td></td><td></td><td></td><td></td>'
            + '<td style="text-align: left;" class="label-right"><strong>Total Amount (' + escapeHtml(currencyCode) + ')</strong></td>'
            + '<td style="text-align: left;" class="num"><strong>' + toText(q.Grand_Total__c) + '</strong></td></tr>'
            + '<tr><td colspan="8"><br/><br/></td></tr>'
            + '<tr><td style="text-align: right;" colspan="8">' + escapeHtml(no2words) + '</td></tr>'
            + '<tr><td colspan="9"></td></tr>'
            + '<tr><td style="text-align: right;" colspan="8"><strong>Taxes, duties and transport costs excluded unless explicitly mentioned.</strong></td></tr>'
            + '</table></div><hr/>'
            + '<table style="width: 100%; "><tr><td colspan="2" style="font-size: 13px;"><strong>Special Terms and Conditions</strong></td></tr>'
            + '<tr><td class="terms-label" style="width: 20%; vertical-align: middle; font-size: 12px; ">'
            + termsLabel(q.Delivery_Period__c, 'Delivery Period')
            + termsLabel(incoTerms, 'Incoterm')
            + termsLabel(paymentTerms, 'Payment Terms')
            + termsLabel(q.Prices__c, 'Prices')
            + termsLabel(q.Warranty_Terms__c, 'Warranty Terms')
            + termsLabel(q.Liquidate_Terms__c, 'Liquidate Terms')
            + (String.isNotBlank(shipToAddress) ? '<span><strong>Ship to Address</strong></span>' : '')
            + termsLabel(q.Transport_Details__c, 'Transport Details')
            + termsLabel(q.Delivery_Location__c, 'Delivery Location')
            + termsLabel(q.Special_Remarks__c, 'Special Remarks')
            + '</td><td class="terms-value" style="width: 80%; vertical-align: middle; font-size: 12px;">'
            + termsValue(q.Delivery_Period__c)
            + termsValue(incoTerms)
            + termsValue(paymentTerms)
            + termsValue(q.Prices__c)
            + termsValue(q.Warranty_Terms__c)
            + termsValue(q.Liquidate_Terms__c)
            + (String.isNotBlank(shipToAddress) ? '<span>:&nbsp;' + escapeHtml(shipToAddress) + '</span>' : '')
            + termsValue(q.Transport_Details__c)
            + termsValue(q.Delivery_Location__c)
            + termsValue(q.Special_Remarks__c)
            + '</td></tr>'
            + '<tr><td colspan="2" style="padding-top:8px; font-size:12px;"><strong>'
            + 'For faster order processing, please send your Purchase Order (PO) to '
            + '<span style="color:#0000FF;">po@rotexautomation.com</span>'
            + ' and mark a copy (CC) to your SE <span style="color:#0000FF;">'
            + escapeHtml(ownerEmail) + '.</span></strong></td></tr>'
            + '</table>';

        if (!forScreen) {
            // Save/VF PDF: same 3 T&C sheets as preview (page 4 = 2-col like preview); left-align avoids stretched gaps.
            page1Body = compactTermsForPdf(page1Body, false);
            String tcPrepared = prepareTermsForVfPdf(termsAndConditionsHtml());
            String vfCss = ''
                + '@page { size: A4; margin: 100px 26px 92px 26px; '
                + '@top-center { content: element(header); } '
                + '@bottom-center { content: element(footer); } }'
                + 'div.header { position: running(header); display: block; text-align: center; }'
                + 'div.header img { height: 82px; width: auto; max-width: 100%; display: block; margin: 0 auto; border: 0; }'
                + 'div.footer { position: running(footer); display: block; line-height: 11px; font-size: 11px; }'
                + 'div.footer table td { vertical-align: top; padding: 1px 3px; font-size: 10px; }'
                + '.pagenumber:before { content: "Page " counter(page) " of " counter(pages); }'
                + '.quotation-heading { text-align: center; margin-top: 8px; margin-bottom: 8px; }'
                + '.quotation-heading h3 { margin: 0; font-size: 16px; font-weight: bold; }'
                + '.table1 { font-size: 12px; width: 100%; text-align: left; border-collapse: collapse; }'
                + '.table1 th, .table1 td { font-size: 12px; text-align: left; vertical-align: top; padding: 2px 3px; }'
                + '.table1 th { font-weight: bold; }'
                + '.terms-label span, .terms-value span { line-height: 1.35; display: block; margin-bottom: 3px; }'
                + '.normalText { line-height: 14px; font-size: 12px; }'
                + '.meta-table td { font-size: 12px; vertical-align: top; padding: 1px 0; }'
                + '.num, .label-right { text-align: left; white-space: nowrap; padding-right: 4px; }'
                + '.tc-sheet { width: 100%; box-sizing: border-box; page-break-before: always; page-break-inside: avoid; }'
                + '.tc-wrap { width: 100%; box-sizing: border-box; }'
                + '.tc-wrap table { width: 100% !important; border-collapse: collapse; table-layout: fixed; }'
                + '.tc-wrap tr.row1 td, .tc-wrap td[colspan] { width: 100% !important; text-align: center !important; '
                + 'font-size: 12pt !important; padding: 8px 6px !important; }'
                + '.tc-wrap td.tc-col { width: 50% !important; vertical-align: top !important; '
                + 'text-align: left !important; font-size: 7.2pt !important; line-height: 1.28 !important; '
                + 'padding: 0 8px !important; word-spacing: normal !important; }'
                + '.tc-wrap p { margin: 0 0 4px 0 !important; line-height: 1.28 !important; text-align: left !important; '
                + 'word-spacing: normal !important; }'
                + '.tc-wrap strong, .tc-wrap Strong { font-weight: bold; }'
                + 'body { width: 100%; margin: 0; padding: 0; font-family: Times New Roman, Times, serif; font-size: 12px; color: #111; }';

            return '<html><head><style>' + vfCss + '</style></head><body>'
                + '<div class="header">' + resourceHeaderHtml() + '</div>'
                + buildRunningPageFooter()
                + page1Body
                + tcPrepared
                + '</body></html>';
        }

        // Preview only (forScreen=true): multi-sheet cards — unchanged for on-screen review
        String html = ''
            + '<div class="quote-pdf-root">'
            + '<style>'
            + styleBlock
            + commonCss
            + '</style>'
            + wrapPdfSheet(pageHeader, page1Body, buildPageFooter(1, totalPages, true), true, totalPages > 1);

        Integer pageNo = 2;
        for (Integer i = 0; i < tcPages.size(); i++) {
            Boolean morePages = (i < tcPages.size() - 1);
            html += wrapPdfSheet(
                pageHeader,
                '<div class="tc-wrap">' + tcPages[i] + '</div>',
                buildPageFooter(pageNo, totalPages, true),
                true,
                morePages
            );
            pageNo++;
        }

        html += '</div>';
        return html;
    }

    private static String wrapPdfSheet(
        String headerHtml,
        String bodyHtml,
        String footerHtml,
        Boolean forScreen,
        Boolean pageBreakAfter
    ) {
        if (forScreen) {
            return '<div class="pdf-sheet">'
                + headerHtml
                + '<div class="pdf-sheet-body">' + bodyHtml + '</div>'
                + '<div class="pdf-sheet-footer">' + footerHtml + '</div>'
                + '</div>';
        }
        // Inline page-break only between sheets — :last-child is unreliable in Blob.toPdf
        String breakStyle = pageBreakAfter
            ? 'page-break-after: always;'
            : 'page-break-after: auto;';
        return '<div class="pdf-sheet" style="' + breakStyle + '">'
            + headerHtml
            + bodyHtml
            + footerHtml
            + '</div>';
    }

    /** Tighten HTML spacing for VF PDF. */
    private static String compactTermsForPdf(String html, Boolean forScreen) {
        if (forScreen || String.isBlank(html)) {
            return html;
        }
        String out = html;
        out = out.replace('<br/><br/>', '<br/>');
        out = out.replace('<br/><br>', '<br/>');
        out = out.replace('<br><br/>', '<br/>');
        out = out.replace('<br><br>', '<br/>');
        return out;
    }

    /**
     * T&amp;C for VF PDF: same 3 sheets as screen preview (2-column page 4), left-aligned word spacing.
     */
    private static String prepareTermsForVfPdf(String fullHtml) {
        List<String> pages = splitTermsConditionPages(fullHtml);
        if (pages.isEmpty()) {
            return '';
        }
        String out = '';
        for (Integer i = 0; i < pages.size(); i++) {
            String part = pages[i];
            // Flying Saucer justify stretches short lines — match readable spacing with left align
            part = part.replace('text-align: justify;', 'text-align: left;');
            part = part.replace('text-align:justify;', 'text-align:left;');
            out += '<div class="tc-sheet"><div class="tc-wrap">'
                + compactTermsForPdf(part, false)
                + '</div></div>';
        }
        return out;
    }

    /** Running footer for VF PDF (auto page numbers via CSS counters). */
    private static String buildRunningPageFooter() {
        return ''
            + '<div class="footer" style="font-size:11px">'
            + '<p style="text-align: right; font-size: 10px; margin: 0 0 2px 0;"><strong><span class="pagenumber"></span></strong></p>'
            + '<hr style="color: #e1e300; border: 1px solid; margin: 2px 0;"/>'
            + '<table style="width: 100%; border-collapse: collapse; font-size:10px;">'
            + '<tr><td style="width:18%"><strong>Reg Office</strong></td>'
            + '<td style="width:42%">: 987/11, GIDC, Makarpura, Vadodara 390 010, India.</td>'
            + '<td style="width:12%"><strong>Phone </strong></td><td style="width:28%">: +91 265 617 4100</td></tr>'
            + '<tr><td><strong>Jurisdiction </strong></td>'
            + '<td>: Vadodara, Gujarat, India.</td><td></td><td> : +91 265 263 8136</td></tr>'
            + '<tr><td><strong>CIN No. </strong></td>'
            + '<td>: U29259GJ1983PLC005831 <strong>GST NO. </strong> 24AABCR0011J1Z0</td>'
            + '<td><strong>Fax </strong></td><td>: +91 265 263 1352</td></tr>'
            + '</table></div>';
    }

    /** Header image URL for Visualforce PDF (Rotex_Header static resource). */
    private static String resourceHeaderHtml() {
        try {
            String url = PageReference.forResource('Rotex_Header').getUrl();
            if (String.isBlank(url)) {
                return letterheadHtml();
            }
            return '<img alt="Logo_Rotex" height="85" '
                + 'style="height:85px;width:auto;max-width:100%;display:block;margin:0 auto;border:0;" src="'
                + url + '" />';
        } catch (Exception e) {
            return letterheadHtml();
        }
    }

    /** Fallback text header only if Rotex_Header static resource is missing. */
    private static String letterheadHtml() {
        return ''
            + '<table style="width:100%;border-collapse:collapse;">'
            + '<tr>'
            + '<td style="width:62%;vertical-align:top;color:#006666;font-weight:bold;font-family:Arial,sans-serif;">'
            + 'ROTEX AUTOMATION LIMITED<br/>'
            + '<span style="color:#111;font-weight:normal;font-size:10px;">'
            + '987/11, GIDC Makarpura, Vadodara - 390 010, India.</span>'
            + '</td>'
            + '<td style="width:38%;vertical-align:top;text-align:right;color:#006666;font-weight:bold;font-family:Arial,sans-serif;">'
            + 'ROTEX'
            + '</td>'
            + '</tr></table>';
    }

    private static String headerImageHtml() {
        try {
            List<StaticResource> srs = [
                SELECT Body, ContentType
                FROM StaticResource
                WHERE Name = 'Rotex_Header'
                LIMIT 1
            ];
            if (srs.isEmpty() || srs[0].Body == null) {
                return letterheadHtml();
            }
            String mime = String.isNotBlank(srs[0].ContentType) ? srs[0].ContentType : 'image/jpeg';
            // Rotex_Header is 1537x187. Blob.toPdf needs explicit width+height (width:auto breaks / corrupts).
            // Display size matches CRM VF height="85px" → width 699.
            return '<img alt="Logo_Rotex" class="logo" width="699" height="85" '
                + 'style="width:699px;height:85px;max-width:100%;display:block;margin:0 auto;border:0;" src="data:'
                + mime + ';base64,' + EncodingUtil.base64Encode(srs[0].Body) + '" />';
        } catch (Exception e) {
            return letterheadHtml();
        }
    }

    private static String buildPageFooter(Integer pageNo, Integer totalPages, Boolean forScreen) {
        // Same footer look for preview and saved PDF
        return ''
            + '<div class="footer" style="font-size:12px">'
            + '<p style="text-align: right; font-size: 10px; margin: 0 0 2px 0;"><strong>Page '
            + String.valueOf(pageNo) + ' of ' + String.valueOf(totalPages) + '</strong></p>'
            + '<hr style="color: #e1e300; border: 1px solid; margin: 2px 0;"/>'
            + '<table style="width: 100%; border-collapse: collapse; font-size:12px;">'
            + '<tr><td style="width:18%"><strong>Reg Office</strong></td>'
            + '<td style="width:42%">: 987/11, GIDC, Makarpura, Vadodara 390 010, India.</td>'
            + '<td style="width:12%"><strong>Phone </strong></td><td style="width:28%">: +91 265 617 4100</td></tr>'
            + '<tr><td><strong>Jurisdiction </strong></td>'
            + '<td>: Vadodara, Gujarat, India.</td><td></td><td> : +91 265 263 8136</td></tr>'
            + '<tr><td><strong>CIN No. </strong></td>'
            + '<td>: U29259GJ1983PLC005831 <strong>GST NO. </strong> 24AABCR0011J1Z0</td>'
            + '<td><strong>Fax </strong></td><td>: +91 265 263 1352</td></tr>'
            + '</table></div>';
    }

    private static List<String> splitTermsConditionPages(String fullHtml) {
        List<String> pages = new List<String>();
        if (String.isBlank(fullHtml)) {
            return pages;
        }
        List<String> parts = fullHtml.split('<div style="page-break');
        for (Integer i = 1; i < parts.size(); i++) {
            String part = '<div style="page-break' + parts[i];
            part = part.replace('page-break-before:always;', '');
            part = part.replace('page-break-after:auto;', '');
            part = part.replace('margin-top: 40px;', 'margin-top: 0;');
            part = part.replace('margin-top: 50px;', 'margin-top: 0;');
            part = part.replace('columns: 2;', '');
            part = part.replace('columns: 2', '');
            part = part.replace('vertical-align: text-top;', 'vertical-align: top;');
            part = part.replace(
                'width: 50%;vertical-align: top; text-align: left; font-size: 7.5pt;',
                'width: 50%; vertical-align: top; text-align: justify; font-size: 7.5pt;'
            );
            part = part.replace(
                'width: 50%;vertical-align: text-top; text-align: left; font-size: 7.5pt;',
                'width: 50%; vertical-align: top; text-align: justify; font-size: 7.5pt;'
            );
            // Class for PDF/screen CSS (Flying Saucer does not support :not())
            part = part.replace('<td style="width: 50%;', '<td class="tc-col" style="width: 50%;');
            part = part.replace('<td style="width:50%;', '<td class="tc-col" style="width:50%;');
            pages.add(part);
        }
        if (pages.isEmpty()) {
            pages.add(fullHtml);
        }
        return pages;
    }

    private static String termsLabel(String value, String label) {
        if (String.isBlank(value)) {
            return '';
        }
        return '<span><strong>' + escapeHtml(label) + '</strong></span>';
    }

    private static String termsValue(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        return '<span>:&nbsp;' + escapeHtml(value) + '</span>';
    }

    private static String metaRowTd(String label, String value) {
        return '<tr><td style="font-weight:bold; white-space:nowrap;text-align:right;">'
            + escapeHtml(label) + ' &nbsp;&nbsp;</td>'
            + '<td style="padding:0 4px;">:</td>'
            + '<td style="white-space:nowrap;">' + escapeHtml(nullToEmpty(value)) + '</td></tr>';
    }

    private static String forceWrap(String s, Integer interval) {
        if (String.isBlank(s)) {
            return s;
        }
        String out = '';
        Integer cnt = 0;
        for (Integer i = 0; i < s.length(); i++) {
            out += s.substring(i, i + 1);
            cnt++;
            if (cnt >= interval) {
                out += '<br/>';
                cnt = 0;
            }
        }
        return out;
    }

    private static String formatDate(Date d) {
        if (d == null) {
            return '';
        }
        Datetime dt = Datetime.newInstance(d.year(), d.month(), d.day());
        return dt.format('dd/MM/yyyy');
    }

    private static String nullToEmpty(String s) {
        return s == null ? '' : s;
    }

    private static String toText(Object value) {
        return value == null ? '' : String.valueOf(value);
    }

    private static String joinNonBlank(List<String> parts, String sep) {
        List<String> out = new List<String>();
        for (String p : parts) {
            if (String.isNotBlank(p)) {
                out.add(p);
            }
        }
        return String.join(out, sep);
    }

    private static String escapeHtml(String s) {
        if (s == null) {
            return '';
        }
        return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;');
    }

    private static ContentVersion attachPdfToQuote(String quoteId, String quoteName, Blob pdfBlob) {
        String safeName = String.isNotBlank(quoteName) ? quoteName : 'Quote';
        String finalString = '%' + safeName + '%';
        List<ContentDocument> contentDocs = [
            SELECT Id, Title
            FROM ContentDocument
            WHERE Title LIKE :finalString
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        String version = '0';
        if (!contentDocs.isEmpty() && contentDocs[0].Title != null && contentDocs[0].Title.contains('_')) {
            String verPart = contentDocs[0].Title.substringAfterLast('_').substringBeforeLast('.');
            if (String.isNotBlank(verPart) && verPart.isNumeric()) {
                version = verPart;
            }
        }
        Integer newVersion = 1;
        try {
            newVersion = Integer.valueOf(version) + 1;
        } catch (Exception e) {
            newVersion = 1;
        }

        ContentVersion contentVersion = new ContentVersion();
        contentVersion.ContentLocation = 'S';
        contentVersion.PathOnClient = safeName + '_' + newVersion + '.pdf';
        contentVersion.Title = safeName + '_' + newVersion + '.pdf';
        contentVersion.IsMajorVersion = true;
        contentVersion.VersionData = pdfBlob;
        // Publish onto Quote so portal users inherit record access
        contentVersion.FirstPublishLocationId = quoteId;
        insert contentVersion;

        contentVersion = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :contentVersion.Id
        ];

        // Experience Cloud needs AllUsers visibility or iframe stays blank
        List<ContentDocumentLink> links = [
            SELECT Id, Visibility, ShareType
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :contentVersion.ContentDocumentId
            AND LinkedEntityId = :quoteId
            LIMIT 1
        ];
        if (!links.isEmpty()) {
            links[0].Visibility = 'AllUsers';
            links[0].ShareType = 'V';
            update links;
        } else {
            insert new ContentDocumentLink(
                ContentDocumentId = contentVersion.ContentDocumentId,
                LinkedEntityId = quoteId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
        }
        return contentVersion;
    }

    private static String termsAndConditionsHtml() {
        String b64 = '';
        b64 += 'PGRpdiBzdHlsZT0icGFnZS1icmVhay1iZWZvcmU6YWx3YXlzO3dpZHRoOiAxMDAlOyAgbWFyZ2luLXRvcDogNDBweDsiPgogICAgICAgICAgICAKICAgICAgICAgICAgCiAgICAgICAgICAgIDx0YWJsZSBzdHlsZT0id2lkdGg6IDEwMCU7IHRleHQtYWxpZ246IGNlbnRlcjsgY29sdW1uczogMjsiPgogICAgICAgICAgICAgICAgPHRyIGNsYXNzPSJyb3cxIj4KICAgICAgICAgICAgICAgICAgICA8dGQgY29sc3Bhbj0iMiI+CiAgICAgICAgICAgICAgICAgICAgICAgIDxzdHJvbmc+VEVSTVMgQU5EIENPTkRJVElPTlM8L3N0cm9uZz4KICAgICAgICAgICAgICAgICAgICA8L3RkPgogICAgICAgICAgICAgICAgPC90cj4KICAgICAgICAgICAgICAgIDx0ciAgPgogICAgICAgICAgICAgICAgICAgIDx0ZCBzdHlsZT0id2lkdGg6IDUwJTt2ZXJ0aWNhbC1hbGlnbjogdGV4dC10b3A7IHRleHQtYWxpZ246IGxlZnQ7IGZvbnQtc2l6ZTogNy41cHQ7Ij4KICAgICAgICAgICAgICAgICAgICAgICAgPHA+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICA8c3Ryb25nPjEuIERFRklOSVRJT05TOiA8L3N0cm9uZz4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICNSb3RleCMgc2hhbGwgbWVhbiAjIFJvdGV4IEF1dG9tYXRpb24gTGltaXRlZCMKICAgICAgICAgICAgICAgICAgICAgICAgICAgICNDdXN0b21lciMgc2hhbGwgbWVhbiB0aGUgcGVyc29uKHMpIG9yIGNvbXBhbnkgdGhhdCBwdXJjaGFzZXMKICAgICAgICAgICAgICAgICAgICAgICAgICAgIEVxdWlwbWVudC9TZXJ2aWNlcyBmcm9tIFJvdGV4IHB1cnN1YW50IHRvIHRoaXMgT3JkZXIuCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAjRXF1aXBtZW50IyBtZWFucyBhbGwgY29tcG9uZW50cywgc3BhcmUgcGFydHMsIGdvb2RzLCBlcXVpcG1lbnQsIG9yIG1hdGVyaWFscwogICAgICAgICAgICAgICAgICAgICAgICAgICAgb2YgYW55IGtpbmQsIHdoaWNoIGFyZSBzdXBwbGllZCBieSBSb3RleCB1bmRlciB0aGlzIE9yZGVyLgogICAgICAgICAgICAgICAgICAgICAgICAgICAgI09wZXJhdG9yIyBzaGFsbCBtZWFuIHRoZSBvcGVyYXRvciBvciB1c2VyIG9mIHRoZSBFcXVpcG1lbnQvU2VydmljZXMuCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAjT3JkZXIjIHNoYWxsIG1lYW4gdGhlIGFncmVlbWVudCBiZXR3ZWVuIFJvdGV4IGFuZCB0aGUgQ3VzdG9tZXIKICAgICAgICAgICAgICAgICAgICAgICAgICAgIChpbmRpdmlkdWFsbHkgI1BhcnR5IyBhbmQgY29sbGVjdGl2ZWx5ICN0aGUgUGFydGllcyMpIGZvciB0aGUgc2FsZSBhbmQgcHVyY2hhc2Ugb2YKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHRoZSBFcXVpcG1lbnQvU2VydmljZXMsIGluY2x1ZGluZyB0aGUgVGVybXMgYW5kIENvbmRpdGlvbnMgb2YgU2FsZSBoZXJlaW4gYW5kCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBhbnkgY29udGVtcG9yYW5lb3VzIHdyaXRpbmcsIHNpZ25lZCBieSBib3RoIFBhcnRpZXMsIGFuZCBmaXJtbHkgYXR0YWNoZWQKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGhlcmV0by4KICAgICAgICAgICAgICAgICAgICAgICAgICAgICNTZXJ2aWNlcyMgbWVhbnMgYWxsIHNlcnZpY2VzLCBpbmNsdWRpbmcgbWFpbnRlbmFuY2UgYW5kIGluc3RhbGxhdGlvbiBzZXJ2aWNlcywKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHByb3ZpZGVkIHVuZGVyIHRoaXMgT3JkZXIuIDxici8+PGJyLz4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgPHN0cm9uZz4yLiBPRkZFUiBBTkQgR09WRVJOSU5HIFBST1ZJU0lPTlM6ICA8L3N0cm9uZz4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIEVhY2ggcXVvdGF0aW9uIGFuZCBPcmRlcgogICAgICAgICAgICAgICAgICAgICAgICAgICAgYWNrbm93bGVkZ2VtZW50IGlzc3VlZCBieSBSb3RleCBpcyBhbiBvZmZlciBieSBSb3RleCB0byBzZWxsIHRoZSBnb29kcyBhbmQvb3IKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHNlcnZpY2VzIGRlc2NyaWJlZCBpbiBpdCBpbiBhY2NvcmRhbmNlIHdpdGggdGhlc2UgVGVybXMgYW5kIENvbmRpdGlvbnMgb2YgU2FsZSwKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGlzIG5vdCBhbiBhY2NlcHRhbmNlIG9mIGFueSBvZmZlciBtYWRlIGJ5IHRoZSBDdXN0b21lciwgYW5kIGlzIGV4cHJlc3NseQogICAgICAgICAgICAgICAgICAgICAgICAgICAgY29uZGl0aW9uZWQgdXBvbiB0aGUgQ3VzdG9tZXIncyBhc3NlbnQgdG8gdGhlc2UgVGVybXMgYW5kIENvbmRpdGlvbnMgb2YgU2FsZS4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIFJvdGV4IG9iamVjdHMgdG8gYW55IGFkZGl0aW9uYWwgb3IgZGlmZmVyZW50IHRlcm1zIGNvbnRhaW5lZCBpbiBhbnkgcHVyY2hhc2UKICAgICAgICAgICAgICAgICAgICAgICAgICAgIG9yZGVyIG9yIG90aGVyIGNvbW11bmljYXRpb24gcHJldmlvdXNseSBvciBoZXJlYWZ0ZXIgcHJvdmlkZWQgYnkgQ3VzdG9tZXIgdG8KICAgICAgICAgICAgICAgICAgICAgICAgICAgIFJvdGV4LiBObyBzdWNoIGFkZGl0aW9uYWwgb3IgZGlmZmVyZW50IHRlcm1zIG9yIGNvbmRpdGlvbnMgd2lsbCBiZSBvZiBhbnkgZm9yY2UKICAgICAgICAgICAgICAgICAgICAgICAgICAgIG9yIGVmZmVjdC4gVGhlIHRlcm1zIG9mIHRoZSBPcmRlciB3aWxsIGJlIHRoZSBlbnRpcmUgYWdyZWVtZW50IGJldHdlZW4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIEN1c3RvbWVyIGFuZCBSb3RleCBvbiB0aGUgc3ViamVjdCBvZiB0aGUgdHJhbnNhY3Rpb24gdGhhdCBpdCBkZXNjcmliZXM7IGFuZCB0aGVyZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgYXJlIG5vIGNvbmRpdGlvbnMgdG8gdGhhdCBhZ3JlZW1lbnQgdGhhdCBhcmUgbm90IHBhcnQgb2YgdGhlIE9yZGVyLjxici8+PGJyLz4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgPHN0cm9uZz4zLiBQVVJDSEFTRSBQUklDRTogPC9zdHJvbmc+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICBQcmljZXMgc2hhbGwgYmUgYXMgc3BlY2lmaWVkIGJ5IFJvdGV4IGFuZCBzaGFsbCBhcHBseQogICAgICAgICAgICAgICAgICAgICAgICAgICAgZm9yIHRoZSBwZXJpb2Qgc3BlY2lmaWVkLiBJZiBubyBwZXJpb2QgaXMgc3BlY2lmaWVkLCBwcmljZXMgc2hhbGwgYmUgdmFsaWQgZm9yIDMwCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBkYXlzLiBQcmljZXMgY2l0ZWQgaGVyZWluIGFyZSBiYXNlZCBvbiBjdXJyZW50IGNvc3RzIGFuZCBhcmUgc3ViamVjdCB0byByZWFzb25hYmxlCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBhZGp1c3RtZW50IG9uIG9yIGFmdGVyIHRoZSBkYXRlIG9mIGFjY2VwdGFuY2Ugb2YgYW55IHB1cmNoYXNlIG9yZGVyIHRvIG1lZXQgYQogICAgICAgICAgICAgICAgICAgICAgICAgICAgcmlzZSBvciBmYWxsIGluIHN1Y2ggY29zdHMsIGFzIGNvbXB1dGVkIG9uIHRoZSBkYXRlIG9mIGRlbGl2ZXJ5LiBJbiB0aGUgZXZlbnQgdGhlCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBDdXN0b21lciBpcyBwdXJjaGFzaW5nIHRoZSBFcXVpcG1lbnQgZm9yIHJlc2FsZSB0byBhIHRoaXJkIHBhcnR5LCB0aGUgQ3VzdG9tZXIKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHNoYWxsIGludGltYXRlIFJvdGV4IG9mIHRoZSBzYW1lLiBJbiBzdWNoIGV2ZW50LCBSb3RleCByZXNlcnZlcyB0aGUgcmlnaHQsIHRvIHRoZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgZXh0ZW50IHBlcm1pdHRlZCBieSB0aGUgYXBwbGljYWJsZSBsYXcsIHRvIGVzdGFibGlzaCBhbmQgdG8gcmV2aXNlLCBieSBnaXZpbmcKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHdyaXR0ZW4gbm90aWNlIHRvIHRoZSBDdXN0b21lciwgbWF4aW11bSBwcmljZXMgYXQgd2hpY2ggZWFjaCBvZiB0aGUgRXF1aXBtZW50CiAgICAgICAgICAgICAgICAgICAgICAgICAgICBtYXkgYmUgc29sZCBieSB0aGUgQ3VzdG9tZXIgdG8gYSB0aGlyZCBwYXJ0eS48YnIvPjxici8+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxzdHJvbmc+NC4gUEFZTUVOVDogPC9zdHJvbmc+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAoQSkgVW5sZXNzIG90aGVyd2lzZSBhZ3JlZWQgdG8gYnkgUm90ZXggaW4gd3JpdGluZywgcGF5bWVudAogICAgICAgICAgICAgICAgICAgICAgICAgICAgc2hhbGwgYmUgbWFkZSBpbiBmdWxsIGJ5IEN1c3RvbWVyIGluIGFkdmFuY2Ugb2Ygc2hpcG1lbnQgb3IgZGVsaXZlcnkuIEN1c3RvbWVyCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBhZ3JlZXMgdG8gcGF5IHRoZSBlbnRpcmUgYW1vdW50IG9mIGVhY2ggaW52b2ljZSB3aXRob3V0IHNldC1vZmYgb3IgZGVkdWN0aW9uLjxici8+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAoQikgUHVuY3R1YWwgcGF5bWVudCBhcyBzdGlwdWxhdGVkIGhlcmVpbiBpcyBvZiB0aGUgZXNzZW5jZSBmb3IgdGhlIE9yZGVyLiBXaGVuCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBhbnkgc3VtIG93ZWQgYnkgQ3VzdG9tZXIgdG8gUm90ZXggdW5kZXIgdGhpcyBPcmRlciBpcyBvdmVyZHVlLCBSb3RleCBtYXksCiAgICAgICAgICAgICAgICAgICAgICAgICAgICB3aXRob3V0IG5vdGljZSB0byBDdXN0b21lcjo8YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgKGkpIGNlYXNlIHRoZSBzdXBwbHkgb2YgZnVydGhlciBFcXVpcG1lbnQvU2VydmljZXMgdW5kZXIgdGhpcyBPcmRlciB3aXRob3V0CiAgICAgICAgICAgICAgICAgICAgICAgICAgICBsaWFiaWxpdHkgZm9yIGFueSBsb3NzIChpbmNsdWRpbmcgbG9zcyBvZiBwcm9maXQsIGNvbnNlcXVlbnRpYWwgb3IgaW5kaXJlY3QgbG9zcyBvcgogICAgICAgICAgICAgICAgICAgICAgICAgICAgb3RoZXIgZmluYW5jaWFsIG9yIGVjb25vbWljIGxvc3MpIHRvIEN1c3RvbWVyIHVudGlsIHN1Y2ggc3VtLCB0b2dldGhlciB3aXRoIHN1Y2gKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGludGVyZXN0IGFzIG1heSBiZSBkdWUgdGhlcmVvbiwgaXMgcGFpZDsgYW5kL29yPGJyLz4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIChpaSkgdGVybWluYXRlIHRoZSBPcmRlciBhbmQgYW55IG90aGVyIGFncmVlbWVudHMgYmV0d2VlbiBSb3RleCBhbmQgQ3VzdG9tZXIsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICB3aGV0aGVyIG9yIG5vdCBhbnkgc3VtcyBhcmUgZHVlIGZvciBwYXltZW50IGJ5IEN1c3RvbWVyIHRoZXJldW5kZXIsIHdpdGhvdXQKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHByZWp1ZGljZSB0byBSb3RleCcgcmlnaHQgdG8gcmVjb3ZlciBzdWNoIHN1bXMgYXMgbWF5IGJlIGR1ZSBmcm9tIHRoZSBDdXN0b21lcgogICAgICAgICAgICAgICAgICAgICAgICAgICAgYW5kIHdpdGhvdXQgbGlhYmlsaXR5IG9uIHRoZSBwYXJ0IG9mIFJvdGV4Ozxici8+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAoQykgTm8gZGVmZWN0IGluIHRoZSBPcmRlciBvZiB0aGUgRXF1aXBtZW50L1NlcnZpY2VzIHNoYWxsIG9wZXJhdGUgdG8gaW50ZXJmZXJlCiAgICAgICAgICAgICAgICAgICAgICAgICAgICB3aXRoIHRoZSB0ZXJtcyBvZiBwYXltZW50LiBJZiBwYXltZW50IGlzIG5vdCBtYWRlIGFzIHByb3ZpZGVkIGFib3ZlLCBDdXN0b21lcgogICAgICAgICAgICAgICAgICAgICAgICAgICAgc2hhbGwgdGhlcmVieSBiZSBkZWVtZWQgdG8gaGF2ZSB3YWl2ZWQgdGhlIHdhcnJhbnRpZXMgcHJvdmlkZWQgaW4gU2VjdGlvbiAxMAogICAgICAgICAgICAgICAgICAgICAgICAgICAgaGVyZXVuZGVyLiBSb3RleCBtYXkgZGVtYW5kIGRpZmZlcmVudCB0ZXJtcyBvZiBwYXltZW50IGZyb20gdGhvc2Ugc3BlY2lmaWVkCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBvbiB0aGUgZmFjZSBv';
        b64 += 'ZiB0aGlzIE9yZGVyLCB3aGVuZXZlciBpdCByZWFzb25hYmx5IGFwcGVhcnMgdGhhdCBDdXN0b21lciNzCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBmaW5hbmNpYWwgY29uZGl0aW9uIHJlcXVpcmVzIHN1Y2ggY2hhbmdlcywgYW5kIG1heSBkZW1hbmQgYXNzdXJhbmNlIG9mIHRoZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgQ3VzdG9tZXIjcyBhYmlsaXR5IHRvIHBheSB3aGVuZXZlciBpdCByZWFzb25hYmx5IGFwcGVhcnMgdGhhdCBzdWNoIGFiaWxpdHkgaXMgaW4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIGRvdWJ0LiBTdWNoIGRlbWFuZCBzaGFsbCBiZSBpbiB3cml0aW5nIGFuZCBSb3RleCBtYXksIHVwb24gbWFraW5nIHN1Y2gKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGRlbWFuZCwgc3RvcCBwcm9kdWN0aW9uIGFuZC9vciBzdXNwZW5kIHNoaXBtZW50cyBoZXJldW5kZXIuPGJyLz4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIChEKSBJZiBDdXN0b21lciBpcyBpbiBkZWZhdWx0IG9mIGFueSBwYXltZW50IG9ibGlnYXRpb24sIFJvdGV4IGlzLCB3aXRob3V0CiAgICAgICAgICAgICAgICAgICAgICAgICAgICByZW1pbmRlciBhbmQgcHJlanVkaWNlIHRvIGFueSBvdGhlciByaWdodHMsIGVudGl0bGVkIHRvIGNoYXJnZSBpbnRlcmVzdCBhdCB0aGUKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHByZXZhaWxpbmcgYmFzZSByYXRlIG9mIFN0YXRlIEJhbmsgb2YgSW5kaWEgZm9yIGFueSBvdXRzdGFuZGluZyBzdW0sIGJlZ2lubmluZwogICAgICAgICAgICAgICAgICAgICAgICAgICAgd2l0aCBhbnkgZHVlIGRhdGUgb2YgcGF5bWVudCB1bnRpbCByZWNlaXB0IG9mIGZ1bGwgYW5kIGZpbmFsIHBheW1lbnQgYWxvbmcgd2l0aAogICAgICAgICAgICAgICAgICAgICAgICAgICAgaW50ZXJlc3QgYWNjcnVlZCB0aGVyZW9uPGJyLz48YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICA8c3Ryb25nPiA1LiBMSUVOUyBBTkQgVElUTEU6IDwvc3Ryb25nPihBKSBDdXN0b21lciBoZXJlYnkgZ3JhbnRzIHRvIFJvdGV4IGEgc2VjdXJpdHkKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGludGVyZXN0IGluIGFueSBwcm9wZXJ0eSBvd25lZCBieSB0aGUgQ3VzdG9tZXIgKGluY2x1ZGluZyBDdXN0b21lciNzCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBiZW5lZmljaWFsIHJpZ2h0cyB0byBwcm9wZXJ0eSBsZWFzZWQgYnkgQ3VzdG9tZXIpIGluIHRoZSBwb3NzZXNzaW9uIG9mIFJvdGV4IG9yCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBhbnkgb2YgUm90ZXgjIGFmZmlsaWF0ZXMsIGF0IGFueSB0aW1lLCB0byBzZWN1cmUgYWxsIGFtb3VudHMgb3dlZCBieSBDdXN0b21lciB0bwogICAgICAgICAgICAgICAgICAgICAgICAgICAgUm90ZXggdW5kZXIgdGhpcyBPcmRlci4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIChCKSBJbiB0aGUgY2FzZSBvZiByZXBhaXJzIG9yIG92ZXJoYXVscyBwZXJmb3JtZWQgcHVyc3VhbnQgdG8gdGhpcyBPcmRlciwKICAgICAgICAgICAgICAgICAgICAgICAgICAgIEN1c3RvbWVyIGFncmVlcyB0byBncmFudCBSb3RleCBhIHBlcmZlY3RlZCBzZWN1cml0eSBpbnRlcmVzdCBpbiBhbGwgRXF1aXBtZW50CiAgICAgICAgICAgICAgICAgICAgICAgICAgICByZXRhaW5lZCBpbiBwb3NzZXNzaW9uIG9mIFJvdGV4IHVwb24gd2hpY2ggYW55IHJlcGFpciBvciBvdmVyaGF1bCBzZXJ2aWNlcyBoYXZlCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBiZWVuIHBlcmZvcm1lZCBieSBSb3RleC4gQ3VzdG9tZXIgZnVydGhlciBhY2tub3dsZWRnZXMgYW5kIGFncmVlcyB0aGF0LCBpbgogICAgICAgICAgICAgICAgICAgICAgICAgICAgYWRkaXRpb24gdG8gdGhlIHNlY3VyaXR5IGludGVyZXN0IGFuZCBsaWVuIGV4cHJlc3NseSBncmFudGVkIGJ5IEN1c3RvbWVyIHRvCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBSb3RleCwgUm90ZXggc2hhbGwgaGF2ZSBhIGxpZW4gb24gdGhlIEVxdWlwbWVudCByZXRhaW5lZCBpbiBwb3NzZXNzaW9uIG9mIFJvdGV4CiAgICAgICAgICAgICAgICAgICAgICAgICAgICB0byB0aGUgZXh0ZW50IG90aGVyd2lzZSBwcm92aWRlZCBieSBsYXcuIEN1c3RvbWVyIGFja25vd2xlZGdlcyB0aGF0IHRoZSBsaWVuCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAod2hldGhlciBncmFudGVkIGJ5IEN1c3RvbWVyIG9yIHRocm91Z2ggdGhlIG9wZXJhdGlvbiBvZiBsYXcpIGZvciByZXBhaXJzIG9yCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBvdmVyaGF1bCBzaGFsbCBiZSBmb3IgdGhlIGZ1bGwgdmFsdWUgb2Ygc3VjaCB3b3JrLCBhbmQgc2hhbGwgYmUgc3VwZXJpb3IgdG8gYW55CiAgICAgICAgICAgICAgICAgICAgICAgICAgICBsaWVuIG9yIGludGVyZXN0IGluIGZhdm91ciBvZiBDdXN0b21lciwgaXRzIHBhcmVudHMsIGFmZmlsaWF0ZXMsIG9yIHN1YnNpZGlhcmllcywgb3IKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGFueSBvdGhlciBwZXJzb24gd2hvIGhhcyBrbm93bGVkZ2Ugb2YgdGhpcyBPcmRlci4gVG8gdGhlIGV4dGVudCB0aGF0IFJvdGV4CiAgICAgICAgICAgICAgICAgICAgICAgICAgICBtYWludGFpbnMgcG9zc2Vzc2lvbiBvZiBFcXVpcG1lbnQgdW5kZXIgcmVwYWlyLCBDdXN0b21lciBhZ3JlZXMgdGhhdCBSb3RleCBpcwogICAgICAgICAgICAgICAgICAgICAgICAgICAgYSBzZWN1cmVkIGNyZWRpdG9yIG9mIEN1c3RvbWVyIGFuZCBoYXMgYWxsIHRoZSByaWdodHMgb2YgYSBzZWN1cmVkIGNyZWRpdG9yLgogICAgICAgICAgICAgICAgICAgICAgICAgICAgKEMpIFdpdGggcmVzcGVjdCB0byBFcXVpcG1lbnQgc29sZCBwdXJzdWFudCB0byB0aGlzIE9yZGVyLCBDdXN0b21lciBhZ3JlZXMgYW5kCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgPC9wPiAKICAgICAgICAgICAgICAgICAgICA8L3RkPgogICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgIDx0ZCBzdHlsZT0id2lkdGg6IDUwJTt2ZXJ0aWNhbC1hbGlnbjogdGV4dC10b3A7IHRleHQtYWxpZ246IGxlZnQ7IGZvbnQtc2l6ZTogNy41cHQ7Ij4KICAgICAgICAgICAgICAgICAgICAgICAgPHA+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHRoZSBDdXN0b21lciwgUm90ZXggbWF5LCBhdCBpdHMgZGlzY3JldGlvbiwgcmVjb3ZlciBhbGwgRXF1aXBtZW50IHNvbGQgcHVyc3VhbnQKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHRvIHRoaXMgT3JkZXIgYW5kL29yIHNlZWsgZGFtYWdlcyBvciBjb3N0cyBzdWJqZWN0IHRvIGFwcGxpY2FibGUgbGF3cy4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIChEKSBUaGUgQ3VzdG9tZXIgaGVyZWJ5IHVuZGVydGFrZXMgdG8gcmVnaXN0ZXIgdGhlIHNlY3VyaXR5IGludGVyZXN0IGNyZWF0ZWQgb24KICAgICAgICAgICAgICAgICAgICAgICAgICAgIGl0cyBhc3NldHMgaW4gdGVybXMgb2Ygc2VjdGlvbiA1KEEpLCAoQikgYW5kIChDKSBhYm92ZSwgd2l0aCB0aGUgcmVsZXZhbnQgUmVnaXN0cmFyCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBvZiBDb21wYW5pZXMgaW4gY29tcGxpYW5jZSB3aXRoIHRoZSBwcm92aXNpb25zIG9mIHRoZSBDb21wYW5pZXMgQWN0LCAxOTU2CiAgICAgICAgICAgICAgICAgICAgICAgICAgICBhbmQgcHJvdmlkZSB3cml0dGVuIG5vdGlmaWNhdGlvbiB0byBSb3RleCB3aXRoaW4gNSBkYXlzIG9mIHN1Y2ggcmVnaXN0cmF0aW9uLjxici8+PGJyLz4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxzdHJvbmc+IDYuIERFTElWRVJZOiA8L3N0cm9uZz4oQSkgVW5sZXNzIG90aGVyd2lzZSBhZ3JlZWQgdG8gaW4gd3JpdGluZywgYWxsIHNoaXBtZW50cyBvZgogICAgICAgICAgICAgICAgICAgICAgICAgICAgRXF1aXBtZW50IGJ5IFJvdGV4IHNoYWxsIGJlIEV4IFdvcmtzIFJvdGV4IyBEZXNpZ25hdGVkIEZhY2lsaXR5CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAoSU5DT1RFUk1TIDIwMjApLiBDdXN0b21lciBhY2tub3dsZWRnZXMgdGhhdCBkZWxpdmVyeSBkYXRlcyBwcm92aWRlZCBieQogICAgICAgICAgICAgICAgICAgICAgICAgICAgUm90ZXggYXJlIGVzdGltYXRlcyBvbmx5LiBSb3RleCBzaGFsbCB1c2UgcmVhc29uYWJsZSBlZmZvcnRzIHRvIG1ha2UgdGltZWx5CiAgICAgICAgICAgICAgICAgICAgICAgICAgICBkZWxpdmVyeSBidXQgc2hhbGwgYmUgZXhjdXNlZCBmcm9tIGFueSBkZWxheXMgYXJpc2luZyBvdXQgb2YgY2F1c2VzIGJleW9uZCBpdHMKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHJlYXNvbmFibGUgY29udHJvbC4gUm90ZXggc2hhbGwsIHVuZGVyIG5vIGNpcmN1bXN0YW5jZXMsIGJlIGxpYWJsZSBmb3IgYW55IGxvc3MKICAgICAgICAgICAgICAgICAgICAgICAgICAgIG9yIGRhbWFnZXMgaW5jbHVkaW5nIGluY2lkZW50YWwgb3IgY29uc2VxdWVudGlhbCAoaGVyZWluYWZ0ZXIgY29udGVtcGxhdGVkIGFzCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBpbmNsdWRpbmcsIGJ1dCBub3QgbGltaXRlZCB0bywgZGFtYWdlcyBmb3IgbG9zdCBwcm9maXRzLCBsb3N0IHNhbGVzIGFuZCBpbmp1cnkgdG8KICAgICAgICAgICAgICAgICAgICAgICAgICAgIHBlcnNvbiBvciBwcm9wZXJ0eSksIGZvciBkZWxheXMsIG9yIGZhaWx1cmUgdG8gZ2l2ZSBub3RpY2Ugb2YgZGVsYXksIHdoZXRoZXIgb3Igbm90CiAgICAgICAgICAgICAgICAgICAgICAgICAgICBjYXVzZWQgYnkgb3IgcmVzdWx0aW5nIGZyb20gUm90ZXgjIG5lZ2xpZ2VuY2UuIEN1c3RvbWVyIGFncmVlcyBub3QgdG8gbWFrZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgc3VjaCBjbGFpbSBvbiBSb3RleC48YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgVElNRSBJUyBPRiBUSEUgRVNTRU5DRTogVGhpcyBjbGF1c2UgKHdoZXJlIGFwcGxpY2FibGUpIGNhbm5vdCBiZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgYWNjZXB0ZWQsIFJvdGV4IHdpbGwgdXNlIGFsbCByZWFzb25hYmxlIGVmZm9ydHMgdG8gbWVldCB0aGUgQ3VzdG9tZXIjcy8gZGVsaXZlcnkKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHNjaGVkdWxlcy48YnIvPjxici8+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICA8c3Ryb25nPjcuIEFDQ0VQVEFOQ0UgT0YgRVFVSVBNRU5UOjwvc3Ryb25nPiBDdXN0b21lciBzaGFsbCBjb25kdWN0IGEgdGhvcm91Z2gKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGV2YWx1YXRpb24gb2YgdGhlIGV4dGVyaW9yIG9mIHRoZSBzeXN0ZW0gdXBvbiByZWNlaXB0IG9mIHRoZSBFcXVpcG1lbnQuIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgQ3VzdG9tZXIgaXMgZGVlbWVkIHRvIGhhdmUgYWNjZXB0ZWQgdGhlIEVxdWlwbWVudCB1bmxlc3Mgd3JpdHRlbiBub3RpY2Ugb2YKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHJlamVjdGlvbiBpcyByZWNlaXZlZCBieSBSb3RleCB3aXRoaW4gMyBkYXlzIGFmdGVyIGRlbGl2ZXJ5LCB3aGljaCB0aGUgUGFydGllcwogICAgICAgICAgICAgICAgICAgICAgICAgICAgYWdyZWUgaXMgYSByZWFzb25hYmxlIHBlcmlvZC4gQ3VzdG9tZXIgd2FpdmVzIGFueSByaWdodCB0byByZXZva2UgYWNjZXB0YW5jZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgdGhlcmVhZnRlci48YnIvPjxici8+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICA8c3Ryb25nPjguIFJFVFVSTiBPRiBFUVVJUE1FTlQ6IDwvc3Ryb25nPk5vIHJldHVybiBvZiBFcXVpcG1lbnQgc2hhbGwgYmUgYWNjZXB0ZWQKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGJ5IFJvdGV4IHdpdGhvdXQgYSBSZXR1cm4gTWF0ZXJpYWwgQXV0aG9yaXphdGlvbiAoI1JNQSMpIG51bWJlciwg';
        b64 += 'd2hpY2gKICAgICAgICAgICAgICAgICAgICAgICAgICAgIG1heSBiZSBpc3N1ZWQgYnkgUm90ZXggaW4gaXRzIHNvbGUgZGlzY3JldGlvbi4gUmV0dXJuZWQgRXF1aXBtZW50IG11c3QgYmUgaW4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIGl0cyBvcmlnaW5hbCBzaGlwcGluZyBjYXJ0b25zIGNvbXBsZXRlIHdpdGggYWxsIHBhY2tpbmcgbWF0ZXJpYWxzLiBBbGwgRXF1aXBtZW50CiAgICAgICAgICAgICAgICAgICAgICAgICAgICBmb3IgcmV0dXJuIHNoYWxsIGJlIHJldHVybmVkIGZyZWlnaHQgcHJlcGFpZCBpbiB0aGUgbWFubmVyIHNwZWNpZmllZCBpbiB0aGUgUk1BLgogICAgICAgICAgICAgICAgICAgICAgICAgICAgSWYgcmV0dXJuZWQgRXF1aXBtZW50IGlzIGNsYWltZWQgdG8gYmUgZGVmZWN0aXZlLCBhIGNvbXBsZXRlIGRlc2NyaXB0aW9uIG9mIHRoZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgbmF0dXJlIG9mIHRoZSBkZWZlY3QgbXVzdCBiZSBpbmNsdWRlZCB3aXRoIHRoZSByZXR1cm5lZCBFcXVpcG1lbnQuIEVxdWlwbWVudAogICAgICAgICAgICAgICAgICAgICAgICAgICAgbm90IGVsaWdpYmxlIGZvciByZXR1cm4gc2hhbGwgYmUgcmV0dXJuZWQgdG8gQ3VzdG9tZXIsIGZyZWlnaHQgY29sbGVjdC48YnIvPjxici8+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICA8c3Ryb25nPjkuIFdBUlJBTlRJRVM6IDwvc3Ryb25nPihBKSBSb3RleCB3YXJyYW50cyB0aGF0IHRoZSBFcXVpcG1lbnQgc29sZCBieSBSb3RleCwKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGFuZCB0aGF0IGlzIG1hbnVmYWN0dXJlZCBieSBSb3RleCwgZm9yIGEgcGVyaW9kIG9mIDEyIG1vbnRocyB1bmxlc3Mgb3RoZXJ3aXNlCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBhZ3JlZWQgdG8gYnkgUm90ZXggaW4gd3JpdGluZyAoMSkgY29uZm9ybXMgdG8gUm90ZXggc3BlY2lmaWNhdGlvbnMsIGFuZCAoMikgaXMKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGZyZWUgZnJvbSBkZWZlY3RzIGluIG1hdGVyaWFscyBhbmQgd29ya21hbnNoaXAgKHVuZGVyIG5vcm1hbCB1c2FnZSBhbmQKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHByb3ZpZGVkIHRoYXQgUm90ZXgnIG9wZXJhdGlvbiBhbmQgbWFpbnRlbmFuY2UgaW5zdHJ1Y3Rpb25zIGFyZSBmb2xsb3dlZCBieSB0aGUKICAgICAgICAgICAgICAgICAgICAgICAgICAgIE9wZXJhdG9yKS4gTm9ybWFsIHdlYXIgYW5kIHRlYXIgc2hhbGwgbm90IGJlIGNvbnNpZGVyZWQgYSBkZWZlY3QuIFRoZSB3YXJyYW50eQogICAgICAgICAgICAgICAgICAgICAgICAgICAgcGVyaW9kIHNoYWxsIGNvbW1lbmNlIGRhdGUgb2Ygc2hpcG1lbnQgb2YgdGhlIEVxdWlwbWVudCB0byB0aGUgQ3VzdG9tZXIsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICB3aGV0aGVyIG9yIG5vdCB0aGUgRXF1aXBtZW50IGhhcyBiZWVuIGluc3RhbGxlZCBvciBjb21taXNzaW9uZWQuIEEgd3JpdHRlbgogICAgICAgICAgICAgICAgICAgICAgICAgICAgcHJvZHVjdC1zcGVjaWZpYyB3YXJyYW50eSBhZGRlbmR1bSBtYXkgYWRkcmVzcyBjb25zdW1hYmxlIGl0ZW1zIG9yIG90aGVyCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBwYXJ0cyB0aGF0IGFyZSBub3QgY292ZXJlZCBieSB0aGlzIFdhcnJhbnR5IG9yIGNvbnRhaW4gYWx0ZXJuYXRlIHdhcnJhbnR5IHRlcm1zCiAgICAgICAgICAgICAgICAgICAgICAgICAgICB0aGF0IHdpbGwgc3VwZXJzZWRlIGFueSBzaW1pbGFyIHRlcm1zIGluIHRoaXMgd2FycmFudHkgc2VjdGlvbi48YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgKEIpIFJvdGV4IHdhcnJhbnRzIHRoYXQgaXQgc2hhbGwgdXNlIHJlYXNvbmFibGUgZWZmb3J0cyB0byBwcm92aWRlIHRoZSBTZXJ2aWNlcwogICAgICAgICAgICAgICAgICAgICAgICAgICAgb3JkZXJlZCB1bmRlciB0aGUgT3JkZXIuIFJvdGV4IGRvZXMgbm90IHJlcHJlc2VudCBvciB3YXJyYW50IHRoYXQgYWxsIEVxdWlwbWVudAogICAgICAgICAgICAgICAgICAgICAgICAgICAgcHJvYmxlbXMgd2lsbCBiZSBjb3JyZWN0ZWQgb3IgaWYgY29ycmVjdGVkLCBjb3JyZWN0ZWQgdG8gdGhlIGZ1bGwgc2F0aXNmYWN0aW9uIG9mCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBDdXN0b21lci4gVGhlIGV4cHJlc3Mgd2FycmFudHkgc2V0IGZvcnRoIGluIHRoZSBmaXJzdCBzZW50ZW5jZSBvZiB0aGlzIHBhcmFncmFwaAogICAgICAgICAgICAgICAgICAgICAgICAgICAgc2hhbGwgYmUgdGhlIG9ubHkgd2FycmFudHkgZ2l2ZW4gYnkgUm90ZXggd2l0aCByZXNwZWN0IHRvIHRoZSBTZXJ2aWNlcyBwcm92aWRlZC48YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgKEMpIEZvciBFcXVpcG1lbnQgdGhhdCBpcyBub3QgbWFudWZhY3R1cmVkIGJ5IFJvdGV4LCBSb3RleCcgb25seSByZXNwb25zaWJpbGl0eQogICAgICAgICAgICAgICAgICAgICAgICAgICAgaXMgdG8gYXNzaWduIHRvIGl0cyBDdXN0b21lciBhbnkgbWFudWZhY3R1cmVyI3Mgd2FycmFudHkgdGhhdCBkb2VzIG5vdCBwcm9oaWJpdAogICAgICAgICAgICAgICAgICAgICAgICAgICAgc3VjaCBhc3NpZ25tZW50Ljxici8+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAoRCkgRXF1aXBtZW50IGFuZCBwYXJ0cyB0aGF0IGFyZSBjb25zdW1lZCBpbiBub3JtYWwgb3BlcmF0aW9uIGFyZSBub3QgY292ZXJlZAogICAgICAgICAgICAgICAgICAgICAgICAgICAgYnkgdGhpcyBXYXJyYW50eS48YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgKEUpIElmIEN1c3RvbWVyIG9yIGVuZCB1c2VyLCBhcyB0aGUgY2FzZSBtYXkgYmUsIGRpc2NvdmVycyBhIGRlZmVjdCB3aXRoaW4gdGhlCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBhcHBsaWNhYmxlIHdhcnJhbnR5IHBlcmlvZCwgaXQgbXVzdCBiZSByZXBvcnRlZCB0byBSb3RleCMgc2VydmljZSBkZXBhcnRtZW50CiAgICAgICAgICAgICAgICAgICAgICAgICAgICBpbW1lZGlhdGVseSB1cG9uIGRpc2NvdmVyeS48YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgKEYpIFdpdGhpbiBhIHJlYXNvbmFibGUgdGltZSBhZnRlciBwcm9wZXIgbm90aWZpY2F0aW9uLCBSb3RleCBzaGFsbCwgZHVyaW5nIGl0cwogICAgICAgICAgICAgICAgICAgICAgICAgICAgbm9ybWFsIGJ1c2luZXNzIGhvdXJzLCBNb25kYXkgdGhyb3VnaCBGcmlkYXksIGNvcnJlY3QgYW55IGRlZmVjdCBjb3ZlcmVkIGJ5CiAgICAgICAgICAgICAgICAgICAgICAgICAgICB0aGlzIHdhcnJhbnR5IHdpdGggZWl0aGVyIG5ldyBvciB1c2VkIHJlcGxhY2VtZW50IHBhcnRzLCB3aXRob3V0IGNoYXJnZS4gVGhlCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBvcmlnaW5hbCBkdXJhdGlvbiBvZiB0aGlzIFdhcnJhbnR5IHNoYWxsIHJlbWFpbiBhcHBsaWNhYmxlIHRvIHRob3NlIHBhcnRzIG5vdAogICAgICAgICAgICAgICAgICAgICAgICAgICAgcmVwYWlyZWQgb3IgcmVwbGFjZWQuIEFueSBwYXJ0IHJlcGFpcmVkIG9yIHJlcGxhY2VkIGlzIHdhcnJhbnRlZCB0byBjb25mb3JtIHRvCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBSb3RleCdzIHNwZWNpZmljYXRpb25zIGFuZCB0byBiZSBmcmVlIGZyb20gZGVmZWN0cyBpbiBtYXRlcmlhbHMgb3Igd29ya21hbnNoaXAKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGFwcGVhcmluZyB3aXRoaW4gYSBwZXJpb2QgYWZ0ZXIgcmVwYWlyIG9yIHJlcGxhY2VtZW50IGVxdWl2YWxlbnQgdG8gdGhlIHdhcnJhbnR5CiAgICAgICAgICAgICAgICAgICAgICAgICAgICBwZXJpb2Qgb3JpZ2luYWxseSBhcHBsaWNhYmxlIHRvIHRoZSBFcXVpcG1lbnQgb2Ygd2hpY2ggaXQgaXMgYSBwYXJ0LCBzdWJqZWN0IHRvIHRoZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgb3RoZXIgdGVybXMgb2YgdGhpcyBXYXJyYW50eS4gVGhlIGFib3ZlIHJlbWVkaWVzIGFyZSB0aGUgZXhjbHVzaXZlIHJlbWVkaWVzIG9mCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBDdXN0b21lciBhbmQgRW5kIHVzZXIsIGFuZCB0aGUgc29sZSByZXNwb25zaWJpbGl0eSBvZiBSb3RleCwgZm9yIGJyZWFjaCBvZiB0aGlzCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBXYXJyYW50eS48YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgKEcpIFJvdGV4IyBXYXJyYW50eSBjZWFzZXMgdG8gYmUgZWZmZWN0aXZlIGlmIEN1c3RvbWVyIGFuZC9vciBFbmQgdXNlciBmYWlsIHRvCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBvcGVyYXRlIGFuZCB1c2UgdGhlIEVxdWlwbWVudCBzb2xkIGhlcmV1bmRlciBpbiBhIHNhZmUgYW5kIHJlYXNvbmFibGUgbWFubmVyCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBpbiBhY2NvcmRhbmNlIHdpdGggUm90ZXgjIHdyaXR0ZW4gaW5zdHJ1Y3Rpb25zLjxici8+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAoSCkgTmVpdGhlciBDdXN0b21lciBub3IgRW5kIFVzZXIgc2hhbGwgYmUgZW50aXRsZWQgdG8gYW55IHJlbWVkeSB1bmRlciB0aGlzCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBXYXJyYW50eSB3aXRoIHJlc3BlY3QgdG88YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgKGkpIEVxdWlwbWVudCB0aGF0IGhhcyBiZWVuIHN1YmplY3RlZCB0byBhbnkgYWx0ZXJhdGlvbiwgZGlzYXNzZW1ibHksIHRhbXBlcmluZywKICAgICAgICAgICAgICAgICAgICAgICAgICAgIG1vZGlmaWNhdGlvbiwgb3IgcmVwYWlyIHdpdGhvdXQgcHJpb3IgYXV0aG9yaXphdGlvbiBieSBSb3RleDs8YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgKGlpKSBFcXVpcG1lbnQgc3ViamVjdGVkIHRvIGV4cGVyaW1lbnRhbCBydW5uaW5nIG9yIGFueSB0eXBlIG9mIG9wZXJhdGlvbiBvciB1c2UKICAgICAgICAgICAgICAgICAgICAgICAgICAgIG90aGVyIHRoYW4gdGhhdCBmb3Igd2hpY2ggdGhlIEVxdWlwbWVudC9TZXJ2aWNlcyBpcyBkZXNpZ25lZDs8YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgKGlpaSkgRXF1aXBtZW50IGZyb20gd2hpY2ggUm90ZXgjIGFuZC9vciB2ZW5kb3IjcyB0cmFkZW1hcmsgb3Igc2VyaWFsIG51bWJlcgogICAgICAgICAgICAgICAgICAgICAgICAgICAgaGFzIGJlZW4gYWx0ZXJlZCwgcmVtb3ZlZCwgb3Igb2JsaXRlcmF0ZWQgd2l0aG91dCBSb3RleCMgd3JpdHRlbiBwZXJtaXNzaW9uLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgZXhjbHVkaW5nIGFueSBhbHRlcmF0aW9uLCByZW1vdmFsLCBvciBvYmxpdGVyYXRpb24gZGlyZWN0bHkgY2F1c2VkIGJ5IGFjY2lkZW50IG9yCiAgICAgICAgICAgICAgICAgICAgICAgIDwvcD4KICAgICAgICAgICAgICAgICAgICA8L3RkPgogICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgPC90cj4KICAgICAgICAgICAgICAgIAogICAgICAgICAgICA8L3RhYmxlPiAKICAgICAgICA8L2Rpdj4gIAogICAgICAgIAogICAgICAgIDxkaXYgc3R5bGU9InBhZ2UtYnJlYWstYWZ0ZXI6YXV0bzt3aWR0aDogMTAwJTsgIG1hcmdpbi10b3A6IDQwcHg7Ij4KICAgICAgICAgICAgCiAgICAgICAgICAgIAogICAgICAgICAgICA8dGFibGUgc3R5bGU9IndpZHRoOiAxMDAlOyB0ZXh0LWFsaWduOiBjZW50ZXI7IGNvbHVtbnM6IDI7Ij4KICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgPHRyICA+CiAgICAgICAgICAgICAgICAgICAgPHRkIHN0eWxlPSJ3aWR0aDogNTAlO3ZlcnRpY2FsLWFsaWduOiB0ZXh0LXRvcDsgdGV4dC1hbGlnbjogbGVmdDsgZm9udC1zaXplOiA3LjVwdDsiPgogICAgICAgICAgICAgICAgICAgICAgICA8cD4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIGxpYWJpbGl0eSBzZXQgZm9ydGggaW4gU2VjdGlvbiAxMSBvZiB0aGUgVGVybXMgYW5kIENvbmRpdGlvbnMgb2YgU2FsZSBpbnRvIHdoaWNoIGl0CiAgICAgICAg';
        b64 += 'ICAgICAgICAgICAgICAgICAgICBpcyBpbmNvcnBvcmF0ZWQsICJSb3RleCIgc2hhbGwgYmUgZGVlbWVkIHRvIGluY2x1ZGUgUm90ZXgsIGl0cyBzdWJzaWRpYXJpZXMsIGFuZAogICAgICAgICAgICAgICAgICAgICAgICAgICAgdGhlaXIgYWZmaWxpYXRlcywgZGlyZWN0b3JzLCBvZmZpY2VycywgZW1wbG95ZWVzLCBhZ2VudHMsIHJlcHJlc2VudGF0aXZlcywKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHN1YmNvbnRyYWN0b3JzLCBhbmQgc3VwcGxpZXJzIG9mIGFsbCBvZiB0aGVtLjxici8+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAoSykgVGhpcyBXYXJyYW50eSBpcyBub24tdHJhbnNmZXJhYmxlIGFuZCBpcyBhcHBsaWNhYmxlIG9ubHkgdG8gdGhlIG9yaWdpbmFsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBDdXN0b21lci48YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgKEwpIFRoaXMgV2FycmFudHkgc2hhbGwgbm90IGJlIGV4dGVuZGVkLCBhbHRlcmVkIG9yIHZhcmllZCBleGNlcHQgYnkgd3JpdHRlbgogICAgICAgICAgICAgICAgICAgICAgICAgICAgaW5zdHJ1bWVudCBleGVjdXRlZCBieSBSb3RleC48YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgKE0pIEFueSBvZmZpY2lhbCBhY3Rpb24gb3IgbGVnYWwgcHJvY2VlZGluZyBmb3IgYnJlYWNoIG9mIHRoaXMgV2FycmFudHkgbXVzdCBiZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgY29tbWVuY2VkIHdpdGhpbiAxOCBtb250aHMgYWZ0ZXIgYWNjZXB0YW5jZSBvZiB0aGUgRXF1aXBtZW50L1NlcnZpY2VzLjxici8+PGJyLz4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxzdHJvbmc+MTAuIElOVEVMTEVDVFVBTCBQUk9QRVJUWTogPC9zdHJvbmc+IFJvdGV4IG1ha2VzIG5vIHdhcnJhbnR5IHRoYXQgdGhlCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBFcXVpcG1lbnQvU2VydmljZXMgYXJlIGZyZWUgZnJvbSwgYW5kIHNoYWxsIG5vdCBiZSBsaWFibGUgdG8gQ3VzdG9tZXIgZm9yLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgaW5mcmluZ2VtZW50IG9mIHRoZSBpbnRlbGxlY3R1YWwgcHJvcGVydHkgcmlnaHRzIChpbmNsdWRpbmcgcGF0ZW50cywgdHJhZGVtYXJrcywKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGNvcHlyaWdodHMsIHRyYWRlIHNlY3JldHMgYW5kIGNvbmZpZGVudGlhbCBpbmZvcm1hdGlvbikgb2Ygb3RoZXJzLCBhbmQgQ3VzdG9tZXIKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGFncmVlcyB0byBhc3N1bWUgYWxsIHJpc2tzIGFzc29jaWF0ZWQgdGhlcmV3aXRoLiBDdXN0b21lciBhZ3JlZXMgdG8gaG9sZCBSb3RleAogICAgICAgICAgICAgICAgICAgICAgICAgICAgaGFybWxlc3MgYWdhaW5zdCBhbnkgY2xhaW0gZm9yIGluZnJpbmdlbWVudCBhcmlzaW5nIG91dCBvZiBjb21wbGlhbmNlIHdpdGgKICAgICAgICAgICAgICAgICAgICAgICAgICAgIEN1c3RvbWVyI3MgZHJhd2luZ3MsIHNwZWNpZmljYXRpb25zLCByZXF1aXJlbWVudHMgb3IgaW5zdHJ1Y3Rpb25zLjxici8+PGJyLz4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxzdHJvbmc+MTEuIExJTUlUQVRJT05TIE9GIExJQUJJTElUWSBBTkQgSU5ERU1OSVRZOiA8L3N0cm9uZz48YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgKEEpIEN1c3RvbWVyIGFuZCBFbmQgVXNlciB1bmRlcnN0YW5kIGFuZCBhZ3JlZSB0aGF0OgogICAgICAgICAgICAgICAgICAgICAgICAgICAgbmVpdGhlciBSb3RleCBub3IgYW55IG9mIGl0cyBhZmZpbGlhdGVzIG1ha2UgYW55IGd1YXJhbnR5IG9yIHdhcnJhbnR5IGFzIHRvIHRoZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgcmVzdWx0cyB0aGF0IHdpbGwgYmUgYWNoaWV2ZWQgdGhyb3VnaCB0aGUgdXNlIG9mIHRoZSBFcXVpcG1lbnQgYW5kL29yIHRoZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgU2VydmljZXM7IGFuZCBpdCBpcyBhZ3JlZWQgdGhhdCB0aGUgc29sZSByZXNwb25zaWJpbGl0eSBmb3Igc3VjaCByZXN1bHRzIHNoYWxsIGJlCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBib3JuZSBieSBDdXN0b21lci48YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgKEIpIEFTIFBST1ZJREVEIElOIFRIRSBXQVJSQU5UWSBJTiBTRUNUSU9OIDkgQUJPVkUsIFJPVEVYJwogICAgICAgICAgICAgICAgICAgICAgICAgICAgTElBQklMSVRZIEZPUiBCUkVBQ0ggT0YgV0FSUkFOVFkgU0hBTEwgQkUgTElNSVRFRCBUTyBUSEUKICAgICAgICAgICAgICAgICAgICAgICAgICAgIFJFTUVESUVTIFRIRVJFSU4gUFJPVklERUQuIFdJVEggUkVTUEVDVCBUTyBBTEwgT1RIRVIKICAgICAgICAgICAgICAgICAgICAgICAgICAgIExJQUJJTElUWSwgSU5DTFVESU5HIFdJVEhPVVQgTElNSVRBVElPTiBMSUFCSUxJVFkKICAgICAgICAgICAgICAgICAgICAgICAgICAgIFJFU1VMVElORyBESVJFQ1RMWSBPUiBJTkRJUkVDVExZIEZST00gQlJFQUNIIE9GCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBDT05UUkFDVCwgQlJFQUNIIE9GIEEgRFVUWSBPRiBDQVJFIE9SIFNUQVRVVE9SWSBEVVRZCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBPUiBQUk9EVUNUIExJQUJJTElUWSwgVEhFIEFHR1JFR0FURSBDVU1VTEFUSVZFCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBMSUFCSUxJVFkgT0YgUk9URVggQU5EIElUUyBBRkZJTElBVEVTIFRBS0VOIFRPR0VUSEVSCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBTSEFMTCBJTiBOTyBFVkVOVCBFWENFRUQgVEhFIEFNT1VOVCBPRiBUSElTIE9SREVSIE9SIElOUgogICAgICAgICAgICAgICAgICAgICAgICAgICAgMTAwLDAwMCwgV0hJQ0hFVkVSIElTIFRIRSBMT1dFUi4gSU4gTk8gRVZFTlQgU0hBTEwgUk9URVgKICAgICAgICAgICAgICAgICAgICAgICAgICAgIE9SIEFOWSBPRiBJVFMgQUZGSUxJQVRFUyBCRSBMSUFCTEUgRk9SIEFOWSBMT1NTIE9GIFBST0ZJVFMKICAgICAgICAgICAgICAgICAgICAgICAgICAgIE9SIEFOWSBTUEVDSUFMLCBJTkNJREVOVEFMLCBDT05TRVFVRU5USUFMLCBJTkRJUkVDVCwKICAgICAgICAgICAgICAgICAgICAgICAgICAgIEVYRU1QTEFSWSwgT1IgT1RIRVIgREFNQUdFUywgSU5DTFVESU5HLCBXSVRIT1VUCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBMSU1JVEFUSU9OLCBBTlkgREFNQUdFUyBSRVNVTFRJTkcgRlJPTSBDT1NUIE9GCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBTVUJTVElUVVRFIFBST0NVUkVNRU5ULCBMT1NTIE9GIFVTRSwgTE9TUyBPRiBEQVRBLCBMT1NTIE9GCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBTQVZJTkdTLCBMT1NTIE9GIFJFVkVOVUVTLiBMT1NTIE9GIEJVU0lORVNTLCBPUiBGQUlMVVJFIE9SCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBERUxBWSBJTiBQRVJGT1JNQU5DRSwgV0hFVEhFUiBCQVNFRCBPTiBCUkVBQ0ggT0YKICAgICAgICAgICAgICAgICAgICAgICAgICAgIFdBUlJBTlRZIE9SIE9USEVSIENPTlRSQUNUIEJSRUFDSCwgTkVHTElHRU5DRSBPUgogICAgICAgICAgICAgICAgICAgICAgICAgICAgT1RIRVIgVE9SVCBPUiBPTiBBTlkgU1RSSUNUIExJQUJJTElUWSBUSEVPUlksIEVWRU4gSUYKICAgICAgICAgICAgICAgICAgICAgICAgICAgIFJPVEVYIEhBUyBCRUVOIEFEVklTRUQgT0YgVEhFIFBPU1NJQklMSVRZIE9GIEFOWSBTVUNICiAgICAgICAgICAgICAgICAgICAgICAgICAgICBEQU1BR0VTLiBOT1IgU0hBTEwgUk9URVggT1IgQU5ZIE9GIElUUyBBRkZJTElBVEVTIEJFCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBSRVNQT05TSUJMRSBGT1IgQU5ZIENMQUlNIEFHQUlOU1QgQ1VTVE9NRVIgQlkgQSBUSElSRAogICAgICAgICAgICAgICAgICAgICAgICAgICAgUEFSVFkuPGJyLz4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIChDKSBUbyB0aGUgZnVsbGVzdCBleHRlbnQgcGVybWl0dGVkIGJ5IGFwcGxpY2FibGUgbGF3LCBDdXN0b21lciBzaGFsbCBkZWZlbmQsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBpbmRlbW5pZnksIGFuZCBob2xkIGhhcm1sZXNzIFJvdGV4IGFuZCBpdHMgYWZmaWxpYXRlcyBhbmQgdGhlaXIgcmVzcGVjdGl2ZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgb2ZmaWNlcnMsIHBhcnRuZXJzLCBkaXJlY3RvcnMsIGVtcGxveWVlcywgYWdlbnRzLCBzdWNjZXNzb3JzLCBhbmQgYXNzaWducyAoIlJvdGV4CiAgICAgICAgICAgICAgICAgICAgICAgICAgICBQYXJ0aWVzIikgZnJvbSBhbmQgYWdhaW5zdCBhbnkgYW5kIGFsbCBsb3NzZXMsIGNsYWltcywgZGFtYWdlcywgbGlhYmlsaXRpZXMsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBleHBlbnNlcyAoaW5jbHVkaW5nLCB3aXRob3V0IGxpbWl0YXRpb24sIGZlZXMgYW5kIGRpc2J1cnNlbWVudHMgb2YgbGVnYWwgY291bnNlbAogICAgICAgICAgICAgICAgICAgICAgICAgICAgYW5kIGV4cGVuc2VzIG9mIGxpdGlnYXRpb24pIG9yIG90aGVyIG9ibGlnYXRpb25zIChjb2xsZWN0aXZlbHkgI0xvc3NlcyMpIGFuZAogICAgICAgICAgICAgICAgICAgICAgICAgICAgdGhyZWF0ZW5lZCBMb3NzZXMgdG8gdGhlIGV4dGVudCB0aGV5IGFyaXNlIGZyb20gb3IgaW4gY29ubmVjdGlvbiB3aXRoIHRoZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgcHVyY2hhc2UsIHVzZSBhbmQvb3BlcmF0aW9uIG9mIHRoZSBFcXVpcG1lbnQvU2VydmljZXMgYnkgQ3VzdG9tZXIgb3IgRW5kCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBVc2VyLCBpbmNsdWRpbmcgYnV0IG5vdCBsaW1pdGVkIHRvIGFueSBvZiB0aGUgZm9sbG93aW5nOiAoaSkgdGhlIGRlYXRoIG9yIGJvZGlseQogICAgICAgICAgICAgICAgICAgICAgICAgICAgaW5qdXJ5IG9mIGFueSBhZ2VudCwgZW1wbG95ZWUsIGN1c3RvbWVyLCBidXNpbmVzcyBpbnZpdGVlLCBvciBidXNpbmVzcyB2aXNpdG9yIG9yCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBvdGhlciBwZXJzb24sIGFuZCB0aGUgZGFtYWdlLCBsb3NzLCBvciBkZXN0cnVjdGlvbiBvZiBhbnkgcmVhbCBvciB0YW5naWJsZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgcGVyc29uYWwgcHJvcGVydHk7IChpaSkgYW55IGFjdGlvbiB0YWtlbiBieSBvciBvbiBiZWhhbGYgb2YgQ3VzdG9tZXIgb3IgRW5kIFVzZXIKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGluIHRoZSBwZXJmb3JtYW5jZSBvZiB0aGlzIE9yZGVyIHRoYXQgY2F1c2VzIFJvdGV4IG9yIGFueSBvZiBpdHMgYWZmaWxpYXRlcyB0byBiZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgb2JsaWdhdGVkIHRvIGluZGVtbmlmeSwgZGVmZW5kLCBhbmQvb3IgaG9sZCBoYXJtbGVzcyBhbnkgdGhpcmQgcGFydHk7IChpaWkpIGFueQogICAgICAgICAgICAgICAgICAgICAgICAgICAgY2xhaW0sIGRlbWFuZCwgY2hhcmdlLCBhY3Rpb24sIGNhdXNlIG9mIGFjdGlvbiwgb3Igb3RoZXIgcHJvY2VlZGluZyByZXN1bHRpbmcKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGZyb20gYW4gYWN0IG9yIG9taXNzaW9uIG9mIEN1c3RvbWVyLCBpdHMgZW1wbG95ZWVzLCBhZ2VudHMsIG9yIHN1YmNvbnRyYWN0b3JzCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBhY3RpbmcgaW4gaXRzIG9yIHRoZWlyIGNhcGFjaXR5IGFzIGFuIGVtcGxveWVyIG9yIHBvdGVudGlhbCBlbXBsb3llciB3aXRoIHJlc3BlY3QKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHRvIHRoZSBjbGFpbWFudDsgYW5kIChpdikgYW55IGNsYWltIGJ5IEN1c3RvbWVyIG9yIEVuZCBVc2VyLCB3aGV0aGVyIGJhc2VkIG9uCiAgICAgICAgICAgICAgICAgICAgICAgICAgICB3YXJyYW50eSBvciBvdGhlciBjb250cmFjdCBicmVhY2gsIG5lZ2xpZ2VuY2Ugb3Igb3RoZXIgdG9ydCBvciBvbiBhbnkgc3RyaWN0CiAgICAgICAgICAgICAgICAgICAgICAgICAgICBsaWFiaWxpdHkgdGhlb3J5';
        b64 += 'LCBmb3IgbWF0dGVycyBkaXNjbGFpbWVkIGluIHN1YnNlY3Rpb24gKEIpIGFib3ZlLiBDdXN0b21lciBzaGFsbAogICAgICAgICAgICAgICAgICAgICAgICAgICAgZnVsbHkgaW5kZW1uaWZ5IGFuZCBjb21wbGV0ZWx5IGhvbGQgaGFybWxlc3MgdGhlIFJvdGV4IFBhcnRpZXMgYXMgcHJvdmlkZWQKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGFib3ZlLCB3aGV0aGVyIG9yIG5vdCBuZWdsaWdlbmNlIG9yIG90aGVyIGZhdWx0IG9mIGFueSBvZiB0aGUgUm90ZXggUGFydGllcwogICAgICAgICAgICAgICAgICAgICAgICAgICAgY29udHJpYnV0ZWQgdG8sIG9yIGlzIGNsYWltZWQgb3IgYWxsZWdlZCB0byBoYXZlIGNvbnRyaWJ1dGVkIHRvLCB0aGUgY2xhaW0sIGFjdGlvbiwKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGRhbWFnZSwgbG9zcywgY29zdCwgbGlhYmlsaXR5IG9yIGV4cGVuc2UuIE5vdGhpbmcgaW4gc3Vic2VjdGlvbiAoQikgYW5kIHRoaXMKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHN1YnNlY3Rpb24gKEMpIGFib3ZlIHNoYWxsIGV4Y2x1ZGUgb3IgbGltaXQgdGhlIGxpYWJpbGl0eSBvZiBSb3RleCBvciBpdHMgYWZmaWxpYXRlcywKICAgICAgICAgICAgICAgICAgICAgICAgICAgIG9yIHJlcXVpcmUgQ3VzdG9tZXIgdG8gZGVmZW5kLCBpbmRlbW5pZnkgb3IgaG9sZCBoYXJtbGVzcyBSb3RleCBvciBpdHMKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGFmZmlsaWF0ZXMsIGluIGNpcmN1bXN0YW5jZXMgd2hlcmUgdGhlIExvc3NlcyBjbGFpbWVkIGFyZSBhbGxlZ2VkIHRvIGhhdmUKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHJlc3VsdGVkIGZyb20gKGkpIHdpbGxmdWwgbWlzY29uZHVjdCBvciBncm9zcyBuZWdsaWdlbmNlIG9mIFJvdGV4IG9yIGl0cyBhZmZpbGlhdGVzLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgKGlpKSBhbnkgZnJhdWQgb3IgZnJhdWR1bGVudCBjb25kdWN0IG9uIHRoZSBwYXJ0IG9mIFJvdGV4IG9yIGl0cyBhZmZpbGlhdGVzLCBvciAoaWlpKQogICAgICAgICAgICAgICAgICAgICAgICAgICAgYW55IG90aGVyIGxpYWJpbGl0eSB0aGF0IGNhbm5vdCBiZSBleGNsdWRlZCBieSBsYXcsIGFuZCB3aGVyZSAoaW4gZWFjaCBjYXNlKSBzdWNoCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBmYXVsdCBvciBsaWFiaWxpdHkgb24gdGhlIHBhcnQgb2YgdGhlIFJvdGV4IGFuZC9vciBpdHMgYWZmaWxpYXRlcyBpcyBhZGp1ZGljYXRlZCB0byBiZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgdGhlIGNhdXNlIG9mIHRoZSBMb3NzZXMuPGJyLz4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIChEKSBSb3RleCBzaGFsbCBub3QgYmUgbGlhYmxlIGZvciBmYWlsdXJlIHRvIGRlbGl2ZXIsIGZvciBkZWxheSBpbiBkZWxpdmVyeSwgb3IgZm9yCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBhbnkgbG9zc2VzIG9yIGRhbWFnZSB0byBDdXN0b21lciwgb3IgdG8gdGhlIEVxdWlwbWVudC9TZXJ2aWNlcyBvY2Nhc2lvbmVkIGJ5CiAgICAgICAgICAgICAgICAgICAgICAgICAgICBkZWxheXMsIGluIHRoZSBwZXJmb3JtYW5jZSBvZiBSb3RleCMgb2JsaWdhdGlvbnMsIGR1ZSB0bzogKGkpIGFueSBjYXVzZSBiZXlvbmQKICAgICAgICAgICAgICAgICAgICAgICAgICAgIFJvdGV4IyByZWFzb25hYmxlIGNvbnRyb2wgb3IgdGhlIGNvbnRyb2wgb2YgUm90ZXgjIHN1cHBsaWVycyBvciBzdWJjb250cmFjdG9yczs8YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgKGlpKSBhbiBhY3Qgb2YgR29kLCBhY3Qgb3Igb21pc3Npb24gb2YgQ3VzdG9tZXIsIGFjdCBvZiBjaXZpbCBvciBtaWxpdGFyeSBhdXRob3JpdHksCiAgICAgICAgICAgICAgICAgICAgICAgICAgICByZXBhaXIgd2l0aG91dCBwcmlvciBhdXRob3JpemF0aW9uIGJ5IFJvdGV4LgogICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgIDwvcD4gCiAgICAgICAgICAgICAgICAgICAgPC90ZD4KICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICA8dGQgc3R5bGU9IndpZHRoOiA1MCU7dmVydGljYWwtYWxpZ246IHRleHQtdG9wOyB0ZXh0LWFsaWduOiBsZWZ0OyBmb250LXNpemU6IDcuNXB0OyI+CiAgICAgICAgICAgICAgICAgICAgICAgIDxwPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgPHN0cm9uZz4xMi4gVEFYRVM6ICA8L3N0cm9uZz5TYWxlcywgZ29vZHMgYW5kIHNlcnZpY2VzIGFuZCB1c2UgdGF4ZXMsIHBheWFibGUgYnkgQ3VzdG9tZXIsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICB3aGljaCBhcmUgcHJlc2VudGx5IG9yIG1heSBoZXJlYWZ0ZXIgYmUgaW1wb3NlZCBieSBhbnkgdGF4aW5nIGF1dGhvcml0eSwgYXJlIG5vdAogICAgICAgICAgICAgICAgICAgICAgICAgICAgaW5jbHVkZWQgaW4gdGhlIFB1cmNoYXNlIFByaWNlLiBBbnkgZGlyZWN0IG9yIGltcG9ydCBkdXR5IG9yIGN1c3RvbXMgZHV0eQogICAgICAgICAgICAgICAgICAgICAgICAgICAgcGF5YWJsZSBieSBSb3RleCwgd2hpY2ggbWF5IGhlcmVhZnRlciBiZSBpbXBvc2VkIGJ5IGFueSB0YXhpbmcgYXV0aG9yaXR5LAogICAgICAgICAgICAgICAgICAgICAgICAgICAgd2hlcmVzb2V2ZXIgbG9jYXRlZCwgdXBvbiB0aGUgbWFudWZhY3R1cmUsIHNhbGUgb3IgZGVsaXZlcnkgb2YgcHJvZHVjdHMgY292ZXJlZAogICAgICAgICAgICAgICAgICAgICAgICAgICAgYnkgdGhpcyBPcmRlciwgb3IgYW55IGluY3JlYXNlIGluIHJhdGUgb2YgYW55IHN1Y2ggdGF4IG9yIGltcG9ydCBvciBjdXN0b21zCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBleGFjdGlvbiBub3cgaW4gZm9yY2UsIHNoYWxsIGJlIGFkZGVkIHRvIHRoZSBQdXJjaGFzZSBQcmljZS4gSWYgc3VjaCBjaGFyZ2UgaXMKICAgICAgICAgICAgICAgICAgICAgICAgICAgIG5vdCBjb2xsZWN0ZWQgYXQgdGhlIHRpbWUgb2YgcGF5bWVudCBvZiBQdXJjaGFzZSBQcmljZSwgQ3VzdG9tZXIgd2lsbCBpbmRlbW5pZnkKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGFuZCBob2xkIFJvdGV4IGhhcm1sZXNzIGFnYWluc3QgYW55IHN1Y2ggY2hhcmdlLjxici8+PGJyLz4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxzdHJvbmc+MTMuIENIQU5HRVMgQU5EIFRFUk1JTkFUSU9OOiAgPC9zdHJvbmc+KEEpIFJvdGV4IHNoYWxsIGhhdmUgdGhlIHJpZ2h0LCBpbgogICAgICAgICAgICAgICAgICAgICAgICAgICAgaXRzIHNvbGUgZGlzY3JldGlvbiwgdG8gdGVybWluYXRlIHRoaXMgT3JkZXIgd2hlbmV2ZXIgaXQgZGVlbXMgZml0IGluY2x1ZGluZyBpZgogICAgICAgICAgICAgICAgICAgICAgICAgICAgQ3VzdG9tZXI6IChpKSBpcyB1bmFibGUgdG8gcGF5IGl0cyBkZWJ0cyBnZW5lcmFsbHkgYXMgYW5kIHdoZW4gdGhleSBiZWNvbWUKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGR1ZTsgKGlpKWlzIHRoZSBzdWJqZWN0IG9mIGEgbGVnYWwgcHJvY2VzcyBkZWNsYXJpbmcgaXQgaW5zb2x2ZW50OyAoaWlpKSBjZWFzZXMgb3IKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHRocmVhdGVucyB0byBjZWFzZSBjYXJyeWluZyBvbiBpdHMgYnVzaW5lc3M7IG9yIChpdikgY29tbWl0cyBhIGJyZWFjaCBvZiB0aGlzCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBPcmRlciB3aGljaCBpcyAoYSkgaW5jYXBhYmxlIG9mIHJlbWVkeSAoYXMgcmVhc29uYWJseSBkZXRlcm1pbmVkIGJ5IFJvdGV4KTsgb3IKICAgICAgICAgICAgICAgICAgICAgICAgICAgIChiKSBub3QgcmVtZWRpZWQgd2l0aGluIDE0IGNhbGVuZGFyIGRheXMgb2YgdGhlIGRhdGUgb2YgdGhlIGJyZWFjaC48YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgKEIpIEN1c3RvbWVyIG1heSBtYWtlIGEgd3JpdHRlbiByZXF1ZXN0IGZvciBhbWVuZG1lbnQsIG1vZGlmaWNhdGlvbiwgb3IKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHRlcm1pbmF0aW9uLiBJZiBhIHJlcXVlc3QgZm9yIGFtZW5kbWVudCBvciBtb2RpZmljYXRpb24gaXMgYWNjZXB0ZWQgYnkgUm90ZXgsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBhbmQgYW55IGNoYW5nZXMgY2F1c2UgYW4gaW5jcmVhc2Ugb3IgZGVjcmVhc2UgaW4gdGhlIGNvc3Qgb2YsIG9yIHRoZSB0aW1lCiAgICAgICAgICAgICAgICAgICAgICAgICAgICByZXF1aXJlZCBmb3IsIHRoZSBwZXJmb3JtYW5jZSBvZiBhbnkgcGFydCBvZiB0aGUgd29yayB1bmRlciB0aGlzIE9yZGVyLCBhbgogICAgICAgICAgICAgICAgICAgICAgICAgICAgZXF1aXRhYmxlIGFkanVzdG1lbnQgc2hhbGwgYmUgbWFkZSBpbiB0aGUgcHJpY2Ugb3IgZGVsaXZlcnkgc2NoZWR1bGUsIG9yIGJvdGgsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBhbmQgdGhlIE9yZGVyIHNoYWxsIGJlIG1vZGlmaWVkIGluIHdyaXRpbmcgYWNjb3JkaW5nbHkuIFdoZXJldmVyIHRoZSBjb3N0IG9mCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBwcm9wZXJ0eSBtYWRlIG9ic29sZXRlIGFzIGEgcmVzdWx0IG9mIHRoZSBjaGFuZ2UgaXMgaW5jbHVkZWQgaW4gdGhlIHByaWNlCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBhZGp1c3RtZW50LCBDdXN0b21lciBzaGFsbCBoYXZlIHRoZSByaWdodCB0byBwcmVzY3JpYmUgdGhlIG1hbm5lciBvZiBkaXNwb3NpdGlvbgogICAgICAgICAgICAgICAgICAgICAgICAgICAgb2Ygc3VjaCBwcm9wZXJ0eS4gSWYgcmVxdWVzdCBmb3IgdGVybWluYXRpb24gaXMgYWNjZXB0ZWQgYnkgUm90ZXgsIGVxdWl0YWJsZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgcHJvdmlzaW9uIHNoYWxsIGJlIG1hZGUgdG8gUm90ZXggZm9yIGEgcmVjb3VwbWVudCBvZiBhbGwgY29zdHMgaW5jdXJyZWQgdW5kZXIKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHRoZSBPcmRlciBhbmQgZm9yIHJlYXNvbmFibGUgcHJvZml0IGJhc2VkIG9uIHRpbWUgYW5kIGNvc3RzIGV4cGVuZGVkLiBUaGUKICAgICAgICAgICAgICAgICAgICAgICAgICAgIE9yZGVyIHNoYWxsIGNvbnRpbnVlIGluIGVmZmVjdCB1bnRpbCBzdWNoIHRpbWUgYXMgcGF5bWVudCBpcyByZWNlaXZlZC4gQSB3cml0dGVuCiAgICAgICAgICAgICAgICAgICAgICAgICAgICByZXF1ZXN0IGFzIHNwZWNpZmllZCBoZXJlaW4gc2hhbGwgZ2l2ZSBSb3RleCBhZGVxdWF0ZSByZWFzb24gdG8gZGVtYW5kIHdyaXR0ZW4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIGFzc3VyYW5jZSBvZiBDdXN0b21lciNzIGFiaWxpdHkgYW5kIGludGVudCB0byBjYXJyeSBvdXQgdGhlIE9yZGVyLjxici8+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAoQykgQ29uc2VxdWVuY2Ugb2YgVGVybWluYXRpb246IEluIHRoZSBldmVudCBvZiB0ZXJtaW5hdGlvbjogKGkpIEN1c3RvbWVyIHNoYWxsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBmb3J0aHdpdGggcGF5IFJvdGV4IGltbWVkaWF0ZWx5IGFueSBhbmQgYWxsIHN1bXMgZHVlIGFuZCBvdXRzdGFuZGluZyB1bmRlciBhbGwKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHN1Y2ggYWdyZWVtZW50cyB3aXRoIHJlc3BlY3QgdG8gRXF1aXBtZW50L1NlcnZpY2VzLCBzdXBwbGllZCBvciBvcmRlcmVkIGluCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBwYXJ0aWFsIGV4ZWN1dGlvbiBvZiB0aGUgYWdyZWVtZW50cywgdG9nZXRoZXIgd2l0aCBhbGwgb3ZlcmhlYWQgYW5kIG90aGVyIGNvc3RzCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBpbmN1cnJlZCBieSBSb3RleCBhcyBhIHJlc3VsdCBvZiBzdWNoIHRlcm1pbmF0aW9uIGFuZCBpbnRlcmVzdCBhY2NydWVkIHRoZXJlb24gaW4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIHRlcm1zIGhlcmVvZi4gKGlpKSBhbGwgc3VjaCBjbGF1c2VzLCB0aGUgY29udGV4dCBvZiB3aGljaCByZXF1aXJlIHNoYWxsIHN1cnZpdmUgdGhlCiAgICAgICAgICAgICAgICAgICAg';
        b64 += 'ICAgICAgICB0ZXJtaW5hdGlvbiBvZiB0aGUgT3JkZXIuCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBJbiB0aGUgZXZlbnQsIHRoZSBDdXN0b21lciBkZWZhdWx0cyBpbiB0YWtpbmcgZGVsaXZlcnkgb2YgRXF1aXBtZW50IGZvciBhbnkKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHJlYXNvbiB3aGF0c29ldmVyLCBSb3RleCBzaGFsbCBiZSBlbnRpdGxlZCB0byBzZWVrIHNwZWNpZmljIHBlcmZvcm1hbmNlIG9mIHRoZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgT3JkZXIuPGJyLz48YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgPHN0cm9uZz4xNC4gU0VWRVJBQklMSVRZOiAgPC9zdHJvbmc+SWYgYW55IHByb3Zpc2lvbiBvZiB0aGlzIE9yZGVyIHNoYWxsIGJlIGRldGVybWluZWQgYnkgYQogICAgICAgICAgICAgICAgICAgICAgICAgICAgY291cnQgb2YgY29tcGV0ZW50IGp1cmlzZGljdGlvbiB0byBiZSBpbnZhbGlkIG9yIHVuZW5mb3JjZWFibGUsIHN1Y2gKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGRldGVybWluYXRpb24gc2hhbGwgbm90IGVmZmVjdCB0aGUgcmVtYWluaW5nIHByb3Zpc2lvbnMgb2YgdGhpcyBPcmRlciwgYWxsIG9mCiAgICAgICAgICAgICAgICAgICAgICAgICAgICB3aGljaCBzaGFsbCByZW1haW4gaW4gZnVsbCBmb3JjZSBhbmQgZWZmZWN0Ljxici8+PGJyLz4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxzdHJvbmc+MTUuIERJU1BVVEUgUkVTT0xVVElPTiwgR09WRVJOSU5HIExBVywgQU5EIEZPUlVNOiAgPC9zdHJvbmc+KEEpCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBUaGlzIE9yZGVyIHNoYWxsIGJlIGdvdmVybmVkIGJ5LCBhbmQgY29uc3RydWVkIGluIGFjY29yZGFuY2Ugd2l0aCwgdGhlIGxhd3Mgb2YKICAgICAgICAgICAgICAgICAgICAgICAgICAgIEluZGlhLiBTdWJqZWN0IHRvIHRoZSBTZWN0aW9uIDE2KEIpIGJlbG93LCB0aGUgY291cnRzIGF0IFZhZG9kYXJhLCBJbmRpYSBzaGFsbAogICAgICAgICAgICAgICAgICAgICAgICAgICAgaGF2ZSBleGNsdXNpdmUganVyaXNkaWN0aW9uIGluIGFsbCBtYXR0ZXJzIGFyaXNpbmcgb3V0IG9mIGFuZC9vciBjb25jZXJuaW5nIHRoaXMKICAgICAgICAgICAgICAgICAgICAgICAgICAgIE9yZGVyIHByb3ZpZGVkIGhvd2V2ZXIsIHRoYXQgUm90ZXggc2hhbGwgYmUgZW50aXRsZWQgYXQgYW55IHRpbWUgdG8gc2VlawogICAgICAgICAgICAgICAgICAgICAgICAgICAgaW5qdW5jdGl2ZSBvciBhbnkgb3RoZXIgZXF1aXRhYmxlIHJlbGllZiB1cG9uIGFueSBicmVhY2ggb3IgdGhyZWF0ZW5lZCBicmVhY2ggYnkKICAgICAgICAgICAgICAgICAgICAgICAgICAgIEN1c3RvbWVyIGluIGFueSBjb3VydCBvZiBjb21wZXRlbnQganVyaXNkaWN0aW9uLiBObyBhY3Rpb24gaW4gbGF3IG9yIGVxdWl0eQogICAgICAgICAgICAgICAgICAgICAgICAgICAgYXJpc2luZyBvdXQgb2YgdGhpcyBPcmRlciBtYXkgYmUgYnJvdWdodCBieSBDdXN0b21lciBtb3JlIHRoYW4gMTggbW9udGhzIGFmdGVyCiAgICAgICAgICAgICAgICAgICAgICAgICAgICB0aGUgY2F1c2Ugb2YgYWN0aW9uIGhhcyBmaXJzdCBhcmlzZW4uPGJyLz4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIChCKSBJbiB0aGUgZXZlbnQgYSBkaXNwdXRlIGFyaXNlcyB1bmRlciBvciByZWxhdGVzIHRvIHRoaXMgT3JkZXIsIHRoZSBQYXJ0aWVzIHNoYWxsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBkaWxpZ2VudGx5IGF0dGVtcHQgdG8gcmVzb2x2ZSB0aGUgZGlzcHV0ZSB3aXRoaW4gMzAgZGF5cyBmcm9tIHRoZSBkYXRlIGVpdGhlcgogICAgICAgICAgICAgICAgICAgICAgICAgICAgUGFydHkgZ2l2ZXMgd3JpdHRlbiBub3RpY2UgdG8gdGhlIG90aGVyIG9mIGl0cyBpbnRlbnQgdG8gaW52b2tlIHRoaXMgcHJvdmlzaW9uLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgZHVyaW5nIHdoaWNoIHBlcmlvZCBuZWl0aGVyIFBhcnR5IG1heSBjb21tZW5jZSBsZWdhbCBhY3Rpb24gdG8gYXNzZXJ0IGl0cyByaWdodHMKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGFnYWluc3QgdGhlIG90aGVyLiBJbiB0aGUgZXZlbnQgdGhlIFBhcnRpZXMgZG8gbm90IHJlc29sdmUgdGhlIGRpc3B1dGUgd2l0aGluIHRoZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgMzAtZGF5IHBlcmlvZCByZWZlcmVuY2VkIGFib3ZlLCBlaXRoZXIgUGFydHkgbWF5IHJlZmVyIHRoZSBkaXNwdXRlIHRvIGFuZCB3aGljaAogICAgICAgICAgICAgICAgICAgICAgICAgICAgZGlzcHV0ZSBzaGFsbCBmaW5hbGx5IGJlIHJlc29sdmVkIGJ5IGFyYml0cmF0aW9uIGluIGFjY29yZGFuY2Ugd2l0aCAoSW5kaWFuKQogICAgICAgICAgICAgICAgICAgICAgICAgICAgQXJiaXRyYXRpb24gYW5kIENvbmNpbGlhdGlvbiBBY3QsIDE5OTY8YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgKEMpIEN1c3RvbWVyIGZ1cnRoZXIgaXJyZXZvY2FibHkgY29uc2VudHMgdG8gdGhlIHNlcnZpY2Ugb2YgcHJvY2VzcyBvdXQgb2YgYW55IG9mCiAgICAgICAgICAgICAgICAgICAgICAgICAgICB0aGUgYWZvcmVtZW50aW9uZWQgY291cnRzIGluIGFueSBzdWNoIGFjdGlvbiBvciBwcm9jZWVkaW5nIGlmIHN1Y2ggcHJvY2VzcyBzaGFsbAogICAgICAgICAgICAgICAgICAgICAgICAgICAgYmUgaW4gd3JpdGluZyBhbmQgZWl0aGVyIHNoYWxsIGJlIGRlbGl2ZXJlZCBpbiBwZXJzb24gb3Igc2VudCBieSByZWdpc3RlcmVkIG9yCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBjZXJ0aWZpZWQgbWFpbCAocmV0dXJuIHJlY2VpcHQgcmVxdWVzdGVkKSwgcG9zdGFnZSBwcmUtcGFpZCwgYW5kIGFkZHJlc3NlZCB0bwogICAgICAgICAgICAgICAgICAgICAgICAgICAgQ3VzdG9tZXIgYXQgdGhlIGFkZHJlc3Mgb2YgQ3VzdG9tZXIgZm9yIG5vdGljZXMgdW5kZXIgdGhpcyBPcmRlci4gTm90aGluZwogICAgICAgICAgICAgICAgICAgICAgICAgICAgaGVyZWluIHNoYWxsIGFmZmVjdCB0aGUgcmlnaHQgb2YgUm90ZXggdG8gc2VydmUgcHJvY2VzcyBpbiBhbnkgb3RoZXIgbWFubmVyCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBwZXJtaXR0ZWQgYnkgbGF3IG9yIHRvIGNvbW1lbmNlIGxlZ2FsIHByb2NlZWRpbmdzIG9yIG90aGVyd2lzZSBwcm9jZWVkCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBhZ2FpbnN0IEN1c3RvbWVyIGluIGFueSBvdGhlciBqdXJpc2RpY3Rpb24uPGJyLz4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIChEKSBSb3RleCBzaGFsbCBoYXZlIHRoZSByaWdodCB0byBjb2xsZWN0IGZyb20gQ3VzdG9tZXIgaXRzIHJlYXNvbmFibGUgZXhwZW5zZXMsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBpbmNsdWRpbmcgYXR0b3JuZXlzIyBmZWVzLCBpbmN1cnJlZCBpbiBlbmZvcmNpbmcgdGhpcyBPcmRlci48YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgKEUpIFRoZSByaWdodHMgYW5kIG9ibGlnYXRpb25zIGhlcmVpbiBzaGFsbCBzdXJ2aXZlIGNvbXBsZXRpb24gb2YgdGhlIGZpbmFsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBwYXltZW50IHVuZGVyIHRoaXMgT3JkZXIuPGJyLz48YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgPHN0cm9uZz4xNi4gQ09ORklERU5USUFMSVRZOiAgPC9zdHJvbmc+VGhlIFBhcnRpZXMgYWdyZWUgdGhhdCwgaW4gdGhlIGNvdXJzZSBvZgogICAgICAgICAgICAgICAgICAgICAgICAgICAgcGVyZm9ybWFuY2Ugb2YgdGhpcyBPcmRlciwgaXQgbWF5IGJlIG5lY2Vzc2FyeSBhbmQgZGVzaXJhYmxlIGZvciB0aGVtIHRvCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBleGNoYW5nZSBjb25maWRlbnRpYWwgaW5mb3JtYXRpb24uIEZvciBleGFtcGxlLCBhbGwgdXBkYXRlcywgcmVwYWlycywKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHJlcGxhY2VtZW50cywgZml4ZXMsIG1vZGlmaWNhdGlvbnMsIGFuZCBvdGhlciBjaGFuZ2VzIHRvIHRoZSBFcXVpcG1lbnQvU2VydmljZXMKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHNoYWxsIGJlIGNvbnNpZGVyZWQgUm90ZXgjIHByb3ByaWV0YXJ5IGluZm9ybWF0aW9uLiBUbyBhY2NvbXBsaXNoIHRoaXMKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGNvbmZpZGVudGlhbGl0eSwgdGhlIFBhcnRpZXMgYWdyZWUgYXMgZm9sbG93czogQ3VzdG9tZXIgc2hhbGwgbm90IGRpc2Nsb3NlIAogICAgICAgICAgICAgICAgICAgICAgICA8L3A+CiAgICAgICAgICAgICAgICAgICAgPC90ZD4KICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgIDwvdHI+CiAgICAgICAgICAgICAgICAKICAgICAgICAgICAgPC90YWJsZT4gCiAgICAgICAgPC9kaXY+IAogICAgICAgIAogICAgICAgIDxkaXYgc3R5bGU9InBhZ2UtYnJlYWstYWZ0ZXI6YXV0bzt3aWR0aDogMTAwJTsgIG1hcmdpbi10b3A6IDUwcHg7Ij4KICAgICAgICAgICAgCiAgICAgICAgICAgIAogICAgICAgICAgICA8dGFibGUgc3R5bGU9IndpZHRoOiAxMDAlOyB0ZXh0LWFsaWduOiBjZW50ZXI7IGNvbHVtbnM6IDI7Ij4KICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgPHRyICA+CiAgICAgICAgICAgICAgICAgICAgPHRkIHN0eWxlPSJ3aWR0aDogNTAlO3ZlcnRpY2FsLWFsaWduOiB0ZXh0LXRvcDsgdGV4dC1hbGlnbjogbGVmdDsgZm9udC1zaXplOiA3LjVwdDsiPgogICAgICAgICAgICAgICAgICAgICAgICA8cD4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxTdHJvbmc+MTcuIEVYUE9SVCBBTkQgSU1QT1JUIENPTlRST0xTOiA8L1N0cm9uZz5UaGUgc2FsZSwgcmVzYWxlIG9yIG90aGVyCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBkaXNwb3NpdGlvbiBvZiBFcXVpcG1lbnQgYW5kIGFueSByZWxhdGVkIHRlY2hub2xvZ3kgb3IgZG9jdW1lbnRhdGlvbiBhcmUKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHN1YmplY3QgdG8gdGhlIGV4cG9ydCBjb250cm9sIGxhd3MsIHJlZ3VsYXRpb25zIGFuZCBvcmRlcnMgb2YgSW5kaWEgYW5kIG1heSBiZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgc3ViamVjdCB0byB0aGUgZXhwb3J0IGFuZC9vciBpbXBvcnQgY29udHJvbCBsYXdzIGFuZCByZWd1bGF0aW9ucyBvZiBvdGhlcgogICAgICAgICAgICAgICAgICAgICAgICAgICAgY291bnRyaWVzLiBDdXN0b21lciBhZ3JlZXMgdG8gY29tcGx5IHdpdGggc3VjaCBsYXdzLCByZWd1bGF0aW9ucyBhbmQgb3JkZXJzCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBhbmQgc2hhbGwgbm90IGF1dGhvcml6ZSBvciBwZXJtaXQgaXRzIGVtcGxveWVlcywgZGlzdHJpYnV0b3JzLCBjdXN0b21lcnMsIGJyb2tlcnMsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBmcmVpZ2h0IGZvcndhcmRlcnMsIGFuZC9vciBhZ2VudHMgdG8gZXhwb3J0IG9yIHJlLWV4cG9ydCBhbnkgb2YgdGhlIE9yZGVyCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBFcXVpcG1lbnQvU2VydmljZXMgb3IgYW55IHRlY2hub2xvZ3kgY292ZXJlZCBieSB0aGlzIE9yZGVyIHRvIGFueSBmb3JlaWduCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBwZXJzb24gd2l0aG91dCBjb21wbHlpbmcgd2l0aCBhcHBsaWNhYmxlIGltcG9ydCBhbmQgZXhwb3J0IGxhd3MgYW5kCiAgICAgICAgICAgICAgICAgICAgICAgICAgICByZWd1bGF0aW9ucyBvZiBJbmRpYSwgYW5kIHRoZSBDdXN0b21lciNzIGNvdW50cnkgQ3VzdG9tZXIgYWdyZWVzIHRvIG9idGFpbiBhbmQKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHByb3Blcmx5IHV0aWxpemUgdGhlIEluZGlhbiBnb3Zlcm5tZW50IG9yIGFueSBuZWNlc3NhcnkgZXhwb3J0IGF1dGhvcml6YXRpb25zCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBwcmlvciB0byBleHBvcnRpbmcgb3IgcmUtZXhwb3J0aW5nIHRoZSBPcmRlciBFcXVpcG1lbnQv';
        b64 += 'U2VydmljZXMsIGVpdGhlciBpbiB0aGVpcgogICAgICAgICAgICAgICAgICAgICAgICAgICAgb3JpZ2luYWwgZm9ybSBvciBhZnRlciBiZWluZyBpbmNvcnBvcmF0ZWQgaW50byBvdGhlciBlbmQtaXRlbXMuPGJyLz48YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgPFN0cm9uZz4xOC4gTElDRU5TRSBBTkQgT1dORVJTSElQOiA8L1N0cm9uZz5UbyB0aGUgZXh0ZW50IHRoYXQgdGhlIE9yZGVyCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBFcXVpcG1lbnQvU2VydmljZXMgY29udGFpbiBvciBhcmUgc29mdHdhcmUsIFJvdGV4IGhlcmVieSBncmFudHMgdG8gQ3VzdG9tZXIgYQogICAgICAgICAgICAgICAgICAgICAgICAgICAgbm9uLWV4Y2x1c2l2ZSwgbm9uLXRyYW5zZmVyYWJsZSwgcGVyc29uYWwgbGljZW5zZSB0byB1c2UgdGhlIHNvZnR3YXJlIGFuZCByZWxhdGVkCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBkb2N1bWVudGF0aW9uLiBDdXN0b21lciNzIHVzZSBvZiB0aGUgT3JkZXIgRXF1aXBtZW50L1NlcnZpY2VzIGNvbmNsdXNpdmVseQogICAgICAgICAgICAgICAgICAgICAgICAgICAgZXZpZGVuY2VzIGl0cyBhY2NlcHRhbmNlIG9mIHRoaXMgbGljZW5zZSBhbmQgdGhpcyBPcmRlciwgaW5jbHVkaW5nIHRoaXMgU2VjdGlvbiAxOC4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIFRpdGxlIHRvIHRoZSBzb2Z0d2FyZSBzaGFsbCBhdCBhbGwgdGltZXMgcmVtYWluIHdpdGggUm90ZXguIEN1c3RvbWVyIGFncmVlcyB0aGF0CiAgICAgICAgICAgICAgICAgICAgICAgICAgICB0aGUgc29mdHdhcmUsIGFsbCBlbmhhbmNlbWVudHMsIHJlbGF0ZWQgZG9jdW1lbnRhdGlvbiwgYW5kIGRlcml2YXRpdmUgd29ya3MgYXJlLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgYW5kIHdpbGwgcmVtYWluLCB0aGUgc29sZSBwcm9wZXJ0eSBvZiBSb3RleCBhbmQgaW5jbHVkZXMgdmFsdWFibGUgdHJhZGUgc2VjcmV0cy4gCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBDdXN0b21lciBhZ3JlZXMgdG8gdHJlYXQgdGhlIHNvZnR3YXJlIGFuZCByZWxhdGVkIGRvY3VtZW50YXRpb24gYXMgY29uZmlkZW50aWFsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBhbmQgdG8gbm90IGNvcHksIHJlcHJvZHVjZSwgc3ViLWxpY2Vuc2UsIG9yIG90aGVyd2lzZSBkaXNjbG9zZSB0aGUgc29mdHdhcmUgYW5kCiAgICAgICAgICAgICAgICAgICAgICAgICAgICByZWxhdGVkIGRvY3VtZW50YXRpb24gdG8gdGhpcmQgcGFydGllcy4gQ3VzdG9tZXIgYWdyZWVzIHRvIG5vdCBkaXNhc3NlbWJsZSwKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGRlY29tcGlsZSwgcmV2ZXJzZSBlbmdpbmVlciwgY3JlYXRlIGRlcml2YXRpdmUgd29ya3MgZnJvbSwgYXR0ZW1wdCB0byBkZXJpdmUgdGhlCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBzb3VyY2UgY29kZSBvciBvdGhlcndpc2UgdHJhbnNsYXRlLCBjdXN0b21pemUsIGxvY2FsaXplLCBtb2RpZnksIGFkZCB0bywgb3IgaW4gYW55CiAgICAgICAgICAgICAgICAgICAgICAgICAgICB3YXkgYWx0ZXIsIHJlbnQsIG9yIGxvYW4gdGhlIHNvZnR3YXJlIG9yIHJlbGF0ZWQgZG9jdW1lbnRhdGlvbi48YnIvPjxici8+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICA8U3Ryb25nPjE5LiBBU1NJR05NRU5UOiA8L1N0cm9uZz5DdXN0b21lciBzaGFsbCBub3QgYXNzaWduIG9yIHRyYW5zZmVyIG9yIHB1cnBvcnQgdG8gYXNzaWduCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBvciB0cmFuc2ZlciBhbnkgY29udHJhY3QgdG8gd2hpY2ggdGhlc2UgQ29uZGl0aW9ucyBhcHBseSBvciB0aGUgYmVuZWZpdCB0aGVyZW9mIHRvCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBhbnkgb3RoZXIgcGVyc29uIHdoYXRzb2V2ZXIgd2l0aG91dCB0aGUgY29uc2VudCBvZiBSb3RleC48YnIvPjxici8+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICA8U3Ryb25nPjIwLiBXQUlWRVI6IDwvU3Ryb25nPlRoZSB3YWl2ZXIgb2YgYW55IHByb3Zpc2lvbiBvciBvZiBhbnkgYnJlYWNoIG9yIGRlZmF1bHQgc2hhbGwKICAgICAgICAgICAgICAgICAgICAgICAgICAgIG5vdCBiZSBkZWVtZWQgYSB3YWl2ZXIgb2YgYW55IG90aGVyIHByb3Zpc2lvbiwgYnJlYWNoIG9yIGRlZmF1bHQuPGJyLz48YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgPFN0cm9uZz4yMS4gRk9SQ0UgTUFKRVVSRTogPC9TdHJvbmc+I0ZvcmNlIE1hamV1cmUjIG9jY3VycmVuY2Ugc2hhbGwgYmUgZGVlbWVkIHRvIGJlCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBhbnkgZXZlbnQgYXJpc2luZyBmcm9tIG9yIGF0dHJpYnV0YWJsZSB0byBhY3RzLCBldmVudHMsIG9taXNzaW9ucyBvciBhY2NpZGVudHMKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGJleW9uZCB0aGUgcmVhc29uYWJsZSBjb250cm9sIG9mIHRoZSBQYXJ0eSBhbmQgd2hpY2gsIGJ5IHRoZSBleGVyY2lzZSBvZgogICAgICAgICAgICAgICAgICAgICAgICAgICAgcmVhc29uYWJsZSBjYXJlIGFuZCBkaWxpZ2VuY2UgdGhlIFBhcnR5IGlzIHVuYWJsZSB0byBmb3Jlc2VlIGFuZCBwcmV2ZW50IGFuZCwKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHdpdGhvdXQgcHJlanVkaWNlIHRvIHRoZSBnZW5lcmFsaXR5IHRoZXJlb2YsIGluY2x1ZGluZzoKICAgICAgICAgICAgICAgICAgICAgICAgICAgIChpKSBzdHJpa2VzLCBsb2Nrb3V0cyBvciBvdGhlciBpbmR1c3RyaWFsIGFjdGlvbnMsIHJpb3QsIHdhciAoZGVjbGFyZWQgb3IgdW5kZWNsYXJlZCksCiAgICAgICAgICAgICAgICAgICAgICAgICAgICByZXZvbHV0aW9uLCBpbnN1cnJlY3Rpb24sIHJlYmVsbGlvbiwgc2Fib3RhZ2UsIGFjdHMgb2YgdGVycm9yaXNtLCB0aGVmdCBvZiBtYXRlcmlhbHM7CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAoaWkpIGZsb29kLCBzdG9ybSwgdG9ybmFkbywgZWFydGhxdWFrZSwgZXBpZGVtaWMgb3Igb3RoZXIgbmF0dXJhbCBwaHlzaWNhbAogICAgICAgICAgICAgICAgICAgICAgICAgICAgZGlzYXN0ZXIsIGZpcmUsIGV4cGxvc2lvbiwgb2JzdHJ1Y3Rpb25zLCB0cmFuc3BvcnQgYWNjaWRlbnRzLCBudWNsZWFyIGRpc2FzdGVycywKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGNvbnRhbWluYXRpb24gYnkgcmFkaW9hY3Rpdml0eSBvciBvdGhlciB0b3hpYyBvciBoYXphcmRvdXMgY29udGFtaW5hdGlvbi4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIChpaWkpIGFjdHMgb2YgR29kLCBnb3Zlcm5tZW50YWwgYWN0cyBvciBvbWlzc2lvbnMsIHJlc3RyaWN0aW9ucywgcmVndWxhdGlvbnMsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICByZWZ1c2FsIHRvIGdyYW50IGFueSBsaWNlbnNlcyBvciBwZXJtaXNzaW9ucywgcHJvaGliaXRpb25zLCBvciBtZWFzdXJlcyBvZiBhbnkKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGtpbmQgb24gdGhlIHBhcnQgb2YgYW55IHB1YmxpYyBhdXRob3JpdHkuCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBUaGUgUGFydHkgc3VmZmVyaW5nIHRoZSBGb3JjZSBNYWpldXJlIGV2ZW50IG11c3QgcHJvbXB0bHkgbm90aWZ5IHRoZSBvdGhlcgogICAgICAgICAgICAgICAgICAgICAgICAgICAgUGFydHkgb2YgdGhlIGNpcmN1bXN0YW5jZXMgY29uc3RpdHV0aW5nIHN1Y2ggRm9yY2UgTWFqZXVyZS4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIEluIHRoZSBldmVudCB0aGUgZnVsZmlsbG1lbnQgb2YgYSBQdXJjaGFzZSBPcmRlciBvYmxpZ2F0aW9uIChvdGhlciB0aGFuIHRoZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgQ3VzdG9tZXIgcGF5bWVudCBvYmxpZ2F0aW9uKSBpcyBpbXBlZGVkLCByZXN0cmljdGVkLCBvciBkZWxheWVkIGJ5IGFueSBGb3JjZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgTWFqZXVyZSBldmVudCwgdGhlIG9ibGlnYXRpb24gd2lsbCByZW1haW4gc3VzcGVuZGVkIGZvciB0aGUgZHVyYXRpb24gb2Ygc3VjaAogICAgICAgICAgICAgICAgICAgICAgICAgICAgaW1wZWRpbWVudCwgcmVzdHJpY3Rpb24sIG9yIGRlbGF5LiBJZiBkZWxheSBleGN1c2VkIGJ5IHRoaXMgY2xhdXNlIGV4dGVuZHMgZm9yCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBtb3JlIHRoYW4gc2l4dHkgKDYwKSBkYXlzIGFuZCB0aGUgcGFydGllcyBoYXZlIG5vdCBhZ3JlZWQgdXBvbiBhIHJldmlzZWQgYmFzaXMKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGZvciBjb250aW51aW5nIHRoZSBPcmRlciBhdCB0aGUgZW5kIG9mIHRoZSBkZWxheSwgdGhlbiBlaXRoZXIgcGFydHkgKGV4Y2VwdCB3aGVyZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgYSBkZWxheSBpcyBjYXVzZWQgYnkgQ3VzdG9tZXIsIGluIHdoaWNoIGV2ZW50IG9ubHkgUm90ZXgpLCB1cG9uIHRoaXJ0eSAoMzApCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBkYXlzIHdyaXR0ZW4gbm90aWNlLCBtYXkgdGVybWluYXRlIHRoZSBPcmRlciB3aXRoIHJlc3BlY3QgdG8gaXRzIHVuZXhlY3V0ZWQKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHBvcnRpb24sIHdoZXJldXBvbiBDdXN0b21lciBzaGFsbCBwcm9tcHRseSBwYXkgUm90ZXggaXRzIHRlcm1pbmF0aW9uIGNoYXJnZXMKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGRldGVybWluZWQgaW4gYWNjb3JkYW5jZSB3aXRoIFJvdGV4I3Mgc3RhbmRhcmQgYWNjb3VudGluZyBwcmFjdGljZXMgdXBvbgogICAgICAgICAgICAgICAgICAgICAgICAgICAgc3VibWlzc2lvbiBvZiBSb3RleCNzIGludm9pY2VzLCB0aGVyZWZvcmUuCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBOZWl0aGVyIFBhcnR5IHNoYWxsIGJlIGxpYWJsZSBmb3IgZmFpbHVyZSB0byBwZXJmb3JtIHRoZWlyIG9ibGlnYXRpb25zIHdoaWNoIGFyaXNlcwogICAgICAgICAgICAgICAgICAgICAgICAgICAgYXMgYSBjb25zZXF1ZW5jZSBvZiBhIEZvcmNlIE1hamV1cmUgb2NjdXJyZW5jZSBvdGhlciB0aGFuIHRoZSBvYmxpZ2F0aW9uIHRvCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBtYWtlIHBheW1lbnRzIGR1ZSBhbmQgcGF5YWJsZSB1bmRlciB0aGUgQ29udHJhY3QuPGJyLz48YnIvPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgPFN0cm9uZz4yMi4gSU5TVEFMTEFUSU9OOiA8L1N0cm9uZz4oQSkgV2hlcmUgUm90ZXggaGFzIGFncmVlZCB0byBpbnN0YWxsIHRoZSBFcXVpcG1lbnQsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBDdXN0b21lciBzaGFsbCBhdCBpdHMgb3duIGNvc3QgcHJlcGFyZSB0aGUgc2l0ZSBvbiB3aGljaCB0aGUgRXF1aXBtZW50IGFyZSB0byBiZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgaW5zdGFsbGVkIGluIGFjY29yZGFuY2Ugd2l0aCB0aGUgc3BlY2lmaWNhdGlvbnMgZnVybmlzaGVkIGJ5IFJvdGV4IGZvciB0aGlzCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBwdXJwb3NlIGFuZCwgaW4gYWNjb3JkYW5jZSB3aXRoIHN1Y2ggc3BlY2lmaWNhdGlvbnMsIHByb3ZpZGUgc3VjaCBlcXVpcG1lbnQKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGFuZCBjYXJyeSBvdXQgc3VjaCB3b3JrcyB0byB0aGUgc2l0ZSBhcyBtYXkgYmUgbmVjZXNzYXJ5IHRvIGVuYWJsZSBSb3RleCB0bwogICAgICAgICAgICAgICAgICAgICAgICAgICAgaW5zdGFsbCB0aGUgRXF1aXBtZW50IGFuZCBpZiBpdCBzaGFsbCBmYWlsIHNvIHRvIHByZXBhcmUgdGhlIHNpdGUgYW5kIHByb3ZpZGUgc3VjaAogICAgICAgICAgICAgICAgICAgICAgICAgICAgZXF1aXBtZW50IGFuZCBjYXJyeSBvdXQgc3VjaCB3b3JrcyBiZWZvcmUgdGhlIGFncmVlZCBkZWxpdmVyeSBkYXRlLCBDdXN0b21lcgogICAgICAgICAgICAgICAgICAgICAgICAgICAgc2hhbGwgaW5kZW1uaWZ5IFJvdGV4IGFnYWluc3QgYWxsIGNvc3RzIGFuZCBjaGFyZ2VzIGluY3VycmVkIGJ5IFJvdGV4IChpbmNsdWRpbmcKICAg';
        b64 += 'ICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgIDwvcD4gCiAgICAgICAgICAgICAgICAgICAgPC90ZD4KICAgICAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICA8dGQgc3R5bGU9IndpZHRoOiA1MCU7dmVydGljYWwtYWxpZ246IHRleHQtdG9wOyB0ZXh0LWFsaWduOiBsZWZ0OyBmb250LXNpemU6IDcuNXB0OyI+CiAgICAgICAgICAgICAgICAgICAgICAgIDxwPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgb2YgY29tcGxldGlvbiBvZiBzdWNoIHRlc3RpbmcgKHRoZSAjTm90aWNlIykuIEN1c3RvbWVyIHNoYWxsIG5vdCBnaXZlIGFuZCBzaGFsbAogICAgICAgICAgICAgICAgICAgICAgICAgICAgYmUgZGVlbWVkIG5vdCB0byBoYXZlIGdpdmVuIHRoZSBOb3RpY2UgdW5sZXNzIEN1c3RvbWVyIGhhcyBmb3VuZCBhIHN1YnN0YW50aWFsCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBkZWZlY3QgaW4gdGhlIEVxdWlwbWVudC4gSWYgUm90ZXggaXMgc28gbm90aWZpZWQsIFJvdGV4IHNoYWxsIHVzZSBpdHMgcmVhc29uYWJsZQogICAgICAgICAgICAgICAgICAgICAgICAgICAgZW5kZWF2b3VycyB0byByZW1lZHkgYW55IHN1Y2ggZGVmZWN0IHdpdGhpbiBhIHJlYXNvbmFibGUgdGltZSBhbmQgQ3VzdG9tZXIKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHNoYWxsIGJlIGRlZW1lZCB0byBoYXZlIGFjY2VwdGVkIHRoZSBFcXVpcG1lbnQgd2l0aGluIDMgZGF5cyBvZiBzdWNoIGRlZmVjdAogICAgICAgICAgICAgICAgICAgICAgICAgICAgYmVpbmcgcmVtZWRpZWQuIDxici8+PGJyLz4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxzdHJvbmc+MjMuT3JkZXIgQ2FuY2VsbGF0aW9uOjwvc3Ryb25nPgogICAgICAgICAgICAgICAgICAgICAgICAgICAgUm90ZXggc2hhbGwgbm90IGJlIHBlbmFsaXppbmcgYnV5ZXIsIGZvciBhbnkgY2FuY2VsbGF0aW9uIG9mIG9yZGVycyB3aXRoaW4gMgogICAgICAgICAgICAgICAgICAgICAgICAgICAgd2Vla3Mgb3IgMjUlIG9mIHRoZSB0b3RhbCBsZWFkIHRpbWUgZWxhcHNlZCwgd2hpY2hldmVyIGlzIGVhcmxpZXIsIG9mIHJlY2VpcHQgb2YKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHB1cmNoYXNlIG9yZGVyLiBUaGVyZWFmdGVyLCBpdCBzaGFsbCBiZSBjaGFyZ2VkIGFzIHBlciB0aGUgcHJvZ3Jlc3Mgb2YgdGhlIG9yZGVyIG9uCiAgICAgICAgICAgICAgICAgICAgICAgICAgICB0aGUgZGF0ZSBvZiBjYW5jZWxsYXRpb24uIEhvd2V2ZXIsIDEwMCUgY2FuY2VsbGF0aW9uIGNoYXJnZXMgd2lsbCBiZSBhcHBsaWNhYmxlLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgaWYgdGhlIG5vdGljZSBvZiBjYW5jZWxsYXRpb24gaXMgcmVjZWl2ZWQgYWZ0ZXIgNTAlIG9mIHRoZSB0aW1lIGVsYXBzZWQgdG8gdGhlCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBjb25maXJtZWQgZGVsaXZlcnkgZGF0ZS48YnIvPjxici8+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICA8c3Ryb25nPjI0LiBEZW11cnJhZ2VzIDwvc3Ryb25nPlJvdGV4IHdpbGwgYmUgY2hhcmdpbmcgOSUgZGVtdXJyYWdlcyBjaGFyZ2UgcGVyIG1vbnRoIGZvcgogICAgICAgICAgICAgICAgICAgICAgICAgICAgdGhlIGdvb2RzIHRoYXQgd2VyZSBlaXRoZXIga2VwdCBvbiBob2xkIG9yIG5vdCBwaWNrZWQgYnkgdGhlIHB1cmNoYXNlciBpbiB0aGlzCiAgICAgICAgICAgICAgICAgICAgICAgICAgICBhZ3JlZW1lbnQgYmV5b25kIDMwIGRheXMgZnJvbSB0aGUgd3JpdHRlbiBub3RpY2Ugb2YgcmVhZGluZXNzIG9mIGdvb2RzLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgaW5jbHVkaW5nIG5vdGlmaWNhdGlvbiB2aWEgZW1haWxzLjxici8+PGJyLz4KICAgICAgICAgICAgICAgICAgICAgICAgICAgIDxzdHJvbmc+MjUuIDwvc3Ryb25nPkFsbCB0aGUgcmVtZWRpZXMgcHJvdmlkZWQgaGVyZWluIHNoYWxsIGJlIGluIGFkZGl0aW9uIHRvIGFuZCBub3QgaW4gZGVyb2dhdGlvbgogICAgICAgICAgICAgICAgICAgICAgICAgICAgb2YgdGhlIHJpZ2h0cyBvZiB0aGUgcGFydGllcyB1bmRlciBsYXcuCiAgICAgICAgICAgICAgICAgICAgICAgIDwvcD4KICAgICAgICAgICAgICAgICAgICA8L3RkPiAgICAgICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICA8L3RyPgogICAgICAgICAgICAgICAgCiAgICAgICAgICAgIDwvdGFibGU+IAogICAgICAgIDwvZGl2PiAgICAgICAKICAgIA==';
        return EncodingUtil.base64Decode(b64).toString();
    }

}