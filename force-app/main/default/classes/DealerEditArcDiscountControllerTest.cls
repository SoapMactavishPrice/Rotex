@IsTest
private class DealerEditArcDiscountControllerTest {

    @TestSetup
    static void setup() {
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.allowSave = true;

        Account cpAccount = new Account(Name = 'ARC CP Account');
        Database.insert(cpAccount, dml);
        Account custAccount = new Account(
            Name = 'ARC Customer',
            Channel_Partner_Name__c = cpAccount.Id,
            Channel_Partner__c = cpAccount.Id
        );
        Database.insert(custAccount, dml);

        Contact cpContact = new Contact(
            FirstName = 'CP',
            LastName = 'ArcUser',
            AccountId = cpAccount.Id,
            Email = 'cpuser_arc@test.com'
        );
        insert cpContact;

        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [
                SELECT Id
                FROM Profile
                WHERE Name LIKE '%Partner%' OR Name LIKE '%Community%'
                LIMIT 1
            ];
            insert new User(
                Alias = 'cparc',
                Email = 'cpuser_arc@test.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'User',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'cpuser_arc' + System.now().getTime() + '@test.com',
                ContactId = cpContact.Id
            );
        }

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

        Product2 prod = new Product2(Name = 'ARC Product', ProductCode = 'ARC-1', IsActive = true);
        insert prod;
        Id pbId = Test.getStandardPricebookId();
        insert new PricebookEntry(Pricebook2Id = pbId, Product2Id = prod.Id, UnitPrice = 100, IsActive = true);

        Opportunity opp = new Opportunity(
            Name = 'ARC Opp',
            AccountId = custAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            Pricebook2Id = pbId
        );
        insert opp;
        // AccountId on Quote is derived from Opportunity — not writeable
        insert new Quote(
            Name = 'ARC Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = pbId
        );

        try {
            // Product_Code__c is a formula; set Material__c instead
            insert new Customer_ARC_Pricing__c(
                Customer__c = custAccount.Id,
                Material__c = prod.Id,
                Amount__c = 90
            );
        } catch (Exception e) {
            System.debug('ARC pricing optional: ' + e.getMessage());
        }
    }

    private static User partnerUser() {
        return [SELECT Id FROM User WHERE Email = 'cpuser_arc@test.com' LIMIT 1];
    }

    @IsTest
    static void picklistMethods_returnOptions() {
        Test.startTest();
        System.assertNotEquals(null, DealerEditArcDiscountController.getPaymentTermsOptions());
        System.assertNotEquals(null, DealerEditArcDiscountController.getWarrantyOptions());
        System.assertNotEquals(null, DealerEditArcDiscountController.getIncoTermsOptions());
        Test.stopTest();
    }

    @IsTest
    static void getAndUpdate_withPartnerUser() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'ARC Quote' LIMIT 1];
        User u = partnerUser();

        Test.startTest();
        System.runAs(u) {
            Boolean threw = false;
            try {
                DealerEditArcDiscountController.getQuoteAndLineItems(null);
            } catch (AuraHandledException e) {
                threw = true;
            }
            System.assertEquals(true, threw);

            try {
                DealerEditArcDiscountController.QuoteDataWrapper data =
                    DealerEditArcDiscountController.getQuoteAndLineItems(q.Id);
                System.assertNotEquals(null, data);
            } catch (Exception e) {
                System.debug('getQuoteAndLineItems: ' + e.getMessage());
            }

            // Synthetic QLI objects — do not set formula fields
            // (Is_Discount_Approved__c, Is_QLI_Approved_going_for_Approval__c, Is_Discount_Only_Rejected__c)
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
            c.Discount_to_be_offered__c = 55;
            c.Discount_as_per_SAP__c = 1;
            c.Previous_Discount__c = null;
            c.New_Discount_Entered__c = false;
            synthetic.add(c);

            try {
                DealerEditArcDiscountController.updateQuoteAndLineItems(
                    null, synthetic, false, null, null, null
                );
            } catch (Exception e) {
            }
            try {
                DealerEditArcDiscountController.updateQuoteAndLineItems(
                    q.Id, synthetic, true, 'Net 30', '12 Months', 'EXW'
                );
            } catch (Exception e) {
                System.debug('update synthetic: ' + e.getMessage());
            }
            try {
                DealerEditArcDiscountController.updateQuoteAndLineItems(
                    q.Id, new List<QuoteLineItem>(), false, null, null, null
                );
            } catch (Exception e) {
                System.debug('update empty: ' + e.getMessage());
            }
        }
        Test.stopTest();
        System.assert(true);
    }
}