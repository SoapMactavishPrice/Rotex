@isTest
private class CreatePricingLeadAPITest {

    @isTest
    static void testCreateLeads() {

        // Prepare request payload
        String requestBody = JSON.serialize(
            new List<CreatePricingLeadAPI.LeadWrapper>{
                createLeadWrapper(
                    'John',
                    'ABC Pvt Ltd',
                    'Project A',
                    'Model-123',
                    'Test Remark',
                    'ASB File',
                    'Upload File'
                ),
                createLeadWrapper(
                    null,
                    null,
                    'Project B',
                    'Model-456',
                    'Remark 2',
                    'ASB File 2',
                    'Upload File 2'
                )
            }
        );

        // Set REST request
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/createPricingLead';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();

        List<Map<String, String>> response =
            CreatePricingLeadAPI.createLeads();

        Test.stopTest();

        // Verify response
        System.assertEquals(2, response.size());

        for(Map<String, String> res : response){
            System.assertEquals('Inserted', res.get('Status'));
            System.assertNotEquals(null, res.get('LeadId'));
        }

        // Verify Lead records inserted
        List<Lead> leads = [
            SELECT Id,
                   LastName,
                   Company,
                   Project_Name__c,
                  // Model_String_Required__c,
                   Remark__c,
                   ASB_Verified_Attachment__c,
                   Any_Upload__c
            FROM Lead
            WHERE Id IN :new Set<Id>{
                (Id)response[0].get('LeadId'),
                (Id)response[1].get('LeadId')
            }
        ];

        System.assertEquals(2, leads.size());

        Boolean foundDefaultLead = false;
        Boolean foundNormalLead = false;

        for(Lead l : leads){

            if(l.LastName == 'John'){
                foundNormalLead = true;

                System.assertEquals('ABC Pvt Ltd', l.Company);
                System.assertEquals('Project A', l.Project_Name__c);
                System.assertEquals('Test Remark', l.Remark__c);
                System.assertEquals('ASB File', l.ASB_Verified_Attachment__c);
                System.assertEquals('Upload File', l.Any_Upload__c);
            }

            if(l.LastName == '.'){
                foundDefaultLead = true;

                System.assertEquals('Default Company', l.Company);
                System.assertEquals('Project B', l.Project_Name__c);
            }
        }

        System.assert(foundNormalLead,
            'Lead with supplied LastName should be created');

        System.assert(foundDefaultLead,
            'Lead with default LastName and Company should be created');
    }

    private static CreatePricingLeadAPI.LeadWrapper createLeadWrapper(
        String lastName,
        String company,
        String projectName,
        String modelString,
        String remark,
        String asbAttachment,
        String anyUpload
    ){
        CreatePricingLeadAPI.LeadWrapper lw =
            new CreatePricingLeadAPI.LeadWrapper();

        lw.lastName = lastName;
        lw.company = company;
        lw.projectName = projectName;
        lw.modelString = modelString;
        lw.remark = remark;
        lw.asbAttachment = asbAttachment;
        lw.anyUpload = anyUpload;

        return lw;
    }
}