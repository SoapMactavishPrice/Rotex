import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllQuotations from '@salesforce/apex/SalesPriceApprovalForQuotation.getAllQuotations';
import updateQuoteLineItem from '@salesforce/apex/SalesPriceApprovalForQuotation.updateQuoteLineItem';
import USER_ID from '@salesforce/user/Id';
import { NavigationMixin } from 'lightning/navigation';

export default class QuoteSalesPriceApproval extends NavigationMixin(LightningElement) {
    @track quotes;
    @track updatedLineItems = new Map();
    @track isSaveDisabled = false;
    @track skipSoaRestrictions = false;

    userId = USER_ID;

    @track statusOptions = [
        { label: 'Submitted', value: 'Submitted' },
        { label: 'Approved', value: 'Approved' },
        { label: 'Rejected', value: 'Rejected' }
    ];
    error;

    connectedCallback() {
        this.fetchQuotes();
    }

    get isLoading() {
        return this.isSaveDisabled;
    }

    get isSubmitDisabled() {
        return this.isSaveDisabled || this.requiresNonFinalApproverComment();
    }

    fetchQuotes() {
        getAllQuotations()
            .then(result => {
                this.quotes = result.map(q => this.processQuote(q));
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
                this.redirectToHome();
                setTimeout(() => { window.location.reload(); }, 2500);
            });
    }

    processQuote(q) {
        const quoteRecordUrl = `/lightning/r/Quote/${q.quoteId}/view`;
        const processedLineItems = (q.quoteLineItems || []).map(item => ({
            ...item,
            isFinalDiscountApprover: item.finalDiscountApproverId === this.userId,
            isEditable: item.approvalStatus === 'Submitted',
            skipSoaRestrictions: this.skipSoaRestrictions,
            skipEditableCommentFields: item.skipEditableCommentFields || {}
        }));

        return {
            ...q,
            quoteRecordUrl,
            quoteLineItems: processedLineItems,
            displayRows: this.buildDisplayRows(processedLineItems)
        };
    }

    buildDisplayRows(lineItems) {
        const displayRows = [];
        (lineItems || []).forEach(item => {
            const soaLevels = this.getSoaLevels(item);
            soaLevels.forEach((soa, idx) => {
                const formattedDateTime = soa.dateTime
                    ? new Date(soa.dateTime).toLocaleString('en-GB', {
                        day: '2-digit', month: '2-digit', year: 'numeric',
                        hour: '2-digit', minute: '2-digit'
                    })
                    : '';
                const skipCommentEnabled = this.isSkipCommentEnabled(item, soa);
                const skipFinalStatusEnabled = this.skipSoaRestrictions &&
                    this.isFinalPreviousHierarchyRow(item, soa);
                const showStatusCombobox = (item.isFinalDiscountApprover && soa.isCurrentUserRow && item.isEditable) ||
                    skipFinalStatusEnabled;
                const showCommentInput = (soa.isCurrentUserRow && item.isEditable) || skipCommentEnabled;

                displayRows.push({
                    key: `${item.quoteLineItemId}_${idx}`,
                    isFirstRow: idx === 0,
                    soaCount: soaLevels.length,
                    productName: item.productName,
                    listPrice: item.listPrice,
                    quantity: item.quantity,
                    d1: item.d1,
                    previousDiscount: item.previousDiscount,
                    d2: item.d2,
                    quoteLineItemId: item.quoteLineItemId,
                    parentId: item.parentId,
                    approvalStatus: skipFinalStatusEnabled ? soa.status : item.approvalStatus,
                    soaStatusField: soa.statusField,
                    soaDisplay: soa.name ? `${soa.label} - ${soa.name}` : '',
                    soaStatus: soa.status || '',
                    soaDateTime: formattedDateTime,
                    prevSoaComments: soa.previousCommentsValue || '',
                    soaComments: soa.commentsValue || '',
                    soaCommentsField: soa.commentsField,
                    showStatusCombobox,
                    showStatusText: !showStatusCombobox,
                    showCommentInput,
                    soaCommentsDisabled: !(soa.isCurrentUserRow && item.isEditable) && !skipCommentEnabled,
                    rowStyle: ''
                });
            });
        });

        return displayRows;
    }

    getSoaLevels(item) {
        return [
            {
                label: 'SM', name: item.salesManagerName, approverId: item.salesManagerId,
                status: item.salesManagerStatus, statusField: 'Sales_Manager_Status__c',
                dateTime: item.salesManagerDateTime, commentsField: 'Sales_Manager_Comments',
                commentsValue: item.Sales_Manager_Comments,
                previousCommentsValue: item.prevSalesManagerComments,
                isCurrentUserRow: !item.bcheck1, hierarchyIndex: 1
            },
            {
                label: 'CH', name: item.countryContinentSalesName, approverId: item.countryContinentSalesId,
                status: item.countryContinentSalesStatus, statusField: 'Country_Continent_Sales_H_LOB_Status__c',
                dateTime: item.countryHeadDateTime, commentsField: 'Country_Continent_Sales_LOB_Comments',
                commentsValue: item.Country_Continent_Sales_LOB_Comments,
                previousCommentsValue: item.prevCountryContinentSalesComments,
                isCurrentUserRow: !item.bcheck2, hierarchyIndex: 2
            },
            {
                label: 'GS', name: item.globalSalesHeadName, approverId: item.globalSalesHeadId,
                status: item.globalSalesHeadStatus, statusField: 'Global_Sales_Head_Status__c',
                dateTime: item.globalSalesHeadDateTime, commentsField: 'Global_Sales_Head_Comments',
                commentsValue: item.Global_Sales_Head_Comments,
                previousCommentsValue: item.prevGlobalSalesHeadComments,
                isCurrentUserRow: !item.bcheck5, hierarchyIndex: 3
            },
            {
                label: 'BM', name: item.rotexBoardMemberName, approverId: item.rotexBoardMemberId,
                status: item.rotexBoardMemberStatus, statusField: 'Rotex_Board_Member_Status__c',
                dateTime: item.rotexBoardMemberDateTime, commentsField: 'Rotex_Board_Member_Comments',
                commentsValue: item.Rotex_Board_Member_Comments,
                previousCommentsValue: item.prevRotexBoardMemberComments,
                isCurrentUserRow: !item.bcheck3, hierarchyIndex: 4
            },
            {
                label: 'MD', name: item.managingDirectorName, approverId: item.managingDirectorId,
                status: item.managingDirectorStatus, statusField: 'Managing_Director_Status__c',
                dateTime: item.managingDirectorDateTime, commentsField: 'Managing_Director_Comments',
                commentsValue: item.Managing_Director_Comments,
                previousCommentsValue: item.prevManagingDirectorComments,
                isCurrentUserRow: !item.bcheck4, hierarchyIndex: 5
            }
        ];
    }

    isPreviousHierarchyRow(item, hierarchyIndex) {
        const currentUserIndex = this.getCurrentUserHierarchyIndex(item);
        return currentUserIndex && hierarchyIndex < currentUserIndex;
    }

    isFinalPreviousHierarchyRow(item, soa) {
        return this.isPreviousHierarchyRow(item, soa.hierarchyIndex) &&
            soa.approverId === item.finalDiscountApproverId;
    }

    isSkipCommentEnabled(item, soa) {
        return this.skipSoaRestrictions &&
            item.skipEditableCommentFields &&
            item.skipEditableCommentFields[soa.commentsField] === true;
    }

    getCurrentUserHierarchyIndex(item) {
        if (item.bcheck1 === false) {
            return 1;
        }
        if (item.bcheck2 === false) {
            return 2;
        }
        if (item.bcheck5 === false) {
            return 3;
        }
        if (item.bcheck3 === false) {
            return 4;
        }
        if (item.bcheck4 === false) {
            return 5;
        }
        return null;
    }

    handleSkipSoaRestrictions() {
        this.skipSoaRestrictions = true;
        this.quotes = (this.quotes || []).map(quote => {
            const quoteLineItems = (quote.quoteLineItems || []).map(item => ({
                ...item,
                skipSoaRestrictions: this.skipSoaRestrictions,
                skipEditableCommentFields: {
                    ...(item.skipEditableCommentFields || {}),
                    ...this.getSkipEditableCommentFields(item)
                }
            }));
            return {
                ...quote,
                quoteLineItems,
                displayRows: this.buildDisplayRows(quoteLineItems)
            };
        });
    }

    getSkipEditableCommentFields(item) {
        const editableFields = {};
        this.getSoaLevels(item).forEach(soa => {
            if (this.isPreviousHierarchyRow(item, soa.hierarchyIndex) && !this.hasValue(soa.commentsValue)) {
                editableFields[soa.commentsField] = true;
            }
        });
        return editableFields;
    }


    handleLineItemChanges(event) {
        const field = event.target.dataset.field;
        const lineItemId = event.target.dataset.id;
        const parentId = event.target.dataset.parent;
        const value = event.target.value;
        const stageField = event.target.dataset.stageField;

        let specificQuote = this.quotes.find(quote => quote.quoteId == parentId);

        let specificQuoteLineItem = specificQuote.quoteLineItems.find(quoteLineItem => quoteLineItem.quoteLineItemId == lineItemId);

        specificQuoteLineItem[field] = value;
        if (field === 'approvalStatus' && stageField) {
            specificQuoteLineItem.currentStageField = stageField;
            this.setStageStatusValue(specificQuoteLineItem, stageField, value);
        }
        specificQuoteLineItem.skipSoaRestrictions = this.skipSoaRestrictions;
        specificQuoteLineItem['updated'] = true;
        specificQuote['updated'] = true;
        specificQuote.displayRows = this.buildDisplayRows(specificQuote.quoteLineItems);
        this.quotes = [...this.quotes];
    }

    setStageStatusValue(lineItem, stageField, value) {
        if (stageField === 'Sales_Manager_Status__c') {
            lineItem.salesManagerStatus = value;
        } else if (stageField === 'Country_Continent_Sales_H_LOB_Status__c') {
            lineItem.countryContinentSalesStatus = value;
        } else if (stageField === 'Global_Sales_Head_Status__c') {
            lineItem.globalSalesHeadStatus = value;
        } else if (stageField === 'Rotex_Board_Member_Status__c') {
            lineItem.rotexBoardMemberStatus = value;
        } else if (stageField === 'Managing_Director_Status__c') {
            lineItem.managingDirectorStatus = value;
        }
    }

    validateQuoteData() {
        if (!this.requiresNonFinalApproverComment()) {
            return true;
        }

        this.showToast('Error', 'Enter at least one comment before submitting.', 'error');
        return false;
    }

    requiresNonFinalApproverComment() {
        if (!this.quotes) {
            return false;
        }

        let hasCommentOnlyLine = false;
        let hasCurrentUserComment = false;

        for (let quote of this.quotes) {
            for (let item of quote.quoteLineItems || []) {
                const requiredCommentFields = this.getRequiredCommentFields(item);
                if (!requiredCommentFields.length) {
                    continue;
                }

                hasCommentOnlyLine = true;
                if (requiredCommentFields.some(fieldName => this.hasValue(item[fieldName]))) {
                    hasCurrentUserComment = true;
                    break;
                }
            }

            if (hasCurrentUserComment) {
                break;
            }
        }

        return hasCommentOnlyLine && !hasCurrentUserComment;
    }

    getRequiredCommentFields(item) {
        const requiredFields = [];
        const currentUserComment = this.getCurrentUserComment(item);

        if (currentUserComment && !item.isFinalDiscountApprover && item.isEditable) {
            requiredFields.push(currentUserComment.fieldName);
        }

        Object.keys(item.skipEditableCommentFields || {}).forEach(fieldName => {
            if (item.skipEditableCommentFields[fieldName] === true) {
                requiredFields.push(fieldName);
            }
        });

        return requiredFields;
    }

    getCurrentUserComment(item) {
        if (item.bcheck1 === false) {
            return { fieldName: 'Sales_Manager_Comments' };
        }

        if (item.bcheck2 === false) {
            return { fieldName: 'Country_Continent_Sales_LOB_Comments' };
        }

        if (item.bcheck3 === false) {
            return { fieldName: 'Rotex_Board_Member_Comments' };
        }

        if (item.bcheck4 === false) {
            return { fieldName: 'Managing_Director_Comments' };
        }

        if (item.bcheck5 === false) {
            return { fieldName: 'Global_Sales_Head_Comments' };
        }

        return null;
    }

    hasValue(value) {
        return value !== undefined && value !== null && String(value).trim() !== '';
    }


    saveChanges() {
        this.isSaveDisabled = true;
        let temp = false;
        temp = this.validateQuoteData();
        
        console.log('Final Quote List', JSON.stringify(this.quotes));

    setTimeout(() => {
        if(temp){
            updateQuoteLineItem({quotationListStringObject: JSON.stringify(this.quotes)}).then((result) => {
                if (result == 'Success') {
                    this.showToast('Success', 'Quotation Line Items updated successfully', 'success');

                    setTimeout(()=>{
                        window.location.reload();
                    }, 1500)
                } else {
                    this.showToast('Error', result, 'error');
                }
            }).catch((error)=>{
                this.isSaveDisabled = false;
                this.showToast('Error', error.body.message, 'error');
            })
        } else {
            this.isSaveDisabled = false; // ← ADD THIS
        }
    }, 1000); 

    }

    redirectToHome() {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'home'
            }
        });
    }

    showToast(title, msg, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: msg,
            variant: variant
        });
        this.dispatchEvent(evt);
    }

}
