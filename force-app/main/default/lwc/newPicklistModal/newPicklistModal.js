import { LightningElement, api, track } from 'lwc';

import getMyChannelPartnerAccountId from '@salesforce/apex/DealerPicklistController.getMyChannelPartnerAccountId';
import getMyChannelPartnerAccountName from '@salesforce/apex/DealerPicklistController.getMyChannelPartnerAccountName';
import getCurrentUserName from '@salesforce/apex/DealerPicklistController.getCurrentUserName';
import searchSecondaryCustomers from '@salesforce/apex/DealerPicklistController.searchSecondaryCustomers';
import getAvailableInventoryProducts from '@salesforce/apex/DealerPicklistController.getAvailableInventoryProducts';
import createPicklist from '@salesforce/apex/DealerPicklistController.createPicklist';

const STEPS = { HEADER: 1, PRODUCTS: 2, CART: 3 };
const PAGE_SIZE = 10;

const PRODUCT_COLUMNS = [
    {
        label: 'Product Name',
        fieldName: 'Name',
        type: 'text',
        wrapText: true
    },
    { label: 'Product Code', fieldName: 'ProductCode', type: 'text' },
    {
        label: 'Available Qty',
        fieldName: 'AvailableQuantity',
        type: 'number',
        cellAttributes: { alignment: 'left' }
    }
];

export default class NewPicklistModal extends LightningElement {
    @api isOpen = false;

    step = STEPS.HEADER;
    isSaving = false;
    isLoadingProducts = false;

    partnerAccountId = null;
    partnerAccountName = '';
    ownerName = '';
    picklistNumberDisplay = 'Auto-generated';

    secondaryCustomerId = null;
    secondaryCustomerName = '';
    secondarySearch = '';
    @track customerResults = [];
    showCustomerDropdown = false;

    pickListDate = '';
    requestedDeliveryDate = '';
    remarks = '';

    @track errors = {};

    searchKey = '';
    searchDisabled = false;
    pageNumber = 1;
    totalPages = 1;
    totalCount = 0;
    productColumns = PRODUCT_COLUMNS;
    @track tableData = [];
    @track selectedKeys = [];
    @track cartItems = [];

    @track portalToastVisible = false;
    @track portalToastTitle = '';
    @track portalToastMessage = '';
    @track portalToastVariant = 'info';
    portalToastTimeout;

    /** inventoryId -> product payload (for multi-page selection + cart). */
    productCache = {};
    typingTimeout;

    connectedCallback() {
        this.bootstrap();
    }

    async bootstrap() {
        try {
            const [partnerId, partnerName, userName] = await Promise.all([
                getMyChannelPartnerAccountId(),
                getMyChannelPartnerAccountName(),
                getCurrentUserName()
            ]);
            this.partnerAccountId = partnerId;
            this.partnerAccountName = partnerName || '';
            this.ownerName = userName || '';
            if (!this.pickListDate) {
                this.pickListDate = this.toInputDate(new Date());
            }
        } catch (e) {
            // leave defaults
        }
    }

    @api
    open() {
        this.resetForm();
        this.isOpen = true;
        this.bootstrap();
    }

    resetForm() {
        this.step = STEPS.HEADER;
        this.isSaving = false;
        this.isLoadingProducts = false;
        this.secondaryCustomerId = null;
        this.secondaryCustomerName = '';
        this.secondarySearch = '';
        this.customerResults = [];
        this.showCustomerDropdown = false;
        this.pickListDate = this.toInputDate(new Date());
        this.requestedDeliveryDate = '';
        this.remarks = '';
        this.errors = {};
        this.searchKey = '';
        this.searchDisabled = false;
        this.pageNumber = 1;
        this.totalPages = 1;
        this.totalCount = 0;
        this.tableData = [];
        this.selectedKeys = [];
        this.cartItems = [];
        this.productCache = {};
        this.portalToastVisible = false;
        if (this.portalToastTimeout) {
            window.clearTimeout(this.portalToastTimeout);
            this.portalToastTimeout = null;
        }
        if (this.typingTimeout) {
            clearTimeout(this.typingTimeout);
            this.typingTimeout = null;
        }
    }

    get isStepHeader() {
        return this.step === STEPS.HEADER;
    }
    get isStepProducts() {
        return this.step === STEPS.PRODUCTS;
    }
    get isStepCart() {
        return this.step === STEPS.CART;
    }

    get modalTitle() {
        if (this.isStepProducts) {
            return 'Add Products';
        }
        if (this.isStepCart) {
            return 'Edit Selected Products';
        }
        return 'New Pick List';
    }

    get modalFooterClass() {
        return this.isStepProducts ? 'modal-footer' : 'modal-footer modal-footer--end';
    }

    get modalContainerClass() {
        return this.isStepHeader
            ? 'modal-container'
            : this.isStepCart
              ? 'modal-container modal-container--wide modal-container--cart'
              : 'modal-container modal-container--wide';
    }

    get channelPartnerDisplay() {
        return this.partnerAccountName || '—';
    }

    get hasCustomerResults() {
        return this.customerResults && this.customerResults.length > 0;
    }

    get hasCartItems() {
        return this.cartItems && this.cartItems.length > 0;
    }

    get pageInfo() {
        return `Page ${this.pageNumber} of ${this.totalPages} | Total: ${this.totalCount}`;
    }

    get isFirstPageDisabled() {
        return this.pageNumber <= 1 || this.isLoadingProducts;
    }

    get isLastPageDisabled() {
        return this.pageNumber >= this.totalPages || this.isLoadingProducts;
    }

    get canAddToCart() {
        return this.selectedKeys.length > 0;
    }

    get addToCartDisabled() {
        return !this.canAddToCart;
    }

    get showViewCart() {
        return this.cartItems.length > 0;
    }

    get saveDisabled() {
        return this.isSaving || !this.hasCartItems;
    }

    get portalToastClass() {
        return `portal-toast portal-toast--${this.portalToastVariant || 'info'}`;
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleClose() {
        if (this.isSaving) {
            return;
        }
        this.isOpen = false;
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleBackdropClick() {
        this.handleClose();
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

    async handleCustomerSearch(event) {
        this.secondarySearch = event.target.value || '';
        this.secondaryCustomerId = null;
        this.secondaryCustomerName = '';
        await this.runCustomerSearch();
    }

    async handleCustomerFocus() {
        this.showCustomerDropdown = true;
        if (!this.customerResults.length) {
            await this.runCustomerSearch();
        }
    }

    async runCustomerSearch() {
        try {
            const rows = await searchSecondaryCustomers({ searchText: this.secondarySearch });
            this.customerResults = rows || [];
            this.showCustomerDropdown = true;
        } catch (e) {
            this.customerResults = [];
        }
    }

    handleSelectCustomer(event) {
        const id = event.currentTarget.dataset.id;
        const label = event.currentTarget.dataset.label;
        this.secondaryCustomerId = id;
        this.secondaryCustomerName = label;
        this.secondarySearch = label;
        this.showCustomerDropdown = false;
        this.errors = { ...this.errors, secondaryCustomer: '' };
    }

    clearSecondaryCustomer() {
        this.secondaryCustomerId = null;
        this.secondaryCustomerName = '';
        this.secondarySearch = '';
    }

    validateHeader() {
        const next = {};
        if (!this.pickListDate) {
            next.pickListDate = 'Pick List Date is required.';
        }
        this.errors = next;
        return Object.keys(next).length === 0;
    }

    async handleNextFromHeader() {
        if (!this.validateHeader()) {
            return;
        }
        this.step = STEPS.PRODUCTS;
        this.searchKey = '';
        this.searchDisabled = false;
        this.pageNumber = 1;
        this.selectedKeys = [];
        this.productCache = {};
        await this.loadProducts();
    }

    handleBackToHeader() {
        this.step = STEPS.HEADER;
    }

    handleSearchKeyup(event) {
        this.searchKey = event.target.value || '';
        clearTimeout(this.typingTimeout);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.typingTimeout = setTimeout(() => {
            this.pageNumber = 1;
            this.loadProducts();
        }, 500);
    }

    async loadProducts() {
        this.isLoadingProducts = true;
        try {
            const page = await getAvailableInventoryProducts({
                itemType: null,
                searchKey: this.searchKey || null,
                pageNumber: this.pageNumber,
                pageSize: PAGE_SIZE
            });
            const rows = page.products || [];
            rows.forEach((p) => {
                this.productCache[p.inventoryId] = p;
            });
            this.tableData = rows.map((p) => ({
                Id: p.inventoryId,
                Name: p.productName || '',
                ProductCode: p.productCode || '',
                AvailableQuantity: p.availableQty
            }));
            this.totalCount = page.totalCount || 0;
            this.totalPages = page.totalPages || 1;
            this.pageNumber = page.pageNumber || 1;
            this.searchDisabled = false;
        } catch (e) {
            this.tableData = [];
            this.searchDisabled = false;
            this.showError(this.extractError(e));
        } finally {
            this.isLoadingProducts = false;
        }
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows || [];
        const currentPageIds = this.tableData.map((r) => r.Id);
        const selectedOnPage = new Set(selectedRows.map((r) => r.Id));

        const next = new Set(this.selectedKeys);
        currentPageIds.forEach((id) => {
            if (selectedOnPage.has(id)) {
                next.add(id);
            } else {
                next.delete(id);
            }
        });
        this.selectedKeys = Array.from(next);
    }

    handleAddToCart() {
        if (!this.canAddToCart) {
            this.showError('Please select at least one product.');
            return;
        }
        const cartMap = new Map(this.cartItems.map((c) => [c.inventoryId, c]));
        let added = 0;
        let duplicate = 0;

        this.selectedKeys.forEach((id) => {
            if (cartMap.has(id)) {
                duplicate += 1;
                return;
            }
            const p = this.productCache[id];
            if (!p) {
                return;
            }
            cartMap.set(id, {
                inventoryId: p.inventoryId,
                productId: p.productId,
                productName: p.productName,
                productCode: p.productCode || '',
                availableQty: p.availableQty || 0,
                pickQuantity: 1,
                remarks: '',
                remainingQty: (p.availableQty || 0) - 1
            });
            added += 1;
        });

        this.cartItems = Array.from(cartMap.values()).map((c) => this.refreshCartRow(c));
        this.selectedKeys = [];
        this.clearDatatableSelection();

        if (added === 0 && duplicate > 0) {
            this.showError(
                duplicate === 1
                    ? 'This product is already in your cart.'
                    : 'The selected products are already in your cart.'
            );
            return;
        }
        if (added > 0) {
            this.showSuccess(
                added === 1
                    ? 'Product has been added to cart.'
                    : `${added} products have been added to cart.`
            );
        }
    }

    clearDatatableSelection() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const datatable = this.template.querySelector('[data-id="datatable"]');
            if (datatable) {
                datatable.selectedRows = [];
            }
        }, 0);
    }

    handleViewCart() {
        if (!this.hasCartItems) {
            this.showError('Add products to cart first.');
            return;
        }
        this.step = STEPS.CART;
    }

    handleBackToProducts() {
        this.step = STEPS.PRODUCTS;
    }

    handlePickQtyChange(event) {
        const id = event.currentTarget.dataset.id;
        const value =
            event.detail && event.detail.value !== undefined ? event.detail.value : event.target.value;
        this.cartItems = this.cartItems.map((c) => {
            if (c.inventoryId !== id) {
                return c;
            }
            const qty = value === '' || value == null ? '' : Number(value);
            return this.refreshCartRow({ ...c, pickQuantity: qty });
        });
    }

    handleRemarkChange(event) {
        const id = event.currentTarget.dataset.id;
        const value =
            event.detail && event.detail.value !== undefined
                ? event.detail.value
                : event.target.value || '';
        this.cartItems = this.cartItems.map((c) =>
            c.inventoryId === id ? { ...c, remarks: value } : c
        );
    }

    handleRemoveCartItem(event) {
        const id = event.currentTarget.dataset.id;
        this.cartItems = this.cartItems.filter((c) => c.inventoryId !== id);
        if (!this.cartItems.length) {
            this.step = STEPS.PRODUCTS;
        }
    }

    refreshCartRow(row) {
        const available = Number(row.availableQty) || 0;
        const pick =
            row.pickQuantity === '' || row.pickQuantity == null ? 0 : Number(row.pickQuantity);
        return {
            ...row,
            availableQtyDisplay: this.formatNumber(available),
            remainingQty: available - (isNaN(pick) ? 0 : pick),
            remainingQtyDisplay: this.formatNumber(available - (isNaN(pick) ? 0 : pick)),
            qtyError:
                isNaN(pick) || pick <= 0
                    ? 'Required'
                    : pick > available
                      ? 'Exceeds available'
                      : ''
        };
    }

    validateCart() {
        if (!this.cartItems.length) {
            this.showError('Add at least one product.');
            return false;
        }
        let valid = true;
        this.cartItems = this.cartItems.map((c) => {
            const row = this.refreshCartRow(c);
            if (row.qtyError) {
                valid = false;
            }
            return row;
        });
        return valid;
    }

    async handleSave() {
        if (this.isSaving || !this.validateCart()) {
            return;
        }
        this.isSaving = true;
        try {
            const payload = {
                secondaryCustomerId: this.secondaryCustomerId || null,
                channelPartnerId: this.partnerAccountId || null,
                pickListDate: this.pickListDate || null,
                requestedDeliveryDate: this.requestedDeliveryDate || null,
                remarks: this.remarks || null,
                lines: this.cartItems.map((c) => ({
                    inventoryId: c.inventoryId,
                    productId: c.productId,
                    pickQuantity: Number(c.pickQuantity),
                    remarks: c.remarks || null
                }))
            };
            const result = await createPicklist({ input: payload });
            this.dispatchEvent(
                new CustomEvent('saved', {
                    detail: {
                        picklistId: result.picklistId,
                        picklistNumber: result.picklistNumber
                    }
                })
            );
            this.isOpen = false;
            this.resetForm();
        } catch (e) {
            this.showError(this.extractError(e));
        } finally {
            this.isSaving = false;
        }
    }

    goFirstPage() {
        if (this.isFirstPageDisabled) return;
        this.pageNumber = 1;
        this.loadProducts();
    }

    goPrevPage() {
        if (this.isFirstPageDisabled) return;
        this.pageNumber -= 1;
        this.loadProducts();
    }

    goNextPage() {
        if (this.isLastPageDisabled) return;
        this.pageNumber += 1;
        this.loadProducts();
    }

    goLastPage() {
        if (this.isLastPageDisabled) return;
        this.pageNumber = this.totalPages;
        this.loadProducts();
    }

    toInputDate(dateObj) {
        const d = dateObj instanceof Date ? dateObj : new Date(dateObj);
        const yyyy = d.getFullYear();
        const mm = String(d.getMonth() + 1).padStart(2, '0');
        const dd = String(d.getDate()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}`;
    }

    formatNumber(value) {
        if (value === null || value === undefined || value === '') {
            return '0';
        }
        const n = Number(value);
        if (isNaN(n)) {
            return String(value);
        }
        return n.toLocaleString('en-IN');
    }

    extractError(error) {
        if (!error) {
            return 'Unexpected error.';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        return error.message || 'Unexpected error.';
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
        }, 4000);
    }

    showError(message) {
        this.showToast('Error', message || 'Something went wrong.', 'error');
    }

    showSuccess(message) {
        this.showToast('Success', message || 'Done.', 'success');
    }
}