public with sharing class CaseToLeadVFController {
    public Id caseId          { get; set; }
    public String leadName    { get; set; }
    public String leadEmail   { get; set; }
    public String companyName { get; set; }
    public String leadSubject { get; set; }
    public String leadDescription { get; set; }
    public String leadSource  { get; set; }

    // Field-level error flags consumed by the VF page
    public Boolean nameError     { get; set; }
    public Boolean emailError    { get; set; }
    public String  emailErrorMsg { get; set; }

    private static final Pattern EMAIL_PATTERN =
        Pattern.compile('^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$');

    public CaseToLeadVFController(ApexPages.StandardController controller) {
        caseId        = controller.getId();
        nameError     = false;
        emailError    = false;
        emailErrorMsg = '';
        loadCaseDetails();
    }

    private void loadCaseDetails() {
        if (caseId == null) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR, 'No Case context found.'
            ));
            return;
        }
        try {
            Case c = [
                SELECT Id, SuppliedName, SuppliedEmail, Subject, Description, Origin, Account.Name
                FROM   Case
                WHERE  Id = :caseId
                WITH   SECURITY_ENFORCED
                LIMIT  1
            ];
            leadName        = c.SuppliedName;
            leadEmail       = c.SuppliedEmail;
            companyName     = (c.Account != null) ? c.Account.Name : '';
            leadSubject     = c.Subject;
            leadDescription = c.Description;
            leadSource      = c.Origin;
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Error loading Case details: ' + e.getMessage()
            ));
        }
    }

    public PageReference cancel() {
        PageReference pr = new PageReference('/' + caseId);
        pr.setRedirect(true);
        return pr;
    }

    public PageReference process() {
        // Reset field errors on each submission
        nameError     = false;
        emailError    = false;
        emailErrorMsg = '';

        Boolean hasError = false;

        // --- Name validation (required) ---
        if (String.isBlank(leadName)) {
            nameError = true;
            hasError  = true;
        }

        // --- Email validation ---
        if (String.isBlank(leadEmail)) {
            emailError    = true;
            emailErrorMsg = 'Email is required.';
            hasError      = true;
        } else {
            String trimmedEmail = leadEmail.trim();
            if (!EMAIL_PATTERN.matcher(trimmedEmail).matches()) {
                emailError    = true;
                emailErrorMsg = 'Please enter a valid email address.';
                hasError      = true;
            }
        }

        if (hasError) {
            return null;
        }

        try {
            String email = leadEmail.trim().toLowerCase();

            // --- Split full name into First / Last ---
            String firstName = '';
            String lastName  = 'Email Enq';
            if (String.isNotBlank(leadName)) {
                String[] parts = leadName.trim().split(' ', 2);
                if (parts.size() == 2) {
                    firstName = parts[0];
                    lastName  = parts[1];
                } else {
                    lastName = parts[0];
                }
            }

            List<Lead> leads = [
                SELECT Id, OwnerId, Email, Case__c
                FROM   Lead
                WHERE  Email = :email
                ORDER  BY CreatedDate DESC
                LIMIT  1
            ];

            if (leads.isEmpty()) {
                Lead l = new Lead(
                    FirstName = firstName,
                    LastName  = lastName,
                    Company   = String.isBlank(companyName) ? 'No Company' : companyName,
                    Email     = email,
                    Requirement__c = leadDescription,
                    LeadSource     = leadSource,
                    Subject__c     = leadSubject,
                    Case__c        = caseId
                );
                insert l;
                PageReference pr = new PageReference('/' + l.Id);
                pr.setRedirect(true);
                return pr;
            } else {
                Lead existingLead = leads[0];
                if (existingLead.Case__c != caseId) {
                    existingLead.Case__c = caseId;
                    update existingLead;
                }
                PageReference pr = new PageReference('/' + existingLead.Id);
                pr.setRedirect(true);
                return pr;
            }
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR, 'Error: ' + e.getMessage()
            ));
            return null;
        }
    }
}