public with sharing class QuoteLineItemEditController {
    
    public QuoteLineItemEditController(ApexPages.StandardController controller) {
    }
    
    public PageReference blockEdit() {
        ApexPages.addMessage(
            new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Quote Line Item cannot be edited from this screen.'
            )
        );
        return null;
    }
}