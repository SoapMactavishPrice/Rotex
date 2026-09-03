public without sharing class ProductController {

    public class PriceEntryInput {
        @AuraEnabled public String currencyIsoCode { get; set; }
        @AuraEnabled public Decimal unitPrice { get; set; }
        @AuraEnabled public String validFrom { get; set; }
        @AuraEnabled public String validTo { get; set; }
    }

    public class ProductCreateInput {
        @AuraEnabled public Id productId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String productCode { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Boolean isActive { get; set; }
        @AuraEnabled public String hsnCode { get; set; }
        @AuraEnabled public Id partnerAccountId { get; set; }
        @AuraEnabled public List<PriceEntryInput> priceEntries { get; set; }
    }

    public class PriceEntryWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String currencyIsoCode;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public String validFrom;
        @AuraEnabled public String validTo;
    }

    public class ProductWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String productCode;
        @AuraEnabled public String description;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public String hsnCode;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Id mappingId;
        @AuraEnabled public List<PriceEntryWrapper> priceEntries;
    }

    @AuraEnabled(cacheable=true)
    public static Id getMyChannelPartnerAccountId() {
        return resolvePartnerAccountId(null);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCurrencyPicklistValues() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (Schema.PicklistEntry entry : PricebookEntry.CurrencyIsoCode.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<ProductWrapper> getMyProducts() {
        Id partnerId = resolvePartnerAccountId(null);
        if (partnerId == null) {
            return new List<ProductWrapper>();
        }

        List<Product_CP_Mapping__c> mappings = [
            SELECT Id, CP_Product_Code__c, Product__c,
                   Product__r.Name, Product__r.ProductCode, Product__r.Description,
                   Product__r.IsActive, Product__r.CreatedDate
            FROM Product_CP_Mapping__c
            WHERE Channel_Partner_Name__c = :partnerId
              AND Product__c != null
            ORDER BY CreatedDate DESC
        ];

        Set<Id> productIds = new Set<Id>();
        for (Product_CP_Mapping__c m : mappings) {
            productIds.add(m.Product__c);
        }

        Map<Id, String> hsnByProductId = getHsnByProductId(productIds);

        List<ProductWrapper> results = new List<ProductWrapper>();
        for (Product_CP_Mapping__c m : mappings) {
            ProductWrapper w = new ProductWrapper();
            w.id = m.Product__c;
            w.mappingId = m.Id;
            w.name = m.Product__r != null ? m.Product__r.Name : '';
            w.productCode = m.Product__r != null ? m.Product__r.ProductCode : m.CP_Product_Code__c;
            w.description = m.Product__r != null ? m.Product__r.Description : '';
            w.isActive = m.Product__r != null ? m.Product__r.IsActive : false;
            w.createdDate = m.Product__r != null ? m.Product__r.CreatedDate : null;
            w.hsnCode = hsnByProductId.containsKey(m.Product__c)
                ? hsnByProductId.get(m.Product__c)
                : '';
            w.priceEntries = new List<PriceEntryWrapper>();
            results.add(w);
        }
        return results;
    }

    @AuraEnabled
    public static ProductWrapper getProductById(Id productId) {
        if (productId == null) {
            throw new AuraHandledException('Product Id is required.');
        }
        assertProductAccessible(productId);
        return queryProductWrapper(productId);
    }

    /**
     * Products page only: Description / HSN for a Rotex catalogue Product2.
     * Does not change quote Add Product APIs.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getRotexProductExtras(Id product2Id) {
        Map<String, Object> result = new Map<String, Object>{
            'description' => null,
            'hsnCode' => null
        };
        if (product2Id == null) {
            return result;
        }
        List<Product2> products = [
            SELECT Id, Description
            FROM Product2
            WHERE Id = :product2Id
            LIMIT 1
        ];
        if (products.isEmpty()) {
            return result;
        }
        result.put('description', products[0].Description);
        Map<Id, String> hsnMap = getHsnByProductId(new Set<Id>{ product2Id });
        if (hsnMap.containsKey(product2Id)) {
            result.put('hsnCode', hsnMap.get(product2Id));
        }
        return result;
    }

    @AuraEnabled
    public static ProductWrapper createProduct(ProductCreateInput input) {
        if (input == null) {
            throw new AuraHandledException('Product details are required.');
        }
        if (String.isBlank(input.name)) {
            throw new AuraHandledException('Product Name is required.');
        }
        if (String.isBlank(input.productCode)) {
            throw new AuraHandledException('Product Code is required.');
        }
        if (String.isBlank(input.description)) {
            throw new AuraHandledException('Product Description is required.');
        }
        if (input.isActive == null) {
            throw new AuraHandledException('Active is required.');
        }

        Id partnerId = resolvePartnerAccountId(input.partnerAccountId);
        if (partnerId == null) {
            throw new AuraHandledException('Channel Partner account could not be resolved.');
        }

        String code = normalizePartnerProductCode(input.productCode);
        assertProductCodeUniqueForPartner(code, partnerId, null);

        Savepoint sp = Database.setSavepoint();
        try {
            Product2 product = new Product2();
            applyInputToProduct(product, input);
            product.Item_No__c = code;
            insert product;

            Product_CP_Mapping__c mapping = new Product_CP_Mapping__c();
            mapping.Channel_Partner_Name__c = partnerId;
            mapping.Product__c = product.Id;
            mapping.CP_Product_Code__c = code;
            insert mapping;

            upsertPlantData(product.Id, code, input.hsnCode);
            upsertPricebookEntries(product.Id, partnerId, input.priceEntries, true);

            return queryProductWrapper(product.Id);
        } catch (DmlException e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static ProductWrapper updateProduct(ProductCreateInput input) {
        if (input == null || input.productId == null) {
            throw new AuraHandledException('Product Id is required.');
        }
        if (String.isBlank(input.name)) {
            throw new AuraHandledException('Product Name is required.');
        }
        if (String.isBlank(input.productCode)) {
            throw new AuraHandledException('Product Code is required.');
        }
        if (String.isBlank(input.description)) {
            throw new AuraHandledException('Product Description is required.');
        }
        if (input.isActive == null) {
            throw new AuraHandledException('Active is required.');
        }

        Id partnerId = resolvePartnerAccountId(input.partnerAccountId);
        if (partnerId == null) {
            throw new AuraHandledException('Channel Partner account could not be resolved.');
        }

        assertProductAccessible(input.productId);

        String code = normalizePartnerProductCode(input.productCode);
        assertProductCodeUniqueForPartner(code, partnerId, input.productId);

        Savepoint sp = Database.setSavepoint();
        try {
            Product2 product = [
                SELECT Id
                FROM Product2
                WHERE Id = :input.productId
                LIMIT 1
            ];
            applyInputToProduct(product, input);
            product.Item_No__c = code;
            update product;

            List<Product_CP_Mapping__c> mappings = [
                SELECT Id, CP_Product_Code__c
                FROM Product_CP_Mapping__c
                WHERE Product__c = :input.productId
                  AND Channel_Partner_Name__c = :partnerId
                LIMIT 1
            ];
            if (!mappings.isEmpty()) {
                mappings[0].CP_Product_Code__c = code;
                update mappings;
            }

            upsertPlantData(product.Id, code, input.hsnCode);
            upsertPricebookEntries(product.Id, partnerId, input.priceEntries, false);

            return queryProductWrapper(product.Id);
        } catch (DmlException e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static void applyInputToProduct(Product2 product, ProductCreateInput input) {
        product.Name = input.name.trim();
        product.ProductCode = normalizePartnerProductCode(input.productCode);
        product.Description = input.description.trim();
        product.IsActive = input.isActive == true;
    }

    /** Non-ROTEX partner products use ProductCode prefix CP (not shown on Self / Secondary ROTEX). */
    private static String normalizePartnerProductCode(String productCode) {
        String code = productCode == null ? '' : productCode.trim();
        if (String.isBlank(code)) {
            return code;
        }
        if (code.length() >= 2 && code.substring(0, 2).equalsIgnoreCase('CP')) {
            return code;
        }
        return 'CP' + code;
    }

    private static void upsertPlantData(Id productId, String productCode, String hsnCode) {
        List<Plant_Data__c> existing = [
            SELECT Id, HSN_Code__c, Product_Code__c, Plant__c
            FROM Plant_Data__c
            WHERE Product__c = :productId
              AND Plant__c = '1100'
            LIMIT 1
        ];

        Plant_Data__c plant;
        if (!existing.isEmpty()) {
            plant = existing[0];
        } else {
            plant = new Plant_Data__c();
            plant.Product__c = productId;
            plant.Plant__c = '1100';
            plant.Name = productCode;
        }
        plant.Product_Code__c = productCode;
        plant.HSN_Code__c = String.isBlank(hsnCode) ? null : hsnCode.trim();

        if (plant.Id == null) {
            insert plant;
        } else {
            update plant;
        }
    }

    private static void upsertPricebookEntries(
        Id productId,
        Id partnerId,
        List<PriceEntryInput> entries,
        Boolean requireAtLeastOne
    ) {
        List<PriceEntryInput> cleaned = new List<PriceEntryInput>();
        Set<String> seenCurrencies = new Set<String>();
        if (entries != null) {
            for (PriceEntryInput entry : entries) {
                if (entry == null || String.isBlank(entry.currencyIsoCode) || entry.unitPrice == null) {
                    continue;
                }
                String currencyCode = entry.currencyIsoCode.trim();
                if (seenCurrencies.contains(currencyCode)) {
                    throw new AuraHandledException(
                        'Duplicate Currency in Price Information: ' + currencyCode
                    );
                }
                seenCurrencies.add(currencyCode);
                cleaned.add(entry);
            }
        }

        if (requireAtLeastOne && cleaned.isEmpty()) {
            throw new AuraHandledException('Add at least one Price Information row with Currency and List Price.');
        }
        if (cleaned.isEmpty()) {
            return;
        }

        Id pricebookId = resolvePricebookIdForPartner(partnerId);
        Pricebook2 customPb = [
            SELECT Id, Distribution_Channel__c
            FROM Pricebook2
            WHERE Id = :pricebookId
            LIMIT 1
        ];
        String distChannel = customPb.Distribution_Channel__c;
        if (String.isBlank(distChannel)) {
            distChannel = '10';
        }

        Id standardPbId = [
            SELECT Id
            FROM Pricebook2
            WHERE IsStandard = true
            LIMIT 1
        ].Id;

        Map<String, PricebookEntry> existingStdByCurrency = new Map<String, PricebookEntry>();
        for (PricebookEntry pbe : [
            SELECT Id, CurrencyIsoCode, UnitPrice
            FROM PricebookEntry
            WHERE Product2Id = :productId
              AND Pricebook2Id = :standardPbId
        ]) {
            existingStdByCurrency.put(pbe.CurrencyIsoCode, pbe);
        }

        Map<String, PricebookEntry> existingCustomByCurrency = new Map<String, PricebookEntry>();
        for (PricebookEntry pbe : [
            SELECT Id, CurrencyIsoCode, UnitPrice, Valid_From__c, Valid_To__c,
                   Sales_Org__c, Distribution_Channel__c, Unit_of_Measure__c, Pricing_Unit__c
            FROM PricebookEntry
            WHERE Product2Id = :productId
              AND Pricebook2Id = :pricebookId
        ]) {
            existingCustomByCurrency.put(pbe.CurrencyIsoCode, pbe);
        }

        List<PricebookEntry> stdInserts = new List<PricebookEntry>();
        List<PricebookEntry> stdUpdates = new List<PricebookEntry>();
        List<PricebookEntry> customInserts = new List<PricebookEntry>();
        List<PricebookEntry> customUpdates = new List<PricebookEntry>();

        for (PriceEntryInput entry : cleaned) {
            String currencyCode = entry.currencyIsoCode.trim();
            Date validFrom = parseDate(entry.validFrom);
            Date validTo = parseDate(entry.validTo);

            if (existingStdByCurrency.containsKey(currencyCode)) {
                PricebookEntry std = existingStdByCurrency.get(currencyCode);
                std.UnitPrice = entry.unitPrice;
                std.IsActive = true;
                stdUpdates.add(std);
            } else {
                PricebookEntry std = new PricebookEntry();
                std.Pricebook2Id = standardPbId;
                std.Product2Id = productId;
                std.CurrencyIsoCode = currencyCode;
                std.UnitPrice = entry.unitPrice;
                std.IsActive = true;
                std.UseStandardPrice = false;
                stdInserts.add(std);
            }

            if (existingCustomByCurrency.containsKey(currencyCode)) {
                PricebookEntry custom = existingCustomByCurrency.get(currencyCode);
                custom.UnitPrice = entry.unitPrice;
                custom.IsActive = true;
                custom.Valid_From__c = validFrom;
                custom.Valid_To__c = validTo;
                custom.Sales_Org__c = '1100';
                custom.Distribution_Channel__c = distChannel;
                custom.Unit_of_Measure__c = 'NOS';
                custom.Pricing_Unit__c = 1;
                customUpdates.add(custom);
            } else {
                PricebookEntry custom = new PricebookEntry();
                custom.Pricebook2Id = pricebookId;
                custom.Product2Id = productId;
                custom.CurrencyIsoCode = currencyCode;
                custom.UnitPrice = entry.unitPrice;
                custom.IsActive = true;
                custom.UseStandardPrice = false;
                custom.Valid_From__c = validFrom;
                custom.Valid_To__c = validTo;
                custom.Sales_Org__c = '1100';
                custom.Distribution_Channel__c = distChannel;
                custom.Unit_of_Measure__c = 'NOS';
                custom.Pricing_Unit__c = 1;
                customInserts.add(custom);
            }
        }

        if (!stdInserts.isEmpty()) {
            insert stdInserts;
        }
        if (!stdUpdates.isEmpty()) {
            update stdUpdates;
        }
        if (!customInserts.isEmpty()) {
            insert customInserts;
        }
        if (!customUpdates.isEmpty()) {
            update customUpdates;
        }
    }

    /**
     * One Channel Partner = one Price Book (Pricebook2.Channel_Partner__c).
     * Finds existing active book; creates it if missing (used on product save).
     */
    public static Id resolveOrCreatePartnerPricebook(Id partnerId) {
        if (partnerId == null) {
            throw new AuraHandledException('Channel Partner account could not be resolved.');
        }

        List<Pricebook2> existing = [
            SELECT Id, Name
            FROM Pricebook2
            WHERE Channel_Partner__c = :partnerId
              AND IsActive = true
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            syncAccountPricelist(partnerId, existing[0].Id);
            return existing[0].Id;
        }

        Account partner = [
            SELECT Id, Name
            FROM Account
            WHERE Id = :partnerId
            LIMIT 1
        ];

        String distChannel = '10';
        List<Sales_Area_Item__c> salesAreas = [
            SELECT Distribution_Channel__c
            FROM Sales_Area_Item__c
            WHERE Account__c = :partnerId
              AND Sales_Org__c = '1100'
            LIMIT 1
        ];
        if (!salesAreas.isEmpty() && String.isNotBlank(salesAreas[0].Distribution_Channel__c)) {
            distChannel = salesAreas[0].Distribution_Channel__c;
        }

        Pricebook2 pb = new Pricebook2();
        pb.Name = String.isNotBlank(partner.Name) ? partner.Name : 'Partner Price Book';
        pb.IsActive = true;
        pb.Channel_Partner__c = partnerId;
        pb.Distribution_Channel__c = distChannel;
        insert pb;

        syncAccountPricelist(partnerId, pb.Id);
        return pb.Id;
    }

    /**
     * Find partner price book only (no create). Used when listing products / creating quotes.
     */
    public static Id findPartnerPricebookId(Id partnerId) {
        if (partnerId == null) {
            return null;
        }
        List<Pricebook2> existing = [
            SELECT Id
            FROM Pricebook2
            WHERE Channel_Partner__c = :partnerId
              AND IsActive = true
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        return existing.isEmpty() ? null : existing[0].Id;
    }

    public static String findPartnerPricebookName(Id pricebookId) {
        if (pricebookId == null) {
            return null;
        }
        List<Pricebook2> rows = [
            SELECT Name
            FROM Pricebook2
            WHERE Id = :pricebookId
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0].Name;
    }

    private static void syncAccountPricelist(Id partnerId, Id pricebookId) {
        if (partnerId == null || pricebookId == null) {
            return;
        }
        List<Account> accounts = [
            SELECT Id, Pricelist__c
            FROM Account
            WHERE Id = :partnerId
            LIMIT 1
        ];
        if (accounts.isEmpty()) {
            return;
        }
        if (accounts[0].Pricelist__c != pricebookId) {
            accounts[0].Pricelist__c = pricebookId;
            update accounts;
        }
    }

    private static Id resolvePricebookIdForPartner(Id partnerId) {
        return resolveOrCreatePartnerPricebook(partnerId);
    }

    private static Date parseDate(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return Date.valueOf(value.trim());
        } catch (Exception e) {
            return null;
        }
    }

    private static Map<Id, String> getHsnByProductId(Set<Id> productIds) {
        Map<Id, String> result = new Map<Id, String>();
        if (productIds == null || productIds.isEmpty()) {
            return result;
        }
        for (Plant_Data__c pd : [
            SELECT Product__c, HSN_Code__c
            FROM Plant_Data__c
            WHERE Product__c IN :productIds
              AND Plant__c = '1100'
              AND HSN_Code__c != null
        ]) {
            if (!result.containsKey(pd.Product__c)) {
                result.put(pd.Product__c, pd.HSN_Code__c);
            }
        }
        return result;
    }

    private static ProductWrapper queryProductWrapper(Id productId) {
        Product2 product = [
            SELECT Id, Name, ProductCode, Description, IsActive, CreatedDate
            FROM Product2
            WHERE Id = :productId
            LIMIT 1
        ];

        Id partnerId = resolvePartnerAccountId(null);
        Id mappingId = null;
        if (partnerId != null) {
            List<Product_CP_Mapping__c> mappings = [
                SELECT Id
                FROM Product_CP_Mapping__c
                WHERE Product__c = :productId
                  AND Channel_Partner_Name__c = :partnerId
                LIMIT 1
            ];
            if (!mappings.isEmpty()) {
                mappingId = mappings[0].Id;
            }
        }

        Map<Id, String> hsnMap = getHsnByProductId(new Set<Id>{ productId });

        ProductWrapper w = new ProductWrapper();
        w.id = product.Id;
        w.mappingId = mappingId;
        w.name = product.Name;
        w.productCode = product.ProductCode;
        w.description = product.Description;
        w.isActive = product.IsActive;
        w.createdDate = product.CreatedDate;
        w.hsnCode = hsnMap.containsKey(productId) ? hsnMap.get(productId) : '';
        w.priceEntries = queryPriceEntries(productId, partnerId);
        return w;
    }

    private static List<PriceEntryWrapper> queryPriceEntries(Id productId, Id partnerId) {
        List<PriceEntryWrapper> results = new List<PriceEntryWrapper>();
        if (productId == null || partnerId == null) {
            return results;
        }

        Id pricebookId;
        try {
            pricebookId = resolvePricebookIdForPartner(partnerId);
        } catch (Exception e) {
            return results;
        }

        for (PricebookEntry pbe : [
            SELECT Id, CurrencyIsoCode, UnitPrice, Valid_From__c, Valid_To__c
            FROM PricebookEntry
            WHERE Product2Id = :productId
              AND Pricebook2Id = :pricebookId
            ORDER BY CurrencyIsoCode ASC
        ]) {
            PriceEntryWrapper row = new PriceEntryWrapper();
            row.id = pbe.Id;
            row.currencyIsoCode = pbe.CurrencyIsoCode;
            row.unitPrice = pbe.UnitPrice;
            row.validFrom = pbe.Valid_From__c == null ? null : String.valueOf(pbe.Valid_From__c);
            row.validTo = pbe.Valid_To__c == null ? null : String.valueOf(pbe.Valid_To__c);
            results.add(row);
        }
        return results;
    }

    private static void assertProductAccessible(Id productId) {
        Id partnerId = resolvePartnerAccountId(null);
        if (partnerId == null) {
            throw new AuraHandledException('Channel Partner account could not be resolved.');
        }
        List<Product_CP_Mapping__c> mappings = [
            SELECT Id
            FROM Product_CP_Mapping__c
            WHERE Product__c = :productId
              AND Channel_Partner_Name__c = :partnerId
            LIMIT 1
        ];
        if (mappings.isEmpty()) {
            throw new AuraHandledException('Unauthorised product operation.');
        }
    }

    private static void assertProductCodeUniqueForPartner(String productCode, Id partnerId, Id excludeProductId) {
        List<Product_CP_Mapping__c> existing = [
            SELECT Id, Product__c
            FROM Product_CP_Mapping__c
            WHERE Channel_Partner_Name__c = :partnerId
              AND CP_Product_Code__c = :productCode
            LIMIT 1
        ];
        if (!existing.isEmpty() && existing[0].Product__c != excludeProductId) {
            throw new AuraHandledException('A product with this Product Code already exists for your account.');
        }
    }

    private static Id resolvePartnerAccountId(Id partnerAccountId) {
        if (partnerAccountId != null) {
            return partnerAccountId;
        }
        List<User> users = [
            SELECT AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (!users.isEmpty() && users[0].AccountId != null) {
            return users[0].AccountId;
        }
        return null;
    }
}