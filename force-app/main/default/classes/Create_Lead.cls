@RestResource(urlMapping='/createLead')
global with sharing class Create_Lead {

    @HttpPost
    global static List<Map<String, String>> createLeads() {

        String body = RestContext.request.requestBody.toString();

        List<LeadWrapper> leadList = (List<LeadWrapper>) 
            JSON.deserialize(body, List<LeadWrapper>.class);

        List<Lead> leadsToInsert = new List<Lead>();

        for (LeadWrapper lw : leadList) {

            String firstName;
            String lastName;

		if (lw.name != null) {
			String nameTrimmed = lw.name.trim();

			if (nameTrimmed.contains(' ')) {
				List<String> parts = nameTrimmed.split('\\s+');
				firstName = parts[0];
				lastName = parts[1];
			} else {
				firstName = nameTrimmed;
				lastName = '.';
			}
		} else {
			firstName = null;
			lastName = '.';
		}

            Lead l = new Lead(
                FirstName = firstName,
                LastName = lastName,
                Email = lw.email,
                MobilePhone = lw.mobileNumber,
                Company = lw.companyName != null ? lw.companyName : 'Default Company',
                City = lw.city,
                State = lw.state,
                Country = lw.country
            );

            leadsToInsert.add(l);
        }

        insert leadsToInsert;

        List<Map<String, String>> response = new List<Map<String, String>>();
        for (Lead l : leadsToInsert) {
            Map<String, String> leadInfo = new Map<String, String>();
            leadInfo.put('Name', l.FirstName + ' ' + l.LastName);
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
    }
}