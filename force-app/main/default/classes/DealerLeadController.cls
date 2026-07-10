public without sharing class DealerLeadController {
    @AuraEnabled(cacheable=true)
    public static List<Lead> getMyAssignedLeads() {
        try {
            Id currentUserId = UserInfo.getUserId();
            List<Lead> result = [
                SELECT Id, Name, Email, Phone, Status, Company 
                FROM Lead 
                WHERE OwnerId = :currentUserId
                ORDER BY CreatedDate DESC
            ];
            // System.debug('Leads found:............ ' + result.size());
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching leads: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Lead> getLeadsByDealerAccount() {
    try {
        Id currentUserId = UserInfo.getUserId();
        
        List<User> users = [
            SELECT AccountId 
            FROM User 
            WHERE Id = :currentUserId 
            LIMIT 1
        ];
        // System.debug('Dealer AccountId: ' + users[0].AccountId);

        if (users.isEmpty() || users[0].AccountId == null) {
            return new List<Lead>();
        }
        
        Id dealerAccountId = users[0].AccountId;
        
        List<Lead> leads = [
          SELECT
    Id,
    Name,
    Company,
    Email,
    Phone,
    Website,
    Status,
    Rating,
    LeadSource,
    Industry,
    AnnualRevenue,
    NumberOfEmployees,
    CreatedDate,
    Description,

   Street,
    City,
    State,
    PostalCode,
    Country,

    Customer_Type__c,

    Owner.Name,

    Dealer__c,
    Dealer_Name__c,
    Territory__c,

    Product_Name__c,
    Product_Category__c,
    Product_Interested__c,

    Requirement__c,
    Dealer_Description__c,

    Sales_Turnover__c,
    Quantity__c,
    Quotation_Value__c,

    Application_Specification__c,
    Fluid_circuit_Functionality__c,

    Lead_Type__c,
    Submission_Date__c,
    Opening_Date__c,
    Receive_Date__c,

    Enq_No__c

FROM Lead
WHERE Dealer__c = :dealerAccountId
ORDER BY CreatedDate DESC
        ];
        
        // System.debug('Leads found: ' + leads.size());
        return leads;
        
    } catch (Exception e) {
        throw new AuraHandledException('Error: ' + e.getMessage());
    }
}
@AuraEnabled
public static void updateLeadStatus(
    Id leadId,
    String newStatus
) {

    Lead ld = [
        SELECT Id, Status
        FROM Lead
        WHERE Id = :leadId
        LIMIT 1
    ];

    ld.Status = newStatus;

    update ld;
}
}