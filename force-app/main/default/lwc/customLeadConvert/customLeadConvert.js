import { LightningElement, track, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLeadRecord from '@salesforce/apex/CustomLeadConvertController.getLeadRecord';
import FORM_FACTOR from '@salesforce/client/formFactor';

export default class CustomLeadConvert extends LightningElement {

    @track showSpinner;
    @api recordId;
    @track modalHeader;
    @track modalBody;
    @track modalFooter;

    @track isMobile;
    @track isTablet;
    @track isDesktop;
    @track isNewAccountFlag = false;
    @track isExistingAccountFlag = false;
    @track is_Account_OR = false;
    @track isNewContactFlag = false;
    @track isExistingContactFlag = false;
    @track is_Contact_OR = false;
    @track isNewEnquiryFlag = false;
    @track isExistingEnquiryFlag = false;
    @track is_Enquiry_OR = false;
    @track isCreateEnquiryChecked = false;

    @track leadRecord;
    @track leadName;
    @track accRecordTypes;

    @track modalHeader;

    /* Required, disabled handlers starts here */
    @track AccountCreateNew = true;
    @track AccountCreateNewName;
    @track AccountCreateNewRT;
    @track AccountExisting;
    // @track AccountExistingShowError = false;

    @track ContactCreateNew = true;
    @track ContactName;
    @track ContactExisting;
    @track contactExistingFilter = '';
    // @track ContactExistingShowError = false;

    @track OpportunityCreateNew = true;
    @track OpportunityCreateNewName = true;
    @track OpportunityExisting;
    // @track OpportunityExistingShowError = false;
    /* Required, disabled handlers ends here */

    /* Variables to store values starts here */
    @track accountName;
    @track accountRecordType;
    @track selectedAccountId;
    @track refreshSelectedAccountId = false;

    @track isDirectCustomerChecked = false;
    @track dealerValue = '';

    @track contactSalutation;
    @track contactFirstName;
    @track contactMiddleName;
    @track contactLastName;
    @track selectedContactId;
    @track refreshSelectedContactId = false;

    @track opportunityName;
    @track selectedOpportunityId;
    @track refreshSelectedOpportunityId = false;
    @track recordTypeOptions = [];
    @track selectedRecordTypeId;



    salutationOptions = [
        { label: 'Mr.', value: 'Mr.' },
        { label: 'Ms.', value: 'Ms.' },
        { label: 'Mrs.', value: 'Mrs.' },
        { label: 'Dr.', value: 'Dr.' },
        { label: 'Prof.', value: 'Prof.' }
    ];

    fieldList = ['salutation', 'firstName', 'middleName', 'lastName'];



    connectedCallback() {
        if (this.isMobile != (FORM_FACTOR == "Small")) {
            this.isMobile = FORM_FACTOR === "Small";
        }
        if (this.isTablet != (FORM_FACTOR == "Medium")) {
            this.isTablet = FORM_FACTOR === "Medium";
        }
        if (this.isDesktop != (FORM_FACTOR == "Large")) {
            this.isDesktop = FORM_FACTOR === "Large";
        }
        console.log('isMobile =>> ', this.isMobile);
        console.log('isTablet =>> ', this.isTablet);
        console.log('isDesktop =>> ', this.isDesktop);

        if (this.isDesktop) {
            this.isNewAccountFlag = true;
            this.isExistingAccountFlag = true;
            this.is_Account_OR = true;
            this.isNewContactFlag = true;
            this.isExistingContactFlag = true;
            this.is_Contact_OR = true;
            this.isNewEnquiryFlag = true;
            this.isExistingEnquiryFlag = true;
            this.is_Enquiry_OR = true;
        } else if (this.isMobile) {
            this.isNewAccountFlag = true;
            this.isExistingAccountFlag = false;
            this.is_Account_OR = false;
            this.isNewContactFlag = true;
            this.isExistingContactFlag = false;
            this.is_Contact_OR = false;
            this.isNewEnquiryFlag = true;
            this.isExistingEnquiryFlag = false;
            this.is_Enquiry_OR = false;
        }

        this.getLeadRecord();
        this.decideRequiredOrNot(null);
    }

    closeComponent(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Lead',
                actionName: 'view',

            }
        });
    }

    showToastOnSuccess(title, msg) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: msg,
                variant: 'success'
            })
        );
    }

    showToastOnWarning(title, msg) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: msg,
                variant: 'warn'
            })
        );
    }

    showToastOnError(error) {
        console.warn(error);

        let msg;
        if (error.message) msg = error.message;
        else if (error.body.message) msg = error.body.message;

        this.dispatchEvent(
            new ShowToastEvent({
                // title: 'Error',
                message: msg,
                variant: 'error'
            })
        );

        this.showSpinner = false;
    }

    showToastOnErrorNormal(msg) {
        this.dispatchEvent(
            new ShowToastEvent({
                // title: 'Error',
                message: msg,
                variant: 'error'
            })
        );
        this.showSpinner = false;
    }

    // ================================================================ //

    getLeadRecord() {
        new Promise((resolve, reject) => {
            setTimeout(() => {
                getLeadRecord({ recordId: this.recordId })
                    .then((data) => {
                        console.log('data =>> ', data);
                        let isError = false;
                        if (isError) {
                            this.closeComponent();
                            return;
                        }

                        this.leadRecord = data;
                        this.accountName = this.leadRecord.Name;
                        this.contactSalutation = this.leadRecord.Salutation__c;
                        this.contactFirstName = this.leadRecord.FirstName;
                        this.contactMiddleName = this.leadRecord.Middle_Name__c;
                        this.contactLastName = this.leadRecord.LastName;
                        this.opportunityName = this.leadRecord.Name;
                        this.modalHeader =
                            'Convert ' +
                            //this.leadRecord.First_Name__c +
                            //' ' +
                            this.leadRecord.Name;
                    }).catch((error) => {
                        this.showToastOnError(error);
                    });
            }, 0);
        });
    }

    decideRequiredOrNot(event) {

        // if (event == null || event.target.value == 'AccountCreateNew') {

        //     if (this.isMobile) {
        //         this.isNewAccountFlag = true;
        //         this.isExistingAccountFlag = false;
        //     }

        //     // for Account
        //     this.AccountCreateNew = true;
        //     this.AccountExisting = false;

        //     // for Contact
        //     const radios = this.template.querySelectorAll('.contact-radio');
        //     if (radios.length == 2) {
        //         radios[0].checked = true;
        //         radios[1].checked = false;
        //     }
        //     this.ContactCreateNew = true;
        //     this.ContactExisting = false;
        //     this.ContactName = true;
        //     this.ContactExistingShowError = false;

        //     // for validations (required)
        //     this.AccountCreateNewName = true;
        //     this.AccountCreateNewRT = true;

        //     this.AccountExistingName = false;
        //     this.AccountExistingShowError = false;
        // } else
        if (event == null || event.target.value == 'AccountExisting') {

            if (this.isMobile) {
                this.isNewAccountFlag = false;
                this.isExistingAccountFlag = true;
            }

            // for Account
            this.AccountCreateNew = false;
            this.AccountExisting = true;

            // remove validation from create new
            // const accountFields = this.template.querySelectorAll('.account-fields');
            // for (let i = 0; i < accountFields.length; i++) {
            //     accountFields[i].setCustomValidity(' ');
            //     accountFields[i].reportValidity();
            //     console.log(accountFields[i].className);
            //     accountFields[i].className = accountFields[i].className.replace('slds-has-error', '');
            // }

            this.ContactCreateNew = true;
            this.ContactExisting = false;
            this.ContactName = true;
            // this.ContactExistingShowError = false;

            // for validations (required)
            this.AccountCreateNewName = false;
            this.AccountCreateNewRT = false;

            this.AccountExistingName = true;
            // this.AccountExistingShowError = false;
        } else if (event.target.value == 'ContactCreateNew') {

            if (this.isMobile) {
                this.isNewContactFlag = true;
                this.isExistingContactFlag = false;
            }

            // for Contact
            this.ContactCreateNew = true;
            this.ContactExisting = false;

            // for validations (required)
            this.ContactName = true;
            // this.ContactExistingShowError = false;
        } else if (event.target.value == 'ContactExisting') {

            if (this.isMobile) {
                this.isNewContactFlag = false;
                this.isExistingContactFlag = true;
            }

            // for Contact
            this.ContactCreateNew = false;
            this.ContactExisting = true;

            // for validations (required)
            this.ContactName = false;
            // this.ContactExistingShowError = false;
        } else if (event.target.value == 'OpportunityCreateNew') {

            if (this.isMobile) {
                this.isNewEnquiryFlag = true;
                this.isExistingEnquiryFlag = false;
            }

            // for Opportunity
            this.OpportunityCreateNew = true;
            this.OpportunityExisting = false;

            // for validations (required)
            this.OpportunityCreateNewName = true;
        } else if (event.target.value == 'OpportunityExisting') {

            if (this.isMobile) {
                this.isNewEnquiryFlag = false;
                this.isExistingEnquiryFlag = true;
            }

            // for Opportunity
            this.OpportunityCreateNew = false;
            this.OpportunityExisting = true;

            // for validations (required)
            this.OpportunityCreateNewName = false;
        }

        if (event) this.reportValidity();
    }

    reportValidity() {

        if (this.AccountCreateNew) {
            if (this.refs.accountNameRef || this.refs.accountRTRef) {
                const element = this.template.querySelector('#acc-create-new');
                if (element) {
                    element.setCustomValidity('');
                    element.reportValidity();
                } else {
                    console.error('Element not found');
                }
                // this.refs.accountNameRef.setCustomValidity('');
                // console.log('this.refs.accountNameRef customvalidity if',this.refs.accountNameRef);
                // this.refs.accountNameRef.reportValidity();
                // console.log('this.refs.accountNameRef Reportvalidity if',this.refs.accountNameRef);
                // this.refs.accountRTRef.setCustomValidity('');
                // console.log('this.refs.accountRTRef customvalidity if',this.refs.accountRTRef);
                // this.refs.accountRTRef.reportValidity();
                // console.log('this.refs.accountRTRef Reportvalidity if',this.refs.accountRTRef);
            }
        } else {
            if (this.refs.accountNameRef || this.refs.accountRTRef) {
                console.log('11');
                const element = this.template.querySelector('#acc-create-new');
                if (element) {
                    element.setCustomValidity('');
                    element.reportValidity();
                    element.classList.remove('slds-has-error');
                } else {
                    console.error('Element not found');
                }
                // this.refs.accountNameRef.setCustomValidity('');
                // console.log('this.refs.accountNameRef customvalidity', this.refs.accountNameRef);
                // this.refs.accountNameRef.reportValidity();
                // console.log('this.refs.accountNameRef Reportvalidity', this.refs.accountNameRef);
                // this.accountRTRef.setCustomValidity('');
                // console.log('this.refs.accountRTRef customvalidity', this.accountRTRef);
                // this.accountRTRef.reportValidity();
                // console.log('this.refs.accountRTRef Reportvalidity', this.accountRTRef);
                // this.accountNameRef.classList.remove('slds-has-error');
                // this.accountRTRef.classList.remove('slds-has-error');

                console.log('13');
            }

        }

        /*
        if (this.ContactCreateNew) {
                this.refs.contactNameRef.setCustomValidityForField('', 'lastName');
                this.refs.contactNameRef.reportValidity();
        } else {
                this.refs.contactNameRef.setCustomValidityForField(' ', 'lastName');
                this.refs.contactNameRef.reportValidity();
                const lastName = this.refs.contactNameRef.querySelector('.slds-has-error');
                if (lastName)
                        lastName.classList.remove('slds-has-error');
        }
        */

        if (this.OpportunityCreateNew) {
            // this.refs.opportunityNameRef.setCustomValidity('');
            // this.refs.opportunityNameRef.reportValidity();
            const element = this.template.querySelector('#opp-create-new');
            if (element) {
                element.setCustomValidity('');
                element.reportValidity();
            } else {
                console.error('Element not found');
            }
        } else {
            console.log('23');
            // this.refs.opportunityNameRef.setCustomValidity(' ');
            // this.refs.opportunityNameRef.reportValidity();
            const element = this.template.querySelector('#opp-create-new');
            if (element) {
                element.setCustomValidity('');
                element.reportValidity();
                element.classList.remove('slds-has-error');
            } else {
                console.error('Element not found');
            }
            // this.refs.opportunityNameRef.classList.remove('slds-has-error');

        }
    }

    handleExistingAccountSelect(event) {
        if (event.detail.selectedRecordId) {
            this.selectedAccountId = event.detail.selectedRecordId;
            // this.AccountExistingShowError = false;

            this.contactExistingFilter =
                "AccountId = '" + this.selectedAccountId + "'";
        } else {
            this.selectedAccountId = null;
            this.contactExistingFilter = '';
        }
        this.refreshSelectedContactId = !this.refreshSelectedContactId;
    }

    handleExistingContactSelect(event) {
        if (event.detail.selectedRecordId) {
            this.selectedContactId = event.detail.selectedRecordId;
            // this.ContactExistingShowError = false;
        } else {
            this.selectedContactId = null;
        }
    }

    handleExistingOpportunitySelect(event) {
        if (event.detail.selectedRecordId) {
            this.selectedOpportunityId = event.detail.selectedRecordId;
        } else {
            this.selectedOpportunityId = null;
        }
    }

    handleValueChange(event) {
        if (event.target.name != 'ContactName') {
            // event.target.setCustomValidity("");
            // event.target.reportValidity();
        }

        if (event.target.name == 'ContactName') {
            this.contactSalutation = event.target.salutation;
            this.contactFirstName = event.target.firstName;
            this.contactMiddleName = event.target.middleName;
            this.contactLastName = event.target.lastName;
        } else if (event.target.name == 'PageSize') {
            this.pageSize = parseInt(event.target.value);
            console.log('pageSize', this.pageSize);
            this.paginationHelper();
        } else if (event.target.name == 'Search') {
            this.searchKeyword = event.target.value;

            clearTimeout(this.timeoutInstance);
            this.timeoutInstance = setTimeout(() => {
                if (
                    this.searchKeyword == null ||
                    this.searchKeyword == undefined ||
                    this.searchKeyword == ''
                )
                    this.searchKeyword = '';
                this.filterRecords();
            }, 500);
        } else if (event.target.name == 'PinCode') {
            if (event.target.checkValidity()) {
                this.pinCode = event.target.value;

                clearTimeout(this.timeoutInstance);
                this.timeoutInstance = setTimeout(() => {
                    this.getAccountRecords();
                }, 500);
            } else {
                clearTimeout(this.timeoutInstance);
            }
        } else {
            this[event.target.name] = event.target.value;
            console.log('accountRecordType', this.accountRecordType);
        }
    }

    async handleConfirmClick() {
        if (this.submitValidation()) {
            // this.showSpinner = true;
            // new Promise((resolve, reject) => {
            //     convertLead({
            //         leadRecord: this.leadRecord,
            //         accName: this.accountName,
            //         existingAccId: this.selectedAccountId,
            //         contactName: {
            //             Salutation: this.contactSalutation,
            //             FirstName: this.contactFirstName,
            //             MiddleName: this.contactMiddleName,
            //             LastName: this.contactLastName
            //         },
            //         existingContId: this.selectedContactId,
            //         enqName: this.opportunityName,
            //         isContactNew: this.ContactCreateNew
            //     }).then((data) => {
            //         this.showSpinner = false;
            //         this[NavigationMixin.Navigate]({
            //             type: 'standard__recordPage',
            //             attributes: {
            //                 recordId: data.accountId,
            //                 objectApiName: 'Account',
            //                 actionName: 'view'
            //             }
            //         });
            //     }).catch((error) => {
            //         this.showSpinner = false;
            //         this.showToastOnError(error);
            //     });
            // })
        }
    }

    submitValidation() {
        console.log('leadRecord:>>> ', this.leadRecord);
        console.log('accountName:>>> ', this.accountName);
        console.log('selectedAccountId:>>> ', this.selectedAccountId);
        console.log('contactSalutation:>>> ', this.contactSalutation);
        console.log('contactFirstName:>>> ', this.contactFirstName);
        console.log('contactMiddleName:>>> ', this.contactMiddleName);
        console.log('contactLastName:>>> ', this.contactLastName);
        console.log('selectedContactId:>>> ', this.selectedContactId);
        console.log('opportunityName:>>> ', this.opportunityName);
        console.log('ContactCreateNew:>>> ', this.ContactCreateNew);

        if (this.selectedAccountId == null || this.selectedAccountId == '' || this.selectedAccountId == undefined) {
            this.showToastOnErrorNormal('Please select an existing Account');
            return;
        }

        if (!this.ContactExisting) {
            if (this.contactSalutation == null || this.contactSalutation == '' || this.contactSalutation == undefined) {
                this.showToastOnErrorNormal('Please enter Contact Salutation');
                return;
            }
            if (this.contactFirstName == null || this.contactFirstName == '' || this.contactFirstName == undefined) {
                this.showToastOnErrorNormal('Please enter Contact First Name');
                return;
            }
            if (this.contactLastName == null || this.contactLastName == '' || this.contactLastName == undefined) {
                this.showToastOnErrorNormal('Please enter Contact Last Name');
                return;
            }

        } else {
            if (this.selectedContactId == null || this.selectedContactId == '' || this.selectedContactId == undefined) {
                this.showToastOnErrorNormal('Please select an existing Contact');
                return;
            }
        }

        if (this.opportunityName == null || this.opportunityName == '' || this.opportunityName == undefined) {
            this.showToastOnErrorNormal('Please enter Opportunity Name');
            return;
        }

    }

}