/**
 * Processes each Channel Partner account that has inventory and creates
 * MTA quotes for products where Available Qty < Minimum Stock Level.
 */
public without sharing class InventoryMtaQuoteBatch implements Database.Batchable<SObject>, Database.Stateful {

    public Integer totalCreated = 0;
    public Integer totalSkipped = 0;
    public Integer totalFailed = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name
            FROM Account
            WHERE Id IN (
                SELECT Channel_Partner__c
                FROM Inventory__c
                WHERE Channel_Partner__c != null
                  AND Product__c != null
            )
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        for (SObject row : scope) {
            Account partner = (Account) row;
            try {
                InventoryMtaQuoteService.MtaQuoteCreateResult result =
                    InventoryMtaQuoteService.createMtaQuotesForPartner(partner.Id, null);
                totalCreated += result.createdCount == null ? 0 : result.createdCount;
                totalSkipped += result.skippedCount == null ? 0 : result.skippedCount;
                totalFailed += result.failedCount == null ? 0 : result.failedCount;
            } catch (Exception e) {
                totalFailed++;
                System.debug(
                    LoggingLevel.ERROR,
                    'InventoryMtaQuoteBatch partner ' + partner.Id + ': ' + e.getMessage()
                );
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(
            LoggingLevel.INFO,
            'InventoryMtaQuoteBatch finished. Created=' + totalCreated +
            ', Skipped=' + totalSkipped +
            ', Failed=' + totalFailed
        );
    }
}