trigger QuoteOwnerChange on Quote (after update) {

    Map<Id, Quote> quotesForNotification = new Map<Id, Quote>();
    Map<Id, Id> quoteToOldOwnerMap = new Map<Id, Id>();
    Set<Id> ownerIds = new Set<Id>();
    ownerIds.add(UserInfo.getUserId());

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

    Map<Id, User> userMap = new Map<Id, User>(
        [SELECT Id, Name, Email FROM User WHERE Id IN :ownerIds]
    );

    CustomNotificationType notifType = [
        SELECT Id
        FROM CustomNotificationType
        WHERE DeveloperName = 'Quote_Owner_Changed'
        LIMIT 1
    ];

    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

    for (Quote q : quotesForNotification.values()) {

        User newOwner = userMap.get(q.OwnerId);
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

        notification.send(
            new Set<String>{ String.valueOf(q.OwnerId) }
        );

        if (newOwner != null && String.isNotBlank(newOwner.Email)) {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ newOwner.Email });
            email.setSubject('Quote Ownership Assigned');

            email.setPlainTextBody(
                'Hello ' + newOwner.Name + ',\n\n' +
                'Ownership of Quote "' + q.QuoteNumber + '" has been assigned to you' +
                (oldOwner != null ? ' by ' + oldOwner.Name : '') + '.\n\n' +
                'Please review the quote.\n\n' +
                'Thank you.'
            );

            emails.add(email);
        }
    }

    if (!emails.isEmpty()) {
        Messaging.sendEmail(emails);
    }
}