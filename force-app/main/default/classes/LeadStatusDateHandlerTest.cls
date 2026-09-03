@IsTest
public class LeadStatusDateHandlerTest {

    @IsTest
    static void testApplyStatusDates_Insert() {
        // Test Insert scenario (oldMap is null)
        List<Lead> newLeads = new List<Lead>{
            new Lead(Dealer_Status__c = 'Work In Progress'),
            new Lead(Dealer_Status__c = 'Future Prospect'),
            new Lead(Dealer_Status__c = 'Contacted'),
            new Lead(Dealer_Status__c = 'New'),
            new Lead(Dealer_Status__c = 'Qualified'),
            new Lead(Dealer_Status__c = 'Regret')
        };
        
        Test.startTest();
        LeadStatusDateHandler.applyStatusDates(newLeads, null);
        Test.stopTest();
        
        System.assertNotEquals(null, newLeads[0].Work_In_Progress_Date_Time__c, 'WIP date should be set');
        System.assertNotEquals(null, newLeads[1].Future_Prospect_Date_Time__c, 'Future Prospect date should be set');
        System.assertNotEquals(null, newLeads[2].Contacted_Date_Time__c, 'Contacted date should be set');
        System.assertNotEquals(null, newLeads[3].New_Date_Time__c, 'New date should be set');
        System.assertNotEquals(null, newLeads[4].Qualified_Date_Time__c, 'Qualified date should be set');
        System.assertNotEquals(null, newLeads[5].Regret_Date_Time__c, 'Regret date should be set');
    }
    
    @IsTest
    static void testApplyStatusDates_InsertWithExistingValues() {
        // Test Insert scenario where dates are already provided (e.g. data migration)
        Datetime oldDt = Datetime.newInstance(2020, 1, 1);
        List<Lead> newLeads = new List<Lead>{
            new Lead(Dealer_Status__c = 'Work In Progress', Work_In_Progress_Date_Time__c = oldDt),
            new Lead(Dealer_Status__c = 'Future Prospect', Future_Prospect_Date_Time__c = oldDt),
            new Lead(Dealer_Status__c = 'Contacted', Contacted_Date_Time__c = oldDt),
            new Lead(Dealer_Status__c = 'New', New_Date_Time__c = oldDt),
            new Lead(Dealer_Status__c = 'Qualified', Qualified_Date_Time__c = oldDt),
            new Lead(Dealer_Status__c = 'Regret', Regret_Date_Time__c = oldDt)
        };
        
        Test.startTest();
        LeadStatusDateHandler.applyStatusDates(newLeads, null);
        Test.stopTest();
        
        // Assert that the dates were not overridden
        System.assertEquals(oldDt, newLeads[0].Work_In_Progress_Date_Time__c, 'WIP date should remain unchanged');
        System.assertEquals(oldDt, newLeads[1].Future_Prospect_Date_Time__c, 'Future Prospect date should remain unchanged');
        System.assertEquals(oldDt, newLeads[2].Contacted_Date_Time__c, 'Contacted date should remain unchanged');
        System.assertEquals(oldDt, newLeads[3].New_Date_Time__c, 'New date should remain unchanged');
        System.assertEquals(oldDt, newLeads[4].Qualified_Date_Time__c, 'Qualified date should remain unchanged');
        System.assertEquals(oldDt, newLeads[5].Regret_Date_Time__c, 'Regret date should remain unchanged');
    }

    @IsTest
    static void testApplyStatusDates_Update() {
        // Test Update scenario (oldMap is provided)
        // Generate a fake Lead Id for mapping
        Id fakeLeadId = '00Q000000000000EAA';
        
        Lead oldLead = new Lead(Id = fakeLeadId, Dealer_Status__c = 'New');
        Map<Id, Lead> oldMap = new Map<Id, Lead>{ oldLead.Id => oldLead };
        
        List<Lead> newLeads = new List<Lead>{
            new Lead(Id = fakeLeadId, Dealer_Status__c = 'Work In Progress')
        };
        
        Test.startTest();
        LeadStatusDateHandler.applyStatusDates(newLeads, oldMap);
        Test.stopTest();
        
        System.assertNotEquals(null, newLeads[0].Work_In_Progress_Date_Time__c, 'WIP date should be updated on status change');
    }
    
    @IsTest
    static void testApplyStatusDates_NoStatusChange() {
        // Test when status does not change
        Id fakeLeadId = '00Q000000000000EAA';
        
        Lead oldLead = new Lead(Id = fakeLeadId, Dealer_Status__c = 'New');
        Map<Id, Lead> oldMap = new Map<Id, Lead>{ oldLead.Id => oldLead };
        
        List<Lead> newLeads = new List<Lead>{
            new Lead(Id = fakeLeadId, Dealer_Status__c = 'New') // Status is the same
        };
        
        Test.startTest();
        LeadStatusDateHandler.applyStatusDates(newLeads, oldMap);
        Test.stopTest();
        
        // Ensure New_Date_Time__c wasn't updated because status didn't change
        System.assertEquals(null, newLeads[0].New_Date_Time__c, 'Date should not be stamped if status did not change');
    }
    
    @IsTest
    static void testApplyStatusDates_NullList() {
        Test.startTest();
        LeadStatusDateHandler.applyStatusDates(null, null);
        LeadStatusDateHandler.applyStatusDates(new List<Lead>(), null);
        LeadStatusDateHandler.applyStatusDates(new List<Lead>{ null }, null);
        Test.stopTest();
        
        // Should not throw exceptions
        System.assert(true, 'Method should handle nulls gracefully');
    }
}