@isTest
public class OpportunityPricebookTriggerTest {
    
    @testSetup
    static void setupTestData() {
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User domesticUser = new User(
            Alias = 'domusr',
            Email = 'domestic@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'DomesticUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'domestic@test.com',
            Division__c = 'Domestic'
        );
        
        User exportUser = new User(
            Alias = 'expusr',
            Email = 'export@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'ExportUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'export@test.com',
            Division__c = 'Export'
        );
        
        User bothUser = new User(
            Alias = 'bothsr',
            Email = 'both@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'BothUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'both@test.com',
            Division__c = 'Both'
        );
        
        User noDivisionUser = new User(
            Alias = 'nodiv',
            Email = 'nodivision@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'NoDivisionUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'nodivision@test.com',
            Division__c = null
        );
        
        insert new List<User>{domesticUser, exportUser, bothUser, noDivisionUser};
        
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        Sales_Area_Item__c salesAreaDC10_INR = new Sales_Area_Item__c(
            Account__c = testAccount.Id,
            Sales_Org__c = '1100',
            Distribution_Channel__c = '10',
            Division__c = '10',
            CurrencyIsoCode = 'INR'
        );
        
        Sales_Area_Item__c salesAreaDC10_USD = new Sales_Area_Item__c(
            Account__c = testAccount.Id,
            Sales_Org__c = '1100',
            Distribution_Channel__c = '10',
            Division__c = '10',
            CurrencyIsoCode = 'USD'
        );
        
        Sales_Area_Item__c salesAreaDC20_EUR = new Sales_Area_Item__c(
            Account__c = testAccount.Id,
            Sales_Org__c = '1100',
            Distribution_Channel__c = '20',
            Division__c = '10',
            CurrencyIsoCode = 'EUR'
        );
        
        Sales_Area_Item__c salesAreaDC20_USD = new Sales_Area_Item__c(
            Account__c = testAccount.Id,
            Sales_Org__c = '1100',
            Distribution_Channel__c = '20',
            Division__c = '10',
            CurrencyIsoCode = 'USD'
        );
        
        insert new List<Sales_Area_Item__c>{
            salesAreaDC10_INR, 
            salesAreaDC10_USD, 
            salesAreaDC20_EUR, 
            salesAreaDC20_USD
        };
        
        Pricebook2 pbDC10 = new Pricebook2(
            Name = 'Test Pricebook DC10',
            IsActive = true,
            Distribution_Channel__c = '10'
        );
        
        Pricebook2 pbDC20 = new Pricebook2(
            Name = 'Test Pricebook DC20',
            IsActive = true,
            Distribution_Channel__c = '20'
        );
        
        insert new List<Pricebook2>{pbDC10, pbDC20};
    }
    
    @isTest
    static void testDomesticUserWithDC10() {
        User domesticUser = [SELECT Id FROM User WHERE Username = 'domestic@test.com' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        System.runAs(domesticUser) {
            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity',
                AccountId = testAccount.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            );
            
            Test.startTest();
            insert opp;
            Test.stopTest();
        }
    }
    
    @isTest
    static void testExportUserWithDC20() {
        User exportUser = [SELECT Id FROM User WHERE Username = 'export@test.com' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        System.runAs(exportUser) {
            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity',
                AccountId = testAccount.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            );
            
            Test.startTest();
            insert opp;
            Test.stopTest();
        }
    }
    
    @isTest
    static void testBothUserWithDC10() {
        User bothUser = [SELECT Id FROM User WHERE Username = 'both@test.com' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        System.runAs(bothUser) {
            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity',
                AccountId = testAccount.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            );
            
            Test.startTest();
            insert opp;
            Test.stopTest();
        }
    }
    
    @isTest
    static void testUserWithNoDivision() {
        User noDivisionUser = [SELECT Id FROM User WHERE Username = 'nodivision@test.com' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        System.runAs(noDivisionUser) {
            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity',
                AccountId = testAccount.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            );
            
            Test.startTest();
            try {
                insert opp;
            } catch(DmlException e) {
                System.assert(e.getMessage().contains('User Division is not set'));
            }
            Test.stopTest();
        }
    }
    
    @isTest
    static void testAccountWithNoSalesArea() {
        User domesticUser = [SELECT Id FROM User WHERE Username = 'domestic@test.com' LIMIT 1];
        
        Account noSalesAreaAccount = new Account(Name = 'No Sales Area Account');
        insert noSalesAreaAccount;
        
        System.runAs(domesticUser) {
            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity',
                AccountId = noSalesAreaAccount.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            );
            
            Test.startTest();
            try {
                insert opp;
            } catch(DmlException e) {
                System.assert(e.getMessage().contains('No Sales Area Item found'));
            }
            Test.stopTest();
        }
    }
    
    @isTest
    static void testAccountWithNoMatchingDC() {
        User exportUser = [SELECT Id FROM User WHERE Username = 'export@test.com' LIMIT 1];
        
        Account accountWithDC10Only = new Account(Name = 'Account DC10 Only');
        insert accountWithDC10Only;
        
        Sales_Area_Item__c salesAreaDC10 = new Sales_Area_Item__c(
            Account__c = accountWithDC10Only.Id,
            Sales_Org__c = '1100',
            Distribution_Channel__c = '10',
            Division__c = '10',
            CurrencyIsoCode = 'INR'
        );
        insert salesAreaDC10;
        
        System.runAs(exportUser) {
            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity',
                AccountId = accountWithDC10Only.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            );
            
            Test.startTest();
            try {
                insert opp;
            } catch(DmlException e) {
                System.assert(e.getMessage().contains('No Sales Area Item found'));
            }
            Test.stopTest();
        }
    }
    
    @isTest
    static void testDomesticUserWithDC20Only() {
        User domesticUser = [SELECT Id FROM User WHERE Username = 'domestic@test.com' LIMIT 1];
        
        Account accountWithDC20Only = new Account(Name = 'Account DC20 Only');
        insert accountWithDC20Only;
        
        Sales_Area_Item__c salesAreaDC20 = new Sales_Area_Item__c(
            Account__c = accountWithDC20Only.Id,
            Sales_Org__c = '1100',
            Distribution_Channel__c = '20',
            Division__c = '10',
            CurrencyIsoCode = 'EUR'
        );
        insert salesAreaDC20;
        
        System.runAs(domesticUser) {
            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity',
                AccountId = accountWithDC20Only.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            );
            
            Test.startTest();
            try {
                insert opp;
            } catch(DmlException e) {
                System.assert(e.getMessage().contains('No Sales Area Item found'));
            }
            Test.stopTest();
        }
    }
}