import { LightningElement, api, track } from 'lwc';
import saveProducts from '@salesforce/apex/DealerAddProductQuote.saveProducts';
import getCustomerDiscount from '@salesforce/apex/DealerAddProductQuote.getCustomerDiscount';
import getCustomerDiscountForAccount from '@salesforce/apex/DealerAddProductQuote.getCustomerDiscountForAccount';
import findProductsOptimized from '@salesforce/apex/DealerAddProductQuote.findProductsOptimized';
import findProductsOptimizedForAccount from '@salesforce/apex/DealerAddProductQuote.findProductsOptimizedForAccount';
import findPartnerCreatedProductsForAccount from '@salesforce/apex/DealerAddProductQuote.findPartnerCreatedProductsForAccount';
import findInventoryProductsForAccount from '@salesforce/apex/DealerAddProductQuote.findInventoryProductsForAccount';

const PORTAL_TOAST_DURATION_MS = 4000;

const COLS = [
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
    },
    {
        label: 'List Price',
        fieldName: 'Price',
        type: 'currency',
        typeAttributes: { currencyCode: { fieldName: 'CurrencyIsoCode' } },
        cellAttributes: { alignment: 'left' }
    },
    {
        label: 'List Price',
        fieldName: 'ListPrice',
        type: 'currency',
        typeAttributes: { currencyCode: { fieldName: 'CurrencyIsoCode' } },
        cellAttributes: { alignment: 'left' }
    },
    { label: 'ARC', fieldName: 'IsARC', type: 'boolean', cellAttributes: { alignment: 'left' } }
];

export default class DealerAddProductModal extends LightningElement {
    cols = COLS;

    @api quoteId;
    @api accountId;
    /** Channel Partner / login account — used for Secondary Rotex catalogue (same as Self). */
    @api partnerAccountId;
    /** Quote Record Type Name/DeveloperName (e.g. ARC / Normal) — Secondary create/detail. */
    @api quoteRecordTypeName = '';
    @api createMode = false;
    @api embedded = false;
    @api usePartnerProducts = false;
    @api businessLine = '';
    @api quoteType = '';
    /** Parent-resolved: catalogue | partner | inventory | both */
    @api productMode = '';

    @track showSpinner = false;
    @track isSavingDraft = false;
    @track searchDisabled = true;
    @track recId;

    @api
    clearDraftSaving() {
        this.isSavingDraft = false;
        this.showSpinner = false;
    }

    get searchDisability() {
        return this.searchDisabled || this.showSpinner;
    }

    get normalizedBusinessLine() {
        return String(this.businessLine || '')
            .trim()
            .toUpperCase()
            .replace(/[-_]+/g, ' ')
            .replace(/\s+/g, ' ');
    }

    get normalizedQuoteType() {
        return String(this.quoteType || '')
            .trim()
            .toUpperCase()
            .replace(/[-_]+/g, ' ')
            .replace(/\s+/g, ' ');
    }

    get normalizedProductMode() {
        return String(this.productMode || '')
            .trim()
            .toLowerCase();
    }

    get isSelfQuote() {
        return this.normalizedQuoteType === 'SELF';
    }

    get isSecondaryQuote() {
        return this.normalizedQuoteType === 'SECONDARY CUSTOMER';
    }

    /** Secondary Customer + Quote Type ARC */
    get isArcQuoteRecordType() {
        if (!this.isSecondaryQuote) {
            return false;
        }
        const name = String(this.quoteRecordTypeName || '')
            .trim()
            .toUpperCase()
            .replace(/[-_]+/g, ' ')
            .replace(/\s+/g, ' ');
        return name === 'ARC' || name.includes('ARC');
    }

    get showSellPriceOfSc() {
        return this.isArcQuoteRecordType;
    }

    get reqDiscColumnLabel() {
        return this.isArcQuoteRecordType ? 'Disc. %' : 'Req Disc.';
    }

    get proposedArcPriceColumnLabel() {
        const currency =
            this.SelectedProductData?.[0]?.CurrencyIsoCode ||
            this.cartProducts?.[0]?.CurrencyIsoCode ||
            this.AllProductData?.[0]?.CurrencyIsoCode ||
            '';
        return currency
            ? `Proposed ARC Price (${currency})`
            : 'Proposed ARC Price';
    }

    get showProductTypeFilter() {
        // Secondary BOTH only (create + detail) — never Self
        if (!this.isSecondaryQuote) {
            return false;
        }
        // Secondary + ARC: Rotex catalogue only (Item Type + Search) — no Type dropdown
        if (this.isArcQuoteRecordType) {
            return false;
        }
        if (this.normalizedProductMode === 'both') {
            return true;
        }
        return this.normalizedBusinessLine === 'BOTH';
    }

    get isNonRotexBusinessLine() {
        return this.isSecondaryQuote && this.normalizedBusinessLine === 'NON ROTEX';
    }

    get effectiveUsePartnerProducts() {
        if (!this.isSecondaryQuote) {
            return false;
        }
        if (this.normalizedProductMode === 'partner') {
            return true;
        }
        if (this.normalizedProductMode === 'inventory' || this.normalizedProductMode === 'catalogue') {
            return false;
        }
        if (this.showProductTypeFilter) {
            return this.selectedProductSource === 'Non ROTEX';
        }
        if (this.usePartnerProducts === true || this.usePartnerProducts === 'true') {
            return true;
        }
        return this.isNonRotexBusinessLine;
    }

    get isPartnerAllProductsMode() {
        return this.isSecondaryQuote && this.useAccountProductSources && this.effectiveUsePartnerProducts;
    }

    /** Secondary + inventory only — Rotex catalogue uses isCatalogueProductsMode */
    get isInventoryProductsMode() {
        if (!this.isSecondaryQuote || !this.useAccountProductSources) {
            return false;
        }
        if (this.normalizedProductMode === 'inventory') {
            return true;
        }
        if (this.normalizedProductMode === 'catalogue' || this.normalizedProductMode === 'partner') {
            return false;
        }
        // BOTH: Rotex uses catalogue (like Self), Non-Rotex uses partner
        if (this.showProductTypeFilter) {
            return false;
        }
        if (this.effectiveUsePartnerProducts) {
            return false;
        }
        return false;
    }

    /** Self create (and Secondary Rotex catalogue) */
    get isCatalogueProductsMode() {
        if (this.isPartnerAllProductsMode || this.isInventoryProductsMode) {
            return false;
        }
        // Self create quote product step
        if (this.isCreateModeActive && !this.isSecondaryQuote) {
            return true;
        }
        if (this.normalizedProductMode === 'catalogue') {
            // When Type (Rotex/Non-Rotex) is shown, wait for Rotex — do not force catalogue early
            if (this.showProductTypeFilter) {
                return this.selectedProductSource === 'ROTEX';
            }
            return true;
        }
        // Secondary BOTH + Rotex selected → full catalogue like Self
        if (
            this.isSecondaryQuote &&
            this.useAccountProductSources &&
            this.showProductTypeFilter &&
            this.selectedProductSource === 'ROTEX'
        ) {
            return true;
        }
        // Secondary ARC: always Rotex catalogue (Type hidden)
        if (this.isArcQuoteRecordType && this.useAccountProductSources) {
            return true;
        }
        return false;
    }

    /**
     * Account used for Rotex catalogue product fetch.
     * Self and Secondary Rotex both use CP / login account (same product list as Self).
     */
    get catalogueAccountId() {
        if (this.isCatalogueProductsMode) {
            return this.partnerAccountId || this.accountId;
        }
        return this.accountId;
    }

    /**
     * Account-based product APIs — same for create and detail Add Product
     * when parent sets productMode (catalogue | partner | both).
     */
    get useAccountProductSources() {
        if (!this.accountId) {
            return false;
        }
        if (this.isCreateModeActive) {
            return true;
        }
        return !!this.normalizedProductMode;
    }

    get itemTypeDisabled() {
        return false;
    }

    /** Self always; Secondary Rotex catalogue also — avoids loading entire catalogue (heap). */
    get showItemTypeFilter() {
        if (!this.isSecondaryQuote) {
            return true;
        }
        return this.isCatalogueProductsMode;
    }

    /**
     * Product table + pagination only after required filters are chosen.
     * Self: Item Type. Secondary BOTH: Type (Rotex / Non-Rotex).
     */
    get showProductResults() {
        if (this.showProductTypeFilter && !this.selectedProductSource) {
            return false;
        }
        if (this.showItemTypeFilter && !this.selectedItemType) {
            return false;
        }
        return true;
    }

    get showSelectFilterHint() {
        return this.isFirstPage && !this.showProductResults;
    }

    get selectFilterHintText() {
        if (this.showProductTypeFilter && !this.selectedProductSource) {
            return 'Select Type (Rotex or Non-Rotex) to view products.';
        }
        if (this.showItemTypeFilter && !this.selectedItemType) {
            return 'Select Item Type to view products.';
        }
        return 'Select a filter to view products.';
    }

    get productTypeOptions() {
        return [
            { label: 'Rotex', value: 'ROTEX' },
            { label: 'Non-Rotex', value: 'Non ROTEX' }
        ];
    }

    get showOverlayModal() {
        return this.isModalOpen && !this.isEmbeddedActive;
    }

    get showEmbeddedPanel() {
        return this.isModalOpen && this.isEmbeddedActive;
    }

    get firstPageCancelLabel() {
        return this.isCreateModeActive ? 'Back' : 'Cancel';
    }

    get isCreateModeActive() {
        return this.createMode === true || this.createMode === 'true' || this.createMode === '';
    }

    get isEmbeddedActive() {
        return this.embedded === true || this.embedded === 'true' || this.embedded === '';
    }

    /** One save loader only — create-quote parent already shows its own overlay. */
    get showCartSaveLoader() {
        // Single loader in this modal (create parent overlay was removed to avoid duplicates).
        return this.isSavingDraft;
    }

    get showCartHeading() {
        return this.isSecondPage;
    }

    get showProductsHeading() {
        return this.isFirstPage;
    }

    get pageHeading() {
        if (this.isSecondPage) {
            return 'Edit Selected Products';
        }
        return 'Add Products';
    }

    get showPageHeading() {
        return this.isFirstPage || this.isSecondPage;
    }

    get embeddedRootClass() {
        return this.isSecondPage
            ? 'embedded-add-product embedded-add-product--cart'
            : 'embedded-add-product';
    }

    get overlayContainerClass() {
        return this.isSecondPage
            ? 'slds-modal__container slds-modal__container--cart'
            : 'slds-modal__container';
    }

    get modalContentClass() {
        return this.isSecondPage
            ? 'slds-modal__content slds-p-around_medium slds-modal__content--cart'
            : 'slds-modal__content slds-modal__content--products';
    }

    notifyCartViewChange() {
        this.dispatchEvent(
            new CustomEvent('cartviewchange', {
                detail: {
                    isCart: this.isSecondPage,
                    layout: this.isSecondPage ? 'cart' : 'products'
                },
                bubbles: true,
                composed: true
            })
        );
    }

    @track SelectedRecordCount = 0;
    @track isModalOpen = false;
    @track ShowSelected = true;
    @track PriceBook = '';
    @track ShowTableData = [];
    @track selectedProductCode = [];
    @track AllProductData = [];
    @track SelectedProductData = [];
    @track lstResult = [];
    @track hasRecords = true;
    @track searchKey = '';
    @track isFirstPage = true;
    @track isSecondPage = false;
    @track selectedRows = [];
    @track ShowViewAll = false;
    @track datafilterval = false;
    @track prodfamilylst = [];
    @track FilterForm = { ProductFamily: '' };
    @track showErrorMsg = false;
    @track filteredData = [];
    @track DisableNext = true;
    @track selectedItemType = '';
    @track selectedProductSource = '';
    partnerProductsAutoLoaded = false;
    @track showViewCart = false;
    @track cartProducts = [];
    @track customerSAPdiscount = 0;
    @track disabledApplayButton = true;
    @track paginationDataList;
    @track portalToastVisible = false;
    @track portalToastTitle = '';
    @track portalToastMessage = '';
    @track portalToastVariant = 'info';

    mapIdQuantity;
    mapIdSalesPrice;
    mapIdDate;
    mapIdDiscount;
    mapIdLineDescription;
    mapIdCustomerPartNo;
    mapIdRequestedComments;
    mapIdPotentialQty;
    mapIdValidFrom;
    mapIdValidTill;
    allSelectedProductIds = new Set();
    typingTimeout;
    page = 1;
    pageSize = 10;
    totalRecountCount = 0;
    totalPage = 0;
    startingRecord = 1;
    endingRecord = 0;
    portalToastTimeout;

    get portalToastClass() {
        return `portal-toast portal-toast--${this.portalToastVariant || 'info'}`;
    }

    showToast(title, message, variant) {
        const safeVariant = variant || 'info';
        const safeTitle = title || 'Info';
        const safeMessage = message || '';

        if (this.portalToastTimeout) {
            window.clearTimeout(this.portalToastTimeout);
        }

        this.portalToastTitle = safeTitle;
        this.portalToastMessage = safeMessage;
        this.portalToastVariant = safeVariant;
        this.portalToastVisible = true;

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.portalToastTimeout = window.setTimeout(() => {
            this.portalToastVisible = false;
            this.portalToastTimeout = null;
        }, PORTAL_TOAST_DURATION_MS);
    }

    syncProductColumnWidths() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(() => {
            const box = this.template.querySelector('.product-table-scroll .slds-box');
            const totalWidth = box ? box.clientWidth : 0;
            if (!totalWidth) {
                return;
            }

            const checkboxWidth = 52;
            const usable = Math.max(totalWidth - checkboxWidth, 480);
            const hasAvailable = (this.cols || []).some((c) => c.fieldName === 'AvailableQuantity');
            const nameWidth = Math.floor(usable * (hasAvailable ? 0.4 : 0.5));
            const codeWidth = Math.floor(usable * 0.2);
            const availableWidth = hasAvailable ? Math.floor(usable * 0.15) : 0;
            const priceWidth = usable - nameWidth - codeWidth - availableWidth;

            this.cols = (this.cols || []).map((col) => {
                if (col.fieldName === 'purl') {
                    return { ...col, initialWidth: nameWidth, wrapText: true };
                }
                if (col.fieldName === 'ProductCode') {
                    return { ...col, initialWidth: codeWidth };
                }
                if (col.fieldName === 'AvailableQuantity') {
                    return { ...col, initialWidth: availableWidth };
                }
                if (col.fieldName === 'Price') {
                    return { ...col, initialWidth: priceWidth };
                }
                return col;
            });
        });
    }

    renderedCallback() {
        if (this.isFirstPage && !this.showSpinner) {
            this.syncProductColumnWidths();
        }
        // Create flow: auto-load partner / inventory only. Catalogue waits for Item Type.
        if (
            this.isCreateModeActive &&
            this.accountId &&
            (this.isPartnerAllProductsMode || this.isInventoryProductsMode) &&
            !this.partnerProductsAutoLoaded
        ) {
            this.partnerProductsAutoLoaded = true;
            this.getProductList();
        }
    }

    get options() {
        return this.prodfamilylst;
    }

    get itemsOptions() {
        return [
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
    }

    get bDisableFirst() {
        return this.page === 1;
    }

    get bDisableLast() {
        return this.page === this.totalPage || this.totalPage === 0;
    }

    connectedCallback() {
        this.mapIdQuantity = new Map();
        this.mapIdSalesPrice = new Map();
        this.mapIdDate = new Map();
        this.mapIdDiscount = new Map();
        this.mapIdLineDescription = new Map();
        this.mapIdCustomerPartNo = new Map();
        this.mapIdRequestedComments = new Map();
        this.mapIdPotentialQty = new Map();
        this.mapIdValidFrom = new Map();
        this.mapIdValidTill = new Map();
        this.allSelectedProductIds = new Set();

        this.ShowTableData = [];
        this.selectedProductCode = [];
        this.AllProductData = [];
        this.SelectedProductData = [];
        this.cartProducts = [];
        this.isModalOpen = true;
        this.recId = this.quoteId;
        this.showSpinner = false;
        this.searchDisabled = true;
        this.partnerProductsAutoLoaded = false;

        this.cols = COLS.filter((col) => col.fieldName !== 'ListPrice')
            .filter((col) => col.fieldName !== 'IsARC')
            .filter((col) => col.fieldName !== 'Description');
        if (!this.isInventoryProductsMode) {
            this.cols = this.cols.filter((col) => col.fieldName !== 'AvailableQuantity');
        }
        this.syncProductColumnWidths();

        if (this.isEmbeddedActive) {
            this.notifyCartViewChange();
        }

        if (this.isCreateModeActive) {
            if (this.accountId) {
                this.handlerGetCustomerDiscountForAccount();
                // Secondary: auto-load inventory / partner only. Catalogue waits for Item Type (like Self).
                // Self: wait for Item Type selection (do not auto-load)
                if (this.isSecondaryQuote) {
                    if (this.showProductTypeFilter && !this.selectedProductSource) {
                        this.searchDisabled = true;
                        return;
                    }
                    if (this.isCatalogueProductsMode && !this.selectedItemType) {
                        this.searchDisabled = true;
                        return;
                    }
                    if (this.isPartnerAllProductsMode || this.isInventoryProductsMode) {
                        this.partnerProductsAutoLoaded = true;
                        this.getProductList();
                    }
                }
            } else {
                this.showToast('Error', 'Account is required before adding products.', 'error');
            }
            return;
        }

        if (this.recId) {
            this.handlerGetCustomerDiscount();
        }

        // Existing Secondary quote Add Product — same sources as create (not Self)
        if (!this.isCreateModeActive && this.useAccountProductSources && this.isSecondaryQuote) {
            if (this.showProductTypeFilter && !this.selectedProductSource) {
                this.searchDisabled = true;
                return;
            }
            if (this.isCatalogueProductsMode && !this.selectedItemType) {
                this.searchDisabled = true;
                return;
            }
            if (this.isPartnerAllProductsMode || this.isInventoryProductsMode) {
                this.partnerProductsAutoLoaded = true;
                this.getProductList();
            }
        }
    }

    loadProductsByItemType(option) {
        const params = {
            searchKey: this.searchKey,
            itemType: option
        };

        // Self + Secondary Rotex catalogue: same API and CP account (identical product list)
        if (this.isCatalogueProductsMode && this.catalogueAccountId) {
            if (this.isCreateModeActive || this.useAccountProductSources) {
                return findProductsOptimizedForAccount({
                    accountId: this.catalogueAccountId,
                    ...params
                });
            }
            if (this.recId) {
                return findProductsOptimized({
                    recordId: this.recId,
                    ...params
                });
            }
        }

        // Self detail (non-create): quote price book
        if (!this.isSecondaryQuote) {
            return findProductsOptimized({
                recordId: this.recId,
                ...params
            });
        }

        const promise = this.useAccountProductSources
            ? this.effectiveUsePartnerProducts
                ? findPartnerCreatedProductsForAccount({
                      accountId: this.accountId,
                      ...params
                  })
                : this.isInventoryProductsMode
                  ? findInventoryProductsForAccount({
                        accountId: this.accountId,
                        ...params
                    })
                  : findProductsOptimizedForAccount({
                        accountId: this.catalogueAccountId || this.accountId,
                        ...params
                    })
            : findProductsOptimized({
                  recordId: this.recId,
                  ...params
              });

        return promise;
    }

    loadCurrentProducts() {
        if (this.isSecondaryQuote && this.useAccountProductSources && !this.accountId) {
            this.showSpinner = false;
            this.showToast('Error', 'Account is required to load products.', 'error');
            return;
        }

        if (!this.isSecondaryQuote && this.isCreateModeActive && !this.accountId) {
            this.showSpinner = false;
            this.showToast('Error', 'Account is required to load products.', 'error');
            return;
        }

        if (this.showProductTypeFilter && !this.selectedProductSource) {
            this.showSpinner = false;
            this.showToast('Select Type', 'Please select Rotex or Non-Rotex first.', 'info');
            return;
        }

        // Self + Secondary Rotex catalogue: Item Type required. Inventory / Non-Rotex: no Item Type.
        const needsItemType = !this.isSecondaryQuote || this.isCatalogueProductsMode;
        const option = needsItemType ? this.selectedItemType : '';
        if (needsItemType && option === '') {
            this.AllProductData = [];
            this.ShowTableData = [];
            this.paginiateData(JSON.stringify([]));
            this.showSpinner = false;
            this.searchDisabled = true;
            return;
        }

        this.loadProductsByItemType(option)
            .then((chunks) => {
                let allProducts = [];
                let priceBook = '';

                (chunks || []).forEach((chunkStr) => {
                    const chunkObj = JSON.parse(chunkStr);
                    if (chunkObj.error) {
                        throw new Error(chunkObj.error);
                    }
                    if (!priceBook && chunkObj.priceBook) {
                        priceBook = chunkObj.priceBook;
                        this.PriceBook = priceBook;
                    }
                    if (chunkObj.productList && Array.isArray(chunkObj.productList)) {
                        allProducts = allProducts.concat(chunkObj.productList);
                    }
                });

                this.AllProductData = allProducts;
                this.ShowTableData = allProducts;
                this.paginiateData(JSON.stringify(this.AllProductData));
                this.page = 1;
                this.showSpinner = false;
                this.searchDisabled = false;

                if (allProducts.length === 0) {
                    this.showToast(
                        'No Products',
                        this.isPartnerAllProductsMode
                            ? 'No Channel Partner products found. Create products under Products (with price) first, then retry.'
                            : this.isInventoryProductsMode
                              ? 'No inventory products with Available Quantity > 0 for your Channel Partner.'
                              : 'No products found for this Account. Check Sales Area and catalogue Price Book.',
                        'info'
                    );
                }
            })
            .catch((error) => {
                this.showSpinner = false;
                this.searchDisabled = true;
                this.showToast(
                    'Error',
                    'Failed to load products: ' + (error?.body?.message || error.message),
                    'error'
                );
            });
    }

    handlerGetCustomerDiscountForAccount() {
                getCustomerDiscountForAccount({ accountId: this.accountId })
            .then((result) => {
                if (result != null && result !== '' && !Number.isNaN(parseFloat(result))) {
                    this.customerSAPdiscount = Math.abs(parseFloat(result));
                } else {
                    this.customerSAPdiscount = 0;
                }
            })
            .catch((error) => {
                this.customerSAPdiscount = 0;
                this.showToast('Error', error?.body?.message || 'Unable to load customer discount', 'error');
            });
    }

    handlerGetCustomerDiscount() {
        getCustomerDiscount({ quoteId: this.recId })
            .then((result) => {
                if (result != null && result !== '' && !Number.isNaN(parseFloat(result))) {
                    this.customerSAPdiscount = Math.abs(parseFloat(result));
                } else {
                    this.customerSAPdiscount = 0;
                }
            })
            .catch((error) => {
                this.customerSAPdiscount = 0;
                this.showToast('Error', error?.body?.message || 'Unable to load customer discount', 'error');
            });
    }

    resetProductSelectionState(clearCart = true) {
        if (clearCart) {
            this.cartProducts = [];
            this.showViewCart = false;
        }
        this.allSelectedProductIds.clear();
        this.selectedProductCode = [];
        this.SelectedProductData = [];
        this.selectedRows = [];
        this.SelectedRecordCount = 0;
        this.DisableNext = true;
        this.AllProductData = [];
        this.ShowTableData = [];
        this.paginiateData(JSON.stringify([]));
        this.page = 1;
        this.searchDisabled = true;
    }

    handleProductSourceChange(event) {
        this.selectedProductSource = event.target.value;
        this.selectedItemType = '';
        this.searchKey = '';
        this.showSpinner = true;
        // Keep cart so BOTH (Rotex + Non-Rotex) products can be mixed in one View Cart
        this.resetProductSelectionState(false);
        this.showViewCart = this.cartProducts.length > 0;
        this.refreshColumnSet();

        if (this.effectiveUsePartnerProducts || this.isInventoryProductsMode) {
            this.loadCurrentProducts();
            return;
        }

        this.showSpinner = false;
    }

    refreshColumnSet() {
        let nextCols = COLS.filter((col) => col.fieldName !== 'ListPrice')
            .filter((col) => col.fieldName !== 'IsARC')
            .filter((col) => col.fieldName !== 'Description');
        if (!this.isInventoryProductsMode) {
            nextCols = nextCols.filter((col) => col.fieldName !== 'AvailableQuantity');
        }
        this.cols = nextCols;
        this.syncProductColumnWidths();
    }

    handleItemOptions(event) {
        this.showSpinner = true;
        const option = event.target.value;
        this.selectedItemType = option;
        this.loadCurrentProducts();
    }

    isNonRotexProductCode(productCode) {
        const code = String(productCode || '').trim();
        return code.length >= 2 && code.substring(0, 2).toUpperCase() === 'CP';
    }

    decorateCartProduct(product) {
        const isNonRotex = this.isNonRotexProductCode(product.ProductCode);
        // Secondary + ARC Quote Type: Disc. % + Sales Price + Proposed ARC Price editable.
        // Secondary (Normal): Req Disc locked, Sales Price editable.
        // Self: Non-Rotex (CP) same as Secondary Normal; Rotex keeps Req Disc editable / Sales Price locked.
        if (this.isArcQuoteRecordType) {
            product.reqDiscountDisabled = false;
            product.salesPriceDisabled = false;
            product.hideDiscountColumns = false;
            // Proposed ARC Price defaults to 0 until user enters value / Disc. %
            if (product.SellPriceOfSc == null || product.SellPriceOfSc === '') {
                product.SellPriceOfSc = 0;
            }
        } else if (this.isSecondaryQuote) {
            product.reqDiscountDisabled = true;
            product.salesPriceDisabled = false;
            product.hideDiscountColumns = !!product.IsARC;
            product.Discount = 0;
        } else {
            product.reqDiscountDisabled = isNonRotex;
            product.salesPriceDisabled = !isNonRotex;
            product.hideDiscountColumns = !!product.IsARC;
            if (isNonRotex) {
                product.Discount = 0;
            }
        }
        return product;
    }

    addToCart() {
        if (this.selectedProductCode.length === 0) {
            this.showToast('Error', 'Please select at least one product.', 'error');
            return;
        }

        const alreadyInCartIds = new Set(this.cartProducts.map((p) => p.Id));
        const selectedProducts = [];
        let duplicateCount = 0;

        for (let i = 0; i < this.AllProductData.length; i++) {
            const row = this.AllProductData[i];
            if (!this.selectedProductCode.includes(row.Id)) {
                continue;
            }
            if (alreadyInCartIds.has(row.Id)) {
                duplicateCount += 1;
                continue;
            }
            const product = JSON.parse(JSON.stringify(row));
            product.Quantity = product.ARCQuantity || 1;
            product.Price = this.isArcQuoteRecordType ? 0 : product.ListPrice;
            product.Discount =
                this.isSecondaryQuote && !this.isArcQuoteRecordType
                    ? 0
                    : this.isNonRotexProductCode(product.ProductCode)
                      ? 0
                      : this.customerSAPdiscount;
            product.CustomerPartNo = product.CustomerPartNo || '';
            if (this.isArcQuoteRecordType) {
                product.SellPriceOfSc = 0;
                product.RequestedComments = product.RequestedComments || '';
                product.PotentialQty = product.Quantity || 1;
                product.ValidFrom = product.ValidFrom || '';
                product.ValidTill = product.ValidTill || '';
            }
            this.decorateCartProduct(product);
            selectedProducts.push(product);
        }

        if (selectedProducts.length === 0) {
            const alreadyMessage =
                duplicateCount === 1
                    ? 'This product is already in your cart.'
                    : 'The selected products are already in your cart.';
            this.showToast('Already in Cart', alreadyMessage, 'warning');
            return;
        }

        this.cartProducts = [...this.cartProducts, ...selectedProducts];
        this.selectedProductCode = [];
        this.allSelectedProductIds.clear();
        this.SelectedProductData = [];
        this.selectedRows = [];
        this.SelectedRecordCount = 0;
        this.DisableNext = true;

        const datatable = this.template.querySelector('[data-id="datatable"]');
        if (datatable) {
            datatable.selectedRows = [];
        }

        if (duplicateCount > 0) {
            const addedPart =
                selectedProducts.length === 1
                    ? '1 product added to cart'
                    : `${selectedProducts.length} products added to cart`;
            const skippedPart =
                duplicateCount === 1
                    ? '1 was already in your cart'
                    : `${duplicateCount} were already in your cart`;
            this.showToast('Cart Updated', `${addedPart}. ${skippedPart}.`, 'warning');
        } else {
            const addedMessage =
                selectedProducts.length === 1
                    ? 'Product has been added to cart.'
                    : `${selectedProducts.length} products have been added to cart.`;
            this.showToast('Success', addedMessage, 'success');
        }

        this.showViewCart = this.cartProducts.length > 0;
    }

    viewCart() {
        if (this.cartProducts.length === 0) {
            this.showToast('Info', 'Cart is empty', 'info');
            return;
        }

        const cartItems = [];
        for (let i = 0; i < this.cartProducts.length; i++) {
            const productCopy = this.decorateCartProduct(
                JSON.parse(JSON.stringify(this.cartProducts[i]))
            );
            if (this.isArcQuoteRecordType) {
                // Sales Price to SC defaults to 0; keep user-entered value if already set
                productCopy.Price =
                    productCopy.Price != null && productCopy.Price !== ''
                        ? productCopy.Price
                        : 0;
                productCopy.SellPriceOfSc =
                    productCopy.SellPriceOfSc != null && productCopy.SellPriceOfSc !== ''
                        ? productCopy.SellPriceOfSc
                        : 0;
                productCopy.NetPrice = productCopy.ListPrice;
            } else {
                let newPrice = productCopy.ListPrice;
                const applyDiscount =
                    !productCopy.reqDiscountDisabled &&
                    this.customerSAPdiscount > 0 &&
                    !productCopy.IsARC;
                if (applyDiscount) {
                    newPrice = productCopy.ListPrice * (1 - this.customerSAPdiscount / 100);
                    newPrice = newPrice.toFixed(2);
                }
                productCopy.NetPrice = newPrice;

                const newPriceNum = Number(newPrice) || 0;
                const incoPercent = Number(productCopy.IncoTerms) || 0;
                productCopy.Price = parseFloat(
                    (newPriceNum + (newPriceNum * incoPercent) / 100).toFixed(2)
                );
            }
            cartItems.push(productCopy);
        }

        this.SelectedProductData = cartItems;
        this.isFirstPage = false;
        this.isSecondPage = true;
        this.notifyCartViewChange();
    }

    deleteProductFromCart(event) {
        const productId = event.currentTarget.dataset.id;
        this.cartProducts = this.cartProducts.filter((product) => product.Id !== productId);
        this.SelectedProductData = this.SelectedProductData.filter((product) => product.Id !== productId);
        this.showViewCart = this.cartProducts.length > 0;
        this.showToast('Success', 'Product removed from cart', 'success');

        if (this.cartProducts.length === 0) {
            this.showViewCart = false;
            this.handleback();
        }
    }

    SelectedProduct(event) {
        const selRows = event.detail.selectedRows;
        const currentPageIds = this.ShowTableData.map((item) => item.Id);

        const obsoleteSelected = selRows.filter((row) => row.Status === 'Z1' || row.Status === 'Z2');
        if (obsoleteSelected.length > 0) {
            this.showToast('Error', 'This model is now obsolete and can no longer be used for sales.', 'error');
        }

        const validSelRows = selRows.filter((row) => row.Status !== 'Z1' && row.Status !== 'Z2');

        for (let i = 0; i < currentPageIds.length; i++) {
            const isSelected = validSelRows.some((row) => row.Id === currentPageIds[i]);
            if (!isSelected && this.allSelectedProductIds.has(currentPageIds[i])) {
                this.allSelectedProductIds.delete(currentPageIds[i]);
            }
        }

        for (let i = 0; i < validSelRows.length; i++) {
            this.allSelectedProductIds.add(validSelRows[i].Id);
        }

        this.selectedProductCode = Array.from(this.allSelectedProductIds);
        this.SelectedRecordCount = this.selectedProductCode.length;
        this.selectedRows = validSelRows;
        this.DisableNext = this.selectedProductCode.length === 0;

        this.SelectedProductData = [];
        for (let i = 0; i < this.selectedProductCode.length; i++) {
            let found = false;
            for (let j = 0; j < this.ShowTableData.length; j++) {
                if (this.selectedProductCode.includes(this.ShowTableData[j].Id)) {
                    this.SelectedProductData.push(this.ShowTableData[j]);
                    found = true;
                    break;
                }
            }
            if (!found) {
                for (let j = 0; j < this.AllProductData.length; j++) {
                    if (this.selectedProductCode.includes(this.AllProductData[j].Id)) {
                        this.SelectedProductData.push(this.AllProductData[j]);
                        break;
                    }
                }
            }
        }
        this.SelectedProductData = [...new Set(this.SelectedProductData)];

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const datatable = this.template.querySelector('[data-id="datatable"]');
            if (datatable) {
                datatable.selectedRows = this.selectedProductCode.filter((id) => {
                    const product = this.AllProductData.find((p) => p.Id === id);
                    return product && product.Status !== 'Z1' && product.Status !== 'Z2';
                });
            }
        }, 0);
    }

    closeModal() {
        this.isModalOpen = false;
        this.SelectedRecordCount = 0;
        this.PriceBook = '';
        this.ShowTableData = [];
        this.selectedProductCode = [];
        this.AllProductData = [];
        this.SelectedProductData = [];
        this.cartProducts = [];
        this.showViewCart = false;
        this.allSelectedProductIds.clear();
        this.searchKey = '';
        this.selectedItemType = '';
        this.selectedProductSource = '';
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleFirstPageCancel() {
        if (this.isCreateModeActive) {
            this.dispatchEvent(new CustomEvent('back'));
            return;
        }
        this.closeModal();
    }

    saveDetails() {
        if (this.isSavingDraft) {
            return;
        }

        // Apply quantity map updates before save
        for (let i = 0; i < this.SelectedProductData.length; i++) {
            const obj = this.SelectedProductData[i];
            const id = obj.Id;
            if (this.mapIdQuantity.get(id) != null) {
                obj.Quantity = this.mapIdQuantity.get(id);
            }
            if (this.mapIdSalesPrice.get(id) != null) {
                obj.Price = this.mapIdSalesPrice.get(id);
            }
            if (this.mapIdDiscount.get(id) != null) {
                obj.Discount = this.mapIdDiscount.get(id);
            }
            if (this.mapIdLineDescription.get(id) != null) {
                obj.LineDescription = this.mapIdLineDescription.get(id);
            }
            if (this.mapIdCustomerPartNo.get(id) != null) {
                obj.CustomerPartNo = this.mapIdCustomerPartNo.get(id);
            }
            if (this.mapIdRequestedComments.get(id) != null) {
                obj.RequestedComments = this.mapIdRequestedComments.get(id);
            }
            if (this.mapIdPotentialQty.get(id) != null) {
                obj.PotentialQty = this.mapIdPotentialQty.get(id);
            }
            if (this.mapIdValidFrom.get(id) != null) {
                obj.ValidFrom = this.mapIdValidFrom.get(id);
            }
            if (this.mapIdValidTill.get(id) != null) {
                obj.ValidTill = this.mapIdValidTill.get(id);
            }
            if (this.isArcQuoteRecordType) {
                const moq = Number(obj.PotentialQty);
                if (Number.isFinite(moq) && moq > 0) {
                    obj.Quantity = moq;
                }
            }
            this.SelectedProductData[i] = obj;
        }

        let isValidate = true;
        for (let i = 0; i < this.SelectedProductData.length; i++) {
            const row = this.SelectedProductData[i];
            if (this.isArcQuoteRecordType) {
                const moq = Number(row.PotentialQty);
                if (!Number.isFinite(moq) || moq <= 0) {
                    isValidate = false;
                    break;
                }
            } else if (
                row.Quantity == 0 ||
                row.Quantity === undefined ||
                row.Quantity === ''
            ) {
                isValidate = false;
                break;
            }
        }

        if (!isValidate || this.SelectedProductData.length === 0) {
            if (this.isArcQuoteRecordType && this.SelectedProductData.length > 0) {
                this.showToast('Error', 'Please enter MOQ for all products.', 'error');
                return;
            }
            // fall through to existing error toasts below
        } else if (this.isInventoryProductsMode) {
            for (let i = 0; i < this.SelectedProductData.length; i++) {
                const row = this.SelectedProductData[i];
                const qty = Number(row.Quantity);
                const available = Number(row.AvailableQuantity);
                if (Number.isFinite(available) && Number.isFinite(qty) && qty > available) {
                    this.showToast(
                        'Error',
                        `${row.Name || 'Product'}: Quantity (${qty}) cannot exceed Available Qty (${available}).`,
                        'error'
                    );
                    return;
                }
            }
        }

        if (isValidate && this.SelectedProductData.length > 0) {
            this.isSavingDraft = true;
            // Cart page uses isSavingDraft loader only — avoid a second spinner via showSpinner.
            if (!this.isSecondPage) {
                this.showSpinner = true;
            }

            if (this.isCreateModeActive) {
                this.dispatchEvent(
                    new CustomEvent('save', {
                        detail: {
                            products: this.SelectedProductData,
                            customerSAPdiscount: this.customerSAPdiscount,
                            usePartnerProducts: this.effectiveUsePartnerProducts
                        }
                    })
                );
                return;
            }

            const str = JSON.stringify(this.SelectedProductData);
            saveProducts({
                recordData: str,
                recId: this.recId,
                customerSAPdiscount: this.customerSAPdiscount
            })
                .then(() => {
                    this.isSavingDraft = false;
                    this.showSpinner = false;
                    this.showToast('Success', 'Products Added Successfully', 'success');
                    this.cartProducts = [];
                    this.showViewCart = false;
                    this.allSelectedProductIds.clear();
                    this.selectedProductCode = [];
                    this.dispatchEvent(new CustomEvent('save'));
                    if (!this.isEmbeddedActive) {
                        this.dispatchEvent(new CustomEvent('close'));
                    }
                })
                .catch((error) => {
                    this.isSavingDraft = false;
                    this.showSpinner = false;
                    this.showToast('Error', error?.body?.message || 'Error adding products', 'error');
                });
        } else {
            this.showToast('Error', 'Quantity should be non-Zero for all products', 'error');
        }
    }

    handleback() {
        this.ShowSelected = true;
        this.isFirstPage = true;
        this.isSecondPage = false;
        this.showViewCart = this.cartProducts.length > 0;
        this.notifyCartViewChange();

        this.mapIdQuantity = new Map();
        this.mapIdSalesPrice = new Map();
        this.mapIdDate = new Map();
        this.mapIdDiscount = new Map();
        this.mapIdLineDescription = new Map();
        this.mapIdCustomerPartNo = new Map();
        this.mapIdRequestedComments = new Map();
        this.mapIdPotentialQty = new Map();
        this.mapIdValidFrom = new Map();
        this.mapIdValidTill = new Map();

        this.selectedProductCode = [];
        this.SelectedProductData = [];
        this.selectedRows = [];
        this.SelectedRecordCount = 0;
        this.DisableNext = true;
        this.searchKey = '';
        this.FilterForm = { ProductFamily: '' };
        this.selectedItemType = '';
        if (!this.showProductTypeFilter) {
            this.selectedProductSource = '';
        }

        this.AllProductData = [];
        this.ShowTableData = [];
        this.paginiateData(JSON.stringify([]));
        this.page = 1;
        this.searchDisabled = true;
        this.showSpinner = false;
    }

    getProductList() {
        this.showSpinner = true;
        this.loadCurrentProducts();
    }

    showFilteredProducts(event) {
        this.searchKey = event.target.value;
        clearTimeout(this.typingTimeout);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.typingTimeout = setTimeout(() => {
            if (
                this.isSecondaryQuote ||
                this.isPartnerAllProductsMode ||
                this.isInventoryProductsMode ||
                this.selectedItemType
            ) {
                this.showSpinner = true;
                this.loadCurrentProducts();
            }
        }, 500);
    }

    handleQuantityChange(event) {
        const key = event.currentTarget.dataset.targetId;
        const record = this.SelectedProductData.find((item) => item.Id == key);
        this.mapIdQuantity.set(key, event.target.value);

        if (record && record.IsARC) {
            const enteredQty = parseInt(event.target.value, 10);
            let resultValue;
            const sortedArr = [...(record.PriceOption || [])].sort((a, b) => a.label - b.label);

            for (let i = sortedArr.length - 1; i >= 0; i--) {
                if (enteredQty >= sortedArr[i].label) {
                    resultValue = sortedArr[i].value;
                    break;
                }
            }
            if (!resultValue && sortedArr.length > 0) {
                resultValue = sortedArr[0].value;
            }

            this.SelectedProductData = this.SelectedProductData.map((rec) => {
                if (rec.Id == key) {
                    let newPrice = resultValue;
                    const newPriceNum = Number(newPrice) || 0;
                    const incoPercent = Number(rec.IncoTerms) || 0;
                    newPrice = parseFloat((newPriceNum + (newPriceNum * incoPercent) / 100).toFixed(2));
                    return { ...rec, Quantity: event.target.value, Price: newPrice };
                }
                return rec;
            });
        } else {
            this.SelectedProductData = this.SelectedProductData.map((rec) => {
                if (rec.Id == key) {
                    return { ...rec, Quantity: event.target.value };
                }
                return rec;
            });
        }
    }

    handleSalesPriceChange(event) {
        const key = event.currentTarget.dataset.targetId;
        const current = this.SelectedProductData.find((record) => record.Id == key);
        if (!current || current.salesPriceDisabled) {
            return;
        }
        const value = event.target.value;
        this.mapIdSalesPrice.set(key, value);
        this.SelectedProductData = this.SelectedProductData.map((record) => {
            if (record.Id == key) {
                return { ...record, Price: value };
            }
            return record;
        });
        this.cartProducts = this.cartProducts.map((record) => {
            if (record.Id == key) {
                return { ...record, Price: value };
            }
            return record;
        });
    }

    handleSellPriceOfScChange(event) {
        if (!this.isArcQuoteRecordType) {
            return;
        }
        const key = event.currentTarget.dataset.targetId;
        const value = event.target.value;
        const applyUpdate = (record) => {
            if (record.Id != key) {
                return record;
            }
            const proposed = value !== '' ? parseFloat(value) : null;
            const listPrice = Number(record.ListPrice) || 0;
            let discount = record.Discount;
            // Only derive Disc. % when Proposed ARC Price is entered (> 0)
            if (proposed != null && proposed > 0 && listPrice > 0) {
                discount = parseFloat((((listPrice - proposed) / listPrice) * 100).toFixed(3));
            }
            let newNetPrice = listPrice;
            const discNum = Number(discount) || 0;
            if (discNum > 0) {
                newNetPrice = parseFloat((listPrice * (1 - discNum / 100)).toFixed(2));
            }
            // Sales Price to SC stays user-entered (defaults to 0); do not overwrite from Proposed/Disc %
            return {
                ...record,
                SellPriceOfSc: value === '' ? 0 : value,
                Discount: discount,
                NetPrice: newNetPrice
            };
        };
        this.SelectedProductData = this.SelectedProductData.map(applyUpdate);
        this.cartProducts = this.cartProducts.map(applyUpdate);
        if (value !== '') {
            this.mapIdDiscount.set(key, String(this.SelectedProductData.find((r) => r.Id == key)?.Discount ?? ''));
        }
    }

    handleDiscountChange(event) {
        const key = event.currentTarget.dataset.targetId;
        const current = this.SelectedProductData.find((record) => record.Id == key);
        if (current && current.reqDiscountDisabled) {
            return;
        }
        const discValue = event.target.value;
        this.mapIdDate.set(key, discValue);
        this.mapIdDiscount.set(key, discValue);

        const applyUpdate = (record) => {
            if (record.Id != key) {
                return record;
            }
            const discNum = Number(discValue) || 0;
            let newNetPrice = record.ListPrice;
            let newPrice = record.Price;
            if (discNum > 0) {
                newNetPrice = record.ListPrice * (1 - discNum / 100);
                newNetPrice = Number(newNetPrice.toFixed(2));
            }
            const next = {
                ...record,
                Discount: discValue,
                NetPrice: newNetPrice
            };
            // ARC: sync Proposed ARC Price from Disc. %; keep Sales Price to SC as-is (default 0)
            if (this.isArcQuoteRecordType) {
                const listPrice = Number(record.ListPrice) || 0;
                next.SellPriceOfSc =
                    discNum > 0
                        ? parseFloat((listPrice * (1 - discNum / 100)).toFixed(4))
                        : 0;
            } else {
                const newPriceNum = Number(newNetPrice) || 0;
                const incoPercent = Number(record.IncoTerms) || 0;
                next.Price = parseFloat(
                    (newPriceNum + (newPriceNum * incoPercent) / 100).toFixed(2)
                );
            }
            return next;
        };

        this.SelectedProductData = this.SelectedProductData.map(applyUpdate);
        this.cartProducts = this.cartProducts.map(applyUpdate);
    }

    handleCustomerPartNoChange(event) {
        const key = event.currentTarget.dataset.targetId;
        const value = event.target.value;
        this.mapIdCustomerPartNo.set(key, value);
        this.SelectedProductData = this.SelectedProductData.map((rec) => {
            if (rec.Id == key) {
                return { ...rec, CustomerPartNo: value };
            }
            return rec;
        });
    }

    handleRequestedCommentsChange(event) {
        const key = event.currentTarget.dataset.targetId;
        const value =
            event.detail && event.detail.value !== undefined
                ? event.detail.value
                : event.target.value;
        this.mapIdRequestedComments.set(key, value);
        const applyUpdate = (rec) =>
            rec.Id == key ? { ...rec, RequestedComments: value } : rec;
        this.SelectedProductData = this.SelectedProductData.map(applyUpdate);
        this.cartProducts = this.cartProducts.map(applyUpdate);
    }

    handleMoqChange(event) {
        const key = event.currentTarget.dataset.targetId;
        const value = event.target.value === '' ? '' : Number(event.target.value);
        this.mapIdPotentialQty.set(key, value);
        const qty = Number.isFinite(value) && value > 0 ? value : 1;
        this.mapIdQuantity.set(key, qty);
        const applyUpdate = (rec) =>
            rec.Id == key ? { ...rec, PotentialQty: value, Quantity: qty } : rec;
        this.SelectedProductData = this.SelectedProductData.map(applyUpdate);
        this.cartProducts = this.cartProducts.map(applyUpdate);
    }

    handleValidFromChange(event) {
        const key = event.currentTarget.dataset.targetId;
        const value = event.target.value;
        this.mapIdValidFrom.set(key, value);
        const applyUpdate = (rec) => (rec.Id == key ? { ...rec, ValidFrom: value } : rec);
        this.SelectedProductData = this.SelectedProductData.map(applyUpdate);
        this.cartProducts = this.cartProducts.map(applyUpdate);
    }

    handleValidTillChange(event) {
        const key = event.currentTarget.dataset.targetId;
        const value = event.target.value;
        this.mapIdValidTill.set(key, value);
        const applyUpdate = (rec) => (rec.Id == key ? { ...rec, ValidTill: value } : rec);
        this.SelectedProductData = this.SelectedProductData.map(applyUpdate);
        this.cartProducts = this.cartProducts.map(applyUpdate);
    }

    paginiateData(results) {
        const data = JSON.parse(results);
        this.paginationDataList = data;
        this.totalRecountCount = data.length;
        this.totalPage = Math.ceil(this.totalRecountCount / this.pageSize) || 0;
        this.ShowTableData = this.paginationDataList.slice(0, this.pageSize);
        this.endingRecord = this.pageSize;
        this.showSpinner = false;
        this.syncProductColumnWidths();
    }

    firstPage() {
        this.page = 1;
        this.recordPerPage(this.page, this.SelectedProductData, this.paginationDataList || []);
    }

    previousHandler() {
        if (this.page > 1) {
            this.page = this.page - 1;
            this.recordPerPage(this.page, this.SelectedProductData, this.paginationDataList || []);
        }
    }

    nextHandler() {
        if (this.page < this.totalPage && this.page !== this.totalPage) {
            this.page = this.page + 1;
            this.recordPerPage(this.page, this.SelectedProductData, this.paginationDataList || []);
        }
    }

    lastPage() {
        this.page = this.totalPage;
        if (this.page > 1) {
            this.recordPerPage(this.page, this.SelectedProductData, this.paginationDataList || []);
        }
    }

    recordPerPage(page, selectedRecords, data) {
        const tempdata = data || [];
        this.startingRecord = (page - 1) * this.pageSize;
        this.endingRecord = this.pageSize * page;
        this.endingRecord =
            this.endingRecord > this.totalRecountCount ? this.totalRecountCount : this.endingRecord;
        this.ShowTableData = tempdata.slice(this.startingRecord, this.endingRecord);
        this.startingRecord = this.startingRecord + 1;

        this.selectedRows = [];
        for (let i = 0; i < this.ShowTableData.length; i++) {
            if (this.allSelectedProductIds.has(this.ShowTableData[i].Id)) {
                this.selectedRows.push(this.ShowTableData[i]);
            }
        }

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const datatable = this.template.querySelector('[data-id="datatable"]');
            if (datatable) {
                datatable.selectedRows = Array.from(this.allSelectedProductIds);
            }
        }, 100);
    }
}