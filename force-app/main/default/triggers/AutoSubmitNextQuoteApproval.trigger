trigger AutoSubmitNextQuoteApproval on Quote (after update) {
    for (Quote q : Trigger.new) {
        Quote oldQ = Trigger.oldMap.get(q.Id);

        try {
            // 0️⃣ Auto-submit first approval only if Small Order flag = TRUE
            // AND approval not already submitted
            if (q.Is_Small_Order_Handling__c == true &&
                (oldQ.Minimum_Offer_Approval_Status__c == null || oldQ.Minimum_Offer_Approval_Status__c == '') &&
                (q.Minimum_Offer_Approval_Status__c == null || q.Minimum_Offer_Approval_Status__c == '') &&
                q.Approval_Status__c != 'Pending' &&
                q.Approval_Status__c != 'Approved') {

                Approval.ProcessSubmitRequest req1 = new Approval.ProcessSubmitRequest();
                req1.setObjectId(q.Id);
                req1.setProcessDefinitionNameOrId('Quote_Minimum_Offer_Dynamic_Approval');
                Approval.process(req1);
            }
            // 1️⃣ When first approval gets Approved → auto-submit 2nd
            if (oldQ.Minimum_Offer_Approval_Status__c != 'Approved' &&
                q.Minimum_Offer_Approval_Status__c == 'Approved') {

                Approval.ProcessSubmitRequest req2 = new Approval.ProcessSubmitRequest();
                req2.setObjectId(q.Id);
                req2.setProcessDefinitionNameOrId('Quote_Dynamic_Payment_Terms_V3');
                Approval.process(req2);
            }

            // 2️⃣ When 2nd approval gets Approved → auto-submit 3rd
            if (oldQ.Payment_Terms_Approval_Status__c != 'Approved' &&
                q.Payment_Terms_Approval_Status__c == 'Approved') {

                Approval.ProcessSubmitRequest req3 = new Approval.ProcessSubmitRequest();
                req3.setObjectId(q.Id);
                req3.setProcessDefinitionNameOrId('Quote_Dynamic_Warranty_Terms_V3');
                Approval.process(req3);
            }

            // 3️⃣ When 3rd approval gets Approved → auto-submit 4th
            if (oldQ.Warranty_Terms_Approval_Status__c != 'Approved' &&
                q.Warranty_Terms_Approval_Status__c == 'Approved') {

                Approval.ProcessSubmitRequest req4 = new Approval.ProcessSubmitRequest();
                req4.setObjectId(q.Id);
                req4.setProcessDefinitionNameOrId('Quote_Dynamic_Validity_Terms_v7');
                Approval.process(req4);
            }

            // 4️⃣ Optional: after final approval (you can trigger final actions here)
            if (oldQ.Approval_Status__c != 'Approved' &&
                q.Approval_Status__c == 'Approved') {

                // Optional: mark quote as fully approved
                Quote updateQ = new Quote(Id = q.Id);
                updateQ.Final_Approval_Flag__c = true; // replace with your field
                update updateQ;
            }

        } catch (Exception e) {
            System.debug('⚠️ AutoSubmitNextQuoteApproval error for Quote ' + q.Id + ': ' + e.getMessage());
        }
    }
}