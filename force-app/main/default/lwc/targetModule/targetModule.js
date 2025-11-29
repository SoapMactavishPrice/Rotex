import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDefaultFilterValues from '@salesforce/apex/TargetModule.getDefaultFilterValues';
import getTargetQuantityByEmpId from '@salesforce/apex/TargetModule.getTargetQuantityByEmpId';
import getProductTargetQtyByProdCatVal from '@salesforce/apex/TargetModule.getProductTargetQtyByProdCatVal';

export default class TargetModule extends LightningElement {

    @track filters;
    @track employees;
    @track employes = false;
    @track prodcategory = false;

    @track EWTarget_Flag = false;
    @track EWTarget_value = 0;

    @track EWPCTarget_Flag = false;
    @track EWPCTarget_value = 0;

    @track remaining_flag = false;
    @track remaining_value = 0;

    @track compId;
    @track fiscId;
    @track empId;
    @track prodCatVal;

    @track showSpinner = true;

    @track parentTabLabel;
    @track childTabLabel;

    @track data;
    @track fiscalYearStatus;
    @track months;
    @track offset = 0;
    @track limit = 20;

    @track yearly;
    @track monthly;

    // @track isDataModified = false;

    @track employeeWise = false;
    @track employeeProductWise = false;
    @track employeeCategoryWise = false;
    @track itemGroupWise = false;


    connectedCallback() {
        this.getDefaultFilterValues();
    }



    getDefaultFilterValues() {
        new Promise((resolve, reject) => {
            setTimeout(() => {
                getDefaultFilterValues()
                    .then((data) => {
                        this.filters = JSON.parse(data);
                        //this.compId = this.filters.Company_Master__c;
                        this.fiscId = this.filters.Fiscal_Year__c;
                        console.log(this.fiscId);
                        this.userMapCompanyWise = this.filters.userMapCompanyWise;

                        resolve('Ok');
                    })
                    .catch((error) => {
                        this.dispatchEvent(new ShowToastEvent({
                            title: 'Error',
                            variant: 'error',
                            message: error.message
                        }));

                        reject('Error');
                    })
                    .finally(() => {
                        this.showSpinner = false;
                    });
            }, 0);
        });
    }


    onFilterInputChange(event) {

        console.log('88:>> ', event.target.fieldName);

        if (event.target.fieldName == 'Fiscal_Year__c') {
            this.fiscId = event.target.value;
            this.empId = null;
            this.prodCatVal = null;
            this.EWTarget_value = 0;
            this.EWPCTarget_value = 0;
            this.remaining_value = 0;
        }
        if (event.target.fieldName == 'Employee__c') {
            console.log('99:>> ', event.target.fieldName);
            this.empId = event.target.value;
            //  this.prodCatVal = null;
            this.EWTarget_value = 0
            //this.EWPCTarget_value = 0;
            this.remaining_value = 0;
            this.getEWTQuantitybyEmpId(this.empId);
        }

        if (event.target.fieldName == 'Account__c') {
            this.prodCatVal = event.target.value;
            this.EWPCTarget_value = 0;
            this.remaining_value = 0;


            if (this.empId != null && this.empId != undefined) {
                this.getEWPCTQtybyProdCatVal(this.prodCatVal, this.empId);
                this.getEWTAmountbyEmpId(this.prodCatVal, this.empId);
            }
        }
        // if (event.target.fieldName == 'Product_Category1__c') {
        //     this.prodCatVal = event.target.value;
        //     this.EWPCTarget_value = 0;
        //     this.remaining_value = 0;
        //     if (this.empId != null && this.empId != undefined) {
        //         this.getEWPCTQtybyProdCatVal(this.prodCatVal, this.empId);
        //     }
        // }

        if (event.target.value) {
            this.filters[event.target.fieldName] = event.target.value;
        }
        else {
            delete this.filters[event.target.fieldName];
        }

    }

    getEWTQuantitybyEmpId(ID) {
        new Promise((resolve, reject) => {

            getTargetQuantityByEmpId({
                empId: ID
            }).then((data) => {
                console.log('getEWTQuantitybyEmpId Data:>> ', data);
                console.log('getEWTQuantitybyEmpId Data:>> ', parseFloat(data));
                if (data == '') {
                    this.EWTarget_value = 0;
                } else {
                    this.EWTarget_value = parseFloat(data);
                }
                resolve('ok');
            }).catch((error) => {
                console.log('getEWTQuantitybyEmpId error>>>>>');
            })

        }).then(() => {

        });
    }

    getEWPCTQtybyProdCatVal(VAL, ID) {
        new Promise((resolve, reject) => {

            getProductTargetQtyByProdCatVal({
                empId: ID,
                prodCatVal: VAL
            }).then((data) => {
                console.log('getEWPCTQtybyProdCatVal Data:>> ', data);
                console.log('getEWPCTQtybyProdCatVal Data:>> ', parseFloat(data));
                if (data == '') {
                    this.EWPCTarget_value = 0;
                } else {
                    this.EWPCTarget_value = parseFloat(data);
                }
                resolve('ok');
            }).catch((error) => {
                console.log('getEWPCTQtybyProdCatVal error>>>>>');
            })

        }).then(() => {

        });
    }

    // handleEmployeeChange(event) {
    // 	console.log('handleEmployeeChange called');
    // 	this.empId = event.detail.value;
    // }


    handleparentTabChange(event) {
        this.parentTabLabel = event.currentTarget.dataset.label;
        console.log('parentTab', this.parentTabLabel);
        this.employeeWise = false;
        this.employeeProductWise = false;
        this.employeeCategoryWise = false;
        this.itemGroupWise = false;
        this.employes = false;
        this.prodcategory = false;
        this.EWTarget_Flag = false;
        this.EWPCTarget_Flag = false;
        this.remaining_flag = false;

        this.employees = null;

        this.empId = null;
        this.prodCatVal = null;
        this.EWTarget_value = 0;
        this.EWPCTarget_value = 0;
        this.remaining_value = 0;

        if (this.parentTabLabel == 'Employee_Wise_Target__c') {
            this.employeeWise = true;
            //this.employes=false;
        }
        // else if (this.parentTabLabel == 'Employee_Wise_Product_Category_Target__c') {
        //     this.employeeCategoryWise = true;
        //     this.employes = true;
        //     this.EWTarget_Flag = true;
        //     this.remaining_flag = true;
        // }
        else if (this.parentTabLabel == 'Employee_Wise_Account_Target__c') {
            this.employeeProductWise = true;
            this.employes = true;
            //  this.prodcategory = true;
            // this.EWTarget_Flag = false;
            this.EWTarget_Flag = true;
            this.remaining_flag = true;
        }
    }

    handleChildTabChange(event) {
        this.employees = null;
        if (this.parentTabLabel == 'Employee_Wise_Target__c') {
            this.empId = null;
        }

        if (this.accountEmployeeWise) {
            this.employees = this.userMapCompanyWise[this.compId];
        }

        if (event.target.value == undefined) {
            this.childTabLabel = event.currentTarget.dataset.label;
        }
        else {
            this.childTabLabel = event.currentTarget.dataset.label;
        }
    }


    handleToggleSpinner(event) {
        this.showSpinner = event.detail;
    }

    handleRemainingValueCheck(event) {
        console.log('Remaining Event Call......');
        // console.log(parseInt(event.detail.value));
        // this.remaining_value = event.detail.value;
        this.remaining_value = parseInt(event.detail.value);
    }

}