public class CaseTriggerHandler {

    public static void createLeadFromCase(List<Case> newCases) {

        if (newCases == null || newCases.isEmpty()) {
            return;
        }

        Set<String> keywordNames = new Set<String>();
        Map<String, String> validLeadStates = new Map<String, String>();

        for (Keyword__c kw : [SELECT Name FROM Keyword__c WHERE Name != null]) {
            keywordNames.add(kw.Name.trim().toLowerCase());
        }

        for (Schema.PicklistEntry pe : Lead.StateCode.getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                validLeadStates.put(pe.getLabel().toLowerCase(), pe.getValue());
            }
        }

        if (keywordNames.isEmpty()) {
            return;
        }

        List<Lead> leadsToInsert = new List<Lead>();
        List<Case> casesToUpdate = new List<Case>();

        for (Case cs : newCases) {

            String subjectText = String.isNotBlank(cs.Subject) ? cs.Subject.toLowerCase() : '';

            String descriptionText = String.isNotBlank(cs.Description) ? cs.Description.toLowerCase() : '';

            Boolean keywordFound = false;

            for (String keyword : keywordNames) {
                if (
                    subjectText.contains(keyword) || descriptionText.contains(keyword)
                ) {
                    keywordFound = true;
                    break;
                }
            }

            if (keywordFound) {

                String companyName = extractCompanyFromDescription(cs.Description);
                String matchedStateCode = extractStateCodeFromDescription(cs.Description,validLeadStates);

                String firstName = '';
                String lastName = 'Email Enq';

                if (String.isNotBlank(cs.SuppliedName)) {
                    String[] parts = cs.SuppliedName.trim().split(' ', 2);

                    if (parts.size() == 2) {
                        firstName = parts[0];
                        lastName = parts[1];
                    } else {
                        lastName = parts[0];
                    }
                }

                Lead ld = new Lead(
                    FirstName = firstName,
                    LastName = lastName,
                    Company = String.isBlank(companyName) ? 'Unknown' : companyName,
                    Email = cs.SuppliedEmail,
                    Requirement__c = cs.Description,
                    LeadSource = cs.Origin,
                    Subject__c = cs.Subject,
                    Case__c = cs.Id,
                    //StateCode = matchedStateCode, // commented due to non available and failure
                    Auto_Created_From_Case__c = true
                );
                if (String.isNotBlank(matchedStateCode)) {
                    try {
                        ld.StateCode = matchedStateCode;
                    } catch (Exception e) {
                        System.debug('Invalid state skipped: ' + matchedStateCode);
                    }
                }
                leadsToInsert.add(ld);

                casesToUpdate.add(new Case(Id = cs.Id,Status = 'Potential'));
            }
        }

        if (!leadsToInsert.isEmpty()) {
            
            Database.SaveResult[] results = Database.insert(leadsToInsert, false);
            
            List<Lead> retryLeads = new List<Lead>();
            
            for (Integer i = 0; i < results.size(); i++) {
                
                if (!results[i].isSuccess()) {
                    
                    Boolean stateError = false;
                    
                    for (Database.Error err : results[i].getErrors()) {
                        if (err.getFields().contains('StateCode')) {
                            stateError = true;
                            break;
                        }
                    }
                    
                    if (stateError) {
                        Lead retryLead = leadsToInsert[i];
                        retryLead.StateCode = null;
                        retryLeads.add(retryLead);
                    }
                }
            }
            
            if (!retryLeads.isEmpty()) {
                insert retryLeads;
            }
        }

        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }
    }

    private static String extractCompanyFromDescription(String description) {

        if (String.isBlank(description)) {
            return 'Unknown';
        }

        List<String> lines = description.split('\n');

        for (Integer i = 0; i < lines.size(); i++) {

            String currentLine = lines[i] != null ? lines[i].trim().toLowerCase() : '';

            if (
                currentLine.contains('best regards') ||
                currentLine.contains('regards')
            ) {
                if (i + 2 < lines.size()) {
                    String companyLine = lines[i + 2].trim();

                    //if (String.isNotBlank(companyLine)) {
                        //return companyLine;
                    //} // commented due to failure
                    if (String.isNotBlank(companyLine)) {
                        
                        companyLine = companyLine.replaceAll('<[^>]*>', '');
                        companyLine = companyLine.replaceAll('http[s]?://\\S+', '');
                        companyLine = companyLine.trim();
                        
                        if(companyLine.length() > 255){
                            companyLine = companyLine.substring(0,255);
                        }
                        
                        return companyLine;
                    }
                }
            }
        }
        
        return 'Unknown';
    }
    
    private static String extractStateCodeFromDescription(
        String description,
        Map<String, String> validLeadStates
    ) {
        if (String.isBlank(description) || validLeadStates.isEmpty()) {
            return null;
        }
        
        List<State__c> stateMasters = [
            SELECT Name
            FROM State__c
            WHERE Name != null
        ];
        
        if (stateMasters.isEmpty()) {
            return null;
        }
        
        String descriptionText = description.toLowerCase();
        
        for (State__c st : stateMasters) {
            
            String stateName = st.Name != null ? st.Name.trim() : '';
            
            if (String.isBlank(stateName)) {
                continue;
            }
            
            if (descriptionText.contains(stateName.toLowerCase())) {
                
                if (validLeadStates.containsKey(stateName.toLowerCase())) {
                    return validLeadStates.get(stateName.toLowerCase());
                }
                
                return null;
            }
        }
        
        return null;
    }
}