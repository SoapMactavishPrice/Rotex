/**
 * Visualforce renderAs=pdf host for dealer portal Save PDF.
 * Invoked only via Apex PageReference.getContentAsPDF (not opened in the browser).
 */
public without sharing class DealerQuotePdfRenderController {
    public String htmlContent { get; private set; }

    public DealerQuotePdfRenderController() {
        String quoteId = ApexPages.currentPage().getParameters().get('id');
        htmlContent = DealerSalesQuotationPDFController.buildVisualforcePdfHtml(quoteId);
    }
}