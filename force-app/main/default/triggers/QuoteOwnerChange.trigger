trigger QuoteOwnerChange on Quote (after update) {

    // ✅ Collect Quotes where Owner changed
    Map<Id, Quote> quotesForNotification = new Map<Id, Quote>();
    Map<Id, Id> quoteToOldOwnerMap = new Map<Id, Id>();
    Set<Id> ownerIds = new Set<Id>();

    for (Quote newQuote : Trigger.new) {
        Quote oldQuote = Trigger.oldMap.get(newQuote.Id);

        if (newQuote.OwnerId != oldQuote.OwnerId) {
            quotesForNotification.put(newQuote.Id, newQuote);
            quoteToOldOwnerMap.put(newQuote.Id, oldQuote.OwnerId);

            ownerIds.add(newQuote.OwnerId);
            ownerIds.add(oldQuote.OwnerId);
        }
    }

    if (quotesForNotification.isEmpty()) {
        return;
    }

    // ✅ Query Owners once
    Map<Id, User> userMap = new Map<Id, User>(
        [SELECT Id, Name FROM User WHERE Id IN :ownerIds]
    );

    // ✅ Query Notification Type once
    CustomNotificationType notifType = [
        SELECT Id
        FROM CustomNotificationType
        WHERE DeveloperName = 'Quote_Owner_Changed'
        LIMIT 1
    ];

    // ✅ Send notifications
    for (Quote q : quotesForNotification.values()) {

        User oldOwner = userMap.get(quoteToOldOwnerMap.get(q.Id));

        Messaging.CustomNotification notification =
            new Messaging.CustomNotification();

        notification.setNotificationTypeId(notifType.Id);
        notification.setTitle('Quote Ownership Assigned');
        notification.setBody(
            'Ownership of Quote "' + q.QuoteNumber + '" has been assigned to you'
            + (oldOwner != null ? ' — by ' + oldOwner.Name : '') + '.'
        );
        notification.setTargetId(q.Id);

        // ✅ Correct supported method
        notification.send(
            new Set<String>{ String.valueOf(q.OwnerId) }
        );
    }
}