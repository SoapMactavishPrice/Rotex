import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDealerAccount from '@salesforce/apex/CustomerController.getDealerAccount';
import getCustomersByDealer from '@salesforce/apex/CustomerController.getCustomersByDealer';
import createCustomer from '@salesforce/apex/CustomerController.createCustomer';
import getStateDistrictByPincode from '@salesforce/apex/CustomerController.getStateDistrictByPincode';
import updateCustomer from '@salesforce/apex/CustomerController.updateCustomer';
import saveAttachment from '@salesforce/apex/CustomerController.saveAttachment';
import getAttachments from '@salesforce/apex/CustomerController.getAttachments';
import verifyGST from '@salesforce/apex/CustomerController.verifyGST';
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
    // ── Form model ────────────────────────────────────────────────────────────
    @track form = this._emptyForm();
    @track errors = {};

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

    get gstClass() {
        return this.gstVerified
            ? 'gst-success'
            : 'gst-error';
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
            this.customers = raw.map(c => this._mapCustomer(c));
        } catch (e) {
            this._showToast('Error loading customers: ' + this._errorMsg(e), true);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Map Apex Account → UI object
    // ─────────────────────────────────────────────────────────────────────────
    _mapCustomer(c) {
        const amount = c.Annual_Business_Potential__c;
        const status = c.Approval_Status__c || 'Pending Approval';
        const statusClass =
            status === 'Approved' ? 'cm-status cm-status--approved' :
                status === 'Rejected' ? 'cm-status cm-status--rejected' :
                    'cm-status cm-status--pending';
        return {
            id: c.Id,
            customerName: c.Customer_Name__c || c.Name || '—',
            gstNo: c.GST_No__c || '',
            timestamp: c.Timestamp__c,
            address: c.Street__c || '',
            businessType: c.Business_type__c || '',
            target: c.Target__c || '',
            customerProfile: c.Customer_Profile__c || '—',
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
            targetDisplay: c.Target__c || '—',
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
            status,                   // ← ADD
            statusClass,              // ← ADD
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

        this.form = {
            customerName: this.selectedCustomer.customerName,
            gstNo: this.selectedCustomer.gstNo,
            address: this.selectedCustomer.address,
            businessType: this.selectedCustomer.businessType,
            target: this.selectedCustomer.target,
            customerProfile: this.selectedCustomer.customerProfile,
            oemDetails: this.selectedCustomer.oemDetails,
            state: this.selectedCustomer.state,
            district: this.selectedCustomer.district,
            pinCode: this.selectedCustomer.pinCode,
            annualPotential: this.selectedCustomer.annualPotential,
            customerWebsite: this.selectedCustomer.customerWebsite,
            contactFirstName: this.selectedCustomer.contactFirstName,
       contactLastName: this.selectedCustomer.contactLastName,
        country: this.selectedCustomer.country,
            contactPhone: this.selectedCustomer.contactPhone,
            contactEmail: this.selectedCustomer.contactEmail,
            contactDesignation: this.selectedCustomer.contactDesignation
        };

        // ── Load existing attachments into attach state ──
        try {
            const files = await getAttachments({
                recordId: this.editingCustomerId
            });

            const mapped = this._mapAttachments(files);

            this.attach = {
                ...this._emptyAttach(),

                // Purchase Order
                purchaseOrder: mapped.purchaseOrder,
                purchaseOrderName: mapped.purchaseOrderName || null,
                purchaseOrderIsImage: mapped.purchaseOrderIsImage || false,
                purchaseOrderPreview: mapped.purchaseOrderPreview || null,

                // Latest Enquiry
                latestEnquiry: mapped.latestEnquiry,
                latestEnquiryName: mapped.latestEnquiryName || null,
                latestEnquiryIsImage: mapped.latestEnquiryIsImage || false,
                latestEnquiryPreview: mapped.latestEnquiryPreview || null,

                // BD Plan
                bdPlan: mapped.bdPlan,
                bdPlanName: mapped.bdPlanName || null,
                bdPlanIsImage: mapped.bdPlanIsImage || false,
                bdPlanPreview: mapped.bdPlanPreview || null
            };

        } catch (e) {
            // if attachments fail to load, just open with empty attach
            this.attach = this._emptyAttach();
        }

        this.isModalOpen = true;
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

        this.attach = this._emptyAttach();

    }
    closeModal() { this.isModalOpen = false; }
    handleBackdropClick() { this.closeModal(); }
    stopPropagation(event) { event.stopPropagation(); }

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
    
        // ── GST validation ──
        if (field === 'gstNo') {
    
            this.gstVerified = false;
            this.gstMessage = '';
    
            if (val.length > 0 && val.length < 15) {
                this.errors = {
                    ...this.errors,
                    gstNo: 'GST Number must be exactly 15 characters.'
                };
            } else if (val.length === 15) {
    
                try {
                    const verified = await verifyGST({ gstNo: val });
    
                    if (verified) {
                        this.gstVerified = true;
                        this.gstMessage = 'GST Verified';
                    } else {
                        this.gstVerified = false;
                        this.gstMessage = 'GST Number is not verified';
                    }
                } catch (error) {
                    this.gstVerified = false;
                    this.gstMessage = 'Unable to verify GST';
                }
            }
        }
    
        // ── Pin Code validation ──
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
    
            } else if (val.length === 6) {
                await this.populateStateDistrict(val);
            }
        }
    }

    get showOemDetails() { return this.form.customerProfile === 'OEM' || this.form.customerProfile === 'Machine OEM'; }

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
    _validate() {
        const e = {};
        if (!this.form.customerName?.trim()) e.customerName = 'Customer Name is required.';
        if (!this.form.customerProfile) e.customerProfile = 'Customer Profile is required.';
       if (!this.form.contactFirstName?.trim()) {
    e.contactFirstName = 'Contact Person First Name is required.';
}

if (!this.form.contactLastName?.trim()) {
    e.contactLastName = 'Contact Person Last Name is required.';
}
        if (!this.form.gstNo?.trim()) e.gstNo = 'GST No. is required.';
        if (!this.form.customerWebsite?.trim()) e.customerWebsite = 'Customer Website is required.';
        if (!this.form.businessType) e.businessType = 'Business Type is required.';
        if (!this.form.address?.trim()) e.address = 'Address is required.';
        if (!this.form.country?.trim()) {
    e.country = 'Country is required.';
}
        if (!this.form.pinCode?.trim()) e.pinCode = 'Pin Code is required.';
        else if (!/^\d{6}$/.test(this.form.pinCode)) e.pinCode = 'Pin Code must be exactly 6 digits.';
        if (!this.form.annualPotential) e.annualPotential = 'Annual Business Potential is required.';
        if (!this.form.target) e.target = 'Target is required.';
        if (!this.form.contactPhone?.trim()) e.contactPhone = 'Telephone No. is required.';
        if (!this.form.contactEmail?.trim()) e.contactEmail = 'Email ID is required.';

        // Attachment: only BD Plan is mandatory
        if (!this.isEditMode && !this.attach.bdPlan) e.bdPlan = 'Business Development Plan is required.';

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
            // 1. Create the Account record
           const input = {
    dealerAccountId: this.dealerAccountId,
    customerName: this.form.customerName,
    gstNo: this.form.gstNo,
    address: this.form.address,
    country: this.form.country,
    businessType: this.form.businessType,
    target: this.form.target ? parseFloat(this.form.target) : null,
    customerProfile: this.form.customerProfile,
    oemDetails: this.form.oemDetails,
    state: this.form.state,
    district: this.form.district,
    pinCode: this.form.pinCode,
    annualPotential: this.form.annualPotential
        ? parseFloat(this.form.annualPotential)
        : null,
    customerWebsite: this.form.customerWebsite,

    contactFirstName: this.form.contactFirstName,
    contactLastName: this.form.contactLastName,
    contactPhone: this.form.contactPhone,
    contactEmail: this.form.contactEmail,
    contactDesignation: this.form.contactDesignation
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
        customerProfile: '',
        oemDetails: '',
        state: '',
        district: '',
        pinCode: '',
        annualPotential: '',
        customerWebsite: '',
        contactFirstName: '',
        contactLastName: '',
        contactPhone: '',
        contactEmail: '',
        contactDesignation: ''
    };
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
    
            if (result && result.state && result.district) {
                this.form = {
                    ...this.form,
                    state: result.state,
                    district: result.district
                };
    
                const e = { ...this.errors };
                delete e.pinCode;
                this.errors = e;
    
            } else {
                this.form = {
                    ...this.form,
                    state: '',
                    district: ''
                };
                this.errors = {
                    ...this.errors,
                    pinCode: 'Invalid Pincode.'
                };
            }
    
        } catch (error) {
            console.error('Pincode Error:', JSON.stringify(error));
    
            this.form = {
                ...this.form,
                state: '',
                district: ''
            };
            this.errors = {
                ...this.errors,
                pinCode: 'Invalid Pincode.'
            };
        }
    }
    _handleStatusChange(event) {
        if (event.detail && event.detail.status !== undefined) {
            this.statusFilter = event.detail.status;
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