/**
 * Partner role visibility within one Channel Partner account.
 *
 * Role hierarchy (UserRole.PortalRole):
 *  - Executive → all portal users under the same Account
 *  - Manager   → self + Partner Users (Worker); not Executive
 *  - Worker    → self only (not other Workers / Manager / Executive)
 *
 * Non-portal-owned records (e.g. SAP / internal owner) stay shared to the whole CP.
 */
public without sharing class DealerVisibilityService {
    public class Scope {
        public Id partnerAccountId;
        public String portalRole;
        public Set<Id> visibleUserIds;
        public Set<Id> allPartnerUserIds;
    }

    public static Scope resolve() {
        Scope scope = new Scope();
        scope.visibleUserIds = new Set<Id>{ UserInfo.getUserId() };
        scope.allPartnerUserIds = new Set<Id>{ UserInfo.getUserId() };
        scope.portalRole = null;

        List<User> meRows = [
            SELECT Id, AccountId, UserRoleId, UserRole.PortalRole, UserRole.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (meRows.isEmpty() || meRows[0].AccountId == null) {
            return scope;
        }

        User me = meRows[0];
        scope.partnerAccountId = me.AccountId;
        scope.portalRole = normalizePortalRole(me.UserRole != null ? me.UserRole.PortalRole : null, me.UserRole != null ? me.UserRole.Name : null);

        List<User> partnerUsers = [
            SELECT Id, UserRoleId, UserRole.PortalRole, UserRole.Name
            FROM User
            WHERE IsActive = true
              AND AccountId = :me.AccountId
              AND UserType IN (
                  'PowerPartner',
                  'PowerCustomerSuccess',
                  'CspLitePortal',
                  'CustomerSuccess'
              )
        ];

        Map<Id, String> roleByUser = new Map<Id, String>();
        for (User u : partnerUsers) {
            scope.allPartnerUserIds.add(u.Id);
            roleByUser.put(
                u.Id,
                normalizePortalRole(
                    u.UserRole != null ? u.UserRole.PortalRole : null,
                    u.UserRole != null ? u.UserRole.Name : null
                )
            );
        }

        scope.visibleUserIds = new Set<Id>{ me.Id };
        if (scope.portalRole == 'Executive') {
            scope.visibleUserIds.addAll(scope.allPartnerUserIds);
        } else if (scope.portalRole == 'Manager') {
            for (Id uid : roleByUser.keySet()) {
                String role = roleByUser.get(uid);
                if (uid == me.Id || role == 'Worker') {
                    scope.visibleUserIds.add(uid);
                }
            }
        }

        return scope;
    }

    private static String normalizePortalRole(String portalRole, String roleName) {
        if (portalRole == 'Executive' || portalRole == 'Manager' || portalRole == 'Worker') {
            return portalRole;
        }
        if (String.isBlank(roleName)) {
            return 'Worker';
        }
        String n = roleName.toLowerCase();
        if (n.contains('executive')) {
            return 'Executive';
        }
        if (n.contains('manager')) {
            return 'Manager';
        }
        return 'Worker';
    }

    /**
     * Partner-owned/created → role hierarchy.
     * Otherwise (SAP / internal) → shared within the CP query scope.
     */
    public static Boolean isRecordVisible(Scope scope, Id ownerId, Id createdById) {
        if (scope == null || scope.partnerAccountId == null) {
            return true;
        }
        if (scope.portalRole == 'Executive') {
            return true;
        }
        Boolean partnerOwned =
            (ownerId != null && scope.allPartnerUserIds.contains(ownerId))
            || (createdById != null && scope.allPartnerUserIds.contains(createdById));
        if (!partnerOwned) {
            return true;
        }
        return (ownerId != null && scope.visibleUserIds.contains(ownerId))
            || (createdById != null && scope.visibleUserIds.contains(createdById));
    }

    public static List<SObject> filterByVisibility(List<SObject> rows) {
        if (rows == null || rows.isEmpty()) {
            return rows == null ? new List<SObject>() : rows;
        }
        Scope scope = resolve();
        if (scope.partnerAccountId == null || scope.portalRole == 'Executive') {
            return rows;
        }

        List<SObject> visible = new List<SObject>();
        for (SObject row : rows) {
            Id ownerId = null;
            Id createdById = null;
            try {
                ownerId = (Id) row.get('OwnerId');
            } catch (Exception e) {
                // object may not have OwnerId
            }
            try {
                createdById = (Id) row.get('CreatedById');
            } catch (Exception e) {
                // ignore
            }
            if (isRecordVisible(scope, ownerId, createdById)) {
                visible.add(row);
            }
        }
        return visible;
    }

    /** Bind :visibleUserIds and :allPartnerUserIds in the caller. */
    public static String soqlOwnerOrCreatedByVisibility() {
        return '('
            + '(OwnerId IN :visibleUserIds OR CreatedById IN :visibleUserIds)'
            + ' OR (OwnerId NOT IN :allPartnerUserIds AND CreatedById NOT IN :allPartnerUserIds)'
            + ')';
    }
}