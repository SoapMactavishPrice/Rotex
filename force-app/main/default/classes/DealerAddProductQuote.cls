public without sharing class DealerAddProductQuote {

    /** Keep each JSON chunk small enough for sync Apex heap (full catalogue is large). */
    private static final Integer PRODUCT_JSON_CHUNK_SIZE = 100;

    @AuraEnabled
    public static String findProduct(String recordId, List<String> productFamily, String searchKey, Integer batchNo) {
        try {
            assertQuoteAccessible(recordId);

            Quote qt = [
                SELECT Id, AccountId, QuoteAccountId, Account__c, Pricebook2Id, Pricebook2.Name, Pricebook2.Distribution_Channel__c
                FROM Quote
                WHERE Id = :recordId
            ];

            if (qt == null) {
                return JSON.serialize(new Map<String, Object>{
                    'error' => 'Quote not found'
                });
            }

            Id customerAccountId = resolveQuoteCustomerAccountId(qt);
            List<Sales_Area_Item__c> salesAreaItemList = [
                SELECT Id, Name, Sales_Org__c, Distribution_Channel__c, Division__c, Incoterms__c, CurrencyIsoCode
                FROM Sales_Area_Item__c
                WHERE Account__c = :customerAccountId
                AND Sales_Org__c = '1100'
                AND Distribution_Channel__c = :qt.Pricebook2.Distribution_Channel__c
            ];

            if (salesAreaItemList.isEmpty()) {
                return JSON.serialize(new Map<String, Object>{
                    'error' => 'No Sales Area Item Found'
                });
            }

            wrapperClass wc = new wrapperClass();
            wc.priceBook = qt.Pricebook2.Name;

            String salesAreaCurrency = salesAreaItemList[0].CurrencyIsoCode;

            String query = 'SELECT Id, UnitPrice, Product2Id, ' +
                'Product2.Name, Product2.Family, ' +
                'Product2.ProductCode, Product2.Description, CurrencyIsoCode, Product2.Item_Type__c, Product2.Status__c ' +
                'FROM PricebookEntry ' +
                'WHERE Distribution_Channel__c = \'' + salesAreaItemList[0].Distribution_Channel__c + '\' ' +
                'AND Sales_Org__c = \'1100\' ' +
                'AND Pricebook2Id = \'' + qt.Pricebook2Id + '\' ' +
                'AND CurrencyIsoCode = \'' + salesAreaCurrency + '\' ' +
                'AND Product2Id IN (SELECT Product__c FROM Plant_Data__c WHERE Plant__c = \'1100\') ' +
            'AND (NOT Product2.ProductCode LIKE \'CP%\') ';

            if (searchKey != null && searchKey != '') {
                String escapedSearchKey = String.escapeSingleQuotes(searchKey);
                query += 'AND (Product2.Name LIKE \'%' + escapedSearchKey + '%\' OR Product2.ProductCode LIKE \'%' + escapedSearchKey + '%\')';
            }
            query += 'ORDER BY Product2.ProductCode ASC';

            List<PricebookEntry> templstPBE = (List<PricebookEntry>) Database.query(query);
            List<PricebookEntry> lstPBE = new List<PricebookEntry>();

            Integer size = templstPBE.size();
            Integer mid = Integer.valueOf(Math.ceil((Decimal)size / 2));

            List<PricebookEntry> firstHalf = new List<PricebookEntry>();
            List<PricebookEntry> secondHalf = new List<PricebookEntry>();

            for (Integer x = 0; x < templstPBE.size(); x++) {
                if (x < mid) {
                    firstHalf.add(templstPBE[x]);
                } else {
                    secondHalf.add(templstPBE[x]);
                }
            }

            if (batchNo == 1) {
                lstPBE = firstHalf;
            } else if (batchNo == 2) {
                lstPBE = secondHalf;
            }

            Map<String, Customer_ARC_Pricing__c> arcProductMap = new Map<String, Customer_ARC_Pricing__c>();
            for (Customer_ARC_Pricing__c ca : [
                SELECT Id, Name, Customer__c, Amount__c, Material__c, Material__r.ProductCode,
                    Scale_Qty1__c, Scale_Qty2__c, Scale_Qty3__c, Scale_Qty4__c, Scale_Qty5__c,
                    Scale_Amt1__c, Scale_Amt2__c, Scale_Amt3__c, Scale_Amt4__c, Scale_Amt5__c, Active__c, CurrencyIsoCode
                FROM Customer_ARC_Pricing__c
                WHERE Customer__c = :customerAccountId
                AND Material__c != null
                AND Sales_Organization__c = '1100'
                AND Distribution_Channel__c = :salesAreaItemList[0].Distribution_Channel__c
                AND Active__c = true
                AND CurrencyIsoCode = :salesAreaCurrency
            ]) {
                arcProductMap.put(ca.Material__r.ProductCode, ca);
            }

            Date todayDate = Date.today();
            List<Incoterm__c> incotermsList = [
                SELECT Id, Name, Sales_Org__c, Distribution_Channel__c, Division__c, Valid_From__c, Valid_To__c, Incoterm_Percent__c
                FROM Incoterm__c
                WHERE Name = :salesAreaItemList[0].Incoterms__c
                AND Sales_Org__c = '1100'
                AND Distribution_Channel__c = :salesAreaItemList[0].Distribution_Channel__c
                AND Division__c = :salesAreaItemList[0].Division__c
                AND Valid_From__c <= :todayDate
                AND Valid_To__c >= :todayDate
            ];

            List<ProductWrapper> lstProduct = new List<ProductWrapper>();
            Integer i = 0;
            for (PricebookEntry pbe : lstPBE) {
                ProductWrapper pw = new ProductWrapper();
                pw.Id = pbe.Id;
                pw.purl = '/lightning/r/' + pbe.Id + '/view';
                pw.Product2Id = pbe.Product2Id;
                pw.Name = pbe.Product2.Name;
                pw.ProductCode = pbe.Product2.ProductCode;
                pw.Family = pbe.Product2.Family;
                pw.Description = pbe.Product2.Description;
                pw.Quantity = 0;
                pw.ARCQuantity = 0;
                pw.itemType = pbe.Product2.Item_Type__c;
                pw.CurrencyIsoCode = pbe.CurrencyIsoCode;
                pw.Status = pbe.Product2.Status__c;
                if (arcProductMap.containsKey(pbe.Product2.ProductCode)) {
                    Customer_ARC_Pricing__c cap = arcProductMap.get(pbe.Product2.ProductCode);
                    pw.PriceOption = buildScaleList(cap);
                    pw.Price = cap.Scale_Amt1__c;
                    pw.ListPrice = cap.Scale_Amt1__c;
                    pw.IsARC = true;
                    pw.Quantity = cap.Scale_Qty1__c;
                    pw.ARCQuantity = cap.Scale_Qty1__c;
                } else {
                    pw.Price = pbe.UnitPrice;
                    pw.ListPrice = pbe.UnitPrice;
                    pw.IsARC = false;
                }
                pw.SalesPrice = null;
                if (incotermsList.size() > 0) {
                    pw.Incoterms = incotermsList[0].Incoterm_Percent__c - 100;
                } else {
                    pw.Incoterms = 0;
                }
                pw.index = i++;
                pw.showError = false;
                lstProduct.add(pw);
            }

            wc.productList = lstProduct;
            return JSON.serialize(wc);
        } catch (Exception e) {
            System.debug('Error in findProduct: ' + e.getMessage() + ' at ' + e.getLineNumber());
            return JSON.serialize(new Map<String, Object>{
                'error' => 'An error occurred: ' + e.getMessage()
            });
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<String> findProductsOptimized(String recordId, String searchKey, String itemType) {
        assertQuoteAccessible(recordId);

        Quote qt = [
            SELECT Id, AccountId, QuoteAccountId, Account__c, Pricebook2Id, Pricebook2.Name, Pricebook2.Distribution_Channel__c
            FROM Quote
            WHERE Id = :recordId
        ];

        if (qt == null) {
            return new List<String>{ JSON.serialize(new Map<String, Object>{ 'error' => 'Quote not found' }) };
        }

        Id customerAccountId = resolveQuoteCustomerAccountId(qt);
        List<Sales_Area_Item__c> salesAreaItemList = [
            SELECT Id, Name, Sales_Org__c, Distribution_Channel__c, Division__c, Incoterms__c, CurrencyIsoCode
            FROM Sales_Area_Item__c
            WHERE Account__c = :customerAccountId
            AND Sales_Org__c = '1100'
            AND Distribution_Channel__c = :qt.Pricebook2.Distribution_Channel__c
        ];

        if (salesAreaItemList.isEmpty()) {
            return new List<String>{ JSON.serialize(new Map<String, Object>{ 'error' => 'No Sales Area Item Found' }) };
        }

        String salesAreaCurrency = salesAreaItemList[0].CurrencyIsoCode;

        String query = 'SELECT Id, UnitPrice, Product2Id, ' +
            'Product2.Name, Product2.Family, ' +
            'Product2.ProductCode, Product2.Description, CurrencyIsoCode, Product2.Item_Type__c, Product2.Status__c ' +
            'FROM PricebookEntry ' +
            'WHERE Distribution_Channel__c = \'' + salesAreaItemList[0].Distribution_Channel__c + '\' ' +
            'AND Sales_Org__c = \'1100\' ' +
            'AND Pricebook2Id = \'' + qt.Pricebook2Id + '\' ' +
            'AND CurrencyIsoCode = \'' + salesAreaCurrency + '\' ' +
            'AND Product2Id IN (SELECT Product__c FROM Plant_Data__c WHERE Plant__c = \'1100\') ' +
            'AND (NOT Product2.ProductCode LIKE \'CP%\') ';

        if (String.isNotBlank(searchKey)) {
            String escapedSearchKey = String.escapeSingleQuotes(searchKey);
            query += 'AND (Product2.Name LIKE \'%' + escapedSearchKey + '%\' ' +
                'OR Product2.ProductCode LIKE \'%' + escapedSearchKey + '%\') ';
        }

        if (String.isNotBlank(itemType)) {
            String escapedItemType = String.escapeSingleQuotes(itemType);
            query += 'AND Product2.Item_Type__c = \'' + escapedItemType + '\' ';
        }

        query += 'ORDER BY Product2.ProductCode ASC';

        List<PricebookEntry> lstPBE = Database.query(query);

        Map<String, Customer_ARC_Pricing__c> arcProductMap = new Map<String, Customer_ARC_Pricing__c>();
        for (Customer_ARC_Pricing__c ca : [
            SELECT Id, Name, Customer__c, Amount__c, Material__c, Material__r.ProductCode,
                Scale_Qty1__c, Scale_Qty2__c, Scale_Qty3__c, Scale_Qty4__c, Scale_Qty5__c,
                Scale_Amt1__c, Scale_Amt2__c, Scale_Amt3__c, Scale_Amt4__c, Scale_Amt5__c, Active__c, CurrencyIsoCode
            FROM Customer_ARC_Pricing__c
            WHERE Customer__c = :customerAccountId
            AND Material__c != null
            AND Sales_Organization__c = '1100'
            AND Distribution_Channel__c = :salesAreaItemList[0].Distribution_Channel__c
            AND Active__c = true
            AND CurrencyIsoCode = :salesAreaCurrency
        ]) {
            arcProductMap.put(ca.Material__r.ProductCode, ca);
        }

        Date todayDate = Date.today();
        List<Incoterm__c> incotermsList = [
            SELECT Id, Incoterm_Percent__c
            FROM Incoterm__c
            WHERE Name = :salesAreaItemList[0].Incoterms__c
            AND Sales_Org__c = '1100'
            AND Distribution_Channel__c = :salesAreaItemList[0].Distribution_Channel__c
            AND Division__c = :salesAreaItemList[0].Division__c
            AND Valid_From__c <= :todayDate
            AND Valid_To__c >= :todayDate
            LIMIT 1
        ];

        List<ProductWrapper> lstProduct = new List<ProductWrapper>();
        Integer i = 0;

        for (PricebookEntry pbe : lstPBE) {
            ProductWrapper pw = new ProductWrapper();
            pw.Id = pbe.Id;
            pw.purl = '/lightning/r/' + pbe.Id + '/view';
            pw.Product2Id = pbe.Product2Id;
            pw.Name = pbe.Product2.Name;
            pw.ProductCode = pbe.Product2.ProductCode;
            pw.Family = pbe.Product2.Family;
            pw.Description = pbe.Product2.Description;
            pw.Quantity = 0;
            pw.ARCQuantity = 0;
            pw.itemType = pbe.Product2.Item_Type__c;
            pw.CurrencyIsoCode = pbe.CurrencyIsoCode;
            pw.Status = pbe.Product2.Status__c;
            if (arcProductMap.containsKey(pbe.Product2.ProductCode)) {
                Customer_ARC_Pricing__c cap = arcProductMap.get(pbe.Product2.ProductCode);
                pw.PriceOption = buildScaleList(cap);
                pw.Price = cap.Scale_Amt1__c;
                pw.ListPrice = cap.Scale_Amt1__c;
                pw.IsARC = true;
                pw.Quantity = cap.Scale_Qty1__c;
                pw.ARCQuantity = cap.Scale_Qty1__c;
            } else {
                pw.Price = pbe.UnitPrice;
                pw.ListPrice = pbe.UnitPrice;
                pw.IsARC = false;
            }

            pw.SalesPrice = null;
            pw.Incoterms = incotermsList.isEmpty() ? 0 : incotermsList[0].Incoterm_Percent__c - 100;
            pw.index = i++;
            pw.showError = false;
            lstProduct.add(pw);
        }

        Integer totalSize = lstProduct.size();
        Integer chunkSize = (Integer) Math.ceil(totalSize / 3.0);
        List<String> chunks = new List<String>();

        for (Integer chunkIndex = 0; chunkIndex < 3; chunkIndex++) {
            Integer startIdx = chunkIndex * chunkSize;
            Integer endIdx = Math.min(startIdx + chunkSize, totalSize);

            if (startIdx < totalSize) {
                List<ProductWrapper> chunkData = new List<ProductWrapper>();
                for (Integer idx = startIdx; idx < endIdx; idx++) {
                    chunkData.add(lstProduct[idx]);
                }

                wrapperClass wc = new wrapperClass();
                wc.priceBook = qt.Pricebook2.Name;
                wc.productList = chunkData;
                wc.chunkIndex = chunkIndex;
                wc.totalChunks = 3;
                wc.totalRecords = totalSize;
                chunks.add(JSON.serialize(wc));
            }
        }

        return chunks;
    }

    /**
     * Self / Secondary ROTEX catalogue — Sales Area Distribution Channel catalogue price book
     * (NOT Channel Partner Non-ROTEX price book).
     * Secondary Customer: Sales Area Item is resolved from the CP (login) account first,
     * then the selected customer account as fallback. ARC pricing still uses the customer account.
     */
    @AuraEnabled
    public static List<String> findProductsOptimizedForAccount(String accountId, String searchKey, String itemType) {
        assertAccountAccessible(accountId);

        Id partnerId = resolvePartnerAccountId();
        // Prefer CP Sales Area (Self accountId == partner; Secondary uses CP when customer has none).
        SalesAreaPricebookContext ctx = resolveRotexCatalogueContext(
            partnerId != null ? partnerId : accountId,
            accountId
        );
        if (ctx.error != null) {
            return new List<String>{ JSON.serialize(new Map<String, Object>{ 'error' => ctx.error }) };
        }

        Sales_Area_Item__c salesArea = ctx.salesArea;
        Id pricebookId = ctx.pricebookId;
        String priceBookName = ctx.priceBookName;
        String distChannel = salesArea.Distribution_Channel__c;
        String salesAreaCurrency = salesArea.CurrencyIsoCode;

        // Omit Product2.Description — not shown in portal grid and inflates heap/JSON.
        String query = 'SELECT Id, UnitPrice, Product2Id, ' +
            'Product2.Name, Product2.Family, ' +
            'Product2.ProductCode, CurrencyIsoCode, Product2.Item_Type__c, Product2.Status__c ' +
            'FROM PricebookEntry ' +
            'WHERE Distribution_Channel__c = \'' + String.escapeSingleQuotes(distChannel) + '\' ' +
            'AND Sales_Org__c = \'1100\' ' +
            'AND Pricebook2Id = \'' + String.escapeSingleQuotes(String.valueOf(pricebookId)) + '\' ' +
            'AND CurrencyIsoCode = \'' + String.escapeSingleQuotes(salesAreaCurrency) + '\' ' +
            'AND Product2Id IN (SELECT Product__c FROM Plant_Data__c WHERE Plant__c = \'1100\') ' +
            'AND (NOT Product2.ProductCode LIKE \'CP%\') ';

        if (String.isNotBlank(searchKey)) {
            String escapedSearchKey = String.escapeSingleQuotes(searchKey);
            query += 'AND (Product2.Name LIKE \'%' + escapedSearchKey + '%\' ' +
                'OR Product2.ProductCode LIKE \'%' + escapedSearchKey + '%\') ';
        }

        if (String.isNotBlank(itemType)) {
            String escapedItemType = String.escapeSingleQuotes(itemType);
            query += 'AND Product2.Item_Type__c = \'' + escapedItemType + '\' ';
        }

        query += 'ORDER BY Product2.ProductCode ASC';

        List<PricebookEntry> lstPBE = Database.query(query);

        Map<String, Customer_ARC_Pricing__c> arcProductMap = new Map<String, Customer_ARC_Pricing__c>();
        for (Customer_ARC_Pricing__c ca : [
            SELECT Id, Name, Customer__c, Amount__c, Material__c, Material__r.ProductCode,
                Scale_Qty1__c, Scale_Qty2__c, Scale_Qty3__c, Scale_Qty4__c, Scale_Qty5__c,
                Scale_Amt1__c, Scale_Amt2__c, Scale_Amt3__c, Scale_Amt4__c, Scale_Amt5__c, Active__c, CurrencyIsoCode
            FROM Customer_ARC_Pricing__c
            WHERE Customer__c = :accountId
            AND Material__c != null
            AND Sales_Organization__c = '1100'
            AND Distribution_Channel__c = :distChannel
            AND Active__c = true
            AND CurrencyIsoCode = :salesAreaCurrency
        ]) {
            arcProductMap.put(ca.Material__r.ProductCode, ca);
        }

        Date todayDate = Date.today();
        List<Incoterm__c> incotermsList = [
            SELECT Id, Incoterm_Percent__c
            FROM Incoterm__c
            WHERE Name = :salesArea.Incoterms__c
            AND Sales_Org__c = '1100'
            AND Distribution_Channel__c = :distChannel
            AND Division__c = :salesArea.Division__c
            AND Valid_From__c <= :todayDate
            AND Valid_To__c >= :todayDate
            LIMIT 1
        ];
        Decimal incoPercent = incotermsList.isEmpty() ? 0 : incotermsList[0].Incoterm_Percent__c - 100;

        List<ProductWrapper> lstProduct = new List<ProductWrapper>();
        Integer i = 0;
        for (PricebookEntry pbe : lstPBE) {
            ProductWrapper pw = new ProductWrapper();
            pw.Id = pbe.Id;
            pw.purl = '/lightning/r/' + pbe.Id + '/view';
            pw.Product2Id = pbe.Product2Id;
            pw.Name = pbe.Product2.Name;
            pw.ProductCode = pbe.Product2.ProductCode;
            pw.Family = pbe.Product2.Family;
            pw.Quantity = 0;
            pw.ARCQuantity = 0;
            pw.itemType = pbe.Product2.Item_Type__c;
            pw.CurrencyIsoCode = pbe.CurrencyIsoCode;
            pw.Status = pbe.Product2.Status__c;
            if (arcProductMap.containsKey(pbe.Product2.ProductCode)) {
                Customer_ARC_Pricing__c cap = arcProductMap.get(pbe.Product2.ProductCode);
                pw.PriceOption = buildScaleList(cap);
                pw.Price = cap.Scale_Amt1__c;
                pw.ListPrice = cap.Scale_Amt1__c;
                pw.IsARC = true;
                pw.Quantity = cap.Scale_Qty1__c;
                pw.ARCQuantity = cap.Scale_Qty1__c;
            } else {
                pw.Price = pbe.UnitPrice;
                pw.ListPrice = pbe.UnitPrice;
                pw.IsARC = false;
            }
            pw.SalesPrice = null;
            pw.Incoterms = incoPercent;
            pw.index = i++;
            pw.showError = false;
            lstProduct.add(pw);
        }
        lstPBE = null;
        arcProductMap = null;

        return serializeProductChunks(lstProduct, priceBookName);
    }

    /**
     * Secondary Customer + Business Line ROTEX (or BOTH → Rotex):
     * products from Channel Partner Inventory with Available_Quantity__c > 0.
     * Pricing still comes from the customer's price book.
     */
    @AuraEnabled
    public static List<String> findInventoryProductsForAccount(
        String accountId,
        String searchKey,
        String itemType
    ) {
        assertAccountAccessible(accountId);

        Id partnerId = resolvePartnerAccountId();
        if (partnerId == null) {
            return new List<String>{
                JSON.serialize(new Map<String, Object>{
                    'error' => 'Channel Partner account could not be resolved.'
                })
            };
        }

        Map<Id, Decimal> availableByProduct = new Map<Id, Decimal>();
        for (Inventory__c inv : [
            SELECT Product__c, Available_Quantity__c
            FROM Inventory__c
            WHERE Channel_Partner__c = :partnerId
              AND Product__c != null
              AND Available_Quantity__c > 0
        ]) {
            Decimal qty = inv.Available_Quantity__c != null ? inv.Available_Quantity__c : 0;
            if (availableByProduct.containsKey(inv.Product__c)) {
                availableByProduct.put(
                    inv.Product__c,
                    availableByProduct.get(inv.Product__c) + qty
                );
            } else {
                availableByProduct.put(inv.Product__c, qty);
            }
        }

        if (availableByProduct.isEmpty()) {
            wrapperClass emptyWc = new wrapperClass();
            emptyWc.priceBook = '';
            emptyWc.productList = new List<ProductWrapper>();
            emptyWc.chunkIndex = 0;
            emptyWc.totalChunks = 1;
            emptyWc.totalRecords = 0;
            return new List<String>{ JSON.serialize(emptyWc) };
        }

        // Secondary ROTEX: inventory for availability; Rotex catalogue price book by Sales Area DC
        // (never Channel Partner Non-ROTEX price book). Prefer CP sales area, else customer.
        SalesAreaPricebookContext ctx = resolveRotexCatalogueContext(
            partnerId != null ? partnerId : accountId,
            accountId
        );
        if (ctx.error != null) {
            return new List<String>{ JSON.serialize(new Map<String, Object>{ 'error' => ctx.error }) };
        }

        Sales_Area_Item__c salesArea = ctx.salesArea;
        Id pricebookId = ctx.pricebookId;
        String priceBookName = ctx.priceBookName;

        Set<Id> inventoryProductIds = availableByProduct.keySet();

        // Inventory is the availability source; keep pricebook filters soft so stocked products still appear.
        String query = 'SELECT Id, UnitPrice, Product2Id, ' +
            'Product2.Name, Product2.Family, ' +
            'Product2.ProductCode, Product2.Description, CurrencyIsoCode, Product2.Item_Type__c ' +
            'FROM PricebookEntry ' +
            'WHERE Pricebook2Id = \'' + String.escapeSingleQuotes(String.valueOf(pricebookId)) + '\' ' +
            'AND IsActive = true ' +
            'AND Product2Id IN :inventoryProductIds ' +
            'AND (NOT Product2.ProductCode LIKE \'CP%\') ';

        if (String.isNotBlank(searchKey)) {
            String escapedSearchKey = String.escapeSingleQuotes(searchKey);
            query += 'AND (Product2.Name LIKE \'%' + escapedSearchKey + '%\' ' +
                'OR Product2.ProductCode LIKE \'%' + escapedSearchKey + '%\') ';
        }

        if (String.isNotBlank(itemType)) {
            String escapedItemType = String.escapeSingleQuotes(itemType);
            query += 'AND Product2.Item_Type__c = \'' + escapedItemType + '\' ';
        }

        query += 'ORDER BY Product2.ProductCode ASC';

        List<PricebookEntry> lstPBE = Database.query(query);

        // Fallback: any active PBE for inventory products if catalogue book has no match
        if (lstPBE.isEmpty()) {
            String anyQuery = 'SELECT Id, UnitPrice, Product2Id, ' +
                'Product2.Name, Product2.Family, ' +
                'Product2.ProductCode, Product2.Description, CurrencyIsoCode, Product2.Item_Type__c ' +
                'FROM PricebookEntry ' +
                'WHERE IsActive = true ' +
                'AND Product2Id IN :inventoryProductIds ' +
                'AND (NOT Product2.ProductCode LIKE \'CP%\') ';
            if (String.isNotBlank(searchKey)) {
                String escapedSearchKey = String.escapeSingleQuotes(searchKey);
                anyQuery += 'AND (Product2.Name LIKE \'%' + escapedSearchKey + '%\' ' +
                    'OR Product2.ProductCode LIKE \'%' + escapedSearchKey + '%\') ';
            }
            if (String.isNotBlank(itemType)) {
                String escapedItemType = String.escapeSingleQuotes(itemType);
                anyQuery += 'AND Product2.Item_Type__c = \'' + escapedItemType + '\' ';
            }
            anyQuery += 'ORDER BY Product2.ProductCode ASC';
            lstPBE = Database.query(anyQuery);
        }

        Decimal incotermPercent = 0;
        if (salesArea != null && String.isNotBlank(salesArea.Incoterms__c)) {
            Date todayDate = Date.today();
            List<Incoterm__c> incotermsList = [
                SELECT Id, Incoterm_Percent__c
                FROM Incoterm__c
                WHERE Name = :salesArea.Incoterms__c
                AND Sales_Org__c = '1100'
                AND Distribution_Channel__c = :salesArea.Distribution_Channel__c
                AND Division__c = :salesArea.Division__c
                AND Valid_From__c <= :todayDate
                AND Valid_To__c >= :todayDate
                LIMIT 1
            ];
            if (!incotermsList.isEmpty() && incotermsList[0].Incoterm_Percent__c != null) {
                incotermPercent = incotermsList[0].Incoterm_Percent__c - 100;
            }
        }

        // Deduplicate by Product2Id (prefer first / customer book entry)
        Map<Id, PricebookEntry> pbeByProduct = new Map<Id, PricebookEntry>();
        for (PricebookEntry pbe : lstPBE) {
            if (!pbeByProduct.containsKey(pbe.Product2Id)) {
                pbeByProduct.put(pbe.Product2Id, pbe);
            }
        }

        List<ProductWrapper> lstProduct = new List<ProductWrapper>();
        Integer i = 0;
        Set<Id> productsWithPrice = new Set<Id>();
        for (PricebookEntry pbe : pbeByProduct.values()) {
            if (!availableByProduct.containsKey(pbe.Product2Id)) {
                continue;
            }
            Decimal availableQty = availableByProduct.get(pbe.Product2Id);
            if (availableQty == null || availableQty <= 0) {
                continue;
            }
            productsWithPrice.add(pbe.Product2Id);
            ProductWrapper pw = new ProductWrapper();
            pw.Id = pbe.Id;
            pw.purl = '/lightning/r/' + pbe.Id + '/view';
            pw.Product2Id = pbe.Product2Id;
            pw.Name = pbe.Product2.Name;
            pw.ProductCode = pbe.Product2.ProductCode;
            pw.Family = pbe.Product2.Family;
            pw.Description = pbe.Product2.Description;
            pw.Quantity = 0;
            pw.ARCQuantity = 0;
            pw.itemType = pbe.Product2.Item_Type__c;
            pw.CurrencyIsoCode = pbe.CurrencyIsoCode;
            pw.Status = null;
            pw.Price = pbe.UnitPrice;
            pw.ListPrice = pbe.UnitPrice;
            pw.IsARC = false;
            pw.SalesPrice = null;
            pw.Incoterms = incotermPercent;
            pw.AvailableQuantity = availableQty;
            pw.index = i++;
            pw.showError = false;
            lstProduct.add(pw);
        }

        // Inventory stock without price on chosen book — take any active PBE for that product
        Set<Id> missingPriceIds = new Set<Id>();
        for (Id productId : availableByProduct.keySet()) {
            if (!productsWithPrice.contains(productId)) {
                missingPriceIds.add(productId);
            }
        }
        if (!missingPriceIds.isEmpty()) {
            String anyPbeQuery =
                'SELECT Id, UnitPrice, Product2Id, ' +
                'Product2.Name, Product2.Family, ' +
                'Product2.ProductCode, Product2.Description, CurrencyIsoCode, Product2.Item_Type__c ' +
                'FROM PricebookEntry ' +
                'WHERE IsActive = true AND Product2Id IN :missingPriceIds ';
            if (String.isNotBlank(searchKey)) {
                String escapedSearchKey = String.escapeSingleQuotes(searchKey);
                anyPbeQuery +=
                    'AND (Product2.Name LIKE \'%' +
                    escapedSearchKey +
                    '%\' OR Product2.ProductCode LIKE \'%' +
                    escapedSearchKey +
                    '%\') ';
            }
            if (String.isNotBlank(itemType)) {
                anyPbeQuery +=
                    'AND Product2.Item_Type__c = \'' +
                    String.escapeSingleQuotes(itemType) +
                    '\' ';
            }
            anyPbeQuery += 'ORDER BY Product2.ProductCode ASC';
            for (PricebookEntry pbe : Database.query(anyPbeQuery)) {
                if (productsWithPrice.contains(pbe.Product2Id)) {
                    continue;
                }
                Decimal availableQty = availableByProduct.get(pbe.Product2Id);
                if (availableQty == null || availableQty <= 0) {
                    continue;
                }
                productsWithPrice.add(pbe.Product2Id);
                ProductWrapper pw = new ProductWrapper();
                pw.Id = pbe.Id;
                pw.purl = '/lightning/r/' + pbe.Id + '/view';
                pw.Product2Id = pbe.Product2Id;
                pw.Name = pbe.Product2.Name;
                pw.ProductCode = pbe.Product2.ProductCode;
                pw.Family = pbe.Product2.Family;
                pw.Description = pbe.Product2.Description;
                pw.Quantity = 0;
                pw.ARCQuantity = 0;
                pw.itemType = pbe.Product2.Item_Type__c;
                pw.CurrencyIsoCode = pbe.CurrencyIsoCode;
                pw.Status = null;
                pw.Price = pbe.UnitPrice;
                pw.ListPrice = pbe.UnitPrice;
                pw.IsARC = false;
                pw.SalesPrice = null;
                pw.Incoterms = incotermPercent;
                pw.AvailableQuantity = availableQty;
                pw.index = i++;
                pw.showError = false;
                lstProduct.add(pw);
            }
        }

        Integer totalSize = lstProduct.size();
        Integer chunkSize = totalSize == 0 ? 0 : (Integer) Math.ceil(totalSize / 3.0);
        List<String> chunks = new List<String>();

        if (totalSize == 0) {
            wrapperClass emptyWc = new wrapperClass();
            emptyWc.priceBook = priceBookName;
            emptyWc.productList = new List<ProductWrapper>();
            emptyWc.chunkIndex = 0;
            emptyWc.totalChunks = 1;
            emptyWc.totalRecords = 0;
            chunks.add(JSON.serialize(emptyWc));
            return chunks;
        }

        for (Integer chunkIndex = 0; chunkIndex < 3; chunkIndex++) {
            Integer startIdx = chunkIndex * chunkSize;
            Integer endIdx = Math.min(startIdx + chunkSize, totalSize);
            if (startIdx < totalSize) {
                List<ProductWrapper> chunkData = new List<ProductWrapper>();
                for (Integer idx = startIdx; idx < endIdx; idx++) {
                    chunkData.add(lstProduct[idx]);
                }
                wrapperClass wc = new wrapperClass();
                wc.priceBook = priceBookName;
                wc.productList = chunkData;
                wc.chunkIndex = chunkIndex;
                wc.totalChunks = 3;
                wc.totalRecords = totalSize;
                chunks.add(JSON.serialize(wc));
            }
        }
        return chunks;
    }

    /**
     * Products created by the logged-in Channel Partner (Product_CP_Mapping__c),
     * for Secondary Customer quotes where Business Line = Non ROTEX.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> findPartnerCreatedProductsForAccount(
        String accountId,
        String searchKey,
        String itemType
    ) {
        assertAccountAccessible(accountId);

        Id partnerId = resolvePartnerAccountId();
        if (partnerId == null) {
            return new List<String>{
                JSON.serialize(new Map<String, Object>{
                    'error' => 'Channel Partner account could not be resolved.'
                })
            };
        }

        Set<Id> partnerProductIds = new Set<Id>();
        for (Product_CP_Mapping__c mapping : [
            SELECT Product__c
            FROM Product_CP_Mapping__c
            WHERE Channel_Partner_Name__c = :partnerId
              AND Product__c != null
        ]) {
            partnerProductIds.add(mapping.Product__c);
        }

        if (partnerProductIds.isEmpty()) {
            wrapperClass emptyWc = new wrapperClass();
            emptyWc.priceBook = '';
            emptyWc.productList = new List<ProductWrapper>();
            emptyWc.chunkIndex = 0;
            emptyWc.totalChunks = 1;
            emptyWc.totalRecords = 0;
            return new List<String>{ JSON.serialize(emptyWc) };
        }

        List<Sales_Area_Item__c> salesAreaItemList = [
            SELECT Id, Name, Sales_Org__c, Distribution_Channel__c, Division__c, Incoterms__c, CurrencyIsoCode
            FROM Sales_Area_Item__c
            WHERE Account__c = :partnerId
              AND Sales_Org__c = '1100'
        ];

        Sales_Area_Item__c salesArea = salesAreaItemList.isEmpty() ? null : salesAreaItemList[0];

        // One CP = one Price Book via Pricebook2.Channel_Partner__c
        Id pricebookId = ProductController.findPartnerPricebookId(partnerId);
        String priceBookName = ProductController.findPartnerPricebookName(pricebookId);

        if (pricebookId == null) {
            wrapperClass emptyWc = new wrapperClass();
            emptyWc.priceBook = '';
            emptyWc.productList = new List<ProductWrapper>();
            emptyWc.chunkIndex = 0;
            emptyWc.totalChunks = 1;
            emptyWc.totalRecords = 0;
            return new List<String>{ JSON.serialize(emptyWc) };
        }

        if (salesArea != null
            && String.isNotBlank(priceBookName)
        ) {
            // Prefer sales area matching partner price book distribution channel when available
            List<Pricebook2> pbRows = [
                SELECT Distribution_Channel__c
                FROM Pricebook2
                WHERE Id = :pricebookId
                LIMIT 1
            ];
            if (!pbRows.isEmpty() && String.isNotBlank(pbRows[0].Distribution_Channel__c)) {
                for (Sales_Area_Item__c sai : salesAreaItemList) {
                    if (sai.Distribution_Channel__c == pbRows[0].Distribution_Channel__c) {
                        salesArea = sai;
                        break;
                    }
                }
            }
        }

        String query = 'SELECT Id, UnitPrice, Product2Id, ' +
            'Product2.Name, Product2.Family, ' +
            'Product2.ProductCode, Product2.Description, CurrencyIsoCode, Product2.Item_Type__c ' +
            'FROM PricebookEntry ' +
            'WHERE Pricebook2Id = \'' + String.escapeSingleQuotes(String.valueOf(pricebookId)) + '\' ' +
            'AND Product2Id IN :partnerProductIds ' +
            'AND IsActive = true ' +
            'AND Product2.IsActive = true ' +
            'AND Product2.ProductCode LIKE \'CP%\' ';

        if (String.isNotBlank(searchKey)) {
            String escapedSearchKey = String.escapeSingleQuotes(searchKey);
            query += 'AND (Product2.Name LIKE \'%' + escapedSearchKey + '%\' ' +
                'OR Product2.ProductCode LIKE \'%' + escapedSearchKey + '%\') ';
        }

        if (String.isNotBlank(itemType)) {
            query += 'AND Product2.Item_Type__c = \'' + String.escapeSingleQuotes(itemType) + '\' ';
        }

        query += 'ORDER BY Product2.ProductCode ASC';

        List<PricebookEntry> lstPBE = Database.query(query);

        // Prefer sales-area currency when multiple currencies exist for the same product
        if (salesArea != null && String.isNotBlank(salesArea.CurrencyIsoCode) && !lstPBE.isEmpty()) {
            String preferredCurrency = salesArea.CurrencyIsoCode;
            Map<Id, PricebookEntry> preferredByProduct = new Map<Id, PricebookEntry>();
            Map<Id, PricebookEntry> fallbackByProduct = new Map<Id, PricebookEntry>();
            for (PricebookEntry pbe : lstPBE) {
                if (pbe.Product2Id == null) {
                    continue;
                }
                if (!fallbackByProduct.containsKey(pbe.Product2Id)) {
                    fallbackByProduct.put(pbe.Product2Id, pbe);
                }
                if (pbe.CurrencyIsoCode == preferredCurrency && !preferredByProduct.containsKey(pbe.Product2Id)) {
                    preferredByProduct.put(pbe.Product2Id, pbe);
                }
            }
            List<PricebookEntry> deduped = new List<PricebookEntry>();
            for (Id productId : fallbackByProduct.keySet()) {
                deduped.add(
                    preferredByProduct.containsKey(productId)
                        ? preferredByProduct.get(productId)
                        : fallbackByProduct.get(productId)
                );
            }
            lstPBE = deduped;
        }

        Decimal incoPercent = 0;
        if (salesArea != null && String.isNotBlank(salesArea.Incoterms__c)) {
            Date todayDate = Date.today();
            List<Incoterm__c> incotermsList = [
                SELECT Incoterm_Percent__c
                FROM Incoterm__c
                WHERE Name = :salesArea.Incoterms__c
                  AND Sales_Org__c = '1100'
                  AND Distribution_Channel__c = :salesArea.Distribution_Channel__c
                  AND Division__c = :salesArea.Division__c
                  AND Valid_From__c <= :todayDate
                  AND Valid_To__c >= :todayDate
                LIMIT 1
            ];
            if (!incotermsList.isEmpty() && incotermsList[0].Incoterm_Percent__c != null) {
                incoPercent = incotermsList[0].Incoterm_Percent__c - 100;
            }
        }

        List<ProductWrapper> lstProduct = new List<ProductWrapper>();
        Integer i = 0;
        for (PricebookEntry pbe : lstPBE) {
            ProductWrapper pw = new ProductWrapper();
            pw.Id = pbe.Id;
            pw.purl = '/lightning/r/' + pbe.Id + '/view';
            pw.Product2Id = pbe.Product2Id;
            pw.Name = pbe.Product2.Name;
            pw.ProductCode = pbe.Product2.ProductCode;
            pw.Family = pbe.Product2.Family;
            pw.Description = pbe.Product2.Description;
            pw.Quantity = 0;
            pw.ARCQuantity = 0;
            pw.itemType = pbe.Product2.Item_Type__c;
            pw.CurrencyIsoCode = pbe.CurrencyIsoCode;
            pw.Status = null;
            pw.Price = pbe.UnitPrice;
            pw.ListPrice = pbe.UnitPrice;
            pw.IsARC = false;
            pw.SalesPrice = null;
            pw.Incoterms = incoPercent;
            pw.index = i++;
            pw.showError = false;
            lstProduct.add(pw);
        }

        Integer totalSize = lstProduct.size();
        Integer chunkSize = totalSize == 0 ? 0 : (Integer) Math.ceil(totalSize / 3.0);
        List<String> chunks = new List<String>();

        if (totalSize == 0) {
            wrapperClass emptyWc = new wrapperClass();
            emptyWc.priceBook = priceBookName;
            emptyWc.productList = new List<ProductWrapper>();
            emptyWc.chunkIndex = 0;
            emptyWc.totalChunks = 1;
            emptyWc.totalRecords = 0;
            chunks.add(JSON.serialize(emptyWc));
            return chunks;
        }

        for (Integer chunkIndex = 0; chunkIndex < 3; chunkIndex++) {
            Integer startIdx = chunkIndex * chunkSize;
            Integer endIdx = Math.min(startIdx + chunkSize, totalSize);
            if (startIdx < totalSize) {
                List<ProductWrapper> chunkData = new List<ProductWrapper>();
                for (Integer idx = startIdx; idx < endIdx; idx++) {
                    chunkData.add(lstProduct[idx]);
                }
                wrapperClass wc = new wrapperClass();
                wc.priceBook = priceBookName;
                wc.productList = chunkData;
                wc.chunkIndex = chunkIndex;
                wc.totalChunks = 3;
                wc.totalRecords = totalSize;
                chunks.add(JSON.serialize(wc));
            }
        }
        return chunks;
    }

    @AuraEnabled
    public static String getCustomerDiscountForAccount(String accountId) {
        try {
            assertAccountAccessible(accountId);
            Account acc = [
                SELECT Id, Discount__c
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];
            return JSON.serialize(acc.Discount__c);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static List<Map<String, Decimal>> buildScaleList(Customer_ARC_Pricing__c cap) {
        List<Map<String, Decimal>> scaleList = new List<Map<String, Decimal>>();

        if (cap.Scale_Amt1__c != 0 && cap.Scale_Qty1__c != 0) {
            scaleList.add(new Map<String, Decimal>{ 'label' => cap.Scale_Qty1__c, 'value' => cap.Scale_Amt1__c });
        }
        if (cap.Scale_Amt2__c != 0 && cap.Scale_Qty2__c != 0) {
            scaleList.add(new Map<String, Decimal>{ 'label' => cap.Scale_Qty2__c, 'value' => cap.Scale_Amt2__c });
        }
        if (cap.Scale_Amt3__c != 0 && cap.Scale_Qty3__c != 0) {
            scaleList.add(new Map<String, Decimal>{ 'label' => cap.Scale_Qty3__c, 'value' => cap.Scale_Amt3__c });
        }
        if (cap.Scale_Amt4__c != 0 && cap.Scale_Qty4__c != 0) {
            scaleList.add(new Map<String, Decimal>{ 'label' => cap.Scale_Qty4__c, 'value' => cap.Scale_Amt4__c });
        }
        if (cap.Scale_Amt5__c != 0 && cap.Scale_Qty5__c != 0) {
            scaleList.add(new Map<String, Decimal>{ 'label' => cap.Scale_Qty5__c, 'value' => cap.Scale_Amt5__c });
        }

        return scaleList;
    }

    @AuraEnabled
    public static String getCustomerDiscount(String quoteId) {
        try {
            assertQuoteAccessible(quoteId);

            Quote qt = [
                SELECT Id, AccountId, QuoteAccountId, Account__c,
                    Account.Discount__c, Account__r.Discount__c, QuoteAccount.Discount__c,
                    Pricebook2Id, Pricebook2.Name, CurrencyISOCode
                FROM Quote
                WHERE Id = :quoteId
            ];

            Decimal discount = null;
            if (qt.AccountId != null) {
                discount = qt.Account.Discount__c;
            } else if (qt.Account__c != null) {
                discount = qt.Account__r.Discount__c;
            } else if (qt.QuoteAccountId != null) {
                discount = qt.QuoteAccount.Discount__c;
            }
            return JSON.serialize(discount);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<PicklistValue> getproductfamily() {
        String strObjectName = 'Product2';
        String strPicklistField = 'Family';
        Schema.SObjectType objSobjectType = Schema.getGlobalDescribe().get(strObjectName);
        Schema.DescribeSObjectResult objDescribeSobject = objSobjectType.getDescribe();
        Map<String, Schema.SObjectField> mapFields = objDescribeSobject.fields.getMap();
        List<Schema.PicklistEntry> lstPickListValues = mapFields.get(strPicklistField).getDescribe().getPickListValues();
        List<PicklistValue> pvList = new List<PicklistValue>();
        for (Schema.PicklistEntry objPickList : lstPickListValues) {
            PicklistValue pv = new PicklistValue(objPickList.getValue(), objPickList.getLabel());
            pvList.add(pv);
        }
        return pvList;
    }

    @AuraEnabled
    public static String saveProducts(String recordData, String recId, Double customerSAPdiscount) {
        assertQuoteAccessible(recId);

        List<ProductWrapper> wc = (List<ProductWrapper>) JSON.deserialize(recordData, List<ProductWrapper>.class);
        Map<String, String> plantHsnByCode = buildPlantHsnByProductCode(wc);
        List<QuoteLineItem> lstOpp = new List<QuoteLineItem>();
        for (ProductWrapper pw : wc) {
            QuoteLineItem oli = new QuoteLineItem();
            oli.Quantity = pw.Quantity;
            oli.UnitPrice = pw.Price;
            oli.Discount_as_per_SAP__c = customerSAPdiscount != null ? customerSAPdiscount : 0;
            oli.ServiceDate = System.today();
            oli.Discount_to_be_offered__c = pw.Discount;
            oli.Description = String.isNotBlank(pw.LineDescription) ? pw.LineDescription : pw.Description;
            oli.Customer_Part_No__c = pw.CustomerPartNo;
            if (pw.SellPriceOfSc != null) {
                oli.Sell_Price_of_Sc__c = pw.SellPriceOfSc;
            }
            if (String.isNotBlank(pw.RequestedComments)) {
                oli.Requested_Comments__c = pw.RequestedComments;
            }
            if (pw.PotentialQty != null) {
                oli.Potential_Qty__c = pw.PotentialQty;
            }
            if (String.isNotBlank(pw.ValidFrom)) {
                oli.Valid_from__c = Date.valueOf(pw.ValidFrom);
            }
            if (String.isNotBlank(pw.ValidTill)) {
                oli.Valid_Till__c = Date.valueOf(pw.ValidTill);
            }
            oli.QuoteId = recId;
            oli.Product2Id = pw.Product2Id;
            oli.PricebookEntryId = pw.Id;
            String hsnCode = resolveHsnForProduct(pw, plantHsnByCode);
            if (String.isNotBlank(hsnCode)) {
                oli.HSN_Code__c = hsnCode;
            }
            lstOpp.add(oli);
        }
        try {
            insert lstOpp;
            return 'success';
        } catch (Exception e) {
            System.debug(e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Plant HSN by ProductCode and Product2 Id (CRM plantDataMap parity).
     */
    public static Map<String, String> buildPlantHsnByProductCode(List<ProductWrapper> products) {
        Map<String, String> result = new Map<String, String>();
        if (products == null || products.isEmpty()) {
            return result;
        }

        Set<String> productCodes = new Set<String>();
        Set<Id> productIds = new Set<Id>();
        for (ProductWrapper pw : products) {
            if (pw == null) {
                continue;
            }
            if (String.isNotBlank(pw.ProductCode)) {
                productCodes.add(pw.ProductCode.trim());
            }
            if (String.isNotBlank(pw.Product2Id)) {
                productIds.add((Id) pw.Product2Id);
            }
        }
        if (productCodes.isEmpty() && productIds.isEmpty()) {
            return result;
        }

        addPlantHsnRows(result, [
            SELECT HSN_Code__c, Product_Code__c, Product__c, Product__r.ProductCode
            FROM Plant_Data__c
            WHERE Plant__c = '1100'
              AND HSN_Code__c != null
              AND (
                   Product_Code__c IN :productCodes
                OR Product__r.ProductCode IN :productCodes
                OR Product__c IN :productIds
              )
        ]);

        Set<Id> missingProductIds = new Set<Id>();
        for (Id productId : productIds) {
            if (!result.containsKey(String.valueOf(productId))) {
                missingProductIds.add(productId);
            }
        }
        Set<String> missingProductCodes = new Set<String>();
        for (String productCode : productCodes) {
            if (!result.containsKey(productCode)) {
                missingProductCodes.add(productCode);
            }
        }
        if (!missingProductIds.isEmpty() || !missingProductCodes.isEmpty()) {
            addPlantHsnRows(result, [
                SELECT HSN_Code__c, Product_Code__c, Product__c, Product__r.ProductCode
                FROM Plant_Data__c
                WHERE HSN_Code__c != null
                  AND (
                       Product__c IN :missingProductIds
                    OR Product_Code__c IN :missingProductCodes
                    OR Product__r.ProductCode IN :missingProductCodes
                  )
            ]);
        }

        return result;
    }

    public static Map<Id, String> buildPlantHsnByProductId(Set<Id> productIds) {
        Map<Id, String> result = new Map<Id, String>();
        if (productIds == null || productIds.isEmpty()) {
            return result;
        }

        for (Plant_Data__c pd : [
            SELECT HSN_Code__c, Product__c
            FROM Plant_Data__c
            WHERE Product__c IN :productIds
              AND Plant__c = '1100'
              AND HSN_Code__c != null
        ]) {
            if (pd.Product__c != null && !result.containsKey(pd.Product__c)) {
                result.put(pd.Product__c, pd.HSN_Code__c);
            }
        }

        Set<Id> missingProductIds = new Set<Id>();
        for (Id productId : productIds) {
            if (!result.containsKey(productId)) {
                missingProductIds.add(productId);
            }
        }
        if (!missingProductIds.isEmpty()) {
            for (Plant_Data__c pd : [
                SELECT HSN_Code__c, Product__c
                FROM Plant_Data__c
                WHERE Product__c IN :missingProductIds
                  AND HSN_Code__c != null
            ]) {
                if (pd.Product__c != null && !result.containsKey(pd.Product__c)) {
                    result.put(pd.Product__c, pd.HSN_Code__c);
                }
            }
        }

        return result;
    }

    public static String resolveHsnForProduct(ProductWrapper pw, Map<String, String> hsnLookup) {
        if (pw == null || hsnLookup == null || hsnLookup.isEmpty()) {
            return null;
        }
        if (String.isNotBlank(pw.Product2Id) && hsnLookup.containsKey(pw.Product2Id)) {
            return hsnLookup.get(pw.Product2Id);
        }
        if (String.isNotBlank(pw.ProductCode)) {
            String productCode = pw.ProductCode.trim();
            if (hsnLookup.containsKey(productCode)) {
                return hsnLookup.get(productCode);
            }
        }
        return null;
    }

    private static void addPlantHsnRows(Map<String, String> result, List<Plant_Data__c> plantRows) {
        if (result == null || plantRows == null) {
            return;
        }
        for (Plant_Data__c pd : plantRows) {
            if (pd == null || String.isBlank(pd.HSN_Code__c)) {
                continue;
            }
            if (pd.Product__c != null) {
                String productIdKey = String.valueOf(pd.Product__c);
                if (!result.containsKey(productIdKey)) {
                    result.put(productIdKey, pd.HSN_Code__c);
                }
            }
            String code = String.isNotBlank(pd.Product_Code__c)
                ? pd.Product_Code__c.trim()
                : (pd.Product__r != null ? pd.Product__r.ProductCode : null);
            if (String.isNotBlank(code) && !result.containsKey(code)) {
                result.put(code, pd.HSN_Code__c);
            }
        }
    }

    public with sharing class wrapperClass {
        public String priceBook;
        public List<ProductWrapper> productList;
        public Integer chunkIndex;
        public Integer totalChunks;
        public Integer totalRecords;
    }

    public with sharing class ProductWrapper {
        public String Name;
        public String Id;
        public String purl;
        public String Product2Id;
        public String ProductCode;
        public String PackSize;
        public String hsnMasterId;
        public String hsnMasterCode;
        public Integer index;
        public Decimal Price;
        public Decimal SalesPrice;
        public Decimal ListPrice;
        public Boolean IsARC;
        public List<Map<String, Decimal>> PriceOption;
        public Decimal Quantity;
        public Decimal ARCQuantity;
        public Decimal IncoTerms;
        public String Family;
        public Date PDate;
        public String Description;
        public String LineDescription;
        public String CustomerPartNo;
        public Decimal CGSTRATE;
        public Decimal IGSTRATE;
        public Decimal SGSTRATE;
        public Boolean showError;
        public Decimal Discount = 0;
        public String itemType;
        public String CurrencyIsoCode;
        public String Status;
        public Decimal AvailableQuantity;
        /** Maps to QuoteLineItem.Sell_Price_of_Sc__c — shown as Proposed ARC Price on ARC quotes. */
        public Decimal SellPriceOfSc;
        /** Maps to QuoteLineItem.Requested_Comments__c — Disc. Comments on ARC cart. */
        public String RequestedComments;
        /** Maps to QuoteLineItem.Potential_Qty__c — MOQ on ARC cart. */
        public Decimal PotentialQty;
        /** Maps to QuoteLineItem.Valid_from__c */
        public String ValidFrom;
        /** Maps to QuoteLineItem.Valid_Till__c */
        public String ValidTill;
    }

    public class PicklistValue {
        @AuraEnabled
        public String label { get; set; }
        @AuraEnabled
        public String value { get; set; }

        public PicklistValue(String value, String label) {
            this.value = value;
            this.label = label;
        }
    }

    private static List<String> serializeProductChunks(
        List<ProductWrapper> lstProduct,
        String priceBookName
    ) {
        List<String> chunks = new List<String>();
        Integer totalSize = lstProduct == null ? 0 : lstProduct.size();

        if (totalSize == 0) {
            wrapperClass emptyWc = new wrapperClass();
            emptyWc.priceBook = priceBookName;
            emptyWc.productList = new List<ProductWrapper>();
            emptyWc.chunkIndex = 0;
            emptyWc.totalChunks = 1;
            emptyWc.totalRecords = 0;
            chunks.add(JSON.serialize(emptyWc));
            return chunks;
        }

        Integer chunkSize = PRODUCT_JSON_CHUNK_SIZE;
        Integer totalChunks = (totalSize + chunkSize - 1) / chunkSize;

        for (Integer chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
            Integer startIdx = chunkIndex * chunkSize;
            Integer endIdx = Math.min(startIdx + chunkSize, totalSize);
            List<ProductWrapper> chunkData = new List<ProductWrapper>();
            for (Integer idx = startIdx; idx < endIdx; idx++) {
                chunkData.add(lstProduct[idx]);
                lstProduct[idx] = null;
            }
            wrapperClass wc = new wrapperClass();
            wc.priceBook = priceBookName;
            wc.productList = chunkData;
            wc.chunkIndex = chunkIndex;
            wc.totalChunks = totalChunks;
            wc.totalRecords = totalSize;
            chunks.add(JSON.serialize(wc));
        }
        lstProduct.clear();
        return chunks;
    }

    private static Id resolvePartnerAccountId() {
        List<User> users = [
            SELECT AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        return users.isEmpty() ? null : users[0].AccountId;
    }

    /**
     * Rotex catalogue price book for Self / Secondary ROTEX:
     * Sales Area Item Distribution Channel → Pricebook2 with that DC and Channel_Partner__c = null.
     * Never uses Channel Partner Non-ROTEX price books.
     * primaryAccountId first (CP / Self); fallbackAccountId = secondary customer if needed.
     */
    private class SalesAreaPricebookContext {
        public Sales_Area_Item__c salesArea;
        public Id pricebookId;
        public String priceBookName;
        public String error;
    }

    private static SalesAreaPricebookContext resolveRotexCatalogueContext(
        Id primaryAccountId,
        Id fallbackAccountId
    ) {
        SalesAreaPricebookContext ctx = new SalesAreaPricebookContext();

        Sales_Area_Item__c salesArea = findSalesArea1100(primaryAccountId);
        if (salesArea == null && fallbackAccountId != null && fallbackAccountId != primaryAccountId) {
            salesArea = findSalesArea1100(fallbackAccountId);
        }
        if (salesArea == null || String.isBlank(salesArea.Distribution_Channel__c)) {
            ctx.error = 'No Sales Area Item Found';
            return ctx;
        }

        String distChannel = salesArea.Distribution_Channel__c;
        List<Pricebook2> catalogueBooks = [
            SELECT Id, Name
            FROM Pricebook2
            WHERE IsActive = true
              AND Distribution_Channel__c = :distChannel
              AND Channel_Partner__c = null
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        if (catalogueBooks.isEmpty()) {
            ctx.error =
                'No Rotex catalogue Price Book found for Distribution Channel ' + distChannel;
            return ctx;
        }

        ctx.salesArea = salesArea;
        ctx.pricebookId = catalogueBooks[0].Id;
        ctx.priceBookName = catalogueBooks[0].Name;
        return ctx;
    }

    private static Sales_Area_Item__c findSalesArea1100(Id accountId) {
        if (accountId == null) {
            return null;
        }
        List<Sales_Area_Item__c> rows = [
            SELECT Id, Name, Sales_Org__c, Distribution_Channel__c, Division__c, Incoterms__c, CurrencyIsoCode
            FROM Sales_Area_Item__c
            WHERE Account__c = :accountId
              AND Sales_Org__c = '1100'
              AND Distribution_Channel__c != null
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static void assertQuoteAccessible(Id quoteId) {
        Id partnerId = resolvePartnerAccountId();
        if (partnerId == null) {
            throw new AuraHandledException('Channel Partner account could not be resolved.');
        }

        List<Quote> quotes = [
            SELECT Id
            FROM Quote
            WHERE Id = :quoteId
              AND (
                   AccountId = :partnerId
                OR QuoteAccountId = :partnerId
                OR Account__c = :partnerId
                OR OwnerId = :UserInfo.getUserId()
                OR Account.Channel_Partner_Name__c = :partnerId
                OR Account.Channel_Partner__c = :partnerId
                OR QuoteAccount.Channel_Partner_Name__c = :partnerId
                OR QuoteAccount.Channel_Partner__c = :partnerId
                OR Account__r.Channel_Partner_Name__c = :partnerId
                OR Account__r.Channel_Partner__c = :partnerId
                OR Contact.Account.Channel_Partner_Name__c = :partnerId
                OR Contact.Account.Channel_Partner__c = :partnerId
                OR Contact.AccountId = :partnerId
              )
            LIMIT 1
        ];
        if (quotes.isEmpty()) {
            throw new AuraHandledException('Unauthorised quote operation.');
        }
    }

    private static Id resolveQuoteCustomerAccountId(Quote qt) {
        if (qt.AccountId != null) {
            return qt.AccountId;
        }
        if (qt.QuoteAccountId != null) {
            return qt.QuoteAccountId;
        }
        return qt.Account__c;
    }

    private static void assertAccountAccessible(Id accountId) {
        Id partnerId = resolvePartnerAccountId();
        if (partnerId == null) {
            throw new AuraHandledException('Channel Partner account could not be resolved.');
        }
        if (accountId == partnerId) {
            return;
        }
        List<Account> accounts = [
            SELECT Id
            FROM Account
            WHERE Id = :accountId
              AND (
                   Channel_Partner_Name__c = :partnerId
                OR Channel_Partner__c = :partnerId
              )
            LIMIT 1
        ];
        if (accounts.isEmpty()) {
            throw new AuraHandledException('Unauthorised account operation.');
        }
    }
}