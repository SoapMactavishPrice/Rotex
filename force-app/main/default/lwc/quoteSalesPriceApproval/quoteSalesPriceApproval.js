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

    fetchQuotes() {
        getAllQuotations()
            .then(result => {
                this.quotes = result.map(q => {
                    const quoteRecordUrl = `/lightning/r/Quote/${q.quoteId}/view`;

                    const processedLineItems = (q.quoteLineItems || []).map(item => ({
                        ...item,
                        isFinalDiscountApprover: item.finalDiscountApproverId === this.userId,
                        isEditable: item.approvalStatus === 'Submitted'
                    }));

                    const displayRows = [];
                    processedLineItems.forEach(item => {
                        const soaLevels = [
                            {
                                label: 'SM', name: item.salesManagerName,
                                status: item.salesManagerStatus,
                                dateTime: item.salesManagerDateTime,
                                commentsField: 'Sales_Manager_Comments',
                                commentsValue: item.Sales_Manager_Comments,
                                isCurrentUserRow: !item.bcheck1
                            },
                            {
                                label: 'CH', name: item.countryContinentSalesName,
                                status: item.countryContinentSalesStatus,
                                dateTime: item.countryHeadDateTime,
                                commentsField: 'Country_Continent_Sales_LOB_Comments',
                                commentsValue: item.Country_Continent_Sales_LOB_Comments,
                                isCurrentUserRow: !item.bcheck2
                            },
                            {
                                label: 'GS', name: item.globalSalesHeadName,
                                status: item.globalSalesHeadStatus,
                                dateTime: item.globalSalesHeadDateTime,
                                commentsField: 'Global_Sales_Head_Comments',
                                commentsValue: item.Global_Sales_Head_Comments,
                                isCurrentUserRow: !item.bcheck5
                            },
                            {
                                label: 'BM', name: item.rotexBoardMemberName,
                                status: item.rotexBoardMemberStatus,
                                dateTime: item.rotexBoardMemberDateTime,
                                commentsField: 'Rotex_Board_Member_Comments',
                                commentsValue: item.Rotex_Board_Member_Comments,
                                isCurrentUserRow: !item.bcheck3
                            },
                            {
                                label: 'MD', name: item.managingDirectorName,
                                status: item.managingDirectorStatus,
                                dateTime: item.managingDirectorDateTime,
                                commentsField: 'Managing_Director_Comments',
                                commentsValue: item.Managing_Director_Comments,
                                isCurrentUserRow: !item.bcheck4
                            }
                        ];

                        soaLevels.forEach((soa, idx) => {
                            const formattedDateTime = soa.dateTime
                                ? new Date(soa.dateTime).toLocaleString('en-GB', {
                                    day: '2-digit', month: '2-digit', year: 'numeric',
                                    hour: '2-digit', minute: '2-digit'
                                })
                                : '';

                            displayRows.push({
                                key: `${item.quoteLineItemId}_${idx}`,
                                isFirstRow: idx === 0,
                                soaCount: soaLevels.length,
                                // Rowspan cells
                                productName: item.productName,
                                listPrice: item.listPrice,
                                quantity: item.quantity,
                                d1: item.d1,
                                d2: item.d2,
                                quoteLineItemId: item.quoteLineItemId,
                                parentId: item.parentId,
                                // Combobox binding
                                approvalStatus: item.approvalStatus,
                                isEditable: item.isEditable,
                                // SOA columns
                                soaDisplay: soa.name ? `${soa.label} - ${soa.name}` : '',
                                soaStatus: soa.status || '',
                                soaDateTime: formattedDateTime,
                                soaComments: soa.commentsValue || '',
                                soaCommentsField: soa.commentsField,
                                showStatusCombobox: item.isFinalDiscountApprover && soa.isCurrentUserRow && item.isEditable,
                                showStatusText: false,
                                showCommentInput: soa.isCurrentUserRow,
                                soaCommentsDisabled: !item.isEditable,
                                // Top border to visually separate QLI groups
                                rowStyle: idx === 0 ? 'border-top: 2px solid #c9c7c5;' : ''
                            });
                        });
                    });

                    return {
                        ...q,
                        quoteRecordUrl,
                        quoteLineItems: processedLineItems,
                        displayRows
                    };
                });
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
                this.redirectToHome();
                setTimeout(() => { window.location.reload(); }, 2500);
            });
    }


    handleLineItemChanges(event) {
        const field = event.target.dataset.field;
        const lineItemId = event.target.dataset.id;
        const parentId = event.target.dataset.parent;
        const value = event.target.value;

        let specificQuote = this.quotes.find(quote => quote.quoteId == parentId);

        let specificQuoteLineItem = specificQuote.quoteLineItems.find(quoteLineItem => quoteLineItem.quoteLineItemId == lineItemId);

        specificQuoteLineItem[field] = value;
        specificQuoteLineItem['updated'] = true;
        specificQuote['updated'] = true;
    }

validateQuoteData() {
    let isValid = true;

    outerLoop: // allows breaking both loops
    for (let quote of this.quotes) {
        for (let item of quote.quoteLineItems) {
            if (!item.updated) continue;
            if (item.approvalStatus === 'Approved') {
                if (item.bcheck1 === false && (!item.Sales_Manager_Comments || item.Sales_Manager_Comments.trim() === '')) {
                    // show error toast
                    this.showToast('Error', `Sales Manager Comments are required for product "${item.productName}"`, 'error');
                    
                    isValid = false;
                    break outerLoop; // stop checking other items or quotes
                }

                if (item.bcheck2 === false && (!item.Country_Continent_Sales_LOB_Comments || item.Country_Continent_Sales_LOB_Comments.trim() === '')) {
                    // show error toast
                    this.showToast('Error', `Country / Continent Sales / LOB Comments are required for product "${item.productName}"`, 'error');
                    
                    isValid = false;
                    break outerLoop; // stop checking other items or quotes
                }


                if (item.bcheck3 === false && (!item.Rotex_Board_Member_Comments || item.Rotex_Board_Member_Comments.trim() === '')) {
                    // show error toast
                    this.showToast('Error', `Rotex Board Member Comments are required for product "${item.productName}"`, 'error');
                    
                    isValid = false;
                    break outerLoop; // stop checking other items or quotes
                }

                if (item.bcheck4 === false && (!item.Managing_Director_Comments || item.Managing_Director_Comments.trim() === '')) {
                    // show error toast
                    this.showToast('Error', `Managing Director Comments are required for product "${item.productName}"`, 'error');
                    
                    isValid = false;
                    break outerLoop; // stop checking other items or quotes
                }

                 if (item.bcheck5 === false && (!item.Global_Sales_Head_Comments || item.Global_Sales_Head_Comments.trim() === '')) {
                    // show error toast
                    this.showToast('Error', `Global Sales Head Comments are required for product "${item.productName}"`, 'error');
                    
                    isValid = false;
                    break outerLoop; // stop checking other items or quotes
                }
            }
        }
    }

    return isValid;
}


    saveChanges() {
        this.isSaveDisabled = true;
        let temp =false;
        temp =  this.validateQuoteData(this.quotes);
        
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
