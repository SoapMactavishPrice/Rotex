import { LightningElement, track, api, wire } from 'lwc';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getLineItem from '@salesforce/apex/IntegrationHandler.getLineItem';
import quoteValidation from '@salesforce/apex/IntegrationHandler.quoteValidation';
import salesOrderCreation from '@salesforce/apex/IntegrationHandler.salesOrderCreation';
import updateQuotation from '@salesforce/apex/IntegrationHandler.updateQuotation';
import uploadPOAttachment from '@salesforce/apex/IntegrationHandler.uploadPOAttachment';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';

export default class SendQuoteToSAP extends LightningElement {

    @api recordId;
    @api objectApiName;
    @api salesDocNo;
    @track showSpinner = false;
    @track recTypeName = '';
    @track ResponseMessage = '';
    @track errorResponseMessage = '';
    @track syncDataResponseFlag = false;
    @track partnerfunctionOptions = [];
    @track partnerfunctionValue = '';
    @track bpOptions = [];
    @track bpValue = '';
    @track shOptions = [];
    @track shValue = '';
    @track caOptions = [];
    @track caValue = '';
    @track showPBGComments = false;
    @track showLDComments = false;
    @track salesQuotationType = 'ZQT';
    @track uploadedFiles = [];
    @track isViewFile = false;
    @track selectedFilesForPreview = [];
    @track fileInputKey = Date.now();

    showToast(toastTitle, toastMsg, toastType) {
        const event = new ShowToastEvent({
            title: toastTitle,
            message: toastMsg,
            variant: toastType,
            mode: "dismissable"
        });
        this.dispatchEvent(event);
    }

    connectedCallback() {
        this.showSpinner = true;
        setTimeout(() => {
            console.log('recordId ', this.recordId);
            console.log('objectApiName ', this.objectApiName);
            if (this.recordId) {
                this.handleQuoteCheck();
                this.handleGetLineItems();
            } else {
                this.showToast('Error', 'Invalid Record Id', 'error');
            }
        }, 2000);
    }

    handleUploadClick() {
        this.template.querySelector('.hiddenFileInput').click();
    }

    handleFileChange(event) {
        const files = event.target.files;
        if (!files || files.length === 0) return;

        const filePromises = [];

        Array.from(files).forEach(file => {
            if (file.size > 3.5 * 1024 * 1024) {
                this.showToast('Error', `${file.name} exceeds 3.5MB limit`, 'error');
                return;
            }

            filePromises.push(new Promise((resolve, reject) => {
                const reader = new FileReader();
                reader.onload = () => {
                    try {
                        let base64 = reader.result.split(',')[1];
                        if (!base64 || base64.length === 0) {
                            reject(new Error('Empty base64 data'));
                            return;
                        }
                        resolve({
                            id: Date.now() + Math.random(),
                            filename: file.name,
                            base64: base64,
                            url: reader.result,
                            type: file.type,
                            isImage: file.type.startsWith('image'),
                            isPdf: file.type === 'application/pdf'
                        });
                    } catch (error) {
                        reject(error);
                    }
                };
                reader.onerror = () => reject(new Error('File read error'));
                reader.readAsDataURL(file);
            }));
        });

        Promise.all(filePromises)
            .then(results => {
                this.uploadedFiles = [...this.uploadedFiles, ...results];
                this.showToast('Success', `${results.length} file(s) added successfully`, 'success');
                const fileInput = this.template.querySelector('.hiddenFileInput');
                if (fileInput) {
                    fileInput.value = '';
                }
                this.fileInputKey = Date.now();
            })
            .catch(error => {
                console.error('File processing error:', error);
                this.showToast('Error', error.message, 'error');
            });
    }

    viewFile() {
        if (!this.uploadedFiles || this.uploadedFiles.length === 0) {
            this.showToast('Info', 'No files uploaded to preview', 'info');
            return;
        }
        this.selectedFilesForPreview = this.uploadedFiles.map(file => ({
            id: file.id,
            filename: file.filename,
            url: file.url,
            isImage: file.isImage,
            isPdf: file.isPdf
        }));
        this.isViewFile = true;
    }

    hideModalBox() {
        this.isViewFile = false;
        this.selectedFilesForPreview = [];
    }

    removeFile(event) {
        const fileId = event.currentTarget.dataset.id;
        this.uploadedFiles = this.uploadedFiles.filter(file => file.id != fileId);
        this.showToast('Success', 'File removed successfully', 'success');

        // Update preview if modal is open
        if (this.isViewFile) {
            this.selectedFilesForPreview = this.uploadedFiles.map(file => ({
                id: file.id,
                filename: file.filename,
                url: file.url,
                isImage: file.isImage,
                isPdf: file.isPdf
            }));
        }
    }

    get noFilesToPreview() {
        return this.selectedFilesForPreview.length === 0;
    }

    get poAttachmentRequired() {
        return this.uploadedFiles.length === 0;
    }

    handleSalesQuotationTypeChange(event) {
        this.salesQuotationType = event.detail.value;
    }

    // Send Quote as SO to SAP
    handleQuoteCheck() {
        quoteValidation({
            qId: this.recordId
        }).then((result) => {
            console.log('quoteValidation result ', result);
            let data = JSON.parse(result);
            if (data.status == 'true') {
                // this.showToast('Please wait for callout response', '', 'info');
                // this.handleCallout();
            } else {
                this.closeModal();
                this.showToast(data.message, '', 'error');
                this.errorResponseMessage = data.message;
                this.showSpinner = false;
            }
            this.showSpinner = false;
        }).catch((error) => {
            console.log('= erorr quoteValidation : ', error);
            this.showSpinner = false;
        })
    }

    @track orderLineItemList = [];
    handleGetLineItems() {
        getLineItem({
            qId: this.recordId
        }).then((result) => {
            let data = JSON.parse(result);
            console.log('data:>>> ', data);
            this.orderLineItemList = data.quoteLineItemList;
            console.log('orderLineItemList ', this.orderLineItemList);

            this.bpOptions = data.bpList.map(item => {
                let fullAddress = `${item.Name} - ${item.Street__c}, ${item.City__c}, ${item.State__c}, ${item.Postal_Code__c}, ${item.Country__c} `;
                return {
                    label: fullAddress,
                    value: item.Id
                };
            });
            this.shOptions = data.shList.map(item => {
                let fullAddress = `${item.Name} - ${item.Street__c}, ${item.City__c}, ${item.State__c}, ${item.Postal_Code__c}, ${item.Country__c} `;
                return {
                    label: fullAddress,
                    value: item.Id
                };
            });
            this.caOptions = data.caList.map(item => {
                let fullAddress = `${item.Name} - ${item.Street__c}, ${item.City__c}, ${item.State__c}, ${item.Postal_Code__c}, ${item.Country__c} `;
                return {
                    label: fullAddress,
                    value: item.Id
                };
            });
        })
    }

    handlePBGChange(event) {
        this.showPBGComments =
            event.target.value === 'Yes';
    }

    handleLDChange(event) {
        this.showLDComments =
            event.target.value === 'Yes';
    }

    closeModal(event) {
        this.dispatchEvent(new CloseActionScreenEvent());
        this.dispatchEvent(new RefreshEvent());
    }

    handleInputChange(event) {
        if (event.target.name == 'bp') {
            this.bpValue = event.target.value;
        }
        if (event.target.name == 'sh') {
            this.shValue = event.target.value;
        }
        if (event.target.name == 'ca') {
            this.caValue = event.target.value;
        }
    }

    // ------------ Main Order Submit --------------------
    handleMainSubmit(event) {
        event.preventDefault();

        // Check PO Attachment first (mandatory)
        if (this.uploadedFiles.length === 0) {
            this.showToast('Validation Error', 'PO Attachment is mandatory. Please upload at least one file.', 'error');
            const uploadButton = this.template.querySelector('lightning-button[label="Upload Files"]');
            if (uploadButton) {
                uploadButton.classList.add('slds-has-error');
                setTimeout(() => {
                    uploadButton.classList.remove('slds-has-error');
                }, 2000);
            }
            return;
        }

        const mandatoryFields = ['RequestedDeliveryDate__c', 'Customer_Reference_No__c', 'Customer_Reference_Date__c', 'Sales_Quotation_Type__c'];
        const lwcInputFields = this.template.querySelectorAll('lightning-input-field');
        let validationFlag = false;

        if (lwcInputFields) {
            lwcInputFields.forEach(field => {
                if (mandatoryFields.includes(field.fieldName) && (field.value == null || field.value === '')) {
                    validationFlag = true;
                }
                field.reportValidity();
            });
            if (this.bpValue == '' || this.shValue == '' || (this.salesQuotationType == '' || this.salesQuotationType == null || this.salesQuotationType == undefined)) {
                validationFlag = true;
            }

            if (validationFlag) {
                this.showToast('Please fill/select all the mandatory fields', '', 'error');
            } else {
                // First upload all files to Salesforce
                this.uploadAllFiles();
            }
        }
    }

    async uploadAllFiles() {
        this.showSpinner = true;

        try {
            // Upload each file to Salesforce
            const uploadPromises = this.uploadedFiles.map(file => {
                return uploadPOAttachment({
                    quoteId: this.recordId,
                    fileName: file.filename,
                    base64Data: file.base64
                });
            });

            const results = await Promise.all(uploadPromises);

            // Check if all uploads were successful
            const allSuccess = results.every(result => result.success);

            if (allSuccess) {
                this.showToast('Success', 'Files uploaded successfully', 'success');
                // Now submit the form
                const form1 = this.template.querySelector('lightning-record-edit-form[data-id="mainform"]');
                form1.submit();
            } else {
                const failedUploads = results.filter(r => !r.success);
                this.showToast('Error', `Failed to upload ${failedUploads.length} file(s)`, 'error');
                this.showSpinner = false;
            }
        } catch (error) {
            console.error('Upload error:', error);
            this.showToast('Error', 'Failed to upload files', 'error');
            this.showSpinner = false;
        }
    }

    handleNewError(event) {
        // This will display the error in the lightning-messages component
        const error = event.detail;
        console.log('Error occurred: ', error);

        // Optionally show an error toast message
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'An error occurred: ' + error.detail,
                variant: 'error'
            })
        );

    }

    handleMainSuccess(event) {
        // this.showToast('Customer Details Save', '', 'success');
        this.showToast('Please wait for callout response', '', 'info');
        this.syncDataResponseFlag = true;
        // this.showSpinner = false;
        this.handleCallout();
    }

    // handleCallout() {
    //     salesOrderCreation({
    //         parentId: this.recordId,
    //         bpFuncId: this.bpValue,
    //         shFuncId: this.shValue,
    //         caFuncId: this.caValue
    //     }).then((result) => {
    //         console.log('result ', result);
    //         let data = JSON.parse(JSON.parse(result));
    //         console.log('data:>>> ', data);
    //         if (data.d) {
    //             if (data.d.SalesQuotation) {
    //                 // this.ResponseMessage = 'SAP Quotation Number: ' + data.d.SalesQuotation;
    //                 this.handlerUpdateQuotation(data.d.SalesQuotation);
    //                 // this.showToast('Quotation created in SAP succesfully!', '', 'success');
    //             }
    //         } else {
    //             this.showSpinner = false;
    //             this.errorResponseMessage = JSON.stringify(data.error.message);
    //             this.showToast('Error', 'Something went wrong!!!', 'error');
    //         }

    //     }).catch((error) => {
    //         console.log('= erorr salesOrderCreation', error);
    //         this.showToast('Error', 'Something went wrong!!!', 'error');
    //         this.errorResponseMessage = error;
    //         this.showSpinner = false;
    //     })
    // }

    handleCallout() {
        salesOrderCreation({
            parentId: this.recordId,
            bpFuncId: this.bpValue,
            shFuncId: this.shValue,
            caFuncId: this.caValue,
            salesQuotationType: this.salesQuotationType
        }).then((result) => {
            console.log('result ', result);

            // Parse only once - result is already a JSON string from Apex
            let parsedResult = JSON.parse(result);
            console.log('parsedResult: ', parsedResult);

            // Check if response is an array (your actual SAP response format)
            if (Array.isArray(parsedResult) && parsedResult.length > 0) {
                let sapResponse = parsedResult[0];

                if (sapResponse.SalesQuotationNum) {
                    // Success - got SAP quotation number
                    this.handlerUpdateQuotation(sapResponse.SalesQuotationNum);
                } else if (sapResponse.Message && sapResponse.Message.MType === 'E') {
                    // Error from SAP
                    this.showSpinner = false;
                    this.errorResponseMessage = sapResponse.Message.Message1;
                    this.showToast('Error', sapResponse.Message.Message1, 'error');
                } else {
                    // Unexpected response
                    this.showSpinner = false;
                    this.errorResponseMessage = 'Unexpected SAP response format';
                    this.showToast('Error', 'Something went wrong!!!', 'error');
                }
            }
            // Handle error response from Apex
            else if (parsedResult.error) {
                this.showSpinner = false;
                this.errorResponseMessage = parsedResult.error.message;
                this.showToast('Error', 'Something went wrong!!!', 'error');
            }
            else {
                this.showSpinner = false;
                this.errorResponseMessage = 'Invalid response from server';
                this.showToast('Error', 'Something went wrong!!!', 'error');
            }

        }).catch((error) => {
            console.log('= error salesOrderCreation', error);
            this.showToast('Error', 'Something went wrong!!!', 'error');
            this.errorResponseMessage = error;
            this.showSpinner = false;
        })
    }

    // handlerUpdateQuotation(para) {
    //     updateQuotation({
    //         qId: this.recordId,
    //         qNumber: para
    //     }).then((result) => {
    //         console.log('updateQuotation result : ', result);
    //         if (result == 'ok') {
    //             this.showToast('Quotation created in SAP succesfully!', '', 'success');
    //             this.ResponseMessage = 'SAP Quotation Number: ' + para;
    //         } else {
    //             this.showToast('Error', 'Something went wrong while updating the SAP quation number in salesforce!!!', 'error');
    //         }
    //         this.showSpinner = false;
    //     }).catch((error) => {
    //         console.log('= erorr updateQuotation : ', error);
    //         this.showToast('Error', 'Something went wrong!!!', 'error');
    //     })
    // }

    handlerUpdateQuotation(para) {
        updateQuotation({
            qId: this.recordId,
            qNumber: para
        }).then((result) => {
            console.log('updateQuotation result : ', result);
            if (result == 'ok') {
                this.showToast('Quotation created in SAP successfully!', '', 'success');
                this.ResponseMessage = 'SAP Quotation Number: ' + para;

                // Auto close after 2 seconds on success
                setTimeout(() => {
                    this.dispatchEvent(new CloseActionScreenEvent());
                    this.dispatchEvent(new RefreshEvent());
                }, 2000);
            } else {
                this.showToast('Error', 'Something went wrong while updating the SAP quotation number in Salesforce!!!', 'error');
            }
            this.showSpinner = false;
        }).catch((error) => {
            console.log('= error updateQuotation : ', error);
            this.showToast('Error', 'Something went wrong while updating SAP number!!!', 'error');
            this.showSpinner = false;
        })
    }

}