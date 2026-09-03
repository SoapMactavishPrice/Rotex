public without sharing class ComplaintController {

    /**
     * Feature_Setting__mdt.Default.Show_Complaint_Search_Export__c —
     * when true: Complaints list shows search, export, and table.
     */
    @AuraEnabled(cacheable=true)
    public static Boolean getShowComplaintListUiFlag() {
        Feature_Setting__mdt setting = Feature_Setting__mdt.getInstance('Default');
        return setting != null && setting.Show_Complaint_Search_Export__c == true;
    }

    @AuraEnabled(cacheable=true)
    public static List<Case> getMyCases() {
        Id partnerId = resolvePartnerAccountId(null);
        Id userId = UserInfo.getUserId();
        
        if (partnerId == null) {
            return [
                SELECT
                    Id, CaseNumber, Subject, AccountId, Account.Name,
                    ContactId, Contact.Name, Status, Priority, Description, CreatedDate, ClosedDate, OwnerId, Owner.Name,
                    Resolution__c, Root_Cause__c, Remarks__c, Customer_Satisfaction__c,
                    Ticket_Type__c, Category__c,
                    Customer__c, Customer__r.Name,
                    Quote__c, Quote__r.QuoteNumber, Quote__r.Name,
                    Order__c, Order__r.OrderNumber, Order__r.Name, Order__r.SO_No__c,
                    Invoice__c, Invoice__r.Name, Invoice__r.Bill_Doc_No__c,
                    GRN__c, GRN__r.Name,
                    Product__c, Product__r.Name
                FROM Case
                WHERE OwnerId = :userId
                ORDER BY CreatedDate DESC
            ];
        }

        return [
            SELECT
                Id, CaseNumber, Subject, AccountId, Account.Name,
                ContactId, Contact.Name, Status, Priority, Description, CreatedDate, ClosedDate, OwnerId, Owner.Name,
                Resolution__c, Root_Cause__c, Remarks__c, Customer_Satisfaction__c,
                Ticket_Type__c, Category__c,
                Customer__c, Customer__r.Name,
                Quote__c, Quote__r.QuoteNumber, Quote__r.Name,
                Order__c, Order__r.OrderNumber, Order__r.Name, Order__r.SO_No__c,
                Invoice__c, Invoice__r.Name, Invoice__r.Bill_Doc_No__c,
                GRN__c, GRN__r.Name,
                Product__c, Product__r.Name
            FROM Case
            WHERE AccountId = :partnerId
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<CaseComment> getCaseComments(Id caseId) {
        return [
            SELECT Id, CommentBody, CreatedDate, CreatedBy.Name
            FROM CaseComment 
            WHERE ParentId = :caseId 
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
    public static Id createComplaint(Map<String, Object> caseData) {
        Case newCase = new Case();
        
        if (caseData.containsKey('Subject')) newCase.Subject = (String)caseData.get('Subject');
        if (caseData.containsKey('Description')) newCase.Description = (String)caseData.get('Description');
        if (caseData.containsKey('Priority')) newCase.Priority = (String)caseData.get('Priority');
        if (caseData.containsKey('Status')) newCase.Status = (String)caseData.get('Status');
        if (caseData.containsKey('OwnerId') && String.isNotBlank((String)caseData.get('OwnerId'))) {
            newCase.OwnerId = (Id)caseData.get('OwnerId');
        }
        
        for (String key : caseData.keySet()) {
            if (key.endsWith('__c')) {
                try {
                    newCase.put(key, caseData.get(key));
                } catch(Exception e) {
                    System.debug('Invalid field: ' + key);
                }
            }
        }
        
        if (caseData.containsKey('AccountId') && String.isNotBlank((String)caseData.get('AccountId'))) {
            newCase.AccountId = (Id)caseData.get('AccountId');
        } else {
            newCase.AccountId = resolvePartnerAccountId(null);
        }
        
        if (caseData.containsKey('ContactId') && String.isNotBlank((String)caseData.get('ContactId'))) {
            newCase.ContactId = (Id)caseData.get('ContactId');
        } else {
            List<User> currentUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            if (!currentUser.isEmpty() && currentUser[0].ContactId != null) {
                newCase.ContactId = currentUser[0].ContactId;
            }
        }

        // Cases created from CP portal always use Case Origin = CP Portal
        newCase.Origin = 'CP Portal';

        insert newCase;
        return newCase.Id;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getAllCasePicklists() {
        Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();
        
        String[] fields = new String[]{'Ticket_Type__c', 'Category__c', 'Priority', 'Root_Cause__c', 'Customer_Satisfaction__c', 'Status'};
        
        SObjectType objType = Schema.getGlobalDescribe().get('Case');
        if (objType != null) {
            Map<String, SObjectField> fieldMap = objType.getDescribe().fields.getMap();
            for (String fName : fields) {
                if (fieldMap.containsKey(fName)) {
                    List<Map<String, String>> options = new List<Map<String, String>>();
                    for (Schema.PicklistEntry entry : fieldMap.get(fName).getDescribe().getPicklistValues()) {
                        if (entry.isActive()) {
                            Map<String, String> opt = new Map<String, String>();
                            opt.put('label', entry.getLabel());
                            opt.put('value', entry.getValue());
                            options.add(opt);
                        }
                    }
                    result.put(fName, options);
                }
            }
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAvailableAccounts() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Id partnerId = resolvePartnerAccountId(null);
        
        String query = 'SELECT Id, Name FROM Account ';
        if (partnerId != null) {
            query += ' WHERE Id = :partnerId ';
        }
        query += ' ORDER BY Name LIMIT 100';
        
        for (Account acc : Database.query(query)) {
            Map<String, String> opt = new Map<String, String>();
            opt.put('label', acc.Name);
            opt.put('value', acc.Id);
            options.add(opt);
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAvailableContacts() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Id partnerId = resolvePartnerAccountId(null);
        
        String query = 'SELECT Id, Name FROM Contact ';
        if (partnerId != null) {
            query += ' WHERE AccountId = :partnerId ';
        }
        query += ' ORDER BY Name LIMIT 100';
        
        for (Contact c : Database.query(query)) {
            Map<String, String> opt = new Map<String, String>();
            opt.put('label', c.Name);
            opt.put('value', c.Id);
            options.add(opt);
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getCategoryRelatedData(Id accountId) {
        if (accountId == null) {
            accountId = resolvePartnerAccountId(null);
        }
        
        Map<String, List<Map<String, String>>> result = new CategoryDataHelper().getData(accountId);
        
        // 4. Invoices (Custom object without standard portal sharing, use explicit filter in 'without sharing' context)
        List<Map<String, String>> invoices = new List<Map<String, String>>();
        if (accountId != null) {
            for(SO_Invoice__c inv : [SELECT Id, Name, Bill_Doc_No__c FROM SO_Invoice__c WHERE Account__c = :accountId OR Account__r.Channel_Partner_Name__c = :accountId OR Account__r.Channel_Partner__c = :accountId ORDER BY CreatedDate DESC LIMIT 100]) {
                Map<String, String> m = new Map<String, String>();
                String billDoc = inv.Bill_Doc_No__c;
                String name = inv.Name;
                m.put('label', String.isNotBlank(billDoc) ? billDoc : name);
                m.put('value', inv.Id);
                invoices.add(m);
            }
        }
        result.put('Invoice', invoices);
        
        // 5. GRNs (Use static SOQL and explicit filters for Partner Access)
        List<Map<String, String>> grns = new List<Map<String, String>>();
        if (accountId != null) {
            for(GRN__c grn : [SELECT Id, Name FROM GRN__c WHERE Channel_Partner__c = :accountId OR Invoice__r.Account__c = :accountId OR Invoice__r.Account__r.Channel_Partner_Name__c = :accountId ORDER BY CreatedDate DESC LIMIT 100]) {
                Map<String, String> m = new Map<String, String>();
                m.put('label', grn.Name);
                m.put('value', grn.Id);
                grns.add(m);
            }
        }
        result.put('GRN', grns);
        
        // 6. Products
        List<Map<String, String>> products = new List<Map<String, String>>();
        for(Product2 p : [SELECT Id, Name FROM Product2 WHERE IsActive = true LIMIT 100]) {
            Map<String, String> m = new Map<String, String>();
            m.put('label', p.Name);
            m.put('value', p.Id);
            products.add(m);
        }
        result.put('Product', products);
        
        return result;
    }
    
    public class NoteWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String body;
        @AuraEnabled public String createdDate;
        @AuraEnabled public String author;
    }

    public class FileWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String versionId;
        @AuraEnabled public String fileType;
        @AuraEnabled public String title;
        @AuraEnabled public String size;
        @AuraEnabled public String uploadedDate;
    }

    @AuraEnabled
    public static List<NoteWrapper> getCaseNotes(Id caseId) {
        List<NoteWrapper> results = new List<NoteWrapper>();
        if (caseId == null) {
            return results;
        }
        assertCaseAccessible(caseId);

        for (ContentDocumentLink l : [
            SELECT
                ContentDocumentId,
                ContentDocument.Title,
                ContentDocument.FileType,
                ContentDocument.CreatedDate,
                ContentDocument.CreatedBy.Name,
                ContentDocument.LatestPublishedVersion.TextPreview
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :caseId
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
    public static NoteWrapper addCaseNote(Id caseId, String noteBody) {
        if (caseId == null) {
            throw new AuraHandledException('Case Id is required.');
        }
        if (String.isBlank(noteBody)) {
            throw new AuraHandledException('Note text is required.');
        }
        assertCaseAccessible(caseId);

        String bodyText = noteBody.trim();
        ContentNote note = new ContentNote();
        note.Title = bodyText.length() > 80 ? bodyText.substring(0, 80) : bodyText;
        note.Content = Blob.valueOf(bodyText.escapeHtml4());
        insert note;

        ContentDocumentLink link = new ContentDocumentLink();
        link.ContentDocumentId = note.Id;
        link.LinkedEntityId = caseId;
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
    public static List<FileWrapper> getCaseFiles(Id caseId) {
        List<FileWrapper> results = new List<FileWrapper>();
        if (caseId == null) {
            return results;
        }
        assertCaseAccessible(caseId);

        for (ContentDocumentLink l : [
            SELECT ContentDocumentId,
                   ContentDocument.Title,
                   ContentDocument.ContentSize,
                   ContentDocument.CreatedDate,
                   ContentDocument.FileType,
                   ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :caseId
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
    public static FileWrapper saveCaseAttachment(Id caseId, String fileName, String base64Data) {
        if (caseId == null) {
            throw new AuraHandledException('Case Id is required.');
        }
        if (String.isBlank(fileName) || String.isBlank(base64Data)) {
            throw new AuraHandledException('File data is required.');
        }
        assertCaseAccessible(caseId);

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
                LinkedEntityId = caseId,
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

    private static void assertCaseAccessible(Id caseId) {
        Id partnerId = resolvePartnerAccountId(null);
        Id userId = UserInfo.getUserId();
        List<Case> cases;
        if (partnerId != null) {
            cases = [
                SELECT Id
                FROM Case
                WHERE Id = :caseId
                  AND AccountId = :partnerId
                LIMIT 1
            ];
        } else {
            cases = [
                SELECT Id
                FROM Case
                WHERE Id = :caseId
                  AND OwnerId = :userId
                LIMIT 1
            ];
        }
        if (cases.isEmpty()) {
            throw new AuraHandledException('Unauthorised case operation.');
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

    private with sharing class CategoryDataHelper {
        public Map<String, List<Map<String, String>>> getData(Id accountId) {
            Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();
            
            // 1. Customers (Accounts where RecordType is Customer)
            List<Map<String, String>> customers = new List<Map<String, String>>();
            if (accountId != null) {
                for(Account a : [SELECT Id, Name, Approval_Status__c FROM Account WHERE RecordType.DeveloperName = 'Customer' AND Channel_Partner_Name__c = :accountId LIMIT 100]) {
                    Map<String, String> m = new Map<String, String>();
                    m.put('label', a.Name + (String.isNotBlank(a.Approval_Status__c) ? ' (' + a.Approval_Status__c + ')' : ''));
                    m.put('value', a.Id);
                    customers.add(m);
                }
            }
            result.put('Customer', customers);
            
            // 2. Quotes (Filtered by AccountId)
            List<Map<String, String>> quotes = new List<Map<String, String>>();
            if (accountId != null) {
                for(Quote q : [SELECT Id, Name, QuoteNumber, Status FROM Quote WHERE AccountId = :accountId ORDER BY CreatedDate DESC LIMIT 100]) {
                    Map<String, String> m = new Map<String, String>();
                    String label = q.QuoteNumber + (String.isNotBlank(q.Name) ? ' - ' + q.Name : '') + (String.isNotBlank(q.Status) ? ' (' + q.Status + ')' : '');
                    m.put('label', label);
                    m.put('value', q.Id);
                    quotes.add(m);
                }
            }
            result.put('Quote', quotes);
            
            // 3. Orders (Filtered by AccountId)
            List<Map<String, String>> orders = new List<Map<String, String>>();
            if (accountId != null) {
                for(Order o : [SELECT Id, Name, OrderNumber, SO_No__c, Status FROM Order WHERE AccountId = :accountId ORDER BY CreatedDate DESC LIMIT 100]) {
                    Map<String, String> m = new Map<String, String>();
                    String orderName = String.isNotBlank(o.SO_No__c) ? o.SO_No__c : o.Name;
                    String label = o.OrderNumber + (String.isNotBlank(orderName) ? ' - ' + orderName : '') + (String.isNotBlank(o.Status) ? ' (' + o.Status + ')' : '');
                    m.put('label', label);
                    m.put('value', o.Id);
                    orders.add(m);
                }
            }
            result.put('Order', orders);
            
            return result;
        }
    }
}