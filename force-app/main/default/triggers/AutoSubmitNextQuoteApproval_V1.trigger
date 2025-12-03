trigger AutoSubmitNextQuoteApproval_V1 on Quote (after update) {

    if (AutoApprovalHelper.isRunning) return;
    AutoApprovalHelper.isRunning = true;

    for (Quote q : Trigger.new) {
        Quote oldQ = Trigger.oldMap.get(q.Id);
        Boolean submitted = false;

        // ******** LEVEL 1 ********
       // if (!submitted && q.Is_Small_Order_Handling__c == true && String.isBlank(q.Minimum_Offer_Approval_Status__c)) {
       //     submitted = AutoApprovalHelper.submitApproval(q.Id, 'Quote_Minimum_Offer_Dynamic_Approval');
      //  }

        // ***** LEVEL 1 *****
        if (!submitted && oldQ.Is_Small_Order_Handling__c == true && oldQ.TotalPrice <= 20000 && String.isBlank(oldQ.Minimum_Offer_Approval_Status__c)) 
        {
            submitted = AutoApprovalHelper.submitApproval(oldQ.Id, 'Quote_Minimum_Offer_Dynamic_Approval');
        }

        // ******** LEVEL 2 ********
        if (!submitted && !String.isBlank(q.Payment_Terms__c) && String.isBlank(q.Payment_Terms_Approval_Status__c)) {
            submitted = AutoApprovalHelper.submitApproval(q.Id, 'Quote_Dynamic_Payment_Terms_V3');
        }

        // ******** LEVEL 3 ********
        if (!submitted && !String.isBlank(q.Warranty_Terms__c) && String.isBlank(q.Warranty_Terms_Approval_Status__c)) {
            submitted = AutoApprovalHelper.submitApproval(q.Id, 'Quote_Dynamic_Warranty_Terms_V3');
        }

        // ******** LEVEL 4 ********
        if (!submitted && !String.isBlank(q.Validity_of_Offer__c) && String.isBlank(q.Approval_Status__c)) {
            submitted = AutoApprovalHelper.submitApproval(q.Id, 'Quote_Dynamic_Validity_Approval_V6');
        }
    }

    AutoApprovalHelper.isRunning = false;
}