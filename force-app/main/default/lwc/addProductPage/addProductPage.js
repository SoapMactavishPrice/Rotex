import { LightningElement, wire, track } from 'lwc';
import findProducts from '@salesforce/apex/AddProductPageQuote.findProduct';
import saveProducts from '@salesforce/apex/AddProductPageQuote.saveProducts';
import getproductfamily from '@salesforce/apex/AddProductPageQuote.getproductfamily';
import getCustomerDiscount from '@salesforce/apex/AddProductPageQuote.getCustomerDiscount';
import findProductsOptimized from '@salesforce/apex/AddProductPageQuote.findProductsOptimized';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';
const DELAY = 300;

const COLS = [
    { label: 'Product Name', fieldName: 'purl', type: 'url', typeAttributes: { label: { fieldName: 'Name' } } },
    { label: 'Product Code', fieldName: 'ProductCode', type: 'text' },
    // { label: 'HSN Master', fieldName: 'hsnMasterCode', type: 'text' },
    // { label: 'Product Category', fieldName: 'Family', type: 'text' },
    // { label: 'Pack Size', fieldName: 'PackSize', type: 'text' },
    { label: 'List Price', fieldName: 'Price', type: 'currency', cellAttributes: { alignment: 'left' } },
    { label: 'List Price', fieldName: 'ListPrice', type: 'currency', cellAttributes: { alignment: 'left' } },
    { label: 'ARC', fieldName: 'IsARC', type: 'boolean', cellAttributes: { alignment: 'left' } },
    { label: 'Product Description', fieldName: 'Description', type: 'text' }

];

import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';


export default class AddProductPage extends NavigationMixin(LightningElement) {
    cols = COLS;

    @track showSpinner = true;
    @track searchDisabled = true;

    get searchDisability() {

        return this.searchDisabled
            || this.showSpinner;

    }

    @track recId;
    @wire(CurrentPageReference)
    setCurrentPageReference(currentPageReference) {
        //console.log('currentPageReference', currentPageReference);
        //console.log('state', currentPageReference.attributes.attributes);
        this.currentPageReference = currentPageReference.state.c__refRecordId;
        //console.log('this.currentPageReference', this.currentPageReference.c__refRecordId);
        if (this.currentPageReference) {
            this.recId = this.currentPageReference;
            console.log('Opp Id', this.recId);
        }
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
    @track isSearchLoading = false;
    @track delayTimeout;
    @track isFirstPage = true;
    @track isSecondPage = false;
    @track selectedRows = [];
    @track ShowViewAll = false;
    @track datafilterval = false;
    @track prodfamilylst = [];
    @track FilterForm = { "ProductFamily": "" };
    @track isProductSelect = true;
    mapIdQuantity;
    mapIdSalesPrice;
    mapIdDate;
    mapIdDiscount;
    mapIdLineDescription;
    @track showErrorMsg = false;
    @track filteredData = [];
    @track DisableNext = true;
    @track selectedItemType = '';


    @track showViewCart = false;
    @track cartProducts = [];
    @track allSelectedProductIds = new Set();

    // Add this method
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // Add to Cart method
    addToCart() {
        console.log('addToCart called, selected products count:', this.selectedProductCode.length);

        if (this.selectedProductCode.length === 0) {
            this.showToast('Error', 'Please select at least one product', 'error');
            return;
        }

        // Get selected products from AllProductData
        let selectedProducts = [];
        for (let i = 0; i < this.AllProductData.length; i++) {
            if (this.selectedProductCode.includes(this.AllProductData[i].Id)) {
                let product = JSON.parse(JSON.stringify(this.AllProductData[i]));
                product.Quantity = product.ARCQuantity || 1;
                product.Price = product.ListPrice;
                product.Discount = this.customerSAPdiscount;
                selectedProducts.push(product);
            }
        }

        console.log('Selected products to add:', selectedProducts.length);
        console.log('Existing cart products:', this.cartProducts.length);

        if (selectedProducts.length === 0) {
            this.showToast('Info', 'No products selected', 'info');
            return;
        }

        // Add to existing cart
        this.cartProducts = [...this.cartProducts, ...selectedProducts];
        console.log('Cart total products after add:', this.cartProducts.length);

        // Clear selections
        this.selectedProductCode = [];
        this.allSelectedProductIds.clear();
        this.SelectedProductData = [];
        this.selectedRows = [];
        this.SelectedRecordCount = 0;
        this.DisableNext = true;

        // Clear selection in datatable
        const datatable = this.template.querySelector('[data-id="datatable"]');
        if (datatable) {
            datatable.selectedRows = [];
        }

        // Show success message
        this.showToast('Success', `${selectedProducts.length} product(s) added to cart. Total in cart: ${this.cartProducts.length}`, 'success');

        // Always show View Cart button when cart has items
        this.showViewCart = this.cartProducts.length > 0;
    }

    // View Cart method
    viewCart() {
        console.log('viewCart called, cart products:', this.cartProducts.length);

        if (this.cartProducts.length === 0) {
            this.showToast('Info', 'Cart is empty', 'info');
            return;
        }

        // Prepare cart products for edit page
        let cartItems = [];
        for (let i = 0; i < this.cartProducts.length; i++) {
            let product = this.cartProducts[i];
            let productCopy = JSON.parse(JSON.stringify(product));
            let newPrice = productCopy.ListPrice;
            if (this.customerSAPdiscount > 0 && !productCopy.IsARC) {
                newPrice = productCopy.ListPrice * (1 - (this.customerSAPdiscount / 100));
                newPrice = newPrice.toFixed(2);
            }
            productCopy.NetPrice = newPrice;

            let newPriceNum = Number(newPrice) || 0;
            let incoPercent = Number(productCopy.IncoTerms) || 0;
            productCopy.Price = parseFloat((newPriceNum + (newPriceNum * incoPercent / 100)).toFixed(2));

            cartItems.push(productCopy);
        }

        this.SelectedProductData = cartItems;
        this.isFirstPage = false;
        this.isSecondPage = true;
    }

    // Delete product from cart
    deleteProductFromCart(event) {
        const productId = event.currentTarget.dataset.id;

        // Remove from cart products
        this.cartProducts = this.cartProducts.filter(product => product.Id !== productId);

        // Remove from current view
        this.SelectedProductData = this.SelectedProductData.filter(product => product.Id !== productId);

        // Update View Cart button visibility
        this.showViewCart = this.cartProducts.length > 0;

        // Show success message
        this.showToast('Success', 'Product removed from cart', 'success');

        // If cart becomes empty, go back to add products page
        if (this.cartProducts.length === 0) {
            this.showViewCart = false;
            this.handleback();
        }
    }

    connectedCallback() {
        this.mapIdQuantity = new Map();
        this.mapIdSalesPrice = new Map();
        this.mapIdDate = new Map();
        this.mapIdDiscount = new Map();
        this.mapIdLineDescription = new Map();

        //this.isModalOpen = true;
        this.ShowTableData = [];
        this.selectedProductCode = [];
        this.AllProductData = [];
        this.SelectedProductData = [];
        this.isModalOpen = true;
        console.log('connected call back called');

        // this.getproductfamily();

        this.cols = this.cols.filter(col => col.fieldName !== 'ListPrice');
        this.cols = this.cols.filter(col => col.fieldName !== 'IsARC');

        // this.openModal();
        // findProducts({ recordId: this.recId, productFamily: [] }).then(result => {
        //     console.log('connectedCallback = ', result);
        //     let dataObj = JSON.parse(result);
        //     console.log(dataObj);
        //     this.AllProductData = dataObj.productList;
        //     this.ShowTableData = this.AllProductData;
        //     this.paginiateData(JSON.stringify(this.AllProductData));
        //     this.page = 1;
        // });
        this.showSpinner = false;
        this.handlerGetCustomerDiscount();
    }

    getproductfamily() {
        //this.isModalOpen = true;
        getproductfamily().then(result => {
            console.log('ProductFamily' + result);
            this.prodfamilylst = result;
        });
    }

    get options() {
        return this.prodfamilylst;
    }

    get itemsOptions() {
        let items = [
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

        return items;
    }


    handleItemOptions(event) {
        this.showSpinner = true;
        let option = event.target.value;
        this.selectedItemType = option;

        if (option == '') {
            this.AllProductData = [];
            this.ShowTableData = [];
            this.showSpinner = false;
            this.searchDisabled = true;
            return;
        }

        findProductsOptimized({
            recordId: this.recId,
            searchKey: this.searchKey,
            itemType: option
        })
            .then(chunks => {
                console.log('Received chunks:', chunks.length);

                // Combine all chunks
                let allProducts = [];
                let priceBook = '';

                chunks.forEach(chunkStr => {
                    try {
                        let chunkObj = JSON.parse(chunkStr);

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

                        console.log(`Chunk ${chunkObj.chunkIndex + 1}/${chunkObj.totalChunks}: ${chunkObj.productList?.length || 0} products`);
                    } catch (parseError) {
                        console.error('Error parsing chunk:', parseError);
                        throw parseError;
                    }
                });

                console.log('Total products loaded:', allProducts.length);

                this.AllProductData = allProducts;
                this.ShowTableData = allProducts;
                this.paginiateData(JSON.stringify(this.AllProductData));
                this.page = 1;
                this.showSpinner = false;
                this.searchDisabled = false;
            })
            .catch(error => {
                console.error('Error loading products:', error);
                this.showSpinner = false;
                this.searchDisabled = true;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to load products: ' + (error.body?.message || error.message),
                    variant: 'error',
                }));
            });
    }

    @track disabledApplayButton = true;
    handleChange(event) {
        console.log('name', event.target.name);
        this.FilterForm[event.target.name] = event.detail.value;
        console.log('this.FilterForm', JSON.stringify(this.FilterForm));

        if ((this.FilterForm["ProductCode"] != undefined || this.FilterForm["ProductCode"] != '') &&
            (this.FilterForm["ProductFamily"] != undefined || this.FilterForm["ProductFamily"].length != 0)) {
            this.disabledApplayButton = false;
        } else
            if ((this.FilterForm["ProductCode"] == undefined || this.FilterForm["ProductCode"] == '') &&
                (this.FilterForm["ProductFamily"] == undefined || this.FilterForm["ProductFamily"].length == 0)) {
                this.disabledApplayButton = false; {
                    this.disabledApplayButton = true;
                }
            }
    }

    @track customerSAPdiscount = 0;
    handlerGetCustomerDiscount() {
        getCustomerDiscount({
            quoteId: this.recId
        }).then((result) => {
            console.log('getCustomerDiscount:>>> ', result);

            if (result != null) {
                this.customerSAPdiscount = parseFloat(result);
                // Add negative handling - same as Opportunity
                if (this.customerSAPdiscount < 0) {
                    this.customerSAPdiscount = this.customerSAPdiscount * -1;
                }
            }
        })
    }

    openModal() {
        //window.location.reload();
        this.isModalOpen = true;
        this.ShowTableData = [];
        this.selectedProductCode = [];
        this.AllProductData = [];
        this.SelectedProductData = [];
        findProducts({ recordId: this.recId, productFamily: [], searchKey: '', itemType: '' }).then(result => {
            console.log(result);
            let dataObj = JSON.parse(result);
            console.log(dataObj);
            this.AllProductData = dataObj.productList;
            this.ShowTableData = dataObj.productList;
            this.PriceBook = dataObj.priceBook;

            this.paginiateData(JSON.stringify(this.AllProductData));
        });
    }

    handleShowSelected() {

        this.ShowSelected = false;
        console.log('handleShowSelected called...');
        this.ShowTableData = this.AllProductData;
        this.ShowViewAll = true;
        this.fillselectedRows();
        this.RecalculateselectedProductCode();
        this.paginiateData(JSON.stringify(this.AllProductData));
        this.page = 1;
    }

    handleviewAll(event) {
        this.ShowSelected = true;
        this.ShowViewAll = false;
        this.SelectedProduct(this.tempEvent);
        this.fillselectedRows();
        this.RecalculateselectedProductCode();

        console.log('method view all');
        this.paginiateData(JSON.stringify(this.AllProductData));
        this.page = 1;
    }

    fillselectedRows() {
        this.selectedRows = []
        for (let i = 0; i < this.ShowTableData.length; i++) {
            if (this.selectedProductCode.includes(this.ShowTableData[i].Id)) {
                this.selectedRows.push(this.ShowTableData[i]);
            }
        }
    }

    RecalculateselectedProductCode() {
        this.selectedProductCode = [];
        for (let i = 0; i < this.SelectedProductData.length; i++) {
            this.selectedProductCode.push(this.SelectedProductData[i].Id);
        }
    }

    @track tempEvent;
    SelectedProduct(event) {
        this.tempEvent = event;
        const selRows = event.detail.selectedRows;
        const currentPageIds = this.ShowTableData.map(item => item.Id);

        // Remove selections that are no longer selected on current page
        for (let i = 0; i < currentPageIds.length; i++) {
            const isSelected = selRows.some(row => row.Id === currentPageIds[i]);
            if (!isSelected && this.allSelectedProductIds.has(currentPageIds[i])) {
                this.allSelectedProductIds.delete(currentPageIds[i]);
            }
        }

        // Add newly selected products
        for (let i = 0; i < selRows.length; i++) {
            this.allSelectedProductIds.add(selRows[i].Id);
        }

        // Update selectedProductCode array
        this.selectedProductCode = Array.from(this.allSelectedProductIds);
        this.SelectedRecordCount = this.selectedProductCode.length;
        this.selectedRows = selRows;
        this.DisableNext = this.selectedProductCode.length === 0;

        // Build SelectedProductData from all selected products across all pages
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
    }


    goBackToRecord() {

        this.closeModal();

        window.location.replace(
            `/lightning/r/Quote/${this.recId}/view`
        );
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

    }

    nextDetails() {
        this.isFirstPage = false;
        this.isSecondPage = true;
        this.SelectedProductData = [];
        let tempSelectedProductData = [];
        for (let i = 0; i < this.selectedProductCode.length; i++) {
            //this.selectedProductCode[i].index = i;
            for (let j = 0; j < this.AllProductData.length; j++) {
                if (this.selectedProductCode.includes(this.AllProductData[j].Id)) {
                    var newPrice = this.AllProductData[j].ListPrice;
                    if (this.customerSAPdiscount > 0 && !this.AllProductData[j].IsARC) {
                        newPrice = this.AllProductData[j].ListPrice * (1 - (this.customerSAPdiscount / 100));
                        newPrice = newPrice.toFixed(2);
                        this.AllProductData[j].Discount = this.customerSAPdiscount;
                    }
                    this.AllProductData[j].NetPrice = newPrice;

                    let newPriceNum = Number(newPrice) || 0;
                    let incoPercent = Number(this.AllProductData[j].IncoTerms) || 0;

                    this.AllProductData[j].Price = newPriceNum + (newPriceNum * incoPercent / 100);

                    // Round to 2 decimals
                    this.AllProductData[j].Price = parseFloat(this.AllProductData[j].Price.toFixed(2));


                    tempSelectedProductData.push(this.AllProductData[j]);
                }
            }

        }

        this.SelectedProductData = tempSelectedProductData;

        // //setTimeout(() => {
        //     console.log(this.selectedProductCode.length + '  --- ' + this.SelectedProductData.length);
        //     if (this.SelectedProductData.length > 0) {

        //         for (let j = 0; j < this.SelectedProductData.length; j++) {
        //             this.SelectedProductData[j].hindex = j;
        //             this.SelectedProductData[j].index = j;
        //         }

        //     }
        //console.log('selectedProductCode = ', JSON.stringify(this.selectedProductCode));
        this.SelectedProductData = [...new Set(this.SelectedProductData)];
        clearTimeout(this.timeoutId); // no-op if invalid id
        this.timeoutId = setTimeout(this.updateIndex.bind(this), 1000);
        //}, 600);



    }

    updateIndex() {

    }

    datafilter() {
        if (this.datafilterval) {
            this.datafilterval = false;
        } else {
            this.datafilterval = true;
        }
    }

    hadleDelete(event) {
        this.template.querySelectorAll('tr').forEach(ele => {
            console.log('ele-----------' + JSON.stringify(ele));
            console.log('event.target.value-----------' + JSON.stringify(event.target.value));
            if (ele.id.includes(event.target.value)) {
                ele.classList.add('slds-hide')
            }
        });
    }


    saveDetails() {
        var isValidate = true;
        for (var i = 0; i < this.SelectedProductData.length; i++) {
            if (this.SelectedProductData[i]["Quantity"] == 0 || this.SelectedProductData[i]["Quantity"] == undefined) {
                isValidate = false;
                break;
            }
        }

        if (isValidate && this.SelectedProductData.length > 0) {
            this.showSpinner = true;
            let str = JSON.stringify(this.SelectedProductData);
            saveProducts({ recordData: str, recId: this.recId, customerSAPdiscount: this.customerSAPdiscount })
                .then(result => {
                    this.showSpinner = false;
                    this.showToast('Success', 'Products Added Successfully', 'success');

                    // Clear cart
                    this.cartProducts = [];
                    this.showViewCart = false;
                    this.allSelectedProductIds.clear();
                    this.selectedProductCode = [];

                    // Close modal and refresh
                    this.isModalOpen = false;
                    this.dispatchEvent(new RefreshEvent());

                    this.closeModal();

                    setTimeout(() => {

                        window.location.replace(
                            `/lightning/r/Quote/${this.recId}/view`
                        );

                    }, 500);
                })
                .catch(error => {
                    this.showSpinner = false;
                    this.showToast('Error', error.body.message, 'error');
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

        // Clear maps
        this.mapIdQuantity = new Map();
        this.mapIdSalesPrice = new Map();
        this.mapIdDate = new Map();
        this.mapIdDiscount = new Map();
        this.mapIdLineDescription = new Map();

        // Clear selection
        this.selectedProductCode = [];
        this.SelectedProductData = [];
        this.selectedRows = [];
        this.SelectedRecordCount = 0;
        this.DisableNext = true;
        this.searchKey = '';
        this.FilterForm = { "ProductFamily": "" };

        // Clear Item Type selection
        const itemTypeCombobox = this.template.querySelector('lightning-combobox[name="itemType"]');
        if (itemTypeCombobox) {
            itemTypeCombobox.value = '';
        }
        this.selectedItemType = '';

        // Reload product list
        this.AllProductData = [];
        this.ShowTableData = [];
        this.getProductList();
        this.paginiateData(JSON.stringify(this.AllProductData));
        this.page = 1;
    }

    getProductList() {
        if (!this.selectedItemType || this.selectedItemType === '') {
            this.AllProductData = [];
            this.ShowTableData = [];
            this.showSpinner = false;
            return;
        }

        findProductsOptimized({
            recordId: this.recId,
            searchKey: this.searchKey,
            itemType: this.selectedItemType
        }).then(chunks => {
            let allProducts = [];
            chunks.forEach(chunkStr => {
                let chunkObj = JSON.parse(chunkStr);
                if (chunkObj.productList && Array.isArray(chunkObj.productList)) {
                    allProducts = allProducts.concat(chunkObj.productList);
                }
            });
            this.AllProductData = allProducts;
            this.ShowTableData = allProducts;
            this.paginiateData(JSON.stringify(this.AllProductData));
            this.page = 1;
            this.showSpinner = false;
        }).catch(error => {
            this.showSpinner = false;
            this.showToast('Error', 'Failed to load products', 'error');
        });
    }


    showFilteredProducts(event) {

        this.searchKey =

            event.target.value;

        clearTimeout(

            this.typingTimeout

        );

        this.typingTimeout =

            setTimeout(() => {

                if (

                    this.selectedItemType

                ) {

                    this.handleItemOptions({

                        target: {

                            value:

                                this.selectedItemType

                        }

                    });

                }

            }, 500);

    }

    // handleKeyChange(event) {

    //     this.searchKey =

    //         event.target.value
    //             ?
    //             event.target.value
    //                 .trim()
    //                 .toLowerCase()
    //             :
    //             '';

    //     let data = [];

    //     for (

    //         let i = 0;

    //         i < this.AllProductData.length;

    //         i++

    //     ) {

    //         let rec =

    //             this.AllProductData[i];

    //         let prodName =

    //             rec.Name
    //                 ?
    //                 rec.Name.toLowerCase()
    //                 :
    //                 '';

    //         let prodCode =

    //             rec.ProductCode
    //                 ?
    //                 String(
    //                     rec.ProductCode
    //                 )
    //                     .trim()
    //                     .toLowerCase()
    //                 :
    //                 '';

    //         if (

    //             prodName.includes(
    //                 this.searchKey
    //             )

    //             ||

    //             prodCode.includes(
    //                 this.searchKey
    //             )

    //         ) {

    //             data.push(rec);

    //         }

    //     }

    //     this.paginiateData(

    //         JSON.stringify(data)

    //     );

    //     this.page = 1;

    //     this.recordPerPage(

    //         1,

    //         this.SelectedProductData,

    //         data

    //     );

    // }



    toggleResult(event) {
        console.log('toggleResult called...');
        const lookupInputContainer = this.template.querySelector('.lookupInputContainer');
        const clsList = lookupInputContainer.classList;
        const whichEvent = event.target.getAttribute('data-source');
        switch (whichEvent) {
            case 'searchInputField':
                clsList.add('slds-is-open');
                break;
            case 'lookupContainer':
                clsList.remove('slds-is-open');
                break;
        }
    }

    @track dupSelectedRecordDound = [];
    handelSelectedRecord(event) {
        //console.log(' event.target.dataset ' + JSON.stringify(event.target.dataset));
        //console.log(' event.target ' + JSON.stringify(event.target));

        var objId = event.target.dataset.recid;
        //console.log(' objId ' + objId);
        const searchBoxWrapper = this.template.querySelector('.lookupContainer');
        searchBoxWrapper.classList.remove('slds-show');
        searchBoxWrapper.classList.add('slds-hide');
        this.selectedRecord = this.lstResult.find(data => data.Id === objId);
        this.selectedProductCode.push(this.selectedRecord.Id);
        this.dupSelectedRecordDound.push(this.selectedRecord.Id);
        this.SelectedRecordCount += 1;
        this.ShowTableData.push(this.selectedRecord);

        this.handleShowSelected();
    }

    handleQuantityChange(event) {
        var selectedRow = event.currentTarget;
        var key = selectedRow.dataset.targetId;
        let record = this.SelectedProductData.find(item => item.Id == key);

        console.log(record);


        //console.log(' key ' + key + ' event.target.value ' + event.target.value);
        this.mapIdQuantity.set(key, event.target.value);

        if (record.IsARC) {
            let enteredQty = parseInt(event.target.value, 10);
            let resultValue;

            // Sort array by label just in case
            let sortedArr = [...record.PriceOption].sort((a, b) => a.label - b.label);

            // Find the closest label <= enteredQty
            for (let i = sortedArr.length - 1; i >= 0; i--) {
                if (enteredQty >= sortedArr[i].label) {
                    resultValue = sortedArr[i].value;
                    break;
                }
            }

            // If nothing matches (smaller than smallest label), take the first value
            if (!resultValue && sortedArr.length > 0) {
                resultValue = sortedArr[0].value;
            }
            console.log('For Qty:', enteredQty, 'Value:', resultValue);

            this.SelectedProductData = this.SelectedProductData.map(rec => {
                var newPrice = resultValue;

                let newPriceNum = Number(newPrice) || 0;
                let incoPercent = Number(rec.IncoTerms) || 0;

                newPrice = newPriceNum + (newPriceNum * incoPercent / 100);

                // Round to 2 decimals
                newPrice = parseFloat(newPrice.toFixed(2));

                if (rec.Id == key) {
                    return { ...rec, Price: newPrice }; // merge old + new values
                }
                return rec;
            });

        }


    }

    handleSalesPriceChange(event) {

        var selectedRow = event.currentTarget;
        var key = selectedRow.dataset.targetId;
        this.mapIdSalesPrice.set(key, event.target.value);
    }

    handleDiscountChange(event) {
        var selectedRow = event.currentTarget;
        var key = selectedRow.dataset.targetId;
        this.mapIdDate.set(key, event.target.value);
        this.mapIdDiscount.set(key, event.target.value);

        this.SelectedProductData = this.SelectedProductData.map(record => {
            if (record.Id == key) {
                var newNetPrice = record.ListPrice;
                var newPrice = record.Price;
                if (event.target.value > 0) {
                    newNetPrice = record.ListPrice * (1 - (event.target.value / 100));
                    newNetPrice = newNetPrice.toFixed(2);
                }
                let newPriceNum = Number(newNetPrice) || 0;
                let incoPercent = Number(record.IncoTerms) || 0;

                newPrice = newPriceNum + (newPriceNum * incoPercent / 100);

                // Round to 2 decimals
                newPrice = parseFloat(newPrice.toFixed(2));
                return { ...record, NetPrice: newNetPrice, Price: newPrice }; // merge old + new values
            }
            return record;
        });

    }

    handleLineDescriptionChange(event) {
        var selectedRow = event.currentTarget;
        var key = selectedRow.dataset.targetId;
        this.mapIdLineDescription.set(key, event.target.value);
    }

    ApplyFilter() {
        const searchBox = this.template.querySelector('.searchBox');
        console.log('this.showSpinner 0', this.showSpinner);
        this.showSpinner = true;
        console.log('this.showSpinner 1', this.showSpinner);

        this.isFirstPage = true;
        setTimeout(() => {
            findProducts({ recordId: this.recId, productFamily: [], searchKey: this.searchKey, itemType: this.selectedItemType }).then(result => {
                let dataObj = JSON.parse(result);
                //console.log('filter code', this.FilterForm["ProductCode"]);
                //console.log('Family code', this.FilterForm["ProductFamily"]);
                this.ShowTableData = dataObj.productList;
                this.filteredData = dataObj.productList;
                this.fillselectedRows();
                this.isFirstPage = true;
                this.ShowViewAll = true;
                this.ShowSelected = true;

                //console.log('this.FilterForm["ProductFamily"]', this.FilterForm["ProductFamily"]);
                if (this.FilterForm["ProductCode"] != undefined && this.FilterForm["ProductCode"] != '') {
                    console.log('inside 1 product code');
                    var filteredProductData = [];
                    for (let i = 0; i < this.filteredData.length; i++) {

                        if (this.filteredData[i].ProductCode != '' && this.filteredData[i].ProductCode != null) {
                            if (this.filteredData[i].ProductCode.toLowerCase().includes(this.FilterForm["ProductCode"].toLowerCase())) {
                                if (this.FilterForm["ProductFamily"] != undefined && this.FilterForm["ProductFamily"].length != 0) {
                                    for (let j = 0; j < this.FilterForm["ProductFamily"].length; j++) {
                                        if (this.FilterForm["ProductFamily"][j] == this.filteredData[i].Family) {
                                            console.log('search key', this.searchKey);
                                            let productName =

                                                this.filteredData[i]
                                                    .Name
                                                    ?
                                                    this.filteredData[i]
                                                        .Name
                                                        .toLowerCase()
                                                    :
                                                    '';

                                            let productCode =

                                                this.filteredData[i]
                                                    .ProductCode
                                                    ?
                                                    String(
                                                        this.filteredData[i]
                                                            .ProductCode
                                                    )
                                                        .toLowerCase()
                                                    :
                                                    '';

                                            if (

                                                productName.includes(
                                                    this.searchKey
                                                        .toLowerCase()
                                                )

                                                ||

                                                productCode.includes(
                                                    this.searchKey
                                                        .toLowerCase()
                                                )

                                            ) {

                                                filteredProductData.push(
                                                    this.filteredData[i]
                                                );

                                            } else {
                                                console.log('else name key',);
                                            }
                                        } else {
                                            console.log('family name key',);
                                            //filteredProductData.push(this.filteredData[i]);
                                        }
                                    }
                                } else {
                                    let productName =

                                        this.filteredData[i]
                                            .Name
                                            ?
                                            this.filteredData[i]
                                                .Name
                                                .toLowerCase()
                                            :
                                            '';

                                    let productCode =

                                        this.filteredData[i]
                                            .ProductCode
                                            ?
                                            String(
                                                this.filteredData[i]
                                                    .ProductCode
                                            )
                                                .toLowerCase()
                                            :
                                            '';

                                    if (

                                        productName.includes(
                                            this.searchKey
                                                .toLowerCase()
                                        )

                                        ||

                                        productCode.includes(
                                            this.searchKey
                                                .toLowerCase()
                                        )

                                    ) {

                                        filteredProductData.push(
                                            this.filteredData[i]
                                        );

                                    }
                                }

                            }
                        }
                    }
                    this.showErrorMsg = false;
                    this.ShowTableData = filteredProductData;
                    this.isProductSelect = false;
                    this.fillselectedRows();
                    this.RecalculateselectedProductCode();
                    this.paginiateData(JSON.stringify(this.ShowTableData));
                    this.page = 1;
                    //this.showSpinner = false
                    //console.log('filteredProductData = ', filteredProductData);
                }
                else if (this.FilterForm["ProductFamily"] != undefined && this.FilterForm["ProductFamily"].length != 0) {
                    console.log('inside 2nd product code');
                    var filteredProductData = [];
                    for (let i = 0; i < this.filteredData.length; i++) {
                        for (let j = 0; j < this.FilterForm["ProductFamily"].length; j++) {
                            if (this.FilterForm["ProductFamily"][j] == this.filteredData[i].Family) {
                                let productName =

                                    this.filteredData[i]
                                        .Name
                                        ?
                                        this.filteredData[i]
                                            .Name
                                            .toLowerCase()
                                        :
                                        '';

                                let productCode =

                                    this.filteredData[i]
                                        .ProductCode
                                        ?
                                        String(
                                            this.filteredData[i]
                                                .ProductCode
                                        )
                                            .toLowerCase()
                                        :
                                        '';

                                if (

                                    productName.includes(

                                        this.searchKey
                                            .toLowerCase()

                                    )

                                    ||

                                    productCode.includes(

                                        this.searchKey
                                            .toLowerCase()

                                    )

                                ) {

                                    filteredProductData.push(

                                        this.filteredData[i]

                                    );

                                }
                            }
                        }
                    }
                    this.showErrorMsg = false;
                    this.ShowTableData = filteredProductData;
                    this.isProductSelect = false;
                    this.fillselectedRows();
                    this.RecalculateselectedProductCode();

                    this.paginiateData(JSON.stringify(this.ShowTableData));
                    this.page = 1;
                    //this.showSpinner = false
                    //console.log('filteredProductData = ', filteredProductData);
                }
                else

                    if (this.searchKey != '' && (this.FilterForm["ProductFamily"] == undefined
                        || this.FilterForm["ProductFamily"].length == 0) &&
                        (this.FilterForm["ProductCode"] == undefined || this.FilterForm["ProductCode"] == '')) {
                        console.log('inside 3 product search');
                        var filteredProductData = [];
                        for (let i = 0; i < this.filteredData.length; i++) {
                            //for (let j = 0; j < this.FilterForm["ProductFamily"].length; j++) {
                            //if (this.FilterForm["ProductFamily"][j] == this.filteredData[i].Family) {
                            let productName =

                                this.filteredData[i]
                                    .Name
                                    ?
                                    this.filteredData[i]
                                        .Name
                                        .toLowerCase()
                                    :
                                    '';

                            let productCode =

                                this.filteredData[i]
                                    .ProductCode
                                    ?
                                    String(
                                        this.filteredData[i]
                                            .ProductCode
                                    )
                                        .toLowerCase()
                                    :
                                    '';

                            if (

                                productName.includes(

                                    this.searchKey
                                        .toLowerCase()

                                )

                                ||

                                productCode.includes(

                                    this.searchKey
                                        .toLowerCase()

                                )

                            ) {

                                filteredProductData.push(

                                    this.filteredData[i]

                                );

                            }
                        }
                        this.showErrorMsg = false;
                        this.ShowTableData = filteredProductData;
                        this.isProductSelect = false;
                        this.fillselectedRows();
                        this.RecalculateselectedProductCode();

                        this.paginiateData(JSON.stringify(this.ShowTableData));
                        this.page = 1;
                        //this.showSpinner = false
                    }
                    else {
                        if (this.searchKey == '' && (this.FilterForm["ProductFamily"] == undefined
                            || this.FilterForm["ProductFamily"].length == 0) &&
                            (this.FilterForm["ProductCode"] == undefined || this.FilterForm["ProductCode"] == '')) {

                            this.showErrorMsg = false;
                            this.ShowTableData = this.AllProductData;
                            this.isProductSelect = false;
                            this.fillselectedRows();
                            this.RecalculateselectedProductCode();

                            this.paginiateData(JSON.stringify(this.AllProductData));
                            this.page = 1;
                        }
                    }

            });
            this.showSpinner = false;

        }, 600);

        //}

        this.datafilterval = false;

    }

    clearFilter() {
        this.FilterForm = { "ProductFamily": "" };
        this.disabledApplayButton = true;
        this.datafilterval = false;

        this.fillselectedRows();
        this.RecalculateselectedProductCode();
        this.paginiateData(JSON.stringify(this.AllProductData));
        this.page = 1;
    }


    @track paginationDataList;
    paginiateData(results) {
        let data = JSON.parse(results);
        this.paginationDataList = data;
        this.totalRecountCount = data.length;
        this.totalPage = Math.ceil(this.totalRecountCount / this.pageSize);
        this.ShowTableData = this.paginationDataList.slice(0, this.pageSize);
        ////console.log('totalRecountCount ', this.totalRecountCount);
        this.endingRecord = this.pageSize;
        this.error = undefined;
        this.showSpinner = false;
    }



    page = 1;
    items = [];
    data = [];

    startingRecord = 1;
    endingRecord = 0;
    pageSize = 10;
    totalRecountCount = 0;
    totalPage = 0;


    get bDisableFirst() {
        return this.page == 1;
    }
    get bDisableLast() {
        return this.page == this.totalPage;
    }


    firstPage() {
        this.page = 1;

        this.recordPerPage(this.page, this.SelectedProductData, this.paginationDataList);
        //console.log('this.SelectedProductData 604', this.SelectedProductData.length);
        //this.template.querySelector('[data-id="datatable"]').selectedRows = this.SelectedProductData;

    }

    previousHandler() {
        if (this.page > 1) {
            this.page = this.page - 1;
            //console.log('this.SelectedProductData 611', this.SelectedProductData.length);
            this.recordPerPage(this.page, this.SelectedProductData, this.paginationDataList);
        }
        // this.template.querySelector('[data-id="datatable"]').selectedRows = this.SelectedProductData;

    }

    nextHandler() {
        if ((this.page < this.totalPage) && this.page !== this.totalPage) {
            this.page = this.page + 1;
            //console.log('this.SelectedProductData 619', this.SelectedProductData.length);
            this.recordPerPage(this.page, this.SelectedProductData, this.paginationDataList);
        }

        //console.log('json -->', JSON.parse(this.template.querySelector('[data-id="datatable"]').selectedRows));



    }

    lastPage() {

        this.page = this.totalPage;
        if (this.page > 1) {
            console.log('this.SelectedProductData 633', this.SelectedProductData.length);
            this.recordPerPage(this.page, this.SelectedProductData, this.paginationDataList);
        }
        //this.template.querySelector('[data-id="datatable"]').selectedRows = this.SelectedProductData;

    }


    recordPerPage(page, selectedRecords, data) {
        let tempdata = data;
        this.startingRecord = ((page - 1) * this.pageSize);
        this.endingRecord = (this.pageSize * page);
        this.endingRecord = (this.endingRecord > this.totalRecountCount) ? this.totalRecountCount : this.endingRecord;
        this.ShowTableData = tempdata.slice(this.startingRecord, this.endingRecord);
        this.startingRecord = this.startingRecord + 1;

        // Preserve selections when changing pages
        this.selectedRows = [];
        for (let i = 0; i < this.ShowTableData.length; i++) {
            if (this.allSelectedProductIds.has(this.ShowTableData[i].Id)) {
                this.selectedRows.push(this.ShowTableData[i]);
            }
        }

        // Update the datatable selected rows
        setTimeout(() => {
            const datatable = this.template.querySelector('[data-id="datatable"]');
            if (datatable) {
                datatable.selectedRows = this.selectedRows;
            }
        }, 100);
    }



}