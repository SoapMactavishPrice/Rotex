({
    navigateToLC: function (component, event, helper) {
        var pageReference = {
            type: "standard__component",
            attributes: {
                componentName: "c__SubmitQuoteCaller"
            },
            state: {
                c__refRecordId: component.get("v.recordId")
            }
        };
        console.log('PARENT -> ', pageReference);
        component.set("v.pageReference", pageReference);
        const navService = component.find("navService");
        const pageRef = component.get("v.pageReference");
        const handleUrl = (url) => {
            window.open(url, '_self');
        };
        const handleError = (error) => {
            console.log(error);
        };
        console.log('PARENT -> ', pageReference);
        navService.generateUrl(pageRef).then(handleUrl, handleError);
    }
});