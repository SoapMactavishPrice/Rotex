import { LightningElement, wire, track } from 'lwc';
import findProductsOptimized from '@salesforce/apex/AddProductPageOpp.findProductsOptimized';
import getproductfamily      from '@salesforce/apex/AddProductPageOpp.getproductfamily';
import getCustomerDiscount   from '@salesforce/apex/AddProductPageOpp.getCustomerDiscount';
import getARCProductData     from '@salesforce/apex/AddProductARC.getARCProductData';
import saveARCProducts       from '@salesforce/apex/AddProductARC.saveARCProducts';
import { ShowToastEvent }    from 'lightning/platformShowToastEvent';
import { RefreshEvent }      from 'lightning/refresh';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin }   from 'lightning/navigation';

// ─── Datatable columns (Page 1) ────────────────────────────────────────────────
const COLS = [
    { label: 'Product Name', fieldName: 'purl', type: 'url',
      typeAttributes: { label: { fieldName: 'Name' } } },
    { label: 'Product Code', fieldName: 'ProductCode', type: 'text' },
    { label: 'List Price',   fieldName: 'Price',       type: 'currency',
      cellAttributes: { alignment: 'left' } },
    { label: 'Product Description', fieldName: 'Description', type: 'text' }
];

export default class AddProductARC extends NavigationMixin(LightningElement) {

    // ── Datatable columns ──────────────────────────────────────────────────────
    cols = COLS;

    // ── Page 1 state ───────────────────────────────────────────────────────────
    @track showSpinner        = true;
    @track searchDisabled     = true;
    @track recId;
    @track SelectedRecordCount = 0;
    @track isModalOpen        = false;
    @track ShowSelected       = true;
    @track PriceBook          = '';
    @track ShowTableData      = [];
    @track selectedProductCode = [];
    @track AllProductData     = [];
    @track SelectedProductData = [];
    @track lstResult          = [];
    @track hasRecords         = true;
    @track searchKey          = '';
    @track isSearchLoading    = false;
    @track isFirstPage        = true;
    @track isSecondPage       = false;
    @track selectedRows       = [];
    @track ShowViewAll        = false;
    @track datafilterval      = false;
    @track prodfamilylst      = [];
    @track FilterForm         = { ProductFamily: '' };
    @track showErrorMsg       = false;
    @track filteredData       = [];
    @track DisableNext        = true;
    @track showViewCart       = false;
    @track cartProducts       = [];
    @track allSelectedProductIds = new Set();
    @track customerSAPdiscount = 0;

    // ── Page 2 ARC state ──────────────────────────────────────────────────────
    @track isLoadingARCData   = false;
    @track arcProductDetails  = [];   // array of row objects for the ARC table
    @track paymentTerms       = '';
    @track warranty           = '';
    @track incotermsField     = '';

    // ── Pagination ─────────────────────────────────────────────────────────────
    @track paginationDataList = [];
    page              = 1;
    startingRecord    = 1;
    endingRecord      = 0;
    pageSize          = 10;
    totalRecountCount = 0;
    totalPage         = 0;

    // Internal maps used by legacy save path (kept for back-compat)
    mapIdQuantity;
    mapIdSalesPrice;
    mapIdDate;
    mapIdDiscount;
    mapIdLineDescription;

    @track tempEvent;
    @track delayTimeout;

    // ── Wire ──────────────────────────────────────────────────────────────────
    @wire(CurrentPageReference)
    setCurrentPageReference(currentPageReference) {
        this.currentPageReference = currentPageReference.state.c__refRecordId;
        if (this.currentPageReference) {
            this.recId = this.currentPageReference;
        }
    }

    // ── Computed getters ──────────────────────────────────────────────────────

    get searchDisability() {
        return this.searchDisabled || this.showSpinner;
    }

    get bDisableFirst() {
        return this.page === 1;
    }

    get bDisableLast() {
        return this.page === this.totalPage;
    }

    get options() {
        return this.prodfamilylst;
    }

    get itemsOptions() {
        return [
            { label: '--None--',            value: ''                     },
            { label: 'Spares / Special',    value: 'Spares / Special'     },
            { label: 'Coil',               value: 'Coil'                  },
            { label: 'SOV (0-15000)',       value: 'SOV (0-15000)'        },
            { label: 'SOV (15001-30000)',   value: 'SOV (15001-30000)'    },
            { label: 'SOV (30001-45000)',   value: 'SOV (30001-45000)'    },
            { label: 'SOV (45001-60000)',   value: 'SOV (45001-60000)'    },
            { label: 'Valve',              value: 'Valve'                 },
            { label: 'Others',             value: 'Others'               }
        ];
    }

    get itemDefault() {
        return '';
    }

    /**
     * Maximum valid date for "Valid Till" — March 31 of the current Indian FY end.
     * Indian FY: April 1 – March 31.
     * If we are in Jan-Mar, FY ends March 31 this calendar year.
     * If we are in Apr-Dec, FY ends March 31 next calendar year.
     */
    get fyEndDate() {
        const today = new Date();
        const year  = today.getFullYear();
        const month = today.getMonth() + 1; // 1 = Jan, 3 = Mar
        const fyEndYear = month <= 3 ? year : year + 1;
        return `${fyEndYear}-03-31`;
    }

    /** Sum of all Potential Value cells — updates reactively when arcProductDetails changes */
    get totalAnticipatedBusiness() {
        let total = 0;
        for (let i = 0; i < this.arcProductDetails.length; i++) {
            total += Number(this.arcProductDetails[i].potentialValue) || 0;
        }
        return total % 1 === 0 ? total : parseFloat(total.toFixed(2));
    }

    /** Sum of all Potential Qty cells — updates reactively */
    get totalQty() {
        let total = 0;
        for (let i = 0; i < this.arcProductDetails.length; i++) {
            total += Number(this.arcProductDetails[i].potentialQty) || 0;
        }
        return total;
    }

    // ── Lifecycle ──────────────────────────────────────────────────────────────

    connectedCallback() {
        this.mapIdQuantity        = new Map();
        this.mapIdSalesPrice      = new Map();
        this.mapIdDate            = new Map();
        this.mapIdDiscount        = new Map();
        this.mapIdLineDescription = new Map();

        this.ShowTableData      = [];
        this.selectedProductCode = [];
        this.AllProductData     = [];
        this.SelectedProductData = [];
        this.cartProducts       = [];
        this.showViewCart       = false;

        this.isModalOpen = true;

        // Remove redundant columns (Price is shown under 'List Price' via Price field)
        this.cols = this.cols.filter(col => col.fieldName !== 'ListPrice');
        this.cols = this.cols.filter(col => col.fieldName !== 'IsARC');

        this.showSpinner = true;
        this.loadProductFamilies();
        this.handlerGetCustomerDiscount();
        this.showSpinner = false;
    }

    // ── Data loading ───────────────────────────────────────────────────────────

    loadProductFamilies() {
        getproductfamily().then(result => {
            this.prodfamilylst = result;
        }).catch(err => {
            console.error('Failed to load product families:', err);
        });
    }

    handlerGetCustomerDiscount() {
        getCustomerDiscount({ oppId: this.recId })
            .then(result => {
                if (result != null) {
                    this.customerSAPdiscount = parseFloat(result);
                    if (this.customerSAPdiscount < 0) {
                        this.customerSAPdiscount = this.customerSAPdiscount * -1;
                    }
                }
            })
            .catch(err => {
                console.error('Failed to load customer discount:', err);
            });
    }

    // ── Page 1 – Item Type filter & product loading ────────────────────────────

    handleItemOptions(event) {
        this.showSpinner = true;
        const option = event.target.value;

        if (!option || option === '--None--') {
            this.AllProductData  = [];
            this.ShowTableData   = [];
            this.showSpinner     = false;
            this.searchDisabled  = true;
            this.showToast('Info', 'Please select an Item Type to view products', 'info');
            return;
        }

        findProductsOptimized({
            recordId:  this.recId,
            searchKey: this.searchKey,
            itemType:  option
        })
        .then(chunks => {
            let allProducts = [];
            chunks.forEach(chunkStr => {
                try {
                    const chunkObj = JSON.parse(chunkStr);
                    if (chunkObj.error) throw new Error(chunkObj.error);
                    if (chunkObj.productList && Array.isArray(chunkObj.productList)) {
                        allProducts = allProducts.concat(chunkObj.productList);
                    }
                } catch (parseErr) {
                    throw parseErr;
                }
            });

            this.AllProductData = allProducts.map(p => ({
                ...p,
                Price: p.UnitPrice != null ? p.UnitPrice : p.Price
            }));
            this.ShowTableData = this.AllProductData;
            this.paginiateData(JSON.stringify(this.AllProductData));
            this.page           = 1;
            this.showSpinner    = false;
            this.searchDisabled = false;
        })
        .catch(error => {
            this.showSpinner    = false;
            this.searchDisabled = true;
            this.showToast('Error',
                'Failed to load products: ' + (error.body ? error.body.message : error.message),
                'error');
        });
    }

    // ── Page 1 – Cart management ───────────────────────────────────────────────

    addToCart() {
        if (this.selectedProductCode.length === 0) {
            this.showToast('Error', 'Please select at least one product', 'error');
            return;
        }

        const selectedProducts = [];
        for (let i = 0; i < this.AllProductData.length; i++) {
            if (this.selectedProductCode.includes(this.AllProductData[i].Id)) {
                const product = JSON.parse(JSON.stringify(this.AllProductData[i]));
                product.Quantity = product.ARCQuantity || 1;
                product.Price    = product.UnitPrice || product.ListPrice;
                product.ListPrice = product.UnitPrice || product.ListPrice;
                selectedProducts.push(product);
            }
        }

        if (selectedProducts.length === 0) {
            this.showToast('Info', 'No products found in selection', 'info');
            return;
        }

        this.cartProducts = [...this.cartProducts, ...selectedProducts];

        // Clear selections after adding to cart
        this.selectedProductCode = [];
        this.allSelectedProductIds.clear();
        this.SelectedProductData = [];
        this.selectedRows        = [];
        this.SelectedRecordCount = 0;
        this.DisableNext         = true;

        const datatable = this.template.querySelector('[data-id="datatable"]');
        if (datatable) datatable.selectedRows = [];

        this.showToast('Success',
            `${selectedProducts.length} product(s) added to cart. Total: ${this.cartProducts.length}`,
            'success');
        this.showViewCart = this.cartProducts.length > 0;
    }

    /**
     * Transition to Page 2.
     * Calls getARCProductData to fetch list prices and existing ARC pricing,
     * then builds the arcProductDetails array.
     */
    viewCart() {
        if (this.cartProducts.length === 0) {
            this.showToast('Info', 'Cart is empty', 'info');
            return;
        }

        this.isFirstPage      = false;
        this.isSecondPage     = true;
        this.isLoadingARCData = true;

        // Collect unique product codes from cart
        const productCodes = [...new Set(this.cartProducts.map(p => p.ProductCode))];

        getARCProductData({
            oppId:            this.recId,
            productCodesJson: JSON.stringify(productCodes)
        })
        .then(result => {
            const arcDataList = JSON.parse(result);

            // Build a map: productCode → arc data from Apex
            const arcDataMap = {};
            arcDataList.forEach(ad => {
                arcDataMap[ad.productCode] = ad;
            });

            // Build ARC product rows, merging cart data + fetched data
            this.arcProductDetails = this.cartProducts.map(p => {
                const ad = arcDataMap[p.ProductCode] || {};
                // Prefer the freshly-fetched list price; fall back to cart's ListPrice
                const lp = (ad.listPrice != null) ? ad.listPrice : (Number(p.UnitPrice) || 0);
                return {
                    productCode:           p.ProductCode,
                    productName:           p.Name,
                    product2Id:            p.Product2Id,
                    pricebookEntryId:      ad.pricebookEntryId || p.Id,
                    listPrice:             lp,
                    discountPct:           0,
                    proposedARCPrice:      lp,
                    potentialValue:        null,
                    potentialQty:          null,
                    validFrom:             '',
                    validTill:             '',
                    existingARCPrice:      (ad.existingARCPrice != null)     ? ad.existingARCPrice      : '',
                    existingARCExpiryDate: (ad.existingARCExpiryDate != null) ? ad.existingARCExpiryDate : ''
                };
            });

            this.isLoadingARCData = false;
        })
        .catch(error => {
            this.isLoadingARCData = false;
            this.showToast('Error',
                'Failed to load ARC data: ' + (error.body ? error.body.message : error.message),
                'error');
        });
    }

    handleback() {
        this.ShowSelected  = true;
        this.isFirstPage   = true;
        this.isSecondPage  = false;
        this.showViewCart  = this.cartProducts.length > 0;

        // Reset maps
        this.mapIdQuantity        = new Map();
        this.mapIdSalesPrice      = new Map();
        this.mapIdDate            = new Map();
        this.mapIdDiscount        = new Map();
        this.mapIdLineDescription = new Map();

        // Clear selections (cart is preserved)
        this.selectedProductCode = [];
        this.SelectedProductData = [];
        this.selectedRows        = [];
        this.SelectedRecordCount = 0;
        this.DisableNext         = true;
        this.searchKey           = '';
        this.FilterForm          = { ProductFamily: '' };

        // Clear product list; user must pick Item Type again
        this.AllProductData  = [];
        this.ShowTableData   = [];
        this.paginationDataList = [];
        this.paginiateData(JSON.stringify([]));
        this.page = 1;
    }

    // ── Page 2 – ARC field change handlers ────────────────────────────────────

    /** Discount % changed → recalculate Proposed ARC Price */
    handleDiscountPctChange(event) {
        const code     = event.target.dataset.code;
        const discount = parseFloat(event.target.value) || 0;

        this.arcProductDetails = this.arcProductDetails.map(row => {
            if (row.productCode === code) {
                const lp       = Number(row.listPrice) || 0;
                const proposed = parseFloat((lp * (1 - discount / 100)).toFixed(2));
                return Object.assign({}, row, { discountPct: discount, proposedARCPrice: proposed });
            }
            return row;
        });
    }

    /** Potential Value changed → totals recalculate via getter */
    handlePotentialValueChange(event) {
        const code  = event.target.dataset.code;
        const value = parseFloat(event.target.value) || 0;

        this.arcProductDetails = this.arcProductDetails.map(row => {
            if (row.productCode === code) {
                return Object.assign({}, row, { potentialValue: value });
            }
            return row;
        });
    }

    /** Potential Qty changed → totals recalculate via getter */
    handlePotentialQtyChange(event) {
        const code = event.target.dataset.code;
        const qty  = parseFloat(event.target.value) || 0;

        this.arcProductDetails = this.arcProductDetails.map(row => {
            if (row.productCode === code) {
                return Object.assign({}, row, { potentialQty: qty });
            }
            return row;
        });
    }

    handleValidFromChange(event) {
        const code = event.target.dataset.code;
        const val  = event.target.value;

        this.arcProductDetails = this.arcProductDetails.map(row => {
            if (row.productCode === code) {
                return Object.assign({}, row, { validFrom: val });
            }
            return row;
        });
    }

    handleValidTillChange(event) {
        const code = event.target.dataset.code;
        const val  = event.target.value;

        if (val > this.fyEndDate) {
            this.showToast('Warning',
                `Valid Till cannot be beyond FY end (${this.fyEndDate})`,
                'warning');
            event.target.value = this.fyEndDate; // reset the input
            return;
        }

        this.arcProductDetails = this.arcProductDetails.map(row => {
            if (row.productCode === code) {
                return Object.assign({}, row, { validTill: val });
            }
            return row;
        });
    }

    handlePaymentTermsChange(event) {
        this.paymentTerms = event.target.value;
    }

    handleWarrantyChange(event) {
        this.warranty = event.target.value;
    }

    handleIncotermsChange(event) {
        this.incotermsField = event.target.value;
    }

    // ── Page 2 – Save ─────────────────────────────────────────────────────────

    saveARCDetails() {
        // Validate: Potential Qty must be > 0 for all rows
        for (let i = 0; i < this.arcProductDetails.length; i++) {
            const row = this.arcProductDetails[i];
            if (!row.potentialQty || row.potentialQty <= 0) {
                this.showToast('Error',
                    `Potential Qty must be greater than 0 for product "${row.productCode}"`,
                    'error');
                return;
            }
            if (!row.pricebookEntryId) {
                this.showToast('Error',
                    `PricebookEntry not found for product "${row.productCode}". Please check product setup.`,
                    'error');
                return;
            }
        }

        this.showSpinner = true;

        saveARCProducts({
            recordData: JSON.stringify(this.arcProductDetails),
            recId:      this.recId
        })
        .then(() => {
            this.showSpinner = false;
            this.showToast('Success', 'ARC Products Added Successfully', 'success');

            // Clear state
            this.cartProducts = [];
            this.showViewCart = false;
            this.allSelectedProductIds.clear();
            this.selectedProductCode = [];
            this.arcProductDetails   = [];

            this.isModalOpen = false;
            this.dispatchEvent(new RefreshEvent());

            setTimeout(() => {
                this.closeModal();
                this[NavigationMixin.Navigate]({
                    type: 'standard__webPage',
                    attributes: { url: `/lightning/r/Opportunity/${this.recId}/view` }
                });
                setTimeout(() => { window.location.reload(); }, 300);
            }, 500);
        })
        .catch(error => {
            this.showSpinner = false;
            this.showToast('Error',
                'Error saving ARC products: ' + (error.body ? error.body.message : error.message),
                'error');
        });
    }

    // ── Page 1 – Product row selection ────────────────────────────────────────

    SelectedProduct(event) {
        this.tempEvent        = event;
        const selRows         = event.detail.selectedRows;
        const currentPageIds  = this.ShowTableData.map(item => item.Id);

        // Remove deselections on current page
        for (let i = 0; i < currentPageIds.length; i++) {
            const isSelected = selRows.some(row => row.Id === currentPageIds[i]);
            if (!isSelected && this.allSelectedProductIds.has(currentPageIds[i])) {
                this.allSelectedProductIds.delete(currentPageIds[i]);
            }
        }

        // Add new selections
        for (let i = 0; i < selRows.length; i++) {
            this.allSelectedProductIds.add(selRows[i].Id);
        }

        this.selectedProductCode  = Array.from(this.allSelectedProductIds);
        this.SelectedRecordCount  = this.selectedProductCode.length;
        this.selectedRows         = selRows;
        this.DisableNext          = this.selectedProductCode.length === 0;

        // Rebuild SelectedProductData across all pages
        const selectedSet = new Set(this.selectedProductCode);
        this.SelectedProductData = this.AllProductData.filter(p => selectedSet.has(p.Id));
    }

    fillselectedRows() {
        this.selectedRows = [];
        for (let i = 0; i < this.ShowTableData.length; i++) {
            if (this.selectedProductCode.includes(this.ShowTableData[i].Id)) {
                this.selectedRows.push(this.ShowTableData[i]);
            }
        }
    }

    // ── Page 1 – Search ───────────────────────────────────────────────────────

    showFilteredProducts(event) {
        if (event.keyCode === 13) {
            this.isFirstPage  = false;
            this.showErrorMsg = false;
        } else {
            if (this.AllProductData.length > 0) {
                this.handleKeyChange(event);
            }
            const searchBoxWrapper = this.template.querySelector('.lookupContainer');
            if (searchBoxWrapper) {
                searchBoxWrapper.classList.add('slds-show');
                searchBoxWrapper.classList.remove('slds-hide');
            }
        }
    }

    handleKeyChange(event) {
        this.isSearchLoading = true;
        this.searchKey       = event.target.value;
        const data           = [];
        for (let i = 0; i < this.AllProductData.length; i++) {
            const p = this.AllProductData[i];
            if (p != null &&
                (p.Name.toLowerCase().includes(this.searchKey.toLowerCase()) ||
                 p.ProductCode.includes(this.searchKey))) {
                data.push(p);
            }
        }
        this.paginiateData(JSON.stringify(data));
        this.page = 1;
        this.recordPerPage(1, this.SelectedProductData, data);
    }

    toggleResult(event) {
        const lookupInputContainer = this.template.querySelector('.lookupInputContainer');
        if (!lookupInputContainer) return;
        const clsList    = lookupInputContainer.classList;
        const whichEvent = event.target.getAttribute('data-source');
        if (whichEvent === 'searchInputField') {
            clsList.add('slds-is-open');
        } else if (whichEvent === 'lookupContainer') {
            clsList.remove('slds-is-open');
        }
    }

    handelSelectedRecord(event) {
        const objId = event.target.dataset.recid;
        const searchBoxWrapper = this.template.querySelector('.lookupContainer');
        if (searchBoxWrapper) {
            searchBoxWrapper.classList.remove('slds-show');
            searchBoxWrapper.classList.add('slds-hide');
        }
        this.selectedRecord = this.lstResult.find(data => data.Id === objId);
        if (this.selectedRecord) {
            this.selectedProductCode.push(this.selectedRecord.Id);
            this.SelectedRecordCount += 1;
            this.ShowTableData.push(this.selectedRecord);
            this.fillselectedRows();
        }
    }

    // ── Navigation / Close ────────────────────────────────────────────────────

    goBackToRecord() {
        this.closeModal();
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: `/lightning/r/Opportunity/${this.recId}/view` }
        });
        setTimeout(() => { window.location.reload(); }, 300);
    }

    closeModal() {
        this.isModalOpen         = false;
        this.SelectedRecordCount = 0;
        this.PriceBook           = '';
        this.ShowTableData       = [];
        this.selectedProductCode = [];
        this.AllProductData      = [];
        this.SelectedProductData = [];
        this.lstResult           = [];
        this.hasRecords          = true;
        this.searchKey           = '';
        this.isSearchLoading     = false;
        this.isFirstPage         = true;
        this.isSecondPage        = false;
        this.selectedRows        = [];
        this.ShowViewAll         = false;
        this.ShowSelected        = true;
        this.showErrorMsg        = false;
        this.filteredData        = [];
        this.FilterForm          = { ProductFamily: '' };
        this.datafilterval       = false;
        this.DisableNext         = true;
        this.cartProducts        = [];
        this.showViewCart        = false;
        this.arcProductDetails   = [];
        this.allSelectedProductIds.clear();
    }

    // ── Pagination ─────────────────────────────────────────────────────────────

    paginiateData(results) {
        const data            = JSON.parse(results);
        this.paginationDataList = data;
        this.totalRecountCount  = data.length;
        this.totalPage          = Math.ceil(this.totalRecountCount / this.pageSize);
        this.ShowTableData      = this.paginationDataList.slice(0, this.pageSize);
        this.endingRecord       = this.pageSize;
        this.showSpinner        = false;
    }

    firstPage() {
        this.page = 1;
        this.recordPerPage(this.page, this.SelectedProductData, this.paginationDataList);
    }

    nextHandler() {
        if (this.page < this.totalPage) {
            this.page++;
            this.recordPerPage(this.page, this.SelectedProductData, this.paginationDataList);
        }
    }

    previousHandler() {
        if (this.page > 1) {
            this.page--;
            this.recordPerPage(this.page, this.SelectedProductData, this.paginationDataList);
        }
    }

    lastPage() {
        this.page = this.totalPage;
        if (this.page > 1) {
            this.recordPerPage(this.page, this.SelectedProductData, this.paginationDataList);
        }
    }

    recordPerPage(page, selectedRecords, data) {
        this.startingRecord = (page - 1) * this.pageSize;
        this.endingRecord   = this.pageSize * page;
        this.endingRecord   = this.endingRecord > this.totalRecountCount
            ? this.totalRecountCount : this.endingRecord;
        this.ShowTableData  = data.slice(this.startingRecord, this.endingRecord);
        this.startingRecord = this.startingRecord + 1;

        // Restore selected rows for the new page
        this.selectedRows = [];
        for (let i = 0; i < this.ShowTableData.length; i++) {
            if (this.allSelectedProductIds.has(this.ShowTableData[i].Id)) {
                this.selectedRows.push(this.ShowTableData[i]);
            }
        }

        setTimeout(() => {
            const datatable = this.template.querySelector('[data-id="datatable"]');
            if (datatable) datatable.selectedRows = this.selectedRows;
        }, 100);
    }

    // ── Utility ───────────────────────────────────────────────────────────────

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}