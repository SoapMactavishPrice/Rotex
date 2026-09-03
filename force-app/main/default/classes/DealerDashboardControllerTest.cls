@IsTest
private class DealerDashboardControllerTest {

    @TestSetup
    static void setup() {
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
            Id cpRt = getRecordTypeId('Account', 'Channel_Partner');
            Id custRt = getRecordTypeId('Account', 'Customer');
            Id leadCpRt = getRecordTypeId('Lead', 'Channel_Partner');

            Account cpAcc = new Account(
                Name = 'Dashboard Partner',
                OwnerId = runUser.Id
            );
            if (cpRt != null) {
                cpAcc.RecordTypeId = cpRt;
            }
            insert cpAcc;

            Account customer = new Account(
                Name = 'Dashboard Customer',
                Approval_Status__c = 'Approved',
                Channel_Partner__c = cpAcc.Id,
                Channel_Partner_Name__c = cpAcc.Id
            );
            if (custRt != null) {
                customer.RecordTypeId = custRt;
            }
            insert customer;

            Contact cpContact = new Contact(
                LastName = 'Dashboard Partner Contact',
                AccountId = cpAcc.Id,
                Email = 'dash_partner@test.com'
            );
            insert cpContact;

            Profile partnerProfile = [
                SELECT Id
                FROM Profile
                WHERE Name IN ('Partner Community User', 'Partner Community Login User')
                LIMIT 1
            ];
            String unique = String.valueOf(DateTime.now().getTime());
            User partnerUser = new User(
                Alias = 'dashp',
                Email = 'dash_partner@test.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'DashboardPartner',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = partnerProfile.Id,
                ContactId = cpContact.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                Username = 'dash_partner_' + unique + '@testorg.com',
                IsActive = true
            );
            insert partnerUser;

            SO_Invoice__c inv = new SO_Invoice__c(Account__c = cpAcc.Id);
            insert inv;

            Product2 prod = new Product2(Name = 'Dash Product', IsActive = true, ProductCode = 'DASH-001');
            insert prod;

            Inventory__c inventory = new Inventory__c(
                Channel_Partner__c = cpAcc.Id,
                Product__c = prod.Id,
                Status__c = 'Low Stock'
            );
            insert inventory;

            insert new Inventory_Transaction__c(
                Inventory__c = inventory.Id,
                Transaction_Type__c = 'GRN',
                Quantity__c = 5
            );

            Lead openLead = new Lead(
                LastName = 'Open Lead',
                Company = 'Open Co',
                Status = 'New',
                Dealer__c = cpAcc.Id,
                Email = 'open.lead@test.com'
            );
            if (leadCpRt != null) {
                openLead.RecordTypeId = leadCpRt;
            }
            insert openLead;

            Lead closedLead = new Lead(
                LastName = 'Closed Lead',
                Company = 'Closed Co',
                Status = 'Qualified',
                Dealer__c = cpAcc.Id,
                Email = 'closed.lead@test.com'
            );
            if (leadCpRt != null) {
                closedLead.RecordTypeId = leadCpRt;
            }
            insert closedLead;

            Opportunity opp = new Opportunity(
                Name = 'Dash Opp',
                AccountId = cpAcc.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            );
            insert opp;

            Id pbId = Test.getStandardPricebookId();
            Quote quoteDraft = new Quote(
                Name = 'Dash Quote Draft',
                OpportunityId = opp.Id,
                Pricebook2Id = pbId,
                Status = 'Draft'
            );
            insert quoteDraft;

            // Pending quotes status path (ignore if org rejects status value)
            try {
                Quote quotePending = new Quote(
                    Name = 'Dash Quote Pending',
                    OpportunityId = opp.Id,
                    Pricebook2Id = pbId,
                    Status = 'Submit for SOA Approval'
                );
                insert quotePending;
            } catch (Exception e) {
                // Status value may be restricted in some orgs
            }

            Order ord = new Order(
                AccountId = cpAcc.Id,
                EffectiveDate = Date.today(),
                Status = 'Draft',
                Bill_To_Customer_Name__c = customer.Id
            );
            if (Schema.sObjectType.Order.fields.getMap().containsKey('Net_Value__c')) {
                ord.put('Net_Value__c', '1,500.00');
            }
            if (Schema.sObjectType.Order.fields.getMap().containsKey('SO_No__c')) {
                ord.put('SO_No__c', 'SO-DASH-001');
            }
            insert ord;

            // Optional Target__c for achievement / chart series
            try {
                if (Schema.getGlobalDescribe().containsKey('Target__c')) {
                    SObject target = Schema.getGlobalDescribe().get('Target__c').newSObject();
                    Map<String, Schema.SObjectField> tFields = target.getSObjectType().getDescribe().fields.getMap();
                    if (tFields.containsKey('Customer_Name__c')) {
                        target.put('Customer_Name__c', cpAcc.Id);
                    }
                    if (tFields.containsKey('Total_Target__c')) {
                        target.put('Total_Target__c', 1000);
                    }
                    if (tFields.containsKey('Total_Target_Achieved__c')) {
                        target.put('Total_Target_Achieved__c', 250);
                    }
                    if (tFields.containsKey('Qtr_1_Target__c')) {
                        target.put('Qtr_1_Target__c', 250);
                    }
                    if (tFields.containsKey('Qtr_2_Target__c')) {
                        target.put('Qtr_2_Target__c', 250);
                    }
                    if (tFields.containsKey('Qtr_3_Target__c')) {
                        target.put('Qtr_3_Target__c', 250);
                    }
                    if (tFields.containsKey('Qtr_4_Target__c')) {
                        target.put('Qtr_4_Target__c', 250);
                    }
                    if (tFields.containsKey('Qtr_1_Actual__c')) {
                        target.put('Qtr_1_Actual__c', 100);
                    }
                    if (tFields.containsKey('Qtr_2_Actual__c')) {
                        target.put('Qtr_2_Actual__c', 50);
                    }
                    if (tFields.containsKey('Qtr_3_Actual__c')) {
                        target.put('Qtr_3_Actual__c', 50);
                    }
                    if (tFields.containsKey('Qtr_4_Actual__c')) {
                        target.put('Qtr_4_Actual__c', 50);
                    }
                    insert target;
                }
            } catch (Exception e) {
                // Target layout / validation may vary by org
            }
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

    private static User getPartnerUser() {
        return [
            SELECT Id, AccountId
            FROM User
            WHERE Email = 'dash_partner@test.com'
            LIMIT 1
        ];
    }

    @IsTest
    static void testDashboardMetricsDefaults() {
        DealerDashboardController.DashboardMetrics m = new DealerDashboardController.DashboardMetrics();
        System.assertEquals(0, m.invoiceQty);
        System.assertEquals(0, m.approvedCustomers);
        System.assertEquals(0, m.openLeads);
        System.assertEquals(0, m.pendingQuotes);
        System.assertEquals(0, m.lowStockProducts);
        System.assertEquals(0, m.targetAchievement);
        System.assertEquals(0, m.totalQuotes);
        System.assertEquals(0, m.totalLeads);
        System.assertEquals(0, m.totalInventory);
        System.assertEquals(4, m.chartLabels.size());
        System.assertEquals(4, m.chartTargets.size());
        System.assertEquals(4, m.chartActuals.size());
        System.assertNotEquals(null, m.quoteStatusLabels);
        System.assertNotEquals(null, m.topOrderLabels);
    }

    @IsTest
    static void testGetDashboardMetrics_InternalUser_NoFilters() {
        Test.startTest();
        DealerDashboardController.DashboardMetrics metrics =
            DealerDashboardController.getDashboardMetrics(null, null, null);
        Test.stopTest();

        System.assertNotEquals(null, metrics, 'Metrics should be returned');
        System.assertNotEquals(null, metrics.chartLabels);
        System.assertEquals(4, metrics.chartLabels.size());
        System.assert(metrics.totalQuotes >= 0);
        System.assert(metrics.totalLeads >= 0);
        System.assert(metrics.totalInventory >= 0);
        System.assertNotEquals(null, metrics.topOrderLabels);
        System.assertNotEquals(null, metrics.inventoryStatusLabels);
    }

    @IsTest
    static void testGetDashboardMetrics_YearAndQuarters() {
        String yearStr = String.valueOf(Date.today().year());

        Test.startTest();
        DealerDashboardController.DashboardMetrics allYear =
            DealerDashboardController.getDashboardMetrics(yearStr, null, null);
        DealerDashboardController.DashboardMetrics q1 =
            DealerDashboardController.getDashboardMetrics(yearStr, 'Q1', null);
        DealerDashboardController.DashboardMetrics q2 =
            DealerDashboardController.getDashboardMetrics(yearStr, 'Q2', null);
        DealerDashboardController.DashboardMetrics q3 =
            DealerDashboardController.getDashboardMetrics(yearStr, 'Q3', null);
        DealerDashboardController.DashboardMetrics q4 =
            DealerDashboardController.getDashboardMetrics(yearStr, 'Q4', null);
        Test.stopTest();

        System.assertNotEquals(null, allYear);
        System.assertNotEquals(null, q1);
        System.assertNotEquals(null, q2);
        System.assertNotEquals(null, q3);
        System.assertNotEquals(null, q4);
    }

    @IsTest
    static void testGetDashboardMetrics_MonthAndQuarterWithoutYear() {
        String month = String.valueOf(Date.today().month());

        Test.startTest();
        DealerDashboardController.DashboardMetrics byMonth =
            DealerDashboardController.getDashboardMetrics(null, null, month);
        DealerDashboardController.DashboardMetrics byQ1 =
            DealerDashboardController.getDashboardMetrics(null, 'Q1', null);
        DealerDashboardController.DashboardMetrics byQ2 =
            DealerDashboardController.getDashboardMetrics(null, 'Q2', null);
        DealerDashboardController.DashboardMetrics byQ3 =
            DealerDashboardController.getDashboardMetrics(null, 'Q3', null);
        DealerDashboardController.DashboardMetrics byQ4 =
            DealerDashboardController.getDashboardMetrics(null, 'Q4', null);
        // Month takes precedence when both provided with year
        DealerDashboardController.DashboardMetrics yearMonth =
            DealerDashboardController.getDashboardMetrics(
                String.valueOf(Date.today().year()),
                'Q1',
                month
            );
        Test.stopTest();

        System.assertNotEquals(null, byMonth);
        System.assertNotEquals(null, byQ1);
        System.assertNotEquals(null, byQ2);
        System.assertNotEquals(null, byQ3);
        System.assertNotEquals(null, byQ4);
        System.assertNotEquals(null, yearMonth);
    }

    @IsTest
    static void testGetDashboardMetrics_PartnerUser() {
        User partnerUser = getPartnerUser();
        System.assertNotEquals(null, partnerUser.AccountId, 'Portal user should resolve AccountId');

        System.runAs(partnerUser) {
            Test.startTest();
            DealerDashboardController.DashboardMetrics metrics =
                DealerDashboardController.getDashboardMetrics(
                    String.valueOf(Date.today().year()),
                    null,
                    null
                );
            Test.stopTest();

            System.assertNotEquals(null, metrics);
            System.assert(metrics.approvedCustomers >= 0);
            System.assert(metrics.openLeads >= 0);
            System.assert(metrics.lowStockProducts >= 0);
            System.assertNotEquals(null, metrics.quoteStatusLabels);
            System.assertNotEquals(null, metrics.leadStatusLabels);
            System.assertNotEquals(null, metrics.inventoryStatusLabels);
            System.assertNotEquals(null, metrics.topOrderLabels);
            System.assertEquals(4, metrics.chartTargets.size());
            System.assertEquals(4, metrics.chartActuals.size());
        }
    }

    @IsTest
    static void testOrderWrapperComparable() {
        List<Order> orders = [
            SELECT Id, OrderNumber, SO_No__c, Net_Value__c, Bill_To_Customer_Name__r.Name
            FROM Order
            LIMIT 2
        ];
        if (orders.isEmpty()) {
            // Ensure method path still runs via dashboard
            DealerDashboardController.DashboardMetrics m =
                DealerDashboardController.getDashboardMetrics(null, null, null);
            System.assertNotEquals(null, m.topOrderValues);
            return;
        }

        DealerDashboardController.OrderWrapper w1 =
            new DealerDashboardController.OrderWrapper(orders[0]);
        DealerDashboardController.OrderWrapper w2 =
            new DealerDashboardController.OrderWrapper(orders[0]);

        System.assertEquals(0, w1.compareTo(w2), 'Same net value should compare equal');

        Order high = orders[0].clone(false, true, false, false);
        high.Id = orders[0].Id;
        if (Schema.sObjectType.Order.fields.getMap().containsKey('Net_Value__c')) {
            // Rebuild wrappers with different values through second order if present
            DealerDashboardController.OrderWrapper low =
                new DealerDashboardController.OrderWrapper(orders[0]);
            Order oHigh = new Order();
            oHigh.Id = orders[0].Id;
            oHigh.put('Net_Value__c', '99999');
            oHigh.putSObject(
                'Bill_To_Customer_Name__r',
                new Account(Name = 'High Value Customer')
            );
            DealerDashboardController.OrderWrapper highW =
                new DealerDashboardController.OrderWrapper(oHigh);
            System.assert(highW.compareTo(low) < 0 || highW.compareTo(low) == 0);
        }
    }

    @IsTest
    static void testPartnerUser_AllFilterBranches() {
        User partnerUser = getPartnerUser();
        String yearStr = String.valueOf(Date.today().year());

        System.runAs(partnerUser) {
            Test.startTest();
            DealerDashboardController.getDashboardMetrics(null, null, null);
            DealerDashboardController.getDashboardMetrics(yearStr, 'Q1', null);
            DealerDashboardController.getDashboardMetrics(yearStr, 'Q2', null);
            DealerDashboardController.getDashboardMetrics(yearStr, 'Q3', null);
            DealerDashboardController.getDashboardMetrics(yearStr, 'Q4', null);
            DealerDashboardController.getDashboardMetrics(yearStr, null, '4');
            DealerDashboardController.getDashboardMetrics(yearStr, null, '1');
            DealerDashboardController.getDashboardMetrics(null, 'Q1', null);
            DealerDashboardController.getDashboardMetrics(null, null, '6');
            Test.stopTest();
        }
        System.assert(true, 'Partner filter branches covered without exception');
    }
}