@RestResource(urlMapping='/createPricingLead')
global with sharing class CreatePricingLeadAPI {
    @HttpPost
    global static List<Map<String, String>> createLeads() {
        API_log__c apiLog = new API_log__c();
        apiLog.Api_Name__c = 'PricingLeadAPi';
        String body = RestContext.request.requestBody.toString();
        apiLog.Request__c = body;
        
        List<Map<String, String>> response = new List<Map<String, String>>();
        
        try {
            List<LeadWrapper> leadList = (List<LeadWrapper>)
                JSON.deserialize(body, List<LeadWrapper>.class);
            
            List<Lead> insertLeadList = new List<Lead>();
            for (LeadWrapper lw : leadList) {
                Lead l = new Lead();
                l.LastName  = lw.lastName != null ? lw.lastName : '.';
                l.Company   = lw.company  != null ? lw.company  : 'Default Company';
                l.Project_Name__c            = lw.projectName;
                l.Model_String_Required__c   = lw.modelString;
                l.Remark__c                  = lw.remark;
                l.ASB_Verified_Attachment__c = lw.asbAttachment;
                l.Any_Upload__c              = lw.anyUpload;
                l.Email                      = lw.email;
                l.LeadSource                 = 'Google Form - Pricing';
                insertLeadList.add(l);
            }
            
            insert insertLeadList;
            
            for (Lead l : insertLeadList) {
                Map<String, String> res = new Map<String, String>();
                res.put('LeadId', l.Id);
                res.put('Status', 'Inserted');
                response.add(res);
            }
            
            apiLog.Response__c    = JSON.serialize(response);
            apiLog.Status_Code__c = '200';
            apiLog.Status__c      = 'Success';   // ✅ Success status
            
        } catch (Exception e) {
            apiLog.Status_Code__c = '500';
            apiLog.Status__c      = 'Failure';   // ✅ Failure status
            apiLog.Response__c    = 'Error: '    + e.getMessage()
                + ' | Line: '  + e.getLineNumber()
                + ' | Stack: ' + e.getStackTraceString();
            RestContext.response.statusCode = 500;
            
        } finally {
            insert apiLog;           // ✅ Always inserted — success or failure
        }
        
        return response;
    }
    
    global class LeadWrapper {
        public String lastName;
        public String company;
        public String projectName;
        public String modelString;
        public String remark;
        public String asbAttachment;
        public String anyUpload;
        public String email;
    }
}