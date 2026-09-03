public class Invoice_number {

    public static void getInvoiceMasterNumber(String billDocNum) {

        HttpResponse resp;

        try {

            System.debug('Invoice API started: ' + billDocNum);

            if (String.isBlank(billDocNum)) {
                System.debug('Bill document number is blank');
                return;
            }

            System.debug('Calling SAP API');

            resp = UtilityCls.doGetWithBasicAuth(
                'Invoice_API',
                'BY_NUMBER',
                null,
                null,
                billDocNum
            );

            System.debug('SAP API response received');
            System.debug('Status: ' + resp.getStatusCode());

            if (resp.getStatusCode() == 200) {

                System.debug('Parsing SAP response');

                IntegrationRequestBuilder.InvoiceMasterResponse respWrapper =
                    IntegrationRequestBuilder.InvoiceMasterResponseParse(
                        resp.getBody()
                    );

                if (respWrapper == null ||
                    respWrapper.d == null ||
                    respWrapper.d.results == null) {

                    System.debug('No invoice data found');
                    return;
                }

                List<IntegrationRequestBuilder.invoiceList> parentWrappers =
                    respWrapper.d.results;

                System.debug('Invoices received: ' + parentWrappers.size());

                Set<String> billDocSet = new Set<String>();
                Set<String> soldToSet = new Set<String>();
                Set<String> itemCodeSet = new Set<String>();

                for (IntegrationRequestBuilder.invoiceList parent : parentWrappers) {

                    if (String.isNotBlank(parent.bill_docnum)) {
                        billDocSet.add(parent.bill_docnum);
                    }

                    if (String.isNotBlank(parent.sold_to)) {
                        soldToSet.add(parent.sold_to);
                    }

                    if (parent.to_item_details != null &&
                        parent.to_item_details.results != null) {

                        for (
                            IntegrationRequestBuilder.invItemDetailsList child :
                            parent.to_item_details.results
                        ) {

                            if (String.isNotBlank(child.item_code)) {
                                itemCodeSet.add(child.item_code);
                            }
                        }
                    }
                }

                System.debug('Bill docs: ' + billDocSet.size());
                System.debug('Customers: ' + soldToSet.size());
                System.debug('Products: ' + itemCodeSet.size());

                Map<String, Id> accountMap = new Map<String, Id>();

                if (!soldToSet.isEmpty()) {

                    System.debug('Getting accounts');

                    for (Account acc : [
                        SELECT Id, SAP_Customer_Code__c
                        FROM Account
                        WHERE SAP_Customer_Code__c IN :soldToSet
                    ]) {

                        accountMap.put(
                            acc.SAP_Customer_Code__c,
                            acc.Id
                        );
                    }

                    System.debug('Accounts found: ' + accountMap.size());
                }

                Map<String, Id> productMap = new Map<String, Id>();

                if (!itemCodeSet.isEmpty()) {

                    System.debug('Getting products');

                    for (Product2 prod : [
                        SELECT Id, ProductCode
                        FROM Product2
                        WHERE ProductCode IN :itemCodeSet
                    ]) {

                        productMap.put(
                            prod.ProductCode,
                            prod.Id
                        );
                    }

                    System.debug('Products found: ' + productMap.size());
                }

                Map<String, SO_Invoice__c> existingInvoiceMap =
                    new Map<String, SO_Invoice__c>();

                if (!billDocSet.isEmpty()) {

                    System.debug('Checking existing invoices');

                    for (SO_Invoice__c inv : [
                        SELECT Id, Name, Bill_Doc_No__c
                        FROM SO_Invoice__c
                        WHERE Bill_Doc_No__c IN :billDocSet
                    ]) {

                        existingInvoiceMap.put(
                            inv.Bill_Doc_No__c,
                            inv
                        );
                    }

                    System.debug(
                        'Existing invoices: ' +
                        existingInvoiceMap.size()
                    );
                }

                Map<String, SO_Invoice__c> parentDmlMap =
                    new Map<String, SO_Invoice__c>();

                for (IntegrationRequestBuilder.invoiceList parent : parentWrappers) {

                    if (String.isBlank(parent.bill_docnum)) {
                        continue;
                    }

                    SO_Invoice__c pRecord;

                    if (existingInvoiceMap.containsKey(parent.bill_docnum)) {
                        pRecord = existingInvoiceMap.get(parent.bill_docnum);
                    } else {
                        pRecord = new SO_Invoice__c();
                    }

                    pRecord.Name = parent.bill_docnum;
                    pRecord.Bill_Doc_No__c = parent.bill_docnum;
                    pRecord.Bill_Doc_Type__c = parent.bill_doctype;
                    pRecord.Bill_Date__c = Date.valueOf(parent.bill_date);
                    pRecord.Acc_Doc_No__c = parent.acc_docnum;
                    pRecord.Account__c = accountMap.get(parent.sold_to);
                    pRecord.Sold_To__c = parent.sold_to;
                    pRecord.Zyear__c = parent.zyear;
                    pRecord.SO_No__c = parent.so_num;
                    pRecord.Terms_Of_Payment__c = parent.terms_of_payment;
                    pRecord.Incoterms__c = parent.incoterms;
                    pRecord.Incoterms_Location__c = parent.incoterms_location;
                    pRecord.Company__c = parent.company;
                    pRecord.CurrencyIsoCode = parent.curr;
                    pRecord.Payer__c = parent.payer;
                    pRecord.Bill_To__c = parent.bill_to;
                    pRecord.Sales_Org__c = parent.sales_org;
                    pRecord.Distribution_Channel__c = parent.distribution_channel;
                    pRecord.Division__c = parent.division;
                    pRecord.Net_Value__c = Decimal.valueOf(parent.net_value);
                    pRecord.Tax_Value__c = Decimal.valueOf(parent.tax_value);
                    pRecord.Exc_Rate__c = Decimal.valueOf(parent.exc_rate);
                    pRecord.SAP_Integration__c = true;

                    parentDmlMap.put(parent.bill_docnum, pRecord);
                }

                List<SO_Invoice__c> parentList =
                    new List<SO_Invoice__c>();

                parentList.addAll(parentDmlMap.values());

                System.debug('Invoice records ready: ' + parentList.size());

                if (!parentList.isEmpty()) {

                    System.debug('Updating invoices');

                    upsert parentList;

                    System.debug('Invoices updated');
                }

                Map<String, Id> parentNameToIdMap =
                    new Map<String, Id>();

                for (SO_Invoice__c parent : parentList) {

                    parentNameToIdMap.put(
                        parent.Bill_Doc_No__c,
                        parent.Id
                    );
                }

                Set<Id> parentIds =
                    new Set<Id>(parentNameToIdMap.values());

                Map<String, Invoice_Line_item__c> existingChildMap =
                    new Map<String, Invoice_Line_item__c>();

                if (!parentIds.isEmpty()) {

                    System.debug('Checking existing line items');

                    for (Invoice_Line_item__c child : [
                        SELECT Id, Item_No__c, SO_Invoice__c
                        FROM Invoice_Line_item__c
                        WHERE SO_Invoice__c IN :parentIds
                    ]) {

                        String key =
                            String.valueOf(child.SO_Invoice__c) +
                            '_' +
                            child.Item_No__c;

                        existingChildMap.put(key, child);
                    }

                    System.debug(
                        'Existing line items: ' +
                        existingChildMap.size()
                    );
                }

                Map<String, Invoice_Line_item__c> childDmlMap =
                    new Map<String, Invoice_Line_item__c>();

                for (IntegrationRequestBuilder.invoiceList parent : parentWrappers) {

                    Id parentId =
                        parentNameToIdMap.get(parent.bill_docnum);

                    if (parentId == null ||
                        parent.to_item_details == null ||
                        parent.to_item_details.results == null) {
                        continue;
                    }

                    for (
                        IntegrationRequestBuilder.invItemDetailsList child :
                        parent.to_item_details.results
                    ) {

                        if (String.isBlank(child.item_no)) {
                            continue;
                        }

                        String key =
                            String.valueOf(parentId) +
                            '_' +
                            child.item_no;

                        Invoice_Line_item__c cRecord;

                        if (existingChildMap.containsKey(key)) {
                            cRecord = existingChildMap.get(key);
                        } else {
                            cRecord = new Invoice_Line_item__c();
                        }

                        cRecord.Name = child.item_no;
                        cRecord.Item_No__c = child.item_no;
                        cRecord.Item_Code__c = child.item_code;
                        cRecord.Product__c = productMap.get(child.item_code);
                        cRecord.Product_Description__c = child.item_desc;
                        cRecord.QTY__c = Decimal.valueOf(child.item_qty);
                        cRecord.UOM__c = child.uom;
                        cRecord.Plant__c = child.plant;
                        cRecord.Unit_Price__c = Decimal.valueOf(child.net_amount);
                        cRecord.GST_Amount__c = Decimal.valueOf(child.tax_amount);
                        cRecord.Line_Amount__c = Decimal.valueOf(child.net_price);

                        childDmlMap.put(key, cRecord);
                    }
                }

                List<Invoice_Line_item__c> childList =
                    new List<Invoice_Line_item__c>();

                childList.addAll(childDmlMap.values());

                System.debug('Line items ready: ' + childList.size());

                if (!childList.isEmpty()) {

                    System.debug('Updating line items');

                    upsert childList;

                    System.debug('Line items updated');
                }

                Map<String, Id> childNameToIdMap =
                    new Map<String, Id>();

                for (Invoice_Line_item__c child : childList) {

                    String key =
                        String.valueOf(child.SO_Invoice__c) +
                        '_' +
                        child.Item_No__c;

                    childNameToIdMap.put(
                        key,
                        child.Id
                    );
                }

                List<Price_Details__c> grandChildList =
                    new List<Price_Details__c>();

                for (IntegrationRequestBuilder.invoiceList parent : parentWrappers) {

                    Id parentId =
                        parentNameToIdMap.get(parent.bill_docnum);

                    if (parentId == null ||
                        parent.to_item_details == null ||
                        parent.to_item_details.results == null) {
                        continue;
                    }

                    for (
                        IntegrationRequestBuilder.invItemDetailsList child :
                        parent.to_item_details.results
                    ) {

                        String childKey =
                            String.valueOf(parentId) +
                            '_' +
                            child.item_no;

                        Id childId =
                            childNameToIdMap.get(childKey);

                        if (childId == null ||
                            child.to_price_details == null ||
                            child.to_price_details.results == null) {
                            continue;
                        }

                        for (
                            IntegrationRequestBuilder.invPriceDetailsList price :
                            child.to_price_details.results
                        ) {

                            Price_Details__c gcRecord =
                                new Price_Details__c();

                            gcRecord.Cond_Type__c = price.cond_type;
                            gcRecord.Unit_Amount__c =
                                Decimal.valueOf(price.unit_amount);
                            gcRecord.Unit__c = price.unit;
                            gcRecord.Amount__c =
                                Decimal.valueOf(price.amount);
                            gcRecord.CurrencyIsoCode = price.curr;
                            gcRecord.Invoice_Line_item__c = childId;

                            grandChildList.add(gcRecord);
                        }
                    }
                }

                System.debug(
                    'Price details ready: ' +
                    grandChildList.size()
                );

                if (!grandChildList.isEmpty()) {

                    System.debug('Inserting price details');

                    insert grandChildList;

                    System.debug('Price details inserted');
                }

                System.debug('Invoice API completed');

            } else {

                System.debug(
                    'SAP Error: ' +
                    resp.getStatusCode() +
                    ' ' +
                    resp.getBody()
                );
            }

        } catch (Exception e) {

            System.debug('Error: ' + e.getMessage());
            System.debug('Line: ' + e.getLineNumber());
            System.debug('Type: ' + e.getTypeName());
            System.debug('Stack: ' + e.getStackTraceString());
        }
    }
}