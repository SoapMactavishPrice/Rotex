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

    public String countryCode {get; set;}
    public String stateCode   {get; set;}
    public String city        {get; set;}

    public List<SelectOption> countryOptions {get; set;}
    public List<SelectOption> stateOptions   {get; set;}

    private static final String INDIA_COUNTRY_CODE = 'IN';
    private static final Pattern EMAIL_PATTERN =
        Pattern.compile('^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$');

    public CaseToLeadVFController(ApexPages.StandardController controller) {
        caseId        = controller.getId();
        nameError     = false;
        emailError    = false;
        emailErrorMsg = '';
        loadCaseDetails();

        countryOptions = new List<SelectOption>();
        countryOptions.add(new SelectOption('', '--None--'));

        for (Schema.PicklistEntry p : Lead.CountryCode.getDescribe().getPicklistValues()) {
            if (p.isActive()) {
                countryOptions.add(new SelectOption(p.getValue(), p.getLabel()));
            }
        }

        stateOptions = new List<SelectOption>();
        stateOptions.add(new SelectOption('', '--None--'));
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
                SELECT Id, SuppliedName, SuppliedEmail, Subject, Description, Origin, Account.Name, Status
                FROM   Case
                WHERE  Id = :caseId
                WITH   SECURITY_ENFORCED
                LIMIT  1
            ];
            
            if (c.Status == 'Potential' || c.Status == 'Non Potential') {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Status already set to ' + c.Status + '. Cannot create lead.'
                ));
                return;
            }
            
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
                ORDER BY CreatedDate DESC
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
                    Case__c        = caseId,
                    CountryCode = countryCode,
                    StateCode   = stateCode,
                    City        = city
                );
                insert l;

                Case currentCase = new Case();
                currentCase.Id = caseId;
                currentCase.Status = 'Potential';
                update currentCase;

                PageReference pr = new PageReference('/' + l.Id);
                pr.setRedirect(true);
                return pr;
            } else {
                Lead existingLead = leads[0];
                if (existingLead.Case__c != caseId) {
                    existingLead.Case__c = caseId;
                    update existingLead;
                }

                Case currentCase = new Case();
                currentCase.Id = caseId;
                currentCase.Status = 'Potential';
                update currentCase;

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

    public void updateStates() {
        stateOptions = new List<SelectOption>();
        stateOptions.add(new SelectOption('', '--None--'));

        if (this.getIsIndiaSelected()) {

            Integer indiaIndex = -1;
            List<Schema.PicklistEntry> countryEntries =
                Lead.CountryCode.getDescribe().getPicklistValues();

            for (Integer i = 0; i < countryEntries.size(); i++) {
                if (countryEntries[i].getValue() == INDIA_COUNTRY_CODE) {
                    indiaIndex = i;
                    break;
                }
            }

            if (indiaIndex >= 0) {
                for (Schema.PicklistEntry s : Lead.StateCode.getDescribe().getPicklistValues()) {
                    if (s.isActive() && isValidForIndex(s, indiaIndex)) {
                        stateOptions.add(new SelectOption(s.getValue(), s.getLabel()));
                    }
                }
            }
        } else {
            stateCode = '';
        }
    }

    public Boolean getIsIndiaSelected() {
        return countryCode == INDIA_COUNTRY_CODE;
    }
    
    private Boolean isValidForIndex(Schema.PicklistEntry entry, Integer index) {
        Map<String, Object> entryMap = 
            (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(entry));

        String validForEncoded = (String) entryMap.get('validFor');
        if (String.isBlank(validForEncoded)) return false;

        Blob   validForBlob = EncodingUtil.base64Decode(validForEncoded);
        String hexString    = EncodingUtil.convertToHex(validForBlob);

        Integer byteIndex = index / 8;
        Integer bitIndex  = 7 - Math.mod(index, 8);

        if (byteIndex * 2 + 2 > hexString.length()) return false;

        String  hexByte = hexString.substring(byteIndex * 2, byteIndex * 2 + 2).toUpperCase();
        Integer byteVal = hexCharToInt(hexByte.charAt(0)) * 16 
                        + hexCharToInt(hexByte.charAt(1));

        return (byteVal & (1 << bitIndex)) != 0;
    }

    private Integer hexCharToInt(Integer c) {
        if (c >= 48 && c <= 57)  return c - 48;       // '0'–'9'
        if (c >= 65 && c <= 70)  return c - 55;       // 'A'–'F'
        if (c >= 97 && c <= 102) return c - 87;       // 'a'–'f'
        return 0;
    }

}
