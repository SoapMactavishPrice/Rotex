import { LightningElement, track, api, wire } from 'lwc';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import modal from "@salesforce/resourceUrl/containerCss";
import { loadStyle } from "lightning/platformResourceLoader";
import getQuoteAndLineItems from '@salesforce/apex/editArcDiscountQuantityController.getQuoteAndLineItems';
import updateQuoteAndLineItems from '@salesforce/apex/editArcDiscountQuantityController.updateQuoteAndLineItems';
import { NavigationMixin } from 'lightning/navigation';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';

import QUOTE_OBJECT from '@salesforce/schema/Quote';
import PAYMENT_TERMS_FIELD from '@salesforce/schema/Quote.Payment_Terms__c';
import WARRANTY_TERMS_FIELD from '@salesforce/schema/Quote.Warranty_Terms_Draft__c';
import INCO_TERMS_FIELD from '@salesforce/schema/Quote.INCO_Terms__c';

export default class EditArcDiscountQuantity extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;
    @track showSpinner = false;
    @track quoteLineItemList = [];
    @track quoteRecord = {};
    @track currencyCode = '';
    @track recordType = '';

    // Picklist options
    @track paymentTermsOptions = [];
    @track warrantyOptions = [];
    @track incoTermsOptions = [];

    // Wire Quote Object Info to get default record type ID
    @wire(getObjectInfo, { objectApiName: QUOTE_OBJECT })
    quoteObjectInfo;

    // Wire Picklist Values
    @wire(getPicklistValues, {
        recordTypeId: '$quoteObjectInfo.data.defaultRecordTypeId',
        fieldApiName: PAYMENT_TERMS_FIELD
    })
    wiredPaymentTerms({ data, error }) {
        if (data) {
            this.paymentTermsOptions = data.values.map(item => ({ label: item.label, value: item.value }));
        } else if (error) {
            console.error(error);
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$quoteObjectInfo.data.defaultRecordTypeId',
        fieldApiName: WARRANTY_TERMS_FIELD
    })
    wiredWarrantyTerms({ data, error }) {
        if (data) {
            this.warrantyOptions = data.values.map(item => ({ label: item.label, value: item.value }));
        } else if (error) {
            console.error(error);
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$quoteObjectInfo.data.defaultRecordTypeId',
        fieldApiName: INCO_TERMS_FIELD
    })
    wiredIncoTerms({ data, error }) {
        if (data) {
            this.incoTermsOptions = data.values.map(item => ({ label: item.label, value: item.value }));
        } else if (error) {
            console.error(error);
        }
    }

    // Dynamic calculations
    get totalAnticipatedBusiness() {
        return this.quoteLineItemList.reduce((sum, item) => sum + (parseFloat(item.Potential_Value__c) || 0), 0);
    }

    get totalQty() {
        return this.quoteLineItemList.reduce((sum, item) => sum + (parseFloat(item.Potential_Qty__c) || 0), 0);
    }

    showToast(toastTitle, toastMsg, toastType) {
        const event = new ShowToastEvent({
            title: toastTitle,
            message: toastMsg,
            variant: toastType,
            mode: "dismissable"
        });
        this.dispatchEvent(event);
    }

    closeModal() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Quote',
                actionName: 'view',
            }
        });
        setTimeout(() => {
            window.location.reload();
        }, 1000);
    }

    connectedCallback() {
        this.showSpinner = true;
        loadStyle(this, modal);
        setTimeout(() => {
            console.log('recordId ', this.recordId);
            console.log('objectApiName ', this.objectApiName);
            if (this.recordId) {
                this.handleGetLineItems();
            } else {
                this.showToast('Error', 'Invalid Record Id', 'error');
                this.showSpinner = false;
            }
        }, 1000);
    }

    handleGetLineItems() {
        getQuoteAndLineItems({
            qId: this.recordId
        }).then((result) => {
            console.log('result:>>> ', result);
            this.quoteRecord = result.quoteRecord || {};
            this.currencyCode = this.quoteRecord.CurrencyIsoCode || '';
            if (this.quoteRecord.RecordType && this.quoteRecord.RecordType.Name) {
                this.recordType = this.quoteRecord.RecordType.Name;
            }
            
            this.quoteLineItemList = result.lineItems.map(item => {
                const isApproved = item.Is_Discount_Approved__c;
                const existingArcPrice = result.existingArcPrices && result.existingArcPrices[item.Product2.ProductCode]
                    ? result.existingArcPrices[item.Product2.ProductCode]
                    : null;

                if (isApproved) {
                    // Approved row: Proposed ARC Price shows the PREVIOUS approved price (read-only reference).
                    // Only "New Proposed ARC Price" is editable; Disc % is calculated & read-only.
                    const newProposedPriceLocked = this.isRowLockedForNewDiscount(item);
                    return {
                        ...item,
                        existingArcPrice: existingArcPrice,
                        desiredPriceValue: this.computeDesiredPrice(item.ListPrice, item.Discount_to_be_offered__c),
                        newDesiredPriceValue: null,
                        newDiscountValue: null,
                        isProposedPriceDisabled: true,
                        isNewProposedPriceDisabled: newProposedPriceLocked,
                        isRequestedCommentsDisabled: this.computeRequestedCommentsDisabled(item, null),
                        requestedCommentsPlaceholder: 'Enter comments...'
                    };
                } else {
                    // Non-approved row: only "Proposed ARC Price" is editable; Disc % is calculated & read-only
                    const baseDisabled = this.isRowLocked(item);
                    const discountIsZero = item.Discount_to_be_offered__c === 0;
                    const hasExistingDiscount = this.hasDiscountOfferedValue(item.Discount_to_be_offered__c) && !discountIsZero;
                    return {
                        ...item,
                        existingArcPrice: existingArcPrice,
                        newDesiredPriceValue: null,
                        newDiscountValue: null,
                        desiredPriceValue: hasExistingDiscount
                            ? this.computeDesiredPrice(item.ListPrice, item.Discount_to_be_offered__c)
                            : null,
                        isProposedPriceDisabled: baseDisabled,
                        isNewProposedPriceDisabled: true,
                        isRequestedCommentsDisabled: this.computeRequestedCommentsDisabled(item, null),
                        requestedCommentsPlaceholder: 'Enter comments...'
                    };
                }
            });
            this.showSpinner = false;
        }).catch(error => {
            console.error(error);
            this.showToast('Error', 'Failed to retrieve details: ' + (error?.body?.message || error?.message), 'error');
            this.showSpinner = false;
        });
    }

    // Calculation helper functions
    computeDesiredPrice(listPrice, discountPct) {
        if (listPrice == null || discountPct == null || discountPct === '') return null;
        return parseFloat((listPrice * (1 - parseFloat(discountPct) / 100)).toFixed(4));
    }

    computeDiscountFromDesiredPrice(listPrice, desiredPrice) {
        if (listPrice == null || listPrice === 0 || desiredPrice == null || desiredPrice === '') return null;
        const raw = ((listPrice - parseFloat(desiredPrice)) / listPrice) * 100;
        return this.roundTo3Decimals(raw);
    }

    roundTo3Decimals(value) {
        if (value == null) return null;
        return parseFloat(parseFloat(value).toFixed(3));
    }

    enforceMax3Decimals(value) {
        if (value === '' || value == null) return null;
        const str = String(value);
        const dotIndex = str.indexOf('.');
        if (dotIndex !== -1 && str.length - dotIndex - 1 > 3) {
            this.showToast('Invalid Input', 'Discount can have a maximum of 3 decimal places.', 'warning');
            return this.roundTo3Decimals(parseFloat(value));
        }
        return parseFloat(value);
    }

    hasMoreThan3Decimals(rawValue) {
        const str = String(rawValue);
        const dotIndex = str.indexOf('.');
        return dotIndex !== -1 && str.length - dotIndex - 1 > 3;
    }

    hasDiscountOfferedValue(val) {
        return val != null && val !== '';
    }

    computeRequestedCommentsDisabled(item, overrideNewDiscount) {
        const newDiscount = overrideNewDiscount !== undefined ? overrideNewDiscount : item.newDiscountValue;
        const hasDiscountOffered = item.Discount_to_be_offered__c != null && item.Discount_to_be_offered__c !== '';
        const hasNewDiscount = newDiscount != null && newDiscount !== '';
        return !(hasDiscountOffered || hasNewDiscount);
    }

    isRowLocked(item) {
        return item.Item_Type__c == 'ARC' || item.Is_Discount_Approved__c || this.hasSubmittedApproverStatus(item);
    }

    isRowLockedForNewDiscount(item) {
        return item.Item_Type__c == 'ARC';
    }

    hasSubmittedApproverStatus(item) {
        return [
            item.Sales_Manager_Status__c,
            item.Country_Continent_Sales_H_LOB_Status__c,
            item.Global_Sales_Head_Status__c,
            item.Rotex_Board_Member_Status__c,
            item.Managing_Director_Status__c
        ].some(status => status === 'Submitted');
    }

    // Quote field change handlers
    handlePaymentTermsChange(event) {
        this.quoteRecord = { ...this.quoteRecord, Payment_Terms__c: event.detail.value };
    }

    handleWarrantyTermsChange(event) {
        this.quoteRecord = { ...this.quoteRecord, Warranty_Terms_Draft__c: event.detail.value };
    }

    handleIncoTermsChange(event) {
        this.quoteRecord = { ...this.quoteRecord, INCO_Terms__c: event.detail.value };
    }

    handleDesiredPriceChange(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        const parsedDesiredPrice = value !== '' ? parseFloat(value) : null;

        this.quoteLineItemList = this.quoteLineItemList.map(item => {
            if (item.Id === id) {
                const computedDiscount = this.computeDiscountFromDesiredPrice(item.ListPrice, parsedDesiredPrice);
                const updatedItem = {
                    ...item,
                    desiredPriceValue: parsedDesiredPrice,
                    Discount_to_be_offered__c: computedDiscount,
                    Requested_Comments__c: null
                };
                updatedItem.isRequestedCommentsDisabled = this.computeRequestedCommentsDisabled(
                    updatedItem, item.newDiscountValue
                );
                return updatedItem;
            }
            return item;
        });
    }

    // New Proposed ARC Price change (approved rows) -> recalculates New Disc %
    handleNewDesiredPriceChange(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        const parsedPrice = value !== '' ? parseFloat(value) : null;

        this.quoteLineItemList = this.quoteLineItemList.map(item => {
            if (item.Id === id) {
                const computedDiscount = this.computeDiscountFromDesiredPrice(item.ListPrice, parsedPrice);
                const updatedItem = {
                    ...item,
                    newDesiredPriceValue: parsedPrice,
                    newDiscountValue: computedDiscount,
                    Requested_Comments__c: null
                };
                updatedItem.isRequestedCommentsDisabled = this.computeRequestedCommentsDisabled(
                    updatedItem, computedDiscount
                );
                return updatedItem;
            }
            return item;
        });
    }

    handleRequestedCommentsChange(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        this.quoteLineItemList = this.quoteLineItemList.map(item => {
            if (item.Id === id) {
                return { ...item, Requested_Comments__c: value };
            }
            return item;
        });
    }

    handleNumberFieldChange(event) {
        const id = event.target.dataset.id;
        const field = event.target.dataset.field;
        const value = event.target.value;
        
        this.quoteLineItemList = this.quoteLineItemList.map(item => {
            if (item.Id === id) {
                return {
                    ...item,
                    [field]: value !== '' ? parseFloat(value) : null
                };
            }
            return item;
        });
    }

    handleDateFieldChange(event) {
        const id = event.target.dataset.id;
        const field = event.target.dataset.field;
        const value = event.target.value;
        
        this.quoteLineItemList = this.quoteLineItemList.map(item => {
            if (item.Id === id) {
                return {
                    ...item,
                    [field]: value !== '' ? value : null
                };
            }
            return item;
        });

        if (field === 'Valid_from__c') {
            const inputField = event.target;
            const selectedDate = value
                ? new Date(new Date(value).setHours(0, 0, 0, 0))
                : null;

            const today = new Date();
            today.setHours(0, 0, 0, 0);

            if (selectedDate && selectedDate < today) {
                inputField.setCustomValidity('Valid From date cannot be before today.');
            } else {
                inputField.setCustomValidity('');
            }

            inputField.reportValidity();
        }
        
        if (field === 'Valid_Till__c') {
            const inputField = event.target;
            const selectedDate = value
                ? new Date(new Date(value).setHours(0, 0, 0, 0))
                : null;
            const fyEndDate = this.getFiscalYearEndDate();
            console.log('selected date', selectedDate, 'fyEndDate', fyEndDate);
            if (selectedDate && selectedDate > fyEndDate) {
                const formattedDate = this.formatDate(fyEndDate);
                inputField.setCustomValidity(`Date cannot be beyond Financial Year end (${formattedDate})`);
            } else {
                inputField.setCustomValidity('');
            }
            inputField.reportValidity();
        }
    }

    getFiscalYearEndDate() {
        const today = new Date();
        const currentYear = today.getFullYear();
        const currentMonth = today.getMonth(); // 0-indexed: 0 is Jan
        let fyEndYear = currentYear;
        if (currentMonth >= 3) { // April or later
            fyEndYear = currentYear + 1;
        }
        console.log('new Date(fyEndYear, 2, 31)', new Date(fyEndYear, 2, 31));
        return new Date(fyEndYear, 2, 31); // March 31st
    }

    formatDate(date) {
        const day = String(date.getDate()).padStart(2, '0');
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const year = date.getFullYear();
        return `${day}-${month}-${year}`;
    }

    // Save handling
    handleSave() {
        this.showSpinner = true;

        const allValid = [...this.template.querySelectorAll('lightning-input')]
            .reduce((validSoFar, inputFields) => {
                inputFields.reportValidity();
                return validSoFar && inputFields.checkValidity();
            }, true);

        if (!allValid) {
            this.showToast('Validation Error', 'Please check and correct the errors on the page.', 'error');
            this.showSpinner = false;
            return;
        }

        const invalidPotentialRow = this.quoteLineItemList.find(item => {

            const hasPotentialQty =
                item.Potential_Qty__c !== null &&
                item.Potential_Qty__c !== undefined &&
                item.Potential_Qty__c !== '';

            return !hasPotentialQty;
        });

        if (invalidPotentialRow) {
            this.showToast(
                'Validation Error',
                'For each row, Proposed Qty is mandatory.',
                'error'
            );
            this.showSpinner = false;
            return;
        }

        const invalidNewDiscountItem = this.quoteLineItemList.find(item =>
            item.Is_Discount_Approved__c &&
            item.newDiscountValue != null &&
            item.newDiscountValue !== '' &&
            item.Discount_as_per_SAP__c > 0 &&
            parseFloat(item.newDiscountValue) < parseFloat(item.Discount_as_per_SAP__c)
        );

        const invalidDiscountItem = this.quoteLineItemList.find(item =>
            item.Discount_to_be_offered__c != null &&
            item.Discount_to_be_offered__c !== '' &&
            item.Discount_as_per_SAP__c > 0 &&
            parseFloat(item.Discount_to_be_offered__c) < parseFloat(item.Discount_as_per_SAP__c)
        );

        if (invalidDiscountItem || invalidNewDiscountItem) {
            this.showToast(
                'Error',
                'Discount Value cannot be less than Discount as per SAP.',
                'error'
            );
            this.showSpinner = false;
            return;
        }

        const hasNewDiscountEntered = this.quoteLineItemList.some(item =>
            item.Is_Discount_Approved__c &&
            item.newDiscountValue != null &&
            item.newDiscountValue !== ''
        );

        const itemsToUpdate = this.quoteLineItemList.map(item => {
            const updateData = {
                Id: item.Id,
                Quantity: 1, // Set QLI.Quantity as 1
                Discount_as_per_SAP__c: 0, // Discount as per SAP to 0
                Discount_to_be_offered__c: item.Discount_to_be_offered__c ? parseFloat(item.Discount_to_be_offered__c) : 0,
                Requested_Discount__c: item.Discount_to_be_offered__c ? parseFloat(item.Discount_to_be_offered__c) : 0,
                Customer_Part_No__c: item.Customer_Part_No__c,
                P_F_Charges__c: item.P_F_Charges__c ? parseFloat(item.P_F_Charges__c) : 0,
                Requested_Comments__c: item.Requested_Comments__c || null,
                Is_Discount_Only_Rejected__c: item.Is_Discount_Only_Rejected__c,

                Final_Discount_Approver__c: item.Final_Discount_Approver__c,
                Sales_Rep__c: item.Sales_Rep__c,
                Sales_Manager__c: item.Sales_Manager__c,
                Country_Continent_Sales_Head_LOB_Head__c: item.Country_Continent_Sales_Head_LOB_Head__c,
                Global_Sales_Head__c: item.Global_Sales_Head__c,
                Rotex_Board_Member__c: item.Rotex_Board_Member__c,
                Managing_Director_Country_Manage__c: item.Managing_Director_Country_Manage__c,
                Is_Discount_Approved__c: item.Is_Discount_Approved__c,
                Is_QLI_Approved_going_for_Approval__c: item.Is_QLI_Approved_going_for_Approval__c,

                Potential_Value__c: item.Potential_Value__c ? parseFloat(item.Potential_Value__c) : null,
                Potential_Qty__c: item.Potential_Qty__c ? parseFloat(item.Potential_Qty__c) : null,
                Valid_from__c: item.Valid_from__c || null,
                Valid_Till__c: item.Valid_Till__c || null
            };

            if (item.Is_Discount_Approved__c && item.newDiscountValue != null && item.newDiscountValue !== '') {
                updateData.Is_Edited_Through_Edit_Discount__c = true;
                updateData.Previous_Discount__c = item.Discount_to_be_offered__c;
                updateData.Discount_to_be_offered__c = parseFloat(item.newDiscountValue);
                updateData.Requested_Discount__c = parseFloat(item.newDiscountValue);
                updateData.New_Discount_Entered__c = true;

                updateData.Sales_Manager_Comments__c = item.Sales_Manager_Comments__c;
                updateData.Sales_Manager_Date_Time__c = item.Sales_Manager_Date_Time__c;
                updateData.Country_Continent_Sales_LOB_Comments__c = item.Country_Continent_Sales_LOB_Comments__c;
                updateData.Country_Head_Date_Time__c = item.Country_Head_Date_Time__c;
                updateData.Global_Sales_Head_Comments__c = item.Global_Sales_Head_Comments__c;
                updateData.Global_Sales_Head_Date_Time__c = item.Global_Sales_Head_Date_Time__c;
                updateData.Rotex_Board_Member_Comments__c = item.Rotex_Board_Member_Comments__c;
                updateData.Rotex_Board_Member_Date_time__c = item.Rotex_Board_Member_Date_time__c;
                updateData.Managing_Director_Comments__c = item.Managing_Director_Comments__c;
                updateData.Managing_Director_Date_Time__c = item.Managing_Director_Date_Time__c;
            } else if (item.Previous_Discount__c) {
                updateData.Previous_Discount__c = item.Previous_Discount__c;
            }

            return updateData;
        });

        updateQuoteAndLineItems({
            quoteId: this.recordId,
            quoteLineItems: itemsToUpdate,
            shouldUpdateQuoteStatus: hasNewDiscountEntered,
            paymentTerms: this.quoteRecord.Payment_Terms__c,
            warrantyTerms: this.quoteRecord.Warranty_Terms_Draft__c,
            incoTerms: this.quoteRecord.INCO_Terms__c
        }).then(() => {
            this.showToast('Quote and ARC Line Items Updated', '', 'success');
            this.closeModal();
        }).catch((error) => {
            console.error(error);
            this.showToast('Error', 'Failed to save changes: ' + (error?.body?.message || error?.message), 'error');
            this.showSpinner = false;
        });
    }
}