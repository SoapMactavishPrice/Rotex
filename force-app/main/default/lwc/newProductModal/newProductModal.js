import { LightningElement, api, track } from 'lwc';
import createProduct from '@salesforce/apex/ProductController.createProduct';
import updateProduct from '@salesforce/apex/ProductController.updateProduct';
import getCurrencyPicklistValues from '@salesforce/apex/ProductController.getCurrencyPicklistValues';

const PORTAL_TOAST_DURATION_MS = 4000;

const EMPTY_ERRORS = {
    name: '',
    productCode: '',
    description: '',
    isActive: '',
    priceEntries: ''
};

let priceRowKey = 0;

function newPriceRow(defaults = {}) {
    priceRowKey += 1;
    const hasPrice =
        Object.prototype.hasOwnProperty.call(defaults, 'unitPrice') &&
        defaults.unitPrice != null &&
        defaults.unitPrice !== '';
    return {
        key: `price-${priceRowKey}`,
        currencyIsoCode: defaults.currencyIsoCode || 'INR',
        unitPrice: hasPrice ? String(defaults.unitPrice) : '1',
        validFrom: defaults.validFrom || '',
        validTo: defaults.validTo || ''
    };
}

export default class NewProductModal extends LightningElement {
    @api partnerAccountId;
    @api productRecord;

    @track isSaving = false;
    @track errors = { ...EMPTY_ERRORS };
    @track currencyOptions = [];
    @track priceRows = [newPriceRow({ currencyIsoCode: 'INR', unitPrice: 1 })];
    @track portalToastVisible = false;
    @track portalToastTitle = '';
    @track portalToastMessage = '';
    @track portalToastVariant = 'info';

    portalToastTimeout;
    productId = null;
    name = '';
    productCode = '';
    description = '';
    isActive = true;
    hsnCode = '';

    connectedCallback() {
        getCurrencyPicklistValues()
            .then((data) => {
                this.currencyOptions = data || [];
            })
            .catch(() => {
                this.currencyOptions = [
                    { label: 'INR', value: 'INR' },
                    { label: 'USD', value: 'USD' }
                ];
            });

        this.populateFromRecord(this.productRecord);
    }

    get isEditMode() {
        return !!(this.productId || this.productRecord?.id || this.productRecord?.Id);
    }

    get modalTitle() {
        return this.isEditMode ? 'Edit Product' : 'New Product';
    }

    get nameInputClass() {
        return this.errors.name ? 'form-input form-input-error' : 'form-input';
    }

    get productCodeInputClass() {
        return this.errors.productCode ? 'form-input form-input-error' : 'form-input';
    }

    get descriptionInputClass() {
        return this.errors.description ? 'form-input form-textarea form-input-error' : 'form-input form-textarea';
    }

    get activeValue() {
        return this.isActive ? 'true' : 'false';
    }

    get priceRowsView() {
        const total = this.priceRows.length;
        return this.priceRows.map((row, index) => ({
            ...row,
            showDelete: total > 1,
            isLast: index === total - 1,
            currencyOptions: (this.currencyOptions || []).map((opt) => ({
                label: opt.label,
                value: opt.value,
                selected: opt.value === (row.currencyIsoCode || 'INR')
            }))
        }));
    }

    populateFromRecord(record) {
        if (!record) {
            this.priceRows = [newPriceRow({ currencyIsoCode: 'INR', unitPrice: 1 })];
            return;
        }
        this.productId = record.id || record.Id || null;
        this.name = record.name || record.Name || '';
        this.productCode = record.productCode || record.ProductCode || '';
        this.description = record.description || record.Description || '';
        this.isActive = record.isActive !== false && record.IsActive !== false;
        this.hsnCode = record.hsnCode || '';

        const entries = record.priceEntries || [];
        if (entries.length) {
            this.priceRows = entries.map((entry) =>
                newPriceRow({
                    currencyIsoCode: entry.currencyIsoCode || 'INR',
                    unitPrice: entry.unitPrice != null ? entry.unitPrice : 1,
                    validFrom: entry.validFrom || '',
                    validTo: entry.validTo || ''
                })
            );
        } else {
            this.priceRows = [newPriceRow({ currencyIsoCode: 'INR', unitPrice: 1 })];
        }
    }

    handleFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        if (!field) {
            return;
        }
        this[field] = event.target.value;
        if (this.errors[field]) {
            this.errors = { ...this.errors, [field]: '' };
        }
    }

    handleActiveChange(event) {
        this.isActive = event.target.value === 'true';
        this.errors = { ...this.errors, isActive: '' };
    }

    handlePriceFieldChange(event) {
        const key = event.currentTarget.dataset.key;
        const field = event.currentTarget.dataset.field;
        const value = event.target.value;
        this.priceRows = this.priceRows.map((row) =>
            row.key === key ? { ...row, [field]: value } : row
        );
        if (this.errors.priceEntries) {
            this.errors = { ...this.errors, priceEntries: '' };
        }
    }

    handleAddPriceRow() {
        this.priceRows = [
            ...this.priceRows,
            newPriceRow({ currencyIsoCode: 'INR', unitPrice: 1 })
        ];
    }

    handleRemovePriceRow(event) {
        const key = event.currentTarget.dataset.key;
        if (this.priceRows.length <= 1) {
            return;
        }
        this.priceRows = this.priceRows.filter((row) => row.key !== key);
    }

    validate() {
        const next = { ...EMPTY_ERRORS };
        let ok = true;
        if (!this.name || !this.name.trim()) {
            next.name = 'Product Name is required.';
            ok = false;
        }
        if (!this.productCode || !this.productCode.trim()) {
            next.productCode = 'Product Code is required.';
            ok = false;
        }
        if (!this.description || !this.description.trim()) {
            next.description = 'Product Description is required.';
            ok = false;
        }
        if (this.isActive !== true && this.isActive !== false) {
            next.isActive = 'Active is required.';
            ok = false;
        }

        const validPriceRows = (this.priceRows || []).filter(
            (row) => row.currencyIsoCode && row.unitPrice !== '' && row.unitPrice != null
        );
        if (!validPriceRows.length) {
            next.priceEntries = 'Add at least one price row with Currency and List Price.';
            ok = false;
        } else {
            const currencies = validPriceRows.map((row) => row.currencyIsoCode);
            if (new Set(currencies).size !== currencies.length) {
                next.priceEntries = 'Each Currency can only be used once.';
                ok = false;
            }
        }

        this.errors = next;
        return ok;
    }

    buildPriceEntries() {
        return (this.priceRows || [])
            .filter((row) => row.currencyIsoCode && row.unitPrice !== '' && row.unitPrice != null)
            .map((row) => ({
                currencyIsoCode: row.currencyIsoCode,
                unitPrice: Number(row.unitPrice),
                validFrom: row.validFrom || null,
                validTo: row.validTo || null
            }));
    }

    handleSave() {
        if (this.isSaving || !this.validate()) {
            return;
        }
        this.isSaving = true;
        const input = {
            productId: this.productId || null,
            name: this.name.trim(),
            productCode: this.productCode.trim(),
            description: this.description.trim(),
            isActive: this.isActive === true,
            hsnCode: this.hsnCode ? this.hsnCode.trim() : null,
            partnerAccountId: this.partnerAccountId,
            priceEntries: this.buildPriceEntries()
        };

        const action = this.isEditMode ? updateProduct : createProduct;
        action({ input })
            .then((saved) => {
                this.isSaving = false;
                this.dispatchEvent(
                    new CustomEvent('save', {
                        detail: saved,
                        bubbles: true,
                        composed: true
                    })
                );
                this.dispatchEvent(new CustomEvent('close', { bubbles: true, composed: true }));
            })
            .catch((error) => {
                this.isSaving = false;
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            });
    }

    handleClose() {
        if (this.isSaving) {
            return;
        }
        this.dispatchEvent(new CustomEvent('close', { bubbles: true, composed: true }));
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    get portalToastClass() {
        return `portal-toast portal-toast--${this.portalToastVariant || 'info'}`;
    }

    showToast(title, message, variant) {
        if (this.portalToastTimeout) {
            window.clearTimeout(this.portalToastTimeout);
        }
        this.portalToastTitle = title || 'Info';
        this.portalToastMessage = message || '';
        this.portalToastVariant = variant || 'info';
        this.portalToastVisible = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.portalToastTimeout = window.setTimeout(() => {
            this.portalToastVisible = false;
            this.portalToastTimeout = null;
        }, PORTAL_TOAST_DURATION_MS);
    }

    extractErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.body?.pageErrors?.length) {
            return error.body.pageErrors[0].message;
        }
        if (Array.isArray(error?.body) && error.body.length) {
            return error.body[0].message;
        }
        return error?.message || 'Unexpected error.';
    }
}