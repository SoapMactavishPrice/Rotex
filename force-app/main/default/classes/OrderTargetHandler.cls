public class OrderTargetHandler {

    public static void handleAfterInsert(List<Order> newOrders) {

        if (newOrders == null || newOrders.isEmpty()) return;

        Savepoint sp = Database.setSavepoint();

        try {

            /* 1️⃣ Collect Bill To Codes */
            Set<String> billToCodes = new Set<String>();
            for (Order ord : newOrders) {
                if (String.isNotBlank(ord.Bill_To__c) && ord.EffectiveDate != null) {
                    billToCodes.add(ord.Bill_To__c.trim());
                }
            }
            if (billToCodes.isEmpty()) return;

            /* 2️⃣ Fetch Targets (WITH Fiscal Year) */
            Map<String, List<Target__c>> targetsByBillTo = new Map<String, List<Target__c>>();

            for (Target__c tgt : [
                SELECT Id,
                       Bill_to_Party_Code__c,
                       Qtr_1_Actual__c,
                       Qtr_2_Actual__c,
                       Qtr_3_Actual__c,
                       Qtr_4_Actual__c,
                       Fiscal_Year__r.FY_Start_Date__c,
                       Fiscal_Year__r.FY_End_Date__c
                FROM Target__c
                WHERE Bill_to_Party_Code__c IN :billToCodes
            ]) {
                if (!targetsByBillTo.containsKey(tgt.Bill_to_Party_Code__c)) {
                    targetsByBillTo.put(
                        tgt.Bill_to_Party_Code__c,
                        new List<Target__c>()
                    );
                }
                targetsByBillTo.get(tgt.Bill_to_Party_Code__c).add(tgt);
            }

            if (targetsByBillTo.isEmpty()) return;

            /* 3️⃣ Prepare DML Containers */
            List<Order> ordersToUpdate = new List<Order>();
            Map<Id, Target__c> targetsToUpdate = new Map<Id, Target__c>();

            /* 4️⃣ Process Orders */
            for (Order ord : newOrders) {

                if (String.isBlank(ord.Bill_To__c)) continue;
                if (ord.EffectiveDate == null) continue;
                if (!targetsByBillTo.containsKey(ord.Bill_To__c)) continue;
                if (String.isBlank(ord.Net_Value__c)) continue;

                Decimal netValue;
                try {
                    netValue = Decimal.valueOf(ord.Net_Value__c.trim()).setScale(2);
                } catch (Exception ex) {
                    continue; // invalid SAP data → skip safely
                }

                /* 5️⃣ Find FY-matched Target */
                Date effDate = ord.EffectiveDate;
                Target__c matchedTarget;

                for (Target__c tgt : targetsByBillTo.get(ord.Bill_To__c)) {
                    if (
                        tgt.Fiscal_Year__r.FY_Start_Date__c != null &&
                        tgt.Fiscal_Year__r.FY_End_Date__c != null &&
                        tgt.Fiscal_Year__r.FY_Start_Date__c <= effDate &&
                        tgt.Fiscal_Year__r.FY_End_Date__c >= effDate
                    ) {
                        matchedTarget = tgt;
                        break;
                    }
                }

                if (matchedTarget == null) continue; // no FY match

                /* 6️⃣ Link Order → Target */
                ordersToUpdate.add(new Order(
                    Id = ord.Id,
                    Target__c = matchedTarget.Id
                ));

                /* 7️⃣ Prepare Target Update */
                if (!targetsToUpdate.containsKey(matchedTarget.Id)) {
                    targetsToUpdate.put(matchedTarget.Id, matchedTarget);
                }

                Target__c tgtUpd = targetsToUpdate.get(matchedTarget.Id);

                /* 8️⃣ FY Quarter Logic (Apr–Mar) */
                Integer monthNum = effDate.month();

                if (monthNum >= 4 && monthNum <= 6) {
                    tgtUpd.Qtr_1_Actual__c =
                        (tgtUpd.Qtr_1_Actual__c == null ? 0 : tgtUpd.Qtr_1_Actual__c) + netValue;

                } else if (monthNum >= 7 && monthNum <= 9) {
                    tgtUpd.Qtr_2_Actual__c =
                        (tgtUpd.Qtr_2_Actual__c == null ? 0 : tgtUpd.Qtr_2_Actual__c) + netValue;

                } else if (monthNum >= 10 && monthNum <= 12) {
                    tgtUpd.Qtr_3_Actual__c =
                        (tgtUpd.Qtr_3_Actual__c == null ? 0 : tgtUpd.Qtr_3_Actual__c) + netValue;

                } else { // Jan–Mar
                    tgtUpd.Qtr_4_Actual__c =
                        (tgtUpd.Qtr_4_Actual__c == null ? 0 : tgtUpd.Qtr_4_Actual__c) + netValue;
                }
            }

            /* 9️⃣ Non-blocking DML */
            if (!ordersToUpdate.isEmpty()) {
                Database.update(ordersToUpdate, false);
            }

            if (!targetsToUpdate.isEmpty()) {
                Database.update(targetsToUpdate.values(), false);
            }

        } catch (Exception e) {

            // 🔒 SAP-SAFE rollback
            Database.rollback(sp);

            // Optional logging
            System.debug('OrderTargetHandler Error → ' + e.getMessage());

            // ❌ DO NOT throw exception
        }
    }
}