import { LightningElement, api, track, wire } from 'lwc';

import getMenuItems
    from '@salesforce/apex/RotexNavigationController.getMenuItems';

import logo
    from '@salesforce/resourceUrl/RotexLogo';
import {
    NavigationMixin
} from 'lightning/navigation';

export default class BaseNavigation
extends NavigationMixin(
    LightningElement
) {

    @api menuName;

    logoUrl = logo;

    @track menuItems = [];

    @track activeItemId;

    error;

    get isNavReady() {

        return this.menuItems.length > 0;
    }

    get processedMenuItems() {

        return this.menuItems;
    }

    @wire(getMenuItems, {
        menuName: '$menuName'
    })
    wiredMenuItems({ error, data }) {

        if (data) {

            const uniqueItems = [];
            const addedLabels = new Set();

            data.forEach(item => {
                if (item.label !== 'Home' && !addedLabels.has(item.label)) {
                    addedLabels.add(item.label);

                    const label = (item.publicLabel || item.label || '').toLowerCase();

                    if (label === 'customer') {
                        uniqueItems.push({
                            ...item,
                            children: [
                                { id: item.id + '-pending', publicLabel: 'Pending Approval', status: 'Pending Approval' },
                                { id: item.id + '-approved', publicLabel: 'Approved', status: 'Approved' },
                                { id: item.id + '-rejected', publicLabel: 'Rejected', status: 'Rejected' }
                            ]
                        });
                    } else {
                        uniqueItems.push({ ...item });
                    }
                }
            });

            this.menuItems = uniqueItems;

            if (this.menuItems.length > 0) {
                this.activeItemId = this.menuItems[0].id;
            }

        } else if (error) {
            this.error = error;
            console.error('Menu Error:', error);
        }
    }

    handleItemSelected(event) {

        this.activeItemId =
            event.detail.item.id;
    }
}