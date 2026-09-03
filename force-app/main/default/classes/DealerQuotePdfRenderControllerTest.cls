@IsTest
private class DealerQuotePdfRenderControllerTest {
    @IsTest
    static void testPdfRenderController() {
        // Create basic setup for Quote
        Account acc = new Account(Name = 'Test Account for Quote');
        insert acc;
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opp', 
            StageName = 'Prospecting', 
            CloseDate = Date.today(), 
            AccountId = acc.Id
        );
        insert opp;
        
        Quote q = new Quote(
            Name = 'Test Quote', 
            OpportunityId = opp.Id,
            Email = 'test@example.com'
        );
        insert q;
        
        Test.startTest();
        
        // Setup PageReference and set the ID parameter
        PageReference pr = new PageReference('/apex/DealerQuotePdfRender');
        pr.getParameters().put('id', q.Id);
        Test.setCurrentPage(pr);
        
        // Instantiate the controller
        DealerQuotePdfRenderController ctrl = new DealerQuotePdfRenderController();
        Test.stopTest();
        
        // Assert that htmlContent was populated
        System.assertNotEquals(null, ctrl.htmlContent, 'HTML content should be populated from the PDF builder.');
    }
}