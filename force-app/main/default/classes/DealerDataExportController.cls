/**
 * Portal data export — object-aware via objectKey.
 * Quote page → Quote; Order page → Order; etc.
 * Date range filters on CreatedDate (inclusive).
 */
public without sharing class DealerDataExportController {
    private static final Integer MAX_ROWS = 5000;

    public class PreviewResult {
        @AuraEnabled public Integer recordCount;
        @AuraEnabled public String objectLabel;
        @AuraEnabled public Boolean truncated;
    }

    public class ExportResult {
        @AuraEnabled public String fileName;
        @AuraEnabled public String csvContent;
        @AuraEnabled public Integer recordCount;
        @AuraEnabled public Boolean truncated;
        @AuraEnabled public String objectLabel;
    }

    public class AccountOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public AccountOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<AccountOption> getExportAccounts(String objectKey) {
        String key = String.isBlank(objectKey) ? '' : objectKey.trim().toLowerCase();
        if (!supportsAccountFilter(key)) {
            return new List<AccountOption>();
        }

        Id partnerId = resolvePartnerAccountId();
        List<AccountOption> options = new List<AccountOption>();
        options.add(new AccountOption('All Accounts', ''));

        if (partnerId == null) {
            return options;
        }

        // Include CP account (used by Self quotes/orders) + approved secondary customers
        Set<Id> seen = new Set<Id>();
        for (Account a : [
            SELECT Id, Name
            FROM Account
            WHERE Id = :partnerId
               OR (
                    Channel_Partner_Name__c = :partnerId
                    AND Approval_Status__c = 'Approved'
               )
            ORDER BY Name
            LIMIT 500
        ]) {
            if (seen.contains(a.Id)) {
                continue;
            }
            seen.add(a.Id);
            options.add(new AccountOption(a.Name, String.valueOf(a.Id)));
        }
        return options;
    }

    @AuraEnabled
    public static PreviewResult getExportPreview(
        String objectKey,
        Date fromDate,
        Date toDate,
        String statusFilter,
        String typeFilter,
        String searchKey,
        String accountId
    ) {
        validateDates(fromDate, toDate);
        ObjectDef def = resolveDef(objectKey);
        List<SObject> rows = queryRows(
            def,
            fromDate,
            toDate,
            statusFilter,
            typeFilter,
            searchKey,
            accountId,
            MAX_ROWS + 1
        );
        PreviewResult result = new PreviewResult();
        result.objectLabel = def.label;
        result.truncated = rows.size() > MAX_ROWS;
        result.recordCount = result.truncated ? MAX_ROWS : rows.size();
        return result;
    }

    @AuraEnabled
    public static ExportResult exportData(
        String objectKey,
        Date fromDate,
        Date toDate,
        String statusFilter,
        String typeFilter,
        String searchKey,
        String accountId
    ) {
        validateDates(fromDate, toDate);
        ObjectDef def = resolveDef(objectKey);
        List<SObject> rows = queryRows(
            def,
            fromDate,
            toDate,
            statusFilter,
            typeFilter,
            searchKey,
            accountId,
            MAX_ROWS + 1
        );
        Boolean truncated = rows.size() > MAX_ROWS;
        if (truncated) {
            List<SObject> limited = new List<SObject>();
            for (Integer i = 0; i < MAX_ROWS; i++) {
                limited.add(rows[i]);
            }
            rows = limited;
        }

        ExportResult result = new ExportResult();
        result.objectLabel = def.label;
        result.recordCount = rows.size();
        result.truncated = truncated;
        result.fileName =
            sanitizeFileName(def.label) +
            '_' +
            String.valueOf(fromDate) +
            '_to_' +
            String.valueOf(toDate) +
            '.xls';
        result.csvContent = buildExcelXml(def, rows);
        return result;
    }

    private static Boolean supportsAccountFilter(String key) {
        return key == 'quote' || key == 'quotes'
            || key == 'order' || key == 'orders'
            || key == 'invoice' || key == 'invoices'
            || key == 'contact' || key == 'contacts'
            || key == 'case' || key == 'complaint' || key == 'complaints'
            || key == 'picklist' || key == 'picklists';
    }

    private static void validateDates(Date fromDate, Date toDate) {
        if (fromDate == null || toDate == null) {
            throw new AuraHandledException('From Date and To Date are required.');
        }
        if (fromDate > toDate) {
            throw new AuraHandledException('From Date cannot be after To Date.');
        }
        if (fromDate.daysBetween(toDate) > 366) {
            throw new AuraHandledException('Date range cannot exceed 366 days.');
        }
    }

    private class ObjectDef {
        String key;
        String label;
        String objectApi;
        List<String> fieldPaths;
        List<String> headers;
    }

    private static ObjectDef resolveDef(String objectKey) {
        String key = String.isBlank(objectKey) ? '' : objectKey.trim().toLowerCase();
        ObjectDef def = new ObjectDef();
        def.key = key;

        // Column sets match header-level fields shown on each portal detail page
        // (not related list line items / notes / files).
        if (key == 'quote' || key == 'quotes') {
            def.label = 'Quotes';
            def.objectApi = 'Quote';
            def.headers = new List<String>{
                'Quote Number', 'Owner Name', 'Quote Name', 'Quote For', 'Quote Type',
                'Quote Currency', 'Account Name', 'Status', 'Quote Date', 'Rev. No.',
                'Quote Valid Till', 'Rev. Date', 'MTA Quote',
                'Customer PO Number', 'SAP Quotation Number', 'Customer PO Date',
                'PBG or BG required?', 'Requested Delivery Date',
                'LD Clause Applicable?', 'PBG or BG comments', 'LD Clause comments',
                'Validity of Offer', 'Requested Validity Of Offer', 'Delivery Period',
                'Inco Terms', 'Payment Terms', 'Prices', 'Warranty Terms',
                'Requested Warranty Terms', 'Liquidate Terms', 'Transport Details',
                'Delivery Location', 'Special Remarks',
                'Contact Name', 'Phone', 'Email',
                'Bill To Party Code', 'Ship To Party Code',
                'Bill To Street', 'Ship To Street',
                'Bill To City', 'Ship To City',
                'Bill To Postal Code', 'Ship To Postal Code',
                'Bill To State', 'Ship To State',
                'Bill To Country', 'Ship To Country',
                'Created Date'
            };
            def.fieldPaths = new List<String>{
                'QuoteNumber', 'CP_Owner_Name__r.Name', 'Name', 'Quote_Type__c', 'RecordType.Name',
                'CurrencyIsoCode', 'Account.Name', 'Status', 'Quote_Date__c', 'Rev_No__c',
                'Quote_Valid_Till__c', 'Rev_Date__c', 'MTA_Quote__c',
                'Customer_Reference_No__c', 'SAP_Quotation_Number__c', 'Customer_Reference_Date__c',
                'PBG_or_BG_required__c', 'RequestedDeliveryDate__c',
                'LD_Clause_Applicable__c', 'PBG_or_BG_comments__c', 'LD_Clause_comments__c',
                'Validity_of_Offer__c', 'Requested_Validity_Of_Offer__c', 'Delivery_Period__c',
                'INCO_Terms__c', 'Payment_Terms__c', 'Prices__c', 'Warranty_Terms__c',
                'Warranty_Terms_Draft__c', 'Liquidate_Terms__c', 'Transport_Details__c',
                'Delivery_Location__c', 'Special_Remarks__c',
                'Contact.Name', 'Phone', 'Email',
                'Bill_To_Party_Code__c', 'Ship_To_Party_Code__c',
                'Bill_To_Street__c', 'Ship_To_Street__c',
                'Bill_To_City__c', 'Ship_To_City__c',
                'Bill_To_Postal_Code__c', 'Ship_To_Postal_Code__c',
                'Bill_To_State__c', 'Ship_To_State__c',
                'Bill_To_Country__c', 'Ship_To_Country__c',
                'CreatedDate'
            };
        } else if (key == 'order' || key == 'orders') {
            def.label = 'Orders';
            def.objectApi = 'Order';
            def.headers = new List<String>{
                'SF Order Number', 'Order Type', 'Rotex Order Number', 'Order Date',
                'Account Name', 'Order Currency', 'Net Value', 'Status',
                'Bill To', 'Ship To', 'Bill To Customer Name', 'Sold To',
                'Cust Ref Number', 'Terms Of Payment', 'Cust Ref Date',
                'Incoterms', 'Req Del Date', 'Owner', 'Created Date'
            };
            def.fieldPaths = new List<String>{
                'OrderNumber', 'SO_Type__c', 'SO_No__c', 'EffectiveDate',
                'Account.Name', 'CurrencyIsoCode', 'Net_Value__c', 'Status',
                'Bill_To__c', 'Ship_To__c', 'Bill_To_Customer_Name__r.Name', 'Sold_To__c',
                'Cust_Ref__c', 'Terms_Of_Payment__c', 'Cust_Ref_Date__c',
                'Incoterms__c', 'Req_Del_Date__c', 'Owner.Name', 'CreatedDate'
            };
        } else if (key == 'lead' || key == 'leads') {
            def.label = 'Leads';
            def.objectApi = 'Lead';
            def.headers = new List<String>{
                'Name', 'Customer', 'Designation', 'Phone', 'Email', 'Website',
                'Lead Source', 'Requirement', 'GST Number', 'Status',
                'Street', 'City', 'State', 'Postal Code', 'Country',
                'Regret Reason', 'Other Regret Reason', 'Regret Date/Time',
                'Owner', 'Created Date'
            };
            def.fieldPaths = new List<String>{
                'Name', 'Company', 'Title', 'Phone', 'Email', 'Website',
                'LeadSource', 'Requirement__c', 'GST_Number__c', 'Status',
                'Street', 'City', 'State', 'PostalCode', 'Country',
                'Regret_Reason1__c', 'Regret_Reason__c', 'Regret_Date_Time__c',
                'Owner.Name', 'CreatedDate'
            };
        } else if (key == 'invoice' || key == 'invoices') {
            def.label = 'Invoices';
            def.objectApi = 'SO_Invoice__c';
            def.headers = new List<String>{
                'Bill Doc No.', 'Bill Date', 'SO No.', 'Bill Doc Type', 'Acc Doc No',
                'Invoice Currency', 'Sold To Party Name', 'Net Value', 'Exc Rate', 'Tax Value',
                'Sold To', 'Terms Of Payment', 'Bill To', 'Incoterms', 'Payer',
                'Account', 'Owner', 'Created Date'
            };
            def.fieldPaths = new List<String>{
                'Name', 'Bill_Date__c', 'SO_No__c', 'Bill_Doc_Type__c', 'Acc_Doc_No__c',
                'CurrencyIsoCode', 'Sold_To__c', 'Net_Value__c', 'Exc_Rate__c', 'Tax_Value__c',
                'Sold_To__c', 'Terms_Of_Payment__c', 'Bill_To__c', 'Incoterms__c', 'Payer__c',
                'Account__r.Name', 'Owner.Name', 'CreatedDate'
            };
        } else if (key == 'contact' || key == 'contacts') {
            def.label = 'Contacts';
            def.objectApi = 'Contact';
            def.headers = new List<String>{
                'Name', 'Customer Name', 'Designation', 'Status', 'Email Id', 'Mobile No',
                'DOB', 'Anniversary',
                'Street', 'City', 'State', 'Postal Code', 'Country',
                'Owner', 'Created Date'
            };
            def.fieldPaths = new List<String>{
                'Name', 'Account.Name', 'Contact_Person_Designation__c', 'Status__c', 'Email', 'MobilePhone',
                'DOB__c', 'Anniversary__c',
                'MailingStreet', 'MailingCity', 'MailingState', 'MailingPostalCode', 'MailingCountry',
                'Owner.Name', 'CreatedDate'
            };
        } else if (key == 'case' || key == 'complaint' || key == 'complaints') {
            def.label = 'Complaints';
            def.objectApi = 'Case';
            def.headers = new List<String>{
                'Ticket Number', 'Ticket Type', 'Channel Partner', 'Category', 'Contact',
                'Customer Reference', 'Quote Reference', 'Order Reference',
                'Invoice Reference', 'GRN Reference', 'Product Reference', 'Other Reference',
                'Priority', 'Status', 'Subject', 'Description',
                'Resolution', 'Opened Date', 'Root Cause', 'Closed Date',
                'Remarks', 'Customer Satisfaction', 'Owner'
            };
            def.fieldPaths = new List<String>{
                'CaseNumber', 'Ticket_Type__c', 'Account.Name', 'Category__c', 'Contact.Name',
                'Customer__r.Name', 'Quote__r.QuoteNumber', 'Order__r.OrderNumber',
                'Invoice__r.Bill_Doc_No__c', 'GRN__r.Name', 'Product__r.Name', 'Other__c',
                'Priority', 'Status', 'Subject', 'Description',
                'Resolution__c', 'CreatedDate', 'Root_Cause__c', 'ClosedDate',
                'Remarks__c', 'Customer_Satisfaction__c', 'Owner.Name'
            };
        } else if (key == 'inventory' || key == 'inventories') {
            def.label = 'Inventory';
            def.objectApi = 'Inventory__c';
            def.headers = new List<String>{
                'Inventory Number', 'Last GRN Date', 'Channel Partner', 'Last Sale Date',
                'Product', 'Status', 'Product Code',
                'Minimum Order Quantity', 'Minimum Stock Level',
                'Total GRN Quantity', 'On Hand Quantity',
                'Total Reserved Quantity', 'Current Reserved Quantity',
                'Total Invoice Quantity', 'Available Quantity', 'Total Cancelled Quantity',
                'Owner', 'Created Date'
            };
            def.fieldPaths = new List<String>{
                'Name', 'Last_GRN_Date__c', 'Channel_Partner__r.Name', 'Last_Sale_Date__c',
                'Product__r.Name', 'Status__c', 'Product_Code__c',
                'Minimum_Order_Quantity__c', 'Minimum_Stock_Level__c',
                'Total_GRN_Quantity__c', 'On_Hand_Quantity__c',
                'Total_Reserved_Quantity__c', 'Current_Reserved_Quantity__c',
                'Total_Invoice_Quantity__c', 'Available_Quantity__c', 'Total_Cancelled_Quantity__c',
                'Owner.Name', 'CreatedDate'
            };
        } else if (key == 'product' || key == 'products') {
            def.label = 'Products';
            def.objectApi = 'Product_CP_Mapping__c';
            def.headers = new List<String>{
                'Product Name', 'Active', 'Product Code', 'Item Type',
                'Product Description', 'CP Product Code', 'Created Date'
            };
            def.fieldPaths = new List<String>{
                'Product__r.Name', 'Product__r.IsActive', 'Product__r.ProductCode', 'Product__r.Item_Type__c',
                'Product__r.Description', 'CP_Product_Code__c', 'CreatedDate'
            };
        } else if (key == 'picklist' || key == 'picklists') {
            def.label = 'Picklists';
            def.objectApi = 'Picklist__c';
            def.headers = new List<String>{
                'Pick List Number', 'Owner Name', 'Secondary Customer', 'Channel Partner',
                'Pick List Date', 'Requested Delivery Date', 'Remarks', 'Created Date'
            };
            def.fieldPaths = new List<String>{
                'Name', 'Owner.Name', 'Secondary_Customer__r.Name', 'Channel_Partner__r.Name',
                'Pick_List_Date__c', 'Requested_Delivery_Date__c', 'Remarks__c', 'CreatedDate'
            };
        } else if (key == 'event' || key == 'events' || key == 'visit' || key == 'visits') {
            def.label = 'Events';
            def.objectApi = 'Event';
            def.headers = new List<String>{
                'Subject', 'Start', 'End', 'Location', 'Description',
                'Visit Status', 'Visit Type', 'MOM',
                'Next Action Points', 'Next Action Applicable', 'Next Action Date',
                'Assigned To', 'Related To', 'Name',
                'Reminder Set', 'Reminder Date/Time', 'Created Date'
            };
            def.fieldPaths = new List<String>{
                'Subject', 'StartDateTime', 'EndDateTime', 'Location', 'Description',
                'Visit_Status__c', 'Visit_Type__c', 'MOM__c',
                'Next_Action_Points__c', 'Next_Action_Applicable__c', 'Next_Action_Date__c',
                'Owner.Name', 'What.Name', 'Who.Name',
                'IsReminderSet', 'ReminderDateTime', 'CreatedDate'
            };
        } else if (key == 'task' || key == 'tasks') {
            def.label = 'Tasks';
            def.objectApi = 'Task';
            def.headers = new List<String>{
                'Subject', 'Status', 'Priority', 'Due Date', 'Description',
                'Assigned To', 'Related To', 'Name',
                'Reminder Set', 'Reminder Date/Time', 'Created Date'
            };
            def.fieldPaths = new List<String>{
                'Subject', 'Status', 'Priority', 'ActivityDate', 'Description',
                'Owner.Name', 'What.Name', 'Who.Name',
                'IsReminderSet', 'ReminderDateTime', 'CreatedDate'
            };
        } else if (key == 'customer' || key == 'customers' || key == 'account' || key == 'accounts') {
            // Customer Registration detail minus Contact Information card
            def.label = 'Customers';
            def.objectApi = 'Account';
            def.headers = new List<String>{
                'Customer Name', 'GST No.', 'Customer Website', 'Customer Profile',
                'Product Manufactured By (OEM)', 'Business Line',
                'Approved Date', 'Rejection Date', 'Timestamp', 'Last Modified Date',
                'Channel Partner',
                'Address', 'Country', 'District', 'Pin Code', 'State',
                'Annual Business Potential', 'Target (Rotex)', 'Target (Non-Rotex)',
                'Approval Status', 'Created Date'
            };
            def.fieldPaths = new List<String>{
                'Customer_Name__c', 'GST_No__c', 'Website', 'Customer_Profile__c',
                'Additional_details_in_case_of_OEM__c', 'Business_type__c',
                'Approved_Date__c', 'Rejection_date__c', 'Timestamp__c', 'LastModifiedDate',
                'Channel_Partner_Name__r.Name',
                'Street__c', 'Country__c', 'District__c', 'Postal_Code__c', 'State__c',
                'Annual_Business_Potential__c', 'Target__c', 'Target_Non_Rotex__c',
                'Approval_Status__c', 'CreatedDate'
            };
        } else {
            throw new AuraHandledException('Unsupported export object: ' + objectKey);
        }
        return def;
    }

    private static List<SObject> queryRows(
        ObjectDef def,
        Date fromDate,
        Date toDate,
        String statusFilter,
        String typeFilter,
        String searchKey,
        String accountId,
        Integer rowLimit
    ) {
        Id partnerId = resolvePartnerAccountId();
        Id userId = UserInfo.getUserId();
        Datetime startDt = Datetime.newInstance(fromDate, Time.newInstance(0, 0, 0, 0));
        Datetime endDt = Datetime.newInstance(toDate.addDays(1), Time.newInstance(0, 0, 0, 0));

        // Bind vars used by dynamic filter clauses
        List<String> statusValues = resolveStatusValues(def.key, statusFilter);
        String typeValue = normalizeFilter(typeFilter);
        String searchTerm = buildSearchTerm(searchKey);
        Boolean activeFlag = resolveActiveFlag(def.key, statusFilter);
        Id accountFilterId = null;
        if (String.isNotBlank(accountId)) {
            try {
                accountFilterId = Id.valueOf(accountId.trim());
            } catch (Exception e) {
                accountFilterId = null;
            }
        }

        String selectClause = 'SELECT ' + String.join(uniqueFieldPaths(def.key, def.fieldPaths), ', ');
        String fromClause = ' FROM ' + def.objectApi;
        String whereClause = buildWhere(def.key, partnerId);
        String dateClause = ' AND CreatedDate >= :startDt AND CreatedDate < :endDt';
        String filterClause = buildPageFilters(
            def.key,
            statusValues,
            typeValue,
            searchTerm,
            activeFlag,
            accountFilterId
        );
        String soql =
            selectClause +
            fromClause +
            ' WHERE ' +
            whereClause +
            dateClause +
            filterClause +
            ' ORDER BY CreatedDate DESC LIMIT ' +
            String.valueOf(rowLimit);

        return Database.query(soql);
    }

    private static String normalizeFilter(String value) {
        if (String.isBlank(value) || value.trim().equalsIgnoreCase('All')) {
            return null;
        }
        return value.trim();
    }

    private static String buildSearchTerm(String searchKey) {
        if (String.isBlank(searchKey)) {
            return null;
        }
        return '%' + searchKey.trim() + '%';
    }

    private static Boolean resolveActiveFlag(String key, String statusFilter) {
        String status = normalizeFilter(statusFilter);
        if (status == null) {
            return null;
        }
        if (key == 'product' || key == 'products' || key == 'contact' || key == 'contacts') {
            if (status.equalsIgnoreCase('Active')) {
                return true;
            }
            if (status.equalsIgnoreCase('Inactive')) {
                return false;
            }
        }
        return null;
    }

    private static List<String> resolveStatusValues(String key, String statusFilter) {
        String status = normalizeFilter(statusFilter);
        if (status == null) {
            return new List<String>();
        }

        if (key == 'quote' || key == 'quotes') {
            String n = status.toLowerCase();
            if (n == 'draft') {
                return new List<String>{ 'Draft' };
            }
            if (n == 'submit for soa approval' || n == 'soa approval') {
                return new List<String>{ 'Submit for SOA Approval' };
            }
            if (n == 'submitted to customer' || n == 'submitted') {
                return new List<String>{ 'Submitted to Customer', 'Submitted' };
            }
            if (n == 'negotiation') {
                return new List<String>{ 'Negotiation' };
            }
            if (n == 'closed won' || n == 'accepted') {
                return new List<String>{ 'Accepted', 'Closed Won' };
            }
            if (n == 'closed lost') {
                return new List<String>{ 'Closed Lost' };
            }
            if (n == 'scrap' || n == 'scrap quote') {
                return new List<String>{ 'Scrap Quote', 'Scrap' };
            }
            if (n == 'under review by sales rep') {
                return new List<String>{ 'Under Review by Sales Rep' };
            }
            return new List<String>{ status };
        }

        if (key == 'lead' || key == 'leads') {
            return new List<String>{ status };
        }

        if (key == 'contact' || key == 'contacts') {
            // Active/Inactive handled via activeFlag on Status__c equality below
            return new List<String>();
        }

        if (key == 'product' || key == 'products') {
            return new List<String>();
        }

        if (key == 'case' || key == 'complaint' || key == 'complaints') {
            return new List<String>{ status };
        }

        if (key == 'order' || key == 'orders') {
            return new List<String>{ status };
        }

        if (key == 'customer' || key == 'customers' || key == 'account' || key == 'accounts') {
            return new List<String>{ status };
        }

        if (key == 'task' || key == 'tasks') {
            return new List<String>{ status };
        }

        return new List<String>{ status };
    }

    private static String buildPageFilters(
        String key,
        List<String> statusValues,
        String typeValue,
        String searchTerm,
        Boolean activeFlag,
        Id accountFilterId
    ) {
        List<String> parts = new List<String>();

        if (key == 'quote' || key == 'quotes') {
            if (statusValues != null && !statusValues.isEmpty()) {
                parts.add('Status IN :statusValues');
            }
            if (String.isNotBlank(typeValue)) {
                parts.add('Quote_Type__c = :typeValue');
            }
            if (accountFilterId != null) {
                parts.add(
                    '(AccountId = :accountFilterId OR QuoteAccountId = :accountFilterId OR Account__c = :accountFilterId)'
                );
            }
            if (String.isNotBlank(searchTerm)) {
                parts.add(
                    '(Name LIKE :searchTerm OR QuoteNumber LIKE :searchTerm' +
                    ' OR Account.Name LIKE :searchTerm OR Status LIKE :searchTerm' +
                    ' OR Quote_Type__c LIKE :searchTerm OR Owner.Name LIKE :searchTerm)'
                );
            }
        } else if (key == 'lead' || key == 'leads') {
            if (statusValues != null && !statusValues.isEmpty()) {
                parts.add('Status IN :statusValues');
            }
            if (String.isNotBlank(searchTerm)) {
                parts.add(
                    '(Name LIKE :searchTerm OR Company LIKE :searchTerm OR Email LIKE :searchTerm' +
                    ' OR Phone LIKE :searchTerm OR Status LIKE :searchTerm OR City LIKE :searchTerm)'
                );
            }
        } else if (key == 'contact' || key == 'contacts') {
            if (activeFlag == true) {
                parts.add('Status__c = \'Active\'');
            } else if (activeFlag == false) {
                parts.add('Status__c = \'Inactive\'');
            }
            if (accountFilterId != null) {
                parts.add('AccountId = :accountFilterId');
            }
            if (String.isNotBlank(searchTerm)) {
                parts.add(
                    '(Name LIKE :searchTerm OR Email LIKE :searchTerm OR MobilePhone LIKE :searchTerm' +
                    ' OR Account.Name LIKE :searchTerm OR Status__c LIKE :searchTerm)'
                );
            }
        } else if (key == 'product' || key == 'products') {
            if (activeFlag == true) {
                parts.add('Product__r.IsActive = true');
            } else if (activeFlag == false) {
                parts.add('Product__r.IsActive = false');
            }
            if (String.isNotBlank(searchTerm)) {
                parts.add(
                    '(Product__r.Name LIKE :searchTerm OR Product__r.ProductCode LIKE :searchTerm' +
                    ' OR CP_Product_Code__c LIKE :searchTerm OR Product__r.Description LIKE :searchTerm)'
                );
            }
        } else if (key == 'order' || key == 'orders') {
            if (statusValues != null && !statusValues.isEmpty()) {
                parts.add('Status IN :statusValues');
            }
            if (accountFilterId != null) {
                parts.add('AccountId = :accountFilterId');
            }
            if (String.isNotBlank(searchTerm)) {
                parts.add(
                    '(OrderNumber LIKE :searchTerm OR Name LIKE :searchTerm OR SO_No__c LIKE :searchTerm' +
                    ' OR Account.Name LIKE :searchTerm OR Status LIKE :searchTerm OR Owner.Name LIKE :searchTerm)'
                );
            }
        } else if (key == 'invoice' || key == 'invoices') {
            if (accountFilterId != null) {
                parts.add('Account__c = :accountFilterId');
            }
            if (String.isNotBlank(searchTerm)) {
                parts.add(
                    '(Bill_Doc_No__c LIKE :searchTerm OR Name LIKE :searchTerm OR SO_No__c LIKE :searchTerm' +
                    ' OR Account__r.Name LIKE :searchTerm OR Owner.Name LIKE :searchTerm)'
                );
            }
        } else if (key == 'case' || key == 'complaint' || key == 'complaints') {
            if (statusValues != null && !statusValues.isEmpty()) {
                parts.add('Status IN :statusValues');
            }
            if (accountFilterId != null) {
                parts.add('(AccountId = :accountFilterId OR Customer__c = :accountFilterId)');
            }
            if (String.isNotBlank(searchTerm)) {
                parts.add(
                    '(CaseNumber LIKE :searchTerm OR Subject LIKE :searchTerm OR Account.Name LIKE :searchTerm' +
                    ' OR Contact.Name LIKE :searchTerm OR Status LIKE :searchTerm OR Priority LIKE :searchTerm)'
                );
            }
        } else if (key == 'inventory' || key == 'inventories') {
            if (statusValues != null && !statusValues.isEmpty()) {
                parts.add('Status__c IN :statusValues');
            }
            if (String.isNotBlank(searchTerm)) {
                parts.add(
                    '(Name LIKE :searchTerm OR Product_Code__c LIKE :searchTerm OR Product__r.Name LIKE :searchTerm' +
                    ' OR Channel_Partner__r.Name LIKE :searchTerm OR Status__c LIKE :searchTerm)'
                );
            }
        } else if (key == 'picklist' || key == 'picklists') {
            if (accountFilterId != null) {
                parts.add('Secondary_Customer__c = :accountFilterId');
            }
            if (String.isNotBlank(searchTerm)) {
                parts.add(
                    '(Name LIKE :searchTerm OR Secondary_Customer__r.Name LIKE :searchTerm' +
                    ' OR Channel_Partner__r.Name LIKE :searchTerm' +
                    ' OR Owner.Name LIKE :searchTerm)'
                );
            }
        } else if (
            key == 'event' || key == 'events' || key == 'visit' || key == 'visits'
        ) {
            if (String.isNotBlank(searchTerm)) {
                parts.add('(Subject LIKE :searchTerm OR Location LIKE :searchTerm)');
            }
        } else if (key == 'task' || key == 'tasks') {
            if (statusValues != null && !statusValues.isEmpty()) {
                parts.add('Status IN :statusValues');
            }
            if (String.isNotBlank(searchTerm)) {
                parts.add('(Subject LIKE :searchTerm OR Status LIKE :searchTerm OR Priority LIKE :searchTerm)');
            }
        } else if (key == 'customer' || key == 'customers' || key == 'account' || key == 'accounts') {
            if (statusValues != null && !statusValues.isEmpty()) {
                parts.add('Approval_Status__c IN :statusValues');
            }
            // Page business-line tab (ROTEX / Non ROTEX / BOTH) via typeFilter
            if (String.isNotBlank(typeValue)) {
                parts.add('Business_type__c = :typeValue');
            }
            if (String.isNotBlank(searchTerm)) {
                parts.add(
                    '(Name LIKE :searchTerm OR Customer_Profile__c LIKE :searchTerm' +
                    ' OR District__c LIKE :searchTerm OR State__c LIKE :searchTerm' +
                    ' OR Business_type__c LIKE :searchTerm OR Approval_Status__c LIKE :searchTerm)'
                );
            }
        }

        if (parts.isEmpty()) {
            return '';
        }
        return ' AND ' + String.join(parts, ' AND ');
    }

    private static String buildWhere(String key, Id partnerId) {
        Id userId = UserInfo.getUserId();

        if (key == 'quote' || key == 'quotes') {
            if (partnerId == null) {
                return 'Id = null';
            }
            return
                '(AccountId = :partnerId' +
                ' OR QuoteAccountId = :partnerId' +
                ' OR Account__c = :partnerId' +
                ' OR OwnerId = :userId' +
                ' OR Account.Channel_Partner_Name__c = :partnerId' +
                ' OR Account.Channel_Partner__c = :partnerId' +
                ' OR QuoteAccount.Channel_Partner_Name__c = :partnerId' +
                ' OR QuoteAccount.Channel_Partner__c = :partnerId' +
                ' OR Account__r.Channel_Partner_Name__c = :partnerId' +
                ' OR Account__r.Channel_Partner__c = :partnerId' +
                ' OR Contact.Account.Channel_Partner_Name__c = :partnerId' +
                ' OR Contact.Account.Channel_Partner__c = :partnerId' +
                ' OR Contact.AccountId = :partnerId)';
        }
        if (key == 'order' || key == 'orders') {
            if (partnerId == null) {
                return 'CreatedById = :userId';
            }
            return
                '(AccountId = :partnerId' +
                ' OR Account.Channel_Partner_Name__c = :partnerId' +
                ' OR Account.Channel_Partner__c = :partnerId)';
        }
        if (key == 'lead' || key == 'leads') {
            if (partnerId == null) {
                return 'OwnerId = :userId AND IsConverted = false';
            }
            return
                'Dealer__c = :partnerId AND IsConverted = false' +
                ' AND RecordType.DeveloperName = \'Channel_Partner\'';
        }
        if (key == 'invoice' || key == 'invoices') {
            if (partnerId == null) {
                return 'CreatedById = :userId';
            }
            return
                '(Account__c = :partnerId' +
                ' OR Account__r.Channel_Partner_Name__c = :partnerId' +
                ' OR Account__r.Channel_Partner__c = :partnerId)';
        }
        if (key == 'contact' || key == 'contacts') {
            if (partnerId == null) {
                return 'Id = null';
            }
            return 'AccountId != null AND Account.Channel_Partner_Name__c = :partnerId';
        }
        if (key == 'case' || key == 'complaint' || key == 'complaints') {
            if (partnerId == null) {
                return 'OwnerId = :userId';
            }
            return 'AccountId = :partnerId';
        }
        if (key == 'inventory' || key == 'inventories') {
            if (partnerId == null) {
                return 'OwnerId = :userId';
            }
            return 'Channel_Partner__c = :partnerId';
        }
        if (key == 'picklist' || key == 'picklists') {
            if (partnerId == null) {
                return 'OwnerId = :userId';
            }
            return '(Channel_Partner__c = :partnerId OR OwnerId = :userId)';
        }
        if (key == 'product' || key == 'products') {
            if (partnerId == null) {
                return 'Id = null';
            }
            return 'Channel_Partner_Name__c = :partnerId AND Product__c != null';
        }
        if (
            key == 'event' || key == 'events' || key == 'visit' || key == 'visits'
            || key == 'task' || key == 'tasks'
        ) {
            return 'OwnerId = :userId';
        }
        if (key == 'customer' || key == 'customers' || key == 'account' || key == 'accounts') {
            if (partnerId == null) {
                return 'Id = null';
            }
            return 'Channel_Partner_Name__c = :partnerId AND RecordType.DeveloperName = \'Customer\'';
        }
        return 'Id = null';
    }

    private static List<String> uniqueFieldPaths(String objectKey, List<String> paths) {
        Set<String> seen = new Set<String>();
        List<String> out = new List<String>();
        for (String p : paths) {
            if (String.isBlank(p) || seen.contains(p)) {
                continue;
            }
            seen.add(p);
            out.add(p);
            if (p == 'Owner.Name' || p == 'CP_Owner_Name__r.Name') {
                String prefix = p == 'Owner.Name' ? 'Owner' : 'CP_Owner_Name__r';
                for (String extra : new List<String>{
                    prefix + '.FirstName',
                    prefix + '.LastName',
                    prefix + '.Email'
                }) {
                    if (!seen.contains(extra)) {
                        seen.add(extra);
                        out.add(extra);
                    }
                }
            }
        }
        if (objectKey == 'quote' || objectKey == 'quotes') {
            for (String extra : new List<String>{ 'QuoteAccount.Name', 'Account__r.Name' }) {
                if (!seen.contains(extra)) {
                    seen.add(extra);
                    out.add(extra);
                }
            }
        }
        if (
            (objectKey == 'customer' || objectKey == 'customers' || objectKey == 'account' || objectKey == 'accounts')
            && paths != null
            && paths.contains('Customer_Name__c')
            && !seen.contains('Name')
        ) {
            seen.add('Name');
            out.add('Name');
        }
        if (
            (objectKey == 'invoice' || objectKey == 'invoices')
            && paths != null
            && paths.contains('CurrencyIsoCode')
            && !seen.contains('Currency__c')
        ) {
            seen.add('Currency__c');
            out.add('Currency__c');
        }
        return out;
    }

    private static String buildExcelXml(ObjectDef def, List<SObject> rows) {
        List<List<String>> matrix = new List<List<String>>();
        matrix.add(new List<String>(def.headers));

        for (SObject row : rows) {
            List<String> cells = new List<String>();
            for (String path : def.fieldPaths) {
                cells.add(cellDisplayValue(row, path, def.key));
            }
            matrix.add(cells);
        }

        Integer colCount = def.headers.size();
        List<Integer> widths = new List<Integer>();
        for (Integer c = 0; c < colCount; c++) {
            Integer maxLen = def.headers[c] != null ? def.headers[c].length() : 8;
            for (Integer r = 1; r < matrix.size(); r++) {
                String v = matrix[r][c];
                if (v != null && v.length() > maxLen) {
                    maxLen = v.length();
                }
            }
            // Excel ss:Width ~ character width; keep dates/status fully visible
            Integer w = Math.min(240, Math.max(70, (maxLen + 2) * 7));
            widths.add(w);
        }

        String sheetName = escapeXml(def.label);
        if (sheetName.length() > 31) {
            sheetName = sheetName.substring(0, 31);
        }

        List<String> parts = new List<String>();
        parts.add('<?xml version="1.0"?>');
        parts.add('<?mso-application progid="Excel.Sheet"?>');
        parts.add('<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">');
        parts.add('<Styles>');
        parts.add('<Style ss:ID="Header"><Font ss:Bold="1"/><Interior ss:Color="#E8F2F1" ss:Pattern="Solid"/></Style>');
        parts.add('<Style ss:ID="Text"><NumberFormat ss:Format="@"/></Style>');
        parts.add('</Styles>');
        parts.add('<Worksheet ss:Name="' + sheetName + '">');
        parts.add('<Table>');

        for (Integer c = 0; c < colCount; c++) {
            parts.add('<Column ss:Width="' + String.valueOf(widths[c]) + '"/>');
        }

        // Header row
        parts.add('<Row>');
        for (Integer c = 0; c < colCount; c++) {
            parts.add(
                '<Cell ss:StyleID="Header"><Data ss:Type="String">' +
                escapeXml(matrix[0][c]) +
                '</Data></Cell>'
            );
        }
        parts.add('</Row>');

        // Data rows — all as text so Excel never collapses dates to #####
        for (Integer r = 1; r < matrix.size(); r++) {
            parts.add('<Row>');
            for (Integer c = 0; c < colCount; c++) {
                parts.add(
                    '<Cell ss:StyleID="Text"><Data ss:Type="String">' +
                    escapeXml(matrix[r][c]) +
                    '</Data></Cell>'
                );
            }
            parts.add('</Row>');
        }

        parts.add('</Table>');
        parts.add('</Worksheet>');
        parts.add('</Workbook>');
        return String.join(parts, '');
    }

    private static String cellDisplayValue(SObject row, String path, String objectKey) {
        if (path == 'Owner.Name') {
            return resolveUserDisplayName(row, 'Owner');
        }
        if (path == 'CP_Owner_Name__r.Name') {
            String cpOwner = resolveUserDisplayName(row, 'CP_Owner_Name__r');
            if (String.isNotBlank(cpOwner)) {
                return cpOwner;
            }
            return resolveUserDisplayName(row, 'Owner');
        }
        // Quote Account Name: same fallbacks as portal UI
        if (path == 'Account.Name' && (objectKey == 'quote' || objectKey == 'quotes')) {
            String v = formatValue(getFieldValue(row, 'Account.Name'));
            if (String.isBlank(v)) {
                v = formatValue(getFieldValue(row, 'QuoteAccount.Name'));
            }
            if (String.isBlank(v)) {
                v = formatValue(getFieldValue(row, 'Account__r.Name'));
            }
            return v;
        }
        // Customer Name fallback
        if (path == 'Customer_Name__c') {
            String v = formatValue(getFieldValue(row, 'Customer_Name__c'));
            if (String.isBlank(v)) {
                v = formatValue(getFieldValue(row, 'Name'));
            }
            return v;
        }
        // Invoice currency fallback
        if (path == 'CurrencyIsoCode' && (objectKey == 'invoice' || objectKey == 'invoices')) {
            String v = formatValue(getFieldValue(row, 'CurrencyIsoCode'));
            if (String.isBlank(v)) {
                v = formatValue(getFieldValue(row, 'Currency__c'));
            }
            return v;
        }
        return formatValue(getFieldValue(row, path));
    }

    private static String resolveUserDisplayName(SObject row, String relationship) {
        SObject owner = row == null ? null : row.getSObject(relationship);
        if (owner == null) {
            return '';
        }
        String firstName = (String) owner.get('FirstName');
        String lastName = (String) owner.get('LastName');
        String full = ((firstName == null ? '' : firstName.trim()) + ' ' + (lastName == null ? '' : lastName.trim())).trim();
        if (String.isNotBlank(full) && !full.toLowerCase().startsWith('user')) {
            return full;
        }
        String email = (String) owner.get('Email');
        if (String.isNotBlank(email)) {
            return email;
        }
        String name = (String) owner.get('Name');
        return name == null ? '' : name;
    }

    private static String resolveOwnerDisplayName(SObject row) {
        return resolveUserDisplayName(row, 'Owner');
    }

    private static String escapeXml(String value) {
        if (value == null) {
            return '';
        }
        return value
            .replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;')
            .replace('\'', '&apos;');
    }

    private static Object getFieldValue(SObject record, String fieldPath) {
        if (record == null || String.isBlank(fieldPath)) {
            return null;
        }
        List<String> parts = fieldPath.split('\\.');
        SObject current = record;
        for (Integer i = 0; i < parts.size(); i++) {
            String part = parts[i];
            if (i == parts.size() - 1) {
                return current.get(part);
            }
            current = current.getSObject(part);
            if (current == null) {
                return null;
            }
        }
        return null;
    }

    private static String formatValue(Object value) {
        if (value == null) {
            return '';
        }
        if (value instanceof Datetime) {
            return ((Datetime) value).format('dd-MMM-yyyy HH:mm');
        }
        if (value instanceof Date) {
            Datetime dt = Datetime.newInstance((Date) value, Time.newInstance(0, 0, 0, 0));
            return dt.format('dd-MMM-yyyy');
        }
        if (value instanceof Boolean) {
            return ((Boolean) value) ? 'Yes' : 'No';
        }
        return String.valueOf(value);
    }

    private static String sanitizeFileName(String label) {
        if (String.isBlank(label)) {
            return 'Export';
        }
        return label.replaceAll('[^A-Za-z0-9_-]+', '_');
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