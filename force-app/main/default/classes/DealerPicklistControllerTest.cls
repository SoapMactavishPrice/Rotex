@IsTest
private class DealerPicklistControllerTest {

    @TestSetup
    static void setup() {
        // Existing internal user with a role owns the portal Account
        List<User> adminUsers = [
            SELECT Id
            FROM User
            WHERE UserRoleId != null
              AND IsActive = true
              AND UserType = 'Standard'
            LIMIT 1
        ];
        User runUser = adminUsers.isEmpty()
            ? new User(Id = UserInfo.getUserId())
            : adminUsers[0];

        System.runAs(runUser) {
            Id custRT = getRecordTypeId('Account', 'Customer');
            Id cpRT = getRecordTypeId('Account', 'Channel_Partner');

            Account cpAccount = new Account(Name = 'Test CP Account Unique');
            if (cpRT != null) {
                cpAccount.RecordTypeId = cpRT;
            }
            cpAccount.OwnerId = runUser.Id;
            insert cpAccount;

            Account secAccount = new Account(
                Name = 'Test Secondary Customer',
                Channel_Partner_Name__c = cpAccount.Id,
                BillingCity = 'SecCity'
            );
            if (custRT != null) {
                secAccount.RecordTypeId = custRT;
            }
            insert secAccount;

            Contact cpContact = new Contact(
                FirstName = 'CP',
                LastName = 'User',
                AccountId = cpAccount.Id,
                Email = 'cpuser123@test.com'
            );
            insert cpContact;

            Profile p = [
                SELECT Id
                FROM Profile
                WHERE Name IN ('Partner Community User', 'Partner Community Login User')
                LIMIT 1
            ];
            String uniqueName = String.valueOf(DateTime.now().getTime());
            User u = new User(
                Alias = 'cpuser',
                Email = 'cpuser123@test.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'User',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                Username = 'cpuser123' + uniqueName + '@testorg.com',
                ContactId = cpContact.Id,
                IsActive = true
            );
            insert u;

            Product2 p1 = new Product2(
                Name = 'Standard Valve',
                Family = 'Valves',
                IsActive = true,
                ProductCode = 'P-123'
            );
            insert p1;

            Inventory__c inv = new Inventory__c(
                Product__c = p1.Id,
                Channel_Partner__c = cpAccount.Id
            );
            insert inv;

            // Rollup Total_GRN_Quantity drives On Hand / Available (> 0 required by search)
            insert new Inventory_Transaction__c(
                Inventory__c = inv.Id,
                Transaction_Type__c = 'GRN',
                Quantity__c = 100
            );

            Picklist__c picklist = new Picklist__c(
                Channel_Partner__c = cpAccount.Id,
                Secondary_Customer__c = secAccount.Id,
                Pick_List_Date__c = Date.today(),
                OwnerId = u.Id
            );
            insert picklist;

            Pick_List_Line_Item__c plli = new Pick_List_Line_Item__c(
                Picklist__c = picklist.Id,
                Inventory__c = inv.Id,
                Product__c = p1.Id,
                Pick_Quantity__c = 5
            );
            insert plli;
        }
    }

    private static Id getRecordTypeId(String sObjectType, String developerName) {
        List<RecordType> rts = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = :sObjectType
              AND DeveloperName = :developerName
            LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }

    @IsTest
    static void testGetMyPicklists() {
        User u = [SELECT Id FROM User WHERE Email = 'cpuser123@test.com' LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            List<Picklist__c> picklists = DealerPicklistController.getMyPicklists();
            Test.stopTest();

            System.assertNotEquals(null, picklists);
            System.assertEquals(1, picklists.size(), 'Should return 1 picklist for the partner');
        }
    }

    @IsTest
    static void testGetMyPicklistsNoPartner() {
        Test.startTest();
        List<Picklist__c> picklists = DealerPicklistController.getMyPicklists();
        Test.stopTest();

        System.assertNotEquals(null, picklists);
    }

    @IsTest
    static void testGetPicklistById() {
        Picklist__c p = [SELECT Id FROM Picklist__c LIMIT 1];
        User u = [SELECT Id FROM User WHERE Email = 'cpuser123@test.com' LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            Picklist__c result = DealerPicklistController.getPicklistById(p.Id);
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertEquals(p.Id, result.Id);
        }
    }

    @IsTest
    static void testGetPicklistByIdExceptions() {
        User u = [SELECT Id FROM User WHERE Email = 'cpuser123@test.com' LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            try {
                DealerPicklistController.getPicklistById(null);
                System.assert(false, 'Should throw exception for null Id');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testGetPicklistLineItems() {
        Picklist__c p = [SELECT Id FROM Picklist__c LIMIT 1];
        User u = [SELECT Id FROM User WHERE Email = 'cpuser123@test.com' LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            List<Pick_List_Line_Item__c> items = DealerPicklistController.getPicklistLineItems(p.Id);
            List<Pick_List_Line_Item__c> nullItems = DealerPicklistController.getPicklistLineItems(null);
            Test.stopTest();

            System.assertNotEquals(null, items);
            System.assertEquals(1, items.size(), 'Should return 1 picklist line item');
            System.assertEquals(0, nullItems.size());
        }
    }

    @IsTest
    static void testAccountAndUserInfoGetters() {
        Account cpAccount = [SELECT Id, Name FROM Account WHERE Name = 'Test CP Account Unique' LIMIT 1];
        User u = [SELECT Id, FirstName, LastName, Name FROM User WHERE Email = 'cpuser123@test.com' LIMIT 1];

        System.runAs(u) {
            Id partnerId = DealerPicklistController.getMyChannelPartnerAccountId();
            String partnerName = DealerPicklistController.getMyChannelPartnerAccountName();
            String currentUserName = DealerPicklistController.getCurrentUserName();

            System.assertEquals(cpAccount.Id, partnerId);
            System.assertEquals(cpAccount.Name, partnerName);
            System.assertNotEquals(null, currentUserName);
        }

        String noPartnerName = DealerPicklistController.getMyChannelPartnerAccountName();
        System.assertEquals('', noPartnerName);
    }

    @IsTest
    static void testSearchSecondaryCustomers() {
        Account secAccount = [SELECT Id, Name FROM Account WHERE Name = 'Test Secondary Customer' LIMIT 1];
        User u = [SELECT Id FROM User WHERE Email = 'cpuser123@test.com' LIMIT 1];

        System.runAs(u) {
            List<DealerPicklistController.LookupOption> results = DealerPicklistController.searchSecondaryCustomers(
                'Secondary'
            );
            List<DealerPicklistController.LookupOption> noResults = DealerPicklistController.searchSecondaryCustomers(
                'XYZ'
            );

            System.assertNotEquals(null, results);
            System.assertEquals(1, results.size());
            System.assertEquals(secAccount.Id, results[0].id);
            System.assertEquals(secAccount.Name, results[0].label);
            System.assert(
                results[0].subLabel != null && results[0].subLabel.contains('SecCity'),
                'subLabel should include city: ' + results[0].subLabel
            );

            System.assertEquals(0, noResults.size());
        }

        List<DealerPicklistController.LookupOption> adminResults = DealerPicklistController.searchSecondaryCustomers(
            'Secondary'
        );
        System.assertEquals(0, adminResults.size());
    }

    @IsTest
    static void testGetItemTypeOptions() {
        Test.startTest();
        List<DealerPicklistController.PicklistOption> options = DealerPicklistController.getItemTypeOptions();
        Test.stopTest();

        System.assertNotEquals(null, options);
        System.assert(options.size() > 0, 'Should return at least the "All" option');
    }

    @IsTest
    static void testGetAvailableInventoryProducts() {
        Inventory__c inv = [SELECT Id, Available_Quantity__c, Channel_Partner__c FROM Inventory__c LIMIT 1];
        // Guaranty Available_Quantity__c > 0 for this org’s rollups
        insert new Inventory_Transaction__c(
            Inventory__c = inv.Id,
            Transaction_Type__c = 'GRN',
            Quantity__c = 200
        );
        inv = [SELECT Id, Available_Quantity__c FROM Inventory__c WHERE Id = :inv.Id];
        System.assert(
            inv.Available_Quantity__c != null && inv.Available_Quantity__c > 0,
            'Setup must yield Available_Quantity > 0, got: ' + inv.Available_Quantity__c
        );

        User u = [SELECT Id, AccountId FROM User WHERE Email = 'cpuser123@test.com' LIMIT 1];
        System.assertNotEquals(null, u.AccountId, 'Portal user must have AccountId');

        System.runAs(u) {
            Test.startTest();
            DealerPicklistController.ProductPage page1 = DealerPicklistController.getAvailableInventoryProducts(
                null,
                null,
                1,
                10
            );
            DealerPicklistController.ProductPage page2 = DealerPicklistController.getAvailableInventoryProducts(
                null,
                'Valve',
                null,
                null
            );
            DealerPicklistController.ProductPage page3 = DealerPicklistController.getAvailableInventoryProducts(
                'NonExistentItemType',
                'XYZ',
                0,
                100
            );
            Test.stopTest();

            System.assertNotEquals(null, page1);
            System.assertEquals(
                1,
                page1.products.size(),
                'Available inventory products for partner'
            );
            System.assertEquals(1, page1.totalCount);

            System.assertNotEquals(null, page2);
            System.assertEquals(1, page2.products.size());

            System.assertNotEquals(null, page3);
            System.assertEquals(0, page3.products.size());
            System.assertEquals(50, page3.pageSize);
        }
    }

    @IsTest
    static void testCreatePicklist() {
        Account secAccount = [SELECT Id FROM Account WHERE Name = 'Test Secondary Customer' LIMIT 1];
        Account cpAccount = [SELECT Id FROM Account WHERE Name = 'Test CP Account Unique' LIMIT 1];
        Inventory__c inv = [SELECT Id, Product__c FROM Inventory__c LIMIT 1];
        User u = [SELECT Id FROM User WHERE Email = 'cpuser123@test.com' LIMIT 1];

        DealerPicklistController.LineInput line = new DealerPicklistController.LineInput();
        line.inventoryId = inv.Id;
        line.productId = inv.Product__c;
        line.pickQuantity = 10;
        line.remarks = 'Test Line Remarks';

        DealerPicklistController.CreateInput input = new DealerPicklistController.CreateInput();
        input.channelPartnerId = cpAccount.Id;
        input.secondaryCustomerId = secAccount.Id;
        input.pickListDate = Date.today();
        input.requestedDeliveryDate = Date.today().addDays(5);
        input.remarks = 'Test Remarks';
        input.lines = new List<DealerPicklistController.LineInput>{ line };

        DealerPicklistController.CreateResult result;
        System.runAs(u) {
            Test.startTest();
            result = DealerPicklistController.createPicklist(input);
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertNotEquals(null, result.picklistId);
            System.assertNotEquals(null, result.picklistNumber);
        }

        Picklist__c createdPicklist = [
            SELECT Remarks__c, Secondary_Customer__c
            FROM Picklist__c
            WHERE Id = :result.picklistId
        ];
        System.assertEquals('Test Remarks', createdPicklist.Remarks__c);

        List<Pick_List_Line_Item__c> lines = [
            SELECT Pick_Quantity__c
            FROM Pick_List_Line_Item__c
            WHERE Picklist__c = :result.picklistId
        ];
        System.assertEquals(1, lines.size());
        System.assertEquals(10, lines[0].Pick_Quantity__c);
    }

    @IsTest
    static void testCreatePicklistExceptions() {
        Account cpAccount = [SELECT Id FROM Account WHERE Name = 'Test CP Account Unique' LIMIT 1];
        User u = [SELECT Id FROM User WHERE Email = 'cpuser123@test.com' LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            try {
                DealerPicklistController.createPicklist(null);
                System.assert(false, 'Should throw');
            } catch (AuraHandledException e) {
                System.assert(true);
            }

            DealerPicklistController.CreateInput input = new DealerPicklistController.CreateInput();
            input.channelPartnerId = cpAccount.Id;
            try {
                DealerPicklistController.createPicklist(input);
                System.assert(false, 'Should throw for missing lines');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
            Test.stopTest();
        }
    }
}