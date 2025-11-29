@isTest
public class OrderItemTriggerTest {

    @isTest
    static void testUpdateQuantityOnTarget() {

        // Activate Standard Pricebook
        Id standardPricebookId = Test.getStandardPricebookId();
        Pricebook2 stdPb = new Pricebook2(
            Id = standardPricebookId,
            Name = 'Standard Price Book'
        );
        upsert stdPb;

        // Create Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert prod;

        // Create PricebookEntry in Standard Pricebook if not exists
        PricebookEntry pbe;
        List<PricebookEntry> existingPbes = [
            SELECT Id FROM PricebookEntry 
            WHERE Pricebook2Id = :standardPricebookId 
            AND Product2Id = :prod.Id
            LIMIT 1
        ];

        if (!existingPbes.isEmpty()) {
            pbe = existingPbes[0];
        } else {
            pbe = new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = prod.Id,
                UnitPrice = 100,
                IsActive = true,
                CurrencyIsoCode = 'INR'
            );
            insert pbe;
        }

        // Create Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Create Order
        Order ord = new Order(
            Name = 'Test Order',
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = standardPricebookId
        );
        insert ord;

        // Create OrderItem (fires trigger)
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 100
        );

        Test.startTest();
        insert oi; // Trigger fires here
        Test.stopTest();

        // Verify trigger executed
        OrderItem insertedOi = [SELECT Id, Quantity FROM OrderItem WHERE Id = :oi.Id];
        System.assertEquals(5, insertedOi.Quantity, 'Quantity should match inserted value');
    }
}