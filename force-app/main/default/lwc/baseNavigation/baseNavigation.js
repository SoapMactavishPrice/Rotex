import { LightningElement, api, track, wire } from 'lwc';

import USER_ID from '@salesforce/user/Id';

import { getRecord } from 'lightning/uiRecordApi';

import NAME_FIELD from '@salesforce/schema/User.Name';
import ACCOUNT_NAME_FIELD from '@salesforce/schema/User.Contact.Account.Name';

import getMenuItems
    from '@salesforce/apex/RotexNavigationController.getMenuItems';

import logo
    from '@salesforce/resourceUrl/RotexLogo';
import {
    NavigationMixin
} from 'lightning/navigation';

import basePath
from '@salesforce/community/basePath';

export default class BaseNavigation
extends NavigationMixin(
    LightningElement
) {

    @api menuName;

    logoUrl = logo;

    userId = USER_ID;

    @track menuItems = [];

    @track activeItemId;

    @track currentUserName = '';

    @track currentUserInitials = '';

    @track currentAccountName = '';

    @track dealerCode = '';

    error;

    get isNavReady() {

        return this.menuItems.length > 0;
    }

    get processedMenuItems() {

        return this.menuItems;
    }

    @wire(getRecord, {
        recordId: '$userId',
        fields: [NAME_FIELD, ACCOUNT_NAME_FIELD]
    })
    wiredUser({ error, data }) {

        if (data) {

            this.currentUserName =
                data.fields.Name.value;

            this.currentUserInitials =
                this.getInitials(
                    this.currentUserName
                );

            this.currentAccountName =
                data.fields.Contact?.value?.fields?.Account?.value?.fields?.Name?.value || '';

            this.dealerCode =
                this.userId.substring(0, 8);

        } else if (error) {

            console.error(
                'User Error:',
                error
            );
        }
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

    handleLogout() {

        window.location.href =
            basePath +
            '/secur/logout.jsp';
    }

    getInitials(name) {

        if (!name) {
            return '';
        }

        return name
            .split(' ')
            .map(
                word =>
                    word.charAt(0)
            )
            .join('')
            .toUpperCase()
            .substring(0, 2);
    }
}