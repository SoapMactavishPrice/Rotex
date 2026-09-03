import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';

import getMyProducts from '@salesforce/apex/ProductController.getMyProducts';
import getProductById from '@salesforce/apex/ProductController.getProductById';
import getRotexProductExtras from '@salesforce/apex/ProductController.getRotexProductExtras';
import getMyChannelPartnerAccountId from '@salesforce/apex/ProductController.getMyChannelPartnerAccountId';
import findProductsOptimizedForAccount from '@salesforce/apex/DealerAddProductQuote.findProductsOptimizedForAccount';

const PORTAL_TOAST_DURATION_MS = 4000;

const ITEM_TYPE_OPTIONS = [
    { label: '--None--', value: '' },
    { label: 'Spares / Special', value: 'Spares / Special' },
    { label: 'Coil', value: 'Coil' },
    { label: 'SOV (0-15000)', value: 'SOV (0-15000)' },
    { label: 'SOV (15001-30000)', value: 'SOV (15001-30000)' },
    { label: 'SOV (30001-45000)', value: 'SOV (30001-45000)' },
    { label: 'SOV (45001-60000)', value: 'SOV (45001-60000)' },
    { label: 'Valve', value: 'Valve' },
    { label: 'Others', value: 'Others' }
];

export default class DealerProducts extends LightningElement {
    @track nonRotexProducts = [];
    @track rotexProducts = [];
    @track selectedProduct = null;
    @track editingProduct = null;
    @track showProductModal = false;
    @track partnerAccountId = null;
    @track portalToastVisible = false;
    @track portalToastTitle = '';
    @track portalToastMessage = '';
    @track portalToastVariant = 'info';
    @track isLoadingRotex = false;

    /** 'rotex' | 'nonRotex' — Non-Rotex = CP-created products (existing page). */
    productSourceTab = 'nonRotex';
    /** Applied only when Search button is clicked. */
    searchKey = '';
    selectedStatus = 'All';
    selectedItemType = '';
    itemTypeOptions = ITEM_TYPE_OPTIONS;
    wiredProductsResult;
    portalToastTimeout;
    rotexLoadToken = 0;
    /** Latest typed text in the search box (DOM only until commit). */
    _pendingSearch = '';

    connectedCallback() {
        this._boundShowList = () => this.backToList();
        window.addEventListener('portalshowlist', this._boundShowList);
    }

    disconnectedCallback() {
        if (this._boundShowList) {
            window.removeEventListener('portalshowlist', this._boundShowList);
        }
        if (this.portalToastTimeout) {
            window.clearTimeout(this.portalToastTimeout);
        }
    }

    @wire(getMyChannelPartnerAccountId)
    wiredPartner({ data }) {
        if (data) {
            this.partnerAccountId = data;
            if (this.isRotexTab && this.selectedItemType) {
                this.loadRotexProducts();
            }
        }
    }

    @wire(getMyProducts)
    wiredProducts(result) {
        this.wiredProductsResult = result;
        if (result.data) {
            this.nonRotexProducts = (result.data || []).map((p) => this.mapNonRotexProduct(p));
            if (this.selectedProduct && this.isNonRotexTab) {
                const refreshed = this.nonRotexProducts.find(
                    (row) => row.id === this.selectedProduct.id
                );
                this.selectedProduct = refreshed || null;
            }
        } else if (result.error) {
            this.nonRotexProducts = [];
            this.showToast('Error', this.extractErrorMessage(result.error), 'error');
        }
    }

    get itemTypeOptionsView() {
        return (this.itemTypeOptions || []).map((opt) => ({
            ...opt,
            selected: opt.value === this.selectedItemType
        }));
    }

    get listViewClass() {
        return this.selectedProduct ? 'list-view list-view--hidden' : 'list-view';
    }

    get isRotexTab() {
        return this.productSourceTab === 'rotex';
    }

    get isNonRotexTab() {
        return this.productSourceTab === 'nonRotex';
    }

    get rotexTabClass() {
        return this.isRotexTab ? 'pill-tab pill-tab_active' : 'pill-tab';
    }

    get nonRotexTabClass() {
        return this.isNonRotexTab ? 'pill-tab pill-tab_active' : 'pill-tab';
    }

    get products() {
        return this.isRotexTab ? this.rotexProducts : this.nonRotexProducts;
    }

    get showRotexItemTypePrompt() {
        return this.isRotexTab && !this.selectedItemType && !this.isLoadingRotex;
    }

    get tableHeaderClass() {
        return this.isRotexTab ? 'table-header table-header--rotex' : 'table-header';
    }

    get tableRowClass() {
        return this.isRotexTab ? 'table-row table-row--rotex' : 'table-row';
    }

    get emptyStateMessage() {
        return this.isRotexTab
            ? 'No Rotex products found.'
            : 'No products found for your Channel Partner account.';
    }

    get canEditSelectedProduct() {
        return this.selectedProduct && this.selectedProduct.isRotex !== true;
    }

    mapNonRotexProduct(p) {
        const isActive = p.isActive === true;
        const priceEntries = p.priceEntries || [];
        const mapped = {
            ...p,
            rowKey: p.id,
            isRotex: false,
            statusDisplay: isActive ? 'Active' : 'Inactive',
            statusBadgeClass: isActive
                ? 'status-badge status-active'
                : 'status-badge status-inactive',
            descriptionDisplay: this.displayOrNotSet(p.description),
            hsnDisplay: this.displayOrNotSet(p.hsnCode),
            productCodeDisplay: this.displayOrNotSet(p.productCode),
            descriptionClass: this.valueClass(p.description),
            hsnClass: this.valueClass(p.hsnCode),
            productCodeClass: this.valueClass(p.productCode),
            hasPriceEntries: priceEntries.length > 0,
            priceEntriesView: priceEntries.map((entry, index) => ({
                key: entry.id || `pe-${index}`,
                currencyIsoCode: entry.currencyIsoCode || '—',
                unitPriceDisplay:
                    entry.unitPrice == null
                        ? '—'
                        : Number(entry.unitPrice).toLocaleString('en-IN', {
                              minimumFractionDigits: 2,
                              maximumFractionDigits: 2
                          }),
                validFromDisplay: this.formatDateDisplay(entry.validFrom),
                validToDisplay: this.formatDateDisplay(entry.validTo)
            })),
            createdDate: p.createdDate
                ? new Date(p.createdDate).toLocaleDateString('en-GB', {
                      day: '2-digit',
                      month: 'short',
                      year: 'numeric'
                  })
                : '—'
        };
        mapped.searchBlob = this.buildSearchBlob(mapped);
        return mapped;
    }

    mapRotexProduct(pw, index) {
        const listPrice = pw.ListPrice != null ? pw.ListPrice : pw.Price;
        const isObsolete = pw.Status === 'Z1' || pw.Status === 'Z2';
        const isActive = !isObsolete;
        const productId = pw.Product2Id || pw.Id;
        const mapped = {
            id: productId,
            rowKey: `${productId}-${pw.Id || index}`,
            isRotex: true,
            name: pw.Name || '',
            productCode: pw.ProductCode || '',
            description: pw.Description || '',
            hsnCode: pw.hsnMasterCode || '',
            itemType: pw.itemType || '',
            itemTypeDisplay: pw.itemType || '—',
            currencyIsoCode: pw.CurrencyIsoCode || '—',
            listPrice,
            listPriceDisplay:
                listPrice == null
                    ? '—'
                    : Number(listPrice).toLocaleString('en-IN', {
                          minimumFractionDigits: 2,
                          maximumFractionDigits: 2
                      }),
            isActive,
            statusDisplay: isActive ? 'Active' : 'Inactive',
            statusBadgeClass: isActive
                ? 'status-badge status-active'
                : 'status-badge status-inactive',
            descriptionDisplay: this.displayOrNotSet(pw.Description),
            hsnDisplay: this.displayOrNotSet(pw.hsnMasterCode),
            productCodeDisplay: this.displayOrNotSet(pw.ProductCode),
            descriptionClass: this.valueClass(pw.Description),
            hsnClass: this.valueClass(pw.hsnMasterCode),
            productCodeClass: this.valueClass(pw.ProductCode),
            hasPriceEntries: listPrice != null,
            priceEntriesView: [
                {
                    key: `rotex-pe-${index}`,
                    currencyIsoCode: pw.CurrencyIsoCode || '—',
                    unitPriceDisplay:
                        listPrice == null
                            ? '—'
                            : Number(listPrice).toLocaleString('en-IN', {
                                  minimumFractionDigits: 2,
                                  maximumFractionDigits: 2
                              }),
                    validFromDisplay: '—',
                    validToDisplay: '—'
                }
            ],
            createdDate: '—'
        };
        mapped.searchBlob = this.buildSearchBlob(mapped);
        return mapped;
    }

    buildSearchBlob(p) {
        return [p.name, p.productCode, p.description, p.hsnCode, p.itemType, p.currencyIsoCode]
            .filter((v) => v != null && String(v).trim() !== '')
            .join(' ')
            .toLowerCase();
    }

    formatDateDisplay(value) {
        if (!value) {
            return '—';
        }
        try {
            return new Date(value).toLocaleDateString('en-GB', {
                day: '2-digit',
                month: 'short',
                year: 'numeric'
            });
        } catch (e) {
            return value;
        }
    }

    displayOrNotSet(value) {
        return value && String(value).trim() ? value : 'Not set';
    }

    valueClass(value) {
        return value && String(value).trim()
            ? 'info-row-value'
            : 'info-row-value value-empty';
    }

    get filteredProducts() {
        const key = (this.searchKey || '').trim().toLowerCase();
        const list = this.products || [];
        if (!key && this.isRotexTab) {
            return list;
        }
        return list.filter((p) => {
            if (this.isNonRotexTab) {
                if (this.selectedStatus === 'Active' && p.isActive !== true) {
                    return false;
                }
                if (this.selectedStatus === 'Inactive' && p.isActive === true) {
                    return false;
                }
            }
            if (!key) {
                return true;
            }
            const blob = p.searchBlob || this.buildSearchBlob(p);
            return blob.includes(key);
        });
    }

    get hasProducts() {
        return this.filteredProducts.length > 0;
    }

    get totalCount() {
        return this.nonRotexProducts.length;
    }

    get activeCount() {
        return this.nonRotexProducts.filter((p) => p.isActive === true).length;
    }

    get inactiveCount() {
        return this.nonRotexProducts.filter((p) => p.isActive !== true).length;
    }

    get allTabClass() {
        return this.selectedStatus === 'All' ? 'tab active' : 'tab';
    }

    get activeTabClass() {
        return this.selectedStatus === 'Active' ? 'tab active' : 'tab';
    }

    get inactiveTabClass() {
        return this.selectedStatus === 'Inactive' ? 'tab active' : 'tab';
    }

    handleProductSourceTab(event) {
        const tab = event.currentTarget.dataset.tab;
        if (!tab || tab === this.productSourceTab) {
            return;
        }
        this.productSourceTab = tab;
        this.selectedProduct = null;
        this.clearSearchField();
        if (this.isRotexTab) {
            if (this.selectedItemType) {
                this.loadRotexProducts();
            } else {
                this.rotexProducts = [];
            }
        }
    }

    clearSearchField() {
        this._pendingSearch = '';
        this.searchKey = '';
        // Uncontrolled input — clear DOM without binding value (keeps typing smooth)
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        Promise.resolve().then(() => {
            const el = this.template.querySelector('.search-input');
            if (el) {
                el.value = '';
            }
        });
    }

    handleItemTypeChange(event) {
        this.selectedItemType = event.target.value || '';
        if (this.isRotexTab) {
            if (this.selectedItemType) {
                this.loadRotexProducts();
            } else {
                this.rotexProducts = [];
            }
        }
    }

    async loadRotexProducts() {
        if (!this.partnerAccountId) {
            this.rotexProducts = [];
            this.showToast(
                'Error',
                'Channel Partner account could not be resolved for Rotex products.',
                'error'
            );
            return;
        }
        if (!this.selectedItemType) {
            this.rotexProducts = [];
            return;
        }

        const token = ++this.rotexLoadToken;
        this.isLoadingRotex = true;
        try {
            const chunks = await findProductsOptimizedForAccount({
                accountId: this.partnerAccountId,
                searchKey: (this.searchKey || '').trim(),
                itemType: this.selectedItemType
            });
            if (token !== this.rotexLoadToken) {
                return;
            }
            let allProducts = [];
            for (const chunkStr of chunks || []) {
                const chunkObj = JSON.parse(chunkStr);
                if (chunkObj.error) {
                    throw new Error(chunkObj.error);
                }
                if (chunkObj.productList && Array.isArray(chunkObj.productList)) {
                    allProducts = allProducts.concat(chunkObj.productList);
                }
            }
            this.rotexProducts = allProducts.map((pw, index) => this.mapRotexProduct(pw, index));
        } catch (error) {
            if (token !== this.rotexLoadToken) {
                return;
            }
            this.rotexProducts = [];
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            if (token === this.rotexLoadToken) {
                this.isLoadingRotex = false;
            }
        }
    }

    handleSearchInput(event) {
        // Typing only — search runs when Search button is clicked.
        this._pendingSearch = event.target.value || '';
    }

    handleSearchKeydown(event) {
        // Enter triggers the same action as the Search button
        if (event.key === 'Enter') {
            event.preventDefault();
            this.handleSearchClick();
        }
    }

    handleSearchClick() {
        this.commitSearch();
    }

    /**
     * Apply search only from Search button (or Enter in the field).
     * Defers heavy list re-render so the UI stays smooth.
     */
    commitSearch() {
        const el = this.template.querySelector('.search-input');
        if (el) {
            this._pendingSearch = el.value || '';
        }
        const next = this._pendingSearch != null ? this._pendingSearch : '';
        if (next === this.searchKey) {
            // Same key: still re-run Rotex so user can force refresh
            if (this.isRotexTab && this.selectedItemType) {
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                window.requestAnimationFrame(() => this.loadRotexProducts());
            }
            return;
        }

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.requestAnimationFrame(() => {
            this.searchKey = next;
            if (this.isRotexTab && this.selectedItemType) {
                this.loadRotexProducts();
            }
        });
    }

    handleStatusFilter(event) {
        this.selectedStatus = event.currentTarget.dataset.status || 'All';
    }

    openProductDetail(event) {
        const id = event.currentTarget.dataset.id;
        if (this.isRotexTab) {
            const base =
                this.rotexProducts.find((p) => p.id === id) ||
                this.filteredProducts.find((p) => p.id === id) ||
                null;
            if (!base) {
                this.selectedProduct = null;
                return;
            }
            this.selectedProduct = { ...base };
            const product2Id = base.product2Id || base.id;
            getRotexProductExtras({ product2Id })
                .then((extras) => {
                    if (!this.selectedProduct || this.selectedProduct.id !== base.id) {
                        return;
                    }
                    const description =
                        extras?.description || this.selectedProduct.description || '';
                    const hsnCode = extras?.hsnCode || this.selectedProduct.hsnCode || '';
                    this.selectedProduct = {
                        ...this.selectedProduct,
                        description,
                        hsnCode,
                        descriptionDisplay: this.displayOrNotSet(description),
                        hsnDisplay: this.displayOrNotSet(hsnCode),
                        descriptionClass: this.valueClass(description),
                        hsnClass: this.valueClass(hsnCode)
                    };
                })
                .catch(() => {
                    /* keep list data if extras fail */
                });
            return;
        }
        getProductById({ productId: id })
            .then((data) => {
                this.selectedProduct = this.mapNonRotexProduct(data);
            })
            .catch((error) => {
                this.selectedProduct = this.nonRotexProducts.find((p) => p.id === id) || null;
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            });
    }

    backToList() {
        this.selectedProduct = null;
    }

    handleCreateProduct() {
        this.editingProduct = null;
        this.showProductModal = true;
    }

    handleEditProduct() {
        if (!this.selectedProduct?.id || this.selectedProduct.isRotex) {
            return;
        }
        getProductById({ productId: this.selectedProduct.id })
            .then((data) => {
                this.editingProduct = this.mapNonRotexProduct(data);
                this.showProductModal = true;
            })
            .catch((error) => {
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            });
    }

    closeProductModal() {
        this.showProductModal = false;
        this.editingProduct = null;
    }

    stopProductModalBubble(event) {
        event.stopPropagation();
    }

    handleProductSaved(event) {
        const saved = event.detail;
        const wasEdit = !!this.editingProduct;
        this.showProductModal = false;
        this.editingProduct = null;
        this.productSourceTab = 'nonRotex';
        this.showToast(
            'Success',
            wasEdit ? 'Product updated successfully.' : 'Product created successfully.',
            'success'
        );
        refreshApex(this.wiredProductsResult).then(() => {
            if (saved?.id) {
                getProductById({ productId: saved.id })
                    .then((data) => {
                        this.selectedProduct = this.mapNonRotexProduct(data);
                    })
                    .catch(() => {
                        const row = this.nonRotexProducts.find((p) => p.id === saved.id);
                        if (row) {
                            this.selectedProduct = row;
                        }
                    });
            }
        });
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
        if (Array.isArray(error?.body) && error.body.length) {
            return error.body[0].message;
        }
        return error?.message || 'Unexpected error.';
    }
}