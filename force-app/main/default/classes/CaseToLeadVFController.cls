public with sharing class CaseToLeadVFController {
    
    public Id caseId {get; set;}
    
    public CaseToLeadVFController(ApexPages.StandardController controller){
        caseId = controller.getId();
    }
    
    public PageReference process(){
        
        try {
            
            // 🔹 Fetch Case
            Case c = [
                SELECT Id, SuppliedName, SuppliedEmail, Subject, Description, Origin, AccountId, Account.Name
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
            
            // 🔹 Validate Email
            if(String.isBlank(c.SuppliedEmail)){
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR, 'Email is required on Case.'
                ));
                return null;
            }
            
            String email = c.SuppliedEmail.trim().toLowerCase();
            
            // 🔹 Check Existing Lead
            List<Lead> leads = [
                SELECT Id, OwnerId, Email, Case__c
                FROM Lead
                WHERE Email = :email
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            // =========================
            // ✅ CASE 1: NO LEAD FOUND
            // =========================
            if(leads.isEmpty()){
                
                Lead l = new Lead(
                    LastName = c.SuppliedName != null ? c.SuppliedName : 'Email Enq',
                    Company = 'No Company', // Account.Name
                    Email = email,
                    Requirement__c  = c.Description,
                    LeadSource = c.Origin,
                    Subject__c = c.Subject,
                    Case__c = c.Id
                );
                
                insert l;
                
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.CONFIRM, 'Lead Created Successfully.'
                ));
                
                // 🔁 Redirect to Lead
                PageReference pr = new PageReference('/' + l.Id);
                pr.setRedirect(true);
                return pr;
            }
            
            // =========================
            // ✅ CASE 2: LEAD EXISTS
            // =========================
            else {
                
                Lead existingLead = leads[0];
                
                // 🔹 Update Case lookup
                if(existingLead.Case__c != c.Id){
                    existingLead.Case__c = c.Id;
                    //existingLead.Subject__c = c.Subject;
                    update existingLead;
                }
                
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.CONFIRM,
                    'Existing Lead found. Case linked.'
                ));
                
                // 🔁 Redirect to Lead
                PageReference pr = new PageReference('/' + existingLead.Id);
                pr.setRedirect(true);
                return pr;
            }
            
        } catch (Exception e) {
            
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Error: ' + e.getMessage()
            ));
            
            return null;
        }
    }
}