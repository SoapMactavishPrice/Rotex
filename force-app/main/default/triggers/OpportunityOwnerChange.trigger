trigger OpportunityOwnerChange on Opportunity (after update) {

    // ✅ Collect Opportunities where Owner changed
    Map<Id, Opportunity> oppsForNotification = new Map<Id, Opportunity>();
    Map<Id, Id> oppToOldOwnerMap = new Map<Id, Id>();
    Set<Id> ownerIds = new Set<Id>();

    for (Opportunity newOpp : Trigger.new) {
        Opportunity oldOpp = Trigger.oldMap.get(newOpp.Id);

        if (newOpp.OwnerId != oldOpp.OwnerId) {
            oppsForNotification.put(newOpp.Id, newOpp);
            oppToOldOwnerMap.put(newOpp.Id, oldOpp.OwnerId);

            ownerIds.add(newOpp.OwnerId);
            ownerIds.add(oldOpp.OwnerId);
        }
    }

    if (oppsForNotification.isEmpty()) {
        return;
    }

    // ✅ Query all involved users once
    Map<Id, User> userMap = new Map<Id, User>(
        [SELECT Id, Name FROM User WHERE Id IN :ownerIds]
    );

    // ✅ Query Notification Type once
    CustomNotificationType notifType = [
        SELECT Id
        FROM CustomNotificationType
        WHERE DeveloperName = 'Opportunity_Owner_Changed'
        LIMIT 1
    ];

    // ✅ Send notification per Opportunity
    for (Opportunity opp : oppsForNotification.values()) {

        User oldOwner = userMap.get(oppToOldOwnerMap.get(opp.Id));

        Messaging.CustomNotification notification =
            new Messaging.CustomNotification();

        notification.setNotificationTypeId(notifType.Id);
        notification.setTitle('Opportunity Ownership Assigned');
        notification.setBody(
            'Ownership of Opportunity "' + opp.Name + '" has been assigned to you'
            + (oldOwner != null ? ' — by ' + oldOwner.Name : '') + '.'
        );
        notification.setTargetId(opp.Id);

        // ✅ Supported method
        notification.send(
            new Set<String>{ String.valueOf(opp.OwnerId) }
        );
    }
}