public with sharing class SubmitQuoteController {

    @AuraEnabled
    public static void submitQuoteAndNotifyOwner(String quoteId) {

        Quote quoteRecord = [
                SELECT Id, QuoteNumber, Status, OwnerId, Account.Name, Account.OwnerId, 
                    Opportunity.Name, CreatedBy.Name, CreatedById
                FROM Quote 
                WHERE Id = :quoteId 
                LIMIT 1
            ];
        
        if (quoteRecord.Status == 'Submitted') {
            throw new AuraHandledException('Quote is already submitted.');
        }
        
        Id originalOwnerId = quoteRecord.OwnerId;

        Id newOwnerId = quoteRecord.Account.OwnerId;
        
        quoteRecord.Status = 'Submitted';
        
        quoteRecord.OwnerId = newOwnerId;
        
        update quoteRecord;
        
        sendEmailToAccountOwner(quoteRecord, newOwnerId);
        
        sendCustomNotification(quoteRecord, newOwnerId);
        
    }
    
    private static void sendEmailToAccountOwner(Quote quoteRecord, Id accountOwnerId) {
        
        User accountOwner = [SELECT Email, Name FROM User WHERE Id = :accountOwnerId LIMIT 1];
        
        
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{accountOwner.Email});
        email.setSubject('Quote Submitted by CRR Team – Quote ' + quoteRecord.QuoteNumber);
        email.setWhatId(quoteRecord.Id);
        email.setSaveAsActivity(true);
        
        
        String emailBody = '<html><body>';
        emailBody += '<p>Dear ' + accountOwner.Name + ',</p>';
        emailBody += '<p>The following quote has been successfully submitted to the customer for review:</p>';
        emailBody += '<p><strong>Quote Details:</strong></p>';
        emailBody += '<ul>';
        emailBody += '<li><strong>Quote Number:</strong> ' + quoteRecord.QuoteNumber + '</li>';
        emailBody += '<li><strong>Account:</strong> ' + quoteRecord.Account.Name + '</li>';
        emailBody += '<li><strong>Opportunity:</strong> ' + quoteRecord.Opportunity.Name + '</li>';
        emailBody += '<li><strong>Submitted By (CRR Team Member):</strong> ' + quoteRecord.CreatedBy.Name + '</li>';
        emailBody += '<li><strong>Submission Date:</strong> ' + Date.today().format() + '</li>';
        emailBody += '</ul>';
        emailBody += '<p>If you need any additional information or revisions, please reach out to the CRR Team.</p>';
        emailBody += '<p>Regards,<br/>' + quoteRecord.CreatedBy.Name + '</p>';
        emailBody += '</body></html>';
        
        email.setHtmlBody(emailBody);
        
        
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{email});
    }
    
    private static void sendCustomNotification(Quote quoteRecord, Id accountOwnerId) {
        
        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        
        
        CustomNotificationType notificationType = [
            SELECT Id 
            FROM CustomNotificationType 
            WHERE DeveloperName = 'Quote_Submission_Notification' 
            LIMIT 1
        ];
        
        notification.setNotificationTypeId(notificationType.Id);
        notification.setTitle('Quote Submitted: ' + quoteRecord.QuoteNumber);
        notification.setBody('Quote ' + quoteRecord.QuoteNumber + ' has been submitted by the CRR Team.');
        notification.setTargetId(quoteRecord.Id);
        
        
        notification.send(new Set<String>{accountOwnerId});
    }
}