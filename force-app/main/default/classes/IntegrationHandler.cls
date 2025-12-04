public class IntegrationHandler {

    public static void getCustomerDetailByNumber(String pId, String ccode) {
        HttpResponse resp;
        String API_Name = 'Customer_Master_API_2';
        Date dateOfExc = Date.today();
        try {
            resp = UtilityCls.doGetWithBasicAuth(API_Name, 'DAILY', dateOfExc, dateOfExc, ccode);

            if (resp.getStatusCode() == 200) {
                IntegrationRequestBuilder.CustomerMasterResponse respWrapper = IntegrationRequestBuilder.CustomerMasterResponseParse(resp.getBody());
                List < IntegrationRequestBuilder.customersList > parentWrappers = respWrapper.d.results;

                Partner_Details__c pdToUpsert = new Partner_Details__c();

                if (parentWrappers.size() > 0) {
                    Partner_Details__c pd = new Partner_Details__c();
                    pd.Id = pId;
                    pd.Street__c = parentWrappers[0].street;
                    pd.City__c = parentWrappers[0].city;
                    pd.District__c = parentWrappers[0].district;
                    pd.State__c = parentWrappers[0].state;
                    pd.Country__c = parentWrappers[0].country;
                    pd.Postal_Code__c = parentWrappers[0].postal_code;
                    update pd;
                }
            }

        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        } finally {
            UtilityCls.logApiCall('Customer_Master_API_2:' + String.valueOf(dateOfExc), '', '', resp != null ? resp.getBody() : '', '', resp != null ? resp.getStatusCode() : 0);
        }

    }

    public static void getCustomerMaster() {
        HttpResponse resp;
        String API_Name = 'Customer_Master_API';
        // Date dateOfExc = date.valueOf('2025-01-10');
        Date dateOfExc = Date.today();
        try {
            resp = UtilityCls.doGetWithBasicAuth(API_Name, 'DAILY', dateOfExc, dateOfExc, '');

            if (resp.getStatusCode() == 200) {
                // IntegrationRequestBuilder.CustomerMasterResponse respWrapper = IntegrationRequestBuilder.CustomerMasterResponseParse(resp.getBody());
                // List<IntegrationRequestBuilder.customersList> parentWrappers = respWrapper.d.results;

                // // Collect keys for parent matching
                // Set<String> accCodes = new Set<String>();
                // for (IntegrationRequestBuilder.customersList c : parentWrappers) {
                //     accCodes.add(c.customer_number);
                // }

                IntegrationRequestBuilder.CustomerMasterResponse respWrapper = IntegrationRequestBuilder.CustomerMasterResponseParse(resp.getBody());
                List < IntegrationRequestBuilder.customersList > allCustomers = respWrapper.d.results;

                // Use a map to store unique customers by customer_number
                Map < String, IntegrationRequestBuilder.customersList > uniqueCustomersMap = new Map < String, IntegrationRequestBuilder.customersList > ();

                // Only keep the first occurrence of each customer
                for (IntegrationRequestBuilder.customersList customer: allCustomers) {
                    if (String.isNotBlank(customer.customer_number) && !uniqueCustomersMap.containsKey(customer.customer_number)) {
                        uniqueCustomersMap.put(customer.customer_number, customer);
                    }
                }

                // Get the deduplicated list of customers
                List < IntegrationRequestBuilder.customersList > parentWrappers = uniqueCustomersMap.values();

                // Collect keys for parent matching
                Set < String > accCodes = uniqueCustomersMap.keySet();

                // Fetch existing Accounts
                Map < String, Account > existingAccountsMap = new Map < String, Account > ();
                for (Account acc: [SELECT Id, SAP_Customer_Code__c FROM Account WHERE SAP_Customer_Code__c IN: accCodes]) {
                    existingAccountsMap.put(acc.SAP_Customer_Code__c, acc);
                }

                List < Account > accountsToUpsert = new List < Account > ();
                Map < String, Id > accCodeToIdMap = new Map < String, Id > ();

                List < Sales_Area_Item__c > childrenToUpsert = new List < Sales_Area_Item__c > ();
                Map < String, Id > childKeyToIdMap = new Map < String, Id > ();

                List < Partner_Details__c > grandChildrenToUpsert = new List < Partner_Details__c > ();

                // Fetch existing child records
                Map < String, Sales_Area_Item__c > existingChildMap = new Map < String, Sales_Area_Item__c > ();
                for (Sales_Area_Item__c sai: [
                        SELECT Id, Name, Customer_Number__c FROM Sales_Area_Item__c WHERE Customer_Number__c IN: accCodes
                    ]) {
                    existingChildMap.put(sai.Name + '/' + sai.Customer_Number__c, sai);
                }

                // Fetch existing grandchild records
                Map < String, Partner_Details__c > existingGrandChildMap = new Map < String, Partner_Details__c > ();
                for (Partner_Details__c pd: [
                        SELECT Id, Partner_No__c, Sales_Area_Item__c, Partner_Function__c FROM Partner_Details__c
                        WHERE Sales_Area_Item__r.Customer_Number__c IN: accCodes
                    ]) {
                    existingGrandChildMap.put(pd.Sales_Area_Item__c + '/' + pd.Partner_No__c + '/' + pd.Partner_Function__c, pd);
                }

                System.debug(existingGrandChildMap);

                // Process Parents
                for (IntegrationRequestBuilder.customersList parent: parentWrappers) {
                    Account acc = existingAccountsMap.containsKey(parent.customer_number) ? existingAccountsMap.get(parent.customer_number) : new Account();

                    acc.SAP_Customer_Code__c = parent.customer_number;
                    acc.Name = parent.customer_name;
                    acc.Street__c = parent.street;
                    acc.City__c = parent.city;
                    acc.District__c = parent.district;
                    acc.Country__c = parent.country;
                    acc.Postal_Code__c = parent.postal_code;
                    acc.Email_Id__c = 'abc@gmail.com';
                    acc.GST_No__c = parent.gst_no;
                    acc.Pan_No__c = parent.pan_no;
                    acc.Company__c = parent.company;
                    acc.credit_limit__c = Decimal.valueOf(parent.credit_limit);
                    acc.Credit_Days__c = Integer.valueOf(parent.Credit_Days);
                    acc.Discount__c = Decimal.valueOf(parent.Discount);
                    acc.Description = String.valueOf(dateOfExc); // for testing
                    acc.SAP_Integration__c = true;

                    accountsToUpsert.add(acc);
                }

                System.debug(accountsToUpsert);

                if (accountsToUpsert.size() > 0) {
                    upsert accountsToUpsert;
                }

                for (Account a: accountsToUpsert) {
                    accCodeToIdMap.put(a.SAP_Customer_Code__c, a.Id);
                }

                // Process Children
                for (IntegrationRequestBuilder.customersList parent: parentWrappers) {
                    String parentId = accCodeToIdMap.get(parent.customer_number);
                    if (parent.to_salesareaitem != null && parentId != null) {
                        for (IntegrationRequestBuilder.salesAreaItemList child: parent.to_salesareaitem.results) {
                            String key = child.sales_org + '/' + child.distribution_channel + '/' + child.division + '/' + parent.customer_number;

                            Sales_Area_Item__c sai = existingChildMap.containsKey(key) ? existingChildMap.get(key) : new Sales_Area_Item__c();

                            sai.Name = child.sales_org + '/' + child.distribution_channel + '/' + child.division;
                            sai.Sales_Org__c = child.sales_org;
                            sai.Distribution_Channel__c = child.distribution_channel;
                            sai.Division__c = child.division;
                            sai.Incoterms__c = child.incoterms;
                            sai.Incoterms_Location__c = child.incoterms_location;
                            sai.Terms_Of_Payment__c = child.terms_of_payment;
                            sai.Price_List__c = child.PriceList;
                            sai.Customer_Number__c = parent.customer_number;
                            if (!existingChildMap.containsKey(key)) {
                                sai.Account__c = parentId;
                            }
                            childrenToUpsert.add(sai);
                        }
                    }
                }

                if (childrenToUpsert.size() > 0) {
                    upsert childrenToUpsert;
                }
                for (Sales_Area_Item__c sai: childrenToUpsert) {
                    childKeyToIdMap.put(sai.Name + '/' + sai.Customer_Number__c, sai.Id);
                }

                // Process Grandchildren
                for (IntegrationRequestBuilder.customersList parent: parentWrappers) {
                    String parentId = accCodeToIdMap.get(parent.customer_number);
                    if (parent.to_salesareaitem != null && parentId != null) {
                        for (IntegrationRequestBuilder.salesAreaItemList child: parent.to_salesareaitem.results) {
                            String childKey = child.sales_org + '/' + child.distribution_channel + '/' + child.division + '/' + parent.customer_number;

                            String childId = childKeyToIdMap.get(childKey);

                            if (childId != null && child.to_partnerdetails != null) {
                                for (IntegrationRequestBuilder.partnerDetailsList gc: child.to_partnerdetails.results) {
                                    String gcKey = childId + '/' + gc.partner_number + '/' + gc.partner_function;

                                    Partner_Details__c pd = new Partner_Details__c();
                                    if (existingGrandChildMap.containsKey(gcKey)) {
                                        pd = existingGrandChildMap.get(gcKey);
                                    } else {
                                        pd.Sales_Area_Item__c = childId;
                                    }
                                    pd.Name = gc.partner_number + '/' + gc.partner_function;
                                    pd.Partner_No__c = gc.partner_number;
                                    pd.Partner_Function__c = gc.partner_function;
                                    pd.Customer__c = parent.customer_number;
                                    pd.Account__c = parentId;

                                    grandChildrenToUpsert.add(pd);
                                }
                            }
                        }
                    }
                }

                System.debug(grandChildrenToUpsert);

                if (grandChildrenToUpsert.size() > 0) {
                    upsert grandChildrenToUpsert;
                }

            } else {
                System.debug('Error: ' + resp.getStatusCode() + ' ' + resp.getBody());
            }

        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        } finally {
            String body = resp.getBody();
            Integer maxLength = 10000;
            Integer safeLength = Math.min(body.length(), maxLength);
            UtilityCls.logApiCall('Customer_Master_API:' + String.valueOf(dateOfExc), '', '', resp != null ? body.substring(0, safeLength) : '', '', resp != null ? resp.getStatusCode() : 0);
        }
    }

    public static void getMaterialMaster() {
        HttpResponse resp;
        try {
            // Date dateOfExc = date.valueOf('2025-11-20');
            Date dateOfExc = Date.today();
            resp = UtilityCls.doGetWithBasicAuth('Material_Master_API', 'Daily', dateOfExc, dateOfExc, '');

            if (resp.getStatusCode() == 200) {
                IntegrationRequestBuilder.MaterialMasterResponse respWrapper = IntegrationRequestBuilder.MaterialMasterResponseParse(resp.getBody());
                List < IntegrationRequestBuilder.materialsList > parentWrappers = respWrapper.d.results;

                // Step 1: Get keys and existing records
                Set < String > productCodes = new Set < String > ();
                for (IntegrationRequestBuilder.materialsList m: parentWrappers) {
                    productCodes.add(m.item_no);
                }

                Map < String, Product2 > existingProductsMap = new Map < String, Product2 > ();
                for (Product2 p: [SELECT Id, ProductCode FROM Product2 WHERE ProductCode IN: productCodes]) {
                    existingProductsMap.put(p.ProductCode, p);
                }

                Map < String, Plant_Data__c > existingPlantMap = new Map < String, Plant_Data__c > ();
                Map < String, Id > parentCodeToIdMap = new Map < String, Id > ();

                List < Product2 > productsToUpsert = new List < Product2 > ();
                List < Plant_Data__c > plantsToUpsert = new List < Plant_Data__c > ();
                List < Sales_Area_Data__c > salesAreasToUpsert = new List < Sales_Area_Data__c > ();

                for (Plant_Data__c pd: [
                        SELECT Id, Product_Code__c, Plant__c FROM Plant_Data__c WHERE Product_Code__c IN: productCodes
                    ]) {
                    existingPlantMap.put(pd.Product_Code__c + '/' + pd.Plant__c, pd);
                }

                Map < String, Sales_Area_Data__c > existingSalesAreaMap = new Map < String, Sales_Area_Data__c > ();
                for (Sales_Area_Data__c sad: [
                        SELECT Id, Plant_Data__r.Product_Code__c, Plant_Data__r.Plant__c, Sales_Org__c, Distribution_Channel__c, Division__c
                        FROM Sales_Area_Data__c
                        WHERE Plant_Data__r.Product_Code__c IN: productCodes
                    ]) {
                    String key = sad.Plant_Data__r.Product_Code__c + '/' + sad.Plant_Data__r.Plant__c + '/' + sad.Sales_Org__c + '/' + sad.Distribution_Channel__c + '/' + sad.Division__c;
                    existingSalesAreaMap.put(key, sad);
                }

                // Step 2: Process Parents (Product2)
                for (IntegrationRequestBuilder.materialsList parent: parentWrappers) {
                    Product2 prod = existingProductsMap.containsKey(parent.item_no) ? existingProductsMap.get(parent.item_no) : new Product2();

                    prod.Name = parent.item_description;
                    prod.ProductCode = parent.item_no;
                    prod.Item_No__c = parent.item_no;
                    prod.Item_Description__c = parent.item_description;
                    prod.Description = parent.long_description + ' (' + String.valueOf(dateOfExc) + ')';
                    prod.Base_UOM__c = parent.base_uom;
                    prod.Mat_Group__c = parent.mat_group;
                    prod.SAP_Integration__c = true;
                    prod.SAP_Created_On_Date__c = Date.valueOf(parent.created_on_date);
                    prod.SAP_Changed_On_Date__c = Date.valueOf(parent.changed_on_date);

                    productsToUpsert.add(prod);
                }

                upsert productsToUpsert;
                for (Product2 p: productsToUpsert) {
                    parentCodeToIdMap.put(p.ProductCode, p.Id);
                }

                // Step 3: Process Children (Plant_Data__c)
                Map < String, Id > plantKeyToIdMap = new Map < String, Id > ();

                for (IntegrationRequestBuilder.materialsList parentWrapper: parentWrappers) {
                    String parentId = parentCodeToIdMap.get(parentWrapper.item_no);
                    if (parentWrapper.to_plant_data != null && parentId != null) {
                        for (IntegrationRequestBuilder.toPlantDataList childWrapper: parentWrapper.to_plant_data.results) {
                            String plantKey = parentWrapper.item_no + '/' + childWrapper.plant;

                            Plant_Data__c plant = existingPlantMap.containsKey(plantKey) ? existingPlantMap.get(plantKey) : new Plant_Data__c();

                            plant.Name = childWrapper.plant;
                            plant.Plant__c = childWrapper.plant;
                            plant.HSN_Code__c = childWrapper.hsn_code;
                            plant.Product__c = parentId;
                            plant.Product_Code__c = parentWrapper.item_no;

                            plantsToUpsert.add(plant);
                        }
                    }
                }

                upsert plantsToUpsert;
                for (Plant_Data__c p: plantsToUpsert) {
                    plantKeyToIdMap.put(p.Product_Code__c + '/' + p.Plant__c, p.Id);
                }

                // Step 4: Process Grandchildren (Sales_Area_Data__c)
                for (IntegrationRequestBuilder.materialsList parentWrapper: parentWrappers) {
                    if (parentWrapper.to_plant_data != null) {
                        for (IntegrationRequestBuilder.toPlantDataList childWrapper1: parentWrapper.to_plant_data.results) {
                            String plantId = plantKeyToIdMap.get(parentWrapper.item_no + '/' + childWrapper1.plant);
                            if (childWrapper1.to_salesarea_data != null && plantId != null) {
                                for (IntegrationRequestBuilder.salesAreaDataList grandchildWrapper: childWrapper1.to_salesarea_data.results) {
                                    String saKey = parentWrapper.item_no + '/' + childWrapper1.plant + '/' + grandchildWrapper.sales_org + '/' + grandchildWrapper.distribution_channel + '/' + grandchildWrapper.division;

                                    Sales_Area_Data__c sad = existingSalesAreaMap.containsKey(saKey) ? existingSalesAreaMap.get(saKey) : new Sales_Area_Data__c();

                                    sad.Name = grandchildWrapper.sales_org + '/' + grandchildWrapper.distribution_channel + '/' + grandchildWrapper.division;
                                    sad.Sales_Org__c = grandchildWrapper.sales_org;
                                    sad.Distribution_Channel__c = grandchildWrapper.distribution_channel;
                                    sad.Division__c = grandchildWrapper.division;
                                    sad.Plant_Data__c = plantId;

                                    salesAreasToUpsert.add(sad);
                                }
                            }
                        }
                    }
                }

                upsert salesAreasToUpsert;

            } else {
                System.debug('Error: ' + resp.getStatusCode() + ' ' + resp.getBody());
            }

        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        } finally {
            UtilityCls.logApiCall('Material_Master_API', '', '', resp != null ? resp.getBody() : '', '', resp != null ? resp.getStatusCode() : 0);
            // UtilityCls.logApiCall('Material_Master_API', '', '', '', '', resp != null ? resp.getStatusCode() : 0);
        }
    }

    public static void getSalesOrderMaster() {
        HttpResponse resp;
        try {
            // Date dateOfExc = date.valueOf('2025-09-18');
            Date dateOfExc = Date.today();
            resp = UtilityCls.doGetWithBasicAuth('Sales_Order_API', 'DAILY', dateOfExc, dateOfExc, '');
            if (resp.getStatusCode() == 200) {
                system.debug('resp' + resp.getBody());

                // Deserialize JSON response into wrapper class
                IntegrationRequestBuilder.SalesOrderMasterResponse respWrapper = IntegrationRequestBuilder.SalesOrderMasterResponseParse(resp.getBody());

                List < IntegrationRequestBuilder.salesordersList > parentWrappers = respWrapper.d.results;

                Set < String > salesOrderNumberSet = new Set < String > ();
                for (IntegrationRequestBuilder.salesordersList parent: parentWrappers) {
                    salesOrderNumberSet.add((String) parent.so_num);
                }

                // Lists for bulk DML
                // Set < String > accSet = new Set < String > ();
                Map < String, String > sonumMap = new Map < String, String > ();
                List < Order > existingParentList = [
                    SELECT Id, Name, SO_No__c
                    FROM Order
                    WHERE SO_No__c IN: salesOrderNumberSet
                ];
                for (Order acc: existingParentList) {
                    // accSet.add(acc.SO_No__c);
                    sonumMap.put(acc.SO_No__c, acc.Id);
                }
                List < Order > parentList = new List < Order > ();
                List < OrderItem > childList = new List < OrderItem > ();
                List < Price_Details__c > grandChildList = new List < Price_Details__c > ();

                // Maps to track relationships
                Map < String, Id > parentNameToIdMap = new Map < String, Id > ();
                Map < String, Id > childNameToIdMap = new Map < String, Id > ();
                Map < String, String > parentCurrency = new Map < String, String > ();

                Set < String > itemIds = new Set < String > ();
                Set < String > productCodeSet = new Set < String > ();
                Map < String, Id > accId = new Map < String, Id > ();
                List < Account > accList = new List < Account > ();
                List < Product2 > productList = new List < Product2 > ();

                // Example query to populate the map and list
                List < Order > orders = [SELECT Id, AccountId, Account.Name FROM Order WHERE Id IN: itemIds];

                // Assuming lineListdata is a list of Account objects
                for (IntegrationRequestBuilder.salesordersList parent: parentWrappers) {
                    //Map<String, Account> mpPick = (Map<String, Account>)pickList;
                    //  System.debug('Sold_To__c : ' + String.valueOf(parent.get('sold_to')));
                    if (String.valueOf(parent.sold_to) != '') {
                        itemIds.add(String.valueOf(parent.sold_to));
                    }
                    if (String.valueOf(parent.ship_to) != '') {
                        itemIds.add(String.valueOf(parent.ship_to));
                    }
                    if (String.valueOf(parent.bill_to) != '') {
                        itemIds.add(String.valueOf(parent.bill_to));
                    }

                    if (parent.to_item_details != null) {
                        if (parent.to_item_details.results != null) {
                            for (IntegrationRequestBuilder.itemDetailsList child: parent.to_item_details.results) {
                                productCodeSet.add(child.item_code);
                            }
                        }
                    }
                }

                // Get Account List
                accList = [SELECT id, SAP_Customer_Code__c FROM Account WHERE SAP_Customer_Code__c IN: itemIds];
                for (Account pHSN: accList) {
                    if (!accId.containsKey(pHSN.SAP_Customer_Code__c)) {
                        accId.put(pHSN.SAP_Customer_Code__c, pHSN.id);
                    }
                }

                // Get Product List --------------------
                productList = [
                    SELECT Id, Name, ProductCode
                    FROM Product2
                    WHERE ProductCode IN: productCodeSet
                ];

                Map < String, String > productIdMap = new Map < String, String > ();
                Set < String > productIdSet = new Set < String > ();
                for (Product2 p: productList) {
                    productIdMap.put(p.ProductCode, p.Id);
                    productIdSet.add(p.Id);
                }

                System.debug(productIdMap);
                System.debug(productIdSet);

                // Get Pricebook for create sales order -------------------------
                List < Pricebook2 > pbList = [
                    SELECT Id, Name, Distribution_Channel__c
                    FROM Pricebook2
                    WHERE Distribution_Channel__c != null
                ];

                Map < String, Object > pbMap = new Map < String, Object > ();
                Set < String > pbIdSet = new Set < String > ();
                for (Pricebook2 pb: pbList) {
                    pbMap.put(pb.Distribution_Channel__c, pb.Id);
                    pbIdSet.add(pb.Id);
                }

                System.debug(pbMap);
                System.debug(pbIdSet);

                // Create Sales Order data -----------------------
                for (IntegrationRequestBuilder.salesordersList parent: parentWrappers) {
                    // System.debug('parent.so_num : ' + parent.so_num);
                    // System.debug('parent : ' + parent);
                    // System.debug((String) accId.get(String.valueOf(parent.bill_to)));
                    String sAccId = (String) accId.get(String.valueOf(parent.sold_to));
                    Order pRecord = new Order();
                    pRecord.Status = 'Draft';
                    pRecord.SO_No__c = (String) parent.so_num;
                    //pRecord.AccountId = (String) parent.customer_name;
                    pRecord.AccountId = (String) accId.get(String.valueOf(parent.sold_to));
                    pRecord.SO_Type__c = (String) parent.so_type;
                    pRecord.Sold_To__c = (String) parent.sold_to;
                    pRecord.Ship_To__c = (String) parent.ship_to;
                    pRecord.Bill_To__c = (String) parent.bill_to;
                    pRecord.Cust_Ref__c = (String) parent.cust_ref;
                    pRecord.Cust_Ref_Date__c = Date.valueOf(parent.custref_date);
                    pRecord.EffectiveDate = Date.valueOf(parent.custref_date);
                    pRecord.Req_Del_Date__c = Date.valueOf(parent.reqdel_date);
                    pRecord.Sales_Org__c = (String) parent.sales_org;
                    pRecord.Distribution_Channel__c = (String) parent.distribution_channel;
                    pRecord.Division__c = (String) parent.division;
                    pRecord.Terms_Of_Payment__c = (String) parent.terms_of_payment;
                    pRecord.Incoterms__c = (String) parent.incoterms;
                    pRecord.Incoterms_Location__c = (String) parent.incoterms_location;
                    pRecord.Company__c = (String) parent.company;
                    pRecord.Status__c = (String) parent.status;
                    pRecord.Net_Value__c = (String) parent.net_value;
                    pRecord.SAP_Integration__c = true;
                    pRecord.CurrencyIsoCode = (String) parent.curr;
                    pRecord.Pricebook2Id = String.valueOf(pbMap.get(parent.distribution_channel));
                    if (sAccId != null && sAccId != '') {
                        // if (!accSet.contains((String) parent.so_num)) {
                        //     parentList.add(pRecord);
                        // }
                        if (sonumMap.containsKey((String) parent.so_num)) {
                            pRecord.Id = sonumMap.get((String) parent.so_num);
                        }
                        parentList.add(pRecord);
                    }
                }

                // Insert Parents and update mapping
                if (!parentList.isEmpty()) {
                    upsert parentList;
                    system.debug('Parent created');
                    for (Order parent: parentList) {
                        parentNameToIdMap.put(parent.SO_No__c, parent.Id);
                        parentCurrency.put(parent.SO_No__c, parent.CurrencyIsoCode);
                    }
                }

                System.debug(parentNameToIdMap);
                System.debug(parentCurrency);

                // Process Children
                for (IntegrationRequestBuilder.salesordersList parentWrapper: parentWrappers) {
                    String parentId = parentNameToIdMap.get(parentWrapper.so_num);
                    String curr = parentCurrency.get(parentWrapper.so_num);
                    if (parentWrapper.to_item_details != null) {
                        if (parentWrapper.to_item_details.results != null && parentId != null) {
                            for (IntegrationRequestBuilder.itemDetailsList childWrapper: parentWrapper.to_item_details.results) {
                                if (productIdMap.containsKey(childWrapper.item_code)) {
                                    System.debug(parentWrapper.distribution_channel);
                                    System.debug(String.valueOf(pbMap.get(parentWrapper.distribution_channel)));
                                    System.debug(childWrapper.item_code);
                                    System.debug(String.valueOf(productIdMap.get(childWrapper.item_code)));
                                    PricebookEntry pbe = [
                                        SELECT Id, CurrencyIsoCode
                                        FROM PricebookEntry
                                        WHERE Pricebook2Id =: String.valueOf(pbMap.get(parentWrapper.distribution_channel))
                                        AND Product2Id =: String.valueOf(productIdMap.get(childWrapper.item_code))
                                        AND CurrencyIsoCode =: curr
                                        AND IsActive = true
                                        LIMIT 1
                                    ];
                                    OrderItem cRecord = new OrderItem();
                                    cRecord.Item_No__c = childWrapper.item_no;
                                    cRecord.Item_Code__c = childWrapper.item_code;
                                    cRecord.Description = childWrapper.item_desc;
                                    cRecord.Quantity = Decimal.valueOf(childWrapper.item_qty);
                                    cRecord.UOM__c = childWrapper.uom;
                                    cRecord.Plant__c = childWrapper.plant;
                                    cRecord.Pdd_Dat__c = childWrapper.pdd_dat;
                                    cRecord.It_Status__c = childWrapper.it_status;
                                    cRecord.Product2Id = String.valueOf(productIdMap.get(childWrapper.item_code));
                                    cRecord.PricebookEntryId = pbe.Id;
                                    cRecord.UnitPrice = Decimal.valueOf(childWrapper.net_price);
                                    cRecord.Tax_Amount__c = Decimal.valueOf(childWrapper.tax_amount);
                                    cRecord.OrderId = parentId; // lookup ID
                                    System.debug(cRecord);
                                    childList.add(cRecord);
                                }
                            }
                        }
                    }
                }
                // Insert Children and update mapping
                if (!childList.isEmpty()) {
                    insert childList;
                    system.debug('child created');
                    for (OrderItem child: childList) {
                        childNameToIdMap.put(child.Item_No__c, child.Id);
                    }
                }

                // Process Grandchildren
                for (IntegrationRequestBuilder.salesordersList parentWrapper: parentWrappers) {
                    if (parentWrapper.to_item_details != null) {
                        if (parentWrapper.to_item_details.results != null) {
                            for (IntegrationRequestBuilder.itemDetailsList childWrapper: parentWrapper.to_item_details.results) {
                                Id childId = childNameToIdMap.get(childWrapper.item_no);
                                if (childWrapper.to_price_details != null) {
                                    for (IntegrationRequestBuilder.priceDetailsList grandchildWrapper: childWrapper.to_price_details.results) {
                                        Price_Details__c gcRecord = new Price_Details__c(
                                            Cond_Type__c = grandchildWrapper.cond_type,
                                            Unit_Amount__c = Decimal.valueOf(grandchildWrapper.unit_amount),
                                            Unit__c = grandchildWrapper.unit,
                                            Amount__c = Decimal.valueOf(grandchildWrapper.amount),
                                            CurrencyIsoCode = grandchildWrapper.curr,
                                            Order_Product__c = childId // lookup Id
                                        );
                                        grandChildList.add(gcRecord);
                                    }
                                }
                            }
                        }
                    }
                }
                // Insert Grandchildren
                if (!grandChildList.isEmpty()) {
                    insert grandChildList;
                    system.debug('grandchild created');
                }

            } else {
                System.debug('Error: ' + resp.getStatusCode() + ' ' + resp.getBody());
            }

        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage() + ' || ' + e.getLineNumber());
        } finally {
            // Log the API call
            if (resp != null) {
                UtilityCls.logApiCall('Sales_Order_API', '', '', resp.getBody(), '', resp.getStatusCode());
            } else {
                UtilityCls.logApiCall('Sales_Order_API', '', '', '', 'No response from API', 0);
            }
        }

    }

    public static void getInvoiceMaster() {

        HttpResponse resp;
        try {
            // Date dateOfExc = date.valueOf('2025-04-28');
            Date dateOfExc = Date.today();
            resp = UtilityCls.doGetWithBasicAuth('Invoice_API', 'DAILY', dateOfExc, dateOfExc, '');
            if (resp.getStatusCode() == 200) {
                system.debug('resp' + resp.getBody());
                // Deserialize JSON response into wrapper class
                IntegrationRequestBuilder.InvoiceMasterResponse respWrapper = IntegrationRequestBuilder.InvoiceMasterResponseParse(resp.getBody());
                system.debug(respWrapper);
                List < IntegrationRequestBuilder.invoiceList > parentWrappers = respWrapper.d.results;

                Set < String > billDocSet = new Set < String > ();
                for (IntegrationRequestBuilder.invoiceList parent: parentWrappers) {
                    billDocSet.add((String) parent.bill_docnum);
                }

                // Lists for bulk DML
                Set < String > accSet = new Set < String > ();
                List < SO_Invoice__c > existingParentList = [
                    SELECT Id, Name, Bill_Doc_No__c
                    FROM SO_Invoice__c
                    WHERE Bill_Doc_No__c IN: billDocSet
                ];

                for (SO_Invoice__c acc: existingParentList) {
                    accSet.add(acc.Bill_Doc_No__c);
                }
                List < SO_Invoice__c > parentList = new List < SO_Invoice__c > ();
                List < Invoice_Line_item__c > childList = new List < Invoice_Line_item__c > ();
                List < Price_Details__c > grandChildList = new List < Price_Details__c > ();

                // Maps to track relationships
                Map < String, Id > parentNameToIdMap = new Map < String, Id > ();
                Map < String, Id > childNameToIdMap = new Map < String, Id > ();

                for (IntegrationRequestBuilder.invoiceList parent: parentWrappers) {
                    System.debug('parent.bill_docnum : ' + parent.bill_docnum);
                    SO_Invoice__c pRecord = new SO_Invoice__c();
                    pRecord.Bill_Doc_No__c = (String) parent.bill_docnum;
                    pRecord.Bill_Doc_Type__c = (String) parent.bill_doctype;
                    //pRecord.Bill_Date__c = Date.ValueOf(parent.bill_date);// need to format
                    pRecord.Acc_Doc_No__c = (String) parent.acc_docnum;
                    pRecord.Zyear__c = (String) parent.zyear;
                    pRecord.SO_No__c = (String) parent.so_num;
                    pRecord.Terms_Of_Payment__c = (String) parent.terms_of_payment;
                    pRecord.Incoterms__c = (String) parent.incoterms;
                    pRecord.Incoterms_Location__c = (String) parent.incoterms_location;
                    pRecord.Company__c = (String) parent.company;
                    pRecord.CurrencyIsoCode = (String) parent.curr;
                    pRecord.Sold_To__c = (String) parent.sold_to;
                    pRecord.Payer__c = (String) parent.payer;
                    pRecord.Bill_To__c = (String) parent.bill_to;
                    pRecord.Sales_Org__c = (String) parent.sales_org;
                    pRecord.Distribution_Channel__c = (String) parent.distribution_channel;
                    pRecord.Division__c = (String) parent.division;
                    pRecord.Net_Value__c = Decimal.valueof(parent.net_value);
                    pRecord.Tax_Value__c = Decimal.valueof(parent.tax_value);
                    pRecord.Exc_Rate__c = Decimal.valueof(parent.exc_rate);
                    pRecord.SAP_Integration__c = true;
                    if (!accSet.contains((String) parent.bill_docnum)) {
                        parentList.add(pRecord);
                    }
                }

                // Insert Parents and update mapping
                if (!parentList.isEmpty()) {
                    insert parentList;
                    system.debug('Parent created');
                    for (SO_Invoice__c parent: parentList) {
                        parentNameToIdMap.put(parent.Bill_Doc_No__c, parent.Id);
                    }
                }

                // Process Children
                for (IntegrationRequestBuilder.invoiceList parentWrapper: parentWrappers) {
                    String parentId = parentNameToIdMap.get(parentWrapper.bill_docnum);
                    if (parentWrapper.to_item_details != null) {
                        for (IntegrationRequestBuilder.invItemDetailsList childWrapper: parentWrapper.to_item_details.results) {
                            Invoice_Line_item__c cRecord = new Invoice_Line_item__c();
                            cRecord.Item_No__c = childWrapper.item_no;
                            cRecord.Item_Code__c = childWrapper.item_code;
                            cRecord.Product_Description__c = childWrapper.item_desc;
                            cRecord.QTY__c = Decimal.ValueOf(childWrapper.item_qty);
                            cRecord.UOM__c = childWrapper.uom;
                            cRecord.Plant__c = childWrapper.plant;
                            cRecord.Unit_Price__c = Decimal.ValueOf(childWrapper.net_amount);
                            cRecord.GST_Amount__c = Decimal.ValueOf(childWrapper.tax_amount);
                            cRecord.Line_Amount__c = Decimal.ValueOf(childWrapper.net_price);
                            cRecord.SO_Invoice__c = parentId; // lookup ID 
                            if (parentId != null && parentId != '') {
                                childList.add(cRecord);
                            }
                        }
                    }
                }
                // Insert Children and update mapping
                if (!childList.isEmpty()) {
                    insert childList;
                    system.debug('child created');
                    for (Invoice_Line_item__c child: childList) {
                        childNameToIdMap.put(child.Item_No__c, child.Id);
                    }
                }

                // Process Grandchildren
                for (IntegrationRequestBuilder.invoiceList parentWrapper: parentWrappers) {
                    if (parentWrapper.to_item_details != null) {
                        for (IntegrationRequestBuilder.invItemDetailsList childWrapper: parentWrapper.to_item_details.results) {
                            String childId = childNameToIdMap.get(childWrapper.item_no);
                            if (childWrapper.to_price_details != null) {
                                for (IntegrationRequestBuilder.invPriceDetailsList grandchildWrapper: childWrapper.to_price_details.results) {
                                    Price_Details__c gcRecord = new Price_Details__c(
                                        Cond_Type__c = grandchildWrapper.cond_type,
                                        Unit_Amount__c = Decimal.valueOf(grandchildWrapper.unit_amount),
                                        Unit__c = grandchildWrapper.unit,
                                        Amount__c = Decimal.valueOf(grandchildWrapper.amount),
                                        CurrencyIsoCode = grandchildWrapper.curr,
                                        Invoice_Line_item__c = childId // lookup Id
                                    );
                                    if (childId != null && childId != '') {
                                        grandChildList.add(gcRecord);
                                    }
                                }
                            }
                        }
                    }
                }
                // Insert Grandchildren
                if (!grandChildList.isEmpty()) {
                    insert grandChildList;
                    system.debug('grandchild created');
                }

            } else {
                System.debug('Error: ' + resp.getStatusCode() + ' ' + resp.getBody());
            }

        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        } finally {
            // Log the API call
            UtilityCls.logApiCall('Invoice_API', '', '', resp.getBody(), '', resp.getStatusCode());
        }

    }

    public static void ClearingpaymentMaster() {
        HttpResponse resp;
        try {
            // Date dateOfExc = date.valueOf('2024-07-08');
            Date dateOfExc = Date.today();
            resp = UtilityCls.doGetWithBasicAuth('Clearing_Payment_API', 'DAILY', dateOfExc, dateOfExc, '');
            if (resp.getStatusCode() == 200) {
                system.debug('resp' + resp.getBody());
                // Deserialize JSON response into wrapper class
                IntegrationRequestBuilder.ClearingPaymentMasterResponse respWrapper = IntegrationRequestBuilder.ClearingPaymentMasterResponseParse(resp.getBody());

                List < IntegrationRequestBuilder.clearPaymentList > parentWrappers = respWrapper.d.results;

                // Lists for bulk DML
                Set < String > accSet = new Set < String > ();
                List < Collection__c > existingParentList = [
                    SELECT Id, Name, Reference_Doc__c, Customer__c
                    FROM Collection__c
                ];
                for (Collection__c acc: existingParentList) {
                    accSet.add(acc.Reference_Doc__c + acc.Customer__c);
                }
                List < Collection__c > parentList = new List < Collection__c > ();
                List < Clearing_Payment__c > childList = new List < Clearing_Payment__c > ();
                //  List<Sales_Area_Data__c> grandChildList = new List<Sales_Area_Data__c>();

                // Maps to track relationships
                Map < String, String > parentNameToIdMap = new Map < String, String > ();
                Map < String, Id > childNameToIdMap = new Map < String, Id > ();

                // Process Parents
                for (IntegrationRequestBuilder.clearPaymentList parent: parentWrappers) {
                    Collection__c pRecord = new Collection__c();
                    pRecord.Company_Code__c = (String) parent.company_code;
                    pRecord.Fiscal_Year__c = (String) parent.fiscal_year;
                    pRecord.Document_No__c = (String) parent.document_no;
                    //pRecord.Account_Type__c = (String) parent.account_type;
                    pRecord.Reference_Doc__c = (String) parent.reference_doc;
                    // pRecord.Amount_In_Tra_Cur__c = (String) parent.amount_in_tra_cur;
                    pRecord.Posting_Date__c = Date.Valueof(parent.posting_date);
                    pRecord.Document_Date__c = Date.Valueof(parent.document_date);
                    //pRecord.Document_Type__c = (String) parent.document_type;
                    pRecord.Invoice_Ref__c = (String) parent.invoice_ref;
                    pRecord.Customer__c = (String) parent.customer;
                    pRecord.Clearing_Doc__c = (String) parent.clearing_doc;
                    pRecord.Clearing_Date__c = Date.Valueof(parent.clearing_date);
                    pRecord.SAP_Integration__c = true;
                    pRecord.Changed_On__c = (String) parent.changed_on;
                    // parentList.add(pRecord);
                    if (!accSet.contains((String) parent.reference_doc + (String) parent.customer)) {
                        parentList.add(pRecord);
                    }
                }
                // Insert Parents and update mapping
                if (!parentList.isEmpty()) {
                    insert parentList;
                    system.debug('parent created');
                    for (Collection__c parent: parentList) {
                        parentNameToIdMap.put(parent.Reference_Doc__c + parent.Customer__c, parent.Id);
                    }
                }
                // Process Children
                for (IntegrationRequestBuilder.clearPaymentList parentWrapper: parentWrappers) {
                    String parentId = parentNameToIdMap.get(parentWrapper.reference_doc + parentWrapper.customer);
                    System.debug('ClearingpaymentMaster parentId:>> ' + parentId);
                    if (parentWrapper.to_clearing_payment != null) {
                        for (IntegrationRequestBuilder.clearingPaymentList childWrapper: parentWrapper.to_clearing_payment.results) {
                            Clearing_Payment__c cRecord = new Clearing_Payment__c(
                                Company_Code__c = childWrapper.c_company_code,
                                Fiscal_Year__c = childWrapper.c_fiscal_year,
                                Document_No__c = childWrapper.c_document_no,
                                //Reference_Doc__c = childWrapper.c_reference_doc,
                                Clearing_Payment__c = childWrapper.clearing_payment,
                                Posting_Date__c = Date.Valueof(childWrapper.c_posting_date),
                                //Document_Date__c = Date.Valueof(childWrapper.c_document_date),
                                Invoice_Ref__c = childWrapper.c_invoice_ref,
                                Customer__c = childWrapper.c_customer,
                                //Payment_Status__c = childWrapper.PaymentStatus,
                                Clearing_Doc__c = childWrapper.c_clearing_doc,
                                Clearing_Date__c = Date.Valueof(childWrapper.c_clearing_date),
                                Collection__c = parentId // lookup ID 
                            );
                            if (parentId != null && parentId != '') {
                                childList.add(cRecord);
                            }
                        }
                    }
                }
                // Insert Children and update mapping
                if (!childList.isEmpty()) {
                    insert childList;
                    system.debug('child created');
                    for (Clearing_Payment__c child: childList) {
                        childNameToIdMap.put(child.Company_Code__c, child.Id);
                    }
                }

            } else {
                System.debug('Error: ' + resp.getStatusCode() + ' ' + resp.getBody());
            }

        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        } finally {
            // Log the API call
            UtilityCls.logApiCall('Clearing_Payment_API', '', '', resp.getBody(), '', resp.getStatusCode());
        }

    }

    public static void CustomerGlMaster() {
        HttpResponse resp;
        try {
            // Date dateOfExc = date.valueOf('2025-04-28');
            Date dateOfExc = Date.today();
            resp = UtilityCls.doGetWithBasicAuth('Customer_GL_API', 'DAILY', dateOfExc, dateOfExc, '');
            if (resp.getStatusCode() == 200) {
                system.debug('resp' + resp.getBody());

                // Deserialize JSON response into wrapper class
                IntegrationRequestBuilder.CustomerGlMasterResponse respWrapper = IntegrationRequestBuilder.CustomerGlMasterResponseParse(resp.getBody());

                List < IntegrationRequestBuilder.customerGLList > parentWrappers = respWrapper.d.results;

                // Lists for bulk DML
                Set < String > accSet = new Set < String > ();
                List < Customer_Ledger__c > existingParentList = [
                    SELECT Id, Name, Customer__c, Company_Code__c, Document_No__c, Special_GL_Indicator__c, Total_Amount__c, Document_Type__c
                    FROM Customer_Ledger__c
                ];
                for (Customer_Ledger__c acc: existingParentList) {
                    String sgi = acc.Special_GL_Indicator__c == null ? '' : acc.Special_GL_Indicator__c;
                    String str = acc.Customer__c + '' + acc.Company_Code__c + '' + acc.Document_No__c + '' + sgi + '' + acc.Total_Amount__c + '' + acc.Document_Type__c;
                    // System.debug(str);
                    accSet.add(str);
                }
                // System.debug(accSet);
                List < Customer_Ledger__c > parentList = new List < Customer_Ledger__c > ();
                List < Clearing_Payment__c > childList = new List < Clearing_Payment__c > ();
                //   List<Sales_Area_Data__c> grandChildList = new List<Sales_Area_Data__c>();

                Map < String, Id > parentNameToIdMap = new Map < String, Id > ();
                Map < String, Id > childNameToIdMap = new Map < String, Id > ();

                // Process Parents
                for (IntegrationRequestBuilder.customerGLList parent: parentWrappers) {
                    Customer_Ledger__c pRecord = new Customer_Ledger__c();
                    pRecord.Name = (String) parent.document_no;
                    pRecord.Fiscal_Year__c = (String) parent.fiscal_year;
                    pRecord.Customer__c = (String) parent.customer;
                    pRecord.Company_Code__c = (String) parent.company_code;
                    pRecord.Document_No__c = (String) parent.document_no;
                    pRecord.Reference_Doc__c = (String) parent.reference_doc;
                    // pRecord.Account_Type__c = (String) parent.account_type;
                    // pRecord.Amount_In_Tra_Cur__c = (String) parent.amount_in_tra_cur;
                    pRecord.Total_Amount__c = Decimal.Valueof(parent.total_amount);
                    pRecord.Posting_Date__c = Date.Valueof(parent.posting_date);
                    pRecord.Document_Date__c = Date.Valueof(parent.document_date);
                    pRecord.Document_Type__c = (String) parent.document_type;
                    pRecord.Special_GL_Indicator__c = (String) parent.special_gl_indicator;
                    //pRecord.Invoice_Ref__c = (String) parent.invoice_ref;
                    pRecord.Clearing_Doc__c = (String) parent.clearing_doc;
                    if (parent.clearing_date != '0000-00-00') {
                        pRecord.Clearing_Date__c = Date.Valueof(parent.clearing_date);
                    }
                    pRecord.Changed_On__c = (String) parent.changed_on;
                    pRecord.SAP_Integration__c = true;
                    String str = (String) parent.customer + '' + (String) parent.company_code + '' + (String) parent.document_no + '' + (String) parent.special_gl_indicator + '' + (String) parent.total_amount + '' + (String) parent.document_type;
                    // System.debug(str);
                    if (!accSet.contains(str)) {
                        parentList.add(pRecord);
                    }
                }
                // Insert Parents and update mapping
                if (!parentList.isEmpty()) {
                    insert parentList;
                    system.debug('parent created');
                    for (Customer_Ledger__c parent: parentList) {
                        parentNameToIdMap.put(parent.Name, parent.Id);
                    }
                }
                // Process Children
                for (IntegrationRequestBuilder.customerGLList parentWrapper: parentWrappers) {
                    String parentId = parentNameToIdMap.get(parentWrapper.document_no);
                    if (parentWrapper.to_clearing_payment != null) {
                        for (IntegrationRequestBuilder.clearingPayList childWrapper: parentWrapper.to_clearing_payment.results) {
                            Clearing_Payment__c cRecord = new Clearing_Payment__c(
                                Company_Code__c = childWrapper.c_company_code,
                                Fiscal_Year__c = childWrapper.c_fiscal_year,
                                Document_No__c = childWrapper.c_document_no,
                                //Reference_Doc__c = childWrapper.c_reference_doc,
                                Clearing_Payment__c = childWrapper.clearing_payment,
                                Posting_Date__c = Date.Valueof(childWrapper.c_posting_date),
                                //Document_Date__c = Date.Valueof(childWrapper.c_document_date),
                                Invoice_Ref__c = childWrapper.c_invoice_ref,
                                Customer__c = childWrapper.c_customer,
                                //Payment_Status__c = childWrapper.PaymentStatus,
                                Clearing_Doc__c = childWrapper.c_clearing_doc,
                                Clearing_Date__c = Date.Valueof(childWrapper.c_clearing_date),
                                Customer_Ledger__c = parentId // lookup ID 
                            );
                            // childList.add(cRecord);
                            if (parentId != null && parentId != '') {
                                childList.add(cRecord);
                            }
                        }
                    }
                }
                // Insert Children and update mapping
                if (!childList.isEmpty()) {
                    insert childList;
                    system.debug('child created');
                    for (Clearing_Payment__c child: childList) {
                        childNameToIdMap.put(child.Company_Code__c, child.Id);
                    }
                }
                // Process Grandchildren
                /*       for (IntegrationRequestBuilder.customerGLList parentWrapper : parentWrappers) {
                           if (parentWrapper.to_clearing_payment != null) {
                               for (IntegrationRequestBuilder.toPlantDataList childWrapper1 : parentWrapper.to_clearing_payment.results) {
                                   Id childId = childNameToIdMap.get(childWrapper1.plant);
                                   if (childWrapper1.to_salesarea_data != null) {
                                       for (IntegrationRequestBuilder.salesAreaDataList grandchildWrapper : childWrapper1.to_salesarea_data.results) {
                                           Sales_Area_Data__c gcRecord = new Sales_Area_Data__c(
                                               Name = grandchildWrapper.sales_org+'-'+grandchildWrapper.distribution_channel+'-'+grandchildWrapper.division,
                                               Sales_Org__c = grandchildWrapper.sales_org,
                                               Distribution_Channel__c = grandchildWrapper.distribution_channel,
                                               Division__c = grandchildWrapper.division,
                                               Plant_Data__c = childId  // lookup Id
                                           );
                                           grandChildList.add(gcRecord);
                                       }
                                   }
                               }
                           }
                       }
                       
                       // Insert Grandchildren
                       if (!grandChildList.isEmpty()) {
                           insert grandChildList;
                           system.debug('grandchild created');
                       } */

            } else {
                System.debug('Error: ' + resp.getStatusCode() + ' ' + resp.getBody());
            }

        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage() + ' || ' + e.getLineNumber());
        } finally {
            // Log the API call
            UtilityCls.logApiCall('Customer_GL_API', '', '', resp.getBody(), '', resp.getStatusCode());
        }

    }

    public static void PricingMaster(String pCode) {
        HttpResponse resp;
        try {
            // Date dateOfExc = date.valueOf('2024-07-08');
            Date dateOfExc = Date.today();
            resp = UtilityCls.doGetWithBasicAuth('Pricing_Master_API', 'DAILY', dateOfExc, dateOfExc, pCode);
            if (resp.getStatusCode() == 200) {
                system.debug('resp' + resp.getBody());

                List < PricebookEntry > upsertPBElist = new List < PricebookEntry > ();
                Set < String > productCodeSet = new Set < String > ();

                // Deserialize JSON response into wrapper class
                IntegrationRequestBuilder.pricingMasterMainResponse respWrapper = IntegrationRequestBuilder.pricingMasterMainResponseParse(resp.getBody());
                List < IntegrationRequestBuilder.pricingMasterList > parentWrappers = respWrapper.d.results;
                for (IntegrationRequestBuilder.pricingMasterList parent: parentWrappers) {
                    productCodeSet.add(parent.Material);
                }

                List < Product2 > productList = [
                    SELECT Id, Name, ProductCode
                    FROM Product2
                    WHERE ProductCode IN: productCodeSet
                ];

                Map < String, String > productIdMap = new Map < String, String > ();
                Set < String > productIdSet = new Set < String > ();
                for (Product2 p: productList) {
                    productIdMap.put(p.ProductCode, p.Id);
                    productIdSet.add(p.Id);
                }

                System.debug(productIdMap);

                List < Pricebook2 > pricebookList = [SELECT Id, Name, Distribution_Channel__c FROM Pricebook2 WHERE Distribution_Channel__c != null];

                Map < String, String > pbMap = new Map < String, String > ();
                for (Pricebook2 pb: pricebookList) {
                    pbMap.put(pb.Distribution_Channel__c, pb.Id);
                }

                List < PricebookEntry > existingPBEList = [
                    SELECT Id, Name, CurrencyIsoCode, ProductCode, Distribution_Channel__c, Sales_Org__c, Valid_From__c,
                    Valid_To__c, Pricing_Unit__c, UnitPrice, Unit_of_Measure__c
                    FROM PricebookEntry
                    WHERE Product2Id =: productIdSet
                    AND Distribution_Channel__c != null
                ];

                Map < String, String > pbeListMap = new Map < String, String > ();

                for (PricebookEntry pbe: existingPBEList) {
                    String mapLabel = pbe.ProductCode + '_' + pbe.Sales_Org__c + '_' + pbe.Distribution_Channel__c + '_' + pbe.CurrencyIsoCode;
                    pbeListMap.put(mapLabel, pbe.Id);
                }

                // System.debug(pbeListMap);

                for (IntegrationRequestBuilder.pricingMasterList parent: parentWrappers) {
                    if (productIdMap.containsKey(parent.Material)) {
                        // System.debug(parent);
                        String getMapLabel = parent.Material + '_' + parent.Sales_Org + '_' + parent.Distribution_Channel + '_' + parent.Codition_Curr;
                        PricebookEntry upsertPBE = new PricebookEntry();
                        if (pbeListMap.containsKey(getMapLabel)) {
                            System.debug('YESSSSS');
                            upsertPBE.Id = pbeListMap.get(getMapLabel);
                        } else {
                            System.debug('NOOOOO');
                            upsertPBE.Pricebook2Id = pbMap.get(parent.Distribution_Channel);
                            upsertPBE.Product2Id = productIdMap.get(parent.Material);
                            upsertPBE.Sales_Org__c = parent.Sales_Org;
                            upsertPBE.Distribution_Channel__c = parent.Distribution_Channel;
                            upsertPBE.CurrencyIsoCode = parent.Codition_Curr;
                            upsertPBE.IsActive = true;
                            upsertPBE.UseStandardPrice = false;
                        }
                        upsertPBE.UnitPrice = Decimal.valueOf(parent.Condition_Amt);
                        upsertPBE.Pricing_Unit__c = Decimal.valueOf(parent.Pricing_Unit);
                        upsertPBE.Unit_of_Measure__c = parent.Unit_of_Measure;
                        upsertPBE.Valid_From__c = Date.valueOf(parent.Valid_from);
                        if (String.isNotBlank(parent.Valid_TO) && parent.Valid_TO.contains('9999')) {
                            upsertPBE.Valid_To__c = Date.valueOf('2030-12-31');
                        } else {
                            upsertPBE.Valid_To__c = Date.valueOf(parent.Valid_TO);
                        }
                        upsertPBElist.add(upsertPBE);
                        System.debug(upsertPBE);
                    } else {
                        System.debug('Product ' + parent.Material + 'Not Found in SF system');
                    }
                }
                if (upsertPBElist.size() > 0) {
                    upsert upsertPBElist;
                }
            }
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        } finally {
            // Log the API call
            UtilityCls.logApiCall('Pricing_Master_API', '', '', resp.getBody(), '', resp.getStatusCode());
        }
    }

    public static void DiscountMaster() {
        HttpResponse resp;
        try {
            // Date dateOfExc = date.valueOf('2024-07-08');
            Date dateOfExc = Date.today();
            resp = UtilityCls.doGetWithBasicAuth('Discount_Master_API', 'DAILY', dateOfExc, dateOfExc, '');
            if (resp.getStatusCode() == 200) {
                system.debug('resp' + resp.getBody());

                // Deserialize JSON response into wrapper class
                IntegrationRequestBuilder.discountMasterMainResponse respWrapper = IntegrationRequestBuilder.discountMasterMainResponseParse(resp.getBody());

                List < IntegrationRequestBuilder.discountMasterList > parentWrappers = respWrapper.d.results;

                Map < String, String > customerCodeMap = new Map < String, String > ();

                Set < String > customerCodeSet = new Set < String > ();
                for (IntegrationRequestBuilder.discountMasterList parent: parentWrappers) {
                    customerCodeSet.add(parent.Customer);
                }

                List < Account > existingAccList = [
                    SELECT Id, Name, SAP_Customer_Code__c
                    FROM Account
                    WHERE SAP_Customer_Code__c IN: customerCodeSet
                ];

                for (Account acc: existingAccList) {
                    customerCodeMap.put(acc.SAP_Customer_Code__c, acc.Id);
                }

                List < Account > accToUpdatelist = new List < Account > ();

                for (IntegrationRequestBuilder.discountMasterList parent: parentWrappers) {
                    if (customerCodeMap.containsKey(parent.Customer)) {
                        Account accToUpdate = new Account();
                        accToUpdate.Id = customerCodeMap.get(parent.Customer);
                        accToUpdate.Discount_Valid_From__c = Date.valueOf(parent.Valid_from);
                        accToUpdate.Discount__c = Decimal.valueOf(parent.condition_amt);
                        if (String.isNotBlank(parent.Valid_TO) && parent.Valid_TO.contains('9999')) {
                            accToUpdate.Discount_Valid_To__c = Date.valueOf('2030-12-31');
                        } else {
                            accToUpdate.Discount_Valid_To__c = Date.valueOf(parent.Valid_TO);
                        }
                        accToUpdatelist.add(accToUpdate);
                    } else {
                        System.debug('Customer ' + parent.Customer + ' Not Found in SF system');
                    }
                }
                if (accToUpdatelist.size() > 0) {
                    update accToUpdatelist;
                }
            }
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        } finally {
            // Log the API call
            UtilityCls.logApiCall('Discount_Master_API', '', '', resp.getBody(), '', resp.getStatusCode());
        }
    }

    public static void ARCPricingMaster(String sapCode) {
        HttpResponse resp;
        try {
            // Date dateOfExc = date.valueOf('2024-07-08');
            Date dateOfExc = Date.today();
            resp = UtilityCls.doGetWithBasicAuth('ARCPricing_Master_API', 'DAILY', dateOfExc, dateOfExc, sapCode);
            if (resp.getStatusCode() == 200) {
                system.debug('resp' + resp.getBody());

                Set < String > custSAPCode = new Set < String > ();
                Set < String > productCode = new Set < String > ();

                // Deserialize JSON response into wrapper class
                IntegrationRequestBuilder.arcPricingMasterMainResponse respWrapper = IntegrationRequestBuilder.arcPricingMasterMainResponseParse(resp.getBody());
                List < IntegrationRequestBuilder.arcPricingMasterList > parentWrappers = respWrapper.d.results;

                for (IntegrationRequestBuilder.arcPricingMasterList parent: parentWrappers) {
                    custSAPCode.add(parent.Customer);
                    productCode.add(parent.Material);
                }

                // Get existing ARC Pricing List
                Map < String, String > arcPricingMap = new Map < String, String > ();

                List < Customer_ARC_Pricing__c > existingARClist = [
                    SELECT Id, Name, Amount__c, Customer__c, Distribution_Channel__c, Material__c, Pricing_Unit__c, Sales_Organization__c,
                    Unit_of_Measure__c, Valid_From__c, Valid_To__c, Customer__r.SAP_Customer_Code__c, Material__r.ProductCode
                    FROM Customer_ARC_Pricing__c
                    WHERE Customer__r.SAP_Customer_Code__c IN: custSAPCode
                ];

                // for (Customer_ARC_Pricing__c p : existingARClist) {
                //     String mapLabel = p.Customer__r.SAP_Customer_Code__c+p.Material__r.ProductCode+p.Sales_Organization__c+p.Distribution_Channel__c;
                //     arcPricingMap.put(mapLabel,p.Id);
                // }

                // Get Existing Customers
                Map < String, String > customerCodeMap = new Map < String, String > ();

                List < Account > existingAccList = [
                    SELECT Id, Name, SAP_Customer_Code__c
                    FROM Account
                    WHERE SAP_Customer_Code__c IN: custSAPCode
                ];

                for (Account acc: existingAccList) {
                    customerCodeMap.put(acc.SAP_Customer_Code__c, acc.Id);
                }

                // Get Existing Material
                Map < String, String > productCodeMap = new Map < String, String > ();

                List < Product2 > existingProductList = [
                    SELECT Id, Name, ProductCode
                    FROM Product2
                    WHERE ProductCode IN: productCode
                ];

                for (Product2 p: existingProductList) {
                    productCodeMap.put(p.ProductCode, p.Id);
                }

                List < Customer_ARC_Pricing__c > upsertARCList = new List < Customer_ARC_Pricing__c > ();

                // Deserialize JSON response into wrapper class
                // IntegrationRequestBuilder.arcPricingMasterMainResponse respWrapper = IntegrationRequestBuilder.arcPricingMasterMainResponseParse(resp.getBody());

                // List < IntegrationRequestBuilder.arcPricingMasterList > parentWrappers = respWrapper.d.results;

                for (IntegrationRequestBuilder.arcPricingMasterList parent: parentWrappers) {
                    // if (!customerCodeMap.containsKey(parent.Customer)) {
                    //     System.debug('Customer '+parent.Customer+' not found');
                    // } else if (!productCodeMap.containsKey(parent.Material)) {
                    //     System.debug('Material '+parent.Material+' not found');
                    // } else {
                    // }
                    Customer_ARC_Pricing__c upsertARC = new Customer_ARC_Pricing__c();
                    upsertARC.Customer__c = customerCodeMap.get(parent.Customer);
                    upsertARC.Material__c = productCodeMap.get(parent.Material);
                    upsertARC.Material_Code__c = parent.Material;
                    upsertARC.Sales_Organization__c = parent.Sales_Org;
                    upsertARC.Distribution_Channel__c = parent.Distribution_Channel;
                    upsertARC.Unit_of_Measure__c = parent.Unit_of_Measure;
                    upsertARC.CurrencyIsoCode = parent.Codition_Curr;
                    upsertARC.Scale_Qty1__c = Decimal.valueOf(parent.Scale_Qty1);
                    upsertARC.Scale_Amt1__c = Decimal.valueOf(parent.Scale_Amt1);
                    upsertARC.Scale_Qty2__c = Decimal.valueOf(parent.Scale_Qty2);
                    upsertARC.Scale_Amt2__c = Decimal.valueOf(parent.Scale_Amt2);
                    upsertARC.Scale_Qty3__c = Decimal.valueOf(parent.Scale_Qty3);
                    upsertARC.Scale_Amt3__c = Decimal.valueOf(parent.Scale_Amt3);
                    upsertARC.Scale_Qty4__c = Decimal.valueOf(parent.Scale_Qty4);
                    upsertARC.Scale_Amt4__c = Decimal.valueOf(parent.Scale_Amt4);
                    upsertARC.Scale_Qty5__c = Decimal.valueOf(parent.Scale_Qty5);
                    upsertARC.Scale_Amt5__c = Decimal.valueOf(parent.Scale_Amt5);
                    upsertARC.Amount__c = Decimal.valueOf(parent.Condition_Amt);
                    upsertARC.Valid_From__c = Date.valueOf(parent.Valid_from);
                    if (String.isNotBlank(parent.Valid_TO) && parent.Valid_TO.contains('9999')) {
                        upsertARC.Valid_To__c = Date.valueOf('2030-12-31');
                    } else {
                        upsertARC.Valid_To__c = Date.valueOf(parent.Valid_TO);
                    }
                    upsertARCList.add(upsertARC);
                }
                if (upsertARCList.size() > 0) {
                    insert upsertARCList;
                    delete existingARClist;
                }
            }
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        } finally {
            // Log the API call
            if (!Test.isRunningTest()) {
                UtilityCls.logApiCall('ARCPricing_Master_API', '', '', resp.getBody(), '', resp.getStatusCode());
            }
        }
    }

    public static void getIncoTerms() {
        HttpResponse resp;
        String API_Name = 'Inco_Terms';
        Date dateOfExc = Date.today();
        try {
            resp = UtilityCls.doGetWithBasicAuth(API_Name, 'DAILY', dateOfExc, dateOfExc, '');

            if (resp.getStatusCode() == 200) {
                IntegrationRequestBuilder.IncoTermsMainResponse respWrapper = IntegrationRequestBuilder.IncoTermsMainResponseParse(resp.getBody());
                List < IntegrationRequestBuilder.IncoTermsList > parentWrappers = respWrapper.d.results;

                List < Incoterm__c > upsertIncotermList = new List < Incoterm__c > ();
                List < Incoterm__c > existingIncotermList = new List < Incoterm__c > ();
                existingIncotermList = [
                    SELECT Id, Name, Incoterm_Percent__c, Sales_Org__c, Distribution_Channel__c, Division__c, Condition_Record__c,
                    Valid_From__c, Valid_To__c, Pricing_Unit__c, Unit_of_Measure__c
                    FROM Incoterm__c
                ];

                Map < String, String > exIncotermMap = new Map < String, String > ();
                for (Incoterm__c inco: existingIncotermList) {
                    exIncotermMap.put(inco.Condition_Record__c, inco.Id);
                }

                for (IntegrationRequestBuilder.IncoTermsList parent: parentWrappers) {
                    Incoterm__c incoterm = new Incoterm__c();
                    if (exIncotermMap.containsKey(parent.Condition_Record)) {
                        incoterm.Id = exIncotermMap.get(parent.Condition_Record);
                    } else {
                        incoterm.Condition_Record__c = parent.Condition_Record;
                    }
                    incoterm.Name = parent.Incoterms;
                    incoterm.Incoterm_Percent__c = Decimal.valueOf(parent.Condition_Amount);
                    incoterm.Sales_Org__c = parent.Sales_Org;
                    incoterm.Distribution_Channel__c = parent.Distribution_Channel;
                    incoterm.Division__c = parent.Division;
                    incoterm.Valid_From__c = Date.valueOf(parent.Valid_from);
                    if (String.isNotBlank(parent.Valid_TO) && parent.Valid_TO.contains('9999')) {
                        incoterm.Valid_To__c = Date.valueOf('2030-12-31');
                    } else {
                        incoterm.Valid_To__c = Date.valueOf(parent.Valid_TO);
                    }
                    incoterm.Pricing_Unit__c = Decimal.valueOf(parent.Pricing_Unit);
                    incoterm.Unit_of_Measure__c = parent.Unit_of_Measure;
                    upsertIncotermList.add(incoterm);
                }
                upsert upsertIncotermList;

            }

        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        } finally {
            UtilityCls.logApiCall('Inco_Terms:' + String.valueOf(dateOfExc), '', '', resp != null ? resp.getBody() : '', '', resp != null ? resp.getStatusCode() : 0);
        }

    }

    @AuraEnabled
    public static string salesOrderCreation(String parentId, String bpFuncId, String shFuncId, String caFuncId) {
        // String jsonPayload ='{"SalesQuotationType":"ZQT","SalesOrganization":"1100","DistributionChannel":"10","OrganizationDivision":"10","SoldToParty":"7000001","PurchaseOrderByCustomer":"TESTU","CustomerPurchaseOrderDate":"/Date(1716374400000)/","RequestedDeliveryDate":"/Date(1716460800000)/","BindingPeriodValidityStartDate":"/Date(1716374400000)/","BindingPeriodValidityEndDate":"/Date(1716460800000)/","to_Partner":[{"PartnerFunction":\"SH\",\"Customer\":\"1000441\"},{\"PartnerFunction\":\"BP\",\"Customer\":\"1000441\"}],\"to_Item\":[{\"SalesQuotationItem\":\"10\",\"Material\":\"22000000002\",\"RequestedQuantity\":\"5\",\"Plant\":\"1100\"},{\"SalesQuotationItem\":\"20\",\"Material\":\"22000000002\",\"RequestedQuantity\":\"3\",\"Plant\":\"1200\"}]}';
        // String jsonPayload = '{"SalesQuotationType":"ZQT","SalesOrganization":"1100","DistributionChannel":"10","OrganizationDivision":"10","SoldToParty":"7000001","PurchaseOrderByCustomer":"Test Data 23","CustomerPurchaseOrderDate":"/Date(1716374400000)/","RequestedDeliveryDate":"/Date(1716460800000)/","BindingPeriodValidityStartDate":"/Date(1716374400000)/","BindingPeriodValidityEndDate":"/Date(1716460800000)/","to_Partner":[{"PartnerFunction":"SH","Customer":"1000441"},{"PartnerFunction":"BP","Customer":"1000441"}],"to_Item":[{"SalesQuotationItem":"10","Material":"22000000002","RequestedQuantity":"5","Plant":"1100"},{"SalesQuotationItem":"20","Material":"22000000002","RequestedQuantity":"3","Plant":"1200"}]}';
        // String jsonPayload = '{"SalesQuotationType":"ZQT","SalesOrganization":"1200","DistributionChannel":"20","OrganizationDivision":"20","SoldToParty":"7000002","PurchaseOrderByCustomer":"Demo Order 45","CustomerPurchaseOrderDate":"/Date(1717000000000)/","RequestedDeliveryDate":"/Date(1717086400000)/","BindingPeriodValidityStartDate":"/Date(1717000000000)/","BindingPeriodValidityEndDate":"/Date(1717179200000)/","to_Partner":[{"PartnerFunction":"SH","Customer":"1000555"},{"PartnerFunction":"BP","Customer":"1000555"}],"to_Item":[{"SalesQuotationItem":"10","Material":"22000000003","RequestedQuantity":"10","Plant":"1300"},{"SalesQuotationItem":"20","Material":"22000000005","RequestedQuantity":"2","Plant":"1300"}]}';
        // String jsonPayload = '{"SalesQuotationType":"ZQT","SalesOrganization":"1000","DistributionChannel":"30","OrganizationDivision":"10","SoldToParty":"7000003","PurchaseOrderByCustomer":"PO Ref 789","CustomerPurchaseOrderDate":"/Date(1718000000000)/","RequestedDeliveryDate":"/Date(1718086400000)/","BindingPeriodValidityStartDate":"/Date(1718000000000)/","BindingPeriodValidityEndDate":"/Date(1718265600000)/","to_Partner":[{"PartnerFunction":"SH","Customer":"1000666"},{"PartnerFunction":"BP","Customer":"1000666"}],"to_Item":[{"SalesQuotationItem":"10","Material":"22000000004","RequestedQuantity":"8","Plant":"1100"}]}';
        // String jsonPayload = '{"SalesQuotationType":"ZQT","SalesOrganization":"1100","DistributionChannel":"10","OrganizationDivision":"30","SoldToParty":"7000004","PurchaseOrderByCustomer":"Customer Order 001","CustomerPurchaseOrderDate":"/Date(1719000000000)/","RequestedDeliveryDate":"/Date(1719172800000)/","BindingPeriodValidityStartDate":"/Date(1719000000000)/","BindingPeriodValidityEndDate":"/Date(1719345600000)/","to_Partner":[{"PartnerFunction":"SH","Customer":"1000777"},{"PartnerFunction":"BP","Customer":"1000777"}],"to_Item":[{"SalesQuotationItem":"10","Material":"22000000001","RequestedQuantity":"15","Plant":"1100"},{"SalesQuotationItem":"20","Material":"22000000006","RequestedQuantity":"4","Plant":"1200"},{"SalesQuotationItem":"30","Material":"22000000007","RequestedQuantity":"1","Plant":"1200"}]}';
        // String jsonPayload = '{"SalesQuotationType":"ZQT","SalesOrganization":"1100","DistributionChannel":"10","OrganizationDivision":"10","SoldToParty":"7000001","PurchaseOrderByCustomer":"TESTU","CustomerPurchaseOrderDate":"/Date(1742409000000)/","RequestedDeliveryDate":"/Date(1743359400000)/","BindingPeriodValidityStartDate":"/Date(1740767400000)/","BindingPeriodValidityEndDate":"/Date(1743791400000)/","to_Partner":[{"PartnerFunction":"SH","Customer":"1000441"},{"PartnerFunction":"BP","Customer":"1000441"}],"to_Item":[{"SalesQuotationItem":"10","Material":"22000000002","RequestedQuantity":"5","Plant":"1100"},{"SalesQuotationItem":"20","Material":"22000000002","RequestedQuantity":"3","Plant":"1200"}]}';

        String jsonPayload = '';
        HttpResponse resp;
        HttpResponse response;
        try {

            jsonPayload = getQuotePayload(parentId, bpFuncId, shFuncId, caFuncId);
            System.debug('JSON Payload: ' + jsonPayload);
            //Get SAP CSRF token using get method

            resp = UtilityCls.doGetWithBasicAuth('Get_Session_API', 'Bulk', Null, Null, '');
            // system.debug('x-csrf-token resp : ' + resp.getHeader('x-csrf-token'));
            if (resp.getStatusCode() == 200) {
                system.debug('Get_Session_API resp: ' + resp.getBody());
                //  system.debug('X-CSRF-Token resp : '+resp.getHeader('X-CSRF-Token'));
                String csrfToken = resp.getHeader('x-csrf-token');
                String cookies = resp.getHeader('set-cookie');
                system.debug('x-csrf-token csrfToken : ' + csrfToken);
                system.debug('x-csrf-token resp : ' + resp.getHeader('x-csrf-token'));

                // Make the POST API call
                Http http = new Http();
                HttpRequest request = new HttpRequest();
                //    request.setEndpoint('https://dev.rotexautomation.com:44300/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrder'); // Replace with your API endpoint
                // request.setEndpoint('https://qas.rotexautomation.com:44300/sap/opu/odata/sap/API_SALES_QUOTATION_SRV/A_SalesQuotation'); // Replace with your API endpoint
                request.setEndpoint(System.Label.Push_Quote_to_SAP);
                request.setMethod('POST');
                request.setHeader('Content-Type', 'application/json');
                request.setHeader('Accept', 'application/json');
                request.setBody(jsonPayload);
                // Set basic authentication header
                // String username = 'RTXCTM_SD';
                // String password = 'Iteanz$4321';
                String username = System.Label.Push_Quote_Username;
                String password = System.Label.Push_Quote_Password;
                String authHeader = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(username + ':' + password));
                request.setHeader('Authorization', authHeader);
                request.setHeader('x-csrf-token', csrfToken); // Use the fetched token
                request.setHeader('Content-Type', 'application/json');
                request.setHeader('cookie', cookies); // Use the fetched cookies

                request.setTimeOut(120000);

                response = http.send(request);

                // Log response
                if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
                    System.debug('API call successful: ' + response.getBody());
                } else {
                    System.debug('API call failed: ' + response.getStatusCode() + ' ' + response.getBody());
                }

            }
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        } finally {
            // Log the API call
            //  UtilityCls.logApiCall('salesOrderCreation', '', '', response.getBody, '', response.getStatusCode());
            // UtilityCls.logApiCall('QuotationCreation', '', jsonPayload, response.getBody(), '', 0);
            UtilityCls.logApiCall('QuotationCreation', '', jsonPayload, response.getBody(), '', response.getStatusCode());
        }
        return JSON.serialize(response.getBody());
    }

    public static String getSalesOrderPayload(String parentId) {
        String jsonPayload = '';
        try {
            // Initialize collections
            List < Order > orderList = new List < Order > ();
            List < Partner_Details__c > pdList = new List < Partner_Details__c > ();
            List < OrderItem > orderitemList = new List < OrderItem > ();
            List < Price_Details__c > priceList = new List < Price_Details__c > ();
            Set < Id > acc = new Set < Id > ();
            Set < Id > ord = new Set < Id > ();
            Set < Id > ordPro = new Set < Id > ();

            // Query Parent Order
            orderList = [SELECT Id, Name, SO_Type__c, Sales_Org__c, Distribution_Channel__c, Division__c, OrderNumber,
                Sold_To__c, Cust_Ref__c, Cust_Ref_Date__c, AccountId
                FROM Order
                WHERE Id =: parentId
            ];
            for (Order o: orderList) {
                acc.add(o.AccountId);
                ord.add(o.Id);
            }

            // Query Partner Details related to Parent
            pdList = [SELECT Id, Name, Partner_Function__c, Sales_Area_Item__r.Account__r.Name
                FROM Partner_Details__c
                WHERE Sales_Area_Item__r.Account__c IN: acc
            ];

            // Query Order Items
            orderitemList = [SELECT Id, Item_No__c, Quantity, Plant__c, OrderId
                FROM OrderItem
                WHERE OrderId IN: ord
            ];
            for (OrderItem oi: orderitemList) {
                ordPro.add(oi.Id);
            }

            // Query Pricing Details for Order Items
            priceList = [SELECT Id, Name, Cond_Type__c, Amount__c, CurrencyIsoCode, Order_Product__c
                FROM Price_Details__c
                WHERE Order_Product__c IN: ordPro
            ];

            // Build the nested wrapper structure
            List < OrderWrapper > orderWrapperList = new List < OrderWrapper > ();
            OrderWrapper orderWrapper = new OrderWrapper();
            for (Order o: orderList) {

                orderWrapper.SalesOrder = o.OrderNumber;
                orderWrapper.SalesOrderType = o.SO_Type__c;
                orderWrapper.SalesOrganization = o.Sales_Org__c;
                orderWrapper.DistributionChannel = o.Distribution_Channel__c;
                orderWrapper.OrganizationDivision = o.Division__c;
                orderWrapper.SoldToParty = o.Sold_To__c;
                orderWrapper.PurchaseOrderByCustomer = o.Cust_Ref__c;
                //  orderWrapper.CustomerPurchaseOrderDate = o.Cust_Ref_Date__c != null ? String.valueOf(o.Cust_Ref_Date__c) : null;
                /*
                            // Add Partner Details
                            orderWrapper.to_PartnerFunction = new List<PartnerWrapper>();
                            for (Partner_Details__c pd : pdList) {
                                if (pd.Sales_Area_Item__r.Account__c == o.AccountId) {
                                    PartnerWrapper partnerWrapper = new PartnerWrapper();
                                    partnerWrapper.PartnerFunction = pd.Partner_Function__c;
                                    partnerWrapper.Customer = pd.Sales_Area_Item__r.Account__r.Name;
                                    orderWrapper.to_PartnerFunction.add(partnerWrapper);
                                }
                            }
                */
                // Add Order Items and Pricing Details
                orderWrapper.to_Item = new List < OrderItemWrapper > ();
                for (OrderItem oi: orderitemList) {
                    if (oi.OrderId == o.Id) {
                        OrderItemWrapper itemWrapper = new OrderItemWrapper();
                        itemWrapper.Material = oi.Item_No__c;
                        itemWrapper.SalesOrderItem = oi.Id;
                        itemWrapper.RequestedQuantity = String.valueOf(oi.Quantity);
                        itemWrapper.ProductionPlant = oi.Plant__c;
                        /*
                                           // Add Pricing Elements
                                            itemWrapper.to_PricingElement = new List<PricingWrapper>();
                                            for (Price_Details__c price : priceList) {
                                             //  if (price.Order_Product__c == oi.Id) {
                                                    PricingWrapper pricingWrapper = new PricingWrapper();
                                                    pricingWrapper.PricingProcedureStep = price.Cond_Type__c;
                                                    pricingWrapper.ConditionRateValue = String.valueOf(price.Amount__c);
                                                    pricingWrapper.ConditionCurrency = price.CurrencyIsoCode;
                                                    itemWrapper.to_PricingElement.add(pricingWrapper);
                                               // }
                                            }
                        */
                        orderWrapper.to_Item.add(itemWrapper);
                    }
                }

                orderWrapperList.add(orderWrapper);
            }

            // Convert the nested structure to JSON
            // jsonPayload = JSON.serialize(orderWrapperList);
            jsonPayload = JSON.serialize(orderWrapper);
            System.debug('JSON Payload: ' + jsonPayload);

        } catch (Exception e) {
            jsonPayload = '';
            System.debug('Exception: ' + e.getMessage());
        } finally {
            // Log the API call
            //  UtilityCls.logApiCall('salesOrderCreation', '', '', response.getBody, '', response.getStatusCode());
            //   UtilityCls.logApiCall('salesOrderCreation', '', '',jsonPayload, '',0); 

        }
        return jsonPayload;
    }

    //New Format
    public static String getQuotePayload(String quoteId, String bpId, String shId, String caId) {
        String jsonPayload = '';
        try {
            // Initialize collections
            List < Quote > quoteList = new List < Quote > ();
            List < QuoteLineItem > quoteLineItemList = new List < QuoteLineItem > ();
            List < Partner_Details__c > partnerDetailsList = new List < Partner_Details__c > ();
            Set < Id > quoteIds = new Set < Id > ();
            Set < Id > accountIds = new Set < Id > ();

            // Query Parent Quote
            quoteList = [SELECT Id, Name, QuoteNumber, OpportunityId, AccountId, BillingCity, BillingState, BillingCountry, BillingPostalCode,
                ShippingCity, ShippingState, ShippingCountry, ShippingPostalCode, Status, TotalPrice, Subtotal, Discount,
                Quote_Type__c, SalesOrganization__c, DistributionChannel__c, OrganizationDivision__c, CurrencyISOCode,
                SoldToParty__c, PurchaseOrderByCustomer__c, CustomerPurchaseOrderDate__c, Account.Discount__c,
                RequestedDeliveryDate__c, Quote_Date__c, Quote_Valid_Till__c, Account.SAP_Customer_Code__c, Customer_Reference_Date__c
                FROM Quote
                WHERE Id =: quoteId
            ];
            for (Quote q: quoteList) {
                quoteIds.add(q.Id);
                accountIds.add(q.AccountId);
            }

            // Query Quote Line Items related to Parent Quote
            quoteLineItemList = [
                SELECT Id, QuoteId, Quantity, UnitPrice, TotalPrice, Discount, Product2Id, Product2.Name, Plant__c, LineNumber,
                Product2.ProductCode, Discount_to_be_offered__c, Quote.CurrencyISOCode
                FROM QuoteLineItem
                WHERE QuoteId IN: quoteIds
            ];

            Sales_Area_Item__c saItem = [
                SELECT Id, Name, Sales_Org__c, Distribution_Channel__c, Division__c
                FROM Sales_Area_Item__c
                WHERE Sales_Org__c = '1100'
                AND Division__c != '50'
                AND Division__c != '20'
                AND Division__c != '00'
                AND Account__c =: quoteList[0].AccountId
            ];

            Set < String > pdIdsSet = new Set < String > ();
            pdIdsSet.add(bpId);
            pdIdsSet.add(shId);
            pdIdsSet.add(caId);

            // Query Partner Details related to Parent Quote
            partnerDetailsList = [SELECT Id, Partner_Function__c, Customer__c, Partner_No__c
                FROM Partner_Details__c
                // WHERE Sales_Area_Item__c = : saItem.Id
                // AND Partner_Function__c = 'BP'
                // AND Partner_No__c = :quoteList[0].Account.SAP_Customer_Code__c
                // LIMIT 1
                WHERE Id IN: pdIdsSet
            ];

            // Build the nested wrapper structure
            List < QuoteWrapper > quoteWrapperList = new List < QuoteWrapper > ();
            for (Quote q: quoteList) {
                QuoteWrapper quoteWrapper = new QuoteWrapper();
                // quoteWrapper.SalesQuotationType = q.Quote_Type__c;
                quoteWrapper.SalesQuotationType = 'ZQT';
                // quoteWrapper.SalesOrganization = q.SalesOrganization__c;
                quoteWrapper.SalesOrganization = saItem.Sales_Org__c;
                // quoteWrapper.DistributionChannel = q.DistributionChannel__c;
                quoteWrapper.DistributionChannel = saItem.Distribution_Channel__c;
                // quoteWrapper.OrganizationDivision = q.OrganizationDivision__c;
                quoteWrapper.OrganizationDivision = saItem.Division__c;
                quoteWrapper.SoldToParty = q.Account.SAP_Customer_Code__c;
                // quoteWrapper.PurchaseOrderByCustomer = q.PurchaseOrderByCustomer__c;
                quoteWrapper.PurchaseOrderByCustomer = q.QuoteNumber;
                quoteWrapper.CustomerPurchaseOrderDate = q.Customer_Reference_Date__c != null ? convertDateToMicrosoftJsonFormat(q.Customer_Reference_Date__c) : null;
                quoteWrapper.RequestedDeliveryDate = q.RequestedDeliveryDate__c != null ? convertDateToMicrosoftJsonFormat(q.RequestedDeliveryDate__c) : null;
                Date todayDate = Date.today();
                Date endDate = todayDate.addDays(30);
                quoteWrapper.BindingPeriodValidityStartDate = convertDateToMicrosoftJsonFormat(todayDate);
                quoteWrapper.BindingPeriodValidityEndDate = convertDateToMicrosoftJsonFormat(endDate);
                // quoteWrapper.BindingPeriodValidityStartDate = q.Quote_Date__c != null ? convertDateToMicrosoftJsonFormat(q.Quote_Date__c) : null;
                // quoteWrapper.BindingPeriodValidityEndDate = q.Quote_Valid_Till__c != null ? convertDateToMicrosoftJsonFormat(q.Quote_Valid_Till__c) : null;

                // Add Partner Details
                quoteWrapper.to_Partner = new List < PartnerWrapper > ();
                for (Partner_Details__c pd: partnerDetailsList) {
                    PartnerWrapper partnerWrapper = new PartnerWrapper();
                    partnerWrapper.PartnerFunction = pd.Partner_Function__c;
                    partnerWrapper.Customer = pd.Partner_No__c;
                    quoteWrapper.to_Partner.add(partnerWrapper);
                }

                // Add Quote Line Items
                quoteWrapper.to_Item = new List < QuoteLineItemWrapper > ();
                Integer ind = 10;
                for (QuoteLineItem qli: quoteLineItemList) {
                    if (qli.QuoteId == q.Id) {
                        QuoteLineItemWrapper lineItemWrapper = new QuoteLineItemWrapper();
                        // lineItemWrapper.SalesQuotationItem = qli.LineNumber;
                        lineItemWrapper.SalesQuotationItem = String.valueOf(ind);
                        lineItemWrapper.Material = qli.Product2.ProductCode;
                        lineItemWrapper.RequestedQuantity = String.valueOf(qli.Quantity);
                        // lineItemWrapper.Plant = qli.Plant__c;
                        lineItemWrapper.Plant = saItem.Sales_Org__c;

                        if (qli.Discount_to_be_offered__c > 0) {
                            lineItemWrapper.to_PricingElement = new List < PricingElementWrapper > ();
                            PricingElementWrapper pricingElementWrapper = new PricingElementWrapper();
                            pricingElementWrapper.PricingProcedureStep = '41';
                            pricingElementWrapper.PricingProcedureCounter = '1';
                            pricingElementWrapper.ConditionType = 'ZDIS';
                            pricingElementWrapper.ConditionRateValue = String.valueOf(qli.Discount_to_be_offered__c);
                            pricingElementWrapper.ConditionCurrency = qli.Quote.CurrencyISOCode;
                            lineItemWrapper.to_PricingElement.add(pricingElementWrapper);
                        }

                        quoteWrapper.to_Item.add(lineItemWrapper);
                        ind = ind + 10;
                    }
                }

                quoteWrapperList.add(quoteWrapper);
            }

            // Convert the nested structure to JSON
            jsonPayload = JSON.serialize(quoteWrapperList[0], true);
            System.debug('JSON Payload: ' + jsonPayload);
        } catch (Exception e) {
            jsonPayload = '';
            System.debug('Exception: ' + e.getMessage() + ' at line ' + e.getLineNumber());
        }
        return jsonPayload;
    }

    public static String convertDateToMicrosoftJsonFormat(Date inputDate) {
        // Step 1: Convert Date to DateTime (start of the day)
        DateTime dt = DateTime.newInstance(inputDate, Time.newInstance(0, 0, 0, 0));

        // Step 2: Convert to milliseconds since epoch
        Long millis = dt.getTime(); // getTime() gives milliseconds since 1970

        // Step 3: Format as Microsoft JSON date
        return '/Date(' + millis + ')/';
    }

    // Quotation Fields validation
    @AuraEnabled
    public static string quoteValidation(String qId) {
        try {

            Map < String, String > retResData = new Map < String, String > ();
            retResData.put('status', 'true');
            retResData.put('message', '');

            Quote q = [
                SELECT Id, CustomerPurchaseOrderDate__c, RequestedDeliveryDate__c, Quote_Date__c, Quote_Valid_Till__c, Status, SAP_Quotation_Number__c
                // ,Location__c
                FROM Quote
                WHERE Id =: qId
            ];

            if (q.Status != 'Accepted') {
                retResData.put('status', 'false');
                retResData.put('sync', 'false');
                retResData.put('message', 'Quote status is not Accepted');
            } else
                // if(q.CustomerPurchaseOrderDate__c == null || q.RequestedDeliveryDate__c == null || q.Quote_Date__c == null || q.Quote_Valid_Till__c == null){
                //     retResData.put('status', 'false');
                //     retResData.put('sync', 'false');
                //     retResData.put('message', 'Customer Purchase Order Date, Requested Delivery Date, Quote Date, Quote Valid Till Date cannot be blank');
                // } else
                if (q.SAP_Quotation_Number__c != null) {
                    retResData.put('status', 'false');
                    retResData.put('sync', 'false');
                    retResData.put('message', 'Quotation already sent to SAP');
                }

            return JSON.serialize(retResData);

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static string getLineItem(String qId) {
        try {

            Map < String, Object > respMap = new Map < String, Object > ();

            List < QuoteLineItem > quoteLineItemList = new List < QuoteLineItem > ();
            quoteLineItemList = [
                SELECT Id, Product2Id, Product2.ProductCode, QuoteId, ListPrice, UnitPrice, Quantity, Product2.Name,
                TotalPrice, Discount_to_be_offered__c, Quote.AccountId
                FROM QuoteLineItem
                WHERE QuoteId =: qId
            ];

            respMap.put('quoteLineItemList', quoteLineItemList);

            List < Sales_Area_Item__c > salesAreaItemList = [
                SELECT Id, Name, Sales_Org__c, Distribution_Channel__c, Division__c, Incoterms__c
                FROM Sales_Area_Item__c
                WHERE Sales_Org__c = '1100'
                AND Division__c != '50'
                AND Division__c != '20'
                AND Division__c != '00'
                AND Account__c =: quoteLineItemList[0].Quote.AccountId
            ];

            Set < String > salesAreaItemIdSet = new Set < String > ();
            for (Sales_Area_Item__c sai: salesAreaItemList) {
                // if (sai.Division__c == '10') {
                salesAreaItemIdSet.add(sai.Id);
                // }
            }

            List < Partner_Details__c > partnerDetailsList = new List < Partner_Details__c > ();
            List < Partner_Details__c > bpList = new List < Partner_Details__c > ();
            List < Partner_Details__c > shList = new List < Partner_Details__c > ();
            List < Partner_Details__c > caList = new List < Partner_Details__c > ();

            if (salesAreaItemIdSet.size() > 0) {
                partnerDetailsList = [
                    SELECT Id, Name, Partner_Function__c, Partner_No__c,
                    Street__c, City__c, District__c, State__c, Country__c, Postal_Code__c
                    FROM Partner_Details__c
                    WHERE Sales_Area_Item__c IN: salesAreaItemIdSet
                ];

                for (Partner_Details__c pd: partnerDetailsList) {
                    if (pd.Partner_Function__c == 'BP') {
                        bpList.add(pd);
                    } else if (pd.Partner_Function__c == 'SH') {
                        shList.add(pd);
                    } else if (pd.Partner_Function__c == 'CA') {
                        caList.add(pd);
                    }
                }

                respMap.put('bpList', bpList);
                respMap.put('shList', shList);
                respMap.put('caList', caList);
            }

            return JSON.serialize(respMap);

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static string updateQuotation(String qId, String qNumber) {
        try {

            Quote q = [
                SELECT Id, SAP_Quotation_Number__c, Status
                FROM Quote
                WHERE Id =: qId
            ];

            q.SAP_Quotation_Number__c = qNumber;

            update q;

            return 'ok';

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class QuoteWrapper {
        public String SalesQuotationType;
        public String SalesOrganization;
        public String DistributionChannel;
        public String OrganizationDivision;
        public String SoldToParty;
        public String PurchaseOrderByCustomer;
        public String CustomerPurchaseOrderDate;
        public String RequestedDeliveryDate;
        public String BindingPeriodValidityStartDate;
        public String BindingPeriodValidityEndDate;
        public List < PartnerWrapper > to_Partner;
        public List < QuoteLineItemWrapper > to_Item;
    }

    public class PartnerWrapper {
        public String PartnerFunction;
        public String Customer;
    }

    public class QuoteLineItemWrapper {
        public String SalesQuotationItem;
        public String Material;
        public String RequestedQuantity;
        public String Plant;
        public List < PricingElementWrapper > to_PricingElement;
    }

    public class PricingElementWrapper {
        public String PricingProcedureStep;
        public String PricingProcedureCounter;
        public String ConditionType;
        public String ConditionRateValue;
        public String ConditionCurrency;
    }

    // Wrapper Classes
    public class OrderWrapper {
        public String SalesOrder;
        public String SalesOrderType;
        public String SalesOrganization;
        public String DistributionChannel;
        public String OrganizationDivision;
        public String SoldToParty;
        public String PurchaseOrderByCustomer;
        // public String CustomerPurchaseOrderDate;
        // public List<PartnerWrapper> to_PartnerFunction;
        public List < OrderItemWrapper > to_Item;
    }
    /*
    public class PartnerWrapper {
        public String PartnerFunction;
        public String Customer;
    }
    */
    public class OrderItemWrapper {
        public String Material;
        public String SalesOrderItem;
        public String RequestedQuantity;
        public String ProductionPlant;
        //   public List<PricingWrapper> to_PricingElement;
    }
    /*
    public class PricingWrapper {
        public String PricingProcedureStep;
        public String ConditionRateValue;
        public String ConditionCurrency;
    }
    */

    // public class QuoteWrapper {
    //     public String QuoteNumber;
    //     public Id AccountId;
    //     public Id OpportunityId;
    //     public String BillingAddress;
    //     public String ShippingAddress;
    //     public String Status;
    //     public String TotalPrice;
    //     public String Subtotal;
    //     public String Discount;
    //     public List < QuoteLineItemWrapper > LineItems;
    // }

    // public class QuoteLineItemWrapper {
    //     public String ProductName;
    //     public String Quantity;
    //     public String UnitPrice;
    //     public String TotalPrice;
    //     public String Discount;
    // }

    public static void getHSNMaster() {

        try {
            HttpResponse resp;
            resp = UtilityCls.doGetWithoutAuth('HSN_Master', null, null);
            if (resp.getStatusCode() == 200) {
                IntegrationRequestBuilder.HSNMasterResponse itemResponse = IntegrationRequestBuilder.HSNMasterResponseParse(resp.getBody());
                List < IntegrationRequestBuilder.cls_HSN_List > itemResponseList = itemResponse.HSN_List;

                Set < String > hsnIds = new Set < String > ();
                Map < String, String > mphsnIds = new Map < String, String > ();

                for (IntegrationRequestBuilder.cls_HSN_List row: itemResponseList) {
                    hsnIds.add(row.HSN_Code);
                }
                /*
                List<HSN_Code__c> hsnList=[SELECT Id,Name FROM HSN_Code__c WHERE Name  IN : hsnIds];
                for (HSN_Code__c row : hsnList) {
                mphsnIds.put(row.Name , row.Id);
                }

                List<HSN_Code__c> prodList=new List<HSN_Code__c>();
                for(IntegrationRequestBuilder.cls_HSN_List row:itemResponseList){
                HSN_Code__c prod=new HSN_Code__c();
                if(mphsnIds.get(row.HSN_Code)!=null){
                prod.Id=mphsnIds.get(row.HSN_Code);
                }
                prod.Name=row.HSN_Code;
                prod.Description__c=row.Description;
                prod.Chapter_ID__c=row.Chapter_ID;
                prod.Heading_ID__c=row.Heading_ID;
                prod.SubHeading_ID__c=row.SubHeading_ID;

                prodList.add(prod);

                }
                if(prodList.size()>0){
                UPSERT prodList;
                }*/
            }

        } catch (Exception e) {

        }

    }

    public static void getSACMaster() {

        try {
            HttpResponse resp;
            resp = UtilityCls.doGetWithoutAuth('SAC_Data', null, null);
            if (resp.getStatusCode() == 200) {
                IntegrationRequestBuilder.SACMasterResponse itemResponse = IntegrationRequestBuilder.SACMasterResponseParse(resp.getBody());
                List < IntegrationRequestBuilder.cls_SAC_List > itemResponseList = itemResponse.SAC_List;

                Set < String > Ids = new Set < String > ();
                Map < String, String > mpIds = new Map < String, String > ();

                for (IntegrationRequestBuilder.cls_SAC_List row: itemResponseList) {
                    Ids.add(row.ServCode);
                }
                /*
                List<SAC__c> dList=[SELECT Id,Name FROM SAC__c WHERE Name  IN : Ids];
                for (SAC__c row : dList) {
                mpIds.put(row.Name , row.Id);
                }

                List<SAC__c> prodList=new List<SAC__c>();
                for(IntegrationRequestBuilder.cls_SAC_List row:itemResponseList){
                SAC__c prod=new SAC__c();
                if(mpIds.get(row.ServCode)!=null){
                prod.Id=mpIds.get(row.ServCode);
                }
                prod.Name=row.ServCode;
                prod.ServName__c=row.ServName;
                prod.Abs_Entry__c=String.valueOf(row.AbsEntry);

                prodList.add(prod);

                }
                if(prodList.size()>0){
                UPSERT prodList;
                } */
            }

        } catch (Exception e) {
            system.debug(e.getLineNumber());
            system.debug(e.getMessage());
        }

    }

}