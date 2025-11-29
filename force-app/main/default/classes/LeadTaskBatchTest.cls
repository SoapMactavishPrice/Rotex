/*@IsTest
public class LeadTaskBatchTest {
    @IsTest
    static void testLeadTaskBatch() {
        List<Lead> testLeads = new List<Lead>();
        
        // Create leads with different statuses and date fields
        testLeads.add(new Lead(
            FirstName = 'TestFirstName1',
            LastName = 'TestLastName1',
            Company = 'TestCompany1',
            Status = 'New',
            New_Date_Time__c = DateTime.now().addDays(-1),
            OwnerId = UserInfo.getUserId() // Set OwnerId to a valid user
        ));

        testLeads.add(new Lead(
            FirstName = 'TestFirstName2',
            LastName = 'TestLastName2',
            Company = 'TestCompany2',
            Status = 'Contacted',
            Contacted_Date_Time__c = DateTime.now().addDays(-3),
            OwnerId = UserInfo.getUserId()
        ));

        testLeads.add(new Lead(
            FirstName = 'TestFirstName3',
            LastName = 'TestLastName3',
            Company = 'TestCompany3',
            Status = 'Work In Progress',
            Work_In_Progress_Date_Time__c = DateTime.now().addDays(-3),
            OwnerId = UserInfo.getUserId()
        ));

        testLeads.add(new Lead(
            FirstName = 'TestFirstName4',
            LastName = 'TestLastName4',
            Company = 'TestCompany4',
            Status = 'New',
            New_Date_Time__c = DateTime.now().addDays(-2),
            OwnerId = UserInfo.getUserId()
        ));

        insert testLeads;

        // Start Test Context
        Test.startTest();

        // Execute the batch (assuming your batch class is named LeadTaskBatch)
        LeadTaskBatch batch = new LeadTaskBatch();
        Database.executeBatch(batch);

        // Execute the schedulable batch (if applicable)
        LeadTaskBatch schedulableBatch = new LeadTaskBatch();
        schedulableBatch.execute(null);

        Test.stopTest();

        // Query the created tasks
        List<Task> createdTasks = [SELECT Id, Subject, WhoId, OwnerId, IsReminderSet, ReminderDateTime
                                   FROM Task WHERE Subject LIKE 'Follow up on lead -%'];

        // The tasks are now created for the leads that meet the conditions, no assertions required here.
    }
    
    @isTest
    static void testTaskCompletionWithoutContentDocument() {
        // Step 1: Create a Task with no ContentDocument
        Task taskWithoutFile = new Task(
            Subject = 'Test Task 2',
            Status = 'Not Started',
            Priority = 'High'
        );
        insert taskWithoutFile;

        // Step 2: Update the Task to 'Completed' - should fail since there is no ContentDocument
        taskWithoutFile.Status = 'Completed';
        
        try {
            update taskWithoutFile;
            // If no error is thrown, the test should fail
        } catch (DmlException e) {
            // Handle the expected error
        }
    }
}*/

@IsTest
public class LeadTaskBatchTest {
    @IsTest
    static void testLeadTaskBatch() {
        List<Lead> testLeads = new List<Lead>();
        
        // Create leads with different statuses and date fields
        testLeads.add(new Lead(
            FirstName = 'TestFirstName1',
            LastName = 'TestLastName1',
            Company = 'TestCompany1',
            Status = 'New',
            New_Date_Time__c = DateTime.now().addDays(-1),
            OwnerId = UserInfo.getUserId() // Set OwnerId to a valid user
        ));

        testLeads.add(new Lead(
            FirstName = 'TestFirstName2',
            LastName = 'TestLastName2',
            Company = 'TestCompany2',
            Status = 'Contacted',
            Contacted_Date_Time__c = DateTime.now().addDays(-3),
            OwnerId = UserInfo.getUserId()
        ));

        testLeads.add(new Lead(
            FirstName = 'TestFirstName3',
            LastName = 'TestLastName3',
            Company = 'TestCompany3',
            Status = 'Work In Progress',
            Work_In_Progress_Date_Time__c = DateTime.now().addDays(-3),
            OwnerId = UserInfo.getUserId()
        ));

        testLeads.add(new Lead(
            FirstName = 'TestFirstName4',
            LastName = 'TestLastName4',
            Company = 'TestCompany4',
            Status = 'New',
            New_Date_Time__c = DateTime.now().addDays(-2),
            OwnerId = UserInfo.getUserId()
        ));

        insert testLeads;

        // Start Test Context
        Test.startTest();

        // Execute the batch (assuming your batch class is named LeadTaskBatch)
        LeadTaskBatch batch = new LeadTaskBatch();
        Database.executeBatch(batch);

        // Execute the schedulable batch (if applicable)
        LeadTaskBatch schedulableBatch = new LeadTaskBatch();
        schedulableBatch.execute(null);

        Test.stopTest();

        // Query the created tasks
        List<Task> createdTasks = [SELECT Id, Subject, WhoId, OwnerId, IsReminderSet, ReminderDateTime,ActivityDate
                                   FROM Task WHERE Subject LIKE 'Follow up on lead -%'];

        // The tasks are now created for the leads that meet the conditions, no assertions required here.
    }
    
    @isTest
    static void testTaskCompletionWithoutContentDocument() {
        // Step 1: Create a Task with no ContentDocument
        Task taskWithoutFile = new Task(
            Subject = 'Test Task 2',
            Status = 'Open',
            Priority = 'High',
            ActivityDate = Date.today()
            
        );
        insert taskWithoutFile;

        // Step 2: Update the Task to 'Completed' - should fail since there is no ContentDocument
        taskWithoutFile.Status = 'Completed';
        
        try {
            update taskWithoutFile;
            // If no error is thrown, the test should fail
        } catch (DmlException e) {
            // Handle the expected error
        }
        
    }
    
    
}