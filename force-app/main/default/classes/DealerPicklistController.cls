public without sharing class DealerPicklistController {

    public class LookupOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String label;
        @AuraEnabled public String subLabel;
        public LookupOption(Id id, String label, String subLabel) {
            this.id = id;
            this.label = label;
            this.subLabel = subLabel;
        }
    }

    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class ProductPage {
        @AuraEnabled public List<InventoryProductRow> products;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Integer pageNumber;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public Integer totalPages;
    }

    public class InventoryProductRow {
        @AuraEnabled public Id inventoryId;
        @AuraEnabled public Id productId;
        @AuraEnabled public String productName;
        @AuraEnabled public String productCode;
        @AuraEnabled public String itemType;
        @AuraEnabled public Decimal availableQty;
        @AuraEnabled public Decimal listPrice;
    }

    public class LineInput {
        @AuraEnabled public Id inventoryId { get; set; }
        @AuraEnabled public Id productId { get; set; }
        @AuraEnabled public Decimal pickQuantity { get; set; }
        @AuraEnabled public String remarks { get; set; }
    }

    public class CreateInput {
        @AuraEnabled public Id secondaryCustomerId { get; set; }
        @AuraEnabled public Id channelPartnerId { get; set; }
        @AuraEnabled public Date pickListDate { get; set; }
        @AuraEnabled public Date requestedDeliveryDate { get; set; }
        @AuraEnabled public String remarks { get; set; }
        @AuraEnabled public List<LineInput> lines { get; set; }
    }

    public class CreateResult {
        @AuraEnabled public Id picklistId;
        @AuraEnabled public String picklistNumber;
    }

    /* ===================== LIST / DETAIL ===================== */

    @AuraEnabled(cacheable=true)
    public static List<Picklist__c> getMyPicklists() {
        Id partnerId = resolvePartnerAccountId(null);
        if (partnerId == null) {
            Id userId = UserInfo.getUserId();
            return [
                SELECT Id, Name, Secondary_Customer__c, Secondary_Customer__r.Name,
                       Channel_Partner__c, Channel_Partner__r.Name,
                       Pick_List_Date__c, Requested_Delivery_Date__c, Remarks__c,
                       CreatedDate, OwnerId, Owner.Name, Owner.FirstName, Owner.LastName, Owner.Email
                FROM Picklist__c
                WHERE OwnerId = :userId
                ORDER BY CreatedDate DESC
                LIMIT 500
            ];
        }
        return [
            SELECT Id, Name, Secondary_Customer__c, Secondary_Customer__r.Name,
                   Channel_Partner__c, Channel_Partner__r.Name,
                   Pick_List_Date__c, Requested_Delivery_Date__c, Remarks__c,
                   CreatedDate, OwnerId, Owner.Name, Owner.FirstName, Owner.LastName, Owner.Email
            FROM Picklist__c
            WHERE Channel_Partner__c = :partnerId
               OR OwnerId = :UserInfo.getUserId()
            ORDER BY CreatedDate DESC
            LIMIT 500
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Picklist__c getPicklistById(Id picklistId) {
        if (picklistId == null) {
            throw new AuraHandledException('Picklist Id is required.');
        }
        assertPicklistAccess(picklistId);
        return [
            SELECT Id, Name, Secondary_Customer__c, Secondary_Customer__r.Name,
                   Channel_Partner__c, Channel_Partner__r.Name,
                   Pick_List_Date__c, Requested_Delivery_Date__c, Remarks__c,
                   CreatedDate, OwnerId, Owner.Name, Owner.FirstName, Owner.LastName, Owner.Email
            FROM Picklist__c
            WHERE Id = :picklistId
            LIMIT 1
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Pick_List_Line_Item__c> getPicklistLineItems(Id picklistId) {
        if (picklistId == null) {
            return new List<Pick_List_Line_Item__c>();
        }
        assertPicklistAccess(picklistId);
        return [
            SELECT Id, Name, Picklist__c,
                   Inventory__c, Inventory__r.Name, Inventory__r.Available_Quantity__c,
                   Product__c, Product__r.Name, Product_Code__c,
                   Pick_Quantity__c, Remarks__c, CreatedDate
            FROM Pick_List_Line_Item__c
            WHERE Picklist__c = :picklistId
            ORDER BY CreatedDate ASC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Id getMyChannelPartnerAccountId() {
        return resolvePartnerAccountId(null);
    }

    @AuraEnabled(cacheable=true)
    public static String getMyChannelPartnerAccountName() {
        Id partnerId = resolvePartnerAccountId(null);
        if (partnerId == null) {
            return '';
        }
        List<Account> accounts = [
            SELECT Name
            FROM Account
            WHERE Id = :partnerId
            LIMIT 1
        ];
        return accounts.isEmpty() ? '' : accounts[0].Name;
    }

    @AuraEnabled(cacheable=true)
    public static String getCurrentUserName() {
        User u = [
            SELECT FirstName, LastName, Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String firstLast = ((u.FirstName == null ? '' : u.FirstName.trim()) + ' ' +
            (u.LastName == null ? '' : u.LastName.trim())).trim();
        return String.isNotBlank(firstLast) ? firstLast : u.Name;
    }

    @AuraEnabled(cacheable=true)
    public static List<LookupOption> searchSecondaryCustomers(String searchText) {
        Id partnerId = resolvePartnerAccountId(null);
        if (partnerId == null) {
            return new List<LookupOption>();
        }
        String term = String.isBlank(searchText) ? '%' : '%' + String.escapeSingleQuotes(searchText.trim()) + '%';
        List<LookupOption> results = new List<LookupOption>();
        for (Account a : [
            SELECT Id, Name, BillingCity, BillingState
            FROM Account
            WHERE Channel_Partner_Name__c = :partnerId
              AND Name LIKE :term
            ORDER BY Name
            LIMIT 25
        ]) {
            List<String> parts = new List<String>();
            if (String.isNotBlank(a.BillingCity)) {
                parts.add(a.BillingCity);
            }
            if (String.isNotBlank(a.BillingState)) {
                parts.add(a.BillingState);
            }
            results.add(new LookupOption(
                a.Id,
                a.Name,
                parts.isEmpty() ? '' : String.join(parts, ', ')
            ));
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getItemTypeOptions() {
        List<PicklistOption> options = new List<PicklistOption>();
        options.add(new PicklistOption('All', ''));
        try {
            Schema.DescribeFieldResult dfr = Product2.Item_Type__c.getDescribe();
            for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
                if (pe.isActive()) {
                    options.add(new PicklistOption(pe.getLabel(), pe.getValue()));
                }
            }
        } catch (Exception e) {
            // Item_Type__c may not exist in all orgs
        }
        return options;
    }

    /* ===================== AVAILABLE INVENTORY PRODUCTS ===================== */

    @AuraEnabled
    public static ProductPage getAvailableInventoryProducts(
        String itemType,
        String searchKey,
        Integer pageNumber,
        Integer pageSize
    ) {
        if (pageNumber == null || pageNumber < 1) {
            pageNumber = 1;
        }
        if (pageSize == null || pageSize < 1) {
            pageSize = 10;
        }
        if (pageSize > 50) {
            pageSize = 50;
        }

        Id partnerId = resolvePartnerAccountId(null);
        Id userId = UserInfo.getUserId();

        String soql =
            'SELECT Id, Product__c, Product__r.Name, Product_Code__c, Available_Quantity__c, ' +
            'Product__r.Item_Type__c ' +
            'FROM Inventory__c ' +
            'WHERE Available_Quantity__c > 0 ';

        if (partnerId != null) {
            soql += 'AND Channel_Partner__c = :partnerId ';
        } else {
            soql += 'AND OwnerId = :userId ';
        }

        String itemTypeFilter = String.isBlank(itemType) ? null : itemType.trim();
        if (itemTypeFilter != null) {
            soql += 'AND Product__r.Item_Type__c = :itemTypeFilter ';
        }

        String searchLike = null;
        if (String.isNotBlank(searchKey)) {
            searchLike = '%' + searchKey.trim() + '%';
            soql += 'AND (Product__r.Name LIKE :searchLike OR Product_Code__c LIKE :searchLike) ';
        }

        // Count
        String countSoql = soql.replace(
            'SELECT Id, Product__c, Product__r.Name, Product_Code__c, Available_Quantity__c, ' +
            'Product__r.Item_Type__c ',
            'SELECT COUNT() '
        );
        Integer totalCount = Database.countQuery(countSoql);

        Integer offsetVal = (pageNumber - 1) * pageSize;
        soql += 'ORDER BY Product__r.Name NULLS LAST LIMIT :pageSize OFFSET :offsetVal';

        List<Inventory__c> rows = Database.query(soql);
        List<InventoryProductRow> products = new List<InventoryProductRow>();
        for (Inventory__c inv : rows) {
            InventoryProductRow r = new InventoryProductRow();
            r.inventoryId = inv.Id;
            r.productId = inv.Product__c;
            r.productName = inv.Product__r != null ? inv.Product__r.Name : '';
            r.productCode = inv.Product_Code__c;
            r.itemType = inv.Product__r != null ? (String) inv.Product__r.get('Item_Type__c') : null;
            r.availableQty = inv.Available_Quantity__c;
            r.listPrice = null;
            products.add(r);
        }

        ProductPage page = new ProductPage();
        page.products = products;
        page.totalCount = totalCount;
        page.pageNumber = pageNumber;
        page.pageSize = pageSize;
        page.totalPages = totalCount == 0 ? 1 : (Integer) Math.ceil(Decimal.valueOf(totalCount) / pageSize);
        return page;
    }

    /* ===================== CREATE ===================== */

    @AuraEnabled
    public static CreateResult createPicklist(CreateInput input) {
        if (input == null) {
            throw new AuraHandledException('Picklist details are required.');
        }
        if (input.lines == null || input.lines.isEmpty()) {
            throw new AuraHandledException('Add at least one product to the picklist.');
        }

        Id partnerId = resolvePartnerAccountId(input.channelPartnerId);
        if (partnerId == null) {
            throw new AuraHandledException('Channel Partner account could not be resolved.');
        }

        if (input.secondaryCustomerId != null) {
            assertCustomerBelongsToPartner(input.secondaryCustomerId, partnerId);
        }

        // Validate inventory + quantities
        Set<Id> inventoryIds = new Set<Id>();
        for (LineInput line : input.lines) {
            if (line == null || line.inventoryId == null) {
                throw new AuraHandledException('Each line must reference inventory.');
            }
            if (line.pickQuantity == null || line.pickQuantity <= 0) {
                throw new AuraHandledException('PickList Qty must be greater than zero.');
            }
            inventoryIds.add(line.inventoryId);
        }

        Map<Id, Inventory__c> invMap = new Map<Id, Inventory__c>([
            SELECT Id, Product__c, Product_Code__c, Available_Quantity__c, Channel_Partner__c, OwnerId
            FROM Inventory__c
            WHERE Id IN :inventoryIds
        ]);

        for (LineInput line : input.lines) {
            Inventory__c inv = invMap.get(line.inventoryId);
            if (inv == null) {
                throw new AuraHandledException('Inventory record not found.');
            }
            if (partnerId != null && inv.Channel_Partner__c != partnerId && inv.OwnerId != UserInfo.getUserId()) {
                throw new AuraHandledException('You do not have access to one of the selected inventory products.');
            }
            Decimal available = inv.Available_Quantity__c == null ? 0 : inv.Available_Quantity__c;
            if (line.pickQuantity > available) {
                throw new AuraHandledException(
                    'PickList Qty cannot exceed Available Qty for product ' +
                    (String.isBlank(inv.Product_Code__c) ? String.valueOf(inv.Id) : inv.Product_Code__c) + '.'
                );
            }
        }

        Picklist__c header = new Picklist__c();
        header.Channel_Partner__c = partnerId;
        header.Secondary_Customer__c = input.secondaryCustomerId;
        header.Pick_List_Date__c = input.pickListDate != null ? input.pickListDate : Date.today();
        header.Requested_Delivery_Date__c = input.requestedDeliveryDate;
        header.Remarks__c = blankToNull(input.remarks);
        header.OwnerId = UserInfo.getUserId();

        try {
            insert header;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }

        List<Pick_List_Line_Item__c> lines = new List<Pick_List_Line_Item__c>();
        for (LineInput line : input.lines) {
            Inventory__c inv = invMap.get(line.inventoryId);
            Pick_List_Line_Item__c li = new Pick_List_Line_Item__c();
            li.Picklist__c = header.Id;
            li.Inventory__c = inv.Id;
            li.Product__c = inv.Product__c != null ? inv.Product__c : line.productId;
            li.Pick_Quantity__c = line.pickQuantity;
            li.Remarks__c = blankToNull(line.remarks);
            lines.add(li);
        }

        try {
            insert lines;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }

        Picklist__c saved = [
            SELECT Id, Name
            FROM Picklist__c
            WHERE Id = :header.Id
            LIMIT 1
        ];

        CreateResult result = new CreateResult();
        result.picklistId = saved.Id;
        result.picklistNumber = saved.Name;
        return result;
    }

    /* ===================== HELPERS ===================== */

    private static void assertPicklistAccess(Id picklistId) {
        Id partnerId = resolvePartnerAccountId(null);
        List<Picklist__c> rows;
        if (partnerId != null) {
            rows = [
                SELECT Id
                FROM Picklist__c
                WHERE Id = :picklistId
                  AND (Channel_Partner__c = :partnerId OR OwnerId = :UserInfo.getUserId())
                LIMIT 1
            ];
        } else {
            rows = [
                SELECT Id
                FROM Picklist__c
                WHERE Id = :picklistId
                  AND OwnerId = :UserInfo.getUserId()
                LIMIT 1
            ];
        }
        if (rows.isEmpty()) {
            throw new AuraHandledException('You do not have access to this picklist.');
        }
    }

    private static void assertCustomerBelongsToPartner(Id accountId, Id partnerId) {
        if (accountId == null || partnerId == null) {
            return;
        }
        List<Account> accounts = [
            SELECT Id
            FROM Account
            WHERE Id = :accountId
              AND Channel_Partner_Name__c = :partnerId
            LIMIT 1
        ];
        if (accounts.isEmpty()) {
            throw new AuraHandledException(
                'Selected Secondary Customer is not associated with your Channel Partner account.'
            );
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

    private static String blankToNull(String value) {
        return String.isBlank(value) ? null : value.trim();
    }
}