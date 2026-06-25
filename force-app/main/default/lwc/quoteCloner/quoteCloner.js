import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import cloneQuoteWithLineItems from '@salesforce/apex/QuoteCloner.cloneQuoteWithLineItems';

export default class QuoteCloner extends NavigationMixin(LightningElement) {
    @api recordId;
    isLoading = false;

    handleClone() {
        if (!this.recordId) {
            this.showToast('Error', 'Quote Id is missing.', 'error');
            return;
        }

        this.isLoading = true;

        cloneQuoteWithLineItems({ quoteId: this.recordId })
            .then((clonedQuoteId) => {
                this.showToast('Success', 'Quote cloned successfully.', 'success');
                this.closeAction();
                this.navigateToQuote(clonedQuoteId);
            })
            .catch((error) => {
                this.showToast('Error', this.getErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleCancel() {
        this.closeAction();
    }

    navigateToQuote(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName: 'Quote',
                actionName: 'view'
            }
        });
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    getErrorMessage(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item.message).join(', ');
        }

        return error?.body?.message || error?.message || 'Something went wrong while cloning the quote.';
    }
}