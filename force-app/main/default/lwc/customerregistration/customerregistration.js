import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDealerAccount from '@salesforce/apex/CustomerController.getDealerAccount';
import getCustomersByDealer from '@salesforce/apex/CustomerController.getCustomersByDealer';
import createCustomer from '@salesforce/apex/CustomerController.createCustomer';
import getStateDistrictByPincode from '@salesforce/apex/CustomerController.getStateDistrictByPincode';
import updateCustomer from '@salesforce/apex/CustomerController.updateCustomer';
import saveAttachment from '@salesforce/apex/CustomerController.saveAttachment';
import getAttachments from '@salesforce/apex/CustomerController.getAttachments';
import fetchGSTDetails from '@salesforce/apex/CustomerController.fetchGSTDetails';
import getCustomerContacts from '@salesforce/apex/CustomerController.getCustomerContacts';
import getShowSoTreeFlag from '@salesforce/apex/CustomerController.getShowSoTreeFlag';

export default class CustomerRegistration extends LightningElement {

    // ── Dealer context ────────────────────────────────────────────────────────
    @track dealerAccountId = null;
    @track dealerName = '';
    @track showSoTree = false;
    // ── List state ────────────────────────────────────────────────────────────
    @track customers = [];       // raw records from Apex
    @track searchTerm = '';

    // ── Detail state ─────────────────────────────────────────────────────────
    @track selectedCustomer = null;
    @track isEditMode = false;

    @track editingCustomerId = null;  // null = list view, object = detail view

    // ── Modal state ───────────────────────────────────────────────────────────
    @track isModalOpen = false;
    @track isSaving = false;
    @track showToast = false;
    @track toastMessage = '';
    @track gstVerified = false;
    @track gstMessage = '';
    /** Lock only fields that GST API actually returned */
    @track gstNameLocked = false;
    @track gstAddressLocked = false;
    @track gstPinLocked = false;
    /** Lock District/State only when pincode API populated that field */
    @track districtLocked = false;
    @track stateLocked = false;
    // ── Form model ────────────────────────────────────────────────────────────
    @track form = this._emptyForm();
    @track errors = {};
    @track contacts = [this._emptyContact()];
    @track contactErrors = {};

    // ── File attachments (client-side only until save) ────────────────────────
    @track attach = this._emptyAttach();
    @track showPreview = false;
    @track previewUrl = '';
    @track previewTitle = '';
    @track previewIsImage = false;
    @track previewIsPdf = false;
    @track expandedCustomers = {};
    @track expandedSOs = {};
    @track statusFilter = '';
    /** Business line tab filter — mirrors lead status tabs UI: All | ROTEX | Non ROTEX | BOTH */
    @track businessLineFilter = 'All';

    get gstClass() {
        return this.gstVerified
            ? 'gst-success'
            : 'gst-error';
    }

    get customerNameClass() {
        return this.gstNameLocked
            ? 'cm-input cm-input-readonly'
            : 'cm-input';
    }

    get addressClass() {
        return this.gstAddressLocked
            ? 'cm-textarea cm-textarea--small cm-input-readonly'
            : 'cm-textarea cm-textarea--small';
    }

    get pinCodeClass() {
        return this.gstPinLocked
            ? 'cm-input cm-input-readonly'
            : 'cm-input';
    }

    get districtClass() {
        return this.districtLocked
            ? 'cm-input cm-input-readonly'
            : 'cm-input';
    }

    get stateClass() {
        return this.stateLocked
            ? 'cm-input cm-input-readonly'
            : 'cm-input';
    }

    get contactsView() {
        const total = this.contacts.length;
        const lastKey = total ? this.contacts[total - 1].key : null;
        return this.contacts.map((c, i) => {
            const err = this.contactErrors[c.key] || {};
            return {
                ...c,
                indexLabel: String(i + 1),
                canRemove: total > 1,
                showAddButton: c.key === lastKey,
                errFirstName: err.firstName || '',
                errLastName: err.lastName || '',
                errDesignation: err.designation || '',
                errPhone: err.phone || '',
                errEmail: err.email || ''
            };
        });
    }

    _emptyContact(seed = {}) {
        return {
            key: `c-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
            contactId: seed.contactId || null,
            firstName: seed.firstName || '',
            lastName: seed.lastName || '',
            designation: seed.designation || '',
            phone: seed.phone || '',
            email: seed.email || ''
        };
    }

    _resetGstLocks() {
        this.gstNameLocked = false;
        this.gstAddressLocked = false;
        this.gstPinLocked = false;
    }

    /**
     * Apply Jamku GST payload onto the registration form (same path for type + Edit).
     */
    async _applyFetchedGstDetails(gstVal, details) {
        const tradeName = (details.tradeName || '').trim();
        const filledAddress = (
            details.registeredAddress ||
            details.address ||
            details.adr ||
            ''
        ).trim();
        const filledPin = (
            details.pincode ||
            details.pinCode ||
            ''
        ).trim();

        const missing = [];
        if (!tradeName) missing.push('name');
        if (!filledAddress) missing.push('address');
        if (!filledPin) missing.push('pincode');
        this.gstVerified = true;
        this.gstMessage = missing.length
            ? `GST Verified (enter ${missing.join(', ')} manually)`
            : 'GST Verified';

        this.gstNameLocked = !!tradeName;
        this.gstAddressLocked = !!filledAddress;
        this.gstPinLocked = false;

        this.form = {
            ...this.form,
            gstNo: gstVal,
            customerName: tradeName,
            address: filledAddress,
            pinCode: filledPin,
            district: filledPin ? this.form.district : '',
            state: filledPin ? this.form.state : ''
        };

        this._syncAddressTextarea();

        const e = { ...this.errors };
        if (tradeName) delete e.customerName;
        if (filledAddress) delete e.address;
        if (filledPin) delete e.pinCode;
        delete e.gstNo;
        this.errors = e;

        if (filledPin && String(filledPin).length === 6) {
            await this.populateStateDistrict(filledPin);
        } else {
            this.form = {
                ...this.form,
                district: '',
                state: ''
            };
            this._resetLocationLocks();
        }
    }

    /**
     * Fetch GST details and fill form fields.
     * @param {string} gstVal
     * @param {{ preserveOnFailure?: boolean }} options
     *        preserveOnFailure: on Edit, keep saved values if API fails so save is not blocked
     */
    async _fetchAndApplyGst(gstVal, options = {}) {
        const gst = (gstVal || '').trim().toUpperCase();
        if (gst.length !== 15) {
            return false;
        }
        try {
            const details = await fetchGSTDetails({ gstNo: gst });
            if (details && details.isValid) {
                await this._applyFetchedGstDetails(gst, details);
                return true;
            }
            this.gstVerified = options.preserveOnFailure === true;
            this.gstMessage = 'GST Number is not verified';
            this._resetGstLocks();
            return false;
        } catch (error) {
            this.gstVerified = options.preserveOnFailure === true;
            this.gstMessage = 'Unable to verify GST';
            this._resetGstLocks();
            return false;
        }
    }

    _resetLocationLocks() {
        this.districtLocked = false;
        this.stateLocked = false;
    }

    /**
     * Lock only fields that have a value (API fill or existing customer data).
     */
    _applyLocationLocks(state, district) {
        this.stateLocked = !!(state || '').trim();
        this.districtLocked = !!(district || '').trim();
    }

    _syncAddressTextarea() {
        // LWC does not always re-render native textarea text
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => {
            this._syncFormNativeControls();
        }, 0);
    }

    /**
     * Force native select/textarea/input values after edit prefill.
     * LWC often leaves <select>/<textarea> stale when only property bindings change.
     */
    _syncFormNativeControls() {
        const f = this.form || {};
        const setVal = (sel, value) => {
            const el = this.template.querySelector(sel);
            if (el && String(el.value) !== String(value || '')) {
                el.value = value == null ? '' : String(value);
            }
        };

        setVal('input[data-field="customerName"]', f.customerName);
        setVal('input[data-field="gstNo"]', f.gstNo);
        setVal('input[data-field="customerWebsite"]', f.customerWebsite);
        setVal('select[data-field="businessType"]', f.businessType);
        setVal('select[data-field="customerProfile"]', f.customerProfile);
        setVal('textarea[data-field="address"]', f.address);
        setVal('textarea[data-field="oemDetails"]', f.oemDetails);
        setVal('input[data-field="pinCode"]', f.pinCode);
        setVal('input[data-field="district"]', f.district);
        setVal('input[data-field="state"]', f.state);
        setVal('input[data-field="country"]', f.country);
        setVal('input[data-field="annualPotential"]', f.annualPotential);
        setVal('input[data-field="target"]', f.target);
        setVal('input[data-field="targetNonRotex"]', f.targetNonRotex);

        // Contact rows
        (this.contacts || []).forEach((c) => {
            ['firstName', 'lastName', 'designation', 'phone', 'email'].forEach((field) => {
                const el = this.template.querySelector(
                    `input[data-key="${c.key}"][data-field="${field}"]`
                );
                if (el) {
                    el.value = c[field] == null ? '' : String(c[field]);
                }
            });
        });
    }
    // ─────────────────────────────────────────────────────────────────────────
    // Lifecycle
    // ─────────────────────────────────────────────────────────────────────────
    connectedCallback() {
        this._applyStatusFromUrl();
        this._loadDealer();
        this._loadFeatureFlags();
    
        this._boundStatusHandler = this._handleStatusChange.bind(this);
        window.addEventListener('customerstatuschange', this._boundStatusHandler);
    }
    
    async _loadFeatureFlags() {
        try {
            this.showSoTree = await getShowSoTreeFlag();
        } catch (e) {
            this.showSoTree = false; // safe default if metadata fetch fails
        }
    }
    
    disconnectedCallback() {
        if (this._boundStatusHandler) {
            window.removeEventListener('customerstatuschange', this._boundStatusHandler);
        }
    }
    async _loadDealer() {
        try {
            const dealer = await getDealerAccount();
            this.dealerAccountId = dealer.Id;
            this.dealerName = dealer.Name;
            await this._loadCustomers();
        } catch (e) {
            this._showToast('Error loading dealer account: ' + this._errorMsg(e), true);
        }
    }

    async _loadCustomers() {
        try {
            const raw = await getCustomersByDealer({ dealerAccountId: this.dealerAccountId });
            // Apex returns { record, rejectionRemark, lastModifiedDate }
            this.customers = (raw || []).map(row => {
                const rec = row.record || row;
                const remark = row.rejectionRemark != null ? row.rejectionRemark : '';
                const lastMod = row.lastModifiedDate || rec.LastModifiedDate || null;
                return this._mapCustomer(rec, remark, lastMod);
            });
        } catch (e) {
            this._showToast('Error loading customers: ' + this._errorMsg(e), true);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Map Apex Account → UI object
    // rejectionRemark = CRM Reject Account Comments (approval history)
    // lastModifiedDate = latest related activity (quote/order/task/etc.)
    // ─────────────────────────────────────────────────────────────────────────
    _mapCustomer(c, rejectionRemark, lastModifiedDate) {
        const amount = c.Annual_Business_Potential__c;
        const status = c.Approval_Status__c || 'Pending Approval';
        const statusClass =
            status === 'Approved' ? 'cm-status cm-status--approved' :
                status === 'Rejected' ? 'cm-status cm-status--rejected' :
                    'cm-status cm-status--pending';
        const remark = (rejectionRemark || '').trim();
        return {
            id: c.Id,
            customerName: c.Customer_Name__c || c.Name || '—',
            gstNo: c.GST_No__c || '',
            timestamp: c.Timestamp__c,
            address: c.Street__c || '',
            businessType: c.Business_type__c || '',
            target: c.Target__c || '',
            targetNonRotex:
                c.Target_Non_Rotex__c != null && c.Target_Non_Rotex__c !== undefined
                    ? String(c.Target_Non_Rotex__c)
                    : '',
            // Raw picklist value for edit form (do not use display placeholder '—')
            customerProfile: c.Customer_Profile__c || '',
            customerProfileDisplay: c.Customer_Profile__c || '—',
            oemDetails: c.Additional_details_in_case_of_OEM__c || '',
            state: c.State__c || '',
            district: c.District__c || '',
            pinCode: c.Postal_Code__c || '',
            annualPotential: amount,
            annualPotentialFormatted: amount ? '₹ ' + Number(amount).toLocaleString('en-IN') : '—',
            customerWebsite: c.Website || '',
            contactFirstName: c.Contact_Person_Name__c || '',
            country: c.Country__c || '',
             contactLastName: c.Contact_Person_Last_Name__c || '',
            contactPhone: c.Contact_Person_Telephone_No__c || '',
            contactEmail: c.Contact_Person_Email_ID__c || '',
            contactDesignation: c.Contact_Person_Designation__c || '',
            dealerName: this.dealerName,
            channelPartnerName: c.Channel_Partner_Name__r ? c.Channel_Partner_Name__r.Name : '—',
            createdDate: this._fmtDate(c.CreatedDate),
            gstNoDisplay: c.GST_No__c || '—',
            timestampDisplay: c.Timestamp__c ? this._fmtDateTime(c.Timestamp__c) : '—',
            addressDisplay: c.Street__c || '—',
            businessTypeDisplay: c.Business_type__c || '—',
            targetDisplay: this._formatTargetDisplay(c.Business_type__c, c.Target__c, c.Target_Non_Rotex__c),
            targetRotexDisplay: c.Target__c || '—',
            targetNonRotexDisplay:
                c.Target_Non_Rotex__c != null && c.Target_Non_Rotex__c !== undefined
                    ? String(c.Target_Non_Rotex__c)
                    : '—',
            showTargetRotexDetail:
                c.Business_type__c === 'ROTEX' || c.Business_type__c === 'BOTH',
            showTargetNonRotexDetail:
                c.Business_type__c === 'Non ROTEX' || c.Business_type__c === 'BOTH',
            stateDisplay: c.State__c || '—',
            districtDisplay: c.District__c || '—',
            pinCodeDisplay: c.Postal_Code__c || '—',
            contactFirstNameDisplay: c.Contact_Person_Name__c || '—',
            countryDisplay: c.Country__c || '—',
            contactLastNameDisplay: c.Contact_Person_Last_Name__c || '—',
            contactPhoneDisplay: c.Contact_Person_Telephone_No__c || '—',
            contactEmailDisplay: c.Contact_Person_Email_ID__c || '—',
            contactDesignationDisplay: c.Contact_Person_Designation__c || '—',
            customerWebsiteDisplay: c.Website || '—',
            status,
            statusClass,
            rejectionRemark: remark,
            rejectionRemarkDisplay: remark || '—',
            isApproved: status === 'Approved',
            isRejected: status === 'Rejected',
            approvedDate: c.Approved_Date__c || null,
            approvedDateDisplay:
                status === 'Approved' && c.Approved_Date__c
                    ? this._fmtDate(c.Approved_Date__c)
                    : '—',
            rejectionDate: c.Rejection_date__c || null,
            rejectionDateDisplay:
                status === 'Rejected' && c.Rejection_date__c
                    ? this._fmtDate(c.Rejection_date__c)
                    : '—',
            lastModifiedDate: lastModifiedDate || c.LastModifiedDate || null,
            lastModifiedDisplay: this._fmtDate(lastModifiedDate || c.LastModifiedDate),
            attach: { purchaseOrder: false, latestEnquiry: false, bdPlan: false }
        };
    }
    _mapAttachments(files) {

        const result = {
            purchaseOrder: false,
            latestEnquiry: false,
            bdPlan: false
        };

        files.forEach(f => {

            const url =
                '/sfc/servlet.shepherd/version/download/' +
                f.LatestPublishedVersionId;
            const previewUrl =
                '/sfc/servlet.shepherd/document/download/' +
                f.Id;

            if (f.Title.startsWith('Latest_Purchase_Order')) {

                result.purchaseOrder = true;
                result.purchaseOrderPreview = previewUrl;
                result.purchaseOrderName = f.Title;

                result.purchaseOrderType =
                    f.FileExtension.toLowerCase();

                result.purchaseOrderIsImage =
                    ['PNG', 'JPG', 'JPEG', 'WEBP']
                        .includes(f.FileExtension.toUpperCase());

            }

            else if (f.Title.startsWith('Latest_Enquiry')) {

                result.latestEnquiry = true;
                result.latestEnquiryPreview = previewUrl;
                result.latestEnquiryName = f.Title;

                result.latestEnquiryType =
                    f.FileExtension.toLowerCase();

                result.latestEnquiryIsImage =
                    ['PNG', 'JPG', 'JPEG', 'WEBP']
                        .includes(f.FileExtension.toUpperCase());
            }

            else if (f.Title.startsWith('Business_Development_Plan')) {

                result.bdPlan = true;
                result.bdPlan = true;
                result.bdPlanPreview = previewUrl;
                result.bdPlanName = f.Title;

                result.bdPlanType =
                    f.FileExtension.toLowerCase();

                result.bdPlanIsImage =
                    ['PNG', 'JPG', 'JPEG', 'WEBP']
                        .includes(f.FileExtension.toUpperCase());

            }

        });

        return result;

    }


    // ─────────────────────────────────────────────────────────────────────────
    // Filtered list
    // ─────────────────────────────────────────────────────────────────────────
    get filteredCustomers() {
        let list = [...this.customers];

        if (this.searchTerm) {
            const q = this.searchTerm.toLowerCase();
            list = list.filter(c =>
                (c.customerName || '').toLowerCase().includes(q) ||
                (c.state || '').toLowerCase().includes(q) ||
                (c.district || '').toLowerCase().includes(q) ||
                (c.businessType || '').toLowerCase().includes(q) ||
                (c.contactFirstName || '').toLowerCase().includes(q) ||
                 (c.contactLastName || '').toLowerCase().includes(q)
            );
        }
        if (this.statusFilter) {
            list = list.filter(c => c.status === this.statusFilter);
        }
        if (this.businessLineFilter && this.businessLineFilter !== 'All') {
            list = list.filter(c => c.businessType === this.businessLineFilter);
        }

        // Hardcoded SO data per customer (replace with Apex data later)
const hardcodedSOs = [
    {
        so: '25Y4101138', fi: '05-May-2026', li: '05-May-2026', q: 'Q1', lines: 1, sales: 19.43, tvc: 5.12, tput: 14.31, tp: 73.7,
        items: [{ line: 10, custCode: 'CUST-1001', mat: '94000002880', desc: 'BE370D-1.6-2R-B2-FA', cat: 'SPC VALVE', inv: '15-May-2026', qty: 200, pu: '1,705.46', puRaw: 1705.46, tvcu: '1,174.09', salesl: 3.41, tvcl: 2.35, tputl: 1.06, tpp: 31.2 }]
    },
    {
        so: '25Y4101139', fi: '08-May-2026', li: '08-May-2026', q: 'Q1', lines: 1,
        sales: 11.78, tvc: 3.23, tput: 8.55, tp: 72.6,
        items: [{ line: 10, custCode: 'CUST-1001', mat: '94000002880', desc: 'BE370D-1.6-2R-B2-FA', cat: 'SPC VALVE', inv: '15-May-2026', qty: 200, pu: '1,705.46', puRaw: 1705.46, tvcu: '1,174.09', salesl: 3.41, tvcl: 2.35, tputl: 1.06, tpp: 31.2 }]
    },
    {
        so: '26Y4100072', fi: '28-May-2026', li: '28-May-2026', q: 'Q1', lines: 1, sales: 9.15, tvc: 1.16, tput: 7.99, tp: 87.3,
        items: [{ line: 10, custCode: 'CUST-1001', mat: '94000002880', desc: 'BE370D-1.6-2R-B2-FA', cat: 'SPC VALVE', inv: '15-May-2026', qty: 200, pu: '1,705.46', puRaw: 1705.46, tvcu: '1,174.09', salesl: 3.41, tvcl: 2.35, tputl: 1.06, tpp: 31.2 }]
    },
];

        return list.map((customer, index) => {
            const isExpanded = !!this.expandedCustomers[customer.id];
            const soRows = hardcodedSOs.map((so, si) => {
                const soKey = customer.id + '_' + si;
                const isSoExp = !!this.expandedSOs[soKey];
                return {
                    ...so,
                    soKey,
                    isExpanded: isSoExp,
                    hasItems: (so.items && so.items.length > 0) ? 'true' : 'false',
                    hasItemsbol: so.items && so.items.length > 0, 
                    expandIcon: isSoExp ? '▼' : '▶',                         // ← HERE
                    expandIconClass: 'cm-so-expand-icon cm-so-expand-icon--active',
                    soRowClass: isSoExp ? 'cm-so-row cm-so-row-exp' : 'cm-so-row',
                    soNameClass: isSoExp ? 'cm-so-cell cm-so-cell-exp' : 'cm-so-cell',
                    sales: so.sales.toFixed(2),
                    tvc: so.tvc.toFixed(2),
                    tput: so.tput.toFixed(2),
                    tp: so.tp.toFixed(1) + '%',
                    items: so.items.map((it, li) => ({
                        ...it,
                        lineKey: soKey + '_' + li,
                        salesl: it.salesl.toFixed(2),
                        tvcl: it.tvcl.toFixed(2),
                        tputl: it.tputl.toFixed(2),
                        tpp: it.tpp + '%',
                        finalPrice: (it.qty * it.puRaw).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
                    }))
                };
            });
            return {
                ...customer,
                srNo: index + 1,
                isExpanded,
                expandIcon: (this.showSoTree && soRows.length > 0) ? (isExpanded ? '▼' : '▶') : '',
                soRows: this.showSoTree ? soRows : [],
                actualOI: customer.actualOI || '—',
                salesInvoice: customer.salesInvoice || '—',
            };
        });
    }

    get hasRecords() { return this.filteredCustomers.length > 0; }

    /** Remark column only when viewing Rejected filter (menu / statusParam) */
    get showRemarkColumn() {
        return this.statusFilter === 'Rejected';
    }

    /** Approved Date column only on Approved filter */
    get showApprovedDateColumn() {
        return this.statusFilter === 'Approved';
    }

    /** Rejection Date column only on Rejected filter */
    get showRejectionDateColumn() {
        return this.statusFilter === 'Rejected';
    }

    get customerTableClass() {
        const classes = ['cm-table'];
        if (this.showApprovedDateColumn) {
            classes.push('cm-table--with-approved-date');
        }
        if (this.showRejectionDateColumn || this.showRemarkColumn) {
            classes.push('cm-table--with-remark');
        }
        return classes.join(' ');
    }

    get tableColSpan() {
        let cols = 8;
        if (this.showApprovedDateColumn) cols += 1;
        if (this.showRejectionDateColumn) cols += 1;
        if (this.showRemarkColumn) cols += 1;
        return cols;
    }

    /** Detail: show reject Comments for rejected customers */
    get showDetailRejectionRemark() {
        return !!(this.selectedCustomer && this.selectedCustomer.isRejected);
    }

    get showDetailApprovedDate() {
        return !!(this.selectedCustomer && this.selectedCustomer.isApproved);
    }

    get showDetailRejectionDate() {
        return !!(this.selectedCustomer && this.selectedCustomer.isRejected);
    }

    get blAllCount() {
        return this.customers.length;
    }
    get blRotexCount() {
        return this.customers.filter(c => c.businessType === 'ROTEX').length;
    }
    get blNonRotexCount() {
        return this.customers.filter(c => c.businessType === 'Non ROTEX').length;
    }
    get blBothCount() {
        return this.customers.filter(c => c.businessType === 'BOTH').length;
    }

    get blAllTabClass() {
        return this.businessLineFilter === 'All' ? 'cm-filter-tab cm-filter-tab--active' : 'cm-filter-tab';
    }
    get blRotexTabClass() {
        return this.businessLineFilter === 'ROTEX' ? 'cm-filter-tab cm-filter-tab--active' : 'cm-filter-tab';
    }
    get blNonRotexTabClass() {
        return this.businessLineFilter === 'Non ROTEX' ? 'cm-filter-tab cm-filter-tab--active' : 'cm-filter-tab';
    }
    get blBothTabClass() {
        return this.businessLineFilter === 'BOTH' ? 'cm-filter-tab cm-filter-tab--active' : 'cm-filter-tab';
    }

    handleSearch(event) { this.searchTerm = event.target.value; }
    handleCustomerExpand(event) {
        event.stopPropagation();
    
        const id = event.currentTarget.dataset.id;
    
        this.expandedCustomers = {
            ...this.expandedCustomers,
            [id]: !this.expandedCustomers[id]
        };
    }
    handleStatusFilter(event) {
        this.statusFilter = event.target.value;
    }
    handleBusinessLineFilter(event) {
        const line = event.currentTarget.dataset.line;
        if (line) {
            this.businessLineFilter = line;
        }
    }

    handleSOExpand(event) {
        event.stopPropagation();
        const soKey = event.currentTarget.dataset.soKey;
    
        this.expandedSOs = {
            ...this.expandedSOs,
            [soKey]: !this.expandedSOs[soKey]
        };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Row click → Detail view
    // ─────────────────────────────────────────────────────────────────────────
    async handleRowClick(event) {

        const id = event.currentTarget.dataset.id;
    
        console.log('Customer Id:', id);
    
        if (!id) {
            return;
        }
    
    
        this.selectedCustomer =
            this.customers.find(c => c.id === id) || null;
    
        if (!this.selectedCustomer) {
            return;
        }
    
        const files = await getAttachments({
            recordId: id
        });
    
        this.selectedCustomer.attach = this._mapAttachments(files);
    
        this.selectedCustomer = {
            ...this.selectedCustomer
        };
    }
    handlePreview(event) {

        this.previewUrl = event.currentTarget.dataset.url;

        this.previewTitle = event.currentTarget.dataset.title;

        const type =
            (event.currentTarget.dataset.type || '').toLowerCase();

        this.previewIsImage =
            ['png', 'jpg', 'jpeg', 'webp']
                .includes(type);

        this.previewIsPdf =
            type === 'pdf';

        this.showPreview = true;

    }

    closePreview() {
        this.showPreview = false;
        this.previewUrl = '';
        this.previewTitle = '';
        this.previewIsImage = false;
        this.previewIsPdf = false;
    }
    get dealerInitials() {
        return (this.dealerName || '')
            .split(' ').slice(0, 2).map(w => w[0]).join('').toUpperCase();
    }

    get selectedCustomerInitials() {
        if (!this.selectedCustomer) return '';
        return (this.selectedCustomer.customerName || '')
            .split(' ').slice(0, 2).map(w => w[0]).join('').toUpperCase();
    }

    handleBack() {
        this.selectedCustomer = null;
    }
    async handleEdit() {
        this.isEditMode = true;
        this.editingCustomerId = this.selectedCustomer.id;
        this.errors = {};
        this.contactErrors = {};

        const sc = this.selectedCustomer;
        // Normalize placeholders so select/input show real values
        const rawProfile =
            sc.customerProfile && sc.customerProfile !== '—'
                ? sc.customerProfile
                : '';

        this.form = {
            customerName: sc.customerName && sc.customerName !== '—' ? sc.customerName : '',
            gstNo: sc.gstNo || '',
            address: sc.address || '',
            businessType: sc.businessType || '',
            target: sc.target != null ? String(sc.target) : '',
            targetNonRotex: sc.targetNonRotex != null ? String(sc.targetNonRotex) : '',
            customerProfile: this._normalizeCustomerProfile(rawProfile),
            oemDetails: sc.oemDetails || '',
            state: sc.state || '',
            district: sc.district || '',
            pinCode: sc.pinCode || '',
            annualPotential:
                sc.annualPotential != null && sc.annualPotential !== undefined
                    ? String(sc.annualPotential)
                    : '',
            customerWebsite: sc.customerWebsite || '',
            country: sc.country || ''
        };

        try {
            const rows = await getCustomerContacts({
                customerId: this.editingCustomerId
            });
            if (rows && rows.length) {
                this.contacts = rows.map(r => this._emptyContact({
                    contactId: r.contactId,
                    firstName: r.firstName || '',
                    lastName: r.lastName || '',
                    designation: r.designation || '',
                    phone: r.phone || '',
                    email: r.email || ''
                }));
            } else {
                this.contacts = [this._emptyContact({
                    firstName: sc.contactFirstName || '',
                    lastName: sc.contactLastName || '',
                    designation: sc.contactDesignation || '',
                    phone: sc.contactPhone || '',
                    email: sc.contactEmail || ''
                })];
            }
        } catch (e) {
            this.contacts = [this._emptyContact({
                firstName: sc.contactFirstName || '',
                lastName: sc.contactLastName || '',
                designation: sc.contactDesignation || '',
                phone: sc.contactPhone || '',
                email: sc.contactEmail || ''
            })];
        }

        try {
            const files = await getAttachments({
                recordId: this.editingCustomerId
            });
            const mapped = this._mapAttachments(files);
            this.attach = {
                ...this._emptyAttach(),
                purchaseOrder: mapped.purchaseOrder,
                purchaseOrderName: mapped.purchaseOrderName || null,
                purchaseOrderIsImage: mapped.purchaseOrderIsImage || false,
                purchaseOrderPreview: mapped.purchaseOrderPreview || null,
                latestEnquiry: mapped.latestEnquiry,
                latestEnquiryName: mapped.latestEnquiryName || null,
                latestEnquiryIsImage: mapped.latestEnquiryIsImage || false,
                latestEnquiryPreview: mapped.latestEnquiryPreview || null,
                bdPlan: mapped.bdPlan,
                bdPlanName: mapped.bdPlanName || null,
                bdPlanIsImage: mapped.bdPlanIsImage || false,
                bdPlanPreview: mapped.bdPlanPreview || null
            };
        } catch (e) {
            this.attach = this._emptyAttach();
        }

        this.gstVerified = false;
        this.gstMessage = '';
        this._resetGstLocks();
        this._applyLocationLocks(this.form.state, this.form.district);
        this.isModalOpen = true;

        // Let modal render then force-fill all native controls so values are visible
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => {
            this._syncFormNativeControls();
        }, 0);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => {
            this._syncFormNativeControls();
        }, 50);

        // Same GST fetch/auto-fill as when typing GST (import + older records on Edit)
        const gstVal = (this.form.gstNo || '').trim().toUpperCase();
        if (gstVal.length === 15) {
            await this._fetchAndApplyGst(gstVal, { preserveOnFailure: true });
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            window.setTimeout(() => {
                this._syncFormNativeControls();
            }, 0);
        } else if (gstVal.length > 0) {
            this.gstMessage = 'GST Number must be exactly 15 characters.';
        } else {
            this.gstVerified = true;
        }
    }

    /** Map legacy / alternate labels onto actual Customer_Profile__c values. */
    _normalizeCustomerProfile(value) {
        if (!value || value === '—') {
            return '';
        }
        const v = String(value).trim();
        const map = {
            OEM: 'Project OEM',
            'Project OEM': 'Project OEM',
            VAC: 'VAC',
            Trader: 'Trader',
            'Machine OEM': 'Machine OEM',
            User: 'User',
            'End User': 'End User',
            'System Integrator / EPC': 'System Integrator / EPC',
            'System Integrator/EPC': 'System Integrator / EPC'
        };
        return map[v] || v;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Modal open / close
    // ─────────────────────────────────────────────────────────────────────────
    openModal() {

        this.isEditMode = false;

        this.editingCustomerId = null;

        this.isModalOpen = true;

        this.form = this._emptyForm();

        this.errors = {};

        this.contacts = [this._emptyContact()];
        this.contactErrors = {};

        this.attach = this._emptyAttach();

        this.gstVerified = false;
        this.gstMessage = '';
        this._resetGstLocks();
        this._resetLocationLocks();

    }
    closeModal() { this.isModalOpen = false; }
    handleBackdropClick() { this.closeModal(); }
    stopPropagation(event) { event.stopPropagation(); }

    handleAddContact() {
        this.contacts = [...this.contacts, this._emptyContact()];
    }

    handleRemoveContact(event) {
        const key = event.currentTarget.dataset.key;
        if (this.contacts.length <= 1) {
            return;
        }
        this.contacts = this.contacts.filter(c => c.key !== key);
        if (this.contactErrors[key]) {
            const next = { ...this.contactErrors };
            delete next[key];
            this.contactErrors = next;
        }
    }

    handleContactInput(event) {
        const key = event.currentTarget.dataset.key;
        const field = event.currentTarget.dataset.field;
        const val = event.target.value;
        this.contacts = this.contacts.map(c =>
            c.key === key ? { ...c, [field]: val } : c
        );
        if (this.contactErrors[key]?.[field]) {
            const next = {
                ...this.contactErrors,
                [key]: { ...this.contactErrors[key] }
            };
            delete next[key][field];
            if (!Object.keys(next[key]).length) {
                delete next[key];
            }
            this.contactErrors = next;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Form input handlers
    // ─────────────────────────────────────────────────────────────────────────
    async handleInput(event) {

        const field = event.currentTarget.dataset.field;
        const val = event.target.value;
    
        this.form = {
            ...this.form,
            [field]: val
        };
    
        if (this.errors[field]) {
            const e = { ...this.errors };
            delete e[field];
            this.errors = e;
        }

        if (field === 'annualPotential' || field === 'target') {
            this._syncAnnualPotentialVsTargetError();
        }
    
        // ── GST validation + auto-fill (Jamku) ──
        if (field === 'gstNo') {
            const gstVal = (val || '').trim().toUpperCase();
            if (gstVal !== val) {
                this.form = { ...this.form, gstNo: gstVal };
            }

            this.gstVerified = false;
            this.gstMessage = '';
            this._resetGstLocks();

            // Clear previous GST auto-fill so stale pin/name don't stick when GST changes
            if (gstVal.length !== 15) {
                this.form = {
                    ...this.form,
                    gstNo: gstVal,
                    customerName: '',
                    address: '',
                    pinCode: '',
                    district: '',
                    state: ''
                };
                this._syncAddressTextarea();
            }

            if (gstVal.length > 0 && gstVal.length < 15) {
                this.errors = {
                    ...this.errors,
                    gstNo: 'GST Number must be exactly 15 characters.'
                };
            } else if (gstVal.length === 15) {
                await this._fetchAndApplyGst(gstVal);
            }
        }

        // ── Pin Code validation (always editable, including after GST auto-fill) ──
        if (field === 'pinCode') {
    
            if (val.length > 0 && val.length < 6) {
                // still typing, don't show error yet
                const e = { ...this.errors };
                delete e.pinCode;
                this.errors = e;
    
            } else if (val.length === 6 && !/^\d{6}$/.test(val)) {
                this.errors = {
                    ...this.errors,
                    pinCode: 'Invalid Pincode.'
                };
                this.form = {
                    ...this.form,
                    district: '',
                    state: ''
                };
                this._resetLocationLocks();
    
            } else if (val.length === 6) {
                await this.populateStateDistrict(val);
            } else if (!val.length) {
                this.form = {
                    ...this.form,
                    district: '',
                    state: ''
                };
                this._resetLocationLocks();
                const e = { ...this.errors };
                delete e.pinCode;
                this.errors = e;
            }
        }
    }

    get showOemDetails() {
        const p = this.form.customerProfile || '';
        return p === 'OEM' || p === 'Project OEM' || p === 'Machine OEM';
    }

    get businessTypeOptions() {
        const current = this.form.businessType || '';
        return [
            { key: 'bt-blank', value: '', label: '-- Select Business Line --', selected: !current },
            { key: 'bt-ROTEX', value: 'ROTEX', label: 'ROTEX', selected: current === 'ROTEX' },
            { key: 'bt-Non', value: 'Non ROTEX', label: 'Non ROTEX', selected: current === 'Non ROTEX' },
            { key: 'bt-BOTH', value: 'BOTH', label: 'BOTH', selected: current === 'BOTH' }
        ];
    }

    get customerProfileOptions() {
        const current = this.form.customerProfile || '';
        // Values must match Account.Customer_Profile__c picklist API names
        return [
            { key: 'cp-blank', value: '', label: '-- Select Profile --', selected: !current },
            {
                key: 'cp-ProjectOEM',
                value: 'Project OEM',
                label: 'Project OEM',
                selected: current === 'Project OEM'
            },
            { key: 'cp-VAC', value: 'VAC', label: 'VAC', selected: current === 'VAC' },
            {
                key: 'cp-MachineOEM',
                value: 'Machine OEM',
                label: 'Machine OEM',
                selected: current === 'Machine OEM'
            },
            { key: 'cp-EndUser', value: 'End User', label: 'End User', selected: current === 'End User' },
            {
                key: 'cp-SI',
                value: 'System Integrator / EPC',
                label: 'System Integrator / EPC',
                selected: current === 'System Integrator / EPC'
            }
        ];
    }

    /** Non ROTEX: only Customer Name + GST are mandatory (incl. BD plan optional). */
    get isNonRotexBusiness() {
        return this.form.businessType === 'Non ROTEX';
    }

    get isRotexBusiness() {
        return this.form.businessType === 'ROTEX';
    }

    get isBothBusiness() {
        return this.form.businessType === 'BOTH';
    }

    get showTargetRotexField() {
        return this.isRotexBusiness || this.isBothBusiness;
    }

    get showTargetNonRotexField() {
        return this.isNonRotexBusiness || this.isBothBusiness;
    }

    get showFullFieldRequired() {
        return !this.isNonRotexBusiness;
    }

    get showBdPlanRequired() {
        return !this.isNonRotexBusiness;
    }

    get bdPlanMandatoryNote() {
        return this.isNonRotexBusiness
            ? 'Business Development Plan is optional for Non ROTEX'
            : 'Business Development Plan is mandatory';
    }

    // ─────────────────────────────────────────────────────────────────────────
    // File handlers
    // ─────────────────────────────────────────────────────────────────────────
    handleFileChange(event) {
        const slot = event.currentTarget.dataset.slot;
        const file = event.target.files[0];
        if (!file) return;

        const isImage = file.type.startsWith('image/');
        const reader = new FileReader();

        reader.onload = (e) => {
            const dataUrl = e.target.result;
            const base64 = dataUrl.split(',')[1];
            this.attach = {
                ...this.attach,
                [slot]: true,
                [slot + 'Name']: file.name,
                [slot + 'IsImage']: isImage,
                [slot + 'Preview']: isImage ? dataUrl : null,
                [slot + 'Base64']: base64,
                [slot + 'FileType']: file.type
            };
            // Clear attachment error if at least one is now present
            if (this.errors.attachments) {
                const e = { ...this.errors }; delete e.attachments; this.errors = e;
            }
        };
        reader.readAsDataURL(file);
    }

    handleFileRemove(event) {
        const slot = event.currentTarget.dataset.slot;
        this.attach = {
            ...this.attach,
            [slot]: false,
            [slot + 'Name']: null,
            [slot + 'IsImage']: false,
            [slot + 'Preview']: null,
            [slot + 'Base64']: null,
            [slot + 'FileType']: null
        };
    }

    get hasAtLeastOneFile() {
        return this.attach.purchaseOrder || this.attach.latestEnquiry || this.attach.bdPlan;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Validation
    // ─────────────────────────────────────────────────────────────────────────
    /**
     * Annual Business Potential must not be less than Target (Rotex).
     * Shows / clears error under Annual Business Potential as values change.
     */
    _syncAnnualPotentialVsTargetError() {
        const e = { ...this.errors };
        delete e.annualPotential;
        const msg = this._annualPotentialVsTargetMessage();
        if (msg) {
            e.annualPotential = msg;
        } else if (
            this.showFullFieldRequired &&
            (this.form.annualPotential === '' || this.form.annualPotential == null)
        ) {
            // only set require message on full validate, not while typing empty after edit
        }
        this.errors = e;
    }

    _annualPotentialVsTargetMessage() {
        if (!this.showTargetRotexField) {
            return null;
        }
        const targetRaw = this.form.target != null ? String(this.form.target).trim() : '';
        if (
            this.form.annualPotential === '' ||
            this.form.annualPotential == null ||
            !targetRaw
        ) {
            return null;
        }
        const potential = parseFloat(this.form.annualPotential);
        const targetRotex = parseFloat(targetRaw.replace(/,/g, ''));
        if (
            Number.isNaN(potential) ||
            Number.isNaN(targetRotex) ||
            potential >= targetRotex
        ) {
            return null;
        }
        return 'Annual Business Potential cannot be less than Target (Rotex).';
    }

    _validate() {
        const e = {};
        const nonRotex = this.isNonRotexBusiness;
        const hasBusinessLine = !!this.form.businessType;

        // Always required
        if (!this.form.customerName?.trim()) e.customerName = 'Customer Name is required.';
        if (!this.form.gstNo?.trim()) e.gstNo = 'GST No. is required.';
        else if (this.form.gstNo.trim().length !== 15) {
            e.gstNo = 'GST Number must be exactly 15 characters.';
        }
        if (!hasBusinessLine) e.businessType = 'Business Line is required.';

        // Until Non ROTEX is selected, apply full rules only when business line is ROTEX/BOTH
        if (hasBusinessLine && !nonRotex) {
            if (!this.form.customerProfile) e.customerProfile = 'Customer Profile is required.';
            if (!this.form.customerWebsite?.trim()) e.customerWebsite = 'Customer Website is required.';
            if (!this.form.address?.trim()) e.address = 'Address is required.';
            if (!this.form.country?.trim()) {
                e.country = 'Country is required.';
            }
            if (!this.form.pinCode?.trim()) e.pinCode = 'Pin Code is required.';
            else if (!/^\d{6}$/.test(this.form.pinCode)) e.pinCode = 'Pin Code must be exactly 6 digits.';
            if (!this.form.annualPotential && this.form.annualPotential !== 0) {
                e.annualPotential = 'Annual Business Potential is required.';
            } else {
                const cmpMsg = this._annualPotentialVsTargetMessage();
                if (cmpMsg) e.annualPotential = cmpMsg;
            }
            if (this.showTargetRotexField && !this.form.target?.trim()) {
                e.target = 'Target (Rotex) is required.';
            }
            if (this.showTargetNonRotexField && !this.form.targetNonRotex && this.form.targetNonRotex !== 0) {
                e.targetNonRotex = 'Target (Non-Rotex) is required.';
            }
            // BOTH has both fields required via the above; pure ROTEX only Rotex field
            if (this.showOemDetails && !this.form.oemDetails?.trim()) {
                e.oemDetails = 'Product Manufactured By (OEM) is required.';
            }

            if (!this.isEditMode && !this.attach.bdPlan) {
                e.bdPlan = 'Business Development Plan is required.';
            }

            const cErr = {};
            if (!this.contacts.length) {
                e.contacts = 'At least one contact is required.';
            }
            this.contacts.forEach((c, i) => {
                const row = {};
                if (!c.firstName?.trim()) row.firstName = 'First Name is required.';
                if (!c.lastName?.trim()) row.lastName = 'Last Name is required.';
                if (!c.designation?.trim()) row.designation = 'Designation is required.';
                if (!c.phone?.trim()) row.phone = 'Telephone No. is required.';
                if (!c.email?.trim()) row.email = 'Email ID is required.';
                if (Object.keys(row).length) {
                    cErr[c.key] = row;
                    e[`contact_${i}`] = 'Contact incomplete';
                }
            });
            this.contactErrors = cErr;
        } else if (nonRotex) {
            // Soft format check if pin is filled for Non ROTEX
            if (this.form.pinCode?.trim() && !/^\d{6}$/.test(this.form.pinCode.trim())) {
                e.pinCode = 'Pin Code must be exactly 6 digits.';
            }
            // Soft-validate partially filled contacts only
            const cErr = {};
            this.contacts.forEach((c, i) => {
                const hasAny =
                    c.firstName?.trim() ||
                    c.lastName?.trim() ||
                    c.designation?.trim() ||
                    c.phone?.trim() ||
                    c.email?.trim();
                if (!hasAny) return;
                const row = {};
                if (!c.firstName?.trim()) row.firstName = 'First Name is required.';
                if (!c.lastName?.trim()) row.lastName = 'Last Name is required.';
                if (!c.designation?.trim()) row.designation = 'Designation is required.';
                if (!c.phone?.trim()) row.phone = 'Telephone No. is required.';
                if (!c.email?.trim()) row.email = 'Email ID is required.';
                if (Object.keys(row).length) {
                    cErr[c.key] = row;
                    e[`contact_${i}`] = 'Contact incomplete';
                }
            });
            this.contactErrors = cErr;
        } else {
            this.contactErrors = {};
        }

        this.errors = e;
        return Object.keys(e).length === 0;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Save
    // ─────────────────────────────────────────────────────────────────────────
    async handleSave() {
        if (!this._validate()) return;
        if (this.form.gstNo && !this.gstVerified) {
            this._showToast('GST Number is not verified.', true);
            return;
        }

        this.isSaving = true;
        try {
            const primary = this.contacts[0] || {};
            const contactsPayload = this.contacts.map(c => ({
                contactId: c.contactId || null,
                firstName: c.firstName,
                lastName: c.lastName,
                designation: c.designation,
                phone: c.phone,
                email: c.email
            }));

            // 1. Create / update the Account record
            const input = {
                dealerAccountId: this.dealerAccountId,
                customerName: this.form.customerName,
                gstNo: this.form.gstNo,
                address: this.form.address,
                country: this.form.country,
                businessType: this.form.businessType,
                target: this.form.target || null,
                targetNonRotex: this.form.targetNonRotex !== '' && this.form.targetNonRotex != null
                    ? parseFloat(this.form.targetNonRotex)
                    : null,
                customerProfile: this.form.customerProfile,
                oemDetails: this.form.oemDetails,
                state: this.form.state,
                district: this.form.district,
                pinCode: this.form.pinCode,
                annualPotential: this.form.annualPotential
                    ? parseFloat(this.form.annualPotential)
                    : null,
                customerWebsite: this.form.customerWebsite,

                contactFirstName: primary.firstName || '',
                contactLastName: primary.lastName || '',
                contactPhone: primary.phone || '',
                contactEmail: primary.email || '',
                contactDesignation: primary.designation || '',
                contacts: contactsPayload
            };

            let newId;

            if (this.isEditMode) {

                input.customerId = this.editingCustomerId;

                newId = await updateCustomer({ input });

            } else {

                newId = await createCustomer({ input });

            }
            // 2. Upload any attachments
            const slots = [
                { key: 'purchaseOrder', label: 'Latest_Purchase_Order' },
                { key: 'latestEnquiry', label: 'Latest_Enquiry' },
                { key: 'bdPlan', label: 'Business_Development_Plan' }
            ];

            for (const s of slots) {
                if (this.attach[s.key] && this.attach[s.key + 'Base64']) {
                    try {
                        await saveAttachment({
                            recordId: newId,
                            fileName: s.label + '_' + this.attach[s.key + 'Name'],
                            base64Data: this.attach[s.key + 'Base64'],
                            fileType: this.attach[s.key + 'FileType']
                        });
                    } catch (attachErr) {
                        // silently ignore attachment errors, don't block list reload
                    }
                }
            }


            if (this.isEditMode) {

                const updatedId = this.editingCustomerId;

                this.isEditMode = false;
                this.editingCustomerId = null;
                this.closeModal();

                this.selectedCustomer =
                    this.customers.find(c => c.id === updatedId) || null;

                if (this.selectedCustomer) {
                    try {
                        const files = await getAttachments({
                            recordId: updatedId
                        });
                        this.selectedCustomer.attach =
                            this._mapAttachments(files);
                        this.selectedCustomer = {
                            ...this.selectedCustomer
                        };
                    } catch (e) { }
                }

                this._showToast('Customer updated successfully!');

            } else {

                await this._loadCustomers(); // ← only here for create
                this.closeModal();
                this._showToast('Customer created successfully!');

            }
        } catch (e) {
            this._showToast('Error: ' + this._errorMsg(e), true);
        } finally {
            this.isSaving = false;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────
   _emptyForm() {
    return {
        customerName: '',
        gstNo: '',
        address: '',
        country: '',
        businessType: '',
        target: '',
        targetNonRotex: '',
        customerProfile: '',
        oemDetails: '',
        state: '',
        district: '',
        pinCode: '',
        annualPotential: '',
        customerWebsite: ''
    };
}

    _formatTargetDisplay(businessType, targetRotex, targetNonRotex) {
        const rotex = targetRotex != null && String(targetRotex).trim() !== ''
            ? String(targetRotex).trim()
            : null;
        const non =
            targetNonRotex != null && targetNonRotex !== undefined
                ? String(targetNonRotex)
                : null;
        if (businessType === 'ROTEX') {
            return rotex || '—';
        }
        if (businessType === 'Non ROTEX') {
            return non || '—';
        }
        if (businessType === 'BOTH') {
            const parts = [];
            if (rotex) parts.push('R: ' + rotex);
            if (non) parts.push('NR: ' + non);
            return parts.length ? parts.join(' · ') : '—';
        }
        return rotex || non || '—';
    }

    _emptyAttach() {
        return {
            purchaseOrder: false, purchaseOrderName: null, purchaseOrderIsImage: false,
            purchaseOrderPreview: null, purchaseOrderBase64: null, purchaseOrderFileType: null,
            latestEnquiry: false, latestEnquiryName: null, latestEnquiryIsImage: false,
            latestEnquiryPreview: null, latestEnquiryBase64: null, latestEnquiryFileType: null,
            bdPlan: false, bdPlanName: null, bdPlanIsImage: false,
            bdPlanPreview: null, bdPlanBase64: null, bdPlanFileType: null
        };
    }


    _fmtDate(dateStr) {

        if (!dateStr) {
            return '—';
        }

        return new Date(dateStr).toLocaleDateString('en-IN', {
            day: '2-digit',
            month: 'short',
            year: 'numeric'
        });

    }

    _fmtDateTime(dateStr) {

        if (!dateStr) {
            return '—';
        }

        return new Date(dateStr).toLocaleString('en-IN', {
            day: '2-digit',
            month: 'short',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });

    }

    _errorMsg(e) {
        return e?.body?.message || e?.message || 'Unknown error';
    }

    _showToast(msg, isError = false) {
        this.toastMessage = msg;
        this.showToast = true;
        // Also fire platform toast if available
        try {
            this.dispatchEvent(new ShowToastEvent({
                title: isError ? 'Error' : 'Success',
                message: msg,
                variant: isError ? 'error' : 'success'
            }));
        } catch (_) { /* outside platform context */ }
        setTimeout(() => { this.showToast = false; }, 4000);
    }
    async populateStateDistrict(pinCode) {
        try {
            const result = await getStateDistrictByPincode({ pinCode });

            const state = result && result.state ? String(result.state).trim() : '';
            const district = result && result.district ? String(result.district).trim() : '';

            if (state || district) {
                // Fill what API returned; leave missing fields blank & editable
                this.form = {
                    ...this.form,
                    state,
                    district
                };
                this._applyLocationLocks(state, district);

                const e = { ...this.errors };
                delete e.pinCode;
                if (state) delete e.state;
                if (district) delete e.district;
                this.errors = e;

                // Force native inputs to show filled values
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                window.setTimeout(() => {
                    this._syncFormNativeControls();
                }, 0);
            } else {
                // Invalid / unknown pincode — enable manual State & District
                this.form = {
                    ...this.form,
                    state: '',
                    district: ''
                };
                this._resetLocationLocks();
                this.errors = {
                    ...this.errors,
                    pinCode: 'Invalid Pincode. Enter District and State manually.'
                };
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                window.setTimeout(() => {
                    this._syncFormNativeControls();
                }, 0);
            }

        } catch (error) {
            console.error('Pincode Error:', JSON.stringify(error));

            this.form = {
                ...this.form,
                state: '',
                district: ''
            };
            this._resetLocationLocks();
            this.errors = {
                ...this.errors,
                pinCode: 'Invalid Pincode. Enter District and State manually.'
            };
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            window.setTimeout(() => {
                this._syncFormNativeControls();
            }, 0);
        }
    }
    _handleStatusChange(event) {
        if (event.detail && event.detail.status !== undefined) {
            this.statusFilter = event.detail.status;
            // Leave detail view so the selected status tab/list is shown
            this.selectedCustomer = null;
            this.isEditMode = false;
            this.editingCustomerId = null;
            this.isModalOpen = false;
        }
    }
    
    _applyStatusFromUrl() {
        try {
            const params = new URLSearchParams(window.location.search);
            const status = params.get('status');
            if (status) {
                this.statusFilter = status;
            }
        } catch (e) {
            // ignore malformed URL
        }
    }
}