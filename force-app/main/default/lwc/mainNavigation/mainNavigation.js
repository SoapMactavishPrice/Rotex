import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import basePath from '@salesforce/community/basePath';

export default class MainNavigation extends NavigationMixin(LightningElement) {

    @api item;
    @api activeItemId;

    href = '#';
    pageReference;
    isExpanded = false;

    @track selectedStatus = '';

    connectedCallback() {

        const { target } = this.item;

        if (target) {
            const url = target.startsWith('/')
                ? basePath + target
                : basePath + '/' + target;

            this.pageReference = {
                type: 'standard__webPage',
                attributes: { url }
            };

            this[NavigationMixin.GenerateUrl](this.pageReference)
                .then(url => { this.href = url; })
                .catch(error => {
                    console.error('URL Error:', error);
                    this.href = '#';
                });
        }

        // Read initial status from URL (page load / refresh)
        this.selectedStatus = this._readStatusFromUrl();

        if (this.hasChildren && this.selectedStatus) {
            this.isExpanded = true;
        }

        // ── Listen for changes broadcast by sibling nav items or on browser back/forward ──
        this._boundPopStateHandler = () => {
            this.selectedStatus = this._readStatusFromUrl();
        };
        window.addEventListener('popstate', this._boundPopStateHandler);

        this._boundStatusHandler = (event) => {
            if (event.detail && event.detail.status !== undefined) {
                this.selectedStatus = event.detail.status;
            }
        };
        window.addEventListener('customerstatuschange', this._boundStatusHandler);
    }

    disconnectedCallback() {
        if (this._boundPopStateHandler) {
            window.removeEventListener('popstate', this._boundPopStateHandler);
        }
        if (this._boundStatusHandler) {
            window.removeEventListener('customerstatuschange', this._boundStatusHandler);
        }
    }

    _readStatusFromUrl() {
        try {
            return new URLSearchParams(window.location.search).get('status') || '';
        } catch (e) {
            return '';
        }
    }

    get hasChildren() {
        return !!(this.item.children && this.item.children.length > 0);
    }

    get showChildren() {
        return this.hasChildren && this.isExpanded;
    }

    get expandIcon() {
        return this.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get isOnTargetPage() {
        try {
            const path = (window.location.pathname || '')
                .toLowerCase()
                .replace(/\/+$/, '');
            const target = (this.item?.target || '')
                .toLowerCase()
                .replace(/\/+$/, '');
            const label = (this.item?.publicLabel || this.item?.label || '')
                .toLowerCase()
                .trim();
            const isHomeItem = label === 'home page' || label === 'home';
            const base = String(basePath || '')
                .toLowerCase()
                .replace(/\/+$/, '');

            // Login lands on portal home — mark Home Page tab active by default
            if (isHomeItem) {
                if (this._isAtPortalHome(path, base)) {
                    return true;
                }
                if (target && target !== '/') {
                    const targetSeg = target.split('/').filter(Boolean).pop();
                    if (targetSeg) {
                        const pathSegs = path.split('/').filter(Boolean);
                        return pathSegs.includes(targetSeg);
                    }
                }
                return false;
            }

            if (!target || target === '/') {
                return false;
            }
            const targetSeg = target.split('/').filter(Boolean).pop();
            if (!targetSeg) {
                return false;
            }
            const pathSegs = path.split('/').filter(Boolean);
            return pathSegs.includes(targetSeg);
        } catch (e) {
            return false;
        }
    }

    /**
     * True when the URL is the Experience Cloud site home (no module page slug).
     * Covers base path only and optional home page names.
     */
    _isAtPortalHome(path, base) {
        const p = (path || '').toLowerCase().replace(/\/+$/, '');
        const b = (base || '').toLowerCase().replace(/\/+$/, '');

        if (!p || p === b) {
            return true;
        }

        if (b && p.startsWith(b + '/')) {
            const rest = p.slice(b.length + 1).replace(/\/+$/, '');
            if (!rest) {
                return true;
            }
            const homeOnly = ['home', 'home-page', 'homepage'];
            return !rest.includes('/') && homeOnly.includes(rest);
        }

        const segs = p.split('/').filter(Boolean);
        if (segs.length === 0) {
            return true;
        }
        if (segs.length === 1 && segs[0] === 's') {
            return true;
        }
        const last = segs[segs.length - 1];
        return ['home', 'home-page', 'homepage'].includes(last) && segs.length <= 3;
    }

    get childrenList() {
        if (!this.hasChildren) return [];

        return this.item.children.map(child => {
            const isActive = child.status === this.selectedStatus;
            return {
                ...child,
                cssClass: isActive
                    ? 'submenu-item submenu-item--active'
                    : 'submenu-item'
            };
        });
    }

    get isActive() {
        return this.isOnTargetPage;
    }

    get computedClass() {
        return this.isActive ? 'menu-item active' : 'menu-item';
    }

    get menuIcon() {
        const label = (this.item.publicLabel || this.item.label || '').toLowerCase();
        const ICON_MAP = {
            'home page': 'utility:home',
            leads: 'utility:user',
            contacts: 'utility:contact',
            quotation: 'utility:quotation_marks', 
            customer: 'utility:groups',
            activity: 'utility:event',
            order: 'utility:orders',
           invoice: 'utility:moneybag',   // or 'utility:file'
           product: 'utility:package',
           inventory: 'utility:archive',
           complaint:'utility:case',
           picklist: 'utility:list',
          'pick list': 'utility:list'
        };
        return ICON_MAP[label] || 'utility:chevronright';
    }

    handleClick(event) {
        event.preventDefault();
        event.stopPropagation();

        if (this.hasChildren) {
            this.isExpanded = !this.isExpanded;
            this.dispatchEvent(new CustomEvent('itemselected', {
                detail: { item: this.item },
                bubbles: true,
                composed: true
            }));
            return;
        }

        this.dispatchEvent(new CustomEvent('itemselected', {
            detail: { item: this.item },
            bubbles: true,
            composed: true
        }));

        // Already on this module: force list view (detail → list).
        if (this.isOnTargetPage) {
            window.dispatchEvent(new CustomEvent('portalshowlist'));
            return;
        }

        if (this.pageReference) {
            this[NavigationMixin.Navigate](this.pageReference);
        }
    }

    handleChildClick(event) {
        event.preventDefault();
        event.stopPropagation();
    
        const childId = event.currentTarget.dataset.childId;
        const child = (this.item.children || []).find(c => c.id === childId);
        if (!child) return;
    
        this.selectedStatus = child.status;
    
        this.dispatchEvent(new CustomEvent('itemselected', {
            detail: { item: child, status: child.status },
            bubbles: true,
            composed: true
        }));
    
        const target = this.item.target;
        if (!target) return;
    
        const baseUrl = target.startsWith('/')
            ? basePath + target
            : basePath + '/' + target;
    
        const url = baseUrl + '?status=' + encodeURIComponent(child.status);
    
        if (this.isOnTargetPage) {
            // ── Already on the Customer page: just update URL + broadcast live ──
            try {
                window.history.pushState({}, '', url);
            } catch (e) {
                // fallback if pushState fails for any reason
            }
    
            window.dispatchEvent(new CustomEvent('customerstatuschange', {
                detail: { status: child.status }
            }));
    
        } else {
            // ── Coming from a different page (e.g. Home): do a REAL navigation ──
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: { url }
            });
        }
    }
}