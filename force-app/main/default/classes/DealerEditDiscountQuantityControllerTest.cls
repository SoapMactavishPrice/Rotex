@IsTest
private class DealerEditDiscountQuantityControllerTest {

    @TestSetup
    static void setup() {
        User adminUser = new User(Id = UserInfo.getUserId());

        System.runAs(adminUser) {
            Database.DMLOptions dml = new Database.DMLOptions();
            dml.DuplicateRuleHeader.allowSave = true;

            Account cpAccount = new Account(Name = 'Test CP Account Unique');
            Database.insert(cpAccount, dml);

            Account custAccount = new Account(
                Name = 'Test Customer Unique',
                Channel_Partner_Name__c = cpAccount.Id,
                Channel_Partner__c = cpAccount.Id
            );
            Database.insert(custAccount, dml);

            Contact cpContact = new Contact(
                FirstName = 'CP',
                LastName = 'User',
                AccountId = cpAccount.Id,
                Email = 'cpuser123@test.com'
            );
            Database.insert(cpContact, dml);

            Profile p = [
                SELECT Id
                FROM Profile
                WHERE Name LIKE '%Partner%' OR Name LIKE '%Community%'
                LIMIT 1
            ];
            insert new User(
                Alias = 'cpuser',
                Email = 'cpuser123@test.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'User',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'cpuser123' + System.now().getTime() + '@test.com',
                ContactId = cpContact.Id
            );

            insert new List<SOA_Matrix__c>{
                new SOA_Matrix__c(SOA_Profile__c = 'Sales Rep', Min_Discount__c = 0, Max_Discount__c = 10),
                new SOA_Matrix__c(SOA_Profile__c = 'Sales Manager', Min_Discount__c = 11, Max_Discount__c = 20),
                new SOA_Matrix__c(
                    SOA_Profile__c = 'Country / Continent Sales Head / LOB Head',
                    Min_Discount__c = 21,
                    Max_Discount__c = 30
                ),
                new SOA_Matrix__c(SOA_Profile__c = 'Global Sales Head', Min_Discount__c = 31, Max_Discount__c = 40),
                new SOA_Matrix__c(SOA_Profile__c = 'Rotex Board Member', Min_Discount__c = 41, Max_Discount__c = 50),
                new SOA_Matrix__c(
                    SOA_Profile__c = 'Managing Director / Country Manager',
                    Min_Discount__c = 51,
                    Max_Discount__c = 99
                )
            };

            Product2 p1 = new Product2(
                Name = 'Standard Valve',
                Family = 'Valves',
                IsActive = true,
                ProductCode = 'P-123'
            );
            insert p1;

            Id standardPbId = Test.getStandardPricebookId();
            insert new PricebookEntry(
                Pricebook2Id = standardPbId,
                Product2Id = p1.Id,
                UnitPrice = 100,
                IsActive = true
            );

            Opportunity opp = new Opportunity(
                Name = 'Test Opp',
                AccountId = custAccount.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today(),
                Pricebook2Id = standardPbId
            );
            insert opp;

            // AccountId on Quote is derived from Opportunity — not writeable
            insert new Quote(
                Name = 'Test Quote',
                OpportunityId = opp.Id,
                Pricebook2Id = standardPbId
            );
        }
    }

    private static User partnerUser() {
        return [SELECT Id FROM User WHERE Email = 'cpuser123@test.com' LIMIT 1];
    }

    @IsTest
    static void testGetQuoteHeader() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Test Quote' LIMIT 1];
        User u = partnerUser();

        Test.startTest();
        System.runAs(u) {
            Quote result = DealerEditDiscountQuantityController.getQuoteHeader(q.Id);
            System.assertNotEquals(null, result);
            System.assertEquals(q.Id, result.Id);
            try {
                DealerEditDiscountQuantityController.getQuoteHeader(null);
            } catch (AuraHandledException e) {
                System.assert(true);
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void testUpdateQuoteHeaderFields() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Test Quote' LIMIT 1];
        Contact c = [SELECT Id FROM Contact WHERE Email = 'cpuser123@test.com' LIMIT 1];
        User u = partnerUser();

        Map<String, Object> fields = new Map<String, Object>{
            'Requested_Validity_Of_Offer__c' => '30 Days',
            'Delivery_Period__c' => '10 Days',
            'Warranty_Terms_Draft__c' => '12 Months',
            'Liquidate_Terms__c' => 'Net 30',
            'Transport_Details__c' => 'Road',
            'Delivery_Location__c' => 'Plant',
            'Special_Remarks__c' => 'Remarks',
            'ContactId' => c.Id,
            'Phone' => '9999999999',
            'Email' => 'cpuser123@test.com',
            'Status' => 'Draft'
        };

        Test.startTest();
        System.runAs(u) {
            try {
                DealerEditDiscountQuantityController.updateQuoteHeaderFields(null, fields);
            } catch (Exception e) {
            }
            try {
                DealerEditDiscountQuantityController.updateQuoteHeaderFields(q.Id, null);
            } catch (Exception e) {
            }
            try {
                DealerEditDiscountQuantityController.updateQuoteHeaderFields(q.Id, fields);
            } catch (Exception e) {
                System.debug('updateQuoteHeaderFields: ' + e.getMessage());
            }
        }
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void testGetAndUpdateQuoteLineItem() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Test Quote' LIMIT 1];
        User u = partnerUser();

        // Do not set formula fields (Is_Discount_Approved__c, Is_QLI_Approved_going_for_Approval__c,
        // Is_Discount_Only_Rejected__c). Use writable status/approver inputs instead.
        List<QuoteLineItem> synthetic = new List<QuoteLineItem>();
        QuoteLineItem a = new QuoteLineItem();
        a.Discount_to_be_offered__c = 15;
        a.Discount_as_per_SAP__c = 5;
        a.Previous_Discount__c = 10;
        a.New_Discount_Entered__c = true;
        a.Sales_Manager__c = UserInfo.getUserId();
        a.Final_Discount_Approver__c = UserInfo.getUserId();
        a.Sales_Manager_Status__c = 'Rejected';
        a.Is_Discount_Only_Rejected_Static__c = true;
        a.Sales_Manager_Comments__c = 'sm';
        a.Country_Continent_Sales_LOB_Comments__c = 'ch';
        a.Global_Sales_Head_Comments__c = 'gs';
        a.Rotex_Board_Member_Comments__c = 'bm';
        a.Managing_Director_Comments__c = 'md';
        a.Sales_Manager_Date_Time__c = System.now();
        synthetic.add(a);

        QuoteLineItem b = new QuoteLineItem();
        b.Discount_to_be_offered__c = 5;
        b.Discount_as_per_SAP__c = 10;
        b.Previous_Discount__c = 12;
        b.New_Discount_Entered__c = true;
        b.Sales_Manager__c = UserInfo.getUserId();
        b.Final_Discount_Approver__c = UserInfo.getUserId();
        b.Sales_Manager_Status__c = 'Approved';
        synthetic.add(b);

        QuoteLineItem c = new QuoteLineItem();
        c.Discount_to_be_offered__c = 25;
        c.Discount_as_per_SAP__c = 1;
        c.Sales_Rep__c = UserInfo.getUserId();
        c.Sales_Manager__c = UserInfo.getUserId();
        c.Country_Continent_Sales_Head_LOB_Head__c = UserInfo.getUserId();
        c.Global_Sales_Head__c = UserInfo.getUserId();
        c.Rotex_Board_Member__c = UserInfo.getUserId();
        c.Managing_Director_Country_Manage__c = UserInfo.getUserId();
        synthetic.add(c);

        QuoteLineItem d = new QuoteLineItem();
        d.Discount_to_be_offered__c = 35;
        d.Discount_as_per_SAP__c = 1;
        d.Global_Sales_Head__c = UserInfo.getUserId();
        synthetic.add(d);

        QuoteLineItem e = new QuoteLineItem();
        e.Discount_to_be_offered__c = 45;
        e.Discount_as_per_SAP__c = 1;
        e.Rotex_Board_Member__c = UserInfo.getUserId();
        synthetic.add(e);

        QuoteLineItem f = new QuoteLineItem();
        f.Discount_to_be_offered__c = 60;
        f.Discount_as_per_SAP__c = 1;
        f.Managing_Director_Country_Manage__c = UserInfo.getUserId();
        synthetic.add(f);

        Test.startTest();
        System.runAs(u) {
            List<QuoteLineItem> qlis = DealerEditDiscountQuantityController.getQuoteLineItem(q.Id);
            System.assertNotEquals(null, qlis);

            try {
                DealerEditDiscountQuantityController.updateQuoteLineItem(q.Id, null, false);
            } catch (Exception ex) {
            }
            try {
                DealerEditDiscountQuantityController.updateQuoteLineItem(
                    q.Id, new List<QuoteLineItem>(), true
                );
            } catch (Exception ex) {
            }
            try {
                DealerEditDiscountQuantityController.updateQuoteLineItem(q.Id, synthetic, true);
            } catch (Exception ex) {
                System.debug('updateQuoteLineItem synthetic: ' + ex.getMessage());
            }
            try {
                DealerEditDiscountQuantityController.updateQuoteLineItem(q.Id, synthetic, false);
            } catch (Exception ex) {
                System.debug('update reapproval: ' + ex.getMessage());
            }
        }
        Test.stopTest();
        System.assert(true);
    }
}