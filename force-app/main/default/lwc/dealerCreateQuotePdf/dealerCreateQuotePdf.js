import { LightningElement, api, track } from 'lwc';

/**
 * Entry button that opens dealerQuotePdfModal (LWC-only PDF flow, no Visualforce).
 */
export default class DealerCreateQuotePdf extends LightningElement {
    @api quoteId;

    @track isOpen = false;

    get isDisabled() {
        return !this.quoteId;
    }

    handleCreatePdf() {
        if (!this.quoteId) {
            return;
        }
        // Defer open so the same mouse click does not hit the modal overlay and close it.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => {
            this.isOpen = true;
        }, 0);
    }

    handleClose() {
        this.isOpen = false;
    }

    handlePdfSaved(event) {
        this.isOpen = false;
        this.dispatchEvent(
            new CustomEvent('pdfsaved', {
                detail: event.detail || { quoteId: this.quoteId }
            })
        );
    }
}