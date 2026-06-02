@isTest
private class Create_Lead_Test {

    @isTest
    static void testCreateAndUpdateLeads() {

        // Existing Lead for update scenario
        Lead existingLead = new Lead(
            FirstName = 'Old',
            LastName = 'Lead',
            Company = 'Old Company',
            MobilePhone = '9999999999'
        );
        insert existingLead;

        String requestBody = JSON.serialize(
            new List<Create_Lead.LeadWrapper>{

                // Update existing lead
                createWrapper(
                    'John Doe',
                    'john@test.com',
                    '9999999999',
                    'ABC Company',
                    'Mumbai',
                    'Maharashtra',
                    'India',
                    'Pricing Request'
                ),

                // Insert new lead with single name
                createWrapper(
                    'Ankit',
                    'ankit@test.com',
                    '8888888888',
                    'XYZ Company',
                    'Pune',
                    'Maharashtra',
                    'India',
                    'Product Inquiry'
                ),

                // Insert new lead with null name
                createWrapper(
                    null,
                    'noname@test.com',
                    '7777777777',
                    null,
                    'Delhi',
                    'Delhi',
                    'India',
                    'General Requirement'
                )
            }
        );

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/createLead';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();

        List<Map<String,String>> result =
            Create_Lead.createLeads();

        Test.stopTest();

        System.assertEquals(3, result.size());

        // Verify update happened
        Lead updatedLead = [
            SELECT Id,
                   FirstName,
                   LastName,
                   Email,
                   Company,
                   City,
                   State,
                   Country,
                   Requirement__c,
                   LeadSource
            FROM Lead
            WHERE Id = :existingLead.Id
        ];

        System.assertEquals('John', updatedLead.FirstName);
        System.assertEquals('Doe', updatedLead.LastName);
        System.assertEquals('john@test.com', updatedLead.Email);
        System.assertEquals('ABC Company', updatedLead.Company);
        System.assertEquals('WA AI Sales Bot', updatedLead.LeadSource);

        // Verify single-word name logic
        Lead singleNameLead = [
            SELECT FirstName,
                   LastName,
                   Company,
                   MobilePhone
            FROM Lead
            WHERE MobilePhone = '8888888888'
            LIMIT 1
        ];

        System.assertEquals('Ankit', singleNameLead.FirstName);
        System.assertEquals('.', singleNameLead.LastName);
        System.assertEquals('XYZ Company', singleNameLead.Company);

        // Verify null name + default company logic
        Lead nullNameLead = [
            SELECT FirstName,
                   LastName,
                   Company,
                   MobilePhone
            FROM Lead
            WHERE MobilePhone = '7777777777'
            LIMIT 1
        ];

        System.assertEquals(null, nullNameLead.FirstName);
        System.assertEquals('.', nullNameLead.LastName);
        System.assertEquals('Default Company', nullNameLead.Company);

        // Verify response contains IDs
        for(Map<String,String> m : result){
            System.assertNotEquals(null, m.get('Id'));
        }
    }

    private static Create_Lead.LeadWrapper createWrapper(
        String name,
        String email,
        String mobile,
        String company,
        String city,
        String state,
        String country,
        String requirement
    ){
        Create_Lead.LeadWrapper w =
            new Create_Lead.LeadWrapper();

        w.name = name;
        w.email = email;
        w.mobileNumber = mobile;
        w.companyName = company;
        w.city = city;
        w.state = state;
        w.country = country;
        w.requirement = requirement;

        return w;
    }
}