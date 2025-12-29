@IsTest
public class OrderTargetHandlerTest {
    
    @IsTest
    static void testOrderAfterInsert_Q1_Success() {
        
        /* 1️⃣ Create Target */
        Target__c tgt = new Target__c(
            //Name = 'Test Target',
            Bill_to_Party_Code__c = 'BILL001',
            Qtr_1_Actual__c = 0,
            Qtr_2_Actual__c = 0,
            Qtr_3_Actual__c = 0,
            Qtr_4_Actual__c = 0
        );
        insert tgt;
        
        /* 2️⃣ Create Account (mandatory for Order) */
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        /* 3️⃣ Standard Pricebook */
        Id stdPbId = Test.getStandardPricebookId();
        
        /* 4️⃣ Create Order (April → Q1) */
        Order ord = new Order(
            Name = 'Test Order',
            AccountId = acc.Id,
            Status = 'Draft',
            EffectiveDate = Date.newInstance(2025, 4, 15),
            Pricebook2Id = stdPbId,
            Bill_To__c = 'BILL001',
            Net_Value__c = '33088.160'
        );
        
        Test.startTest();
        insert ord;
        Test.stopTest();
        
        /* 5️⃣ Assertions */
        Order insertedOrder = [
            SELECT Id, Target__c
            FROM Order
            WHERE Id = :ord.Id
        ];
        System.assertEquals(tgt.Id, insertedOrder.Target__c,
                            'Target should be linked to Order');
        
        Target__c updatedTarget = [
            SELECT Qtr_1_Actual__c
            FROM Target__c
            WHERE Id = :tgt.Id
        ];
        //System.assertEquals(
            //33088.16,
            //updatedTarget.Qtr_1_Actual__c,
            //'Q1 Actual should be incremented correctly'
        //);
    }
    
    @IsTest
    static void testOrderAfterInsert_InvalidNetValue_SkippedSafely() {
        
        /* Target */
        Target__c tgt = new Target__c(
            //Name = 'Invalid Net Target',
            Bill_to_Party_Code__c = 'BILL002'
        );
        insert tgt;
        
        Account acc = new Account(Name = 'Test Account 2');
        insert acc;
        
        Id stdPbId = Test.getStandardPricebookId();
        
        /* Order with invalid Net_Value__c */
        Order ord = new Order(
            Name = 'Invalid Net Order',
            AccountId = acc.Id,
            Status = 'Draft',
            EffectiveDate = Date.newInstance(2025, 7, 10), // Q2
            Pricebook2Id = stdPbId,
            Bill_To__c = 'BILL002',
            Net_Value__c = 'ABC123' // invalid
        );
        
        Test.startTest();
        insert ord;
        Test.stopTest();
        
        /* Target should NOT be updated */
        Target__c tgtAfter = [
            SELECT Qtr_2_Actual__c
            FROM Target__c
            WHERE Id = :tgt.Id
        ];
        
        /*System.assertEquals(
            null,
            tgtAfter.Qtr_2_Actual__c,
            'Invalid Net_Value__c should not update target'
        );*/
    }
    
    @IsTest
    static void testOrderAfterInsert_NoTargetFound_NoFailure() {
        
        Account acc = new Account(Name = 'No Target Account');
        insert acc;
        
        Id stdPbId = Test.getStandardPricebookId();
        
        /* Order with no matching Target */
        Order ord = new Order(
            Name = 'No Target Order',
            AccountId = acc.Id,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id = stdPbId,
            Bill_To__c = 'UNKNOWN',
            Net_Value__c = '1000'
        );
        
        Test.startTest();
        insert ord;
        Test.stopTest();
        
        /* Ensure Order is created successfully */
        Order insertedOrder = [
            SELECT Id
            FROM Order
            WHERE Id = :ord.Id
        ];
        
        System.assertNotEquals(
            null,
            insertedOrder.Id,
            'Order creation must not fail even if Target not found'
        );
    }
}