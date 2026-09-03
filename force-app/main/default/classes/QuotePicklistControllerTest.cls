@IsTest
private class QuotePicklistControllerTest {
    @TestSetup
    static void setupData() {
        User owner = [
            SELECT Id
            FROM User
            WHERE UserRoleId != null AND IsActive = true AND UserType = 'Standard'
            LIMIT 1
        ];

        System.runAs(owner) {
            Account partner = new Account(
                Name = 'Quote Picklist Partner',
                RecordTypeId = recordTypeId('Account', 'Channel_Partner'),
                OwnerId = owner.Id
            );
            insert partner;

            Account customer = new Account(
                Name = 'Quote Picklist Customer',
                RecordTypeId = recordTypeId('Account', 'Customer'),
                Channel_Partner__c = partner.Id,
                Channel_Partner_Name__c = partner.Id
            );
            insert customer;

            Contact portalContact = new Contact(
                FirstName = 'Quote',
                LastName = 'Picklist User',
                AccountId = partner.Id,
                Email = 'quotepicklist@test.example'
            );
            insert portalContact;

            Profile portalProfile = [
                SELECT Id
                FROM Profile
                WHERE Name IN ('Partner Community User', 'Partner Community Login User')
                LIMIT 1
            ];
            User portalUser = new User(
                Alias = 'qpick',
                Email = 'quotepicklist@test.example',
                EmailEncodingKey = 'UTF-8',
                LastName = 'QuotePicklistPortal',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = portalProfile.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                Username = 'quotepicklist' + DateTime.now().getTime() + '@test.example',
                ContactId = portalContact.Id,
                IsActive = true
            );
            insert portalUser;

            Product2 product = new Product2(
                Name = 'Quote Picklist Product',
                ProductCode = 'QP-001',
                IsActive = true
            );
            insert product;

            Inventory__c inventory = new Inventory__c(
                Product__c = product.Id,
                Channel_Partner__c = partner.Id
            );
            insert inventory;
            insert new Inventory_Transaction__c(
                Inventory__c = inventory.Id,
                Transaction_Type__c = 'GRN',
                Quantity__c = 25
            );

            Id pricebookId = Test.getStandardPricebookId();
            Opportunity opportunity = new Opportunity(
                Name = 'Quote Picklist Opportunity',
                StageName = 'Prospecting',
                CloseDate = Date.today(),
                AccountId = customer.Id,
                Pricebook2Id = pricebookId
            );
            insert opportunity;

            insert new Quote(
                Name = 'Quote Picklist Source',
                OpportunityId = opportunity.Id,
                Pricebook2Id = pricebookId,
                QuoteAccountId = customer.Id,
                Account__c = customer.Id,
                Quote_Type__c = 'Secondary Customer',
                Status = 'Accepted',
                OwnerId = portalUser.Id
            );
        }
    }

    @IsTest
    static void getProductsValidatesAndReturnsEmptyQuote() {
        User portalUser = [SELECT Id FROM User WHERE LastName = 'QuotePicklistPortal' LIMIT 1];
        Quote quote = [SELECT Id, Status, Quote_Type__c FROM Quote WHERE Name = 'Quote Picklist Source' LIMIT 1];

        System.runAs(portalUser) {
            try {
                QuotePicklistController.getQuoteProducts(null);
                System.assert(false, 'Null quote should be rejected.');
            } catch (AuraHandledException expected) {
                System.assert(true);
            }

            Test.startTest();
            List<QuotePicklistController.ProductRow> rows =
                QuotePicklistController.getQuoteProducts(quote.Id);
            Test.stopTest();
            System.assertEquals(0, rows.size());
        }
    }

    @IsTest
    static void buildsRowsFromQuoteProductsAndInventory() {
        Product2 product = [
            SELECT Id, Name, ProductCode
            FROM Product2
            WHERE Name = 'Quote Picklist Product'
            LIMIT 1
        ];
        Inventory__c inventory = [
            SELECT Id, Product__c, Product_Code__c, Available_Quantity__c
            FROM Inventory__c
            WHERE Product__c = :product.Id
            LIMIT 1
        ];

        QuoteLineItem firstLine = new QuoteLineItem(Product2Id = product.Id, Quantity = 3);
        firstLine.Product2 = product;
        QuoteLineItem secondLine = new QuoteLineItem(Product2Id = product.Id, Quantity = 2);
        secondLine.Product2 = product;

        List<QuotePicklistController.ProductRow> rows = QuotePicklistController.buildProductRows(
            new List<QuoteLineItem>{ firstLine, secondLine },
            new List<Inventory__c>{ inventory }
        );

        System.assertEquals(1, rows.size(), 'Duplicate quote products should be combined.');
        System.assertEquals(Decimal.valueOf(5), rows[0].quoteQty);
        System.assertEquals(inventory.Id, rows[0].inventoryId);
        System.assertEquals(product.ProductCode, rows[0].productCode);

        List<QuotePicklistController.ProductRow> withoutInventory =
            QuotePicklistController.buildProductRows(
                new List<QuoteLineItem>{ firstLine },
                new List<Inventory__c>()
            );
        System.assertEquals(1, withoutInventory.size());
        System.assertEquals(null, withoutInventory[0].inventoryId);
        System.assertEquals(Decimal.valueOf(0), withoutInventory[0].availableQty);
    }

    private static Id recordTypeId(String objectName, String developerName) {
        return [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = :objectName AND DeveloperName = :developerName
            LIMIT 1
        ].Id;
    }
}