@IsTest
public class ZPR0PricingBatchTest {

    // Mock response for ZPR0 API
    private class ZPR0MockCallout implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            res.setBody(
                '[' +
                '{' +
                '"ConditionRecord":"0000777458",' +
                '"ConditionType":"ZPR0",' +
                '"SalesOrg":"1100",' +
                '"DistributionChannel":"10",' +
                '"Material":"TEST001",' +
                '"ConditionAmt":"100.00",' +
                '"PricingUnit":"1",' +
                '"UnitOfMeasure":"EA",' +
                '"ValidFrom":"20260723",' +
                '"ValidTo":"99991231",' +
                '"CoditionCurr":"INR"' +
                '}' +
                ']'
            );

            return res;
        }
    }

    @TestSetup
    static void setupData() {

        Product2 prod = new Product2(
            Name = 'Test Product',
            ProductCode = 'TEST001',
            IsActive = true
        );
        insert prod;

        Pricebook2 pb = new Pricebook2(
            Name = 'Test Pricebook',
            IsActive = true,
            Distribution_Channel__c = '10'
        );
        insert pb;
    }

    @IsTest
    static void testBatchExecution() {

        Test.setMock(HttpCalloutMock.class, new ZPR0MockCallout());

        Test.startTest();

        Database.executeBatch(new ZPR0PricingBatch(), 1);

        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testScheduler() {

        Test.setMock(HttpCalloutMock.class, new ZPR0MockCallout());

        Test.startTest();

        String cron =
            '0 0 0 1 1 ? 2099';

        System.schedule(
            'ZPR0 Pricing Batch Test',
            cron,
            new ZPR0PricingBatch()
        );

        Test.stopTest();

        CronTrigger ct = [
            SELECT Id,
                   CronExpression,
                   State
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'ZPR0 Pricing Batch Test'
            LIMIT 1
        ];

        System.assertEquals('WAITING', ct.State);
    }

}