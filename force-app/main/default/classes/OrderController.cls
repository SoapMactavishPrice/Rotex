public without sharing class OrderController {
    
    @AuraEnabled(cacheable=true)
    public static Id getMyChannelPartnerAccountId() {
        return resolvePartnerAccountId(null);
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getMyChannelPartnerAccountInfo() {
        Id partnerId = resolvePartnerAccountId(null);
        if (partnerId != null) {
            List<Account> accs = [SELECT Id, Name FROM Account WHERE Id = :partnerId LIMIT 1];
            if (!accs.isEmpty()) {
                Map<String, String> result = new Map<String, String>();
                result.put('Id', accs[0].Id);
                result.put('Name', accs[0].Name);
                return result;
            }
        }
        return null;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Order> getMyOrders() {
        Id partnerId = resolvePartnerAccountId(null);
        if (partnerId == null) {
            Id userId = UserInfo.getUserId();
            return [
                SELECT
                    Id, OrderNumber, Name, SO_No__c, Status, SO_Type__c,
                    AccountId, Account.Name,
                    EffectiveDate, CurrencyIsoCode, Net_Value__c,
                    Bill_To__c, Bill_To_Customer_Name__c, Bill_To_Customer_Name__r.Name,
                    Cust_Ref__c, Cust_Ref_Date__c, Req_Del_Date__c,
                    Ship_To__c, Sold_To__c, Terms_Of_Payment__c, Incoterms__c,
                    OwnerId, Owner.Name, Owner.FirstName, Owner.LastName, Owner.Email,
                    TotalAmount, CreatedDate,
                    (SELECT Id, OrderItemNumber, Product2.Name, Product2.ProductCode, UOM__c, ListPrice, UnitPrice, Quantity, TotalPrice FROM OrderItems)
                FROM Order
                WHERE CreatedById = :userId
                ORDER BY CreatedDate DESC
            ];
        }

        return [
            SELECT
                Id, OrderNumber, Name, SO_No__c, Status, SO_Type__c,
                AccountId, Account.Name,
                EffectiveDate, CurrencyIsoCode, Net_Value__c,
                Bill_To__c, Bill_To_Customer_Name__c, Bill_To_Customer_Name__r.Name,
                Cust_Ref__c, Cust_Ref_Date__c, Req_Del_Date__c,
                Ship_To__c, Sold_To__c, Terms_Of_Payment__c, Incoterms__c,
                OwnerId, Owner.Name, Owner.FirstName, Owner.LastName, Owner.Email,
                TotalAmount, CreatedDate,
                (SELECT Id, OrderItemNumber, Product2.Name, Product2.ProductCode, UOM__c, ListPrice, UnitPrice, Quantity, TotalPrice FROM OrderItems)
            FROM Order
            WHERE AccountId = :partnerId
               OR Account.Channel_Partner_Name__c = :partnerId
               OR Account.Channel_Partner__c = :partnerId
            ORDER BY CreatedDate DESC
        ];
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

    @AuraEnabled
    public static void saveOrder(String inputStr) {
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(inputStr);
        
        Order newOrder = new Order();
        newOrder.Status = 'Draft';
        
        if (data.containsKey('accountId') && data.get('accountId') != null) {
            newOrder.AccountId = (Id) data.get('accountId');
        } else {
            Id resolvedPartner = resolvePartnerAccountId(null);
            if(resolvedPartner != null) {
                newOrder.AccountId = resolvedPartner;
            } else {
                throw new AuraHandledException('Partner Account is required to create an Order.');
            }
        }
        
        if (data.containsKey('soNo') && data.get('soNo') != null) {
            newOrder.SO_No__c = (String) data.get('soNo');
        }
        if (data.containsKey('type') && data.get('type') != null) {
            newOrder.Type = (String) data.get('type');
        }
        if (data.containsKey('effectiveDate') && data.get('effectiveDate') != null) {
            newOrder.EffectiveDate = Date.valueOf((String) data.get('effectiveDate'));
        }
        if (data.containsKey('currencyIsoCode') && data.get('currencyIsoCode') != null) {
            newOrder.CurrencyIsoCode = (String) data.get('currencyIsoCode');
        }
        if (data.containsKey('netValue') && data.get('netValue') != null) {
            newOrder.Net_Value__c = String.valueOf(data.get('netValue'));
        }
        
        // Additional info
        if (data.containsKey('billTo') && String.isNotBlank((String) data.get('billTo'))) newOrder.Bill_To__c = (String) data.get('billTo');
        if (data.containsKey('shipTo') && String.isNotBlank((String) data.get('shipTo'))) newOrder.Ship_To__c = (String) data.get('shipTo');
        if (data.containsKey('billToCustomerName') && String.isNotBlank((String) data.get('billToCustomerName'))) newOrder.Bill_To_Customer_Name__c = (String) data.get('billToCustomerName');
        if (data.containsKey('soldTo') && String.isNotBlank((String) data.get('soldTo'))) newOrder.Sold_To__c = (String) data.get('soldTo');
        if (data.containsKey('custRef') && String.isNotBlank((String) data.get('custRef'))) newOrder.Cust_Ref__c = (String) data.get('custRef');
        if (data.containsKey('termsOfPayment') && String.isNotBlank((String) data.get('termsOfPayment'))) newOrder.Terms_Of_Payment__c = (String) data.get('termsOfPayment');
        if (data.containsKey('incoterms') && String.isNotBlank((String) data.get('incoterms'))) newOrder.Incoterms__c = (String) data.get('incoterms');
        
        if (data.containsKey('custRefDate') && String.isNotBlank((String) data.get('custRefDate'))) {
            newOrder.Cust_Ref_Date__c = Date.valueOf((String) data.get('custRefDate'));
        }
        if (data.containsKey('reqDelDate') && String.isNotBlank((String) data.get('reqDelDate'))) {
            newOrder.Req_Del_Date__c = Date.valueOf((String) data.get('reqDelDate'));
        }
        
        try {
            insert newOrder;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /* =========================================================
       ACTIVITY / NOTES / FILES (Order detail sidebar)
    ========================================================= */

    public class ActivityWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String subject;
        @AuraEnabled public String type;
        @AuraEnabled public String dueDate;
        @AuraEnabled public Boolean isOverdue;
        @AuraEnabled public Boolean isClosed;
    }

    public class NoteWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String body;
        @AuraEnabled public String createdDate;
        @AuraEnabled public String author;
    }

    public class FileWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public Id versionId;
        @AuraEnabled public String title;
        @AuraEnabled public String size;
        @AuraEnabled public String uploadedDate;
        @AuraEnabled public String fileType;
    }

    @AuraEnabled
    public static List<ActivityWrapper> getUpcomingActivities(Id orderId) {
        List<ActivityWrapper> results = new List<ActivityWrapper>();
        if (orderId == null) {
            return results;
        }
        assertOrderAccessible(orderId);

        for (Task t : [
            SELECT Id, Subject, ActivityDate, IsClosed
            FROM Task
            WHERE WhatId = :orderId
              AND IsClosed = false
            ORDER BY ActivityDate ASC NULLS LAST
            LIMIT 50
        ]) {
            ActivityWrapper w = new ActivityWrapper();
            w.id = t.Id;
            w.subject = t.Subject;
            w.type = 'Task';
            w.dueDate = t.ActivityDate != null ? t.ActivityDate.format() : 'No due date';
            w.isOverdue = t.ActivityDate != null && t.ActivityDate < Date.today();
            w.isClosed = false;
            results.add(w);
        }

        for (Event ev : [
            SELECT Id, Subject, StartDateTime
            FROM Event
            WHERE WhatId = :orderId
              AND StartDateTime >= :Datetime.now()
            ORDER BY StartDateTime ASC
            LIMIT 50
        ]) {
            ActivityWrapper w = new ActivityWrapper();
            w.id = ev.Id;
            w.subject = ev.Subject;
            w.type = 'Event';
            w.dueDate = ev.StartDateTime != null
                ? ev.StartDateTime.format('dd MMM yyyy, hh:mm a')
                : '';
            w.isOverdue = false;
            w.isClosed = false;
            results.add(w);
        }

        return results;
    }

    @AuraEnabled
    public static List<NoteWrapper> getOrderNotes(Id orderId) {
        List<NoteWrapper> results = new List<NoteWrapper>();
        if (orderId == null) {
            return results;
        }
        assertOrderAccessible(orderId);

        for (ContentDocumentLink l : [
            SELECT
                ContentDocumentId,
                ContentDocument.Title,
                ContentDocument.FileType,
                ContentDocument.CreatedDate,
                ContentDocument.CreatedBy.Name,
                ContentDocument.LatestPublishedVersion.TextPreview
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :orderId
              AND ContentDocument.FileType = 'SNOTE'
            ORDER BY ContentDocument.CreatedDate DESC
        ]) {
            NoteWrapper w = new NoteWrapper();
            w.id = l.ContentDocumentId;
            String preview = l.ContentDocument.LatestPublishedVersion != null
                ? l.ContentDocument.LatestPublishedVersion.TextPreview
                : null;
            w.body = String.isBlank(preview)
                ? l.ContentDocument.Title
                : stripHtml(preview);
            w.createdDate = l.ContentDocument.CreatedDate.format('dd MMM yyyy, hh:mm a');
            w.author = l.ContentDocument.CreatedBy.Name;
            results.add(w);
        }
        return results;
    }

    @AuraEnabled
    public static NoteWrapper addOrderNote(Id orderId, String noteBody) {
        if (orderId == null) {
            throw new AuraHandledException('Order Id is required.');
        }
        if (String.isBlank(noteBody)) {
            throw new AuraHandledException('Note text is required.');
        }
        assertOrderAccessible(orderId);

        String bodyText = noteBody.trim();
        ContentNote note = new ContentNote();
        note.Title = bodyText.length() > 80 ? bodyText.substring(0, 80) : bodyText;
        note.Content = Blob.valueOf(bodyText.escapeHtml4());
        insert note;

        ContentDocumentLink link = new ContentDocumentLink();
        link.ContentDocumentId = note.Id;
        link.LinkedEntityId = orderId;
        link.ShareType = 'V';
        link.Visibility = 'AllUsers';
        insert link;

        ContentVersion insertedNoteCV = [
            SELECT ContentDocumentId, TextPreview, CreatedDate, CreatedBy.Name, Title
            FROM ContentVersion
            WHERE ContentDocumentId = :note.Id
              AND IsLatest = true
            LIMIT 1
        ];

        NoteWrapper w = new NoteWrapper();
        w.id = insertedNoteCV.ContentDocumentId;
        w.body = String.isBlank(insertedNoteCV.TextPreview)
            ? insertedNoteCV.Title
            : stripHtml(insertedNoteCV.TextPreview);
        w.createdDate = insertedNoteCV.CreatedDate.format('dd MMM yyyy, hh:mm a');
        w.author = insertedNoteCV.CreatedBy.Name;
        return w;
    }

    @AuraEnabled
    public static List<FileWrapper> getOrderFiles(Id orderId) {
        List<FileWrapper> results = new List<FileWrapper>();
        if (orderId == null) {
            return results;
        }
        assertOrderAccessible(orderId);

        for (ContentDocumentLink l : [
            SELECT ContentDocumentId,
                   ContentDocument.Title,
                   ContentDocument.ContentSize,
                   ContentDocument.CreatedDate,
                   ContentDocument.FileType,
                   ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :orderId
            ORDER BY ContentDocument.CreatedDate DESC
        ]) {
            if (l.ContentDocument.FileType == 'SNOTE') {
                continue;
            }
            FileWrapper w = new FileWrapper();
            w.id = l.ContentDocumentId;
            w.versionId = l.ContentDocument.LatestPublishedVersionId;
            w.fileType = l.ContentDocument.FileType;
            w.title = l.ContentDocument.Title;
            w.size = formatFileSize(l.ContentDocument.ContentSize);
            w.uploadedDate = l.ContentDocument.CreatedDate.format('dd MMM yyyy');
            results.add(w);
        }
        return results;
    }

    @AuraEnabled
    public static FileWrapper saveOrderAttachment(Id orderId, String fileName, String base64Data) {
        if (orderId == null) {
            throw new AuraHandledException('Order Id is required.');
        }
        if (String.isBlank(fileName) || String.isBlank(base64Data)) {
            throw new AuraHandledException('File data is required.');
        }
        assertOrderAccessible(orderId);

        try {
            ContentVersion cv = new ContentVersion(
                Title = fileName,
                PathOnClient = fileName,
                VersionData = EncodingUtil.base64Decode(base64Data),
                IsMajorVersion = true
            );
            insert cv;

            ContentVersion insertedCV = [
                SELECT ContentDocumentId,
                       ContentDocument.Title,
                       ContentDocument.ContentSize,
                       ContentDocument.CreatedDate,
                       ContentDocument.FileType,
                       ContentDocument.LatestPublishedVersionId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ];

            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = insertedCV.ContentDocumentId,
                LinkedEntityId = orderId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
            insert cdl;

            FileWrapper w = new FileWrapper();
            w.id = insertedCV.ContentDocumentId;
            w.versionId = insertedCV.ContentDocument.LatestPublishedVersionId;
            w.fileType = insertedCV.ContentDocument.FileType;
            w.title = insertedCV.ContentDocument.Title;
            w.size = formatFileSize(insertedCV.ContentDocument.ContentSize);
            w.uploadedDate = insertedCV.ContentDocument.CreatedDate.format('dd MMM yyyy');
            return w;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static void assertOrderAccessible(Id orderId) {
        Id userId = UserInfo.getUserId();
        List<Order> orders = [
            SELECT Id
            FROM Order
            WHERE Id = :orderId
              AND CreatedById = :userId
            LIMIT 1
        ];
        if (orders.isEmpty()) {
            throw new AuraHandledException('Unauthorised order operation.');
        }
    }

    private static String stripHtml(String value) {
        if (String.isBlank(value)) {
            return value;
        }
        return value
            .replaceAll('(?i)<br\\s*/?>', '\n')
            .replaceAll('(?i)</p>', '\n')
            .replaceAll('<[^>]+>', '')
            .unescapeHtml4()
            .trim();
    }

    private static String formatFileSize(Integer bytes) {
        if (bytes == null) {
            return '';
        }
        if (bytes < 1024) {
            return bytes + ' B';
        } else if (bytes < 1048576) {
            return Math.round(bytes / 1024.0) + ' KB';
        } else {
            return (bytes / 1048576.0).setScale(1) + ' MB';
        }
    }
}