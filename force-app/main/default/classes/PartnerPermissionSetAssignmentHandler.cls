public with sharing class PartnerPermissionSetAssignmentHandler {

    // API Name of the Permission Set to auto-assign (from your screenshot: Portal_Permission)
    private static final String PERMISSION_SET_API_NAME = 'Portal_Permission';

    // Add every Partner Community profile name relevant to your org here
    private static final Set<String> PARTNER_PROFILE_NAMES = new Set<String>{
        'Partner Community User',
        'Partner Community Login User'
    };

    public static void assignPermissionSet(List<User> newUsers, Map<Id, User> oldMap) {

        // 1. Collect candidate users: new Partner Community users,
        //    OR users whose profile just changed TO a Partner Community profile
        Set<Id> candidateUserIds = new Set<Id>();
        Set<Id> profileIdsToCheck = new Set<Id>();

        for (User u : newUsers) {
            Boolean isInsertCase = (oldMap == null);
            Boolean profileChangedCase =
                (oldMap != null && oldMap.get(u.Id) != null && oldMap.get(u.Id).ProfileId != u.ProfileId);

            if ((isInsertCase || profileChangedCase) && u.IsActive) {
                candidateUserIds.add(u.Id);
                profileIdsToCheck.add(u.ProfileId);
            }
        }

        if (candidateUserIds.isEmpty()) {
            return;
        }

        // 2. Figure out which of those Profile Ids are actually Partner Community profiles
        Set<Id> partnerProfileIds = new Set<Id>();
        for (Profile p : [
            SELECT Id, Name
            FROM Profile
            WHERE Id IN :profileIdsToCheck
            AND Name IN :PARTNER_PROFILE_NAMES
        ]) {
            partnerProfileIds.add(p.Id);
        }

        if (partnerProfileIds.isEmpty()) {
            return;
        }

        // 3. Narrow candidate users down to those actually on a partner profile
        List<Id> finalUserIds = new List<Id>();
        for (User u : newUsers) {
            if (candidateUserIds.contains(u.Id) && partnerProfileIds.contains(u.ProfileId)) {
                finalUserIds.add(u.Id);
            }
        }

        if (finalUserIds.isEmpty()) {
            return;
        }

        // 4. Get the Permission Set Id
        PermissionSet ps;
        try {
            ps = [SELECT Id FROM PermissionSet WHERE Name = :PERMISSION_SET_API_NAME LIMIT 1];
        } catch (QueryException qe) {
            // Permission Set not found - log and exit gracefully
            System.debug('PartnerPermissionSetAssignmentHandler: Permission Set '
                + PERMISSION_SET_API_NAME + ' not found. ' + qe.getMessage());
            return;
        }

        // 5. Find users who ALREADY have this permission set assigned, to avoid duplicates
        Set<Id> alreadyAssignedUserIds = new Set<Id>();
        for (PermissionSetAssignment psa : [
            SELECT AssigneeId
            FROM PermissionSetAssignment
            WHERE PermissionSetId = :ps.Id
            AND AssigneeId IN :finalUserIds
        ]) {
            alreadyAssignedUserIds.add(psa.AssigneeId);
        }

        // 6. Build the list of new assignments needed
        List<PermissionSetAssignment> assignmentsToInsert = new List<PermissionSetAssignment>();
        for (Id userId : finalUserIds) {
            if (!alreadyAssignedUserIds.contains(userId)) {
                assignmentsToInsert.add(new PermissionSetAssignment(
                    AssigneeId = userId,
                    PermissionSetId = ps.Id
                ));
            }
        }

        // 7. Insert, allowing partial success so one bad record doesn't block the rest
        if (!assignmentsToInsert.isEmpty()) {
            Database.insert(assignmentsToInsert, false);
        }
    }
}