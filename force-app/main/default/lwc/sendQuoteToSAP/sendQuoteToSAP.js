import { LightningElement, track, api, wire } from 'lwc';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getLineItem from '@salesforce/apex/IntegrationHandler.getLineItem';
import quoteValidation from '@salesforce/apex/IntegrationHandler.quoteValidation';
import salesOrderCreation from '@salesforce/apex/IntegrationHandler.salesOrderCreation';
import updateQuotation from '@salesforce/apex/IntegrationHandler.updateQuotation';
import uploadPOAttachment from '@salesforce/apex/IntegrationHandler.uploadPOAttachment';
import updateRoundOffValues from '@salesforce/apex/IntegrationHandler.updateRoundOffValues';
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
    @track newlyUploadedFiles = [];
    @track uploadedFileNames = [];
    @track newlyUploadedFiles = [];
    @track uploadedFileNames = [];

    showToast(toastTitle, toastMsg, toastType) {
        const event = new ShowToastEvent({
            title: toastTitle,
            message: toastMsg,
            variant: toastType,
            mode: "dismissable"
        });
        this.dispatchEvent(event);
    }

    // Add this method to get current session files
    getCurrentSessionFiles() {
        return this.newlyUploadedFiles.map(file => file.filename);
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

    handleRoundOffChange(event) {
        const index = event.target.dataset.index;
        let value = event.target.value;

        if (value === '' || value === null || value === undefined) {
            this.orderLineItemList[index].Round_Off__c = null;
            return;
        }

        // Allow temporary values like "0.", "-0."
        if (value === '0.' || value === '-0.' || value === '-' || value === '-0') {
            this.orderLineItemList[index].Round_Off__c = value;
            return;
        }

        // Clean the value - only allow digits, decimal, and negative sign
        let cleanValue = value.replace(/[^0-9.-]/g, '');

        // Handle multiple negative signs
        if (cleanValue.split('-').length > 2) {
            cleanValue = cleanValue.replace(/-/g, '');
            if (cleanValue.length > 0 && cleanValue[0] !== '-') {
                cleanValue = '-' + cleanValue;
            }
        }

        const parts = cleanValue.split('.');

        // Limit to 2 decimal places
        if (parts.length > 1) {
            parts[1] = parts[1].substring(0, 2);
            cleanValue = parts.join('.');
        }

        let numericValue = parseFloat(cleanValue);

        if (!isNaN(numericValue)) {
            numericValue = Math.round(numericValue * 100) / 100;
            this.orderLineItemList[index].Round_Off__c = numericValue;
        } else {
            this.orderLineItemList[index].Round_Off__c = null;
        }
    }

    handleRoundOffBlur(event) {
        const index = event.target.dataset.index;
        let value = this.orderLineItemList[index].Round_Off__c;

        if (value === null || value === undefined || value === '') {
            this.orderLineItemList[index].Round_Off__c = null;
            return;
        }

        // If value is a string (like "0." or "-0."), convert to proper number
        if (typeof value === 'string') {
            let numericValue = parseFloat(value);
            if (!isNaN(numericValue)) {
                numericValue = Math.round(numericValue * 100) / 100;
                this.orderLineItemList[index].Round_Off__c = numericValue;
            } else {
                this.orderLineItemList[index].Round_Off__c = null;
            }
        }
    }

    handleKeyDown(event) {
        const allowedKeys = [
            'Backspace',
            'Delete',
            'Tab',
            'ArrowLeft',
            'ArrowRight',
            'Home',
            'End'
        ];

        if (allowedKeys.includes(event.key)) {
            return;
        }

        // Block scientific notation
        if (event.key === 'e' || event.key === 'E') {
            event.preventDefault();
            return;
        }

        // Allow only one decimal point
        if (event.key === '.') {
            if (event.target.value.includes('.')) {
                event.preventDefault();
            }
            return;
        }

        // Allow minus only at first position
        if (event.key === '-') {
            if (event.target.selectionStart !== 0 || event.target.value.includes('-')) {
                event.preventDefault();
            }
            return;
        }

        // Allow plus only at first position (remove this block if + is not required)
        if (event.key === '+') {
            if (event.target.selectionStart !== 0 || event.target.value.includes('+')) {
                event.preventDefault();
            }
            return;
        }

        // Allow digits only
        if (!/^[0-9]$/.test(event.key)) {
            event.preventDefault();
        }
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
                        const fileObj = {
                            id: Date.now() + Math.random(),
                            filename: file.name,
                            base64: base64,
                            url: reader.result,
                            type: file.type,
                            isImage: file.type.startsWith('image'),
                            isPdf: file.type === 'application/pdf'
                        };
                        resolve(fileObj);
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
                // ✅ Add to both uploadedFiles (for UI) and newlyUploadedFiles (for tracking)
                this.uploadedFiles = [...this.uploadedFiles, ...results];
                this.newlyUploadedFiles = [...this.newlyUploadedFiles, ...results];
                // ✅ Also track filenames for SAP call
                const newFilenames = results.map(f => f.filename);
                this.uploadedFileNames = [...this.uploadedFileNames, ...newFilenames];

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
        this.newlyUploadedFiles = [];
        this.uploadedFileNames = [];
        this.uploadedFiles = [];
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


    async saveRoundOffValues() {
        this.showSpinner = true;

        try {
            // Prepare the Round Off updates - ONLY include if value is not empty
            const lineItemsToUpdate = this.orderLineItemList
                .filter(item => {
                    // Only include if Round_Off__c has a value (not null, not undefined, not empty string)
                    return item.Round_Off__c !== undefined &&
                        item.Round_Off__c !== null &&
                        item.Round_Off__c !== '';
                })
                .map(item => ({
                    Id: item.Id,
                    Round_Off__c: item.Round_Off__c
                }));

            // If there are Round Off values to update, call Apex
            if (lineItemsToUpdate.length > 0) {
                await updateRoundOffValues({ lineItems: lineItemsToUpdate });
                console.log('Round Off values updated successfully');
            } else {
                console.log('No Round Off values to update');
            }

            this.showSpinner = false;
            return true; // Return success

        } catch (error) {
            console.error('Error saving Round Off values:', error);
            this.showToast('Error', 'Failed to save Round Off values: ' + error.message, 'error');
            this.showSpinner = false;
            return false; // Return failure
        }
    }

    // ------------ Main Order Submit --------------------
    async handleMainSubmit(event) {
        event.preventDefault();

        // Check if there are any files uploaded (new or existing)
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
                this.saveRoundOffValues().then(success => {
                    this.uploadAllFiles();
                });
            }
        }
    }

    async uploadAllFiles() {
        this.showSpinner = true;

        try {
            // ✅ Store filenames of ONLY newly uploaded files
            this.uploadedFileNames = this.newlyUploadedFiles.map(file => file.filename);
            console.log('Files to upload and send (NEWLY ADDED ONLY):', this.uploadedFileNames);

            if (this.newlyUploadedFiles.length === 0) {
                // No files to upload, just submit the form
                const form1 = this.template.querySelector('lightning-record-edit-form[data-id="mainform"]');
                form1.submit();
                return;
            }

            // Upload only newly added files (keep track of them)
            const uploadPromises = this.newlyUploadedFiles.map(file => {
                return uploadPOAttachment({
                    quoteId: this.recordId,
                    fileName: file.filename,
                    base64Data: file.base64
                });
            });

            const results = await Promise.all(uploadPromises);
            const allSuccess = results.every(result => result.success);

            if (allSuccess) {
                this.showToast('Success', 'Files uploaded successfully', 'success');
                // ✅ Keep the filenames for later use - DON'T clear them here
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


    handleMainSuccess(event) {
        this.showToast('Please wait for callout response', '', 'info');
        this.syncDataResponseFlag = true;
        this.handleCallout();
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
        // ✅ Use ONLY the newly uploaded filenames
        const fileNames = this.uploadedFileNames.length > 0 ? this.uploadedFileNames : [];

        // Also capture files that might have been uploaded but not yet tracked
        if (fileNames.length === 0 && this.newlyUploadedFiles.length > 0) {
            // Fallback: get filenames from newlyUploadedFiles
            this.uploadedFileNames = this.newlyUploadedFiles.map(file => file.filename);
        }

        console.log('Sending files to SAP (NEWLY ADDED ONLY):', this.uploadedFileNames);

        salesOrderCreation({
            parentId: this.recordId,
            bpFuncId: this.bpValue,
            shFuncId: this.shValue,
            caFuncId: this.caValue,
            salesQuotationType: this.salesQuotationType,
            fileNames: this.uploadedFileNames  // ✅ Pass ONLY newly uploaded files
        }).then((result) => {
            console.log('result ', result);

            let parsedResult = JSON.parse(result);
            console.log('parsedResult: ', parsedResult);

            if (parsedResult.success === true) {
                if (parsedResult.quotationNumber) {
                    this.handlerUpdateQuotation(parsedResult.quotationNumber);
                } else {
                    this.showSpinner = false;
                    this.errorResponseMessage = 'SAP success but no quotation number returned';
                    this.showToast('Error', this.errorResponseMessage, 'error');
                    // ✅ Clear the tracked files on error
                    this.newlyUploadedFiles = [];
                    this.uploadedFileNames = [];
                }
            } else {
                this.showSpinner = false;
                this.errorResponseMessage = parsedResult.error || 'SAP quotation creation failed';
                this.showToast('Error', this.errorResponseMessage, 'error');
                // ✅ Clear the tracked files on error
                this.newlyUploadedFiles = [];
                this.uploadedFileNames = [];
            }

        }).catch((error) => {
            console.log('= error salesOrderCreation', error);
            this.showToast('Error', 'Something went wrong!!!', 'error');
            this.errorResponseMessage = error;
            this.showSpinner = false;
            // ✅ Clear the tracked files on error
            this.newlyUploadedFiles = [];
            this.uploadedFileNames = [];
        });
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

                // ✅ Clear the tracked files after successful submission
                this.newlyUploadedFiles = [];
                this.uploadedFileNames = [];

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
            // ✅ Clear on error too
            this.newlyUploadedFiles = [];
            this.uploadedFileNames = [];
        })
    }

}