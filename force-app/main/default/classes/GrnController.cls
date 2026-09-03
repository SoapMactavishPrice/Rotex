public without sharing class GrnController {

    /**
     * Feature_Setting__mdt.Default.Show_Create_GRN__c —
     * when true: Invoice detail shows Create GRN button.
     */
    @AuraEnabled(cacheable=true)
    public static Boolean getShowCreateGrnFlag() {
        Feature_Setting__mdt setting = Feature_Setting__mdt.getInstance('Default');
        return setting != null && setting.Show_Create_GRN__c == true;
    }

    public class InvoiceLineForGrn {

        @AuraEnabled public Id invoiceLineItemId;
        @AuraEnabled public Id productId;
        @AuraEnabled public String productName;
        @AuraEnabled public String productCode;
        @AuraEnabled public Decimal orderQty;
        @AuraEnabled public Decimal orderedQty;
        @AuraEnabled public Decimal grnQty;
        @AuraEnabled public Decimal pendingGrnQty;
        @AuraEnabled public Decimal alreadyReceivedQty;
        @AuraEnabled public Decimal remainingQty;
    }

    public class FileInput {
        @AuraEnabled public String fileName { get; set; }
        @AuraEnabled public String base64Data { get; set; }
    }

    public class GrnLineInput {
        @AuraEnabled public Id invoiceLineItemId { get; set; }
        @AuraEnabled public Id productId { get; set; }
        @AuraEnabled public Decimal orderedQty { get; set; }
        @AuraEnabled public Decimal receivedQty { get; set; }
        @AuraEnabled public Decimal damageQty { get; set; }
        @AuraEnabled public Decimal shortQty { get; set; }
        @AuraEnabled public String rejectionReason { get; set; }
        @AuraEnabled public String remarks { get; set; }
        @AuraEnabled public List<FileInput> attachments { get; set; }
    }

    public class GrnCreateInput {
        @AuraEnabled public Id invoiceId { get; set; }
        @AuraEnabled public String grnDate { get; set; }
        @AuraEnabled public Id receivedByContactId { get; set; }
        @AuraEnabled public String remarks { get; set; }
        @AuraEnabled public List<GrnLineInput> lines { get; set; }
    }

    public class CurrentUserInfo {
        @AuraEnabled public Id userId;
        @AuraEnabled public String userName;
        @AuraEnabled public Id partnerAccountId;
        @AuraEnabled public String partnerAccountName;
        @AuraEnabled public Id contactId;
    }

    public class PartnerContactOption {
        @AuraEnabled public Id contactId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
    }

    @AuraEnabled(cacheable=true)
    public static CurrentUserInfo getCurrentUserInfo() {
        CurrentUserInfo info = new CurrentUserInfo();
        info.userId = UserInfo.getUserId();
        info.userName = UserInfo.getName();
        info.partnerAccountId = resolvePartnerAccountId();
        List<User> me = [
            SELECT ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (!me.isEmpty()) {
            info.contactId = me[0].ContactId;
        }
        if (info.partnerAccountId != null) {
            List<Account> partners = [
                SELECT Name
                FROM Account
                WHERE Id = :info.partnerAccountId
                LIMIT 1
            ];
            if (!partners.isEmpty()) {
                info.partnerAccountName = partners[0].Name;
            }
        }
        return info;
    }

    @AuraEnabled(cacheable=true)
    public static List<PartnerContactOption> getPartnerContacts() {
        Id partnerId = resolvePartnerAccountId();
        if (partnerId == null) {
            return new List<PartnerContactOption>();
        }

        List<PartnerContactOption> options = new List<PartnerContactOption>();
        for (Contact c : [
            SELECT Id, Name, Email
            FROM Contact
            WHERE AccountId = :partnerId
            ORDER BY Name
            LIMIT 500
        ]) {
            PartnerContactOption opt = new PartnerContactOption();
            opt.contactId = c.Id;
            opt.name = c.Name;
            opt.email = c.Email;
            options.add(opt);
        }
        return options;
    }

    @AuraEnabled
    public static List<InvoiceLineForGrn> getInvoiceLinesForGrn(Id invoiceId) {
        assertInvoiceAccessible(invoiceId);

        List<SO_Invoice__c> invoices = [
            SELECT Id, Name, Order__c, SO_No__c
            FROM SO_Invoice__c
            WHERE Id = :invoiceId
            LIMIT 1
        ];

        Id orderId = resolveOrderId(invoices.isEmpty() ? null : invoices[0]);
        Map<Id, Decimal> orderQtyByProductId = new Map<Id, Decimal>();
        Map<String, Decimal> orderQtyByProductCode = new Map<String, Decimal>();

        if (orderId != null) {
            for (OrderItem oi : [
                SELECT Product2Id, Quantity, Product2.ProductCode
                FROM OrderItem
                WHERE OrderId = :orderId
            ]) {
                Decimal qty = oi.Quantity != null ? oi.Quantity : 0;
                if (oi.Product2Id != null) {
                    Decimal existing = orderQtyByProductId.containsKey(oi.Product2Id)
                        ? orderQtyByProductId.get(oi.Product2Id)
                        : 0;
                    orderQtyByProductId.put(oi.Product2Id, existing + qty);
                }
                if (oi.Product2 != null && String.isNotBlank(oi.Product2.ProductCode)) {
                    String code = oi.Product2.ProductCode.trim().toLowerCase();
                    Decimal existingCode = orderQtyByProductCode.containsKey(code)
                        ? orderQtyByProductCode.get(code)
                        : 0;
                    orderQtyByProductCode.put(code, existingCode + qty);
                }
            }
        }

        List<Invoice_Line_item__c> invoiceLines = [
            SELECT Id, Name, Product__c, Product__r.Name, Product__r.ProductCode,
                   Quantity__c, QTY__c, Item_Code__c, GRN_Qty__c, Pending_GRN_Qty__c
            FROM Invoice_Line_item__c
            WHERE SO_Invoice__c = :invoiceId
            ORDER BY Item_No__c NULLS LAST, Name
        ];

        List<InvoiceLineForGrn> rows = new List<InvoiceLineForGrn>();
        for (Invoice_Line_item__c li : invoiceLines) {
            InvoiceLineForGrn row = new InvoiceLineForGrn();
            row.invoiceLineItemId = li.Id;
            row.productId = li.Product__c;
            row.productName = li.Product__r != null ? li.Product__r.Name : li.Name;
            row.productCode = li.Product__r != null && String.isNotBlank(li.Product__r.ProductCode)
                ? li.Product__r.ProductCode
                : li.Item_Code__c;

            // ORDER QTY = Order line Quantity matched via Rotex Order Number (Order.SO_No__c)
            Decimal fromOrder = null;
            if (li.Product__c != null && orderQtyByProductId.containsKey(li.Product__c)) {
                fromOrder = orderQtyByProductId.get(li.Product__c);
            } else {
                String codeKey = String.isNotBlank(row.productCode)
                    ? row.productCode.trim().toLowerCase()
                    : null;
                if (codeKey != null && orderQtyByProductCode.containsKey(codeKey)) {
                    fromOrder = orderQtyByProductCode.get(codeKey);
                }
            }
            row.orderQty = fromOrder != null ? fromOrder : 0;

            // Invoice billed qty (for GRN pending calc)
            Decimal ordered = li.QTY__c != null ? li.QTY__c : li.Quantity__c;
            row.orderedQty = ordered != null ? ordered : 0;
            row.grnQty = li.GRN_Qty__c != null ? li.GRN_Qty__c : 0;
            Decimal pending = li.Pending_GRN_Qty__c;
            if (pending == null) {
                pending = row.orderedQty - row.grnQty;
            }
            row.pendingGrnQty = pending > 0 ? pending : 0;
            row.alreadyReceivedQty = row.grnQty;
            row.remainingQty = row.pendingGrnQty;
            rows.add(row);
        }
        return rows;
    }

    /**
     * Find Order for invoice: Order lookup first, else Rotex Order Number
     * (Invoice SO_No__c / Name → Order.SO_No__c).
     */
    private static Id resolveOrderId(SO_Invoice__c inv) {
        if (inv == null) {
            return null;
        }
        if (inv.Order__c != null) {
            return inv.Order__c;
        }

        Set<String> rotexNumbers = new Set<String>();
        if (String.isNotBlank(inv.SO_No__c)) {
            rotexNumbers.add(inv.SO_No__c.trim());
        }
        if (String.isNotBlank(inv.Name)) {
            rotexNumbers.add(inv.Name.trim());
        }
        if (rotexNumbers.isEmpty()) {
            return null;
        }

        List<Order> matchedOrders = [
            SELECT Id
            FROM Order
            WHERE SO_No__c IN :rotexNumbers
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return matchedOrders.isEmpty() ? null : matchedOrders[0].Id;
    }

    public class FileWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public Id versionId;
        @AuraEnabled public String title;
        @AuraEnabled public String fileType;
        @AuraEnabled public String size;
        @AuraEnabled public String uploadedDate;
    }

    @AuraEnabled
    public static List<GRN__c> getGrnsForInvoice(Id invoiceId) {
        assertInvoiceAccessible(invoiceId);
        // Only return GRNs created via Create GRN (must have a GRN Date)
        return [
            SELECT Id, Name, GRN_Date__c, Status__c, Remarks__c,
                   Channel_Partner__c, Channel_Partner__r.Name,
                   Received_By__c, Received_By__r.Name,
                   CreatedDate
            FROM GRN__c
            WHERE Invoice__c = :invoiceId
              AND GRN_Date__c != null
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled
    public static List<GRN_Line_Item__c> getGrnLineItemsForInvoice(Id invoiceId) {
        assertInvoiceAccessible(invoiceId);
        return [
            SELECT Id, Name, Status__c, Ordered_Qty__c, Received_Qty__c, Pending_Qty__c,
                   Damage_Qty__c, Short_Qty__c, Accepted_Qty__c, Rejection_Reason__c, Remarks__c,
                   Product__c, Product__r.Name, Product__r.ProductCode,
                   Invoice_Line_Item__c, Invoice_Line_Item__r.Name,
                   GRN__c, GRN__r.Name, GRN__r.GRN_Date__c,
                   CreatedDate
            FROM GRN_Line_Item__c
            WHERE GRN__r.Invoice__c = :invoiceId
              AND GRN__r.GRN_Date__c != null
            ORDER BY CreatedDate DESC, Name
        ];
    }

    @AuraEnabled
    public static GRN__c getGrnDetail(Id grnId) {
        if (grnId == null) {
            throw new AuraHandledException('GRN Id is required.');
        }
        List<GRN__c> rows = [
            SELECT Id, Name, GRN_Date__c, Status__c, Remarks__c, Invoice__c,
                   Channel_Partner__c, Channel_Partner__r.Name,
                   Received_By__c, Received_By__r.Name,
                   CreatedDate
            FROM GRN__c
            WHERE Id = :grnId
              AND GRN_Date__c != null
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw new AuraHandledException('GRN not found.');
        }
        assertInvoiceAccessible(rows[0].Invoice__c);
        return rows[0];
    }

    @AuraEnabled
    public static GRN_Line_Item__c getGrnLineItemDetail(Id lineItemId) {
        if (lineItemId == null) {
            throw new AuraHandledException('GRN Line Item Id is required.');
        }
        List<GRN_Line_Item__c> rows = [
            SELECT Id, Name, Status__c, Ordered_Qty__c, Received_Qty__c, Pending_Qty__c,
                   Damage_Qty__c, Short_Qty__c, Accepted_Qty__c, Rejection_Reason__c, Remarks__c,
                   Product__c, Product__r.Name, Product__r.ProductCode,
                   Invoice_Line_Item__c, Invoice_Line_Item__r.Name,
                   GRN__c, GRN__r.Name, GRN__r.GRN_Date__c, GRN__r.Invoice__c,
                   CreatedDate
            FROM GRN_Line_Item__c
            WHERE Id = :lineItemId
              AND GRN__r.GRN_Date__c != null
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw new AuraHandledException('GRN Line Item not found.');
        }
        assertInvoiceAccessible(rows[0].GRN__r.Invoice__c);
        return rows[0];
    }

    @AuraEnabled
    public static List<FileWrapper> getGrnLineItemFiles(Id lineItemId) {
        getGrnLineItemDetail(lineItemId);
        List<FileWrapper> results = new List<FileWrapper>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId,
                   ContentDocument.Title,
                   ContentDocument.FileType,
                   ContentDocument.ContentSize,
                   ContentDocument.CreatedDate,
                   ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :lineItemId
            ORDER BY ContentDocument.CreatedDate DESC
        ]) {
            FileWrapper w = new FileWrapper();
            w.id = cdl.ContentDocumentId;
            w.versionId = cdl.ContentDocument.LatestPublishedVersionId;
            w.title = cdl.ContentDocument.Title;
            w.fileType = cdl.ContentDocument.FileType;
            w.size = formatFileSize(cdl.ContentDocument.ContentSize);
            w.uploadedDate = cdl.ContentDocument.CreatedDate.format('dd MMM yyyy');
            results.add(w);
        }
        return results;
    }

    private static String formatFileSize(Integer bytes) {
        if (bytes == null) {
            return '';
        }
        if (bytes < 1024) {
            return bytes + ' B';
        }
        if (bytes < 1024 * 1024) {
            return (bytes / 1024) + ' KB';
        }
        return String.valueOf((bytes / (1024 * 1024.0)).setScale(1)) + ' MB';
    }

    @AuraEnabled
    public static GRN__c createGrn(GrnCreateInput input) {
        if (input == null || input.invoiceId == null) {
            throw new AuraHandledException('Invoice is required.');
        }
        assertInvoiceAccessible(input.invoiceId);

        if (String.isBlank(input.grnDate)) {
            throw new AuraHandledException('GRN Date is required.');
        }
        if (input.receivedByContactId == null) {
            throw new AuraHandledException('Received By is required.');
        }
        if (String.isBlank(input.remarks)) {
            throw new AuraHandledException('Remarks is required.');
        }
        Date grnDateVal;
        try {
            grnDateVal = Date.valueOf(input.grnDate.trim());
        } catch (Exception e) {
            throw new AuraHandledException('GRN Date is invalid.');
        }

        if (input.lines == null || input.lines.isEmpty()) {
            throw new AuraHandledException('Add at least one GRN line item.');
        }

        Id partnerId = resolvePartnerAccountId();
        Id receivedByUserId = resolveReceivedByUserId(input.receivedByContactId, partnerId);

        List<GrnLineInput> validLines = new List<GrnLineInput>();
        for (GrnLineInput line : input.lines) {
            if (line == null) {
                continue;
            }
            Decimal received = line.receivedQty != null ? line.receivedQty : 0;
            Decimal damage = line.damageQty != null ? line.damageQty : 0;
            Decimal shortQty = line.shortQty != null ? line.shortQty : 0;
            if (received <= 0 && damage <= 0 && shortQty <= 0) {
                continue;
            }
            if (received <= 0) {
                throw new AuraHandledException('Received Qty is required for each product being received.');
            }
            if (received < 0 || damage < 0 || shortQty < 0) {
                throw new AuraHandledException('Quantities cannot be negative.');
            }
            if (damage > 0 && String.isBlank(line.rejectionReason)) {
                throw new AuraHandledException('Rejection Reason is required when Damage Qty is entered.');
            }
            if (line.invoiceLineItemId == null) {
                throw new AuraHandledException('Invoice Line Item is required on each GRN line.');
            }
            validLines.add(line);
        }
        if (validLines.isEmpty()) {
            throw new AuraHandledException('Enter Received Qty for at least one product.');
        }

        Set<Id> invoiceLineIds = new Set<Id>();
        for (GrnLineInput line : validLines) {
            invoiceLineIds.add(line.invoiceLineItemId);
        }
        Map<Id, Invoice_Line_item__c> invoiceLinesById = new Map<Id, Invoice_Line_item__c>([
            SELECT Id, QTY__c, Quantity__c, GRN_Qty__c, Pending_GRN_Qty__c
            FROM Invoice_Line_item__c
            WHERE Id IN :invoiceLineIds
            FOR UPDATE
        ]);

        for (GrnLineInput line : validLines) {
            Invoice_Line_item__c invLine = invoiceLinesById.get(line.invoiceLineItemId);
            if (invLine == null) {
                throw new AuraHandledException('Invoice Line Item not found for one of the GRN lines.');
            }
            Decimal ordered = invLine.QTY__c != null ? invLine.QTY__c : invLine.Quantity__c;
            if (ordered == null) {
                ordered = 0;
            }
            Decimal currentGrnQty = invLine.GRN_Qty__c != null ? invLine.GRN_Qty__c : 0;
            Decimal pending = invLine.Pending_GRN_Qty__c;
            if (pending == null) {
                pending = ordered - currentGrnQty;
            }
            if (pending < 0) {
                pending = 0;
            }
            Decimal received = line.receivedQty != null ? line.receivedQty : 0;
            Decimal damage = line.damageQty != null ? line.damageQty : 0;
            Decimal shortQty = line.shortQty != null ? line.shortQty : 0;
            if (received > pending) {
                throw new AuraHandledException(
                    'Received Qty cannot exceed Pending GRN Qty (' + String.valueOf(pending) + ').'
                );
            }
            if (damage > pending) {
                throw new AuraHandledException(
                    'Damage Qty cannot exceed Pending GRN Qty (' + String.valueOf(pending) + ').'
                );
            }
            if (shortQty > pending) {
                throw new AuraHandledException(
                    'Short Qty cannot exceed Pending GRN Qty (' + String.valueOf(pending) + ').'
                );
            }
            // Persist full ordered qty on the GRN line; pending drives the receive cap.
            line.orderedQty = ordered;
        }

        Boolean allComplete = true;
        for (GrnLineInput line : validLines) {
            Invoice_Line_item__c invLine = invoiceLinesById.get(line.invoiceLineItemId);
            Decimal ordered = invLine.QTY__c != null ? invLine.QTY__c : invLine.Quantity__c;
            if (ordered == null) {
                ordered = 0;
            }
            Decimal currentGrnQty = invLine.GRN_Qty__c != null ? invLine.GRN_Qty__c : 0;
            Decimal pending = invLine.Pending_GRN_Qty__c;
            if (pending == null) {
                pending = ordered - currentGrnQty;
            }
            Decimal received = line.receivedQty != null ? line.receivedQty : 0;
            if (received < pending) {
                allComplete = false;
                break;
            }
        }

        Savepoint sp = Database.setSavepoint();
        try {
            GRN__c grn = new GRN__c();
            grn.Invoice__c = input.invoiceId;
            grn.GRN_Date__c = grnDateVal;
            grn.Channel_Partner__c = partnerId;
            grn.Received_By__c = receivedByUserId;
            grn.Remarks__c = String.isBlank(input.remarks) ? null : input.remarks.trim();
            grn.Status__c = allComplete ? 'Complete' : 'Partial';
            insert grn;

            List<GRN_Line_Item__c> lineItems = new List<GRN_Line_Item__c>();
            Map<Id, Decimal> grnQtyToAddByInvoiceLine = new Map<Id, Decimal>();
            for (GrnLineInput line : validLines) {
                Decimal ordered = line.orderedQty != null ? line.orderedQty : 0;
                Decimal received = line.receivedQty != null ? line.receivedQty : 0;
                Decimal damage = line.damageQty != null ? line.damageQty : 0;
                Decimal shortQty = line.shortQty != null ? line.shortQty : 0;

                Invoice_Line_item__c invLine = invoiceLinesById.get(line.invoiceLineItemId);
                Decimal currentGrnQty = invLine.GRN_Qty__c != null ? invLine.GRN_Qty__c : 0;
                Decimal pending = invLine.Pending_GRN_Qty__c;
                if (pending == null) {
                    pending = ordered - currentGrnQty;
                }

                GRN_Line_Item__c gli = new GRN_Line_Item__c();
                gli.GRN__c = grn.Id;
                gli.Invoice_Line_Item__c = line.invoiceLineItemId;
                gli.Product__c = line.productId;
                gli.Ordered_Qty__c = ordered;
                gli.Received_Qty__c = received;
                gli.Damage_Qty__c = damage;
                gli.Short_Qty__c = shortQty;
                gli.Rejection_Reason__c = String.isBlank(line.rejectionReason)
                    ? null
                    : line.rejectionReason.trim();
                gli.Remarks__c = String.isBlank(line.remarks) ? null : line.remarks.trim();
                gli.Status__c = received >= pending && pending > 0 ? 'Complete' : 'Partial';
                if (pending == 0 && received > 0) {
                    gli.Status__c = 'Complete';
                }
                lineItems.add(gli);

                Decimal addQty = grnQtyToAddByInvoiceLine.containsKey(line.invoiceLineItemId)
                    ? grnQtyToAddByInvoiceLine.get(line.invoiceLineItemId)
                    : 0;
                grnQtyToAddByInvoiceLine.put(line.invoiceLineItemId, addQty + received);
            }
            insert lineItems;

            List<Invoice_Line_item__c> invoiceLinesToUpdate = new List<Invoice_Line_item__c>();
            for (Id invLineId : grnQtyToAddByInvoiceLine.keySet()) {
                Invoice_Line_item__c invLine = invoiceLinesById.get(invLineId);
                Decimal currentGrnQty = invLine.GRN_Qty__c != null ? invLine.GRN_Qty__c : 0;
                invLine.GRN_Qty__c = currentGrnQty + grnQtyToAddByInvoiceLine.get(invLineId);
                invoiceLinesToUpdate.add(invLine);
            }
            if (!invoiceLinesToUpdate.isEmpty()) {
                update invoiceLinesToUpdate;
            }

            applyInventoryFromGrn(partnerId, grnDateVal, lineItems);

            List<ContentVersion> versions = new List<ContentVersion>();
            List<Id> versionLineIndexes = new List<Id>();
            for (Integer i = 0; i < validLines.size(); i++) {
                GrnLineInput line = validLines[i];
                if (line.attachments == null || line.attachments.isEmpty()) {
                    continue;
                }
                for (FileInput file : line.attachments) {
                    if (file == null || String.isBlank(file.fileName) || String.isBlank(file.base64Data)) {
                        continue;
                    }
                    versions.add(new ContentVersion(
                        Title = file.fileName,
                        PathOnClient = file.fileName,
                        VersionData = EncodingUtil.base64Decode(file.base64Data),
                        IsMajorVersion = true
                    ));
                    versionLineIndexes.add(lineItems[i].Id);
                }
            }
            if (!versions.isEmpty()) {
                insert versions;
                Set<Id> versionIds = new Map<Id, ContentVersion>(versions).keySet();
                Map<Id, ContentVersion> insertedById = new Map<Id, ContentVersion>([
                    SELECT Id, ContentDocumentId
                    FROM ContentVersion
                    WHERE Id IN :versionIds
                ]);
                List<ContentDocumentLink> links = new List<ContentDocumentLink>();
                for (Integer i = 0; i < versions.size(); i++) {
                    ContentVersion cv = insertedById.get(versions[i].Id);
                    if (cv == null || cv.ContentDocumentId == null) {
                        continue;
                    }
                    links.add(new ContentDocumentLink(
                        ContentDocumentId = cv.ContentDocumentId,
                        LinkedEntityId = versionLineIndexes[i],
                        ShareType = 'V',
                        Visibility = 'AllUsers'
                    ));
                }
                if (!links.isEmpty()) {
                    insert links;
                }
            }

            return [
                SELECT Id, Name, GRN_Date__c, Status__c, Remarks__c,
                       Channel_Partner__c, Channel_Partner__r.Name,
                       Received_By__c, Received_By__r.Name
                FROM GRN__c
                WHERE Id = :grn.Id
                LIMIT 1
            ];
        } catch (DmlException e) {
            Database.rollback(sp);
            AuraHandledException ex = new AuraHandledException(e.getDmlMessage(0));
            ex.setMessage(e.getDmlMessage(0));
            throw ex;
        } catch (AuraHandledException e) {
            Database.rollback(sp);
            throw e;
        } catch (Exception e) {
            Database.rollback(sp);
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    /**
     * One Inventory__c per Channel Partner + Product.
     * Each GRN line creates an Inventory_Transaction__c (Type = GRN).
     * Quantity rollups (Total GRN / On Hand / Available) update from transactions.
     */
    private static void applyInventoryFromGrn(
        Id partnerId,
        Date grnDate,
        List<GRN_Line_Item__c> lineItems
    ) {
        if (partnerId == null || lineItems == null || lineItems.isEmpty()) {
            return;
        }

        Set<Id> productIds = new Set<Id>();
        for (GRN_Line_Item__c li : lineItems) {
            if (li.Product__c != null) {
                productIds.add(li.Product__c);
            }
        }
        if (productIds.isEmpty()) {
            return;
        }

        Map<Id, Inventory__c> inventoryByProduct = new Map<Id, Inventory__c>();
        for (Inventory__c inv : [
            SELECT Id, Product__c, Channel_Partner__c, Last_GRN_Date__c, Status__c
            FROM Inventory__c
            WHERE Channel_Partner__c = :partnerId
              AND Product__c IN :productIds
        ]) {
            inventoryByProduct.put(inv.Product__c, inv);
        }

        List<Inventory__c> inventoriesToInsert = new List<Inventory__c>();
        for (Id productId : productIds) {
            if (inventoryByProduct.containsKey(productId)) {
                continue;
            }
            Inventory__c inv = new Inventory__c();
            inv.Channel_Partner__c = partnerId;
            inv.Product__c = productId;
            inv.Last_GRN_Date__c = grnDate;
            inv.Status__c = 'Available';
            inventoriesToInsert.add(inv);
            inventoryByProduct.put(productId, inv);
        }
        if (!inventoriesToInsert.isEmpty()) {
            insert inventoriesToInsert;
        }

        List<Inventory__c> inventoriesToUpdate = new List<Inventory__c>();
        Set<Id> updatedIds = new Set<Id>();
        for (Inventory__c inv : inventoryByProduct.values()) {
            if (inv.Id == null) {
                continue;
            }
            Boolean changed = false;
            if (grnDate != null && (inv.Last_GRN_Date__c == null || inv.Last_GRN_Date__c < grnDate)) {
                inv.Last_GRN_Date__c = grnDate;
                changed = true;
            }
            if (String.isBlank(inv.Status__c)) {
                inv.Status__c = 'Available';
                changed = true;
            }
            if (changed && !updatedIds.contains(inv.Id)) {
                inventoriesToUpdate.add(inv);
                updatedIds.add(inv.Id);
            }
        }
        if (!inventoriesToUpdate.isEmpty()) {
            update inventoriesToUpdate;
        }

        Datetime txnWhen = Datetime.now();
        List<Inventory_Transaction__c> transactions = new List<Inventory_Transaction__c>();
        for (GRN_Line_Item__c li : lineItems) {
            if (li.Product__c == null || !inventoryByProduct.containsKey(li.Product__c)) {
                continue;
            }
            Decimal received = li.Received_Qty__c != null ? li.Received_Qty__c : 0;
            Decimal damage = li.Damage_Qty__c != null ? li.Damage_Qty__c : 0;
            Decimal acceptedQty = received - damage;
            if (acceptedQty <= 0) {
                continue;
            }
            Inventory__c inv = inventoryByProduct.get(li.Product__c);
            if (inv.Id == null) {
                continue;
            }
            Inventory_Transaction__c txn = new Inventory_Transaction__c();
            txn.Inventory__c = inv.Id;
            txn.Transaction_Type__c = 'GRN';
            txn.Transaction_Date_Time__c = txnWhen;
            txn.GRN_Line_Item__c = li.Id;
            txn.Quantity__c = acceptedQty;
            txn.Remarks__c = li.Remarks__c;
            transactions.add(txn);
        }
        if (!transactions.isEmpty()) {
            insert transactions;
        }
    }

    private static Id resolveReceivedByUserId(Id contactId, Id partnerId) {
        if (contactId == null) {
            return null;
        }
        if (partnerId != null) {
            List<Contact> contacts = [
                SELECT Id
                FROM Contact
                WHERE Id = :contactId
                  AND AccountId = :partnerId
                LIMIT 1
            ];
            if (contacts.isEmpty()) {
                throw new AuraHandledException('Selected contact is not under your Channel Partner account.');
            }
        }
        List<User> users = [
            SELECT Id
            FROM User
            WHERE ContactId = :contactId
              AND IsActive = true
            LIMIT 1
        ];
        if (!users.isEmpty()) {
            return users[0].Id;
        }
        // Received_By__c is Lookup(User); fall back to current user when contact has no portal login
        return UserInfo.getUserId();
    }

    private static void assertInvoiceAccessible(Id invoiceId) {
        if (invoiceId == null) {
            throw new AuraHandledException('Invoice Id is required.');
        }
        Id partnerId = resolvePartnerAccountId();
        List<SO_Invoice__c> invoices;
        if (partnerId == null) {
            invoices = [
                SELECT Id
                FROM SO_Invoice__c
                WHERE Id = :invoiceId
                  AND CreatedById = :UserInfo.getUserId()
                LIMIT 1
            ];
        } else {
            invoices = [
                SELECT Id
                FROM SO_Invoice__c
                WHERE Id = :invoiceId
                  AND (
                       Account__c = :partnerId
                    OR Account__r.Channel_Partner_Name__c = :partnerId
                    OR Account__r.Channel_Partner__c = :partnerId
                  )
                LIMIT 1
            ];
        }
        if (invoices.isEmpty()) {
            throw new AuraHandledException('Unauthorised invoice operation.');
        }
    }

    private static Id resolvePartnerAccountId() {
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