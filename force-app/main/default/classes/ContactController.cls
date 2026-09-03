public without sharing class ContactController {

    public class ContactCreateInput {
        @AuraEnabled public Id contactId { get; set; }
        @AuraEnabled public String salutation { get; set; }
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String lastName { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String mobilePhone { get; set; }
        @AuraEnabled public String designation { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Id accountId { get; set; }
        @AuraEnabled public String dob { get; set; }
        @AuraEnabled public String anniversary { get; set; }
        @AuraEnabled public String street { get; set; }
        @AuraEnabled public String city { get; set; }
        @AuraEnabled public String postalCode { get; set; }
        @AuraEnabled public String state { get; set; }
        @AuraEnabled public String country { get; set; }
        @AuraEnabled public Id partnerAccountId { get; set; }
    }

    public class LookupOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String label;
        @AuraEnabled public String subtitle;

        public LookupOption(Id id, String label, String subtitle) {
            this.id = id;
            this.label = label;
            this.subtitle = subtitle;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Id getMyChannelPartnerAccountId() {
        return resolvePartnerAccountId(null);
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getSalutationPicklistValues() {
        List<String> values = new List<String>();
        for (Schema.PicklistEntry entry : Contact.Salutation.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                values.add(entry.getValue());
            }
        }
        return values;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getStatusPicklistValues() {
        List<String> values = new List<String>();
        for (Schema.PicklistEntry entry : Contact.Status__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                values.add(entry.getValue());
            }
        }
        return values;
    }

    @AuraEnabled(cacheable=true)
    public static List<Contact> getMyContacts() {
        Id partnerId = resolvePartnerAccountId(null);
        if (partnerId == null) {
            return new List<Contact>();
        }

        return [
            SELECT
                Id, Name, Salutation, FirstName, LastName,
                Email, MobilePhone, Phone,
                Contact_Person_Designation__c,
                Status__c,
                AccountId, Account.Name,
                DOB__c, Anniversary__c,
                MailingStreet, MailingCity, MailingState,
                MailingPostalCode, MailingCountry,
                Owner.Name, CreatedDate
            FROM Contact
            WHERE AccountId != null
              AND Account.Channel_Partner_Name__c = :partnerId
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<LookupOption> searchCustomerAccounts(String searchText, Id partnerAccountId) {
        Id partnerId = resolvePartnerAccountId(partnerAccountId);
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

    @AuraEnabled
    public static Contact createContact(ContactCreateInput input) {
        if (input == null) {
            throw new AuraHandledException('Contact details are required.');
        }
        if (String.isBlank(input.firstName)) {
            throw new AuraHandledException('First Name is required.');
        }
        if (String.isBlank(input.lastName)) {
            throw new AuraHandledException('Last Name is required.');
        }
        if (input.accountId == null) {
            throw new AuraHandledException('Customer Name is required.');
        }

        Id partnerId = resolvePartnerAccountId(input.partnerAccountId);
        assertAccountBelongsToPartner(input.accountId, partnerId);

        Contact con = new Contact();
        con.Salutation = blankToNull(input.salutation);
        con.FirstName = input.firstName.trim();
        con.LastName = input.lastName.trim();
        con.Email = blankToNull(input.email);
        con.MobilePhone = blankToNull(input.mobilePhone);
        con.Contact_Person_Designation__c = blankToNull(input.designation);
        con.Status__c = String.isBlank(input.status) ? 'Active' : input.status.trim();
        con.AccountId = input.accountId;
        con.DOB__c = parseDate(input.dob);
        con.Anniversary__c = parseDate(input.anniversary);
        con.MailingStreet = blankToNull(input.street);
        con.MailingCity = blankToNull(input.city);
        con.MailingPostalCode = blankToNull(input.postalCode);
        con.MailingState = blankToNull(input.state);
        con.MailingCountry = blankToNull(input.country);
        con.OwnerId = UserInfo.getUserId();

        try {
            insert con;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }

        return queryContactById(con.Id);
    }

    @AuraEnabled
    public static Contact updateContact(ContactCreateInput input) {
        if (input == null || input.contactId == null) {
            throw new AuraHandledException('Contact Id is required.');
        }
        if (String.isBlank(input.firstName)) {
            throw new AuraHandledException('First Name is required.');
        }
        if (String.isBlank(input.lastName)) {
            throw new AuraHandledException('Last Name is required.');
        }
        if (input.accountId == null) {
            throw new AuraHandledException('Customer Name is required.');
        }

        Id partnerId = resolvePartnerAccountId(input.partnerAccountId);
        assertContactBelongsToPartner(input.contactId, partnerId);
        assertAccountBelongsToPartner(input.accountId, partnerId);

        Contact con = new Contact(Id = input.contactId);
        con.Salutation = blankToNull(input.salutation);
        con.FirstName = input.firstName.trim();
        con.LastName = input.lastName.trim();
        con.Email = blankToNull(input.email);
        con.MobilePhone = blankToNull(input.mobilePhone);
        con.Contact_Person_Designation__c = blankToNull(input.designation);
        con.Status__c = String.isBlank(input.status) ? 'Active' : input.status.trim();
        con.AccountId = input.accountId;
        con.DOB__c = parseDate(input.dob);
        con.Anniversary__c = parseDate(input.anniversary);
        con.MailingStreet = blankToNull(input.street);
        con.MailingCity = blankToNull(input.city);
        con.MailingPostalCode = blankToNull(input.postalCode);
        con.MailingState = blankToNull(input.state);
        con.MailingCountry = blankToNull(input.country);

        try {
            update con;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }

        return queryContactById(con.Id);
    }

    private static Contact queryContactById(Id contactId) {
        return [
            SELECT
                Id, Name, Salutation, FirstName, LastName,
                Email, MobilePhone, Phone,
                Contact_Person_Designation__c,
                Status__c,
                AccountId, Account.Name,
                DOB__c, Anniversary__c,
                MailingStreet, MailingCity, MailingState,
                MailingPostalCode, MailingCountry,
                Owner.Name, CreatedDate
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];
    }

    private static void assertContactBelongsToPartner(Id contactId, Id partnerId) {
        if (partnerId == null) {
            throw new AuraHandledException('Channel Partner account could not be resolved.');
        }
        List<Contact> contacts = [
            SELECT Id
            FROM Contact
            WHERE Id = :contactId
              AND AccountId != null
              AND Account.Channel_Partner_Name__c = :partnerId
            LIMIT 1
        ];
        if (contacts.isEmpty()) {
            throw new AuraHandledException(
                'Selected Contact is not associated with your Channel Partner account.'
            );
        }
    }

    private static void assertAccountBelongsToPartner(Id accountId, Id partnerId) {
        if (partnerId == null) {
            throw new AuraHandledException('Channel Partner account could not be resolved.');
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
                'Selected Customer is not associated with your Channel Partner account.'
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

    private static Date parseDate(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return Date.valueOf(value.trim());
        } catch (Exception e) {
            throw new AuraHandledException('Invalid date value: ' + value);
        }
    }

    private static String blankToNull(String value) {
        return String.isBlank(value) ? null : value.trim();
    }

    /* =========================================================
       ACTIVITY / NOTES / FILES (Contact detail sidebar)
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
    public static List<ActivityWrapper> getUpcomingActivities(Id contactId) {
        List<ActivityWrapper> results = new List<ActivityWrapper>();
        if (contactId == null) {
            return results;
        }

        Id currentUserId = UserInfo.getUserId();

        for (Task t : [
            SELECT Id, Subject, ActivityDate, IsClosed
            FROM Task
            WHERE OwnerId = :currentUserId
              AND WhoId = :contactId
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
            WHERE OwnerId = :currentUserId
              AND WhoId = :contactId
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
    public static List<NoteWrapper> getContactNotes(Id contactId) {
        List<NoteWrapper> results = new List<NoteWrapper>();
        if (contactId == null) {
            return results;
        }

        for (ContentDocumentLink l : [
            SELECT
                ContentDocumentId,
                ContentDocument.Title,
                ContentDocument.FileType,
                ContentDocument.CreatedDate,
                ContentDocument.CreatedBy.Name,
                ContentDocument.LatestPublishedVersion.TextPreview
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :contactId
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
    public static NoteWrapper addContactNote(Id contactId, String noteBody) {
        if (contactId == null) {
            throw new AuraHandledException('Contact Id is required.');
        }
        if (String.isBlank(noteBody)) {
            throw new AuraHandledException('Note text is required.');
        }

        Id partnerId = resolvePartnerAccountId(null);
        assertContactBelongsToPartner(contactId, partnerId);

        String bodyText = noteBody.trim();

        ContentNote note = new ContentNote();
        note.Title = bodyText.length() > 80 ? bodyText.substring(0, 80) : bodyText;
        note.Content = Blob.valueOf(bodyText.escapeHtml4());
        insert note;

        ContentDocumentLink link = new ContentDocumentLink();
        link.ContentDocumentId = note.Id;
        link.LinkedEntityId = contactId;
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
    public static List<FileWrapper> getContactFiles(Id contactId) {
        List<FileWrapper> results = new List<FileWrapper>();
        if (contactId == null) {
            return results;
        }

        for (ContentDocumentLink l : [
            SELECT ContentDocumentId,
                   ContentDocument.Title,
                   ContentDocument.ContentSize,
                   ContentDocument.CreatedDate,
                   ContentDocument.FileType,
                   ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :contactId
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
    public static FileWrapper saveContactAttachment(Id contactId, String fileName, String base64Data) {
        try {
            if (contactId == null) {
                throw new AuraHandledException('Contact Id is required.');
            }
            if (String.isBlank(fileName) || String.isBlank(base64Data)) {
                throw new AuraHandledException('File data is required.');
            }

            Id partnerId = resolvePartnerAccountId(null);
            assertContactBelongsToPartner(contactId, partnerId);

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

            insert new ContentDocumentLink(
                ContentDocumentId = insertedCV.ContentDocumentId,
                LinkedEntityId = contactId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );

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
        }
        if (bytes < 1024 * 1024) {
            return (bytes / 1024) + ' KB';
        }
        return (bytes / (1024 * 1024)) + ' MB';
    }
}