@RestResource(urlMapping='/createLead')
global with sharing class Create_Lead {

    @HttpPost
    global static List<Map<String, String>> createLeads() {

        String body = RestContext.request.requestBody.toString();

        List<LeadWrapper> leadList = (List<LeadWrapper>) 
            JSON.deserialize(body, List<LeadWrapper>.class);

        Set<String> phoneSet = new Set<String>();

        for (LeadWrapper lw : leadList) {
            if (lw.mobileNumber != null) {
                phoneSet.add(lw.mobileNumber.trim());
            }
        }

        Map<String, Lead> existingLeadMap = new Map<String, Lead>();

        if (!phoneSet.isEmpty()) {
            for (Lead l : [SELECT Id, MobilePhone FROM Lead WHERE MobilePhone IN :phoneSet]) {
                existingLeadMap.put(l.MobilePhone, l);
            }
        }

        List<Lead> upsertLeadList = new List<Lead>();

        for (LeadWrapper lw : leadList) {

            String phone = lw.mobileNumber != null ? lw.mobileNumber.trim() : null;

            Lead l = new Lead();

            if (phone != null && existingLeadMap.containsKey(phone)) {
                l.Id = existingLeadMap.get(phone).Id;
            }

            String firstName;
            String lastName;

            if (lw.name != null) {
                String nameTrimmed = lw.name.trim();
                if (nameTrimmed.contains(' ')) {
                    List<String> parts = nameTrimmed.split('\\s+');
                    firstName = parts[0];
                    lastName = parts.size() > 1 ? parts[1] : '.';
                } else {
                    firstName = nameTrimmed;
                    lastName = '.';
                }
            } else {
                firstName = null;
                lastName = '.';
            }

            l.FirstName = firstName;
            l.LastName = lastName;
            l.Email = lw.email;
            l.MobilePhone = phone;
            l.Company = lw.companyName != null ? lw.companyName : 'Default Company';
            l.City = lw.city;
            l.State = lw.state;
            l.Country = lw.country;
            l.Requirement__c = lw.requirement;
            l.LeadSource = 'WA AI Sales Bot';

            upsertLeadList.add(l);
        }

        upsert upsertLeadList;

        List<Map<String, String>> response = new List<Map<String, String>>();
        for (Lead l : upsertLeadList) {
            Map<String, String> leadInfo = new Map<String, String>();
            leadInfo.put('Name', (l.FirstName != null ? l.FirstName : '') + ' ' + l.LastName);
            leadInfo.put('Id', l.Id);
            response.add(leadInfo);
        }

        return response;
    }

    global class LeadWrapper {
        public String name;
        public String email;
        public String mobileNumber;
        public String companyName;
        public String city;
        public String state;
        public String country;
        public String requirement;
    }
}