import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getQuoteSapData from '@salesforce/apex/DealerQuoteSapController.getQuoteSapData';
import updateQuoteSapDetails from '@salesforce/apex/DealerQuoteSapController.updateQuoteSapDetails';
import sendQuoteToSap from '@salesforce/apex/DealerQuoteSapController.sendQuoteToSap';
import saveQuoteAttachment from '@salesforce/apex/QuoteController.saveQuoteAttachment';
import getQuoteFiles from '@salesforce/apex/QuoteController.getQuoteFiles';
import deleteQuoteAttachment from '@salesforce/apex/QuoteController.deleteQuoteAttachment';

function toInputDate(value) {
    if (!value) {
        return '';
    }
    return String(value).substring(0, 10);
}

const IMAGE_TYPES = ['PNG', 'JPG', 'JPEG', 'GIF', 'WEBP', 'BMP', 'SVG'];

export default class DealerQuoteSapModal extends LightningElement {
    @api quoteId;

    @track lineItems = [];
    @track billToOptions = [];
    @track shipToOptions = [];
    @track salesAgentOptions = [];
    @track poFiles = [];

    yesNoOptions = [
        { label: '--None--', value: '' },
        { label: 'Yes', value: 'Yes' },
        { label: 'No', value: 'No' }
    ];

    requestedDeliveryDate = '';
    customerReferenceDate = '';
    customerReferenceNo = '';
    billToPartnerId = '';
    shipToPartnerId = '';
    salesAgentPartnerId = '';
    pbgOrBgRequired = '';
    pbgOrBgComments = '';
    ldClauseApplicable = '';
    ldClauseComments = '';
    hasPoAttachment = false;
    showPoFilesPreview = false;
    @track errors = {};
    @track showValidationBanner = false;
    validationBannerTimeout;

    showSpinner = false;
    isSaving = false;
    syncDataResponseFlag = false;
    responseMessage = '';
    errorResponseMessage = '';
    loadError = '';

    connectedCallback() {
        this.loadData();
    }

    get hasPoFiles() {
        return this.poFiles && this.poFiles.length > 0;
    }

    get poFilesPreviewTitle() {
        const count = this.poFiles ? this.poFiles.length : 0;
        return `Files Selected (${count})`;
    }

    loadData() {
        if (!this.quoteId) {
            this.loadError = 'Invalid Quote Id.';
            return;
        }

        this.showSpinner = true;
        getQuoteSapData({ quoteId: this.quoteId })
            .then((result) => {
                const data = JSON.parse(result || '{}');
                const quote = data.quote || {};
                const validation = data.validation || {};
                const sapData = data.sapData || {};

                if (String(validation.status) !== 'true') {
                    this.loadError = validation.message || 'Quote cannot be sent to SAP.';
                }

                this.requestedDeliveryDate = toInputDate(quote.RequestedDeliveryDate__c);
                this.customerReferenceDate = toInputDate(quote.Customer_Reference_Date__c);
                this.customerReferenceNo = quote.Customer_Reference_No__c || '';
                // Keep PBG / LD as --None-- until user explicitly selects Yes/No
                this.pbgOrBgRequired = '';
                this.ldClauseApplicable = '';
                this.pbgOrBgComments = quote.PBG_or_BG_comments__c || '';
                this.ldClauseComments = quote.LD_Clause_comments__c || '';
                this.hasPoAttachment = data.hasPoAttachment === true;
                this.lineItems = (sapData.quoteLineItemList || []).map((item) => ({
                    ...item,
                    productName: item.Product2?.Name || '',
                    roundOff:
                        item.Round_Off__c != null && item.Round_Off__c !== ''
                            ? String(item.Round_Off__c)
                            : ''
                }));
                this.billToOptions = this.mapPartnerOptions(sapData.bpList);
                this.shipToOptions = this.mapPartnerOptions(sapData.shList);
                this.salesAgentOptions = this.mapPartnerOptions(sapData.caList);
                return this.loadPoFiles();
            })
            .catch((error) => {
                this.loadError = this.extractErrorMessage(error);
            })
            .finally(() => {
                this.showSpinner = false;
            });
    }

    loadPoFiles() {
        return getQuoteFiles({ quoteId: this.quoteId })
            .then((data) => {
                this.poFiles = (data || []).map((file) => this.mapPoFile(file));
                this.hasPoAttachment = this.poFiles.length > 0;
            })
            .catch(() => {
                // Keep hasPoAttachment from SAP payload if file list fails
            });
    }

    mapPoFile(file, localUrl) {
        const type = (file.fileType || '').toUpperCase();
        const fromName = String(file.title || '')
            .split('.')
            .pop()
            .toUpperCase();
        const resolvedType = type || fromName;
        const isImage =
            IMAGE_TYPES.includes(resolvedType) ||
            (localUrl && String(localUrl).startsWith('data:image'));
        const isPdf = resolvedType === 'PDF';
        const url =
            localUrl ||
            (file.versionId ? '/sfc/servlet.shepherd/version/download/' + file.versionId : '');

        return {
            id: file.id,
            versionId: file.versionId,
            title: file.title,
            fileType: resolvedType,
            url,
            isImage,
            isPdf,
            isOther: !isImage && !isPdf
        };
    }

    mapPartnerOptions(items) {
        return (items || []).map((item) => {
            const address = [
                item.Name,
                item.Street__c,
                item.City__c,
                item.State__c,
                item.Postal_Code__c,
                item.Country__c
            ]
                .filter((part) => part)
                .join(', ');
            return {
                label: address,
                value: item.Id
            };
        });
    }

    get hasLineItems() {
        return this.lineItems && this.lineItems.length > 0;
    }

    get showPbgComments() {
        return this.pbgOrBgRequired === 'Yes';
    }

    get showLdComments() {
        return this.ldClauseApplicable === 'Yes';
    }

    get pbgRowClass() {
        return this.showPbgComments
            ? 'form-grid form-grid-pbg-ld'
            : 'form-grid form-grid-pbg-only';
    }

    get ldRowClass() {
        return this.showLdComments
            ? 'form-grid form-grid-pbg-ld'
            : 'form-grid form-grid-pbg-only';
    }

    get pbgRequiredInputClass() {
        return this.errors.pbgOrBgRequired ? 'sap-combobox-error' : '';
    }

    get ldApplicableInputClass() {
        return this.errors.ldClauseApplicable ? 'sap-combobox-error' : '';
    }

    get billToInputClass() {
        return this.errors.billToPartnerId ? 'sap-combobox-error' : '';
    }

    get shipToInputClass() {
        return this.errors.shipToPartnerId ? 'sap-combobox-error' : '';
    }

    get requestedDeliveryDateInputClass() {
        return this.errors.requestedDeliveryDate
            ? 'form-input form-input-error'
            : 'form-input';
    }

    get customerReferenceDateInputClass() {
        return this.errors.customerReferenceDate
            ? 'form-input form-input-error'
            : 'form-input';
    }

    get customerReferenceNoInputClass() {
        return this.errors.customerReferenceNo
            ? 'form-input form-input-error'
            : 'form-input';
    }

    get pbgCommentsInputClass() {
        return this.errors.pbgOrBgComments
            ? 'form-input form-textarea form-input-error'
            : 'form-input form-textarea';
    }

    get ldCommentsInputClass() {
        return this.errors.ldClauseComments
            ? 'form-input form-textarea form-input-error'
            : 'form-input form-textarea';
    }

    get showValidationBannerMessage() {
        return this.showValidationBanner === true;
    }

    get validationBannerMessage() {
        return 'Please fill/select all the mandatory fields.';
    }

    get isSaveDisabled() {
        return this.isSaving || this.showSpinner || !!this.loadError;
    }

    clearValidationBannerTimer() {
        if (this.validationBannerTimeout) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            clearTimeout(this.validationBannerTimeout);
            this.validationBannerTimeout = null;
        }
    }

    showValidationBannerForFiveSeconds() {
        this.clearValidationBannerTimer();
        this.showValidationBanner = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.validationBannerTimeout = setTimeout(() => {
            this.showValidationBanner = false;
            this.validationBannerTimeout = null;
        }, 5000);
    }

    disconnectedCallback() {
        this.clearValidationBannerTimer();
    }

    clearFieldError(field) {
        if (!field || !this.errors?.[field]) {
            return;
        }
        const next = { ...this.errors };
        delete next[field];
        this.errors = next;
    }

    handleFieldChange(event) {
        const field =
            event.currentTarget?.dataset?.field || event.target?.dataset?.field;
        if (!field) {
            return;
        }
        const raw =
            event.detail && Object.prototype.hasOwnProperty.call(event.detail, 'value')
                ? event.detail.value
                : event.target.value;
        this[field] = raw == null ? '' : String(raw);
        this.clearFieldError(field);
        if (field === 'pbgOrBgRequired' && this.pbgOrBgRequired !== 'Yes') {
            this.pbgOrBgComments = '';
            this.clearFieldError('pbgOrBgComments');
        }
        if (field === 'ldClauseApplicable' && this.ldClauseApplicable !== 'Yes') {
            this.ldClauseComments = '';
            this.clearFieldError('ldClauseComments');
        }
    }

    handleRoundOffChange(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        this.lineItems = (this.lineItems || []).map((item) => {
            if (item.Id !== id) {
                return item;
            }
            return { ...item, roundOff: value };
        });
    }

    handlePoFileInputChange(event) {
        const files = event.target.files;
        if (!files || files.length === 0 || !this.quoteId) {
            return;
        }

        Array.from(files).forEach((file) => {
            this.uploadPoFile(file);
        });
        event.target.value = '';
    }

    uploadPoFile(file) {
        const reader = new FileReader();
        reader.onload = () => {
            const dataUrl = reader.result;
            const base64Data = String(dataUrl).split(',')[1];
            this.showSpinner = true;
            saveQuoteAttachment({
                quoteId: this.quoteId,
                fileName: file.name,
                base64Data
            })
                .then((saved) => {
                    const mapped = this.mapPoFile(saved || { title: file.name }, dataUrl);
                    this.poFiles = [mapped, ...this.poFiles];
                    this.hasPoAttachment = true;
                    this.showToast('Success', 'PO file uploaded successfully.', 'success');
                })
                .catch((error) => {
                    this.showToast('Error', this.extractErrorMessage(error), 'error');
                })
                .finally(() => {
                    this.showSpinner = false;
                });
        };
        reader.onerror = () => {
            this.showToast('Error', 'Could not read file: ' + file.name, 'error');
        };
        reader.readAsDataURL(file);
    }

    openPoFilesPreview() {
        if (!this.hasPoFiles) {
            return;
        }
        this.showPoFilesPreview = true;
    }

    closePoFilesPreview() {
        this.showPoFilesPreview = false;
    }

    handleDeletePoFile(event) {
        event.stopPropagation();
        const fileId = event.currentTarget.dataset.id;
        if (!fileId || !this.quoteId) {
            return;
        }

        this.showSpinner = true;
        deleteQuoteAttachment({ quoteId: this.quoteId, contentDocumentId: fileId })
            .then(() => {
                this.poFiles = this.poFiles.filter((file) => file.id !== fileId);
                this.hasPoAttachment = this.poFiles.length > 0;
                if (!this.hasPoAttachment) {
                    this.showPoFilesPreview = false;
                }
                this.showToast('Success', 'File removed.', 'success');
            })
            .catch((error) => {
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            })
            .finally(() => {
                this.showSpinner = false;
            });
    }

    handleSave(event) {
        event.preventDefault();
        if (!this.validate()) {
            return;
        }

        this.isSaving = true;
        this.showSpinner = true;

        const input = {
            quoteId: this.quoteId,
            requestedDeliveryDate: this.requestedDeliveryDate,
            customerReferenceDate: this.customerReferenceDate,
            customerReferenceNo: this.customerReferenceNo,
            billToPartnerId: this.billToPartnerId,
            shipToPartnerId: this.shipToPartnerId,
            salesAgentPartnerId: this.salesAgentPartnerId || null,
            pbgOrBgRequired: this.pbgOrBgRequired || null,
            pbgOrBgComments: this.showPbgComments ? this.pbgOrBgComments || null : null,
            ldClauseApplicable: this.ldClauseApplicable || null,
            ldClauseComments: this.showLdComments ? this.ldClauseComments || null : null,
            salesQuotationType: 'ZQT',
            fileNames: (this.poFiles || []).map((f) => f.title).filter((n) => !!n),
            lineItems: (this.lineItems || []).map((item) => ({
                id: item.Id,
                roundOff:
                    item.roundOff !== '' && item.roundOff != null
                        ? Number(item.roundOff)
                        : null
            }))
        };

        // Same as IntegrationHandler flow: save Quote first (own transaction), then SAP callouts
        updateQuoteSapDetails({ input })
            .then(() => sendQuoteToSap({ input }))
            .then((result) => this.handleSapResponse(result))
            .catch((error) => {
                this.errorResponseMessage = this.extractErrorMessage(error);
                this.syncDataResponseFlag = true;
                this.showToast('Error', this.errorResponseMessage, 'error');
            })
            .finally(() => {
                this.isSaving = false;
                this.showSpinner = false;
            });
    }

    handleSapResponse(result) {
        let parsed;
        try {
            parsed = typeof result === 'string' ? JSON.parse(result) : result;
            // Support legacy double-encoded OData responses if present
            if (typeof parsed === 'string') {
                parsed = JSON.parse(parsed);
            }
        } catch (e) {
            this.errorResponseMessage = 'Unable to read SAP response.';
            this.syncDataResponseFlag = true;
            return;
        }

        const sapQuotationNumber =
            parsed?.quotationNumber ||
            parsed?.d?.SalesQuotation ||
            '';
        const success = parsed?.success === true || !!sapQuotationNumber;

        if (!success || !sapQuotationNumber) {
            this.errorResponseMessage =
                parsed?.error ||
                (parsed?.error?.message ? JSON.stringify(parsed.error.message) : '') ||
                'Something went wrong while sending quote to SAP.';
            this.syncDataResponseFlag = true;
            this.showToast('Error', this.errorResponseMessage || 'Something went wrong!!!', 'error');
            return;
        }

        this.responseMessage = 'SAP Quotation Number: ' + sapQuotationNumber;
        this.syncDataResponseFlag = true;
        this.showToast('Success', 'Quotation created in SAP successfully!', 'success');
        this.dispatchEvent(new CustomEvent('save', { bubbles: true, composed: true }));
    }

    validate() {
        const next = {};
        if (!this.requestedDeliveryDate) {
            next.requestedDeliveryDate = 'Requested Delivery Date is required.';
        }
        if (!this.customerReferenceDate) {
            next.customerReferenceDate = 'Customer PO Date is required.';
        }
        if (!String(this.customerReferenceNo || '').trim()) {
            next.customerReferenceNo = 'Customer PO No is required.';
        }
        if (!this.hasPoAttachment) {
            next.poAttachment = 'PO Attachment is required.';
        }
        if (!this.billToPartnerId) {
            next.billToPartnerId = 'Bill To Party is required.';
        }
        if (!this.shipToPartnerId) {
            next.shipToPartnerId = 'Ship To Party is required.';
        }
        if (!this.pbgOrBgRequired) {
            next.pbgOrBgRequired = 'PBG or BG required is required.';
        }
        if (this.pbgOrBgRequired === 'Yes' && !String(this.pbgOrBgComments || '').trim()) {
            next.pbgOrBgComments = 'PBG comment is required.';
        }
        if (!this.ldClauseApplicable) {
            next.ldClauseApplicable = 'LD Clause Applicable is required.';
        }
        if (this.ldClauseApplicable === 'Yes' && !String(this.ldClauseComments || '').trim()) {
            next.ldClauseComments = 'LD clause from quote is required.';
        }
        this.errors = next;
        if (Object.keys(next).length > 0) {
            this.showValidationBannerForFiveSeconds();
            return false;
        }
        this.showValidationBanner = false;
        this.clearValidationBannerTimer();
        return true;
    }

    handleClose() {
        if (this.isSaving) {
            return;
        }
        this.dispatchEvent(new CustomEvent('close', { bubbles: true, composed: true }));
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant: variant || 'info'
            })
        );
    }

    extractErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'Something went wrong. Please try again.';
    }
}