import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';

import getQuoteProducts
    from '@salesforce/apex/QuoteProductViewController.getQuoteProducts';

export default class QuoteLineItemsReadOnlyLWC extends NavigationMixin(LightningElement) {

    @api recordId;

    @track products = [];

    @track isLoading = false;

    connectedCallback() {

        this.loadProducts();

    }

    loadProducts() {

        this.isLoading = true;

        getQuoteProducts({

            quoteId: this.recordId

        })

        .then(result => {

            this.products = this.prepareRows(result);

        })

        .catch(error => {

            console.error(error);

        })

        .finally(() => {

            this.isLoading = false;

        });

    }

    prepareRows(data) {

        return data.map(product => {

            const soaUsers = [];

            if(product.soaUsers){

                product.soaUsers.forEach((soa,index)=>{

                    soaUsers.push({

                        ...soa,

                        firstRow : index===0,

                        uniqueKey :
                            product.quoteLineItemId + '_' + index,

                        statusClass :
                            this.getStatusClass(soa.status),

                        dateTimeString :
                            this.formatDateTime(
                                soa.dateTimeData
                            )

                    });

                });

            }

            return{

                ...product,

                rowSpan :
                    soaUsers.length>0 ? soaUsers.length : 1,

                listPrice :
                    this.formatCurrency(product.listPrice),

                salesPrice :
                    this.formatCurrency(product.salesPrice),

                quantity :
                    this.formatNumber(product.quantity),

                discountSAP :
                    this.formatNumber(product.discountSAP),

                previousDiscount :
                    this.formatNumber(product.previousDiscount),

                discount :
                    this.formatNumber(product.discount),

                soaUsers

            };

        });

    }

    formatCurrency(value){

        if(value===null || value===undefined){

            return '';

        }

        return Number(value).toLocaleString(

            'en-IN',

            {

                minimumFractionDigits:2,

                maximumFractionDigits:2

            }

        );

    }

    formatNumber(value){

        if(value===null || value===undefined){

            return '';

        }

        return Number(value).toLocaleString(

            'en-IN',

            {

                maximumFractionDigits:2

            }

        );

    }

    formatDateTime(value){

        if(!value){

            return '';

        }

        return new Intl.DateTimeFormat(

            'en-GB',

            {

                day:'2-digit',

                month:'2-digit',

                year:'numeric',

                hour:'2-digit',

                minute:'2-digit'

            }

        ).format(new Date(value));

    }

    getStatusClass(status){

        if(!status){

            return 'status-default';

        }

        switch(status.toLowerCase()){

            case 'approved':

                return 'status-approved';

            case 'rejected':

                return 'status-rejected';

            case 'submitted':

                return 'status-submitted';

            case 'commented':

                return 'status-commented';

            default:

                return 'status-default';

        }

    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Quote',
                actionName: 'view'
            }
        });

    }

    handleViewPDF() {

        this[NavigationMixin.GenerateUrl]({
            type: 'standard__webPage',
            attributes: {
                url: '/apex/ViewQuotation?id=' + this.recordId
            }
        }).then(url => {
            window.open(url, '_blank');
        });

    }

    handleDownloadPDF() {

        const url =
            '/apex/ViewQuotation?id=' + this.recordId +
            '&download=true';

        window.open(url, '_blank');
    }

}