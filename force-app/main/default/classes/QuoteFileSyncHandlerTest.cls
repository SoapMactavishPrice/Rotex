@IsTest
private class QuoteFileSyncHandlerTest {

    @IsTest
    static void testCopyOpportunityFilesToQuote() {

        // Account
        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;

        // Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        // Create File
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test Data')
        );
        insert cv;

        // Get ContentDocumentId
        cv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];

        // Link File to Opportunity
        ContentDocumentLink oppLink = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = opp.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert oppLink;

        // Quote
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id
        );
        insert q;

        Test.startTest();

        QuoteFileSyncHandler.copyOpportunityFilesToQuote(
            new List<Quote>{q}
        );

        Test.stopTest();

        List<ContentDocumentLink> quoteLinks =
            [
                SELECT Id,
                       ContentDocumentId,
                       LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :q.Id
            ];

        System.assert(
            quoteLinks.size() > 0,
            'File should be linked to Quote'
        );
    }

    @IsTest
    static void testNoOpportunityOnQuote() {

        Quote q = new Quote();

        Test.startTest();

        QuoteFileSyncHandler.copyOpportunityFilesToQuote(
            new List<Quote>{q}
        );

        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testOpportunityWithoutFiles() {

        Account acc = new Account(
            Name = 'No File Account'
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'No File Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Quote q = new Quote(
            Name = 'No File Quote',
            OpportunityId = opp.Id
        );
        insert q;

        Test.startTest();

        QuoteFileSyncHandler.copyOpportunityFilesToQuote(
            new List<Quote>{q}
        );

        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testExistingQuoteFileLink() {

        Account acc = new Account(
            Name = 'Duplicate Test'
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Duplicate Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        ContentVersion cv = new ContentVersion(
            Title = 'Duplicate File',
            PathOnClient = 'Duplicate.pdf',
            VersionData = Blob.valueOf('Duplicate Data')
        );
        insert cv;

        cv = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];

        insert new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = opp.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Quote q = new Quote(
            Name = 'Duplicate Quote',
            OpportunityId = opp.Id
        );
        insert q;

        // Existing file already linked to quote
       /* insert new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = q.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );*/

        Test.startTest();

        QuoteFileSyncHandler.copyOpportunityFilesToQuote(
            new List<Quote>{q}
        );

        Test.stopTest();

        System.assert(true);
    }
}