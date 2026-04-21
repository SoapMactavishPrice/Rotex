import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getFieldValue, getRecord, updateRecord } from 'lightning/uiRecordApi';

const CASE_REMARKS_FIELD = 'Case.Non_Potential_Remarks__c';
const CASE_STATUS_FIELD = 'Case.Status';
const CASE_FIELDS = [CASE_REMARKS_FIELD, CASE_STATUS_FIELD];
const NON_POTENTIAL_STATUS = 'Non Potential';
const POTENTIAL_STATUS = 'Potential';

export default class MarkCaseNonPotential extends NavigationMixin(LightningElement) {
    @api recordId;

    remarks = '';
    isSaving = false;
    hasLoadedInitialRemarks = false;
    caseStatus = '';

    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    wiredCase({ data, error }) {
        if (data && !this.hasLoadedInitialRemarks) {
            this.remarks = getFieldValue(data, CASE_REMARKS_FIELD) || '';
            this.caseStatus = getFieldValue(data, CASE_STATUS_FIELD) || '';
            this.hasLoadedInitialRemarks = true;
            if (this.caseStatus === POTENTIAL_STATUS || this.caseStatus === NON_POTENTIAL_STATUS) {
                this.showToast('Error', `Status already set to ${this.caseStatus}.`, 'error');
                this.closeAndNavigate();
                return;
            }
        } else if (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        }
    }

    handleRemarksChange(event) {
        this.remarks = event.target.value;
    }

    handleCancel() {
        this.closeAndNavigate();
    }

    async handleSave() {
        if (!this.recordId) {
            this.showToast('Error', 'Case record was not found.', 'error');
            return;
        }

        this.isSaving = true;

        try {
            await updateRecord({
                fields: {
                    Id: this.recordId,
                    Status: NON_POTENTIAL_STATUS,
                    Non_Potential_Remarks__c: this.remarks
                }
            });

            this.showToast('Success', 'Case updated successfully.', 'success');
            this.closeAndNavigate();
        } catch (error) {
            this.isSaving = false;
            this.showToast('Error', this.reduceError(error), 'error');
        }
    }

    closeAndNavigate() {
        this.dispatchEvent(new CloseActionScreenEvent());

        window.setTimeout(() => {
            this[NavigationMixin.Navigate](
                {
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: this.recordId,
                        objectApiName: 'Case',
                        actionName: 'view'
                    }
                },
                true
            );
        }, 150);
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

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item.message).join(', ');
        }

        return error?.body?.message || error?.message || 'Something went wrong.';
    }
}
