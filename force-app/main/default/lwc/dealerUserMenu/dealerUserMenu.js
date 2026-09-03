import { LightningElement, track, wire } from 'lwc';
import USER_ID from '@salesforce/user/Id';
import { getRecord, getFieldValue, getRecordNotifyChange } from 'lightning/uiRecordApi';
import NAME_FIELD from '@salesforce/schema/User.Name';
import CONTACT_ID_FIELD from '@salesforce/schema/User.ContactId';
import CONTACT_NAME_FIELD from '@salesforce/schema/User.Contact.Name';
import CONTACT_FIRST_NAME_FIELD from '@salesforce/schema/User.Contact.FirstName';
import CONTACT_LAST_NAME_FIELD from '@salesforce/schema/User.Contact.LastName';
import CONTACT_TITLE_FIELD from '@salesforce/schema/User.Contact.Title';
import CONTACT_EMAIL_FIELD from '@salesforce/schema/User.Contact.Email';
import CONTACT_MOBILE_FIELD from '@salesforce/schema/User.Contact.MobilePhone';
import CONTACT_STREET_FIELD from '@salesforce/schema/User.Contact.MailingStreet';
import CONTACT_CITY_FIELD from '@salesforce/schema/User.Contact.MailingCity';
import CONTACT_STATE_FIELD from '@salesforce/schema/User.Contact.MailingState';
import CONTACT_POSTAL_FIELD from '@salesforce/schema/User.Contact.MailingPostalCode';
import CONTACT_COUNTRY_FIELD from '@salesforce/schema/User.Contact.MailingCountry';
import ACCOUNT_NAME_FIELD from '@salesforce/schema/User.Contact.Account.Name';
import basePath from '@salesforce/community/basePath';
import userManualUrl from '@salesforce/resourceUrl/User_manual';
import getUnreadNotifications from '@salesforce/apex/DealerNotificationService.getUnreadNotifications';
import markAllAsReadApex from '@salesforce/apex/DealerNotificationService.markAllAsRead';
import markAsReadApex from '@salesforce/apex/DealerNotificationService.markAsRead';
import getMyProfilePhoto from '@salesforce/apex/DealerUserProfileController.getMyProfilePhoto';
import saveMyProfilePhoto from '@salesforce/apex/DealerUserProfileController.saveMyProfilePhoto';

const USER_FIELDS = [
    NAME_FIELD,
    CONTACT_ID_FIELD,
    CONTACT_NAME_FIELD,
    CONTACT_FIRST_NAME_FIELD,
    CONTACT_LAST_NAME_FIELD,
    CONTACT_TITLE_FIELD,
    CONTACT_EMAIL_FIELD,
    CONTACT_MOBILE_FIELD,
    CONTACT_STREET_FIELD,
    CONTACT_CITY_FIELD,
    CONTACT_STATE_FIELD,
    CONTACT_POSTAL_FIELD,
    CONTACT_COUNTRY_FIELD,
    ACCOUNT_NAME_FIELD
];

export default class DealerUserMenu extends LightningElement {
    userId = USER_ID;
    contactId = null;

    @track currentUserName = '';
    @track currentUserInitials = '';
    @track currentAccountName = '';
    @track isUserMenuOpen = false;
    @track isNotificationMenuOpen = false;
    @track showProfileDetail = false;

    @track profileFirstName = '';
    @track profileLastName = '';
    @track profileDesignation = '';
    @track profileEmail = '';
    @track profileMobile = '';
    @track profileAddress = '';

    @track profilePhotoUrl = '';
    @track hasProfilePhoto = false;
    @track photoError = '';
    @track isPhotoSaving = false;
    @track pendingPhotoName = '';
    pendingPhotoBase64 = null;

    @track notifications = [];

    fetchNotifications() {
        getUnreadNotifications()
            .then((result) => {
                if (result) {
                    const data = JSON.parse(result);
                    if (data && data.notifications) {
                        this.notifications = data.notifications.map(n => {
                            let title = 'Notification';
                            let message = n.messageBody || '';
                            if (n.payload && n.payload.messageTitle) {
                                title = n.payload.messageTitle;
                            }

                            let iconStyle = 'background: #0070d2;';
                            let isTask = false;
                            let isMeeting = false;
                            let isApproval = false;
                            let isLead = false;
                            let isCustomer = false;
                            let isQuote = false;
                            let isOrder = false;
                            let isInvoice = false;
                            let isInventory = false;
                            const titleLower = (title || '').toLowerCase();

                            if (titleLower.includes('lead')) {
                                isLead = true;
                                iconStyle = 'background: #f28b00;';
                            } else if (titleLower.includes('customer')) {
                                isCustomer = true;
                                iconStyle = 'background: #0070d2;';
                            } else if (
                                titleLower.includes('minimum stock') ||
                                titleLower.includes('stock level')
                            ) {
                                isInventory = true;
                                iconStyle = 'background: #f57c00;';
                                message = this.boldQuotedValue(message);
                            } else if (titleLower.includes('mta quote') || titleLower.includes('quote')) {
                                isQuote = true;
                                if (
                                    titleLower.includes('closed lost') ||
                                    titleLower.includes('scrap')
                                ) {
                                    iconStyle = 'background: #d32f2f;';
                                } else if (
                                    titleLower.includes('closed won') ||
                                    titleLower.includes('mta quote generated')
                                ) {
                                    iconStyle = 'background: #2e7d32;';
                                } else {
                                    iconStyle = 'background: #4caf50;';
                                }
                                message = this.boldQuotedValue(message);
                            } else if (titleLower.includes('order')) {
                                isOrder = true;
                                iconStyle = 'background: #00bcd4;';
                            } else if (titleLower.includes('invoice')) {
                                isInvoice = true;
                                iconStyle = 'background: #ff9800;';
                            } else if (titleLower.includes('task')) {
                                isTask = true;
                                iconStyle = 'background: #4caf50;';
                            } else if (titleLower.includes('event') || titleLower.includes('meeting')) {
                                isMeeting = true;
                                iconStyle = 'background: #ba68c8;';
                            } else {
                                isTask = true;
                            }

                            let timeStr = '';
                            if (n.lastModifiedDate) {
                                const d = new Date(n.lastModifiedDate);
                                timeStr = d.toLocaleString();
                            }

                            return {
                                id: n.id,
                                title: title,
                                titleClass: this.getNotifTitleClass(title),
                                message: message,
                                time: timeStr,
                                isRead: n.read,
                                isTask: isTask,
                                isMeeting: isMeeting,
                                isApproval: isApproval,
                                isLead: isLead,
                                isCustomer: isCustomer,
                                isQuote: isQuote,
                                isOrder: isOrder,
                                isInvoice: isInvoice,
                                isInventory: isInventory,
                                iconStyle: iconStyle,
                                targetRecordId: n.targetRecordId || null
                            };
                        });
                    }
                }
            })
            .catch((error) => {
                console.error('Error fetching notifications', error);
            });
    }

    get unreadCount() {
        return this.notifications.filter(n => !n.isRead).length;
    }

    getNotifTitleClass(title) {
        const titleLower = (title || '').toLowerCase();
        if (
            titleLower.includes('closed won') ||
            titleLower.includes('mta quote generated')
        ) {
            return 'notif-title notif-title--success';
        }
        if (titleLower.includes('closed lost') || titleLower.includes('scrap')) {
            return 'notif-title notif-title--danger';
        }
        if (
            titleLower.includes('minimum stock') ||
            titleLower.includes('stock level')
        ) {
            return 'notif-title notif-title--warning';
        }
        return 'notif-title';
    }

    boldQuotedValue(message) {
        if (!message || message.includes('<b>"') || message.includes('"<b>')) {
            return message;
        }
        return message.replace(/"([^"]+)"/, '"<b>$1</b>"');
    }

    get hasUnreadNotifications() {
        return this.unreadCount > 0;
    }

    get formattedNotifications() {
        return this.notifications.map(n => ({
            ...n,
            containerClass: n.isRead
                ? 'notif-item read'
                : 'notif-item unread'
        }));
    }

    get firstNameDisplay() {
        return this.displayOrNotSet(this.profileFirstName);
    }

    get lastNameDisplay() {
        return this.displayOrNotSet(this.profileLastName);
    }

    get designationDisplay() {
        return this.displayOrNotSet(this.profileDesignation);
    }

    get accountDisplay() {
        return this.displayOrNotSet(this.currentAccountName);
    }

    get emailDisplay() {
        return this.displayOrNotSet(this.profileEmail);
    }

    get mobileDisplay() {
        return this.displayOrNotSet(this.profileMobile);
    }

    get addressDisplay() {
        return this.displayOrNotSet(this.profileAddress);
    }

    get firstNameClass() {
        return this.valueClass(this.profileFirstName);
    }

    get lastNameClass() {
        return this.valueClass(this.profileLastName);
    }

    get designationClass() {
        return this.valueClass(this.profileDesignation);
    }

    get accountClass() {
        return this.valueClass(this.currentAccountName);
    }

    get emailClass() {
        return this.valueClass(this.profileEmail);
    }

    get mobileClass() {
        return this.valueClass(this.profileMobile);
    }

    get addressClass() {
        return this.valueClass(this.profileAddress);
    }

    displayOrNotSet(value) {
        return value && String(value).trim() ? value : 'Not set';
    }

    valueClass(value) {
        return value && String(value).trim()
            ? 'info-row-value'
            : 'info-row-value value-empty';
    }

    formatAddress(street, city, state, postal, country) {
        return [street, city, state, postal, country]
            .map((part) => (part || '').trim())
            .filter(Boolean)
            .join(', ');
    }

    _boundDocClick;

    connectedCallback() {
        this._boundDocClick = () => this.handleDocumentClick();
        this._boundRefreshProfile = () => {
            if (this.showProfileDetail && document.visibilityState !== 'hidden') {
                this.refreshUserProfile();
            }
        };
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => {
            document.addEventListener('click', this._boundDocClick);
        }, 0);
        window.addEventListener('focus', this._boundRefreshProfile);
        document.addEventListener('visibilitychange', this._boundRefreshProfile);
        this.fetchNotifications();
        this.loadProfilePhoto();
    }

    disconnectedCallback() {
        if (this._boundDocClick) {
            document.removeEventListener('click', this._boundDocClick);
        }
        if (this._boundRefreshProfile) {
            window.removeEventListener('focus', this._boundRefreshProfile);
            document.removeEventListener('visibilitychange', this._boundRefreshProfile);
        }
    }

    get addProfileButtonLabel() {
        return this.hasProfilePhoto || this.pendingPhotoBase64 ? 'Change Photo' : 'Add Profile';
    }

    get savePhotoButtonLabel() {
        return this.isPhotoSaving ? 'Saving…' : 'Save';
    }

    get showSavePhotoButton() {
        return !!this.pendingPhotoBase64 && !this.isPhotoSaving;
    }

    /** Circle fill via background-image — avoids Experience Cloud img sizing issues. */
    get profilePhotoBgStyle() {
        if (!this.hasProfilePhoto || !this.profilePhotoUrl) {
            return '';
        }
        const url = String(this.profilePhotoUrl).replace(/\\/g, '\\\\').replace(/"/g, '\\"');
        return `background-image:url("${url}");background-size:contain;background-position:center;background-repeat:no-repeat;`;
    }

    get profilePhotoRingClass() {
        return this.hasProfilePhoto
            ? 'profile-photo-ring profile-photo-ring--has-photo'
            : 'profile-photo-ring';
    }

    photoUrlFromVersionId(versionId) {
        if (!versionId) {
            return '';
        }
        // Direct File download endpoint works in Experience Cloud
        return '/sfc/servlet.shepherd/version/download/' + versionId;
    }

    async loadProfilePhoto() {
        try {
            const info = await getMyProfilePhoto();
            if (info && info.hasPhoto && info.versionId) {
                this.profilePhotoUrl = this.photoUrlFromVersionId(info.versionId);
                this.hasProfilePhoto = true;
            } else {
                this.profilePhotoUrl = '';
                this.hasProfilePhoto = false;
            }
        } catch (e) {
            console.error('Error loading profile photo', e);
        }
    }

    handleAddProfileClick(event) {
        event.stopPropagation();
        this.photoError = '';
        const input = this.template.querySelector('.profile-file-input');
        if (input) {
            input.click();
        }
    }

    handlePhotoSelected(event) {
        event.stopPropagation();
        this.photoError = '';
        const file = event.target.files && event.target.files[0];
        if (!file) {
            return;
        }
        if (!file.type || !file.type.startsWith('image/')) {
            this.photoError = 'Please choose an image file.';
            return;
        }
        if (file.size > 3 * 1024 * 1024) {
            this.photoError = 'Image must be under 3 MB.';
            return;
        }

        const reader = new FileReader();
        reader.onload = () => {
            this.normalizePhotoDataUrl(String(reader.result || ''), file.name)
                .then((normalized) => {
                    this.pendingPhotoBase64 = normalized.base64;
                    this.pendingPhotoName = normalized.fileName;
                    this.profilePhotoUrl = normalized.dataUrl;
                    this.hasProfilePhoto = true;
                })
                .catch(() => {
                    this.photoError = 'Could not process the selected image.';
                });
        };
        reader.onerror = () => {
            this.photoError = 'Could not read the selected image.';
        };
        reader.readAsDataURL(file);
    }

    /**
     * Scale large images down so they fit cleanly in the avatar circle.
     * Keeps full image visible (not a zoomed crop of a huge photo).
     */
    normalizePhotoDataUrl(dataUrl, originalName) {
        return new Promise((resolve, reject) => {
            if (!dataUrl) {
                reject(new Error('empty'));
                return;
            }
            const img = new Image();
            img.onload = () => {
                try {
                    const MAX = 512;
                    let w = img.naturalWidth || img.width;
                    let h = img.naturalHeight || img.height;
                    if (!w || !h) {
                        const base64 = dataUrl.includes(',') ? dataUrl.split(',')[1] : dataUrl;
                        resolve({
                            dataUrl,
                            base64,
                            fileName: this.ensureImageFileName(originalName)
                        });
                        return;
                    }
                    if (w > MAX || h > MAX) {
                        if (w >= h) {
                            h = Math.round((h * MAX) / w);
                            w = MAX;
                        } else {
                            w = Math.round((w * MAX) / h);
                            h = MAX;
                        }
                    }
                    const canvas = document.createElement('canvas');
                    canvas.width = w;
                    canvas.height = h;
                    const ctx = canvas.getContext('2d');
                    ctx.drawImage(img, 0, 0, w, h);
                    const out = canvas.toDataURL('image/jpeg', 0.9);
                    resolve({
                        dataUrl: out,
                        base64: out.split(',')[1],
                        fileName: this.ensureImageFileName(originalName, '.jpg')
                    });
                } catch (e) {
                    reject(e);
                }
            };
            img.onerror = () => reject(new Error('image load'));
            img.src = dataUrl;
        });
    }

    ensureImageFileName(name, forceExt) {
        const base = (name && String(name).trim()) || 'profile.jpg';
        if (forceExt) {
            const withoutExt = base.replace(/\.[^.]+$/, '');
            return withoutExt + forceExt;
        }
        if (/\.(png|jpe?g|gif|webp|bmp)$/i.test(base)) {
            return base;
        }
        return base + '.jpg';
    }

    async handleSaveProfilePhoto(event) {
        event.stopPropagation();
        if (!this.pendingPhotoBase64) {
            return;
        }
        this.isPhotoSaving = true;
        this.photoError = '';
        try {
            const info = await saveMyProfilePhoto({
                fileName: this.pendingPhotoName || 'profile.jpg',
                base64Data: this.pendingPhotoBase64
            });
            this.pendingPhotoBase64 = null;
            this.pendingPhotoName = '';
            if (info && info.versionId) {
                // Cache-bust so the new image is shown
                this.profilePhotoUrl =
                    this.photoUrlFromVersionId(info.versionId) + '?t=' + Date.now();
                this.hasProfilePhoto = true;
            } else {
                await this.loadProfilePhoto();
            }
            const input = this.template.querySelector('.profile-file-input');
            if (input) {
                input.value = '';
            }
        } catch (e) {
            this.photoError = this.extractProfileError(e);
        } finally {
            this.isPhotoSaving = false;
        }
    }

    extractProfileError(error) {
        if (!error) {
            return 'Unable to save photo.';
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        if (Array.isArray(error.body) && error.body[0] && error.body[0].message) {
            return error.body[0].message;
        }
        return error.message || 'Unable to save photo.';
    }

    get chevronClass() {
        return this.isUserMenuOpen
            ? 'user-menu-chevron user-menu-chevron-open'
            : 'user-menu-chevron';
    }

    @wire(getRecord, {
        recordId: '$userId',
        fields: USER_FIELDS
    })
    wiredUser({ error, data }) {
        if (data) {
            this.applyUserRecord(data);
        } else if (error) {
            // keep empty labels
        }
    }

    applyUserRecord(data) {
        this.contactId = getFieldValue(data, CONTACT_ID_FIELD) || null;
        this.currentUserName =
            getFieldValue(data, CONTACT_NAME_FIELD) ||
            getFieldValue(data, NAME_FIELD) ||
            '';
        this.currentUserInitials = this.getInitials(this.currentUserName);
        this.currentAccountName = getFieldValue(data, ACCOUNT_NAME_FIELD) || '';
        this.profileFirstName = getFieldValue(data, CONTACT_FIRST_NAME_FIELD) || '';
        this.profileLastName = getFieldValue(data, CONTACT_LAST_NAME_FIELD) || '';
        this.profileDesignation = getFieldValue(data, CONTACT_TITLE_FIELD) || '';
        this.profileEmail = getFieldValue(data, CONTACT_EMAIL_FIELD) || '';
        this.profileMobile = getFieldValue(data, CONTACT_MOBILE_FIELD) || '';
        this.profileAddress = this.formatAddress(
            getFieldValue(data, CONTACT_STREET_FIELD),
            getFieldValue(data, CONTACT_CITY_FIELD),
            getFieldValue(data, CONTACT_STATE_FIELD),
            getFieldValue(data, CONTACT_POSTAL_FIELD),
            getFieldValue(data, CONTACT_COUNTRY_FIELD)
        );
    }

    refreshUserProfile() {
        const records = [];
        if (this.userId) {
            records.push({ recordId: this.userId });
        }
        if (this.contactId) {
            records.push({ recordId: this.contactId });
        }
        if (records.length) {
            getRecordNotifyChange(records);
        }
    }

    get accountHeaderDisplay() {
        return (this.currentAccountName || '').toUpperCase();
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    toggleUserMenu(event) {
        event.stopPropagation();
        this.isUserMenuOpen = !this.isUserMenuOpen;
        if (this.isUserMenuOpen) {
            this.isNotificationMenuOpen = false;
        }
    }

    toggleNotificationMenu(event) {
        event.stopPropagation();
        this.isNotificationMenuOpen = !this.isNotificationMenuOpen;
        if (this.isNotificationMenuOpen) {
            this.isUserMenuOpen = false;
            this.fetchNotifications(); // Refresh when opening
        }
    }

    handleOpenUserManual(event) {
        if (event) {
            event.stopPropagation();
        }
        window.open(userManualUrl, '_blank', 'noopener,noreferrer');
    }

    markAllAsRead(event) {
        event.stopPropagation();
        markAllAsReadApex()
            .then(() => {
                this.notifications = this.notifications.map(n => ({ ...n, isRead: true }));
            })
            .catch(error => {
                console.error('Error marking as read', error);
            });
    }

    async handleNotificationClick(event) {
        event.stopPropagation();
        const notificationId = event.currentTarget.dataset.id;
        const targetId = event.currentTarget.dataset.targetId;
        const isLead = event.currentTarget.dataset.isLead === 'true';
        const isCustomer = event.currentTarget.dataset.isCustomer === 'true';
        const isQuote = event.currentTarget.dataset.isQuote === 'true';
        const isOrder = event.currentTarget.dataset.isOrder === 'true';
        const isInvoice = event.currentTarget.dataset.isInvoice === 'true';
        const isInventory = event.currentTarget.dataset.isInventory === 'true';
        const isTask = event.currentTarget.dataset.isTask === 'true';
        const isMeeting = event.currentTarget.dataset.isMeeting === 'true';

        if (notificationId) {
            this.notifications = this.notifications.map((n) =>
                n.id === notificationId ? { ...n, isRead: true } : n
            );
            try {
                await markAsReadApex({ notificationId });
            } catch (error) {
                console.error('Error marking notification as read', error);
            }
        }

        this.isNotificationMenuOpen = false;

        if (isLead && targetId) {
            try {
                sessionStorage.setItem('portalOpenLeadId', targetId);
            } catch (e) {
                /* ignore storage errors */
            }
            const path = (basePath || '').replace(/\/$/, '');
            window.location.href = path + '/lead';
        } else if (isCustomer && targetId) {
            try {
                sessionStorage.setItem('portalOpenCustomerId', targetId);
            } catch (e) {
                /* ignore storage errors */
            }
            const path = (basePath || '').replace(/\/$/, '');
            window.location.href = path + '/customer';
        } else if (isInventory && targetId) {
            try {
                sessionStorage.setItem('portalOpenInventoryId', targetId);
            } catch (e) {
                /* ignore storage errors */
            }
            const path = (basePath || '').replace(/\/$/, '');
            window.location.href = path + '/inventory';
        } else if (isQuote && targetId) {
            try {
                sessionStorage.setItem('portalOpenQuoteId', targetId);
            } catch (e) {
                /* ignore storage errors */
            }
            const path = (basePath || '').replace(/\/$/, '');
            window.location.href = path + '/Quotation';
        } else if (isOrder && targetId) {
            try {
                sessionStorage.setItem('portalOpenOrderId', targetId);
            } catch (e) {
                /* ignore storage errors */
            }
            const path = (basePath || '').replace(/\/$/, '');
            window.location.href = path + '/order';
        } else if (isInvoice && targetId) {
            try {
                sessionStorage.setItem('portalOpenInvoiceId', targetId);
            } catch (e) {
                /* ignore storage errors */
            }
            const path = (basePath || '').replace(/\/$/, '');
            window.location.href = path + '/invoice'; // Using /invoice as requested
        } else if ((isTask || isMeeting) && targetId) {
            try {
                sessionStorage.setItem('portalOpenActivityId', targetId);
            } catch (e) {
                /* ignore storage errors */
            }
            const path = (basePath || '').replace(/\/$/, '');
            window.location.href = path + '/activity';
        }
    }

    handleDocumentClick() {
        if (this.isUserMenuOpen) {
            this.isUserMenuOpen = false;
        }
        if (this.isNotificationMenuOpen) {
            this.isNotificationMenuOpen = false;
        }
    }

    handleMyProfile() {
        this.isUserMenuOpen = false;
        this.isNotificationMenuOpen = false;
        this.showProfileDetail = true;
        this.refreshUserProfile();
        this.loadProfilePhoto();
    }

    closeProfileDetail() {
        this.showProfileDetail = false;
        this.pendingPhotoBase64 = null;
        this.pendingPhotoName = '';
        this.photoError = '';
        // Reload saved photo if user discarded a local preview
        this.loadProfilePhoto();
    }

    handleLogout() {
        this.isUserMenuOpen = false;
        window.location.href = basePath + '/secur/logout.jsp';
    }

    getInitials(name) {
        if (!name) {
            return '';
        }
        return name
            .split(' ')
            .map((word) => word.charAt(0))
            .join('')
            .toUpperCase()
            .substring(0, 2);
    }
}