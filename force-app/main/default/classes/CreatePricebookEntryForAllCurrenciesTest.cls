@isTest
public class CreatePricebookEntryForAllCurrenciesTest {

    @testSetup
    static void setup() {
        Id standardPricebookId = Test.getStandardPricebookId();

        Pricebook2 stdPb = new Pricebook2(
            Id = standardPricebookId,
            Name = 'Standard Price Book',
            IsActive = true
        );
        upsert stdPb;

        List<Product2> products = new List<Product2>{
            new Product2(Name = 'VOXCO CHROME ORANGE VO-750/SA', Family = 'VO', IsActive = true, ProductCode = 'T001'),
            new Product2(Name = 'VOXCO SCARLET CHROME', Family = 'VOS', IsActive = true, ProductCode = 'T002'),
            new Product2(Name = 'VOXCO ZINC CHROME', Family = 'Anti-Corrosive', IsActive = true, ProductCode = 'T003')
        };
        insert products;

        List<PricebookEntry> stdEntries = new List<PricebookEntry>();
        for (Product2 p : products) {
            if ([SELECT COUNT() FROM PricebookEntry WHERE Pricebook2Id = :standardPricebookId AND Product2Id = :p.Id] == 0) {
                stdEntries.add(new PricebookEntry(
                    Pricebook2Id = standardPricebookId,
                    Product2Id = p.Id,
                    UnitPrice = 100,
                    IsActive = true
                ));
            }
        }
        if (!stdEntries.isEmpty()) insert stdEntries;

        Pricebook2 customPB = new Pricebook2(Name = 'Test Pricebook', IsActive = true);
        insert customPB;

        List<PricebookEntry> customEntries = new List<PricebookEntry>();
        for (Product2 p : products) {
            customEntries.add(new PricebookEntry(
                Pricebook2Id = customPB.Id,
                Product2Id = p.Id,
                UnitPrice = 120,
                IsActive = true
            ));
        }
        insert customEntries;
    }

    @isTest
    static void testPricebookEntryTrigger() {
        List<CurrencyType> activeCurrencies = [SELECT IsoCode FROM CurrencyType WHERE IsActive = true];

        Product2 testProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'T001' LIMIT 1];

        Test.startTest();
        Product2 newProduct = new Product2(Name = 'New Test Product', Family = 'Test', IsActive = true, ProductCode = 'T010');
        insert newProduct;
        Test.stopTest();

        Id standardPBId = Test.getStandardPricebookId();

        List<PricebookEntry> entries = [
            SELECT Id, Product2Id, Pricebook2Id, CurrencyIsoCode, UnitPrice, IsActive
            FROM PricebookEntry
            WHERE Product2Id = :newProduct.Id
        ];

        System.debug('PricebookEntry records created: ' + entries);

    }
}