/**
 * Scans WIP (day 6) and Future Prospect (day 90) leads and emails owners.
 *
 * Stateful: accumulates due leads across execute chunks, then sends one
 * consolidated email per owner (per stage) in finish().
 */
public without sharing class LeadStageReminderBatch implements Database.Batchable<SObject>, Database.Stateful {

    public Integer totalWip = 0;
    public Integer totalFuture = 0;
    public Integer totalSent = 0;
    public Integer totalFailed = 0;

    private Map<Id, List<Lead>> wipByOwner = new Map<Id, List<Lead>>();
    private Map<Id, List<Lead>> futureByOwner = new Map<Id, List<Lead>>();
    private Map<Id, String> ownerEmail = new Map<Id, String>();
    private Map<Id, String> ownerName = new Map<Id, String>();

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime wipFrom = Datetime.newInstance(Date.today().addDays(-7), Time.newInstance(0, 0, 0, 0));
        Datetime wipTo = Datetime.newInstance(Date.today().addDays(-5), Time.newInstance(23, 59, 59, 0));
        Datetime fpFrom = Datetime.newInstance(Date.today().addDays(-91), Time.newInstance(0, 0, 0, 0));
        Datetime fpTo = Datetime.newInstance(Date.today().addDays(-89), Time.newInstance(23, 59, 59, 0));

        return Database.getQueryLocator([
            SELECT
                Id,
                Name,
                FirstName,
                LastName,
                Company,
                Email,
                Phone,
                Status,
                Dealer_Status__c,
                IsConverted,
                OwnerId,
                Owner.Name,
                Owner.Email,
                LastModifiedDate,
                Work_In_Progress_Date_Time__c,
                Future_Prospect_Date_Time__c
            FROM Lead
            WHERE IsConverted = false
              AND (
                  (
                      Dealer_Status__c = :LeadStageReminderService.STATUS_WIP
                      AND Work_In_Progress_Date_Time__c >= :wipFrom
                      AND Work_In_Progress_Date_Time__c <= :wipTo
                  )
                  OR (
                      Dealer_Status__c = :LeadStageReminderService.STATUS_FUTURE
                      AND Future_Prospect_Date_Time__c >= :fpFrom
                      AND Future_Prospect_Date_Time__c <= :fpTo
                  )
              )
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Lead> leads = (List<Lead>) scope;

        for (Lead ld : leads) {
            if (ld == null || ld.IsConverted || ld.OwnerId == null) {
                continue;
            }
            if (ld.Owner == null || String.isBlank(ld.Owner.Email)) {
                continue;
            }

            if (ld.Dealer_Status__c == LeadStageReminderService.STATUS_WIP && ld.Work_In_Progress_Date_Time__c != null) {
                if (LeadStageReminderService.isReminderDue(
                    ld.Work_In_Progress_Date_Time__c,
                    LeadStageReminderService.WIP_DAYS
                )) {
                    totalWip++;
                    accumulate(wipByOwner, ld);
                    ownerEmail.put(ld.OwnerId, ld.Owner.Email);
                    ownerName.put(ld.OwnerId, ld.Owner.Name);
                }
            } else if (
                ld.Dealer_Status__c == LeadStageReminderService.STATUS_FUTURE &&
                ld.Future_Prospect_Date_Time__c != null
            ) {
                if (LeadStageReminderService.isReminderDue(
                    ld.Future_Prospect_Date_Time__c,
                    LeadStageReminderService.FUTURE_DAYS
                )) {
                    totalFuture++;
                    accumulate(futureByOwner, ld);
                    ownerEmail.put(ld.OwnerId, ld.Owner.Email);
                    ownerName.put(ld.OwnerId, ld.Owner.Name);
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        List<Lead> allDue = new List<Lead>();
        for (Id ownerId : wipByOwner.keySet()) {
            for (Lead ld : wipByOwner.get(ownerId)) {
                attachOwner(ld, ownerId);
                allDue.add(ld);
            }
        }
        for (Id ownerId : futureByOwner.keySet()) {
            for (Lead ld : futureByOwner.get(ownerId)) {
                attachOwner(ld, ownerId);
                allDue.add(ld);
            }
        }

        if (!allDue.isEmpty()) {
            LeadStageReminderService.SendSummary summary =
                LeadStageReminderService.processLeads(allDue);
            totalSent = summary.emailsSent;
            totalFailed = summary.emailsFailed;
            totalWip = summary.wipCandidates;
            totalFuture = summary.futureCandidates;
        }

        System.debug(
            LoggingLevel.INFO,
            'LeadStageReminderBatch finished. WIP=' + totalWip +
            ', Future=' + totalFuture +
            ', Sent=' + totalSent +
            ', Failed=' + totalFailed
        );
    }

    private void accumulate(Map<Id, List<Lead>> byOwner, Lead ld) {
        if (!byOwner.containsKey(ld.OwnerId)) {
            byOwner.put(ld.OwnerId, new List<Lead>());
        }
        byOwner.get(ld.OwnerId).add(ld);
    }

    private void attachOwner(Lead ld, Id ownerId) {
        // User.Name is not writeable — put display name in LastName for email greeting fallback
        User u = new User(
            Id = ownerId,
            Email = ownerEmail.get(ownerId),
            LastName = ownerName.get(ownerId)
        );
        ld.putSObject('Owner', u);
    }
}