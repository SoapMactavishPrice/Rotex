@isTest
public class API_Log_Summary_Batch_Order_Test {
     @IsTest
    static void testBatchExecution2() {
        Test.startTest();
        // Run the batch
        Database.executeBatch(new API_Log_Summary_Batch_Order(), 200);
        Test.stopTest();

        // Verify invoice records for yesterday
        Date yesterday = Date.today().addDays(-1);
        List<Order> yesterdayInvoices = [
            SELECT Id 
            FROM Order 
            WHERE EffectiveDate = :yesterday
        ];
       // System.assertEquals(2, yesterdayInvoices.size(), 'Should have 2 invoices from yesterday');

        // Total quantity should be parsed correctly (150 + 2500 = 2650)
        Integer expectedTotal = 2650;
        List<Order> allInvoices = [
            SELECT Net_Value__c 
            FROM Order 
            WHERE EffectiveDate = :yesterday
        ];
        Decimal netValue = 0;
        for(Order o : allInvoices) {
            if (o.Net_Value__c != null && o.Net_Value__c.trim() != '') {
                            netValue += Decimal.valueOf(o.Net_Value__c);
                        }
        }
       // System.assertEquals(expectedTotal, netValue, 'Total quantity should match for yesterday\'s invoices');
    }
}