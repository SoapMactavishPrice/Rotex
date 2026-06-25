import { LightningElement, api } from 'lwc';
import submitQuoteAndNotifyOwner from '@salesforce/apex/SubmitQuoteController.submitQuoteAndNotifyOwner';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from 'lightning/navigation';

export default class SubmitQuote extends NavigationMixin(LightningElement) {
    @api recordId;

    connectedCallback() {
        submitQuoteAndNotifyOwner({ quoteId: this.recordId })
            .then(()=>{
                this.showToast('Success', 'Quote submitted successfully', 'success' );
                this.goToQuote(this.recordId);
            })
            .catch(error => {
                this.showToast('Error', error?.body?.message, 'error' );
                this.goToQuote(this.recordId);
            })
    }

    goToQuote(result) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: result,
                actionName: 'view'
            }
        });
    }

    showToast(title, msg, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: msg,
            variant: variant
        });
        this.dispatchEvent(evt);
    }
}