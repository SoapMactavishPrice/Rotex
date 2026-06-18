public with sharing class QuoteWarrantyApprovalHandler {

    public static Boolean bypassDraftApprovalReset = false;

    private static final String STATUS_SUBMITTED = 'Submitted';
    private static final String STATUS_APPROVED  = 'Approved';
    private static final String STATUS_REJECTED  = 'Rejected';
    private static final String DEFAULT_WARRANTY_TERMS = '12 Months from date of supply';

    private static final String PROFILE_SALES_MANAGER      = 'Sales Manager';
    private static final String PROFILE_COUNTRY_HEAD       = 'Country / Continent Sales Head / LOB Head';
    private static final String PROFILE_GLOBAL_SALES_HEAD  = 'Global Sales Head';
    private static final String PROFILE_ROTEX_BOARD_MEMBER = 'Rotex Board Member';
    private static final String PROFILE_MANAGING_DIRECTOR  = 'Managing Director / Country Manager';
    
    private static final String NOTIFICATION_TYPE_API_NAME = 'Quote_Warranty_Approval_Required';

    public static void handleBeforeUpdate(List<Quote> newQuotes, Map<Id, Quote> oldQuoteMap) {

        Boolean anyStatusChanged = false;

        for (Quote q : newQuotes) {
            Quote oldQ = oldQuoteMap.get(q.Id);

            if (!bypassDraftApprovalReset &&
                q.Warranty_Terms_Draft__c != oldQ.Warranty_Terms_Draft__c) {
                resetApprovalFields(q);

                if (q.Warranty_Terms_Draft__c == DEFAULT_WARRANTY_TERMS) {
                    q.Warranty_Terms__c = q.Warranty_Terms_Draft__c;
                } else {
                    initiateApprovalProcess(q);
                }
            }

            if (hasApprovalStatusChanged(q, oldQ)) {
                anyStatusChanged = true;
            }
        }

        if (anyStatusChanged) {
            handleApprovalProgression(newQuotes, oldQuoteMap);
        }
    }

    private static void initiateApprovalProcess(Quote q) {
        String finalApproverProfile            = determineFinalApproverProfile(q.Warranty_Terms_Draft__c);
        q.Final_Warranty_Terms_Approver__c     = resolveApproverUserId(q, finalApproverProfile);
        q.SM_Warranty_Status__c                = STATUS_SUBMITTED;
    }

    private static String determineFinalApproverProfile(String warrantyTerms) {

        String normalizedTerm;

        if      (warrantyTerms == '24 Months from date of supply')           normalizedTerm = '24 Months';
        else if (warrantyTerms == '30 Months from date of supply')           normalizedTerm = '30 Months';
        else if (warrantyTerms == '36 Months from date of supply')           normalizedTerm = '36 Months';
        else if (warrantyTerms == '48 Months from date of supply')           normalizedTerm = '48 Months';
        else if (warrantyTerms == 'More than 48 Months from date of supply') normalizedTerm = 'More than 48 Months';

        if (normalizedTerm != null) {
            List<SOA_Matrix__c> rows = [
                SELECT SOA_Profile__c
                FROM   SOA_Matrix__c
                WHERE  Warranty_Terms__c = :normalizedTerm
                LIMIT  1
            ];
            if (!rows.isEmpty()) {
                return rows[0].SOA_Profile__c;
            }
        }

        return PROFILE_SALES_MANAGER;
    }

    private static Id resolveApproverUserId(Quote q, String profileName) {
        if (profileName == PROFILE_SALES_MANAGER)      return q.Sales_Manager__c;
        if (profileName == PROFILE_COUNTRY_HEAD)       return q.Country_Continent_Sales_Head_LOB_Head__c;
        if (profileName == PROFILE_GLOBAL_SALES_HEAD)  return q.Global_Sales_Head__c;
        if (profileName == PROFILE_ROTEX_BOARD_MEMBER) return q.Rotex_Board_Member__c;
        if (profileName == PROFILE_MANAGING_DIRECTOR)  return q.Managing_Director_Country_Manager__c;
        return q.Sales_Manager__c;
    }

    private static Boolean hasApprovalStatusChanged(Quote newQ, Quote oldQ) {
        return newQ.SM_Warranty_Status__c != oldQ.SM_Warranty_Status__c
            || newQ.CH_Warranty_Status__c != oldQ.CH_Warranty_Status__c
            || newQ.GS_Warranty_Status__c != oldQ.GS_Warranty_Status__c
            || newQ.BM_Warranty_Status__c != oldQ.BM_Warranty_Status__c
            || newQ.MD_Warranty_Status__c != oldQ.MD_Warranty_Status__c;
    }

    private static void handleApprovalProgression(List<Quote> newQuotes, Map<Id, Quote> oldQuoteMap) {

        Set<Id> quoteIdsForApprover = new Set<Id>();
        Set<Id> quoteIdsForOwner    = new Set<Id>();

        for (Quote q : newQuotes) {
            Quote oldQ = oldQuoteMap.get(q.Id);

            String finalProfile = determineFinalApproverProfile(q.Warranty_Terms_Draft__c);

            // ── Sales Manager ─────────────────────────────────────────────
            if (q.SM_Warranty_Status__c != oldQ.SM_Warranty_Status__c) {
                if (q.SM_Warranty_Status__c == STATUS_SUBMITTED) {
                    quoteIdsForApprover.add(q.Id);

                } else if (q.SM_Warranty_Status__c == STATUS_APPROVED) {
                    q.SM_Warranty_Date_Time__c = System.now();
                    if (shouldProgressToNextLevel(finalProfile, PROFILE_SALES_MANAGER)) {
                        if (q.CH_Warranty_Status__c != STATUS_APPROVED && q.CH_Warranty_Status__c != STATUS_REJECTED) {
                            q.CH_Warranty_Status__c = STATUS_SUBMITTED;
                            quoteIdsForApprover.add(q.Id);
                        }
                    } else {
                        finalizeApproval(q);
                    }
                } else if (q.SM_Warranty_Status__c == STATUS_REJECTED) {
                    quoteIdsForOwner.add(q.Id);
                }
            }

            // ── Country / Continent Head ──────────────────────────────────
            if (q.CH_Warranty_Status__c != oldQ.CH_Warranty_Status__c) {
                if (q.CH_Warranty_Status__c == STATUS_SUBMITTED) {
                    quoteIdsForApprover.add(q.Id);

                } else if (q.CH_Warranty_Status__c == STATUS_APPROVED) {
                    q.CH_Warranty_Date_Time__c = System.now();
                    if (shouldProgressToNextLevel(finalProfile, PROFILE_COUNTRY_HEAD)) {
                        if (q.GS_Warranty_Status__c != STATUS_APPROVED && q.GS_Warranty_Status__c != STATUS_REJECTED) {
                            q.GS_Warranty_Status__c = STATUS_SUBMITTED;
                            quoteIdsForApprover.add(q.Id);
                        }
                    } else {
                        finalizeApproval(q);
                    }
                } else if (q.CH_Warranty_Status__c == STATUS_REJECTED) {
                    quoteIdsForOwner.add(q.Id);
                }
            }

            // ── Global Sales Head ─────────────────────────────────────────
            if (q.GS_Warranty_Status__c != oldQ.GS_Warranty_Status__c) {
                if (q.GS_Warranty_Status__c == STATUS_SUBMITTED) {
                    quoteIdsForApprover.add(q.Id);

                } else if (q.GS_Warranty_Status__c == STATUS_APPROVED) {
                    q.GS_Warranty_Date_Time__c = System.now();
                    if (shouldProgressToNextLevel(finalProfile, PROFILE_GLOBAL_SALES_HEAD)) {
                        if (q.BM_Warranty_Status__c != STATUS_APPROVED && q.BM_Warranty_Status__c != STATUS_REJECTED) {
                            q.BM_Warranty_Status__c = STATUS_SUBMITTED;
                            quoteIdsForApprover.add(q.Id);
                        }
                    } else {
                        finalizeApproval(q);
                    }
                } else if (q.GS_Warranty_Status__c == STATUS_REJECTED) {
                    quoteIdsForOwner.add(q.Id);
                }
            }

            // ── Rotex Board Member ────────────────────────────────────────
            if (q.BM_Warranty_Status__c != oldQ.BM_Warranty_Status__c) {
                if (q.BM_Warranty_Status__c == STATUS_SUBMITTED) {
                    quoteIdsForApprover.add(q.Id);

                } else if (q.BM_Warranty_Status__c == STATUS_APPROVED) {
                    q.BM_Warranty_Date_Time__c = System.now();
                    if (shouldProgressToNextLevel(finalProfile, PROFILE_ROTEX_BOARD_MEMBER)) {
                        if (q.MD_Warranty_Status__c != STATUS_APPROVED && q.MD_Warranty_Status__c != STATUS_REJECTED) {
                            q.MD_Warranty_Status__c = STATUS_SUBMITTED;
                            quoteIdsForApprover.add(q.Id);
                        }
                    } else {
                        finalizeApproval(q);
                    }
                } else if (q.BM_Warranty_Status__c == STATUS_REJECTED) {
                    quoteIdsForOwner.add(q.Id);
                }
            }

            // ── Managing Director ─────────────────────────────────────────
            if (q.MD_Warranty_Status__c != oldQ.MD_Warranty_Status__c) {
                if (q.MD_Warranty_Status__c == STATUS_SUBMITTED) {
                    quoteIdsForApprover.add(q.Id);

                } else if (q.MD_Warranty_Status__c == STATUS_APPROVED) {
                    q.MD_Warranty_Date_Time__c = System.now();
                    finalizeApproval(q);
                } else if (q.MD_Warranty_Status__c == STATUS_REJECTED) {
                    quoteIdsForOwner.add(q.Id);
                }
            }
        }

        if (!quoteIdsForApprover.isEmpty() || !quoteIdsForOwner.isEmpty()) {
            sendApprovalNotifications(
                new List<Id>(quoteIdsForApprover),
                new List<Id>(quoteIdsForOwner)
            );
        }
    }

    private static Boolean shouldProgressToNextLevel(
            String finalApproverProfile, String currentApprover) {

        List<String> hierarchy = new List<String>{
            PROFILE_SALES_MANAGER,
            PROFILE_COUNTRY_HEAD,
            PROFILE_GLOBAL_SALES_HEAD,
            PROFILE_ROTEX_BOARD_MEMBER,
            PROFILE_MANAGING_DIRECTOR
        };

        Integer currentIdx = hierarchy.indexOf(currentApprover);
        Integer finalIdx   = hierarchy.indexOf(finalApproverProfile);

        return currentIdx < finalIdx;
    }

    private static void finalizeApproval(Quote q) {
        q.Warranty_Terms__c = q.Warranty_Terms_Draft__c;
    }

    private static void resetApprovalFields(Quote q) {
        q.Final_Warranty_Terms_Approver__c = null;

        q.SM_Warranty_Status__c    = null;
        q.SM_Warranty_Date_Time__c = null;
        q.SM_Warranty_Comments__c  = null;

        q.CH_Warranty_Status__c    = null;
        q.CH_Warranty_Date_Time__c = null;
        q.CH_Warranty_Comments__c  = null;

        q.GS_Warranty_Status__c    = null;
        q.GS_Warranty_Date_Time__c = null;
        q.GS_Warranty_Comments__c  = null;

        q.BM_Warranty_Status__c    = null;
        q.BM_Warranty_Date_Time__c = null;
        q.BM_Warranty_Comments__c  = null;

        q.MD_Warranty_Status__c    = null;
        q.MD_Warranty_Date_Time__c = null;
        q.MD_Warranty_Comments__c  = null;
    }

    @future
    private static void sendApprovalNotifications(
            List<Id> approverQuoteIds, List<Id> ownerQuoteIds) {

        Set<Id> allIds = new Set<Id>();
        allIds.addAll(approverQuoteIds);
        allIds.addAll(ownerQuoteIds);

        // Query quotes with all necessary fields including approver emails
        Map<Id, Quote> quotesMap = new Map<Id, Quote>([
            SELECT Id, QuoteNumber, OwnerId, Owner.Email,
                   Warranty_Terms_Draft__c,
                   Sales_Manager__c, Sales_Manager__r.Email,
                   Country_Continent_Sales_Head_LOB_Head__c, Country_Continent_Sales_Head_LOB_Head__r.Email,
                   Global_Sales_Head__c, Global_Sales_Head__r.Email,
                   Rotex_Board_Member__c, Rotex_Board_Member__r.Email,
                   Managing_Director_Country_Manager__c, Managing_Director_Country_Manager__r.Email,
                   SM_Warranty_Status__c,
                   CH_Warranty_Status__c,
                   GS_Warranty_Status__c,
                   BM_Warranty_Status__c,
                   MD_Warranty_Status__c
            FROM   Quote
            WHERE  Id IN :allIds
        ]);

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        // Get the Custom Notification Type
        CustomNotificationType notificationType;
        try {
            notificationType = [
                SELECT Id, DeveloperName 
                FROM CustomNotificationType 
                WHERE DeveloperName = :NOTIFICATION_TYPE_API_NAME
                LIMIT 1
            ];
        } catch (Exception e) {
            System.debug('Custom Notification Type not found: ' + e.getMessage());
        }

        // Process approver notifications
        for (Id quoteId : approverQuoteIds) {
            Quote q = quotesMap.get(quoteId);
            if (q == null) continue;
            
            Id nextApproverId = getNextApproverId(q);
            String nextApproverEmail = getNextApproverEmail(q);
            
            if (nextApproverId == null || String.isBlank(nextApproverEmail)) continue;
            
            // Build and add email
            Messaging.SingleEmailMessage email = buildEmail(q, nextApproverEmail, false);
            if (email != null) emails.add(email);
            
            // Send custom notification
            if (notificationType != null) {
                sendCustomNotification(notificationType.Id, q, nextApproverId, false);
            }
        }

        // Process owner rejection notifications
        for (Id quoteId : ownerQuoteIds) {
            Quote q = quotesMap.get(quoteId);
            if (q == null || String.isBlank(q.Owner.Email)) continue;
            
            // Build and add email
            Messaging.SingleEmailMessage email = buildEmail(q, q.Owner.Email, true);
            if (email != null) emails.add(email);
            
            // Send custom notification
            if (notificationType != null) {
                sendCustomNotification(notificationType.Id, q, q.OwnerId, true);
            }
        }

        // Send all emails
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }

    private static Id getNextApproverId(Quote q) {
        if (q.MD_Warranty_Status__c == STATUS_SUBMITTED) return q.Managing_Director_Country_Manager__c;
        if (q.BM_Warranty_Status__c == STATUS_SUBMITTED) return q.Rotex_Board_Member__c;
        if (q.GS_Warranty_Status__c == STATUS_SUBMITTED) return q.Global_Sales_Head__c;
        if (q.CH_Warranty_Status__c == STATUS_SUBMITTED) return q.Country_Continent_Sales_Head_LOB_Head__c;
        if (q.SM_Warranty_Status__c == STATUS_SUBMITTED) return q.Sales_Manager__c;
        return null;
    }

    private static String getNextApproverEmail(Quote q) {
        if (q.MD_Warranty_Status__c == STATUS_SUBMITTED && q.Managing_Director_Country_Manager__r != null) {
            return q.Managing_Director_Country_Manager__r.Email;
        }
        if (q.BM_Warranty_Status__c == STATUS_SUBMITTED && q.Rotex_Board_Member__r != null) {
            return q.Rotex_Board_Member__r.Email;
        }
        if (q.GS_Warranty_Status__c == STATUS_SUBMITTED && q.Global_Sales_Head__r != null) {
            return q.Global_Sales_Head__r.Email;
        }
        if (q.CH_Warranty_Status__c == STATUS_SUBMITTED && q.Country_Continent_Sales_Head_LOB_Head__r != null) {
            return q.Country_Continent_Sales_Head_LOB_Head__r.Email;
        }
        if (q.SM_Warranty_Status__c == STATUS_SUBMITTED && q.Sales_Manager__r != null) {
            return q.Sales_Manager__r.Email;
        }
        return null;
    }

    private static Messaging.SingleEmailMessage buildEmail(
            Quote q, String recipientEmail, Boolean isRejection) {

        if (String.isBlank(recipientEmail)) return null;

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{recipientEmail});
        email.setSaveAsActivity(true);
        email.setWhatId(q.Id);

        String approvalPageUrl = URL.getOrgDomainUrl().toExternalForm() + '/lightning/n/Quote_Discount_Approval';
        String quoteRecordUrl  = URL.getOrgDomainUrl().toExternalForm() + '/' + q.Id;

        if (isRejection) {
            email.setSubject('Quote Warranty Terms Rejected — ' + q.QuoteNumber);
            email.setHtmlBody(
                'The warranty terms approval for Quote ' + q.QuoteNumber +
                ' has been rejected.<br/><br/>Proposed terms: ' + q.Warranty_Terms_Draft__c +
                '<br/><br/>Please review the approver comments and take necessary action.<br/><br/>' +
                'Quote Record Page: <a href="' + quoteRecordUrl + '">click here</a>'
            );
        } else {
            email.setSubject('Approval Required: Warranty Terms — ' + q.QuoteNumber);
            email.setHtmlBody(
                'Your approval is required for the warranty terms on Quote ' + q.QuoteNumber +
                '.<br/><br/>Proposed warranty terms: ' + q.Warranty_Terms_Draft__c +
                '<br/><br/>Please log in to review and approve or reject.<br/><br/>' +
                'Quote Approval Page: <a href="' + approvalPageUrl + '">click here</a>'
            );
        }

        return email;
    }

    private static void sendCustomNotification(
        Id notificationTypeId, Quote q, Id recipientId, Boolean isRejection) {
        if (recipientId == null) return;
        try {
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setNotificationTypeId(notificationTypeId);
            notification.setTargetPageRef(JSON.serialize(new Map<String, Object>{
                'type' => 'standard__navItemPage',
                'attributes' => new Map<String, Object>{
                    'apiName' => 'Quote_Discount_Approval'
                }
            }));
            if (isRejection) {
                notification.setTitle('Quote Warranty Terms Rejected');

                notification.setBody(
                    'Quote ' + q.QuoteNumber +
                    ' warranty terms have been rejected. Proposed terms: ' +
                    q.Warranty_Terms_Draft__c
                );
            } else {
                notification.setTitle('Warranty Approval Required');

                notification.setBody(
                    'Your approval is required for warranty terms on Quote ' +
                    q.QuoteNumber +
                    '. Proposed terms: ' +
                    q.Warranty_Terms_Draft__c
                );
            }
            notification.send(new Set<String>{ recipientId });
        } catch (Exception e) {
            System.debug('Error sending custom notification: ' + e.getMessage());
        }
    }
}