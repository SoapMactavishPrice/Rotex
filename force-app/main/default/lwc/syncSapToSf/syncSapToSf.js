import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import syncCustomer from '@salesforce/apex/SyncSapToSf.syncCustomer';
import getMaterialMaster from '@salesforce/apex/SyncSapToSf.getMaterialMaster';

export default class SyncSapToSf extends LightningElement {
    customerCode = '';
    materialCode = '';
    isCustomerLoading = false;
    isMaterialLoading = false;

    get isCustomerButtonDisabled() {
        return this.isCustomerLoading || !this.customerCode.trim();
    }

    get isMaterialButtonDisabled() {
        return this.isMaterialLoading || !this.materialCode.trim();
    }

    handleCustomerCodeChange(event) {
        this.customerCode = event.target.value;
    }

    handleMaterialCodeChange(event) {
        this.materialCode = event.target.value;
    }

    async handleGetCustomer() {
        await this.runSync({
            loadingProperty: 'isCustomerLoading',
            action: () => syncCustomer({ customerCode: this.customerCode.trim() }),
            successTitle: 'Customer synced'
        });
    }

    async handleGetMaterial() {
        await this.runSync({
            loadingProperty: 'isMaterialLoading',
            action: () => getMaterialMaster({ materialCode: this.materialCode.trim() }),
            successTitle: 'Material synced'
        });
    }

    async runSync({ loadingProperty, action, successTitle }) {
        this[loadingProperty] = true;

        try {
            const result = await action();
            const variant = result?.variant || 'success';
            const title = variant === 'info' ? 'Already present' : successTitle;
            this.showToast(title, result?.message || 'Sync completed.', variant);
        } catch (error) {
            console.error(JSON.parse(JSON.stringify(error)));
            this.showToast('Sync failed', this.getErrorMessage(error), 'error');
        } finally {
            this[loadingProperty] = false;
        }
    }

    getErrorMessage(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item.message).join(', ');
        }

        return error?.body?.message || error?.message || 'Unexpected error while syncing.';
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
}
