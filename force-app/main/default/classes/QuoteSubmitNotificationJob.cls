global class QuoteSubmitNotificationJob implements Schedulable {

    global void execute(SchedulableContext sc) {

        DateTime cutoffTime = System.now().addHours(-48);

        List<Quote> quotesToNotify = [
            SELECT Id, Name, OwnerId, Quote_Submitted__c, Owner.Name
            FROM Quote
            WHERE Status = 'Submitted'
            AND Quote_Submitted__c != null
            AND Quote_Submitted__c <= :cutoffTime
        ];

        if (quotesToNotify.isEmpty()) {
            return;
        }

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Quote q : quotesToNotify) {

            String ownerName = (q.Owner != null) ? q.Owner.Name : 'Team';
            String quoteName = q.Name;

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

            mail.setTargetObjectId(q.OwnerId);
            mail.setSaveAsActivity(false);
            mail.setSubject('Quote Submitted - 48 Hour Alert');

            // SAFE Apex email body (no merge field dependency)
            mail.setPlainTextBody(
                'Hello ' + ownerName + ',\n\n' +
                'Quote "' + quoteName + '" has been in "Submitted" status for 48 hours.\n\n' +
                'Please take the necessary action.'
            );

            emails.add(mail);
        }

        Messaging.sendEmail(emails);
    }
}