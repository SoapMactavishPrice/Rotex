import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getResubmittableApprovals from '@salesforce/apex/QuoteApprovalResubmitController.getResubmittableApprovals';
import resubmitApprovals from '@salesforce/apex/QuoteApprovalResubmitController.resubmitApprovals';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

export default class QuoteApprovalResubmit extends LightningElement {
    @api recordId;

    isLoading = true;
    isSubmitting = false;
    options = [];
    selectedApprovalTypes = [];

    @wire(getResubmittableApprovals, { quoteId: '$recordId' })
    wiredResubmittableApprovals({ data, error }) {
        this.isLoading = false;

        if (data) {
            this.options = data.options || [];
            this.selectedApprovalTypes = this.options.length === 1 ? [this.options[0].value] : [];
        } else if (error) {
            this.options = [];
            this.showToast('Error', this.getErrorMessage(error), 'error');
        }
    }

    get hasOptions() {
        return this.options.length > 0;
    }

    get checkboxOptions() {
        return this.options.map((option) => ({
            label: option.label,
            value: option.value
        }));
    }

    get isSubmitDisabled() {
        return this.isLoading || this.isSubmitting || this.selectedApprovalTypes.length === 0;
    }

    handleApprovalTypeChange(event) {
        this.selectedApprovalTypes = event.detail.value;
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleSubmit() {
        this.isSubmitting = true;

        resubmitApprovals({
            quoteId: this.recordId,
            approvalTypes: this.selectedApprovalTypes
        })
            .then(async () => {
                await notifyRecordUpdateAvailable([
                    { recordId: this.recordId }
                ]);

                this.showToast('Success', 'Approval resubmitted successfully.', 'success');
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch((error) => {
                this.showToast('Error', this.getErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isSubmitting = false;
            });
    }

    getErrorMessage(error) {
        return error?.body?.message || error?.message || 'Something went wrong.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}