import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getYearly from '@salesforce/apex/TargetModule.getYearly';
import getMonthly from '@salesforce/apex/TargetModule.getMonthly';
import saveRecords from '@salesforce/apex/TargetModule.saveRecords';


const PAGINATION_STEP = 2;
const PREVIOUS_BUTTON = '&#9668;';
const NEXT_BUTTON = '&#9658;';
const THREE_DOTS = '...';


export default class AssignTargetEmployeeWise extends LightningElement {

    @track showSpinner;

    @track _compId;
    @track _fiscId;
    @track _empId;
    @track __prodCatVal;
    @track _parentTabLabel;
    @track _childTabLabel;
    @track _paginatorString;

    @track yearly;
    @track monthly;

    @track isDataModified;
    @track parameterLabel;


    @track pageSize;
    @track pageNumber = 1;
    @track hasRendered = false;
    @track searchThrottlingTimeout;
    @track filteredRecordHolder = [];
    @track paginationCode = [];
    @track pageSizeOptions = [10, 25, 50, 100];
    @track searchKeyword;
    @track hasDataInTable;

    @track records = [];
    @track data = [];




    @api
    set fiscId(value) {
        this._fiscId = value;

        if (this.parentTabLabel == 'Employee_Wise_Target__c') {
            console.log('getdata__from__here__111');
            if (this.fiscId) {
                this.getData();
            } else {
                this.data = null;
                this.isDataModified = false;
            }
        }
    }

    get fiscId() {
        return this._fiscId;
    }

    @api
    set empId(value) {
        this._empId = value;

        if (this.parentTabLabel == 'Employee_Wise_Account_Target__c') {
            if (this.fiscId != null && this.fiscId != undefined && this.empId != null && this.empId != undefined) {
                console.log('getdata__from__here__333');
                this.getData();
            } else {
                this.data = null;
                this.isDataModified = false;
            }
        }
    }

    get empId() {
        return this._empId;
    }

    // @api
    // set prodCatVal(value) {
    //     this._prodCatVal = value;

    //     if (this.parentTabLabel == 'Employee_Wise_Product_Target__c') {
    //         if (this.fiscId != null && this.fiscId != undefined && this.empId != null && this.empId != undefined && this.prodCatVal != null && this.prodCatVal != undefined) {
    //             console.log('getdata__from__here__444');
    //             this.getData();
    //         } else {
    //             this.data = null;
    //             this.isDataModified = false;
    //         }
    //     }
    // }

    // get prodCatVal() {
    //     return this._prodCatVal;
    // }

    @api
    set parentTabLabel(value) {
        this._parentTabLabel = value;

        switch (this.parentTabLabel) {
            case 'Employee_Wise_Target__c':
                this.parameterLabel = 'Employee Name';
                break;
            case 'Employee_Wise_Account_Target__c':
                this.parameterLabel = 'Account Name';
                break;
            // case 'Employee_Wise_Product_Category_Target__c':
            //     this.parameterLabel = 'Product Category';
            //     break;
        }

    }

    get parentTabLabel() {
        return this._parentTabLabel;
    }

    @api
    set childTabLabel(value) {
        if (this._childTabLabel != value) {
            this._childTabLabel = value;
            if (value) {
                this.yearly = false;
                this.monthly = false;
                if (value == 'Yearly') { this.yearly = true; }
                else if (value == 'Monthly') { this.monthly = true; }
                console.log('getdata__from__here__222');
                this.getData();
            }
        }

    }

    get childTabLabel() {
        return this._childTabLabel;
    }

    @api targetValFlag;
    @track newTargetValFlag;

    handleShowSpinner() {
        this.dispatchEvent(new CustomEvent("handletogglespinner", {
            detail: true
        }));
    }

    handleHideSpinner() {
        this.dispatchEvent(new CustomEvent("handletogglespinner", {
            detail: false
        }));
    }


    getData() {
        console.log('getData__Called:> ');
        console.log('getDataCHECK__HA__1:> ', this.parentTabLabel);
        console.log('getDataCHECK__HA__2:> ', this.childTabLabel);
        console.log('getDataCHECK__HA__3:> ', this.fiscId);
        console.log('getDataCHECK__HA__4:> ', this.empId);
        console.log('getDataCHECK__HA__5:> ', this.prodCatVal);
        this.yearly = false;
        this.monthly = false;
        if (this.childTabLabel == 'Yearly') {
            this.yearly = true;
            if (this.parentTabLabel == 'Employee_Wise_Target__c') {
                if (this.fiscId) {
                    this.getYearlyData();
                }
            }
            // else if (this.parentTabLabel == 'Employee_Wise_Product_Category_Target__c') {
            //     if (this.fiscId && this.empId) {
            //         this.getYearlyData();
            //     }
            // }
            else if (this.parentTabLabel == 'Employee_Wise_Account_Target__c') {
                if (this.fiscId && this.empId) {
                    this.getYearlyData();
                }
            }
        } else if (this.childTabLabel == 'Monthly') {
            // this.fiscId ='a0ZF3000007Ica8MAC'
            this.monthly = true;
            if (this.parentTabLabel != 'Employee_Wise_Account_Target__c') {

                console.log('inside 170 :> ', this.fiscId);
                if (this.fiscId) {
                    this.getMonthlyData();
                }
            }
            else if (this.parentTabLabel == 'Employee_Wise_Account_Target__c') {
                if (this.compId && this.fiscId && this.empId) {
                    this.getMonthlyData();
                }
                if (this.fiscId && this.empId) {
                    this.getMonthlyData();
                }
            }
        }
    }

    getYearlyData() {
        console.log('getYearlyData called', this.parentTabLabel);
        this.handleShowSpinner();

        this.records = [];
        this.data = [];
        this.filteredRecordHolder = [];

        new Promise((resolve, reject) => {
            setTimeout(() => {
                getYearly({
                    prodId: this.prodId,
                    fiscId: this.fiscId,
                    accId: this.accId,
                    empId: this.empId,
                    parentTab: this.parentTabLabel,
                    prodCatVal: this.prodCatVal
                })
                    .then((data) => {
                        const jsonData = JSON.parse(data);
                        console.log('getYearlyData jsonData -> ', jsonData);


                        if (jsonData.parameterData != undefined || jsonData.parameterData != null) {
                            this.records = jsonData.parameterData;

                            this.hasDataInTable = this.records.length > 0;

                            this.setDefaultView();
                        }
                        this.handleHideSpinner();
                        resolve('Ok');
                    })
                    .catch((error) => {
                        console.log('getYearlyData error ->', error);
                        this.dispatchEvent(new ShowToastEvent({ title: 'Error', variant: 'error', message: error.message }));

                        this.handleHideSpinner();
                        reject('Error');
                    })
                    .finally(result => {
                        this.handleIsDataModified();
                        this.startPagination();
                    });
            }, 0);
        });
    }

    getMonthlyData() {
        console.log('getMonthlyData called');
        // this.handleShowSpinner();

        new Promise((resolve, reject) => {
            setTimeout(() => {
                getMonthly({
                    fiscId: this.fiscId,
                    empId: this.empId,
                    accId: this.accId,
                    parentTab: this.parentTabLabel,
                    prodCatVal: this.prodCatVal
                }).then((data) => {
                    try {
                        const jsonData = JSON.parse(data);
                        console.log('json --> ', data);
                        console.log('getMonthlyData jsonData ->', jsonData);


                        if (jsonData.parameterData != undefined || jsonData.parameterData != null) {
                            this.records = jsonData.parameterData;
                            this.months = jsonData.months;

                            this.hasDataInTable = true;
                            this.setDefaultView();
                        } else {

                            this.hasDataInTable = false;

                            this.records = [];
                        }

                        this.handleHideSpinner();
                        resolve('Ok');
                    } catch (error) {
                        console.error('Error parsing JSON:', error);
                        reject('Error parsing JSON');
                    }
                })


                    /* .catch((error) => {
                       console.log('getMonthlyData error ->', error);
                       this.dispatchEvent(new ShowToastEvent({ title: 'Error', variant: 'error', message: error.message }));
           
                       this.handleHideSpinner();
                       reject('Error');
                     }) */

                    .finally(result => {
                        this.handleIsDataModified();
                        this.startPagination();
                    });
            }, 0);
        });
    }


    onDataInput(event) {
        console.log('onDataInput called');
        console.log('targetValFlag::>> ', parseFloat(this.targetValFlag));

        if (this.yearly) {
            let index = this.data.map(a => a.ParameterId).indexOf(event.currentTarget.dataset.id);

            if (event.target.value) {
                this.data[index].Target_Amount_New__c = event.target.value;
                console.log('this.data[index].Target_Amount_New__c', this.data[index].Target_Amount_New__c);
            }
            else {
                this.data[index].Target_Amount_New__c = null;
            }

            this.data[index].isDataModified = this.data[index].Target_Amount__c != this.data[index].Target_Amount_New__c ? true : false;
            this.data[index].className = this.data[index].isDataModified ? "undo" : "";

            const editItems = this.template.querySelectorAll('[data-id="' + event.currentTarget.dataset.id + '"]');
            if (editItems.length >= 1) {
                editItems[0].classList.remove('slds-has-error');
                editItems[1].innerHTML = '';
            }
        }

        else if (this.monthly) {
            let index = this.data.map(a => a.ParameterId).indexOf(event.currentTarget.dataset.id);
            let childIndex = this.data[index].childData.map(a => a.ParameterId).indexOf(event.currentTarget.dataset.childid);

            let childData = this.data[index].childData[childIndex];

            if (event.target.value) {
                childData.Monthly_Target_Amount_New__c = event.target.value;
            } else {
                childData.Monthly_Target_Amount_New__c = null;
            }

            childData.isDataModified = childData.Monthly_Target_Amount__c != childData.Monthly_Target_Amount_New__c ? true : false;
            childData.className = childData.isDataModified ? "undo" : "";

            const editItems = this.template.querySelectorAll('[data-childid="' + childData.ParameterId + '"]');
            if (editItems.length >= 1) {
                editItems[0].classList.remove('slds-has-error');
                editItems[1].innerHTML = '';
            }
        }

        this.handleIsDataModified();

    }


    handleIsDataModified() {
        console.log('handleIsDataModified called:>> ', this.records);
        this.newTargetValFlag = 0;
        this.isDataModified = false;


        if (this.records == null || this.records == undefined) {
            this.records = [];
        }


        if (this.yearly) {
            for (let i = 0; i < this.records.length; i++) {
                if (this.records[i].isDataModified) {
                    this.isDataModified = true;
                    break;
                }
            }
        } else if (this.monthly) {
            for (let i = 0; i < this.records.length; i++) {
                for (let j = 0; j < this.records[i].childData.length; j++) {
                    if (this.records[i].childData[j].isDataModified) {
                        this.isDataModified = true;
                        break;
                    }
                }
            }
        }


        const targetdatatable = this.template.querySelector('.targetdatatable');
        if (targetdatatable != null && targetdatatable != undefined) {
            if (this.isDataModified)
                targetdatatable.classList.add('slds-m-bottom_xx-large');
            else
                targetdatatable.classList.remove('slds-m-bottom_xx-large');
        }


        this.records.forEach(ele => {
            if (this.yearly) {
                // console.log('eleCHECK Yearly:>> ', ele.Target_Amount_New__c);
                if (ele.Target_Amount_New__c != null) {
                    this.newTargetValFlag = this.newTargetValFlag + parseFloat(ele.Target_Amount_New__c);
                }
            }
            if (this.monthly) {
                ele.childData.forEach(ele2 => {
                    // console.log('eleCHECK monthly:>> ', ele2.Monthly_Target_Amount_New__c);

                    if (ele2.Monthly_Target_Amount_New__c != null && ele2.Monthly_Target_Amount_New__c != 0) {
                        this.newTargetValFlag = this.newTargetValFlag + parseFloat(ele2.Monthly_Target_Amount_New__c);
                    }
                });
            }
        });


        setTimeout(() => {

            // if (this.newTargetValFlag > 0) {
            //     if (this.newTargetValFlag > parseFloat(this.targetValFlag)) {
            //         this.dispatchEvent(new ShowToastEvent({
            //             title: 'Error',
            //             variant: 'error',
            //             message: 'Assigned Qty (' + this.newTargetValFlag + ') cannot be greater than Target Qty (' + parseFloat(this.targetValFlag) + ')'
            //         }));
            //     } else {

            //         // this.validateAndSaveRecord();
            //         this.dispatchEvent(new ShowToastEvent({
            //             title: 'Error',
            //             variant: 'error',
            //             message: 'Assigned Qty cannot be zero.'
            //         }));
            //     }

            // } else {

            //     this.dispatchEvent(new ShowToastEvent({
            //         title: 'Error',
            //         variant: 'error',
            //         message: 'Assigned Qty cannot be zero.'
            //     }));
            // }

            if (this.newTargetValFlag > parseFloat(this.targetValFlag)) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    variant: 'error',
                    message: 'Assigned Qty (' + this.newTargetValFlag + ') cannot be greater than Target Qty (' + parseFloat(this.targetValFlag) + ')'
                }));
            } else {

                if (this.newTargetValFlag < 0) {

                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Error',
                        variant: 'error',
                        message: 'Assigned Qty cannot be zero.'
                    }));
                }

                // this.validateAndSaveRecord();
            }

            console.log('TESTTTTT');


            this.dispatchEvent(new CustomEvent('remainingvalue', {
                detail: {
                    value: parseFloat(this.targetValFlag) - this.newTargetValFlag
                }
            }));
        }, 100);

        console.log('403:>> ', this.newTargetValFlag);
        console.log('403:>> ', parseFloat(this.targetValFlag));

        console.log('New Target Value:', this.newTargetValFlag);
        console.log('Target Value:', parseFloat(this.targetValFlag));
    }

    validateAndSaveRecord() {

        if (this.newTargetValFlag > 0) {

            this.saveRecord();
        } else {

            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                variant: 'error',
                message: 'Amount cannot be zero. Data not saved.'
            }));
        }
    }


    handleReset() {
        console.log('handleReset called');
        this.isDataModified = false;
        if (this.yearly) {
            this.records.forEach(item => {
                item.Target_Amount_New__c = item.Target_Amount__c;
                item.isDataModified = false;
                item.className = item.isDataModified ? "undo" : "";

                const id = item.ParameterId;
                const editItems = this.template.querySelectorAll('[data-id="' + id + '"]');
                if (editItems.length >= 1) {
                    // editItems[0].classList.remove('undo');
                    editItems[0].classList.remove('slds-has-error');
                    editItems[1].innerHTML = '';
                }
            });
        }
        else if (this.monthly) {
            this.records.forEach(item => {
                item.childData.forEach(monthItem => {
                    monthItem.Monthly_Target_Amount_New__c = monthItem.Monthly_Target_Amount__c;
                    monthItem.isDataModified = false;
                    monthItem.className = monthItem.isDataModified ? "undo" : "";

                    const id = monthItem.ParameterId;
                    const editItems = this.template.querySelectorAll('[data-childid="' + id + '"]');
                    if (editItems.length >= 1) {
                        // editItems[0].classList.remove('undo');
                        editItems[0].classList.remove('slds-has-error');
                        editItems[1].innerHTML = '';
                    }
                });
            });
        }

        this.isDataModified = false;
    }


    handleSave() {
        console.log('handleSave called');
        this.handleShowSpinner();

        console.log(parseFloat(this.targetValFlag));
        console.log(this.newTargetValFlag);

        if (this.newTargetValFlag > parseFloat(this.targetValFlag)) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                variant: 'error',
                message: 'Assigned Amount (' + this.newTargetValFlag + ') cannot be greater then Target Amount (' + parseFloat(this.targetValFlag) + ')'
            }));
        } else {

            let finalData = [];

            if (this.yearly) {
                this.data.forEach(item => {
                    if (item.isDataModified) {
                        finalData.push(item);
                    }
                });
            }
            else if (this.monthly) {
                this.data.forEach(item => {
                    item.childData.forEach(childItem => {
                        if (childItem.isDataModified)
                            finalData.push(childItem);
                    });
                });
            }

            console.log('in__save__finalData :> ', finalData);

            let finalResult = '';

            new Promise((resolve, reject) => {
                setTimeout(() => {
                    saveRecords({
                        data: JSON.stringify(finalData),
                        //companyMasterId: this.compId,
                        fiscalYearId: this.fiscId,
                        employeeId: this.empId,
                        type: this.parentTabLabel,
                        subType: this.childTabLabel
                    })
                        .then((data) => {
                            let result = JSON.parse(data);
                            finalResult = result.status;
                            if (result.status == 'Success') {
                                this.dispatchEvent(new ShowToastEvent({
                                    title: result.status,
                                    variant: 'success',
                                    message: 'Target Amount is updated for given Entities'
                                }));

                                // eval("$A.get('e.force:refreshView').fire();");

                                result.errorList.forEach(item => {
                                    const editItems = this.template.querySelectorAll('[data-id="' + item.ParameterId + '"]');
                                    if (editItems.length >= 3) {
                                        editItems[1].classList.remove('slds-has-error');
                                        editItems[2].innerHTML = '';
                                        editItems[2].title = '';
                                    }
                                });

                                setTimeout(() => {
                                    this.getData();
                                }, 500);

                            }
                            else if (result.status == 'Error') {
                                this.dispatchEvent(new ShowToastEvent({
                                    title: result.status,
                                    variant: 'error',
                                    message: result.message
                                }));
                                this.handleHideSpinner();
                            }
                            else if (result.status == 'PartialError') {
                                result.errorList.forEach(item => {
                                    if (this.yearly) {
                                        const editItems = this.template.querySelectorAll('[data-id="' + item.ParameterId + '"]');
                                        if (editItems.length >= 2) {
                                            editItems[0].classList.add('slds-has-error');
                                            editItems[1].innerHTML = item.message;
                                            editItems[1].title = item.message;
                                        }
                                    }
                                    else if (this.monthly) {
                                        const editItems = this.template.querySelectorAll('[data-childid="' + item.ParameterId + '"]');
                                        if (editItems.length >= 2) {
                                            editItems[0].classList.add('slds-has-error');
                                            editItems[1].innerHTML = item.message;
                                            editItems[1].title = item.message;
                                        }
                                    }
                                });
                                this.handleHideSpinner();
                            }

                            resolve('Ok');
                        })
                        .catch((error) => {
                            console.log('error', error);
                            this.dispatchEvent(new ShowToastEvent({
                                title: 'Error',
                                variant: 'error',
                                message: error.message
                            }));

                            reject('Error');
                        });
                }, 0);
            });
        }


    }





    /* ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ Table Paginations ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ */

    setDefaultView() {
        this.filteredRecordHolder = this.records;

        this.pageSize = this.getSelectedPaging();
        this.data = [];
        if (this.pageSize < this.filteredRecordCount) {
            for (let i = 0; i < this.pageSize; i++) {
                this.data.push(this.filteredRecordHolder[i]);
            }
        }
        else {
            this.data = this.filteredRecordHolder;
        }

        console.log('CHECK::>> ', this.data);
    }

    setRecordsToDisplay() {
        let pageSize = this.getSelectedPaging();
        let lastPosition = (pageSize * this.pageNumber);
        let firstPosition = (lastPosition - pageSize);
        // this.data = Object.assign([], ((this.showPageEntries || this.showPagination) ? records.slice(firstPosition, lastPosition) : this.filteredRecordHolder));

        // if (this.filteredRecordHolder == undefined || this.filteredRecordHolder == null || this.filteredRecordHolder.length == 0) {
        // this.filteredRecordHolder = this.records;
        // }
        this.data = [];
        let finalLastPosition = lastPosition < this.filteredRecordCount ? lastPosition : this.filteredRecordCount;

        for (let i = firstPosition; i < finalLastPosition; i++) {
            this.data.push(this.filteredRecordHolder[i]);
        }

        this.data.forEach(item => {
            item.className = item.isDataModified ? "undo" : "";
        });
    }

    /* ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ Table Paginations ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ */

    paginationAdd(start, end) {
        for (let index = start; index < end; index++) {
            this.paginationCode.push(index);
        }
    }
    paginationFirst() {  // Add First Page With Separator
        this.paginationCode = [...this.paginationCode, 1, THREE_DOTS];
    }
    paginationLast() { // Add Last Page With Separator
        this.paginationCode = [...this.paginationCode, THREE_DOTS, this.getCountOfTotalPages()];
    }

    previousPage() {
        if (!this.hasDataInTable) {
            return;
        }
        this.pageNumber--;
        if (this.pageNumber < 1) {
            this.pageNumber = 1;
        }
        this.setDataAccordingToPagination();
    }

    nextPage() {
        if (!this.hasDataInTable) {
            return;
        }
        this.pageNumber++;
        if (this.pageNumber > this.getCountOfTotalPages()) {
            this.pageNumber = this.getCountOfTotalPages();
        }
        this.setDataAccordingToPagination();
    }

    paginationWithPageNumber(event) {
        let selectedPageNumber = event.currentTarget.dataset.pageNumber;
        if (selectedPageNumber == THREE_DOTS) {
            return;
        }
        this.pageNumber = parseInt(selectedPageNumber);
        this.setDataAccordingToPagination();
    }

    setDataAccordingToPagination() {
        this.setRecordsToDisplay();
        this.startPagination();
    }

    getCountOfTotalPages() {
        return Math.ceil(((this.filteredRecordCount ? this.filteredRecordCount : (this.hasDataInTable ? this.totalNumberOfRows : 0)) / this.getSelectedPaging()));
    }


    paginationCreateOnDOM() {
        console.log('paginationCreateOnDOM called');
        let data = [PREVIOUS_BUTTON, ...this.paginationCode, NEXT_BUTTON];
        this.paginationCode = [];

        let paginationContainer = this.template.querySelector('[data-pagination]');
        paginationContainer.innerHTML = '';

        data.forEach(item => {
            let element = document.createElement("div");
            element.innerHTML = item;
            element.dataset.pageNumber = item;
            if (item == this.pageNumber) {
                element.classList.add('active-button');
            }
            if (item == PREVIOUS_BUTTON) {
                element.addEventListener("click", this.previousPage.bind(this));
            } else if (item == NEXT_BUTTON) {
                element.addEventListener("click", this.nextPage.bind(this));
            } else if (item == THREE_DOTS) {
                element.classList.add('more-button');
            } else {
                element.addEventListener("click", this.paginationWithPageNumber.bind(this));
            }
            paginationContainer.appendChild(element);
        });
    }


    startPagination() {
        let totalPages = this.getCountOfTotalPages();
        if (totalPages < PAGINATION_STEP * 2 + 6) {
            this.paginationAdd(1, totalPages + 1);
        } else if (this.pageNumber < PAGINATION_STEP * 2 + 1) {
            this.paginationAdd(1, PAGINATION_STEP * 2 + 4);
            this.paginationLast();
        } else if (this.pageNumber > totalPages - PAGINATION_STEP * 2) {
            this.paginationFirst();
            this.paginationAdd(totalPages - PAGINATION_STEP * 2 - 2, totalPages + 1);
        } else {
            this.paginationFirst();
            this.paginationAdd(this.pageNumber - PAGINATION_STEP, this.pageNumber + PAGINATION_STEP + 1);
            this.paginationLast();
        }
        this.paginationCreateOnDOM();
    }

    /* ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ Table Page Entries ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ */

    handlePageEntries(event) {
        this.pageNumber = 1;
        this.setDataAccordingToPagination();
    }

    /* ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ Table Filter Functions ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ */

    dataFilter(fieldName, searchTerm) {
        let filteredItems = [];
        this.pageNumber = 1;
        if (fieldName == 'all') {
            filteredItems = this.records.filter(o => Object.keys(o).some(k => o[k].toLowerCase().includes(searchTerm)));
        } else {
            filteredItems = this.records.filter(result => result[fieldName].toLowerCase().includes(searchTerm));
        }
        this.filteredRecordHolder = filteredItems;
        // let filteredRecords = Object.assign([], filteredItems);
        // this.data = Object.assign([], ((this.showPageEntries || this.showPagination) ? filteredRecords.slice(0, this.getSelectedPaging()) : filteredRecords));
        this.setDataAccordingToPagination();
    }

    handleSearching(event) {
        let searchTerm = event.target.value;
        // Apply search throttling (prevents search if user is still typing)
        /*
        if (this.searchThrottlingTimeout) {
          window.clearTimeout(this.searchThrottlingTimeout);
        }
        */

        // this.searchThrottlingTimeout = window.setTimeout(() => {
        searchTerm = searchTerm.trim().replace(/\*/g, '').toLowerCase();
        if (searchTerm == '' || searchTerm == null || searchTerm == undefined) {
            this.filteredRecordHolder = this.records;
            this.setDataAccordingToPagination();
        }
        else {
            this.pageNumber = 1;
            if (searchTerm.length) {
                this.dataFilter(this.getSearchTerm(), searchTerm);
            }
            else {
                this.filteredRecordHolder = [];
                this.setDataAccordingToPagination();
            }
        }
        this.searchThrottlingTimeout = null;
        // }, SEARCH_DELAY);
    }


    /* ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ Table Sort Functions ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ */
    /*
      handleColumnSorting(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;
        this.sortData(this.sortedBy, this.sortedDirection);
      }
    
      sortData(fieldName, direction) {
        let result = Object.assign([], this.data);
        this.data = result.sort((a, b) => {
          if (a[fieldName] < b[fieldName])
            return direction === 'asc' ? -1 : 1;
          else if (a[fieldName] > b[fieldName])
            return direction === 'asc' ? 1 : -1;
          else
            return 0;
        })
      }
    */


    /* ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ Common use Getter ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ */
    getSearchTerm() {
        return 'ParameterName';
        // let input = this.template.querySelector('[data-search-input]');
        // return input ? input.value.trim().replace(/\*/g, '').toLowerCase() : '';
    }

    getSelectedPaging() {
        let input = this.template.querySelector('[data-show-entries-input]');
        return input ? parseInt(input.value) : 10;
    }


    /* ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ Getter ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ */

    get hasRecords() {
        return (this.dataCollection.length ? true : false);
    }

    get filteredRecordCount() {
        return this.filteredRecordHolder.length;
    }

    get pageLengthDefaultValue() {
        return (this.pageSizeOptions.length ? this.pageSizeOptions[0].toString() : '10');
    }

    get totalNumberOfRows() {
        return (this.dataCollection ? this.dataCollection.length : 0);
    }

    get showingEntriesMessage() {
        let message = '', pages = 0, lastRecordNumber = 0, start = 0, end = 0, pageEntries = this.getSelectedPaging();
        if (this.getSearchTerm().length) {
            pages = (this.filteredRecordCount / pageEntries);
            lastRecordNumber = (this.pageNumber * pageEntries);
            end = (this.filteredRecordCount >= lastRecordNumber) ? lastRecordNumber : this.filteredRecordCount;
            start = ((pages > 1) ? ((this.filteredRecordCount == end) ? this.filteredRecordCount : ((end - pageEntries) + 1)) : (this.hasDataInTable ? 1 : 0));
            message = `Showing ${start} to ${end} of ${this.filteredRecordCount} entries (filtered from ${this.totalNumberOfRows} total entries)`;
        } else {
            pages = (this.totalNumberOfRows / pageEntries);
            lastRecordNumber = (this.pageNumber * pageEntries);
            end = ((this.totalNumberOfRows >= lastRecordNumber) ? lastRecordNumber : this.totalNumberOfRows);
            start = ((pages > 1) ? ((this.totalNumberOfRows == end) ? this.totalNumberOfRows : ((end - pageEntries) + 1)) : (this.hasDataInTable ? 1 : 0));
            message = `Showing ${start} to ${end} of ${this.totalNumberOfRows} entries`;
        }
        return message;
    }

    get pageLengthOptions() {
        return this.pageSizeOptions.map(x => {
            return { label: x.toString(), value: x.toString() };
        });
    }



}