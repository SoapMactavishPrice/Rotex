import { LightningElement, track, api, wire } from 'lwc';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import modal from "@salesforce/resourceUrl/containerCss";
import { loadStyle } from "lightning/platformResourceLoader";
import getQuoteLineItem from '@salesforce/apex/editDiscountQuantityController.getQuoteLineItem';
import updateQuoteLineItem from '@salesforce/apex/editDiscountQuantityController.updateQuoteLineItem';
import { NavigationMixin } from 'lightning/navigation';

export default class EditDiscountQuantity extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;
    @track showSpinner = false;
    @track quoteLineItemList = [];
    @track currencyCode = '';

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
                this.showSpinner = false;
            } else {
                this.showToast('Error', 'Invalid Record Id', 'error');
            }
        }, 1000);
    }

    handleGetLineItems() {
        getQuoteLineItem({
            qId: this.recordId
        }).then((result) => {
            console.log('data:>>> ', result);
            this.quoteLineItemList = result.map(item => {
                const baseDisabled = this.isRowLocked(item);
                const isApproved = item.Is_Discount_Approved__c;

                if (isApproved) {
                    // ── Approved row: New Discount ↔ Desired Price mutual-exclusion ──
                    // Discount Offered is always disabled for approved rows.
                    // Desired Price pre-fills from existing Discount_to_be_offered__c if non-zero.
                    const newDiscountBaseLocked = this.isRowLockedForNewDiscount(item); // ARC / submitted only — NOT Is_Discount_Approved__c
                    const discountIsZero = item.Discount_to_be_offered__c === 0;
                    const hasExistingDiscount = this.hasDiscountOfferedValue(item.Discount_to_be_offered__c) && !discountIsZero;
                    return {
                        ...item,
                        newDiscountValue: null,
                        desiredPriceValue: null,
                        isDiscountOfferedDisabled: true,
                        isDesiredPriceDisabled: newDiscountBaseLocked,
                        isNewDiscountDisabled: newDiscountBaseLocked,
                        isRequestedCommentsDisabled: this.computeRequestedCommentsDisabled(item, null, isApproved),
                        requestedCommentsPlaceholder: 'Enter comments...'
                    };
                } else {
                    // ── Non-approved row: Discount Offered ↔ Desired Price mutual-exclusion ──
                    const discountIsZero = item.Discount_to_be_offered__c === 0;
                    const hasExistingDiscount = this.hasDiscountOfferedValue(item.Discount_to_be_offered__c) && !discountIsZero;
                    return {
                        ...item,
                        newDiscountValue: null,
                        desiredPriceValue: hasExistingDiscount
                            ? this.computeDesiredPrice(item.ListPrice, item.Discount_to_be_offered__c)
                            : null,
                        isDesiredPriceDisabled: baseDisabled || hasExistingDiscount,
                        isDiscountOfferedDisabled: baseDisabled,
                        isNewDiscountDisabled: true, // New Discount column shows '-' for non-approved
                        isRequestedCommentsDisabled: this.computeRequestedCommentsDisabled(item, null, isApproved),
                        requestedCommentsPlaceholder: 'Enter comments...'
                    };
                }
            });
            if (result && result.length > 0) {
                this.currencyCode = result[0].CurrencyIsoCode;
            }
            console.log('quoteLineItemList ', this.quoteLineItemList);
        });
    }

    // ─── Desired Price / Discount mutual-exclusion helpers ────────────────────

    /**
     * Calculates Desired Price from ListPrice and Discount%.
     * Returns null if inputs are missing.
     */
    computeDesiredPrice(listPrice, discountPct) {
        if (listPrice == null || discountPct == null || discountPct === '') return null;
        return parseFloat((listPrice * (1 - parseFloat(discountPct) / 100)).toFixed(4));
    }

    /**
     * Calculates Discount% from ListPrice and Desired Price.
     * Returns null if inputs are missing or ListPrice is 0.
     * Result is clamped to 2 decimal places.
     */
    computeDiscountFromDesiredPrice(listPrice, desiredPrice) {
        if (listPrice == null || listPrice === 0 || desiredPrice == null || desiredPrice === '') return null;
        const raw = ((listPrice - parseFloat(desiredPrice)) / listPrice) * 100;
        return this.roundTo2Decimals(raw);
    }

    /**
     * Rounds a number to max 2 decimal places.
     * Strips trailing zeros (e.g. 10.50 → 10.5, 10.00 → 10).
     */
    roundTo2Decimals(value) {
        if (value == null) return null;
        return parseFloat(parseFloat(value).toFixed(2));
    }

    /**
     * Enforces max 2 decimal places on a string input value.
     * Returns the clamped numeric value, or null if empty.
     * Shows a toast warning if the user typed more than 2 decimals.
     */
    enforceMax2Decimals(value) {
        if (value === '' || value == null) return null;
        const str = String(value);
        const dotIndex = str.indexOf('.');
        if (dotIndex !== -1 && str.length - dotIndex - 1 > 2) {
            this.showToast('Invalid Input', 'Discount can have a maximum of 2 decimal places.', 'warning');
            return this.roundTo2Decimals(parseFloat(value));
        }
        return parseFloat(value);
    }

    /**
     * Checks whether a raw input string has more than 2 decimal places.
     */
    hasMoreThan2Decimals(rawValue) {
        const str = String(rawValue);
        const dotIndex = str.indexOf('.');
        return dotIndex !== -1 && str.length - dotIndex - 1 > 2;
    }

    hasDiscountOfferedValue(val) {
        return val != null && val !== '';
    }

    hasDesiredPriceValue(val) {
        return val != null && val !== '';
    }

    /**
     * Whether the row is intrinsically locked (ARC / approved / submitted).
     */
    isRowLocked(item) {
        return item.Item_Type__c == 'ARC' || item.Is_Discount_Approved__c || this.hasSubmittedApproverStatus(item);
    }

    /**
     * Whether the row is base-locked for the purpose of New Discount
     * (only ARC or submitted status — NOT Is_Discount_Approved__c itself,
     * since that flag is what enables the New Discount column).
     */
    isRowLockedForNewDiscount(item) {
        return item.Item_Type__c == 'ARC';
    }

    // ─── Existing helpers ─────────────────────────────────────────────────────

    /**
     * Requested Comments is enabled when there is any active discount value:
     *  - For approved rows:  newDiscountValue OR Discount_to_be_offered__c
     *  - For non-approved:   Discount_to_be_offered__c OR newDiscountValue (legacy)
     *
     * Returns true = disabled, false = enabled.
     */
    computeRequestedCommentsDisabled(item, overrideNewDiscount, isApproved) {
        const newDiscount = overrideNewDiscount !== undefined ? overrideNewDiscount : item.newDiscountValue;
        const hasDiscountOffered = item.Discount_to_be_offered__c != null && item.Discount_to_be_offered__c !== '';
        const hasNewDiscount = newDiscount != null && newDiscount !== '';
        return !(hasDiscountOffered || hasNewDiscount);
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

    // ─── Event handlers ───────────────────────────────────────────────────────

    handleCustomerPartNoChange(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        this.quoteLineItemList = this.quoteLineItemList.map(item => {
            if (item.Id === id) {
                return { ...item, Customer_Part_No__c: value };
            }
            return item;
        });
    }

    /**
     * When the user types into the Desired Price field:
     *
     * NON-APPROVED row (Discount Offered ↔ Desired Price):
     *  - Compute Discount Offered dynamically
     *  - Lock Discount Offered if Desired Price is non-null AND non-zero
     *  - Re-enable Discount Offered if Desired Price is cleared or 0
     *
     * APPROVED row (New Discount ↔ Desired Price):
     *  - Compute New Discount dynamically (max 2 decimals)
     *  - Lock New Discount if Desired Price is non-null AND non-zero
     *  - Re-enable New Discount if Desired Price is cleared or 0
     *  - Discount Offered stays disabled regardless
     */
    handleDesiredPriceChange(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        const parsedDesiredPrice = value !== '' ? parseFloat(value) : null;

        this.quoteLineItemList = this.quoteLineItemList.map(item => {
            if (item.Id === id) {
                const baseLocked = this.isRowLockedForNewDiscount(item);
                const computedDiscount = this.computeDiscountFromDesiredPrice(item.ListPrice, parsedDesiredPrice);
                const desiredPriceIsNonZero = parsedDesiredPrice !== null && parsedDesiredPrice !== 0;

                if (item.Is_Discount_Approved__c) {
                    // ── Approved: Desired Price drives New Discount ──
                    const updatedItem = {
                        ...item,
                        desiredPriceValue: parsedDesiredPrice,
                        newDiscountValue: computedDiscount,
                        Requested_Comments__c: null,
                        isDiscountOfferedDisabled: true,
                        isDesiredPriceDisabled: baseLocked,
                        isNewDiscountDisabled: baseLocked || desiredPriceIsNonZero
                    };
                    updatedItem.isRequestedCommentsDisabled = this.computeRequestedCommentsDisabled(
                        updatedItem, updatedItem.newDiscountValue, true
                    );
                    return updatedItem;
                } else {
                    // ── Non-approved: Desired Price drives Discount Offered ──
                    const updatedItem = {
                        ...item,
                        desiredPriceValue: parsedDesiredPrice,
                        Discount_to_be_offered__c: computedDiscount,
                        Requested_Comments__c: null,
                        isDesiredPriceDisabled: false,
                        isDiscountOfferedDisabled: desiredPriceIsNonZero
                    };
                    updatedItem.isRequestedCommentsDisabled = this.computeRequestedCommentsDisabled(
                        updatedItem, item.newDiscountValue, false
                    );
                    return updatedItem;
                }
            }
            return item;
        });
    }

    /**
     * When the user types into the Discount Offered field (only active on non-approved rows):
     *  - Enforce max 2 decimal places
     *  - Compute Desired Price dynamically
     *  - Lock Desired Price if Discount Offered is non-null AND non-zero
     *  - Re-enable Desired Price if Discount Offered is cleared or 0
     */
    handleDiscountChange(event) {
        const id = event.target.dataset.id;
        const rawValue = event.target.value;
        const parsedDiscount = this.enforceMax2Decimals(rawValue);

        // Push corrected value back if clamped
        if (parsedDiscount !== null && this.hasMoreThan2Decimals(rawValue)) {
            event.target.value = parsedDiscount;
        }

        this.quoteLineItemList = this.quoteLineItemList.map(item => {
            if (item.Id === id) {
                const locked = this.isRowLocked(item);
                const computedDesiredPrice = this.computeDesiredPrice(item.ListPrice, parsedDiscount);
                const discountIsNonZero = parsedDiscount !== null && parsedDiscount !== 0;
                const updatedItem = {
                    ...item,
                    Discount_to_be_offered__c: parsedDiscount,
                    desiredPriceValue: computedDesiredPrice,
                    Requested_Comments__c: null,
                    isDiscountOfferedDisabled: locked,
                    isDesiredPriceDisabled: locked || discountIsNonZero
                };
                updatedItem.isRequestedCommentsDisabled = this.computeRequestedCommentsDisabled(
                    updatedItem, item.newDiscountValue, false
                );
                return updatedItem;
            }
            return item;
        });
    }

    handlePFChargeChanges(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        this.quoteLineItemList = this.quoteLineItemList.map(item => {
            if (item.Id === id) {
                return { ...item, P_F_Charges__c: parseInt(value) };
            }
            return item;
        });
    }

    handleQuantityChange(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        this.quoteLineItemList = this.quoteLineItemList.map(item => {
            if (item.Id === id) {
                return {
                    ...item,
                    Quantity: value !== '' ? parseFloat(value) : null
                };
            }
            return item;
        });
    }

    /**
     * When the user types into the New Discount field (only active on approved rows):
     *  - Enforce max 2 decimal places
     *  - Compute Desired Price dynamically (same as Discount Offered logic)
     *  - Lock Desired Price if New Discount is non-null AND non-zero
     *  - Re-enable Desired Price if New Discount is cleared or 0
     *  - Discount Offered stays disabled regardless
     */
    handleNewDiscountChange(event) {
        const id = event.target.dataset.id;
        const rawValue = event.target.value;
        const parsedValue = this.enforceMax2Decimals(rawValue);

        // Push corrected value back if clamped
        if (parsedValue !== null && this.hasMoreThan2Decimals(rawValue)) {
            event.target.value = parsedValue;
        }

        this.quoteLineItemList = this.quoteLineItemList.map(item => {
            if (item.Id === id) {
                const baseLocked = this.isRowLockedForNewDiscount(item);
                const computedDesiredPrice = this.computeDesiredPrice(item.ListPrice, parsedValue);
                // Desired Price locked only when New Discount is non-null AND non-zero
                const newDiscountIsNonZero = parsedValue !== null && parsedValue !== 0;
                const updatedItem = {
                    ...item,
                    newDiscountValue: parsedValue,
                    desiredPriceValue: computedDesiredPrice,
                    Requested_Comments__c: null,
                    isDiscountOfferedDisabled: true,
                    isNewDiscountDisabled: baseLocked,
                    isDesiredPriceDisabled: baseLocked || newDiscountIsNonZero
                };
                updatedItem.isRequestedCommentsDisabled = this.computeRequestedCommentsDisabled(
                    updatedItem, parsedValue, true
                );
                return updatedItem;
            }
            return item;
        });
        console.log('New Discount entered for item:', id, 'Value:', parsedValue);
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

    handleSave() {
        this.showSpinner = true;

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
                Quantity: item.Quantity ? parseFloat(item.Quantity) : 0,
                Discount_to_be_offered__c: item.Discount_to_be_offered__c ? parseFloat(item.Discount_to_be_offered__c) : 0,
                Requested_Discount__c: item.Discount_to_be_offered__c ? parseFloat(item.Discount_to_be_offered__c) : 0,
                Customer_Part_No__c: item.Customer_Part_No__c,
                P_F_Charges__c: item.P_F_Charges__c ? parseFloat(item.P_F_Charges__c) : 0,
                Discount_as_per_SAP__c: parseFloat(item.Discount_as_per_SAP__c),
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
                Is_QLI_Approved_going_for_Approval__c: item.Is_QLI_Approved_going_for_Approval__c
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

        updateQuoteLineItem({
            quoteId: this.recordId,
            quoteLineItems: itemsToUpdate,
            shouldUpdateQuoteStatus: hasNewDiscountEntered
        }).then(() => {
            this.showToast('Quote Line Items Updated', '', 'success');
            this.closeModal();
        }).catch((error) => {
            console.error(error?.body);
            this.showToast('Error', error?.body?.message, 'error');
            this.errorResponseMessage = error;
            this.showSpinner = false;
        });
    }
}