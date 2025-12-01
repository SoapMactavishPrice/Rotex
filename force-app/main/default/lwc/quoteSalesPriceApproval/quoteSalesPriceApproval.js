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
                console.log('OUTPUT : ',JSON.stringify(result));
                this.quotes = result.map(q => {
                    const isHodUser = (q.hodUserId === this.userId);
                    return {
                        ...q,
                        isHodUser: isHodUser,
                        disableFields: !isHodUser // 👈 add this
                    };
                });
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
                this.redirectToHome();
                setTimeout(()=>{ window.location.reload(); }, 2500);
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