public with sharing class SyncSapToSf {
    private static final Integer LOG_MAX_LENGTH = 10000;

    public SyncSapToSf() {

    }

    @AuraEnabled
    public static SyncResult syncCustomer(String customerCode) {
        CustomerSyncPayload payload = fetchCustomerPayload(customerCode);

        if (isCustomerPresent(payload.customers)) {
            return new SyncResult(true, 'This customer is already present.', 'info');
        }

        Integer syncedCount = upsertCustomers(payload.customers, payload.dateOfExc);
        return new SyncResult(true, 'Customer sync completed. Records synced: ' + syncedCount, 'success');
    }

    @AuraEnabled
    public static SyncResult getMaterialMaster(String materialCode) {
        MaterialSyncPayload payload = fetchMaterialPayload(materialCode);

        if (isMaterialPresent(payload.materials)) {
            return new SyncResult(true, 'This material is already present.', 'info');
        }

        Integer syncedCount = upsertMaterials(payload.materials, payload.dateOfExc);
        IntegrationHandler.PricingMaster(materialCode, true);
        return new SyncResult(true, 'Material sync completed. Records synced: ' + syncedCount, 'success');
    }

    @AuraEnabled
    public static SyncResult getPricingMaster(String materialCode) {
        IntegrationHandler.PricingMaster(materialCode);
        return new SyncResult(true, 'Pricing sync completed.', 'success');
    }

    public static Integer getCustomerMaster(String customerCode) {
        CustomerSyncPayload payload = fetchCustomerPayload(customerCode);
        return upsertCustomers(payload.customers, payload.dateOfExc);
    }

    private static CustomerSyncPayload fetchCustomerPayload(String customerCode) {
        if (String.isBlank(customerCode)) {
            throw new AuraHandledException('Enter Customer Code');
        }

        HttpResponse resp;
        String apiName = 'Customer_Master_API';
        Date dateOfExc = Date.today();

        try {
            resp = UtilityCls.doGetWithBasicAuth(apiName, 'DAILY', dateOfExc, dateOfExc, customerCode.trim());

            if (resp.getStatusCode() != 200) {
                throw new AuraHandledException('Customer sync failed. Status: ' + resp.getStatusCode());
            }

            IntegrationRequestBuilder.CustomerMasterResponse respWrapper = IntegrationRequestBuilder.CustomerMasterResponseParse(resp.getBody());
            List<IntegrationRequestBuilder.customersList> allCustomers = respWrapper != null && respWrapper.d != null
                ? respWrapper.d.results
                : new List<IntegrationRequestBuilder.customersList>();

            if (allCustomers == null || allCustomers.isEmpty()) {
                throw new AuraHandledException('Invalid Customer Code.');
            }

            return new CustomerSyncPayload(allCustomers, dateOfExc);
        } finally {
            logApiResponse(apiName + ':' + String.valueOf(dateOfExc), resp);
        }
    }

    private static MaterialSyncPayload fetchMaterialPayload(String materialCode) {
        if (String.isBlank(materialCode)) {
            throw new AuraHandledException('Enter Material Code');
        }

        HttpResponse resp;
        Date dateOfExc = Date.today();

        try {
            resp = UtilityCls.doGetWithBasicAuth('Material_Master_API', 'DAILY', dateOfExc, dateOfExc, materialCode.trim());

            if (resp.getStatusCode() != 200) {
                throw new AuraHandledException('Material sync failed. Status: ' + resp.getStatusCode());
            }

            IntegrationRequestBuilder.MaterialMasterResponse respWrapper = IntegrationRequestBuilder.MaterialMasterResponseParse(resp.getBody());
            List<IntegrationRequestBuilder.materialsList> materials = respWrapper != null && respWrapper.d != null
                ? respWrapper.d.results
                : new List<IntegrationRequestBuilder.materialsList>();

            if (materials == null || materials.isEmpty()) {
                throw new AuraHandledException('Invalid Material Code.');
            }

            return new MaterialSyncPayload(materials, dateOfExc);
        } finally {
            logApiResponse('Material_Master_API', resp);
        }
    }

    private static Boolean isCustomerPresent(List<IntegrationRequestBuilder.customersList> customers) {
        Set<String> customerCodes = new Set<String>();
        for (IntegrationRequestBuilder.customersList customer : customers) {
            if (String.isNotBlank(customer.customer_number)) {
                customerCodes.add(customer.customer_number);
            }
        }

        return !customerCodes.isEmpty() && [
            SELECT COUNT()
            FROM Account
            WHERE SAP_Customer_Code__c IN :customerCodes
        ] > 0;
    }

    private static Boolean isMaterialPresent(List<IntegrationRequestBuilder.materialsList> materials) {
        Set<String> materialCodes = new Set<String>();
        for (IntegrationRequestBuilder.materialsList material : materials) {
            if (String.isNotBlank(material.item_no)) {
                materialCodes.add(material.item_no);
            }
        }

        return !materialCodes.isEmpty() && [
            SELECT COUNT()
            FROM Product2
            WHERE ProductCode IN :materialCodes
        ] > 0;
    }

    private static Integer upsertCustomers(List<IntegrationRequestBuilder.customersList> allCustomers, Date dateOfExc) {
        Map<String, IntegrationRequestBuilder.customersList> uniqueCustomersMap = new Map<String, IntegrationRequestBuilder.customersList>();

        for (IntegrationRequestBuilder.customersList customer : allCustomers) {
            if (String.isNotBlank(customer.customer_number) && !uniqueCustomersMap.containsKey(customer.customer_number)) {
                uniqueCustomersMap.put(customer.customer_number, customer);
            }
        }

        List<IntegrationRequestBuilder.customersList> parentWrappers = uniqueCustomersMap.values();
        Set<String> accCodes = uniqueCustomersMap.keySet();

        Map<String, Account> existingAccountsMap = new Map<String, Account>();
        for (Account acc : [SELECT Id, SAP_Customer_Code__c FROM Account WHERE SAP_Customer_Code__c IN :accCodes]) {
            existingAccountsMap.put(acc.SAP_Customer_Code__c, acc);
        }

        Map<String, Sales_Area_Item__c> existingChildMap = new Map<String, Sales_Area_Item__c>();
        for (Sales_Area_Item__c sai : [
            SELECT Id, Name, Customer_Number__c
            FROM Sales_Area_Item__c
            WHERE Customer_Number__c IN :accCodes
        ]) {
            existingChildMap.put(sai.Name + '/' + sai.Customer_Number__c, sai);
        }

        Map<String, Partner_Details__c> existingGrandChildMap = new Map<String, Partner_Details__c>();
        for (Partner_Details__c pd : [
            SELECT Id, Partner_No__c, Sales_Area_Item__c, Partner_Function__c
            FROM Partner_Details__c
            WHERE Sales_Area_Item__r.Customer_Number__c IN :accCodes
        ]) {
            existingGrandChildMap.put(pd.Sales_Area_Item__c + '/' + pd.Partner_No__c + '/' + pd.Partner_Function__c, pd);
        }

        List<Account> accountsToUpsert = new List<Account>();
        Map<String, Id> accCodeToIdMap = new Map<String, Id>();

        for (IntegrationRequestBuilder.customersList parent : parentWrappers) {
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
            acc.credit_limit__c = parseDecimal(parent.credit_limit);
            acc.Credit_Days__c = parseInteger(parent.Credit_Days);
            acc.Discount__c = parseDecimal(parent.Discount);
            acc.Description = String.valueOf(dateOfExc);
            acc.SAP_Integration__c = true;

            accountsToUpsert.add(acc);
        }

        if (!accountsToUpsert.isEmpty()) {
            upsert accountsToUpsert;
        }

        for (Account a : accountsToUpsert) {
            accCodeToIdMap.put(a.SAP_Customer_Code__c, a.Id);
        }

        List<Sales_Area_Item__c> childrenToUpsert = new List<Sales_Area_Item__c>();
        Map<String, Id> childKeyToIdMap = new Map<String, Id>();

        for (IntegrationRequestBuilder.customersList parent : parentWrappers) {
            Id parentId = accCodeToIdMap.get(parent.customer_number);
            if (parent.to_salesareaitem == null || parent.to_salesareaitem.results == null || parentId == null) {
                continue;
            }

            for (IntegrationRequestBuilder.salesAreaItemList child : parent.to_salesareaitem.results) {
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

        if (!childrenToUpsert.isEmpty()) {
            upsert childrenToUpsert;
        }

        for (Sales_Area_Item__c sai : childrenToUpsert) {
            childKeyToIdMap.put(sai.Name + '/' + sai.Customer_Number__c, sai.Id);
        }

        List<Partner_Details__c> grandChildrenToUpsert = new List<Partner_Details__c>();

        for (IntegrationRequestBuilder.customersList parent : parentWrappers) {
            Id parentId = accCodeToIdMap.get(parent.customer_number);
            if (parent.to_salesareaitem == null || parent.to_salesareaitem.results == null || parentId == null) {
                continue;
            }

            for (IntegrationRequestBuilder.salesAreaItemList child : parent.to_salesareaitem.results) {
                String childKey = child.sales_org + '/' + child.distribution_channel + '/' + child.division + '/' + parent.customer_number;
                Id childId = childKeyToIdMap.get(childKey);
                if (childId == null || child.to_partnerdetails == null || child.to_partnerdetails.results == null) {
                    continue;
                }

                for (IntegrationRequestBuilder.partnerDetailsList gc : child.to_partnerdetails.results) {
                    String gcKey = childId + '/' + gc.partner_number + '/' + gc.partner_function;
                    Partner_Details__c pd = existingGrandChildMap.containsKey(gcKey)
                        ? existingGrandChildMap.get(gcKey)
                        : new Partner_Details__c(Sales_Area_Item__c = childId);

                    pd.Name = gc.partner_number + '/' + gc.partner_function;
                    pd.Partner_No__c = gc.partner_number;
                    pd.Partner_Function__c = gc.partner_function;
                    pd.Customer__c = parent.customer_number;
                    pd.Account__c = parentId;

                    grandChildrenToUpsert.add(pd);
                }
            }
        }

        if (!grandChildrenToUpsert.isEmpty()) {
            upsert grandChildrenToUpsert;
        }

        return parentWrappers.size();
    }

    private static Integer upsertMaterials(List<IntegrationRequestBuilder.materialsList> parentWrappers, Date dateOfExc) {
        Set<String> productCodes = new Set<String>();
        for (IntegrationRequestBuilder.materialsList material : parentWrappers) {
            if (String.isNotBlank(material.item_no)) {
                productCodes.add(material.item_no);
            }
        }

        Map<String, Product2> existingProductsMap = new Map<String, Product2>();
        for (Product2 p : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode IN :productCodes]) {
            existingProductsMap.put(p.ProductCode, p);
        }

        Map<String, Plant_Data__c> existingPlantMap = new Map<String, Plant_Data__c>();
        for (Plant_Data__c pd : [
            SELECT Id, Product_Code__c, Plant__c
            FROM Plant_Data__c
            WHERE Product_Code__c IN :productCodes
        ]) {
            existingPlantMap.put(pd.Product_Code__c + '/' + pd.Plant__c, pd);
        }

        Map<String, Sales_Area_Data__c> existingSalesAreaMap = new Map<String, Sales_Area_Data__c>();
        for (Sales_Area_Data__c sad : [
            SELECT Id, Plant_Data__r.Product_Code__c, Plant_Data__r.Plant__c, Sales_Org__c, Distribution_Channel__c, Division__c
            FROM Sales_Area_Data__c
            WHERE Plant_Data__r.Product_Code__c IN :productCodes
        ]) {
            String key = sad.Plant_Data__r.Product_Code__c + '/' + sad.Plant_Data__r.Plant__c + '/' + sad.Sales_Org__c + '/' + sad.Distribution_Channel__c + '/' + sad.Division__c;
            existingSalesAreaMap.put(key, sad);
        }

        List<Product2> productsToUpsert = new List<Product2>();
        Map<String, Id> parentCodeToIdMap = new Map<String, Id>();

        for (IntegrationRequestBuilder.materialsList parent : parentWrappers) {
            if (String.isBlank(parent.item_no)) {
                continue;
            }

            Product2 prod = existingProductsMap.containsKey(parent.item_no) ? existingProductsMap.get(parent.item_no) : new Product2();

            prod.Name = parent.item_description;
            prod.ProductCode = parent.item_no;
            prod.Item_No__c = parent.item_no;
            prod.Item_Description__c = parent.item_description;
            prod.Description = parent.long_description + ' (' + String.valueOf(dateOfExc) + ')';
            prod.Base_UOM__c = parent.base_uom;
            prod.Mat_Group__c = parent.mat_group;
            prod.SAP_Integration__c = true;
            prod.IsActive = true;
            prod.SAP_Created_On_Date__c = parseDate(parent.created_on_date);
            prod.SAP_Changed_On_Date__c = parseDate(parent.changed_on_date);

            productsToUpsert.add(prod);
        }

        if (!productsToUpsert.isEmpty()) {
            upsert productsToUpsert;
        }

        for (Product2 p : productsToUpsert) {
            parentCodeToIdMap.put(p.ProductCode, p.Id);
        }

        List<Plant_Data__c> plantsToUpsert = new List<Plant_Data__c>();
        Map<String, Id> plantKeyToIdMap = new Map<String, Id>();

        for (IntegrationRequestBuilder.materialsList parentWrapper : parentWrappers) {
            Id parentId = parentCodeToIdMap.get(parentWrapper.item_no);
            if (parentWrapper.to_plant_data == null || parentWrapper.to_plant_data.results == null || parentId == null) {
                continue;
            }

            for (IntegrationRequestBuilder.toPlantDataList childWrapper : parentWrapper.to_plant_data.results) {
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

        if (!plantsToUpsert.isEmpty()) {
            upsert plantsToUpsert;
        }

        for (Plant_Data__c p : plantsToUpsert) {
            plantKeyToIdMap.put(p.Product_Code__c + '/' + p.Plant__c, p.Id);
        }

        List<Sales_Area_Data__c> salesAreasToUpsert = new List<Sales_Area_Data__c>();

        for (IntegrationRequestBuilder.materialsList parentWrapper : parentWrappers) {
            if (parentWrapper.to_plant_data == null || parentWrapper.to_plant_data.results == null) {
                continue;
            }

            for (IntegrationRequestBuilder.toPlantDataList childWrapper : parentWrapper.to_plant_data.results) {
                Id plantId = plantKeyToIdMap.get(parentWrapper.item_no + '/' + childWrapper.plant);
                if (childWrapper.to_salesarea_data == null || childWrapper.to_salesarea_data.results == null || plantId == null) {
                    continue;
                }

                for (IntegrationRequestBuilder.salesAreaDataList grandchildWrapper : childWrapper.to_salesarea_data.results) {
                    String saKey = parentWrapper.item_no + '/' + childWrapper.plant + '/' + grandchildWrapper.sales_org + '/' + grandchildWrapper.distribution_channel + '/' + grandchildWrapper.division;
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

        if (!salesAreasToUpsert.isEmpty()) {
            upsert salesAreasToUpsert;
        }

        return productsToUpsert.size();
    }

    private static Decimal parseDecimal(String value) {
        return String.isNotBlank(value) ? Decimal.valueOf(value) : null;
    }

    private static Integer parseInteger(String value) {
        return String.isNotBlank(value) ? Integer.valueOf(value) : null;
    }

    private static Date parseDate(String value) {
        return String.isNotBlank(value) ? Date.valueOf(value) : null;
    }

    private static void logApiResponse(String apiName, HttpResponse resp) {
        String body = resp != null && resp.getBody() != null ? resp.getBody() : '';
        Integer safeLength = Math.min(body.length(), LOG_MAX_LENGTH);
        UtilityCls.logApiCall(apiName, '', '', body.substring(0, safeLength), '', resp != null ? resp.getStatusCode() : 0);
    }

    public class SyncResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String variant;

        public SyncResult(Boolean success, String message, String variant) {
            this.success = success;
            this.message = message;
            this.variant = variant;
        }
    }

    private class CustomerSyncPayload {
        private List<IntegrationRequestBuilder.customersList> customers;
        private Date dateOfExc;

        private CustomerSyncPayload(List<IntegrationRequestBuilder.customersList> customers, Date dateOfExc) {
            this.customers = customers;
            this.dateOfExc = dateOfExc;
        }
    }

    private class MaterialSyncPayload {
        private List<IntegrationRequestBuilder.materialsList> materials;
        private Date dateOfExc;

        private MaterialSyncPayload(List<IntegrationRequestBuilder.materialsList> materials, Date dateOfExc) {
            this.materials = materials;
            this.dateOfExc = dateOfExc;
        }
    }
}