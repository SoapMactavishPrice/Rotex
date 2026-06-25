@IsTest
public class OrderTargetHandlerTest {

    /* ===================== TEST DATA SETUP ===================== */
    private static Fiscal_Year__c createFY() {
        Fiscal_Year__c fy = new Fiscal_Year__c(
            Name = 'FY 2025-26',
            FY_Start_Date__c = Date.newInstance(2025, 4, 1),
            FY_End_Date__c   = Date.newInstance(2026, 3, 31)
        );
        insert fy;
        return fy;
    }

    private static Target__c createTarget(String billTo, Fiscal_Year__c fy) {
        Target__c tgt = new Target__c(
            Bill_to_Party_Code__c = billTo,
            Fiscal_Year__c = fy.Id,
            Qtr_1_Actual__c = 0,
            Qtr_2_Actual__c = 0,
            Qtr_3_Actual__c = 0,
            Qtr_4_Actual__c = 0
        );
        insert tgt;
        return tgt;
    }

    private static Order createOrder(
        Account acc,
        Id pbId,
        String billTo,
        Date effDate,
        String netValue
    ) {
        return new Order(
            Name = 'Test Order',
            AccountId = acc.Id,
            Status = 'Draft',
            EffectiveDate = effDate,
            Pricebook2Id = pbId,
            Bill_To__c = billTo,
            Net_Value__c = netValue
        );
    }

    /* ===================== Q1 SUCCESS ===================== */
    @IsTest
    static void test_Q1_Update() {

        Fiscal_Year__c fy = createFY();
        Target__c tgt = createTarget('BILL001', fy);

        Account acc = new Account(Name = 'Acc Q1');
        insert acc;

        Id pbId = Test.getStandardPricebookId();

        Order ord = createOrder(
            acc, pbId, 'BILL001',
            Date.newInstance(2025, 4, 10), // Q1
            '100.50'
        );

        Test.startTest();
        insert ord;
        Test.stopTest();

        tgt = [
            SELECT Qtr_1_Actual__c
            FROM Target__c WHERE Id = :tgt.Id
        ];
        System.assertEquals(100.50, tgt.Qtr_1_Actual__c);
    }

    /* ===================== Q2 SUCCESS ===================== */
    @IsTest
    static void test_Q2_Update() {

        Fiscal_Year__c fy = createFY();
        Target__c tgt = createTarget('BILL002', fy);

        Account acc = new Account(Name = 'Acc Q2');
        insert acc;

        Order ord = createOrder(
            acc,
            Test.getStandardPricebookId(),
            'BILL002',
            Date.newInstance(2025, 8, 5), // Q2
            '200'
        );

        Test.startTest();
        insert ord;
        Test.stopTest();

        tgt = [SELECT Qtr_2_Actual__c FROM Target__c WHERE Id = :tgt.Id];
        System.assertEquals(200, tgt.Qtr_2_Actual__c);
    }

    /* ===================== Q3 SUCCESS ===================== */
    @IsTest
    static void test_Q3_Update() {

        Fiscal_Year__c fy = createFY();
        Target__c tgt = createTarget('BILL003', fy);

        Account acc = new Account(Name = 'Acc Q3');
        insert acc;

        Order ord = createOrder(
            acc,
            Test.getStandardPricebookId(),
            'BILL003',
            Date.newInstance(2025, 11, 20), // Q3
            '300'
        );

        Test.startTest();
        insert ord;
        Test.stopTest();

        tgt = [SELECT Qtr_3_Actual__c FROM Target__c WHERE Id = :tgt.Id];
        System.assertEquals(300, tgt.Qtr_3_Actual__c);
    }

    /* ===================== Q4 SUCCESS ===================== */
    @IsTest
    static void test_Q4_Update() {

        Fiscal_Year__c fy = createFY();
        Target__c tgt = createTarget('BILL004', fy);

        Account acc = new Account(Name = 'Acc Q4');
        insert acc;

        Order ord = createOrder(
            acc,
            Test.getStandardPricebookId(),
            'BILL004',
            Date.newInstance(2026, 2, 10), // Q4
            '400'
        );

        Test.startTest();
        insert ord;
        Test.stopTest();

        tgt = [SELECT Qtr_4_Actual__c FROM Target__c WHERE Id = :tgt.Id];
        System.assertEquals(400, tgt.Qtr_4_Actual__c);
    }

    /* ===================== INVALID NET VALUE ===================== */
    @IsTest
    static void test_Invalid_Net_Value_Skipped() {

        Fiscal_Year__c fy = createFY();
        Target__c tgt = createTarget('BILL005', fy);

        Account acc = new Account(Name = 'Invalid Net');
        insert acc;

        Order ord = createOrder(
            acc,
            Test.getStandardPricebookId(),
            'BILL005',
            Date.newInstance(2025, 6, 1),
            'ABC' // invalid
        );

        Test.startTest();
        insert ord;
        Test.stopTest();

        tgt = [SELECT Qtr_1_Actual__c FROM Target__c WHERE Id = :tgt.Id];
        System.assertEquals(0, tgt.Qtr_1_Actual__c);
    }

    /* ===================== NO FY MATCH ===================== */
    @IsTest
    static void test_No_Fiscal_Year_Match() {

        Fiscal_Year__c fy = createFY();
        Target__c tgt = createTarget('BILL006', fy);

        Account acc = new Account(Name = 'No FY Match');
        insert acc;

        Order ord = createOrder(
            acc,
            Test.getStandardPricebookId(),
            'BILL006',
            Date.newInstance(2027, 1, 1), // outside FY
            '100'
        );

        Test.startTest();
        insert ord;
        Test.stopTest();

        tgt = [SELECT Qtr_4_Actual__c FROM Target__c WHERE Id = :tgt.Id];
        System.assertEquals(0, tgt.Qtr_4_Actual__c);
    }

    /* ===================== BLANK SAFETY ===================== */
    @IsTest
    static void test_Blank_BillTo_Safely_Ignored() {

        Account acc = new Account(Name = 'Blank BillTo');
        insert acc;

        Order ord = new Order(
            Name = 'Blank BillTo Order',
            AccountId = acc.Id,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id = Test.getStandardPricebookId(),
            Net_Value__c = '100'
        );

        Test.startTest();
        insert ord;
        Test.stopTest();

        System.assertNotEquals(null, ord.Id);
    }
}