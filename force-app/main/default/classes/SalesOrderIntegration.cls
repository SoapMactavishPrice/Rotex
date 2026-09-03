public class SalesOrderIntegration {

    public static void getSalesOrderMaster() {

        HttpResponse resp;

        try {

            Date dateOfExc = Date.today();

            resp = UtilityCls.doGetWithBasicAuth(
                'Sales_Order_API',
                'DAILY',
                dateOfExc,
                dateOfExc,
                ''
            );

            if (resp.getStatusCode() == 200) {

                System.debug('resp: ' + resp.getBody());

                IntegrationRequestBuilder.SalesOrderMasterResponse respWrapper =
                    IntegrationRequestBuilder.SalesOrderMasterResponseParse(
                        resp.getBody()
                    );

                if (respWrapper == null ||
                    respWrapper.d == null ||
                    respWrapper.d.results == null) {

                    System.debug('No sales order data found.');
                    return;
                }

                List<IntegrationRequestBuilder.salesordersList> parentWrappers =
                    respWrapper.d.results;

                Set<String> salesOrderNumberSet = new Set<String>();

                for (IntegrationRequestBuilder.salesordersList parent : parentWrappers) {

                    if (String.isNotBlank(parent.so_num)) {
                        salesOrderNumberSet.add(parent.so_num);
                    }
                }

                if (salesOrderNumberSet.isEmpty()) {
                    System.debug('No sales order numbers found.');
                    return;
                }

                Map<String, Id> sonumMap = new Map<String, Id>();

                for (Order existingOrder : [
                    SELECT Id, SO_No__c
                    FROM Order
                    WHERE SO_No__c IN :salesOrderNumberSet
                ]) {
                    sonumMap.put(existingOrder.SO_No__c, existingOrder.Id);
                }

                Set<String> itemIds = new Set<String>();
                Set<String> productCodeSet = new Set<String>();

                for (IntegrationRequestBuilder.salesordersList parent : parentWrappers) {

                    if (String.isNotBlank(parent.sold_to)) {
                        itemIds.add(parent.sold_to);
                    }

                    if (String.isNotBlank(parent.ship_to)) {
                        itemIds.add(parent.ship_to);
                    }

                    if (String.isNotBlank(parent.bill_to)) {
                        itemIds.add(parent.bill_to);
                    }

                    if (parent.to_item_details != null &&
                        parent.to_item_details.results != null) {

                        for (IntegrationRequestBuilder.itemDetailsList child :
                            parent.to_item_details.results) {

                            if (String.isNotBlank(child.item_code)) {
                                productCodeSet.add(child.item_code);
                            }
                        }
                    }
                }

                Map<String, Id> accId = new Map<String, Id>();

                if (!itemIds.isEmpty()) {

                    for (Account acc : [
                        SELECT Id, SAP_Customer_Code__c
                        FROM Account
                        WHERE SAP_Customer_Code__c IN :itemIds
                    ]) {

                        accId.put(
                            acc.SAP_Customer_Code__c,
                            acc.Id
                        );
                    }
                }

                Map<String, Id> productIdMap = new Map<String, Id>();

                if (!productCodeSet.isEmpty()) {

                    for (Product2 product : [
                        SELECT Id, ProductCode
                        FROM Product2
                        WHERE ProductCode IN :productCodeSet
                    ]) {

                        productIdMap.put(
                            product.ProductCode,
                            product.Id
                        );
                    }
                }

                Map<String, Id> pbMap = new Map<String, Id>();

                for (Pricebook2 pb : [
                    SELECT Id, Distribution_Channel__c
                    FROM Pricebook2
                    WHERE Distribution_Channel__c != null
                    AND Channel_Partner__c = null
                ]) {

                    pbMap.put(
                        pb.Distribution_Channel__c,
                        pb.Id
                    );
                }

                List<Order> parentList = new List<Order>();

                for (IntegrationRequestBuilder.salesordersList parent : parentWrappers) {

                    if (String.isBlank(parent.so_num)) {
                        continue;
                    }

                    if (!accId.containsKey(parent.sold_to)) {
                        continue;
                    }

                    Order pRecord = new Order();

                    if (sonumMap.containsKey(parent.so_num)) {
                        pRecord.Id = sonumMap.get(parent.so_num);
                    }

                    pRecord.Status = 'Draft';
                    pRecord.SO_No__c = parent.so_num;
                    pRecord.AccountId = accId.get(parent.sold_to);
                    pRecord.SO_Type__c = parent.so_type;
                    pRecord.Sold_To__c = parent.sold_to;
                    pRecord.Ship_To__c = parent.ship_to;
                    pRecord.Bill_To__c = parent.bill_to;
                    pRecord.Cust_Ref__c = parent.cust_ref;

                    if (String.isNotBlank(parent.custref_date)) {
                        pRecord.Cust_Ref_Date__c =
                            Date.valueOf(parent.custref_date);
                    }

                    if (String.isNotBlank(parent.created_on_date)) {
                        pRecord.EffectiveDate =
                            Date.valueOf(parent.created_on_date);
                    } else {
                        pRecord.EffectiveDate = Date.today();
                    }

                    if (String.isNotBlank(parent.reqdel_date)) {
                        pRecord.Req_Del_Date__c =
                            Date.valueOf(parent.reqdel_date);
                    }

                    pRecord.Sales_Org__c = parent.sales_org;
                    pRecord.Distribution_Channel__c =
                        parent.distribution_channel;
                    pRecord.Division__c = parent.division;
                    pRecord.Terms_Of_Payment__c =
                        parent.terms_of_payment;
                    pRecord.Incoterms__c = parent.incoterms;
                    pRecord.Incoterms_Location__c =
                        parent.incoterms_location;
                    pRecord.Company__c = parent.company;
                    pRecord.Status__c = parent.status;
                    pRecord.Net_Value__c = parent.net_value;
                    pRecord.SAP_Integration__c = true;

                    if (String.isNotBlank(parent.curr)) {
                        pRecord.CurrencyIsoCode = parent.curr;
                    }

                    if (pbMap.containsKey(parent.distribution_channel)) {
                        pRecord.Pricebook2Id =
                            pbMap.get(parent.distribution_channel);
                    }

                    parentList.add(pRecord);
                }

                if (!parentList.isEmpty()) {
                    upsert parentList;
                    System.debug('Parent upserted: ' + parentList.size());
                }

                Map<String, Id> parentNameToIdMap =
                    new Map<String, Id>();

                Map<String, String> parentCurrency =
                    new Map<String, String>();

                for (Order parent : parentList) {

                    parentNameToIdMap.put(
                        parent.SO_No__c,
                        parent.Id
                    );

                    parentCurrency.put(
                        parent.SO_No__c,
                        parent.CurrencyIsoCode
                    );
                }

                Map<String, Id> existingChildMap =
                    new Map<String, Id>();

                if (!parentNameToIdMap.isEmpty()) {

                    for (OrderItem existingOi : [
                        SELECT Id, OrderId, Item_No__c
                        FROM OrderItem
                        WHERE OrderId IN :parentNameToIdMap.values()
                    ]) {

                        existingChildMap.put(
                            existingOi.OrderId + '/' +
                            existingOi.Item_No__c,
                            existingOi.Id
                        );
                    }
                }

                Set<Id> neededPricebookIds = new Set<Id>();
                Set<Id> neededProductIds = new Set<Id>();
                Set<String> neededCurrencies = new Set<String>();

                for (IntegrationRequestBuilder.salesordersList parent :
                    parentWrappers) {

                    if (parent.to_item_details == null ||
                        parent.to_item_details.results == null) {
                        continue;
                    }

                    Id pbId = pbMap.get(
                        parent.distribution_channel
                    );

                    String curr = parentCurrency.get(parent.so_num);

                    if (pbId != null) {
                        neededPricebookIds.add(pbId);
                    }

                    if (String.isNotBlank(curr)) {
                        neededCurrencies.add(curr);
                    }

                    for (IntegrationRequestBuilder.itemDetailsList child :
                        parent.to_item_details.results) {

                        if (productIdMap.containsKey(child.item_code)) {
                            neededProductIds.add(
                                productIdMap.get(child.item_code)
                            );
                        }
                    }
                }

                Map<String, Id> pbeMap = new Map<String, Id>();

                if (!neededPricebookIds.isEmpty() &&
                    !neededProductIds.isEmpty() &&
                    !neededCurrencies.isEmpty()) {

                    for (PricebookEntry pbeRow : [
                        SELECT Id,
                               Pricebook2Id,
                               Product2Id,
                               CurrencyIsoCode
                        FROM PricebookEntry
                        WHERE Pricebook2Id IN :neededPricebookIds
                        AND Product2Id IN :neededProductIds
                        AND CurrencyIsoCode IN :neededCurrencies
                        AND IsActive = true
                    ]) {

                        pbeMap.put(
                            pbeRow.Pricebook2Id + '_' +
                            pbeRow.Product2Id + '_' +
                            pbeRow.CurrencyIsoCode,
                            pbeRow.Id
                        );
                    }
                }

                List<OrderItem> childList =
                    new List<OrderItem>();

                Map<String, Id> childNameToIdMap =
                    new Map<String, Id>();

                for (IntegrationRequestBuilder.salesordersList parent :
                    parentWrappers) {

                    Id parentId =
                        parentNameToIdMap.get(parent.so_num);

                    String curr =
                        parentCurrency.get(parent.so_num);

                    if (parentId == null ||
                        parent.to_item_details == null ||
                        parent.to_item_details.results == null) {
                        continue;
                    }

                    for (IntegrationRequestBuilder.itemDetailsList child :
                        parent.to_item_details.results) {

                        if (!productIdMap.containsKey(child.item_code)) {
                            continue;
                        }

                        Id productId =
                            productIdMap.get(child.item_code);

                        Id pbId =
                            pbMap.get(parent.distribution_channel);

                        String pbeKey =
                            pbId + '_' +
                            productId + '_' +
                            curr;

                        Id pbeId = pbeMap.get(pbeKey);

                        if (pbeId == null) {
                            continue;
                        }

                        String childKey =
                            parentId + '/' + child.item_no;

                        OrderItem cRecord =
                            new OrderItem();

                        if (existingChildMap.containsKey(childKey)) {
                            cRecord.Id =
                                existingChildMap.get(childKey);
                        }

                        cRecord.Item_No__c = child.item_no;
                        cRecord.Item_Code__c = child.item_code;
                        cRecord.Description = child.item_desc;

                        if (String.isNotBlank(child.item_qty)) {
                            cRecord.Quantity =
                                Decimal.valueOf(child.item_qty);
                        }

                        cRecord.UOM__c = child.uom;
                        cRecord.Plant__c = child.plant;
                        cRecord.Pdd_Dat__c = child.pdd_dat;
                        cRecord.It_Status__c = child.it_status;
                        cRecord.Product2Id = productId;
                        cRecord.PricebookEntryId = pbeId;

                        if (String.isNotBlank(child.net_price)) {
                            cRecord.UnitPrice =
                                Decimal.valueOf(child.net_price);
                        }

                        if (String.isNotBlank(child.tax_amount)) {
                            cRecord.Tax_Amount__c =
                                Decimal.valueOf(child.tax_amount);
                        }

                        cRecord.OrderId = parentId;

                        childList.add(cRecord);
                    }
                }

                if (!childList.isEmpty()) {

                    upsert childList;

                    System.debug(
                        'Child upserted: ' +
                        childList.size()
                    );

                    for (OrderItem child : childList) {

                        childNameToIdMap.put(
                            child.OrderId + '/' +
                            child.Item_No__c,
                            child.Id
                        );
                    }
                }

                List<Price_Details__c> grandChildList =
                    new List<Price_Details__c>();

                for (IntegrationRequestBuilder.salesordersList parent :
                    parentWrappers) {

                    if (parent.to_item_details == null ||
                        parent.to_item_details.results == null) {
                        continue;
                    }

                    Id parentId =
                        parentNameToIdMap.get(parent.so_num);

                    for (IntegrationRequestBuilder.itemDetailsList child :
                        parent.to_item_details.results) {

                        Id childId =
                            childNameToIdMap.get(
                                parentId + '/' +
                                child.item_no
                            );

                        if (childId == null ||
                            child.to_price_details == null ||
                            child.to_price_details.results == null) {
                            continue;
                        }

                        for (IntegrationRequestBuilder.priceDetailsList price :
                            child.to_price_details.results) {

                            Price_Details__c gcRecord =
                                new Price_Details__c();

                            gcRecord.Cond_Type__c =
                                price.cond_type;

                            if (String.isNotBlank(price.unit_amount)) {
                                gcRecord.Unit_Amount__c =
                                    Decimal.valueOf(
                                        price.unit_amount
                                    );
                            }

                            gcRecord.Unit__c =
                                price.unit;

                            if (String.isNotBlank(price.amount)) {
                                gcRecord.Amount__c =
                                    Decimal.valueOf(
                                        price.amount
                                    );
                            }

                            gcRecord.CurrencyIsoCode =
                                price.curr;

                            gcRecord.Order_Product__c =
                                childId;

                            grandChildList.add(gcRecord);
                        }
                    }
                }

                if (!grandChildList.isEmpty()) {
                    insert grandChildList;
                    System.debug(
                        'Price details inserted: ' +
                        grandChildList.size()
                    );
                }

            } else {

                System.debug(
                    'Error: ' +
                    resp.getStatusCode() +
                    ' ' +
                    resp.getBody()
                );
            }

        } catch (Exception e) {

            System.debug(
                'Exception: ' +
                e.getMessage() +
                ' Line: ' +
                e.getLineNumber()
            );

        } finally {

            String body = '';

            if (resp != null && resp.getBody() != null) {
                body = resp.getBody();
            }

            Integer maxLength = 10000;
            Integer safeLength =
                Math.min(body.length(), maxLength);

            if (resp != null) {

                UtilityCls.logApiCall(
                    'Sales_Order_API',
                    '',
                    '',
                    body.substring(0, safeLength),
                    '',
                    resp.getStatusCode()
                );

            } else {

                UtilityCls.logApiCall(
                    'Sales_Order_API',
                    '',
                    '',
                    '',
                    'No response from API',
                    0
                );
            }
        }
    }
}