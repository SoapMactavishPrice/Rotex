import { LightningElement } from 'lwc';
import doLogin from '@salesforce/apex/CommunityLoginController.doLogin';
import logo from '@salesforce/resourceUrl/RotexLogo';

export default class CustomLoginPage extends LightningElement {
    username = '';
    password = '';
    errorMessage = '';
    isLoading = false;
    showPassword = false;

    logoUrl = logo;

    get passwordFieldType() {
        return this.showPassword ? 'text' : 'password';
    }

    get passwordIcon() {
        return this.showPassword ? 'utility:hide' : 'utility:preview';
    }

    handleUsername(event) {
        this.username = event.target.value;
    }

    handlePassword(event) {
        this.password = event.target.value;
    }

    togglePasswordVisibility() {
        this.showPassword = !this.showPassword;
    }

    handleForgotPassword(event) {
        event.preventDefault();
        // e.g. /Rotex/login -> /Rotex -> /Rotex/ForgotPassword
        const basePath = window.location.pathname.replace(/\/login.*$/i, '');
        window.location.href = `${basePath}/ForgotPassword`;
    }

    handleLogin() {
        this.errorMessage = '';

        if (!this.username || !this.password) {
            this.errorMessage = 'Please enter username and password.';
            return;
        }

        this.isLoading = true;

        doLogin({
            username: this.username,
            password: this.password
        })
        .then(result => {
            if (result.status === 'SUCCESS') {
                window.location.replace(result.redirectUrl);
            } else {
                this.errorMessage = result.message;
            }
        })
        .catch(error => {
            this.errorMessage = error.body?.message || 'Login failed. Please try again.';
        })
        .finally(() => {
            this.isLoading = false;
        });
    }
}