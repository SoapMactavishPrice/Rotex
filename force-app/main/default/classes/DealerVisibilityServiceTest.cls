@IsTest
private class DealerVisibilityServiceTest {
    @IsTest
    static void testResolveAndFilter() {
        DealerVisibilityService.Scope scope = DealerVisibilityService.resolve();
        System.assertNotEquals(null, scope.visibleUserIds);
        System.assert(scope.visibleUserIds.contains(UserInfo.getUserId()));
        System.assertNotEquals(null, scope.allPartnerUserIds);

        Account a = new Account(Name = 'Vis Test ' + Datetime.now().getTime());
        insert a;
        a = [SELECT Id, OwnerId, CreatedById FROM Account WHERE Id = :a.Id];

        List<SObject> filtered = DealerVisibilityService.filterByVisibility(new List<SObject>{ a });
        System.assertEquals(1, filtered.size());

        System.assertEquals(
            true,
            DealerVisibilityService.isRecordVisible(scope, UserInfo.getUserId(), UserInfo.getUserId())
        );
        System.assert(
            String.isNotBlank(DealerVisibilityService.soqlOwnerOrCreatedByVisibility())
        );
        System.assertEquals(0, DealerVisibilityService.filterByVisibility(new List<SObject>()).size());
        System.assertEquals(0, DealerVisibilityService.filterByVisibility(null).size());
    }

    @IsTest
    static void testRoleVisibilityRules() {
        Id me = UserInfo.getUserId();
        Id otherWorker = UserInfo.getUserId(); // placeholder; use fake ids via Scope sets
        // Build synthetic peer ids that are not me
        Id peerWorker = '005000000000001AAA';
        Id peerManager = '005000000000002AAA';
        Id peerExec = '005000000000003AAA';
        Id internalUser = '005000000000004AAA';

        DealerVisibilityService.Scope workerScope = new DealerVisibilityService.Scope();
        workerScope.partnerAccountId = '001000000000001AAA';
        workerScope.portalRole = 'Worker';
        workerScope.visibleUserIds = new Set<Id>{ me };
        workerScope.allPartnerUserIds = new Set<Id>{ me, peerWorker, peerManager, peerExec };

        System.assertEquals(true, DealerVisibilityService.isRecordVisible(workerScope, me, me));
        System.assertEquals(false, DealerVisibilityService.isRecordVisible(workerScope, peerWorker, peerWorker));
        System.assertEquals(false, DealerVisibilityService.isRecordVisible(workerScope, peerManager, peerManager));
        System.assertEquals(false, DealerVisibilityService.isRecordVisible(workerScope, peerExec, peerExec));
        System.assertEquals(true, DealerVisibilityService.isRecordVisible(workerScope, internalUser, internalUser));

        DealerVisibilityService.Scope managerScope = new DealerVisibilityService.Scope();
        managerScope.partnerAccountId = workerScope.partnerAccountId;
        managerScope.portalRole = 'Manager';
        managerScope.visibleUserIds = new Set<Id>{ me, peerWorker };
        managerScope.allPartnerUserIds = workerScope.allPartnerUserIds;

        System.assertEquals(true, DealerVisibilityService.isRecordVisible(managerScope, me, me));
        System.assertEquals(true, DealerVisibilityService.isRecordVisible(managerScope, peerWorker, peerWorker));
        System.assertEquals(false, DealerVisibilityService.isRecordVisible(managerScope, peerExec, peerExec));

        DealerVisibilityService.Scope execScope = new DealerVisibilityService.Scope();
        execScope.partnerAccountId = workerScope.partnerAccountId;
        execScope.portalRole = 'Executive';
        execScope.visibleUserIds = workerScope.allPartnerUserIds;
        execScope.allPartnerUserIds = workerScope.allPartnerUserIds;
        System.assertEquals(true, DealerVisibilityService.isRecordVisible(execScope, peerExec, peerExec));
        System.assertEquals(true, DealerVisibilityService.isRecordVisible(null, peerExec, peerExec));
    }
}