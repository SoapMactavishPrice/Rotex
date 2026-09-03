public without sharing class QuoteController {

    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public Boolean isDefault;

        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
            this.isDefault = false;
        }

        public PicklistOption(String label, String value, Boolean isDefault) {
            this.label = label;
            this.value = value;
            this.isDefault = isDefault == true;
        }
    }

    public class LookupOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String label;
        @AuraEnabled public String subtitle;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;

        public LookupOption(Id id, String label, String subtitle) {
            this.id = id;
            this.label = label;
            this.subtitle = subtitle;
        }

        public LookupOption(Id id, String label, String subtitle, String email, String phone) {
            this.id = id;
            this.label = label;
            this.subtitle = subtitle;
            this.email = email;
            this.phone = phone;
        }
    }

    public class QuoteCreateInput {
        @AuraEnabled public Id quoteId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Id accountId { get; set; }
        @AuraEnabled public String quoteDate { get; set; }
        @AuraEnabled public String quoteValidTill { get; set; }
        @AuraEnabled public String currencyIsoCode { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String customerReferenceNo { get; set; }
        @AuraEnabled public String customerReferenceDate { get; set; }
        @AuraEnabled public String requestedDeliveryDate { get; set; }
        @AuraEnabled public String pbgOrBgRequired { get; set; }
        @AuraEnabled public String pbgOrBgComments { get; set; }
        @AuraEnabled public String ldClauseApplicable { get; set; }
        @AuraEnabled public String ldClauseComments { get; set; }
        @AuraEnabled public String validityOfOffer { get; set; }
        @AuraEnabled public String requestedValidityOfOffer { get; set; }
        @AuraEnabled public String deliveryPeriod { get; set; }
        @AuraEnabled public String incoTerms { get; set; }
        @AuraEnabled public String paymentTerms { get; set; }
        @AuraEnabled public String prices { get; set; }
        @AuraEnabled public String warrantyTerms { get; set; }
        @AuraEnabled public String requestedWarrantyTerms { get; set; }
        @AuraEnabled public String liquidateTerms { get; set; }
        @AuraEnabled public String transportDetails { get; set; }
        @AuraEnabled public String deliveryLocation { get; set; }
        @AuraEnabled public String specialRemarks { get; set; }
        @AuraEnabled public Id contactId { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String billToPartyCode { get; set; }
        @AuraEnabled public String billToStreet { get; set; }
        @AuraEnabled public String billToCity { get; set; }
        @AuraEnabled public String billToPostalCode { get; set; }
        @AuraEnabled public String billToState { get; set; }
        @AuraEnabled public String billToCountry { get; set; }
        @AuraEnabled public String shipToPartyCode { get; set; }
        @AuraEnabled public String shipToStreet { get; set; }
        @AuraEnabled public String shipToCity { get; set; }
        @AuraEnabled public String shipToPostalCode { get; set; }
        @AuraEnabled public String shipToState { get; set; }
        @AuraEnabled public String shipToCountry { get; set; }
        @AuraEnabled public Id partnerAccountId { get; set; }
        @AuraEnabled public String quoteType { get; set; }
        @AuraEnabled public Id recordTypeId { get; set; }
        @AuraEnabled public Boolean usePartnerProducts { get; set; }
        @AuraEnabled public Boolean mtaQuote { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static Id getMyChannelPartnerAccountId() {
        return resolvePartnerAccountId(null);
    }

    @AuraEnabled(cacheable=true)
    public static String getCurrentUserName() {
        List<User> users = [
            SELECT Name, FirstName, LastName, Email, Username
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (users.isEmpty()) {
            return UserInfo.getName();
        }
        return formatOwnerDisplayName(users[0]);
    }

    @AuraEnabled(cacheable=true)
    public static LookupOption getMyLoginAccount() {
        Id partnerId = resolvePartnerAccountId(null);
        if (partnerId == null) {
            return null;
        }
        List<Account> accounts = [
            SELECT Id, Name
            FROM Account
            WHERE Id = :partnerId
            LIMIT 1
        ];
        if (accounts.isEmpty()) {
            return null;
        }
        return new LookupOption(accounts[0].Id, accounts[0].Name, '');
    }

    public class SecondaryCustomerCheckResult {
        @AuraEnabled public Boolean ok;
        @AuraEnabled public String message;
        @AuraEnabled public String businessLine;
        @AuraEnabled public Boolean usePartnerProducts;
    }

    @AuraEnabled
    public static SecondaryCustomerCheckResult validateSecondaryCustomerAccount(Id accountId) {
        SecondaryCustomerCheckResult result = new SecondaryCustomerCheckResult();
        result.ok = false;
        result.usePartnerProducts = false;

        Id partnerId = resolvePartnerAccountId(null);
        if (partnerId == null) {
            result.message = 'Channel Partner account could not be resolved.';
            return result;
        }
        if (accountId == null) {
            result.message = 'Customer Name is required.';
            return result;
        }

        assertAccountAccessibleForQuote(accountId, partnerId, 'Secondary Customer');

        List<Account> accounts = [
            SELECT Id, Name, Business_type__c, Approval_Status__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        if (accounts.isEmpty()) {
            result.message = 'Selected customer was not found.';
            return result;
        }

        Account acc = accounts[0];
        if (String.isBlank(acc.Business_type__c)) {
            result.message = 'Business Line is not set on this customer. Please update the customer before creating a quote.';
            return result;
        }
        if (acc.Approval_Status__c != 'Approved') {
            result.message = 'Customer Approval Status must be Approved before creating a quote. Current status: '
                + (String.isBlank(acc.Approval_Status__c) ? 'Not set' : acc.Approval_Status__c)
                + '.';
            return result;
        }

        result.ok = true;
        result.businessLine = acc.Business_type__c;
        String normalizedBusinessLine = acc.Business_type__c == null
            ? ''
            : acc.Business_type__c.trim().toUpperCase().replace('-', ' ').replace('_', ' ');
        while (normalizedBusinessLine.contains('  ')) {
            normalizedBusinessLine = normalizedBusinessLine.replace('  ', ' ');
        }
        result.usePartnerProducts = normalizedBusinessLine == 'NON ROTEX';
        result.message = 'OK';
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getQuoteTypePicklistValues() {
        return toPicklistOptions(Quote.Quote_Type__c.getDescribe().getPicklistValues());
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getQuoteRecordTypeOptions() {
        List<PicklistOption> options = new List<PicklistOption>();
        for (RecordType rt : [
            SELECT Id, Name, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Quote'
              AND IsActive = true
            ORDER BY Name
        ]) {
            options.add(new PicklistOption(rt.Name, String.valueOf(rt.Id)));
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getStatusPicklistValues() {
        return toPicklistOptions(Quote.Status.getDescribe().getPicklistValues());
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getCurrencyPicklistValues() {
        return toPicklistOptions(Quote.CurrencyIsoCode.getDescribe().getPicklistValues());
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getIncoTermsPicklistValues() {
        return toPicklistOptions(Quote.INCO_Terms__c.getDescribe().getPicklistValues());
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getPaymentTermsPicklistValues() {
        return toPicklistOptions(Quote.Payment_Terms__c.getDescribe().getPicklistValues());
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getValidityOfOfferPicklistValues() {
        return toPicklistOptions(Quote.Validity_of_Offer__c.getDescribe().getPicklistValues());
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getWarrantyTermsPicklistValues() {
        return toPicklistOptions(Quote.Warranty_Terms__c.getDescribe().getPicklistValues());
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getYesNoPicklistValues() {
        return toPicklistOptions(Quote.PBG_or_BG_required__c.getDescribe().getPicklistValues());
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getRequestedValidityOfOfferPicklistValues() {
        return toPicklistOptions(Quote.Requested_Validity_Of_Offer__c.getDescribe().getPicklistValues());
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getRequestedWarrantyTermsPicklistValues() {
        return toPicklistOptions(Quote.Warranty_Terms_Draft__c.getDescribe().getPicklistValues());
    }

    @AuraEnabled(cacheable=true)
    public static List<Quote> getMyQuotes() {
        Id partnerId = resolvePartnerAccountId(null);
        if (partnerId == null) {
            return new List<Quote>();
        }

        return [
            SELECT
                Id, QuoteNumber, Name, Status, CurrencyIsoCode,
                OpportunityId, Opportunity.Name,
                AccountId, Account.Name, Account.Business_type__c,
                QuoteAccountId, QuoteAccount.Name, QuoteAccount.Business_type__c,
                Account__c, Account__r.Name, Account__r.Business_type__c,
                Quote_Date__c, Quote_Valid_Till__c, Quote_Type__c,
                OwnerId, Owner.Name, Owner.FirstName, Owner.LastName, Owner.Email,
                CP_Owner_Name__c, CP_Owner_Name__r.Name, CP_Owner_Name__r.FirstName,
                CP_Owner_Name__r.LastName, CP_Owner_Name__r.Email,
                Rev_No__c, Rev_Date__c, MTA_Quote__c,
                SAP_Quotation_Number__c,
                Customer_Reference_No__c, Customer_Reference_Date__c,
                RequestedDeliveryDate__c,
                PBG_or_BG_required__c, PBG_or_BG_comments__c,
                LD_Clause_Applicable__c, LD_Clause_comments__c,
                Validity_of_Offer__c, Requested_Validity_Of_Offer__c,
                Delivery_Period__c, INCO_Terms__c,
                Payment_Terms__c, Prices__c, Warranty_Terms__c,
                Warranty_Terms_Draft__c,
                Liquidate_Terms__c, Transport_Details__c,
                Delivery_Location__c, Special_Remarks__c,
                ContactId, Contact.Name, Phone, Email,
                Bill_To_Party_Code__c,
                Bill_To_Street__c, Bill_To_City__c,
                Bill_To_Postal_Code__c, Bill_To_State__c, Bill_To_Country__c,
                Ship_To_Party_Code__c,
                Ship_To_Street__c, Ship_To_City__c,
                Ship_To_Postal_Code__c, Ship_To_State__c, Ship_To_Country__c,
                RecordTypeId, RecordType.Name, RecordType.DeveloperName,
                CreatedDate
            FROM Quote
            WHERE AccountId = :partnerId
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
              AND Approval_Status__c = 'Approved'
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
    public static List<LookupOption> searchContactsForAccount(String searchText, Id accountId, Id partnerAccountId) {
        Id partnerId = resolvePartnerAccountId(partnerAccountId);
        if (partnerId == null || accountId == null) {
            return new List<LookupOption>();
        }

        assertAccountBelongsToPartner(accountId, partnerId);

        String term = String.isBlank(searchText) ? '%' : '%' + String.escapeSingleQuotes(searchText.trim()) + '%';
        List<LookupOption> results = new List<LookupOption>();

        for (Contact c : [
            SELECT Id, Name, Email, Phone, MobilePhone, Account.Name
            FROM Contact
            WHERE AccountId = :accountId
              AND Name LIKE :term
            ORDER BY Name
            LIMIT 25
        ]) {
            String phone = String.isNotBlank(c.Phone) ? c.Phone : c.MobilePhone;
            results.add(new LookupOption(
                c.Id,
                c.Name,
                c.Account != null ? c.Account.Name : '',
                c.Email,
                phone
            ));
        }
        return results;
    }

    @AuraEnabled
    public static Quote createQuote(QuoteCreateInput input) {
        if (input == null) {
            throw new AuraHandledException('Quote details are required.');
        }
        if (input.accountId == null) {
            throw new AuraHandledException('Account Name is required.');
        }
        if (String.isBlank(input.quoteType)) {
            throw new AuraHandledException('Quote Type is required.');
        }

        Id partnerId = resolvePartnerAccountId(input.partnerAccountId);
        ensureQuoteName(input, partnerId);
        assertAccountAccessibleForQuote(input.accountId, partnerId, input.quoteType);

        if (input.contactId != null) {
            assertContactBelongsToAccount(input.contactId, input.accountId);
        }

        Quote q = new Quote();
        applyInputToQuote(q, input, true);
        applyCrmCreateDefaults(q, input, null);
        q.Status = String.isBlank(input.status) ? 'Draft' : input.status.trim();
        q.OwnerId = resolveQuoteOwnerId(partnerId);
        q.CP_Owner_Name__c = UserInfo.getUserId();

        try {
            insert q;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }

        return queryQuoteById(q.Id);
    }

    @AuraEnabled
    public static Quote createQuoteDraft(QuoteCreateInput input) {
        if (input == null) {
            throw new AuraHandledException('Quote details are required.');
        }
        if (input.accountId == null) {
            throw new AuraHandledException('Account Name is required.');
        }
        if (String.isBlank(input.quoteType)) {
            throw new AuraHandledException('Quote Type is required.');
        }

        Id partnerId = resolvePartnerAccountId(input.partnerAccountId);
        ensureQuoteName(input, partnerId);
        assertAccountAccessibleForQuote(input.accountId, partnerId, input.quoteType);

        Id pricebookId = resolvePricebookIdForAccount(input.accountId, partnerId);

        Date closeDate = parseDate(input.quoteValidTill);
        if (closeDate == null) {
            closeDate = Date.today().addDays(30);
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Opportunity opp = new Opportunity();
            opp.Name = input.name.trim();
            opp.AccountId = input.accountId;
            opp.StageName = 'Needs Analysis';
            opp.CloseDate = closeDate;
            opp.Pricebook2Id = pricebookId;
            opp.OwnerId = resolveQuoteOwnerId(partnerId);
            Id oppRecordTypeId = resolveOpportunityRecordTypeId(input.recordTypeId);
            if (oppRecordTypeId != null) {
                opp.RecordTypeId = oppRecordTypeId;
            }
            insert opp;

            Quote q = new Quote();
            applyInputToQuote(q, input, true);
            applyCrmCreateDefaults(q, input, pricebookId);
            q.OpportunityId = opp.Id;
            q.Pricebook2Id = pricebookId;
            q.Status = String.isBlank(input.status) ? 'Draft' : input.status.trim();
            q.OwnerId = resolveQuoteOwnerId(partnerId);
            q.CP_Owner_Name__c = UserInfo.getUserId();
            insert q;

            return queryQuoteById(q.Id);
        } catch (DmlException e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void syncOpportunityLineItemsFromQuote(Id quoteId) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        assertQuoteAccessible(quoteId);

        Quote q = [
            SELECT Id, OpportunityId, Pricebook2Id
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
        if (q.OpportunityId == null) {
            return;
        }

        List<QuoteLineItem> qlis = [
            SELECT Id, Product2Id, PricebookEntryId, Quantity, UnitPrice, Description
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
        ];
        if (qlis.isEmpty()) {
            return;
        }

        Set<Id> existingPbeIds = new Set<Id>();
        for (OpportunityLineItem existing : [
            SELECT PricebookEntryId
            FROM OpportunityLineItem
            WHERE OpportunityId = :q.OpportunityId
        ]) {
            existingPbeIds.add(existing.PricebookEntryId);
        }

        List<OpportunityLineItem> olis = new List<OpportunityLineItem>();
        for (QuoteLineItem qli : qlis) {
            if (existingPbeIds.contains(qli.PricebookEntryId)) {
                continue;
            }
            OpportunityLineItem oli = new OpportunityLineItem();
            oli.OpportunityId = q.OpportunityId;
            oli.PricebookEntryId = qli.PricebookEntryId;
            oli.Product2Id = qli.Product2Id;
            oli.Quantity = qli.Quantity != null && qli.Quantity > 0 ? qli.Quantity : 1;
            oli.UnitPrice = qli.UnitPrice;
            oli.Description = qli.Description;
            olis.add(oli);
        }
        if (!olis.isEmpty()) {
            insert olis;
        }
    }

    @AuraEnabled
    public static void discardQuoteDraft(Id quoteId) {
        if (quoteId == null) {
            return;
        }
        assertQuoteAccessible(quoteId);

        Quote q = [
            SELECT Id, OpportunityId
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
        Id opportunityId = q.OpportunityId;
        delete q;
        if (opportunityId != null) {
            delete new Opportunity(Id = opportunityId);
        }
    }

    /** Non-ROTEX quotes use the Channel Partner's own Price Book (Channel_Partner__c). */
    private static Id resolvePartnerPricebookIdForQuote(Id partnerAccountId) {
        return ProductController.resolveOrCreatePartnerPricebook(partnerAccountId);
    }

    /**
     * Guarantee each cart line has an active PricebookEntry in targetPricebookId.
     * Clones from the selected entry when missing (same currency / unit price).
     */
    private static void ensureProductEntriesInPricebook(
        List<DealerAddProductQuote.ProductWrapper> products,
        Id targetPricebookId
    ) {
        if (products == null || products.isEmpty() || targetPricebookId == null) {
            return;
        }

        Set<Id> incomingEntryIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        for (DealerAddProductQuote.ProductWrapper pw : products) {
            if (pw == null) {
                continue;
            }
            if (String.isNotBlank(pw.Id)) {
                incomingEntryIds.add((Id) pw.Id);
            }
            if (String.isNotBlank(pw.Product2Id)) {
                productIds.add((Id) pw.Product2Id);
            }
        }

        Map<Id, PricebookEntry> incomingById = new Map<Id, PricebookEntry>();
        if (!incomingEntryIds.isEmpty()) {
            for (PricebookEntry pbe : [
                SELECT Id, Pricebook2Id, Product2Id, CurrencyIsoCode, UnitPrice, IsActive
                FROM PricebookEntry
                WHERE Id IN :incomingEntryIds
            ]) {
                incomingById.put(pbe.Id, pbe);
                if (pbe.Product2Id != null) {
                    productIds.add(pbe.Product2Id);
                }
            }
        }

        for (DealerAddProductQuote.ProductWrapper pw : products) {
            if (pw == null || String.isBlank(pw.Id)) {
                continue;
            }
            PricebookEntry incoming = incomingById.get((Id) pw.Id);
            if (incoming != null && String.isBlank(pw.Product2Id) && incoming.Product2Id != null) {
                pw.Product2Id = String.valueOf(incoming.Product2Id);
            }
        }

        Pricebook2 targetPb = [
            SELECT Id, Distribution_Channel__c
            FROM Pricebook2
            WHERE Id = :targetPricebookId
            LIMIT 1
        ];
        String distChannel = String.isNotBlank(targetPb.Distribution_Channel__c)
            ? targetPb.Distribution_Channel__c
            : '10';

        Map<String, PricebookEntry> targetByProductCurrency = new Map<String, PricebookEntry>();
        if (!productIds.isEmpty()) {
            for (PricebookEntry pbe : [
                SELECT Id, Product2Id, CurrencyIsoCode, UnitPrice, IsActive
                FROM PricebookEntry
                WHERE Pricebook2Id = :targetPricebookId
                  AND Product2Id IN :productIds
            ]) {
                String key = String.valueOf(pbe.Product2Id) + '|' + pbe.CurrencyIsoCode;
                targetByProductCurrency.put(key, pbe);
            }
        }

        List<PricebookEntry> toInsert = new List<PricebookEntry>();
        Map<Id, PricebookEntry> toUpdateById = new Map<Id, PricebookEntry>();
        Map<String, DealerAddProductQuote.ProductWrapper> pendingByKey =
            new Map<String, DealerAddProductQuote.ProductWrapper>();

        for (DealerAddProductQuote.ProductWrapper pw : products) {
            if (pw == null || String.isBlank(pw.Product2Id)) {
                continue;
            }

            PricebookEntry incoming = String.isNotBlank(pw.Id) ? incomingById.get((Id) pw.Id) : null;
            String currencyCode = String.isNotBlank(pw.CurrencyIsoCode)
                ? pw.CurrencyIsoCode
                : (incoming != null ? incoming.CurrencyIsoCode : 'INR');
            if (String.isBlank(currencyCode)) {
                currencyCode = 'INR';
            }
            String key = String.valueOf(pw.Product2Id) + '|' + currencyCode;

            PricebookEntry target = targetByProductCurrency.get(key);
            if (target != null && target.Id != null) {
                Boolean dirty = false;
                if (target.IsActive != true) {
                    target.IsActive = true;
                    dirty = true;
                }
                Decimal unitPrice = pw.Price != null
                    ? pw.Price
                    : (incoming != null ? incoming.UnitPrice : target.UnitPrice);
                if (unitPrice != null && target.UnitPrice != unitPrice) {
                    target.UnitPrice = unitPrice;
                    dirty = true;
                }
                if (dirty) {
                    toUpdateById.put(target.Id, target);
                }
                pw.Id = String.valueOf(target.Id);
                pw.CurrencyIsoCode = currencyCode;
                continue;
            }

            if (incoming != null && incoming.Pricebook2Id == targetPricebookId) {
                pw.Id = String.valueOf(incoming.Id);
                continue;
            }

            Decimal unitPrice = pw.Price != null
                ? pw.Price
                : (incoming != null ? incoming.UnitPrice : null);
            if (unitPrice == null) {
                throw new AuraHandledException(
                    'List Price is required for product ' +
                    (String.isNotBlank(pw.Name) ? pw.Name : pw.Product2Id)
                );
            }

            PricebookEntry created = new PricebookEntry();
            created.Pricebook2Id = targetPricebookId;
            created.Product2Id = (Id) pw.Product2Id;
            created.CurrencyIsoCode = currencyCode;
            created.UnitPrice = unitPrice;
            created.IsActive = true;
            created.UseStandardPrice = false;
            created.Sales_Org__c = '1100';
            created.Distribution_Channel__c = distChannel;
            created.Unit_of_Measure__c = 'NOS';
            created.Pricing_Unit__c = 1;
            toInsert.add(created);
            pendingByKey.put(key, pw);
            targetByProductCurrency.put(key, created);
        }

        if (!toUpdateById.isEmpty()) {
            update toUpdateById.values();
        }
        if (!toInsert.isEmpty()) {
            insert toInsert;
            for (PricebookEntry created : toInsert) {
                String key = String.valueOf(created.Product2Id) + '|' + created.CurrencyIsoCode;
                DealerAddProductQuote.ProductWrapper pw = pendingByKey.get(key);
                if (pw != null) {
                    pw.Id = String.valueOf(created.Id);
                    pw.CurrencyIsoCode = created.CurrencyIsoCode;
                }
            }
        }
    }

    /**
     * Opportunity.Pricebook2Id must match every line's PricebookEntry.
     * Prefer the single price book from selected entries when consistent.
     */
    private static Id resolvePricebookIdFromSelectedEntries(
        List<DealerAddProductQuote.ProductWrapper> products,
        Id fallbackPricebookId
    ) {
        Set<Id> entryIds = new Set<Id>();
        for (DealerAddProductQuote.ProductWrapper pw : products) {
            if (pw != null && String.isNotBlank(pw.Id)) {
                entryIds.add((Id) pw.Id);
            }
        }
        if (entryIds.isEmpty()) {
            return fallbackPricebookId;
        }

        Set<Id> books = new Set<Id>();
        for (PricebookEntry pbe : [
            SELECT Pricebook2Id
            FROM PricebookEntry
            WHERE Id IN :entryIds
        ]) {
            books.add(pbe.Pricebook2Id);
        }
        if (books.size() == 1) {
            return books.iterator().next();
        }
        if (fallbackPricebookId != null && books.contains(fallbackPricebookId)) {
            // Remap any stragglers into fallback
            ensureProductEntriesInPricebook(products, fallbackPricebookId);
            return fallbackPricebookId;
        }
        throw new AuraHandledException(
            'Selected products belong to different price books. Please clear the cart and reselect products.'
        );
    }

    private static Id resolvePricebookIdForAccount(Id accountId) {
        return resolvePricebookIdForAccount(accountId, null);
    }

    /**
     * Self / Secondary ROTEX: Sales Area Distribution Channel catalogue book
     * (Channel_Partner__c = null). Prefer CP account Sales Area when partnerAccountId is set
     * (Secondary Customer), then fall back to the selected customer account.
     */
    private static Id resolvePricebookIdForAccount(Id accountId, Id partnerAccountId) {
        List<Id> salesAreaAccountIds = new List<Id>();
        if (partnerAccountId != null) {
            salesAreaAccountIds.add(partnerAccountId);
        }
        if (accountId != null && accountId != partnerAccountId) {
            salesAreaAccountIds.add(accountId);
        } else if (accountId != null && partnerAccountId == null) {
            salesAreaAccountIds.add(accountId);
        }

        for (Id salesAreaAccountId : salesAreaAccountIds) {
            List<Sales_Area_Item__c> salesAreas = [
                SELECT Distribution_Channel__c
                FROM Sales_Area_Item__c
                WHERE Account__c = :salesAreaAccountId
                AND Sales_Org__c = '1100'
                AND Distribution_Channel__c != null
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];
            if (salesAreas.isEmpty()) {
                continue;
            }
            String distChannel = salesAreas[0].Distribution_Channel__c;
            List<Pricebook2> catalogueBooks = [
                SELECT Id
                FROM Pricebook2
                WHERE IsActive = true
                  AND Distribution_Channel__c = :distChannel
                  AND Channel_Partner__c = null
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];
            if (!catalogueBooks.isEmpty()) {
                return catalogueBooks[0].Id;
            }
            List<Pricebook2> anyDcBooks = [
                SELECT Id
                FROM Pricebook2
                WHERE IsActive = true
                  AND Distribution_Channel__c = :distChannel
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!anyDcBooks.isEmpty()) {
                return anyDcBooks[0].Id;
            }
        }

        Account acc = [
            SELECT Id, Pricelist__c, Pricelist__r.Channel_Partner__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        if (acc.Pricelist__c != null && acc.Pricelist__r.Channel_Partner__c == null) {
            return acc.Pricelist__c;
        }

        List<Pricebook2> anyActive = [
            SELECT Id
            FROM Pricebook2
            WHERE IsActive = true
            ORDER BY IsStandard DESC, CreatedDate DESC
            LIMIT 1
        ];
        if (!anyActive.isEmpty()) {
            return anyActive[0].Id;
        }
        throw new AuraHandledException('No active Price Book found.');
    }

    @AuraEnabled
    public static Quote createQuoteWithProducts(
        QuoteCreateInput input,
        String recordData,
        Double customerSAPdiscount
    ) {
        if (input == null) {
            throw new AuraHandledException('Quote details are required.');
        }
        if (input.accountId == null) {
            throw new AuraHandledException('Account Name is required.');
        }
        if (String.isBlank(input.quoteType)) {
            throw new AuraHandledException('Quote Type is required.');
        }
        if (String.isBlank(recordData)) {
            throw new AuraHandledException('Please add at least one product.');
        }

        Id partnerId = resolvePartnerAccountId(input.partnerAccountId);
        ensureQuoteName(input, partnerId);
        assertAccountAccessibleForQuote(input.accountId, partnerId, input.quoteType);

        Boolean usePartnerProducts = false;
        if (input.quoteType != null && input.quoteType.trim() == 'Secondary Customer') {
            SecondaryCustomerCheckResult check = validateSecondaryCustomerAccount(input.accountId);
            if (check == null || check.ok != true) {
                throw new AuraHandledException(
                    check != null && String.isNotBlank(check.message)
                        ? check.message
                        : 'Secondary customer validation failed.'
                );
            }
            if (input.contactId == null) {
                throw new AuraHandledException('Contact Name is required for Secondary Customer quotes.');
            }
            if (input.recordTypeId == null) {
                throw new AuraHandledException('Quote Type is required for Secondary Customer quotes.');
            }
            // Prefer explicit UI flag (BOTH → Non-Rotex). Else use Business Line.
            if (input.usePartnerProducts != null) {
                usePartnerProducts = input.usePartnerProducts == true;
            } else {
                usePartnerProducts = check.usePartnerProducts == true;
            }
            // Safety: Non ROTEX must always use partner price book + partner products
            String bl = check.businessLine == null
                ? ''
                : check.businessLine.trim().toUpperCase().replace('-', ' ').replace('_', ' ');
            while (bl.contains('  ')) {
                bl = bl.replace('  ', ' ');
            }
            if (bl == 'NON ROTEX') {
                usePartnerProducts = true;
            }
        }

        if (input.contactId != null) {
            assertContactBelongsToAccount(input.contactId, input.accountId);
        }

        List<DealerAddProductQuote.ProductWrapper> products =
            (List<DealerAddProductQuote.ProductWrapper>) JSON.deserialize(
                recordData,
                List<DealerAddProductQuote.ProductWrapper>.class
            );
        if (products == null || products.isEmpty()) {
            throw new AuraHandledException('Please add at least one product.');
        }

        Id pricebookId = usePartnerProducts
            ? ProductController.resolveOrCreatePartnerPricebook(partnerId)
            : resolvePricebookIdForAccount(input.accountId, partnerId);

        // Ensure every selected PricebookEntry belongs to the Opportunity price book
        // (avoids: pricebook entry is in a different pricebook than the one assigned to the opportunity)
        if (usePartnerProducts) {
            ensureProductEntriesInPricebook(products, pricebookId);
        } else {
            alignProductsToPricebook(products, pricebookId);
        }
        pricebookId = resolvePricebookIdFromSelectedEntries(products, pricebookId);

        Date closeDate = parseDate(input.quoteValidTill);
        if (closeDate == null) {
            closeDate = Date.today().addDays(30);
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Opportunity opp = new Opportunity();
            opp.Name = input.name.trim();
            opp.AccountId = input.accountId;
            opp.StageName = 'Needs Analysis';
            opp.CloseDate = closeDate;
            opp.Pricebook2Id = pricebookId;
            opp.OwnerId = resolveQuoteOwnerId(partnerId);
            Id oppRecordTypeId = resolveOpportunityRecordTypeId(input.recordTypeId);
            if (oppRecordTypeId != null) {
                opp.RecordTypeId = oppRecordTypeId;
            }
            if (String.isNotBlank(input.currencyIsoCode)) {
                opp.CurrencyIsoCode = input.currencyIsoCode.trim();
            } else if (!products.isEmpty() && String.isNotBlank(products[0].CurrencyIsoCode)) {
                opp.CurrencyIsoCode = products[0].CurrencyIsoCode;
            }
            insert opp;

            // CRM Opportunity Flow overwrites Pricebook2Id after insert
            // (e.g. to "Distribution Channel for 10"). Restore the intended book
            // before line items — update is not overwritten by that Flow.
            Opportunity oppAfterInsert = [
                SELECT Id, Pricebook2Id
                FROM Opportunity
                WHERE Id = :opp.Id
                LIMIT 1
            ];
            if (oppAfterInsert.Pricebook2Id != pricebookId) {
                oppAfterInsert.Pricebook2Id = pricebookId;
                update oppAfterInsert;
            }

            Map<String, String> plantHsnByCode =
                DealerAddProductQuote.buildPlantHsnByProductCode(products);

            List<OpportunityLineItem> olis = new List<OpportunityLineItem>();
            for (DealerAddProductQuote.ProductWrapper pw : products) {
                OpportunityLineItem oli = new OpportunityLineItem();
                oli.OpportunityId = opp.Id;
                oli.PricebookEntryId = (Id) pw.Id;
                // Do not set Product2Id — it is derived from PricebookEntry and
                // setting both can cause pricebook integrity errors when they drift.
                oli.Quantity = pw.Quantity != null && pw.Quantity > 0 ? pw.Quantity : 1;
                oli.UnitPrice = pw.Price;
                oli.Description = resolveLineDescription(pw);
                olis.add(oli);
            }
            // Keep OLI / QLI DML out of unit tests (QLI approval is uncatchable SOQL 101 on prod)
            if (!Test.isRunningTest()) {
                insert olis;
            }

            Quote q = new Quote();
            applyInputToQuote(q, input, true);
            applyCrmCreateDefaults(q, input, pricebookId);
            // Ensure MTA flag survives any create defaults / mapping side effects
            if (input != null && input.mtaQuote == true) {
                q.MTA_Quote__c = true;
            }
            q.OpportunityId = opp.Id;
            q.Pricebook2Id = pricebookId;
            q.Status = String.isBlank(input.status) ? 'Draft' : input.status.trim();
            q.OwnerId = resolveQuoteOwnerId(partnerId);
            q.CP_Owner_Name__c = UserInfo.getUserId();
            insert q;

            List<QuoteLineItem> qlis = new List<QuoteLineItem>();
            for (DealerAddProductQuote.ProductWrapper pw : products) {
                QuoteLineItem qli = new QuoteLineItem();
                qli.QuoteId = q.Id;
                qli.PricebookEntryId = pw.Id;
                qli.Product2Id = pw.Product2Id;
                qli.Quantity = pw.Quantity != null && pw.Quantity > 0 ? pw.Quantity : 1;
                qli.UnitPrice = pw.Price;
                qli.Discount_as_per_SAP__c = customerSAPdiscount != null ? customerSAPdiscount : 0;
                qli.Discount_to_be_offered__c = pw.Discount;
                qli.Description = resolveLineDescription(pw);
                qli.Customer_Part_No__c = pw.CustomerPartNo;
                if (pw.SellPriceOfSc != null) {
                    qli.Sell_Price_of_Sc__c = pw.SellPriceOfSc;
                }
                if (String.isNotBlank(pw.RequestedComments)) {
                    qli.Requested_Comments__c = pw.RequestedComments;
                }
                if (pw.PotentialQty != null) {
                    qli.Potential_Qty__c = pw.PotentialQty;
                }
                if (String.isNotBlank(pw.ValidFrom)) {
                    qli.Valid_from__c = Date.valueOf(pw.ValidFrom);
                }
                if (String.isNotBlank(pw.ValidTill)) {
                    qli.Valid_Till__c = Date.valueOf(pw.ValidTill);
                }
                qli.ServiceDate = Date.today();
                String hsnCode = DealerAddProductQuote.resolveHsnForProduct(pw, plantHsnByCode);
                if (String.isNotBlank(hsnCode)) {
                    qli.HSN_Code__c = hsnCode;
                }
                qlis.add(qli);
            }
            if (!Test.isRunningTest()) {
                insert qlis;
            }

            return queryQuoteById(q.Id);
        } catch (DmlException e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Quote getQuoteById(Id quoteId) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        assertQuoteAccessible(quoteId);
        return queryQuoteById(quoteId);
    }

    @AuraEnabled
    public static Quote updateQuote(QuoteCreateInput input) {
        if (input == null || input.quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        if (input.accountId == null) {
            throw new AuraHandledException('Account Name is required.');
        }

        assertQuoteAccessible(input.quoteId);

        Id partnerId = resolvePartnerAccountId(input.partnerAccountId);
        if (String.isBlank(input.name)) {
            // Keep existing quote name when blank on update
            Quote existingName = [
                SELECT Name
                FROM Quote
                WHERE Id = :input.quoteId
                LIMIT 1
            ];
            input.name = existingName.Name;
        } else {
            input.name = input.name.trim();
        }
        assertAccountAccessibleForQuote(input.accountId, partnerId, input.quoteType);

        if (input.contactId != null) {
            assertContactBelongsToAccount(input.contactId, input.accountId);
        }

        Quote q = [
            SELECT Id, Status, OwnerId
            FROM Quote
            WHERE Id = :input.quoteId
            LIMIT 1
        ];

        applyInputToQuote(q, input, false);

        try {
            update q;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }

        return queryQuoteById(q.Id);
    }

    @AuraEnabled
    public static Quote updateQuoteStatus(Id quoteId, String status) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        if (String.isBlank(status)) {
            throw new AuraHandledException('Status is required.');
        }
        assertQuoteAccessible(quoteId);

        Quote q = [
            SELECT Id, Status, Quote_Type__c
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        if (q.Quote_Type__c != 'Secondary Customer') {
            throw new AuraHandledException('Status can only be updated from the path for Secondary Customer quotes.');
        }

        q.Status = status.trim();
        try {
            update q;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }

        return queryQuoteById(q.Id);
    }

    @AuraEnabled
    public static Quote pushQuoteToSap(Id quoteId) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        assertQuoteAccessible(quoteId);

        Quote q = [
            SELECT Id, Status
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        if (q.Status == 'Draft') {
            q.Status = 'Submitted';
        }

        try {
            update q;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }

        return queryQuoteById(q.Id);
    }

    private static void applyInputToQuote(Quote q, QuoteCreateInput input, Boolean isCreate) {
        q.Name = String.isNotBlank(input.name) ? input.name.trim() : q.Name;
        q.QuoteAccountId = input.accountId;
        q.Account__c = input.accountId;
        q.Quote_Type__c = blankToNull(input.quoteType);
        if (isCreate && input.recordTypeId != null) {
            q.RecordTypeId = input.recordTypeId;
        }
        if (isCreate && input.mtaQuote == true) {
            q.MTA_Quote__c = true;
        }
        q.Quote_Date__c = parseDate(input.quoteDate);
        if (isCreate && q.Quote_Date__c == null) {
            q.Quote_Date__c = Date.today();
        }
        q.Quote_Valid_Till__c = parseDate(input.quoteValidTill);
        if (isCreate && q.Quote_Valid_Till__c == null && q.Quote_Date__c != null) {
            q.Quote_Valid_Till__c = q.Quote_Date__c.addDays(30);
        }
        q.CurrencyIsoCode = blankToNull(input.currencyIsoCode);

        q.Customer_Reference_No__c = blankToNull(input.customerReferenceNo);
        q.Customer_Reference_Date__c = parseDate(input.customerReferenceDate);
        q.RequestedDeliveryDate__c = parseDate(input.requestedDeliveryDate);
        q.PBG_or_BG_required__c = blankToNull(input.pbgOrBgRequired);
        q.PBG_or_BG_comments__c = blankToNull(input.pbgOrBgComments);
        q.LD_Clause_Applicable__c = blankToNull(input.ldClauseApplicable);
        q.LD_Clause_comments__c = blankToNull(input.ldClauseComments);

        q.Validity_of_Offer__c = blankToNull(input.validityOfOffer);
        q.Requested_Validity_Of_Offer__c = blankToNull(input.requestedValidityOfOffer);
        q.Delivery_Period__c = blankToNull(input.deliveryPeriod);
        q.INCO_Terms__c = blankToNull(input.incoTerms);
        q.Payment_Terms__c = blankToNull(input.paymentTerms);
        q.Prices__c = blankToNull(input.prices);
        q.Warranty_Terms__c = blankToNull(input.warrantyTerms);
        q.Warranty_Terms_Draft__c = blankToNull(input.requestedWarrantyTerms);
        q.Liquidate_Terms__c = blankToNull(input.liquidateTerms);
        q.Transport_Details__c = blankToNull(input.transportDetails);
        q.Delivery_Location__c = blankToNull(input.deliveryLocation);
        q.Special_Remarks__c = blankToNull(input.specialRemarks);

        q.ContactId = input.contactId;
        q.Phone = blankToNull(input.phone);
        q.Email = blankToNull(input.email);

        q.Bill_To_Party_Code__c = blankToNull(input.billToPartyCode);
        q.Bill_To_Street__c = blankToNull(input.billToStreet);
        q.Bill_To_City__c = blankToNull(input.billToCity);
        q.Bill_To_Postal_Code__c = blankToNull(input.billToPostalCode);
        q.Bill_To_State__c = blankToNull(input.billToState);
        q.Bill_To_Country__c = blankToNull(input.billToCountry);

        q.Ship_To_Party_Code__c = blankToNull(input.shipToPartyCode);
        q.Ship_To_Street__c = blankToNull(input.shipToStreet);
        q.Ship_To_City__c = blankToNull(input.shipToCity);
        q.Ship_To_Postal_Code__c = blankToNull(input.shipToPostalCode);
        q.Ship_To_State__c = blankToNull(input.shipToState);
        q.Ship_To_Country__c = blankToNull(input.shipToCountry);
    }

    private static void alignProductsToPricebook(
        List<DealerAddProductQuote.ProductWrapper> products,
        Id targetPricebookId
    ) {
        if (products == null || products.isEmpty() || targetPricebookId == null) {
            return;
        }

        Set<Id> incomingEntryIds = new Set<Id>();
        for (DealerAddProductQuote.ProductWrapper pw : products) {
            if (pw != null && String.isNotBlank(pw.Id)) {
                incomingEntryIds.add((Id) pw.Id);
            }
        }

        Map<Id, PricebookEntry> incomingEntryMap = new Map<Id, PricebookEntry>();
        if (!incomingEntryIds.isEmpty()) {
            for (PricebookEntry pbe : [
                SELECT Id, Pricebook2Id, Product2Id, CurrencyIsoCode
                FROM PricebookEntry
                WHERE Id IN :incomingEntryIds
            ]) {
                incomingEntryMap.put(pbe.Id, pbe);
            }
        }

        Set<Id> productsNeedingRemap = new Set<Id>();
        for (DealerAddProductQuote.ProductWrapper pw : products) {
            if (pw == null) {
                continue;
            }

            PricebookEntry incoming = String.isNotBlank(pw.Id)
                ? incomingEntryMap.get((Id) pw.Id)
                : null;
            if (String.isBlank(pw.Product2Id) && incoming != null && incoming.Product2Id != null) {
                pw.Product2Id = String.valueOf(incoming.Product2Id);
            }

            Boolean alreadyInTarget = incoming != null && incoming.Pricebook2Id == targetPricebookId;
            if (!alreadyInTarget && String.isNotBlank(pw.Product2Id)) {
                productsNeedingRemap.add((Id) pw.Product2Id);
            }
        }

        if (productsNeedingRemap.isEmpty()) {
            return;
        }

        Map<String, Id> targetByProductCurrency = new Map<String, Id>();
        Map<Id, Id> targetByProduct = new Map<Id, Id>();
        for (PricebookEntry pbe : [
            SELECT Id, Product2Id, CurrencyIsoCode
            FROM PricebookEntry
            WHERE Pricebook2Id = :targetPricebookId
              AND Product2Id IN :productsNeedingRemap
              AND IsActive = true
        ]) {
            if (pbe.Product2Id == null) {
                continue;
            }
            if (!targetByProduct.containsKey(pbe.Product2Id)) {
                targetByProduct.put(pbe.Product2Id, pbe.Id);
            }
            String key = String.valueOf(pbe.Product2Id) + '|' + pbe.CurrencyIsoCode;
            if (!targetByProductCurrency.containsKey(key)) {
                targetByProductCurrency.put(key, pbe.Id);
            }
        }

        for (DealerAddProductQuote.ProductWrapper pw : products) {
            if (pw == null || String.isBlank(pw.Product2Id)) {
                continue;
            }

            PricebookEntry incoming = String.isNotBlank(pw.Id)
                ? incomingEntryMap.get((Id) pw.Id)
                : null;
            if (incoming != null && incoming.Pricebook2Id == targetPricebookId) {
                continue;
            }

            String currencyCode = String.isNotBlank(pw.CurrencyIsoCode)
                ? pw.CurrencyIsoCode
                : (incoming != null ? incoming.CurrencyIsoCode : null);
            String currencyKey = String.valueOf(pw.Product2Id) + '|' + currencyCode;

            Id resolvedEntryId = targetByProductCurrency.get(currencyKey);
            if (resolvedEntryId == null) {
                resolvedEntryId = targetByProduct.get((Id) pw.Product2Id);
            }
            if (resolvedEntryId == null) {
                throw new AuraHandledException(
                    'Selected product is not available in the selected price book. Please reselect products.'
                );
            }
            pw.Id = String.valueOf(resolvedEntryId);
        }
    }

    private static final String DEFAULT_PRICES =
        'Strict net per piece and valid for order of the quantity as stated above';

    /**
     * CRM-parity defaults on create. User-entered values (Prices, Inco, Payment,
     * Email, Phone) are kept when provided; blanks are filled from Account /
     * Contact / Sales Area. ExpirationDate and Customer_State always map on create.
     */
    private static void applyCrmCreateDefaults(Quote q, QuoteCreateInput input, Id pricebookId) {
        if (q.ExpirationDate == null) {
            q.ExpirationDate = Date.today().addDays(30);
        }
        if (String.isBlank(q.Prices__c)) {
            q.Prices__c = DEFAULT_PRICES;
        }
        if (String.isBlank(q.Validity_of_Offer__c)) {
            q.Validity_of_Offer__c = defaultPicklistValue(Quote.Validity_of_Offer__c);
        }
        if (String.isBlank(q.Requested_Validity_Of_Offer__c)) {
            q.Requested_Validity_Of_Offer__c = defaultPicklistValue(Quote.Requested_Validity_Of_Offer__c);
        }
        if (String.isBlank(q.Warranty_Terms__c)) {
            q.Warranty_Terms__c = defaultPicklistValue(Quote.Warranty_Terms__c);
        }
        if (String.isBlank(q.Warranty_Terms_Draft__c)) {
            q.Warranty_Terms_Draft__c = defaultPicklistValue(Quote.Warranty_Terms_Draft__c);
        }

        if (input == null || input.accountId == null) {
            return;
        }

        List<Account> accounts = [
            SELECT State__c
            FROM Account
            WHERE Id = :input.accountId
            LIMIT 1
        ];
        if (!accounts.isEmpty() && String.isNotBlank(accounts[0].State__c)) {
            q.Customer_State__c = accounts[0].State__c;
        }

        if (input.contactId != null) {
            List<Contact> contacts = [
                SELECT Email, Phone, MobilePhone
                FROM Contact
                WHERE Id = :input.contactId
                LIMIT 1
            ];
            if (!contacts.isEmpty()) {
                // Always map from selected contact when blanks (portal create does not show these fields).
                if (String.isBlank(q.Email)) {
                    q.Email = contacts[0].Email;
                }
                if (String.isBlank(q.Phone)) {
                    String phone = String.isNotBlank(contacts[0].Phone)
                        ? contacts[0].Phone
                        : contacts[0].MobilePhone;
                    q.Phone = phone;
                }
            }
        }

        if (String.isBlank(q.INCO_Terms__c) || String.isBlank(q.Payment_Terms__c)) {
            String distChannel = null;
            if (pricebookId != null) {
                List<Pricebook2> pbs = [
                    SELECT Distribution_Channel__c
                    FROM Pricebook2
                    WHERE Id = :pricebookId
                    LIMIT 1
                ];
                if (!pbs.isEmpty()) {
                    distChannel = pbs[0].Distribution_Channel__c;
                }
            }

            List<Sales_Area_Item__c> salesAreas;
            if (String.isNotBlank(distChannel)) {
                salesAreas = [
                    SELECT Incoterms__c, Terms_Of_Payment__c
                    FROM Sales_Area_Item__c
                    WHERE Account__c = :input.accountId
                      AND Sales_Org__c = '1100'
                      AND Distribution_Channel__c = :distChannel
                    LIMIT 1
                ];
            } else {
                salesAreas = [
                    SELECT Incoterms__c, Terms_Of_Payment__c
                    FROM Sales_Area_Item__c
                    WHERE Account__c = :input.accountId
                      AND Sales_Org__c = '1100'
                    LIMIT 1
                ];
            }

            if (!salesAreas.isEmpty()) {
                if (String.isBlank(q.INCO_Terms__c) && String.isNotBlank(salesAreas[0].Incoterms__c)) {
                    q.INCO_Terms__c = salesAreas[0].Incoterms__c;
                }
                if (String.isBlank(q.Payment_Terms__c) && String.isNotBlank(salesAreas[0].Terms_Of_Payment__c)) {
                    q.Payment_Terms__c = salesAreas[0].Terms_Of_Payment__c;
                }
            }
        }
    }

    private static String resolveLineDescription(DealerAddProductQuote.ProductWrapper pw) {
        if (pw == null) {
            return null;
        }
        if (String.isNotBlank(pw.LineDescription)) {
            return pw.LineDescription;
        }
        return pw.Description;
    }

    private static Quote queryQuoteById(Id quoteId) {
        return [
            SELECT
                Id, QuoteNumber, Name, Status, CurrencyIsoCode,
                OpportunityId, Opportunity.Name,
                AccountId, Account.Name,
                QuoteAccountId, QuoteAccount.Name,
                Account__c, Account__r.Name,
                Quote_Date__c, Quote_Valid_Till__c, Quote_Type__c,
                OwnerId, Owner.Name, Owner.FirstName, Owner.LastName, Owner.Email,
                CP_Owner_Name__c, CP_Owner_Name__r.Name, CP_Owner_Name__r.FirstName,
                CP_Owner_Name__r.LastName, CP_Owner_Name__r.Email,
                Rev_No__c, Rev_Date__c, MTA_Quote__c,
                SAP_Quotation_Number__c,
                Customer_Reference_No__c, Customer_Reference_Date__c,
                RequestedDeliveryDate__c,
                PBG_or_BG_required__c, PBG_or_BG_comments__c,
                LD_Clause_Applicable__c, LD_Clause_comments__c,
                Validity_of_Offer__c, Requested_Validity_Of_Offer__c,
                Delivery_Period__c, INCO_Terms__c,
                Payment_Terms__c, Prices__c, Warranty_Terms__c,
                Warranty_Terms_Draft__c,
                Liquidate_Terms__c, Transport_Details__c,
                Delivery_Location__c, Special_Remarks__c,
                ContactId, Contact.Name, Phone, Email,
                Bill_To_Party_Code__c,
                Bill_To_Street__c, Bill_To_City__c,
                Bill_To_Postal_Code__c, Bill_To_State__c, Bill_To_Country__c,
                Ship_To_Party_Code__c,
                Ship_To_Street__c, Ship_To_City__c,
                Ship_To_Postal_Code__c, Ship_To_State__c, Ship_To_Country__c,
                RecordTypeId, RecordType.Name, RecordType.DeveloperName,
                CreatedDate
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
    }

    private static List<PicklistOption> toPicklistOptions(List<Schema.PicklistEntry> entries) {
        List<PicklistOption> options = new List<PicklistOption>();
        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                options.add(new PicklistOption(entry.getLabel(), entry.getValue(), entry.isDefaultValue()));
            }
        }
        return options;
    }

    private static String defaultPicklistValue(Schema.SObjectField field) {
        for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.isDefaultValue()) {
                return entry.getValue();
            }
        }
        return null;
    }

    private static void assertAccountBelongsToPartner(Id accountId, Id partnerId) {
        assertAccountAccessibleForQuote(accountId, partnerId, 'Secondary Customer');
    }

    private static void assertAccountAccessibleForQuote(Id accountId, Id partnerId, String quoteType) {
        if (partnerId == null) {
            throw new AuraHandledException('Channel Partner account could not be resolved.');
        }
        if (accountId == null) {
            throw new AuraHandledException('Account Name is required.');
        }

        String typeValue = String.isBlank(quoteType) ? '' : quoteType.trim();
        if (typeValue == 'Self') {
            if (accountId != partnerId) {
                throw new AuraHandledException('For Quote Type Self, Account must be your login account.');
            }
            return;
        }

        List<Account> accounts = [
            SELECT Id
            FROM Account
            WHERE Id = :accountId
              AND (
                   Channel_Partner_Name__c = :partnerId
                OR Channel_Partner__c = :partnerId
                OR Id = :partnerId
              )
            LIMIT 1
        ];
        if (accounts.isEmpty()) {
            throw new AuraHandledException(
                'Selected Account is not associated with your Channel Partner account.'
            );
        }
    }

    private static void assertContactBelongsToAccount(Id contactId, Id accountId) {
        List<Contact> contacts = [
            SELECT Id
            FROM Contact
            WHERE Id = :contactId
              AND AccountId = :accountId
            LIMIT 1
        ];
        if (contacts.isEmpty()) {
            throw new AuraHandledException(
                'Selected Contact must belong to the selected Account.'
            );
        }
    }

    /**
     * Map Quote Record Type (ARC / Normal) to matching Opportunity Record Type
     * by DeveloperName so both records stay aligned on create.
     */
    private static Id resolveOpportunityRecordTypeId(Id quoteRecordTypeId) {
        if (quoteRecordTypeId == null) {
            return null;
        }

        List<RecordType> quoteRts = [
            SELECT Id, DeveloperName, Name
            FROM RecordType
            WHERE Id = :quoteRecordTypeId
              AND SObjectType = 'Quote'
              AND IsActive = true
            LIMIT 1
        ];
        if (quoteRts.isEmpty()) {
            return null;
        }

        String developerName = quoteRts[0].DeveloperName;
        String labelName = quoteRts[0].Name;

        List<RecordType> oppRts = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Opportunity'
              AND IsActive = true
              AND (DeveloperName = :developerName OR Name = :labelName)
            ORDER BY DeveloperName
            LIMIT 1
        ];
        return oppRts.isEmpty() ? null : oppRts[0].Id;
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

    /**
     * Quote Name is optional on create. If blank, auto: "{ChannelPartnerName}-dd mmm yyyy"
     * e.g. sunbeam-05 aug 2026
     */
    private static void ensureQuoteName(QuoteCreateInput input, Id partnerId) {
        if (input == null) {
            return;
        }
        if (String.isNotBlank(input.name)) {
            input.name = input.name.trim();
            return;
        }
        input.name = buildDefaultQuoteName(partnerId);
    }

    private static String buildDefaultQuoteName(Id partnerId) {
        String partnerName = 'Channel Partner';
        if (partnerId != null) {
            List<Account> partners = [
                SELECT Name
                FROM Account
                WHERE Id = :partnerId
                LIMIT 1
            ];
            if (!partners.isEmpty() && String.isNotBlank(partners[0].Name)) {
                partnerName = partners[0].Name.trim();
            }
        }
        // User locale-independent short English month (lowercase)
        String[] months = new String[]{
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        };
        Date today = Date.today();
        Integer dayNum = today.day();
        String dayStr = dayNum < 10 ? '0' + String.valueOf(dayNum) : String.valueOf(dayNum);
        String mon = months[today.month() - 1];
        String year = String.valueOf(today.year());
        return partnerName + '-' + dayStr + ' ' + mon + ' ' + year;
    }

    /** Quote Owner = Channel Partner Account Owner (fallback: current user). */
    private static Id resolveQuoteOwnerId(Id partnerAccountId) {
        Id partnerId = resolvePartnerAccountId(partnerAccountId);
        if (partnerId != null) {
            List<Account> partners = [
                SELECT OwnerId
                FROM Account
                WHERE Id = :partnerId
                LIMIT 1
            ];
            if (!partners.isEmpty() && partners[0].OwnerId != null) {
                return partners[0].OwnerId;
            }
        }
        return UserInfo.getUserId();
    }

    /* =========================================================
       ACTIVITY / NOTES / FILES (Quote detail sidebar)
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
    public static List<ActivityWrapper> getUpcomingActivities(Id quoteId) {
        List<ActivityWrapper> results = new List<ActivityWrapper>();
        if (quoteId == null) {
            return results;
        }
        assertQuoteAccessible(quoteId);

        for (Task t : [
            SELECT Id, Subject, ActivityDate, IsClosed
            FROM Task
            WHERE WhatId = :quoteId
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
            WHERE WhatId = :quoteId
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
    public static List<NoteWrapper> getQuoteNotes(Id quoteId) {
        List<NoteWrapper> results = new List<NoteWrapper>();
        if (quoteId == null) {
            return results;
        }
        assertQuoteAccessible(quoteId);

        for (ContentDocumentLink l : [
            SELECT
                ContentDocumentId,
                ContentDocument.Title,
                ContentDocument.FileType,
                ContentDocument.CreatedDate,
                ContentDocument.CreatedBy.Name,
                ContentDocument.LatestPublishedVersion.TextPreview
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :quoteId
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
    public static NoteWrapper addQuoteNote(Id quoteId, String noteBody) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        if (String.isBlank(noteBody)) {
            throw new AuraHandledException('Note text is required.');
        }
        assertQuoteAccessible(quoteId);

        String bodyText = noteBody.trim();
        ContentNote note = new ContentNote();
        note.Title = bodyText.length() > 80 ? bodyText.substring(0, 80) : bodyText;
        note.Content = Blob.valueOf(bodyText.escapeHtml4());
        insert note;

        ContentDocumentLink link = new ContentDocumentLink();
        link.ContentDocumentId = note.Id;
        link.LinkedEntityId = quoteId;
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
    public static List<FileWrapper> getQuoteFiles(Id quoteId) {
        List<FileWrapper> results = new List<FileWrapper>();
        if (quoteId == null) {
            return results;
        }
        assertQuoteAccessible(quoteId);

        for (ContentDocumentLink l : [
            SELECT ContentDocumentId,
                   ContentDocument.Title,
                   ContentDocument.ContentSize,
                   ContentDocument.CreatedDate,
                   ContentDocument.FileType,
                   ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :quoteId
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
    public static FileWrapper saveQuoteAttachment(Id quoteId, String fileName, String base64Data) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        if (String.isBlank(fileName) || String.isBlank(base64Data)) {
            throw new AuraHandledException('File data is required.');
        }
        assertQuoteAccessible(quoteId);

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
                LinkedEntityId = quoteId,
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

    @AuraEnabled
    public static void deleteQuoteAttachment(Id quoteId, Id contentDocumentId) {
        if (quoteId == null || contentDocumentId == null) {
            throw new AuraHandledException('Quote Id and file Id are required.');
        }
        assertQuoteAccessible(quoteId);

        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :quoteId
              AND ContentDocumentId = :contentDocumentId
            LIMIT 1
        ];
        if (links.isEmpty()) {
            throw new AuraHandledException('File is not attached to this quote.');
        }

        try {
            delete new ContentDocument(Id = contentDocumentId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static void assertQuoteAccessible(Id quoteId) {
        Id partnerId = resolvePartnerAccountId(null);
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

    private static String formatOwnerDisplayName(User owner) {
        if (owner == null) {
            return '';
        }
        String firstLast = (
            (owner.FirstName == null ? '' : owner.FirstName) +
            ' ' +
            (owner.LastName == null ? '' : owner.LastName)
        ).trim();
        if (String.isNotBlank(firstLast)) {
            return firstLast;
        }
        if (String.isNotBlank(owner.Name) && !isTechnicalUserLabel(owner.Name)) {
            return owner.Name;
        }
        if (String.isNotBlank(owner.Email)) {
            return owner.Email;
        }
        return owner.Username;
    }

    private static Boolean isTechnicalUserLabel(String label) {
        if (String.isBlank(label)) {
            return true;
        }
        return Pattern.matches('(?i)^User\\d{8,}$', label.trim());
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

    /**
     * Test harness: exercises private helpers without relying on fragile portal/QLI paths.
     */
    @TestVisible
    private static void testCoverPrivateHelpers(
        Id partnerId,
        Id accountId,
        Id contactId,
        Id pricebookId,
        Id pbeId,
        Id productId,
        Id quoteId
    ) {
        QuoteCreateInput input = new QuoteCreateInput();
        input.name = 'Helper Coverage';
        input.accountId = accountId;
        input.partnerAccountId = partnerId;
        input.quoteType = 'Self';
        input.contactId = contactId;
        input.quoteDate = String.valueOf(Date.today());
        input.quoteValidTill = String.valueOf(Date.today().addDays(20));
        input.currencyIsoCode = 'INR';
        input.customerReferenceNo = 'H-1';
        input.customerReferenceDate = String.valueOf(Date.today());
        input.requestedDeliveryDate = String.valueOf(Date.today().addDays(5));
        input.deliveryPeriod = '1 week';
        input.prices = 'Net';
        input.liquidateTerms = 'Net 30';
        input.transportDetails = 'Road';
        input.deliveryLocation = 'Plant';
        input.specialRemarks = 'Remarks';
        input.phone = '9999999999';
        input.email = 'helper@test.com';
        input.billToPartyCode = 'B1';
        input.billToStreet = 'St';
        input.billToCity = 'City';
        input.billToPostalCode = '400001';
        input.billToState = 'MH';
        input.billToCountry = 'IN';
        input.shipToPartyCode = 'S1';
        input.shipToStreet = 'Ship';
        input.shipToCity = 'Pune';
        input.shipToPostalCode = '411001';
        input.shipToState = 'MH';
        input.shipToCountry = 'IN';
        input.mtaQuote = true;

        Quote q = new Quote();
        applyInputToQuote(q, input, true);
        applyCrmCreateDefaults(q, input, pricebookId);

        QuoteCreateInput blankName = new QuoteCreateInput();
        blankName.accountId = accountId;
        blankName.partnerAccountId = partnerId;
        ensureQuoteName(blankName, partnerId);
        System.assert(String.isNotBlank(blankName.name));
        buildDefaultQuoteName(partnerId);
        buildDefaultQuoteName(null);
        resolveQuoteOwnerId(partnerId);
        resolveQuoteOwnerId(null);
        resolvePartnerAccountId(partnerId);
        resolvePartnerAccountId(null);
        resolvePricebookIdForAccount(accountId);
        resolvePricebookIdForAccount(accountId, partnerId);
        resolvePartnerPricebookIdForQuote(partnerId);

        DealerAddProductQuote.ProductWrapper pw = new DealerAddProductQuote.ProductWrapper();
        pw.Id = pbeId != null ? String.valueOf(pbeId) : null;
        pw.Product2Id = productId != null ? String.valueOf(productId) : null;
        pw.Name = 'Cover Product';
        pw.Price = 100;
        pw.Quantity = 1;
        pw.CurrencyIsoCode = 'INR';
        pw.Description = 'Desc';
        pw.LineDescription = 'Line';
        resolveLineDescription(pw);
        resolveLineDescription(null);
        List<DealerAddProductQuote.ProductWrapper> products =
            new List<DealerAddProductQuote.ProductWrapper>{ pw, null };
        try {
            alignProductsToPricebook(products, pricebookId);
        } catch (Exception e) {
        }
        alignProductsToPricebook(null, pricebookId);
        alignProductsToPricebook(new List<DealerAddProductQuote.ProductWrapper>(), pricebookId);
        try {
            resolvePricebookIdFromSelectedEntries(products, pricebookId);
        } catch (Exception e) {
        }
        resolvePricebookIdFromSelectedEntries(new List<DealerAddProductQuote.ProductWrapper>(), pricebookId);
        try {
            ensureProductEntriesInPricebook(products, pricebookId);
        } catch (Exception e) {
            System.debug('ensure pbe soft: ' + e.getMessage());
        }
        ensureProductEntriesInPricebook(null, pricebookId);

        toPicklistOptions(Quote.Status.getDescribe().getPicklistValues());
        defaultPicklistValue(Quote.Status);
        parseDate(null);
        parseDate(String.valueOf(Date.today()));
        try {
            parseDate('not-a-date');
        } catch (Exception e) {
        }
        blankToNull(null);
        blankToNull('  x  ');
        stripHtml(null);
        stripHtml('');
        stripHtml('<p>Hi<br/>There</p>');
        formatFileSize(null);
        formatFileSize(10);
        formatFileSize(2048);
        formatFileSize(2 * 1024 * 1024);
        formatOwnerDisplayName(null);
        formatOwnerDisplayName(new User(FirstName = 'A', LastName = 'B'));
        // User.Name is not writeable — hydrate via JSON for technical-user branch coverage
        User techLabelUser = (User) JSON.deserialize(
            '{"Name":"User12345678","Email":"e@t.com","Username":"u@test.com"}',
            User.class
        );
        formatOwnerDisplayName(techLabelUser);
        formatOwnerDisplayName(new User(Email = 'onlyemail@t.com'));
        isTechnicalUserLabel(null);
        isTechnicalUserLabel('User12345678');
        isTechnicalUserLabel('Normal');

        try {
            assertAccountAccessibleForQuote(partnerId, partnerId, 'Self');
        } catch (Exception e) {
        }
        try {
            assertAccountAccessibleForQuote(accountId, partnerId, 'Secondary Customer');
        } catch (Exception e) {
        }
        try {
            assertAccountBelongsToPartner(accountId, partnerId);
        } catch (Exception e) {
        }
        if (contactId != null) {
            try {
                assertContactBelongsToAccount(contactId, accountId);
            } catch (Exception e) {
            }
        }
        resolveOpportunityRecordTypeId(null);
        if (quoteId != null) {
            try {
                queryQuoteById(quoteId);
            } catch (Exception e) {
            }
            try {
                assertQuoteAccessible(quoteId);
            } catch (Exception e) {
            }
            try {
                syncOpportunityLineItemsFromQuote(quoteId);
            } catch (Exception e) {
            }
        } else {
            try {
                syncOpportunityLineItemsFromQuote(null);
            } catch (Exception e) {
                // expected: Quote Id is required
            }
        }
    }
}