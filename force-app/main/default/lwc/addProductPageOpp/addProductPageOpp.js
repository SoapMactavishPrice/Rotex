import { LightningElement, wire, track } from 'lwc';
import findProducts from '@salesforce/apex/AddProductPageOpp.findProduct';
import findProductsOptimized from '@salesforce/apex/AddProductPageOpp.findProductsOptimized';
import saveProducts from '@salesforce/apex/AddProductPageOpp.saveProducts';
import getproductfamily from '@salesforce/apex/AddProductPageOpp.getproductfamily';
import getCustomerDiscount from '@salesforce/apex/AddProductPageOpp.getCustomerDiscount';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';
const DELAY = 300;

const COLS = [
    { label: 'Product Name', fieldName: 'purl', type: 'url', typeAttributes: { label: { fieldName: 'Name' } } },
    { label: 'Product Code', fieldName: 'ProductCode', type: 'text' },
    // { label: 'HSN Master', fieldName: 'hsnMasterCode', type: 'text' },
    // { label: 'Product Category', fieldName: 'Family', type: 'text' },
    // { label: 'Pack Size', fieldName: 'PackSize', type: 'text' },
    { label: 'List Price', fieldName: 'Price', type: 'currency', typeAttributes: { currencyCode: { fieldName: 'CurrencyIsoCode' } }, cellAttributes: { alignment: 'left' } },
    { label: 'List Price', fieldName: 'ListPrice', type: 'currency', typeAttributes: { currencyCode: { fieldName: 'CurrencyIsoCode' } }, cellAttributes: { alignment: 'left' } },
    { label: 'ARC', fieldName: 'IsARC', type: 'boolean', cellAttributes: { alignment: 'left' } },
    { label: 'Product Description', fieldName: 'Description', type: 'text' }

];

import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
import Price from '@salesforce/schema/Asset.Price';


export default class AddProductPage extends NavigationMixin(LightningElement) {
    cols = COLS;

    @track showSpinner = true;

    @track searchDisabled = true;

    get searchDisability() {
        return this.searchDisabled || this.showSpinner;
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
    @track firstHalfProductData = [];
    @track secondHalfProductData = [];
    @track thirdHalfProductData = [];
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

    // Update these properties (remove showAddToCart, keep showViewCart)
    @track showViewCart = false;
    @track cartProducts = [];
    // Add with your other @track properties
    @track allSelectedProductIds = new Set(); // Track all selected products across pages

    addToCart() {
        console.log('addToCart called, selected products count:', this.selectedProductCode.length);

        if (this.selectedProductCode.length === 0) {
            this.showToast('Error', 'Please select at least one product', 'error');
            return;
        }

        // Get selected products from AllProductData (all pages)
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

    // Add this method to your class
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }

    // Delete product from cart (no confirmation)
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

    handleback() {
        this.ShowSelected = true;
        this.isFirstPage = true;
        this.isSecondPage = false;

        // Show View Cart button if cart has products
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

        // Clear Item Type selection
        const itemTypeCombobox = this.template.querySelector('lightning-combobox[name="itemType"]');
        if (itemTypeCombobox) {
            itemTypeCombobox.value = '';
        }

        // Clear search
        this.searchKey = '';

        // Clear filters
        this.FilterForm = { "ProductFamily": "" };

        // Reload product list
        this.AllProductData = [];
        this.ShowTableData = [];
        this.getProductList();
        this.paginiateData(JSON.stringify(this.AllProductData));
        this.page = 1;
    }



    // saveDetails() {
    //     var deletedProducts = []
    //     this.template.querySelectorAll('tr').forEach(ele => {
    //         if (ele.classList.value.includes('slds-hide') && !ele.id.includes('firstRow')) {
    //             var temp = ele.id.split('-');
    //             if (temp.length > 0) {
    //                 deletedProducts.push(temp[0]);
    //             }
    //         }
    //     });

    //     // console.log('hiddendProducts = ', deletedProducts);
    //     for (var i = 0; i < this.SelectedProductData.length; i++) {
    //         var obj = this.SelectedProductData[i];
    //         for (var key in obj) {
    //             var value = obj[key];
    //             if (key === 'Id') {
    //                 if (this.mapIdQuantity.get(value) != undefined) {
    //                     obj.Quantity = this.mapIdQuantity.get(value);
    //                 }
    //                 if (this.mapIdSalesPrice.get(value) != undefined) {
    //                     obj.Price = this.mapIdSalesPrice.get(value);
    //                 }
    //                 if (this.mapIdDate.get(value) != undefined) {
    //                     obj.PDate = this.mapIdDate.get(value);
    //                 }
    //                 if (this.mapIdLineDescription.get(value) != undefined) {
    //                     obj.LineDescription = this.mapIdLineDescription.get(value);
    //                 }
    //                 if (this.mapIdDiscount.get(value) != undefined) {
    //                     obj.Discount = this.mapIdDiscount.get(value);
    //                 }

    //             }
    //         }
    //         this.SelectedProductData[i] = obj;
    //     }
    //     var DataToSave = this.SelectedProductData;
    //     this.SelectedProductData = [];
    //     var isValidate = true;
    //     for (var i = 0; i < DataToSave.length; i++) {
    //         if (!deletedProducts.includes(DataToSave[i]["Id"])) {
    //             this.SelectedProductData.push(DataToSave[i]);
    //         }
    //     }

    //     for (var i = 0; i < this.SelectedProductData.length; i++) {
    //         console.log(' SelectedProductData::> ' + this.SelectedProductData[i]["IsARC"]);
    //         if (this.SelectedProductData[i]["Quantity"] == 0 || this.SelectedProductData[i]["Quantity"] == undefined) {
    //             isValidate = false;
    //             break;
    //         }
    //     }

    //     if (isValidate) {
    //         this.isFirstPage = false;
    //         let str = JSON.stringify(this.SelectedProductData);
    //         saveProducts({ recordData: str, recId: this.recId, customerSAPdiscount: this.customerSAPdiscount }).then(result => {
    //             this.selectedRecord = [];


    //             this.dispatchEvent(new ShowToastEvent({
    //                 title: 'Success',
    //                 message: 'Product Added Successfully',
    //                 variant: 'success',
    //             }));
    //             this.dispatchEvent(new RefreshEvent());
    //             this.goBackToRecord();




    //         })
    //             .catch(error => {
    //                 this.dispatchEvent(
    //                     new ShowToastEvent({
    //                         title: 'Error Product Adding',
    //                         message: error.body.message,
    //                         variant: 'error',
    //                     }),
    //                 );
    //                 //this.updateRecordView();
    //                 //this.closeModal();
    //             });
    //     } else {
    //         this.dispatchEvent(new ShowToastEvent({
    //             title: 'Error',
    //             message: 'Quantity should be non-Zero',
    //             variant: 'error',
    //         }));
    //     }

    // }

    connectedCallback() {
        this.mapIdQuantity = new Map();
        this.mapIdSalesPrice = new Map();
        this.mapIdDate = new Map();
        this.mapIdDiscount = new Map();
        this.mapIdLineDescription = new Map();

        this.ShowTableData = [];
        this.selectedProductCode = [];
        this.AllProductData = [];
        this.SelectedProductData = [];

        this.isModalOpen = true;

        this.cartProducts = [];
        this.showViewCart = false;

        this.cols = this.cols.filter(col => col.fieldName !== 'ListPrice');
        this.cols = this.cols.filter(col => col.fieldName !== 'IsARC');

        this.showSpinner = true;

        console.log('connected callback called');

        // DON'T load products here - wait for user to select Item Type
        // setTimeout(() => {
        //     if (this.recId) {
        //         this.getProductList();  // REMOVE THIS
        //         this.getproductfamily();
        //     }
        //     this.showSpinner = false;
        // }, 100);

        // Only load product families, not products
        this.getproductfamily();
        this.handlerGetCustomerDiscount();
        this.showSpinner = false;
    }



    getProductList() {
        // findProducts({
        //     recordId: this.recId,
        //     productFamily: [],
        //     searchKey: this.searchKey
        // }).then(result => {
        //     // console.log('connectedCallback = ', result);
        //     let dataObj = JSON.parse(result);
        //     // console.log(dataObj);
        //     this.AllProductData = dataObj.productList;
        //     this.ShowTableData = this.AllProductData;
        //     this.paginiateData(JSON.stringify(this.AllProductData));
        //     this.page = 1;
        // });
        // this.handlerGetCustomerDiscount();

        findProducts({
            recordId: this.recId,
            productFamily: [],
            searchKey: this.searchKey,
            batchNo: 1
        }).then(result => {
            let dataObj = JSON.parse(result);
            console.log('firstHalfProductData', dataObj);
            this.firstHalfProductData = dataObj.productList;
            findProducts({
                recordId: this.recId,
                productFamily: [],
                searchKey: this.searchKey,
                batchNo: 2
            }).then(result => {
                let dataObj = JSON.parse(result);
                console.log('secondHalfProductData', dataObj);
                this.secondHalfProductData = dataObj.productList;
                findProducts({
                    recordId: this.recId,
                    productFamily: [],
                    searchKey: this.searchKey,
                    batchNo: 3
                }).then(result => {
                    let dataObj = JSON.parse(result);
                    console.log('thirdHalfProductData', dataObj);
                    this.thirdHalfProductData = dataObj.productList;
                    setTimeout(() => {
                        this.AllProductData = [...this.firstHalfProductData, ...this.secondHalfProductData, ...this.thirdHalfProductData];
                        this.ShowTableData = this.AllProductData;
                        this.paginiateData(JSON.stringify(this.AllProductData));
                        this.page = 1;
                    }, 3000);
                });
            });

        });
        this.handlerGetCustomerDiscount();
    }

    getproductfamily() {
        //this.isModalOpen = true;
        getproductfamily().then(result => {
            console.log('ProductFamily' + JSON.stringify(result));

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

    get itemDefault() {
        return '';
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

    handleItemOptions(event) {
        console.log('check item value:>>:>' + event.target.value);
        this.showSpinner = true;
        let option = event.target.value;

        if (option == '' || option == '--None--') {
            this.AllProductData = [];
            this.ShowTableData = [];
            this.showSpinner = false;
            this.searchDisabled = true;
            this.showToast('Info', 'Please select an Item Type to view products', 'info');
            return;
        }

        findProductsOptimized({
            recordId: this.recId,
            searchKey: this.searchKey,
            itemType: option
        })
            .then(chunks => {
                console.log('Received chunks:', chunks.length);

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
                        }
                        if (chunkObj.productList && Array.isArray(chunkObj.productList)) {
                            allProducts = allProducts.concat(chunkObj.productList);
                        }
                        console.log(`Chunk ${chunkObj.chunkIndex + 1}/${chunkObj.totalChunks}: ${chunkObj.productList.length} products`);
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
                console.log('Cart products preserved:', this.cartProducts.length);
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

    @track customerSAPdiscount = 0;
    handlerGetCustomerDiscount() {
        getCustomerDiscount({
            oppId: this.recId
        }).then((result) => {
            // console.log('getCustomerDiscount:>>> ', result);

            if (result != null) {
                this.customerSAPdiscount = parseFloat(result);
                if (this.customerSAPdiscount < 0) {
                    this.customerSAPdiscount = this.customerSAPdiscount * -1;
                }
            }
        })
    }


    // @wire(findProducts, { recordId: '$recId', productFamily: '$productFamily' })
    // wiredProducts({ error, data }) {

    //     // console.log('HEREEE:>> ', data);
    //     // console.log('HEREEE:>> ', error);

    //     if (data) {
    //         this.isModalOpen = true;
    //         let lstProduct = [];
    //         this.ShowTableData = [];
    //         this.selectedProductCode = [];
    //         this.AllProductData = [];
    //         this.SelectedProductData = [];
    //         data.forEach(pbe => {
    //             let pw = {
    //                 Id: pbe.Id,
    //                 purl: `/lightning/r/${pbe.Id}/view`,
    //                 Product2Id: pbe.Product2Id,
    //                 Name: pbe.Product2.Name,
    //                 ProductCode: pbe.Product2.ProductCode,
    //                 Family: pbe.Product2.Family,
    //                 Description: pbe.Product2.Description,
    //                 Price: pbe.UnitPrice,
    //                 SalesPrice: null,
    //                 index: i++,
    //                 showError: false
    //             };
    //             lstProduct.push(pw);
    //         });
    //         this.AllProductData = lstProduct;
    //         this.ShowTableData = lstProduct;
    //         // this.PriceBook = dataObj.priceBook;
    //         const endTime = performance.now(); // End time measurement
    //         this.loadTime = (endTime - this.startTime).toFixed(2); // Calculate load time
    //         console.log(`Wire method load time: ${this.loadTime} ms`);
    //     } else if (error) {
    //         console.log('HEREEE 222');
    //         this.error = error;
    //         console.error(`Error fetching products: ${error.message}`);
    //     }
    // }


    // openModal() {

    //     this.isModalOpen = true;
    //     let lstProduct = [];
    //     this.ShowTableData = [];
    //     this.selectedProductCode = [];
    //     this.AllProductData = [];
    //     this.SelectedProductData = [];
    //     findProducts({ recordId: this.recId, productFamily: [] }).then(result => {
    //         console.log(result);
    //         let i = 0;

    //         result.forEach(pbe => {
    //             let pw = {
    //                 Id: pbe.Id,
    //                 purl: `/lightning/r/${pbe.Id}/view`,
    //                 Product2Id: pbe.Product2Id,
    //                 Name: pbe.Product2.Name,
    //                 ProductCode: pbe.Product2.ProductCode,
    //                 Family: pbe.Product2.Family,
    //                 Description: pbe.Product2.Description,
    //                 Price: pbe.UnitPrice,
    //                 SalesPrice: null,
    //                 index: i++,
    //                 showError: false
    //             };
    //             lstProduct.push(pw);
    //         });
    //         this.AllProductData = lstProduct;
    //         this.ShowTableData = lstProduct;
    //        const endTime = performance.now(); // End time measurement
    //        this.loadTime = (endTime - this.startTime).toFixed(2); // Calculate load time
    //        console.log(`Wire method load time: ${this.loadTime} ms`);

    //         this.paginiateData(JSON.stringify(this.AllProductData));
    //     });
    // }

    @track startTime = performance.now();



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

        // Update selectedRows for current page display
        this.selectedRows = selRows;

        // Update DisableNext button
        this.DisableNext = this.selectedProductCode.length === 0;

        // Build SelectedProductData from all selected products across all pages
        this.SelectedProductData = [];
        for (let i = 0; i < this.selectedProductCode.length; i++) {
            // First check in current ShowTableData
            let found = false;
            for (let j = 0; j < this.ShowTableData.length; j++) {
                if (this.selectedProductCode.includes(this.ShowTableData[j].Id)) {
                    this.SelectedProductData.push(this.ShowTableData[j]);
                    found = true;
                    break;
                }
            }
            // If not in current page, check in AllProductData
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

        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/lightning/r/Opportunity/${this.recId}/view`
            }
        });

        setTimeout(() => {
            window.location.reload();
        }, 300);
    }

    closeModal() {
        this.isModalOpen = false;
        this.SelectedRecordCount = 0;
        this.PriceBook = '';
        this.ShowTableData = [];
        this.selectedProductCode = [];
        this.AllProductData = [];
        this.SelectedProductData = [];
        this.lstResult = [];
        this.hasRecords = true;
        this.searchKey = '';
        this.isSearchLoading = false;
        this.isFirstPage = true;
        this.isSecondPage = false;
        this.selectedRows = [];
        this.ShowViewAll = false;
        this.ShowSelected = true;
        this.showErrorMsg = false;
        this.filteredData = [];
        this.FilterForm = { "ProductFamily": "" };
        this.datafilterval = false;
        this.DisableNext = true;

        // Clear cart and selections
        this.cartProducts = [];
        this.showViewCart = false;
        this.allSelectedProductIds.clear();
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
        console.log('GO NEXT:>> ', this.SelectedProductData);
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
        var deletedProducts = []
        this.template.querySelectorAll('tr').forEach(ele => {
            if (ele.classList.value.includes('slds-hide') && !ele.id.includes('firstRow')) {
                var temp = ele.id.split('-');
                if (temp.length > 0) {
                    deletedProducts.push(temp[0]);
                }
            }
        });

        // Update quantities and prices from maps
        for (var i = 0; i < this.SelectedProductData.length; i++) {
            var obj = this.SelectedProductData[i];
            for (var key in obj) {
                var value = obj[key];
                if (key === 'Id') {
                    if (this.mapIdQuantity.get(value) != undefined) {
                        obj.Quantity = this.mapIdQuantity.get(value);
                    }
                    if (this.mapIdSalesPrice.get(value) != undefined) {
                        obj.Price = this.mapIdSalesPrice.get(value);
                    }
                    if (this.mapIdDate.get(value) != undefined) {
                        obj.PDate = this.mapIdDate.get(value);
                    }
                    if (this.mapIdLineDescription.get(value) != undefined) {
                        obj.LineDescription = this.mapIdLineDescription.get(value);
                    }
                    if (this.mapIdDiscount.get(value) != undefined) {
                        obj.Discount = this.mapIdDiscount.get(value);
                    }
                }
            }
            this.SelectedProductData[i] = obj;
        }

        var DataToSave = this.SelectedProductData;
        this.SelectedProductData = [];
        var isValidate = true;

        // Filter out deleted products
        for (var i = 0; i < DataToSave.length; i++) {
            if (!deletedProducts.includes(DataToSave[i]["Id"])) {
                this.SelectedProductData.push(DataToSave[i]);
            }
        }

        // Validate quantities
        for (var i = 0; i < this.SelectedProductData.length; i++) {
            console.log(' SelectedProductData::> ' + this.SelectedProductData[i]["IsARC"]);
            if (this.SelectedProductData[i]["Quantity"] == 0 || this.SelectedProductData[i]["Quantity"] == undefined) {
                isValidate = false;
                break;
            }
        }

        if (isValidate && this.SelectedProductData.length > 0) {
            // Show spinner while saving
            this.showSpinner = true;

            let str = JSON.stringify(this.SelectedProductData);
            saveProducts({ recordData: str, recId: this.recId, customerSAPdiscount: this.customerSAPdiscount })
                .then(result => {
                    this.showSpinner = false;
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Success',
                        message: 'Products Added Successfully',
                        variant: 'success',
                    }));

                    // Clear cart
                    this.cartProducts = [];
                    this.showViewCart = false;

                    // Clear all selections
                    this.allSelectedProductIds.clear();
                    this.selectedProductCode = [];

                    // Close modal and refresh the record page
                    this.isModalOpen = false;
                    this.dispatchEvent(new RefreshEvent());

                    // Navigate to record page
                    setTimeout(() => {

                        this.closeModal();

                        this[NavigationMixin.Navigate]({
                            type: 'standard__webPage',
                            attributes: {
                                url: `/lightning/r/Opportunity/${this.recId}/view`
                            }
                        });

                        setTimeout(() => {
                            window.location.reload();
                        }, 300);

                    }, 500);
                })
                .catch(error => {
                    this.showSpinner = false;
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Error Product Adding',
                        message: error.body.message,
                        variant: 'error',
                    }));
                });
        } else {
            if (this.SelectedProductData.length === 0) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: 'No products to save',
                    variant: 'error',
                }));
            } else {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: 'Quantity should be non-Zero for all products',
                    variant: 'error',
                }));
            }
        }
    }
    // handleback() {
    //     //this.ShowTableData = this.AllProductData;

    //     this.ShowSelected = true;
    //     this.isFirstPage = true;
    //     this.isSecondPage = false;
    //     mapIdQuantity = '';
    //     mapIdSalesPrice = '';
    //     mapIdDate = '';
    //     mapIdDiscount = '';
    //     mapIdLineDescription = '';

    //     this.fillselectedRows();
    //     this.RecalculateselectedProductCode();
    //     this.paginiateData(JSON.stringify(this.AllProductData));
    //     this.page = 1;

    // }

    handleSearchKeyChange(event) {
        this.searchKey = event.target.value;
        clearTimeout(this.typingTimeout);
        this.typingTimeout = setTimeout(() => {
            // Only search if products are already loaded and Item Type is selected
            if (this.AllProductData.length > 0) {
                this.handleKeyChange(event);
            }
        }, 1000);
    }

    showFilteredProducts(event) {
        if (event.keyCode == 13) {
            this.isFirstPage = false;
            this.showErrorMsg = false;
        } else {
            // Only handle key change if products are loaded
            if (this.AllProductData.length > 0) {
                this.handleKeyChange(event);
            }
            const searchBoxWrapper = this.template.querySelector('.lookupContainer');
            searchBoxWrapper.classList.add('slds-show');
            searchBoxWrapper.classList.remove('slds-hide');
        }
    }

    handleKeyChange(event) {
        this.isSearchLoading = true;
        this.searchKey = event.target.value;
        var data = [];
        for (var i = 0; i < this.AllProductData.length; i++) {
            if (this.AllProductData[i] != undefined && (this.AllProductData[i].Name.toLowerCase().includes(this.searchKey.toLowerCase()) || this.AllProductData[i].ProductCode.includes(this.searchKey))) {
                data.push(this.AllProductData[i]);
            }
        }
        this.paginiateData(JSON.stringify(data));
        this.page = 1;
        this.recordPerPage(1, this.SelectedProductData, data);

        // Cart products remain unchanged
        console.log('Cart preserved during search:', this.cartProducts.length);
        console.log('Selected product IDs preserved:', Array.from(this.allSelectedProductIds));
    }



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
            findProducts({ recordId: this.recId, productFamily: [] }).then(result => {
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
                                            if (this.filteredData[i].Name.toLowerCase().includes(this.searchKey.toLowerCase())) {
                                                console.log('inside name key',);
                                                filteredProductData.push(this.filteredData[i]);
                                                break;
                                            } else {
                                                console.log('else name key',);
                                            }
                                        } else {
                                            console.log('family name key',);
                                            //filteredProductData.push(this.filteredData[i]);
                                        }
                                    }
                                } else {
                                    if (this.filteredData[i].Name.toLowerCase().includes(this.searchKey.toLowerCase())) {
                                        filteredProductData.push(this.filteredData[i]);
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
                                if (this.filteredData[i].Name.toLowerCase().includes(this.searchKey.toLowerCase())) {
                                    filteredProductData.push(this.filteredData[i]);
                                    break;
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
                            if (this.filteredData[i].Name.toLowerCase().includes(this.searchKey.toLowerCase())) {
                                filteredProductData.push(this.filteredData[i]);
                                break;
                                //}
                                //}
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

    nextHandler() {
        if ((this.page < this.totalPage) && this.page !== this.totalPage) {
            this.page = this.page + 1;
            this.recordPerPage(this.page, this.SelectedProductData, this.paginationDataList);
        }
        // Cart remains unchanged
    }

    previousHandler() {
        if (this.page > 1) {
            this.page = this.page - 1;
            this.recordPerPage(this.page, this.SelectedProductData, this.paginationDataList);
        }
        // Cart remains unchanged
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