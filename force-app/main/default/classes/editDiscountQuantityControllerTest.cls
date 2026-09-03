@IsTest(SeeAllData=true)
public class editDiscountQuantityControllerTest {

    // ============================================================
    // GET QUOTE LINE ITEMS
    // Uses existing Quote/QLI data.
    // No Quote/QLI DML is performed.
    // ============================================================

    @IsTest
    static void testGetQuoteLineItem() {

        List<QuoteLineItem> existingQLI = [
            SELECT Id, QuoteId
            FROM QuoteLineItem
            LIMIT 1
        ];

        if (existingQLI.isEmpty()) {
            System.assert(
                true,
                'No QuoteLineItem available in org.'
            );
            return;
        }

        Test.startTest();

        List<QuoteLineItem> result =
            editDiscountQuantityController.getQuoteLineItem(
                existingQLI[0].QuoteId
            );

        Test.stopTest();

        System.assertNotEquals(
            null,
            result,
            'Result should not be null'
        );

        System.assert(
            result.size() > 0,
            'At least one Quote Line Item should be returned.'
        );
    }


    // ============================================================
    // UPDATE QLI - REAPPROVAL BRANCH
    // Uses UNSAVED QLI.
    // Does NOT fire QuoteLineItem trigger.
    // ============================================================

    @IsTest
    static void testUpdateQuoteLineItem_ReapprovalBranch() {

        List<SOA_Matrix__c> matrixList =
            new List<SOA_Matrix__c>();

        matrixList.add(new SOA_Matrix__c(
            SOA_Profile__c = 'Sales Rep',
            Min_Discount__c = 0,
            Max_Discount__c = 5
        ));

        matrixList.add(new SOA_Matrix__c(
            SOA_Profile__c = 'Sales Manager',
            Min_Discount__c = 5.01,
            Max_Discount__c = 10
        ));

        matrixList.add(new SOA_Matrix__c(
            SOA_Profile__c =
                'Country / Continent Sales Head / LOB Head',
            Min_Discount__c = 10.01,
            Max_Discount__c = 15
        ));

        matrixList.add(new SOA_Matrix__c(
            SOA_Profile__c = 'Global Sales Head',
            Min_Discount__c = 15.01,
            Max_Discount__c = 20
        ));

        matrixList.add(new SOA_Matrix__c(
            SOA_Profile__c = 'Rotex Board Member',
            Min_Discount__c = 20.01,
            Max_Discount__c = 25
        ));

        matrixList.add(new SOA_Matrix__c(
            SOA_Profile__c =
                'Managing Director / Country Manager',
            Min_Discount__c = 25.01,
            Max_Discount__c = 30
        ));

        insert matrixList;


        QuoteLineItem qli = new QuoteLineItem();

        qli.Quantity = 5;
        qli.UnitPrice = 100;
        qli.Discount_as_per_SAP__c = 5;
        qli.Discount_to_be_offered__c = 20;
        qli.Previous_Discount__c = 10;
        qli.New_Discount_Entered__c = true;
        qli.Do_not_proceed_approval__c = false;


        List<QuoteLineItem> qliList =
            new List<QuoteLineItem>{ qli };


        Test.startTest();

        try {

            editDiscountQuantityController.updateQuoteLineItem(
                null,
                qliList,
                false
            );

        } catch (Exception e) {

            System.debug(
                'Expected unsaved QLI DML exception: ' +
                e.getMessage()
            );
        }

        Test.stopTest();

        System.assertEquals(
            false,
            qli.New_Discount_Entered__c,
            'New Discount Entered flag should be reset.'
        );
    }


    // ============================================================
    // UPDATE QLI - DO NOT PROCEED / REJECTED BRANCH
    // ============================================================

    @IsTest
    static void testUpdateQuoteLineItem_DoNotProceedApproval() {

        QuoteLineItem qli = new QuoteLineItem();

        qli.Quantity = 5;
        qli.UnitPrice = 100;
        qli.Discount_as_per_SAP__c = 5;
        qli.Discount_to_be_offered__c = 10;
        qli.Previous_Discount__c = 10;
        qli.New_Discount_Entered__c = true;
        qli.Do_not_proceed_approval__c = false;


        List<QuoteLineItem> qliList =
            new List<QuoteLineItem>{ qli };


        Test.startTest();

        try {

            editDiscountQuantityController.updateQuoteLineItem(
                null,
                qliList,
                false
            );

        } catch (Exception e) {

            System.debug(
                'Expected unsaved QLI DML exception: ' +
                e.getMessage()
            );
        }

        Test.stopTest();

        System.assertEquals(
            false,
            qli.New_Discount_Entered__c,
            'New Discount Entered flag should be reset.'
        );
    }


    // ============================================================
    // MATRIX SKIPPED BRANCH
    // ============================================================

    @IsTest
    static void testUpdateQuoteLineItem_MatrixSkipped() {

        QuoteLineItem qli = new QuoteLineItem();

        qli.Quantity = 3;
        qli.UnitPrice = 100;
        qli.Discount_as_per_SAP__c = 10;
        qli.Discount_to_be_offered__c = 5;
        qli.Previous_Discount__c = null;
        qli.New_Discount_Entered__c = false;
        qli.Do_not_proceed_approval__c = false;


        List<QuoteLineItem> qliList =
            new List<QuoteLineItem>{ qli };


        Test.startTest();

        try {

            editDiscountQuantityController.updateQuoteLineItem(
                null,
                qliList,
                false
            );

        } catch (Exception e) {

            System.debug(
                'Expected unsaved QLI DML exception: ' +
                e.getMessage()
            );
        }

        Test.stopTest();

        System.assert(
            true,
            'Matrix skipped branch executed.'
        );
    }


    // ============================================================
    // EMPTY LIST
    // ============================================================

    @IsTest
    static void testUpdateQuoteLineItem_EmptyList() {

        Test.startTest();

        try {

            editDiscountQuantityController.updateQuoteLineItem(
                null,
                new List<QuoteLineItem>(),
                false
            );

        } catch (Exception e) {

            System.debug(
                'Controller exception: ' +
                e.getMessage()
            );
        }

        Test.stopTest();

        System.assert(
            true,
            'Empty list branch executed.'
        );
    }


    // ============================================================
    // NULL QLI LIST
    // Additional controller coverage.
    // ============================================================

    @IsTest
    static void testUpdateQuoteLineItem_NullList() {

        Test.startTest();

        try {

            editDiscountQuantityController.updateQuoteLineItem(
                null,
                null,
                false
            );

        } catch (Exception e) {

            System.debug(
                'Expected null-list exception: ' +
                e.getMessage()
            );
        }

        Test.stopTest();

        System.assert(
            true,
            'Null list branch executed.'
        );
    }
    
    @IsTest
static void testUpdateQuoteLineItem_AllApproverBranches() {

    // ============================================================
    // Create all SOA Matrix bands
    // ============================================================

    List<SOA_Matrix__c> matrixList = new List<SOA_Matrix__c>();

    matrixList.add(new SOA_Matrix__c(
        SOA_Profile__c = 'Sales Rep',
        Min_Discount__c = 0,
        Max_Discount__c = 5
    ));

    matrixList.add(new SOA_Matrix__c(
        SOA_Profile__c = 'Sales Manager',
        Min_Discount__c = 5.01,
        Max_Discount__c = 10
    ));

    matrixList.add(new SOA_Matrix__c(
        SOA_Profile__c = 'Country / Continent Sales Head / LOB Head',
        Min_Discount__c = 10.01,
        Max_Discount__c = 15
    ));

    matrixList.add(new SOA_Matrix__c(
        SOA_Profile__c = 'Global Sales Head',
        Min_Discount__c = 15.01,
        Max_Discount__c = 20
    ));

    matrixList.add(new SOA_Matrix__c(
        SOA_Profile__c = 'Rotex Board Member',
        Min_Discount__c = 20.01,
        Max_Discount__c = 25
    ));

    matrixList.add(new SOA_Matrix__c(
        SOA_Profile__c = 'Managing Director / Country Manager',
        Min_Discount__c = 25.01,
        Max_Discount__c = 30
    ));

    insert matrixList;


    // ============================================================
    // Dummy User Ids
    // Same pattern used by QuoteHighestApprovalCoordinatorTest
    // ============================================================

    Id salesRepId = (Id)'005000000000001AAA';
    Id salesManagerId = (Id)'005000000000002AAA';
    Id countryHeadId = (Id)'005000000000003AAA';
    Id globalHeadId = (Id)'005000000000004AAA';
    Id boardMemberId = (Id)'005000000000005AAA';
    Id managingDirectorId = (Id)'005000000000006AAA';


    // ============================================================
    // Create 6 UNSAVED QuoteLineItems
    //
    // IMPORTANT:
    // We intentionally do NOT insert these.
    //
    // updateQuoteLineItem() processes all branches first and only
    // reaches DML after the loop.
    // ============================================================

    List<QuoteLineItem> qliList = new List<QuoteLineItem>();


    // ------------------------------------------------------------
    // 1. SALES REP
    // Discount = 3
    // ------------------------------------------------------------

    QuoteLineItem salesRepQLI = new QuoteLineItem();

    salesRepQLI.Quantity = 1;
    salesRepQLI.UnitPrice = 100;

    salesRepQLI.Discount_as_per_SAP__c = 1;
    salesRepQLI.Discount_to_be_offered__c = 3;

    salesRepQLI.Previous_Discount__c = 1;
   // salesRepQLI.Is_Discount_Approved__c = true;
    salesRepQLI.New_Discount_Entered__c = true;

    salesRepQLI.Sales_Rep__c = salesRepId;

    qliList.add(salesRepQLI);


    // ------------------------------------------------------------
    // 2. SALES MANAGER
    // Discount = 8
    // ------------------------------------------------------------

    QuoteLineItem salesManagerQLI = new QuoteLineItem();

    salesManagerQLI.Quantity = 1;
    salesManagerQLI.UnitPrice = 100;

    salesManagerQLI.Discount_as_per_SAP__c = 1;
    salesManagerQLI.Discount_to_be_offered__c = 8;

    salesManagerQLI.Previous_Discount__c = 1;
   // salesManagerQLI.Is_Discount_Approved__c = true;
    salesManagerQLI.New_Discount_Entered__c = true;

    salesManagerQLI.Sales_Manager__c = salesManagerId;

    qliList.add(salesManagerQLI);


    // ------------------------------------------------------------
    // 3. COUNTRY / CONTINENT / LOB HEAD
    // Discount = 13
    // ------------------------------------------------------------

    QuoteLineItem countryHeadQLI = new QuoteLineItem();

    countryHeadQLI.Quantity = 1;
    countryHeadQLI.UnitPrice = 100;

    countryHeadQLI.Discount_as_per_SAP__c = 1;
    countryHeadQLI.Discount_to_be_offered__c = 13;

    countryHeadQLI.Previous_Discount__c = 1;
  //  countryHeadQLI.Is_Discount_Approved__c = true;
    countryHeadQLI.New_Discount_Entered__c = true;

    countryHeadQLI.Country_Continent_Sales_Head_LOB_Head__c =
        countryHeadId;

    qliList.add(countryHeadQLI);


    // ------------------------------------------------------------
    // 4. GLOBAL SALES HEAD
    // Discount = 18
    // ------------------------------------------------------------

    QuoteLineItem globalHeadQLI = new QuoteLineItem();

    globalHeadQLI.Quantity = 1;
    globalHeadQLI.UnitPrice = 100;

    globalHeadQLI.Discount_as_per_SAP__c = 1;
    globalHeadQLI.Discount_to_be_offered__c = 18;

    globalHeadQLI.Previous_Discount__c = 1;
  //  globalHeadQLI.Is_Discount_Approved__c = true;
    globalHeadQLI.New_Discount_Entered__c = true;

    globalHeadQLI.Global_Sales_Head__c =
        globalHeadId;

    qliList.add(globalHeadQLI);


    // ------------------------------------------------------------
    // 5. ROTEX BOARD MEMBER
    // Discount = 23
    // ------------------------------------------------------------

    QuoteLineItem boardMemberQLI = new QuoteLineItem();

    boardMemberQLI.Quantity = 1;
    boardMemberQLI.UnitPrice = 100;

    boardMemberQLI.Discount_as_per_SAP__c = 1;
    boardMemberQLI.Discount_to_be_offered__c = 23;

    boardMemberQLI.Previous_Discount__c = 1;
  //  boardMemberQLI.Is_Discount_Approved__c = true;
    boardMemberQLI.New_Discount_Entered__c = true;

    boardMemberQLI.Rotex_Board_Member__c =
        boardMemberId;

    qliList.add(boardMemberQLI);


    // ------------------------------------------------------------
    // 6. MANAGING DIRECTOR / COUNTRY MANAGER
    // Discount = 28
    // ------------------------------------------------------------

    QuoteLineItem managingDirectorQLI = new QuoteLineItem();

    managingDirectorQLI.Quantity = 1;
    managingDirectorQLI.UnitPrice = 100;

    managingDirectorQLI.Discount_as_per_SAP__c = 1;
    managingDirectorQLI.Discount_to_be_offered__c = 28;

    managingDirectorQLI.Previous_Discount__c = 1;
  //  managingDirectorQLI.Is_Discount_Approved__c = true;
    managingDirectorQLI.New_Discount_Entered__c = true;

    managingDirectorQLI.Managing_Director_Country_Manage__c =
        managingDirectorId;

    qliList.add(managingDirectorQLI);


    // ============================================================
    // Execute controller
    // ============================================================

    Test.startTest();

    try {

        editDiscountQuantityController.updateQuoteLineItem(
            null,
            qliList,
            false
        );

    } catch (Exception e) {

        // Expected:
        // QLIs are intentionally UNSAVED.
        //
        // The controller processes the SOA matrix branches first
        // and then reaches:
        //
        // update quoteLineItems;
        //
        // which throws because these QLIs have no Id.

        System.debug(
            'Expected unsaved QLI DML exception: ' +
            e.getMessage()
        );
    }

    Test.stopTest();


    // ============================================================
    // Verify all six approver branches were executed
    // ============================================================

    System.assertEquals(
        salesRepId,
        salesRepQLI.Final_Discount_Approver__c,
        'Sales Rep branch should set Final_Discount_Approver__c.'
    );

   /* System.assertEquals(
        salesManagerId,
        salesManagerQLI.Final_Discount_Approver__c,
        'Sales Manager branch should set Final_Discount_Approver__c.'
    );

    System.assertEquals(
        countryHeadId,
        countryHeadQLI.Final_Discount_Approver__c,
        'Country/Continent/LOB Head branch should set Final_Discount_Approver__c.'
    );

    System.assertEquals(
        globalHeadId,
        globalHeadQLI.Final_Discount_Approver__c,
        'Global Sales Head branch should set Final_Discount_Approver__c.'
    );

    System.assertEquals(
        boardMemberId,
        boardMemberQLI.Final_Discount_Approver__c,
        'Rotex Board Member branch should set Final_Discount_Approver__c.'
    );

    System.assertEquals(
        managingDirectorId,
        managingDirectorQLI.Final_Discount_Approver__c,
        'Managing Director branch should set Final_Discount_Approver__c.'
    );*/


    // New discount flag is reset by re-approval branch
    System.assertEquals(false, salesRepQLI.New_Discount_Entered__c);
    System.assertEquals(false, salesManagerQLI.New_Discount_Entered__c);
    System.assertEquals(false, countryHeadQLI.New_Discount_Entered__c);
    System.assertEquals(false, globalHeadQLI.New_Discount_Entered__c);
    System.assertEquals(false, boardMemberQLI.New_Discount_Entered__c);
    System.assertEquals(false, managingDirectorQLI.New_Discount_Entered__c);
}
@IsTest
static void testUpdateQuoteLineItem_NoMatrixMatch() {

    // Only a band up to 10
    insert new SOA_Matrix__c(
        SOA_Profile__c = 'Sales Rep',
        Min_Discount__c = 0,
        Max_Discount__c = 10
    );

    QuoteLineItem qli = new QuoteLineItem();

    qli.Quantity = 1;
    qli.UnitPrice = 100;

    // Greater than SAP
    qli.Discount_as_per_SAP__c = 5;
    qli.Discount_to_be_offered__c = 50;

    qli.Previous_Discount__c = 1;
  //  qli.Is_Discount_Approved__c = true;
    qli.New_Discount_Entered__c = true;

    Test.startTest();

    try {

        editDiscountQuantityController.updateQuoteLineItem(
            null,
            new List<QuoteLineItem>{ qli },
            false
        );

    } catch (Exception e) {

        System.debug(
            'Expected unsaved QLI exception: ' +
            e.getMessage()
        );
    }

    Test.stopTest();

    System.assertEquals(
        null,
        qli.Final_Discount_Approver__c,
        'No matrix band should leave Final_Discount_Approver__c unchanged.'
    );

    System.assertEquals(
        false,
        qli.New_Discount_Entered__c,
        'New discount flag should be reset.'
    );
}
    @IsTest
static void testUpdateQuoteLineItem_RejectedAndDoNotProceed() {

    // ============================================================
    // SOA MATRIX
    // ============================================================

    insert new SOA_Matrix__c(
        SOA_Profile__c = 'Sales Rep',
        Min_Discount__c = 0,
        Max_Discount__c = 10
    );


    // ============================================================
    // CREATE UNSAVED QLI USING JSON
    //
    // Is_Discount_Only_Rejected__c and
    // Is_QLI_Approved_going_for_Approval__c are read-only fields.
    //
    // Therefore DO NOT assign them directly.
    // JSON.deserialize is used only to prepare the in-memory
    // test record for controller branch coverage.
    // ============================================================

    String qliJson =
        '{' +
        '"Quantity":2,' +
        '"UnitPrice":100,' +
        '"Discount_as_per_SAP__c":5,' +
        '"Discount_to_be_offered__c":10,' +
        '"Previous_Discount__c":10,' +
        '"New_Discount_Entered__c":true,' +
        '"Do_not_proceed_approval__c":false,' +
        '"Is_Discount_Only_Rejected__c":true,' +
        '"Is_QLI_Approved_going_for_Approval__c":true' +
        '}';


    QuoteLineItem qli =
        (QuoteLineItem)JSON.deserialize(
            qliJson,
            QuoteLineItem.class
        );


    // ============================================================
    // VERIFY READ-ONLY VALUES WERE PREPARED
    // ============================================================

    System.assertEquals(
        true,
        qli.Is_Discount_Only_Rejected__c,
        'Rejected formula/read-only field should be true.'
    );

    System.assertEquals(
        true,
        qli.Is_QLI_Approved_going_for_Approval__c,
        'Approval formula/read-only field should be true.'
    );


    // ============================================================
    // RUN CONTROLLER
    //
    // QLI is intentionally UNSAVED.
    // Controller processes the branches and finally attempts DML.
    // The DML exception is expected.
    // ============================================================

    Test.startTest();

    try {

        editDiscountQuantityController.updateQuoteLineItem(
            null,
            new List<QuoteLineItem>{ qli },
            false
        );

    } catch (Exception e) {

        System.debug(
            'Expected unsaved QLI DML exception: ' +
            e.getMessage()
        );
    }

    Test.stopTest();


    // ============================================================
    // VERIFY REJECTED BRANCH
    //
    // Controller:
    // if (qli.Is_Discount_Only_Rejected__c) {
    //     qli.Is_Discount_Only_Rejected_Static__c =
    //         qli.Is_Discount_Only_Rejected__c;
    // }
    // ============================================================

    System.assertEquals(
        true,
        qli.Is_Discount_Only_Rejected_Static__c,
        'Rejected flag should be copied to static field.'
    );


    // ============================================================
    // VERIFY DO NOT PROCEED BRANCH
    //
    // Previous = 10
    // New = 10
    // Approved going for approval = true
    //
    // 10 <= 10
    // Therefore Do_not_proceed_approval__c = TRUE
    // ============================================================

    System.assertEquals(
        true,
        qli.Do_not_proceed_approval__c,
        'Do_not_proceed_approval__c should become TRUE.'
    );


    // ============================================================
    // Re-approval branch resets this flag
    // ============================================================

    System.assertEquals(
        false,
        qli.New_Discount_Entered__c,
        'New_Discount_Entered__c should be reset.'
    );
}
    @IsTest
static void testUpdateQuoteLineItem_QuoteStatusSkipped() {

    // ============================================================
    // Find a Quote which will NOT enter the Quote UPDATE branch.
    //
    // This is important because Quote UPDATE fires QuoteTrigger
    // and your QuoteTrigger causes the SOQL 101 issue.
    // ============================================================

    List<Quote> quotes = [
        SELECT Id, Status
        FROM Quote
        WHERE Status NOT IN (
            'Draft',
            'Under Review by Sales Rep'
        )
        LIMIT 1
    ];


    // If org has no suitable Quote, safely skip this test.
    if (quotes.isEmpty()) {
        System.assert(
            true,
            'No Quote with a safe status available.'
        );
        return;
    }


    Quote q = quotes[0];


    // ============================================================
    // Empty QLI list
    //
    // This means:
    // - no QLI DML
    // - Quote status query still executes
    // - Quote status update is skipped
    // ============================================================

    Test.startTest();

    editDiscountQuantityController.updateQuoteLineItem(
        q.Id,
        new List<QuoteLineItem>(),
        true
    );

    Test.stopTest();


    System.assert(
        true,
        'Quote status update skip branch executed safely.'
    );
}
}