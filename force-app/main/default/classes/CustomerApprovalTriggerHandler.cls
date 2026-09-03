public class CustomerApprovalTriggerHandler {

    private static final String PROCESS_CUSTOMER_APPROVAL = 'Customer_Approval_v3';
    private static final String SOA_SALES_REP = 'Sales Rep';
    private static final String SOA_SALES_MANAGER = 'Sales Manager';
    /** Non ROTEX customers auto-approve; ROTEX / BOTH go through approval. */
    private static final String BUSINESS_LINE_NON_ROTEX = 'Non ROTEX';

    public static void handleBeforeInsert(List<Account> newAccounts) {
        assignCustomerOwnerAndSalesManager(newAccounts);
        autoApproveNonRotexCustomers(newAccounts);
    }

    public static void handleBeforeUpdate(List<Account> newAccounts, Map<Id, Account> oldMap) {
        stampApprovalDates(newAccounts, oldMap);
    }

    public static void handleAfterInsert(List<Account> newAccounts) {
        submitCustomerApproval(newAccounts);
    }

    /**
     * Non ROTEX: skip approval workflow — set Approved on insert.
     * ROTEX / BOTH: leave status for approval process (initial submit → Pending).
     */
    private static void autoApproveNonRotexCustomers(List<Account> accounts) {
        if (accounts == null || accounts.isEmpty()) {
            return;
        }

        Id customerRtId = getCustomerRecordTypeId();
        if (customerRtId == null) {
            return;
        }

        for (Account acc : accounts) {
            if (acc.RecordTypeId != customerRtId) {
                continue;
            }
            if (isNonRotexBusinessLine(acc.Business_type__c)) {
                acc.Approval_Status__c = 'Approved';
                if (acc.Approved_Date__c == null) {
                    acc.Approved_Date__c = Date.today();
                }
            }
        }
    }

    /**
     * When Approval_Status__c becomes Approved / Rejected (approval process or manual),
     * stamp Approved_Date__c / Rejection_date__c once with today.
     */
    private static void stampApprovalDates(List<Account> accounts, Map<Id, Account> oldMap) {
        if (accounts == null || accounts.isEmpty()) {
            return;
        }

        Id customerRtId = getCustomerRecordTypeId();
        if (customerRtId == null) {
            return;
        }

        for (Account acc : accounts) {
            if (customerRtId != null && acc.RecordTypeId != null && acc.RecordTypeId != customerRtId) {
                continue;
            }
            Account oldAcc = oldMap == null ? null : oldMap.get(acc.Id);
            String oldStatus = oldAcc == null ? null : oldAcc.Approval_Status__c;
            if (acc.Approval_Status__c == oldStatus) {
                continue;
            }
            if (acc.Approval_Status__c == 'Approved' && acc.Approved_Date__c == null) {
                acc.Approved_Date__c = Date.today();
            } else if (acc.Approval_Status__c == 'Rejected' && acc.Rejection_date__c == null) {
                acc.Rejection_date__c = Date.today();
            }
        }
    }

    private static Boolean isNonRotexBusinessLine(String businessType) {
        return String.isNotBlank(businessType)
            && businessType.trim().equalsIgnoreCase(BUSINESS_LINE_NON_ROTEX);
    }

    private static Boolean requiresCustomerApproval(String businessType) {
        // Approval only for ROTEX and BOTH (anything other than pure Non ROTEX)
        return !isNonRotexBusinessLine(businessType);
    }

    /**
     * Customer Owner = CP Account Owner.
     * If Owner SOA = Sales Rep, Approver_Sales_Manager__c = first manager
     * in the User Manager chain whose SOA Profile is Sales Manager
     * (skips Board Member / other profiles).
     */
    public static void assignCustomerOwnerAndSalesManager(List<Account> accounts) {
        if (accounts == null || accounts.isEmpty()) {
            return;
        }

        Id customerRtId = getCustomerRecordTypeId();
        if (customerRtId == null) {
            return;
        }

        Set<Id> partnerIds = new Set<Id>();
        for (Account acc : accounts) {
            if (acc.RecordTypeId != customerRtId) {
                continue;
            }
            Id partnerId = resolvePartnerId(acc);
            if (partnerId != null) {
                partnerIds.add(partnerId);
            }
        }

        if (partnerIds.isEmpty()) {
            return;
        }

        Map<Id, Account> partnersById = new Map<Id, Account>([
            SELECT Id, OwnerId
            FROM Account
            WHERE Id IN :partnerIds
        ]);

        Set<Id> ownerIds = new Set<Id>();
        for (Account partner : partnersById.values()) {
            if (partner.OwnerId != null) {
                ownerIds.add(partner.OwnerId);
            }
        }

        Map<Id, User> usersById = loadUsersWithManagers(ownerIds);

        for (Account acc : accounts) {
            if (acc.RecordTypeId != customerRtId) {
                continue;
            }
            Id partnerId = resolvePartnerId(acc);
            Account partner = partnerId == null ? null : partnersById.get(partnerId);
            if (partner == null || partner.OwnerId == null) {
                continue;
            }

            acc.OwnerId = partner.OwnerId;
            acc.Approver_Sales_Manager__c = null;

            User cpOwner = usersById.get(partner.OwnerId);
            if (cpOwner == null) {
                continue;
            }

            String soa = normalizeSoa(cpOwner.SOA_Profile__c);
            if (soa.equalsIgnoreCase(SOA_SALES_REP)) {
                acc.Approver_Sales_Manager__c = findSalesManagerUpChain(cpOwner, usersById);
            }
            // Sales Manager / other: Owner approval is final — leave Approver_Sales_Manager__c blank
        }
    }

    public static void submitCustomerApproval(List<Account> newAccounts) {
        Id customerRtId = getCustomerRecordTypeId();
        if (customerRtId == null) {
            return;
        }

        Set<Id> accIds = new Set<Id>();
        for (Account acc : newAccounts) {
            accIds.add(acc.Id);
        }

        List<Account> accounts = [
            SELECT Id, RecordTypeId, OwnerId, Business_type__c, Approval_Status__c
            FROM Account
            WHERE Id IN :accIds
        ];

        List<Approval.ProcessSubmitRequest> requests =
            new List<Approval.ProcessSubmitRequest>();

        for (Account acc : accounts) {
            if (acc.RecordTypeId != customerRtId || acc.OwnerId == null) {
                continue;
            }
            // Non ROTEX is auto-approved — do not submit for approval
            if (!requiresCustomerApproval(acc.Business_type__c)) {
                continue;
            }
            if (acc.Approval_Status__c == 'Approved') {
                continue;
            }

            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(acc.Id);
            req.setSubmitterId(acc.OwnerId);
            req.setProcessDefinitionNameOrId(PROCESS_CUSTOMER_APPROVAL);
            req.setSkipEntryCriteria(false);
            requests.add(req);
        }

        if (requests.isEmpty()) {
            return;
        }

        try {
            List<Approval.ProcessResult> results = Approval.process(requests);
            for (Approval.ProcessResult result : results) {
                System.debug('Approval submitted: ' + result.isSuccess());
                if (!result.isSuccess()) {
                    System.debug('Errors: ' + result.getErrors());
                }
            }
        } catch (Exception e) {
            System.debug('Approval submission failed: ' + e.getMessage());
        }
    }

    /**
     * Walk ManagerId chain until SOA Profile = Sales Manager.
     */
    private static Id findSalesManagerUpChain(User startUser, Map<Id, User> usersById) {
        Id currentManagerId = startUser.ManagerId;
        Integer guard = 0;
        while (currentManagerId != null && guard < 10) {
            guard++;
            User mgr = usersById.get(currentManagerId);
            if (mgr == null) {
                // Lazy-load any missing manager nodes
                Map<Id, User> extra = loadUsersWithManagers(new Set<Id>{ currentManagerId });
                usersById.putAll(extra);
                mgr = usersById.get(currentManagerId);
            }
            if (mgr == null) {
                break;
            }
            if (normalizeSoa(mgr.SOA_Profile__c).equalsIgnoreCase(SOA_SALES_MANAGER)) {
                return mgr.Id;
            }
            currentManagerId = mgr.ManagerId;
        }
        return null;
    }

    private static Map<Id, User> loadUsersWithManagers(Set<Id> seedIds) {
        Map<Id, User> result = new Map<Id, User>();
        if (seedIds == null || seedIds.isEmpty()) {
            return result;
        }

        Set<Id> toQuery = new Set<Id>(seedIds);
        Integer guard = 0;
        while (!toQuery.isEmpty() && guard < 10) {
            guard++;
            List<User> batch = [
                SELECT Id, SOA_Profile__c, ManagerId
                FROM User
                WHERE Id IN :toQuery
            ];
            Set<Id> next = new Set<Id>();
            for (User u : batch) {
                result.put(u.Id, u);
                if (u.ManagerId != null && !result.containsKey(u.ManagerId)) {
                    next.add(u.ManagerId);
                }
            }
            toQuery = next;
        }
        return result;
    }

    private static String normalizeSoa(String value) {
        return value == null ? '' : value.trim();
    }

    private static Id resolvePartnerId(Account acc) {
        if (acc.Channel_Partner_Name__c != null) {
            return acc.Channel_Partner_Name__c;
        }
        return acc.Channel_Partner__c;
    }

    private static Id getCustomerRecordTypeId() {
        try {
            return [
                SELECT Id
                FROM RecordType
                WHERE SObjectType = 'Account'
                  AND DeveloperName = 'Customer'
                LIMIT 1
            ].Id;
        } catch (Exception e) {
            System.debug('Customer RecordType not found: ' + e.getMessage());
            return null;
        }
    }
}