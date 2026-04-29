@RestResource(urlMapping='/createPricingLead')
global with sharing class CreatePricingLeadAPI {

    @HttpPost
    global static List<Map<String, String>> createLeads() {

        String body = RestContext.request.requestBody.toString();

        List<LeadWrapper> leadList = (List<LeadWrapper>)
            JSON.deserialize(body, List<LeadWrapper>.class);

        List<Lead> insertLeadList = new List<Lead>();

        for (LeadWrapper lw : leadList) {

            Lead l = new Lead();

            // Mandatory fields
            l.LastName = lw.lastName != null ? lw.lastName : '.';
            l.Company = lw.company != null ? lw.company : 'Default Company';

            // Pricing fields
            l.Project_Name__c = lw.projectName;
            l.Model_String_Required__c = lw.modelString;
            l.Remark__c = lw.remark;
            l.ASB_Verified_Attachment__c = lw.asbAttachment;
            l.Any_Upload__c = lw.anyUpload;

            //l.LeadSource = 'Google Form - Pricing';

            insertLeadList.add(l);
        }

        insert insertLeadList;

        // Response
        List<Map<String, String>> response = new List<Map<String, String>>();

        for (Lead l : insertLeadList) {
            Map<String, String> res = new Map<String, String>();
            res.put('LeadId', l.Id);
            res.put('Status', 'Inserted');
            response.add(res);
        }

        return response;
    }

    // Wrapper class
    global class LeadWrapper {
        public String lastName;
        public String company;
        public String projectName;
        public String modelString;
        public String remark;
        public String asbAttachment;
        public String anyUpload;
    }
}