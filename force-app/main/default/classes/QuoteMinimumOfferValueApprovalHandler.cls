public with sharing class QuoteMinimumOfferValueApprovalHandler {

    private static final String STATUS_SUBMITTED = 'Submitted';
    private static final String STATUS_APPROVED  = 'Approved';
    private static final String STATUS_REJECTED  = 'Rejected';

    private static final String PROFILE_SALES_REP          = 'Sales Rep';
    private static final String PROFILE_SALES_MANAGER      = 'Sales Manager';
    private static final String PROFILE_COUNTRY_HEAD       = 'Country / Continent Sales Head / LOB Head';
    private static final String PROFILE_GLOBAL_SALES_HEAD  = 'Global Sales Head';
    private static final String PROFILE_ROTEX_BOARD_MEMBER = 'Rotex Board Member';
    private static final String PROFILE_MANAGING_DIRECTOR  = 'Managing Director / Country Manager';

    private static final String NOTIFICATION_TYPE_API_NAME = 'Quote_Minimum_Offer_Value_Approval_Required';

    public static void handleAfterInsert(List<Quote> newQuotes) {
        Set<Decimal> totalValues = new Set<Decimal>();
        for (Quote q : newQuotes) {
            if (isEntryEligible(q)) {
                totalValues.add(q.Total_Value__c);
            }
        }
        if (totalValues.isEmpty()) return;

        Map<Decimal, String> profileByValue = getFinalApproverProfileByValue(totalValues);
        List<Quote> quotesToUpdate = new List<Quote>();

        for (Quote q : newQuotes) {
            if (!isEntryEligible(q)) continue;

            Quote quoteToUpdate = new Quote(Id = q.Id);
            resetApprovalFields(quoteToUpdate);

            String finalApproverProfile = profileByValue.get(q.Total_Value__c);
            if (String.isBlank(finalApproverProfile)) {
                finalApproverProfile = PROFILE_GLOBAL_SALES_HEAD;
            }
            applyInitialApprovalState(quoteToUpdate, q, finalApproverProfile);
            quotesToUpdate.add(quoteToUpdate);
        }

        if (!quotesToUpdate.isEmpty()) {
            update quotesToUpdate;
        }
    }

    public static void handleBeforeUpdate(List<Quote> newQuotes, Map<Id, Quote> oldQuoteMap) {
        Boolean anyStatusChanged = false;
        Set<Decimal> totalValuesForRecalc = new Set<Decimal>();

        for (Quote q : newQuotes) {
            Quote oldQ = oldQuoteMap.get(q.Id);
            if (oldQ == null) continue;

            Boolean becameEligible = isEntryEligible(q) && !isEntryEligible(oldQ);
            Boolean totalChangedWithinEligible = isEntryEligible(q) && q.Total_Value__c != oldQ.Total_Value__c;

            if (becameEligible || totalChangedWithinEligible) {
                totalValuesForRecalc.add(q.Total_Value__c);
            }
            if (hasApprovalStatusChanged(q, oldQ)) {
                anyStatusChanged = true;
            }
        }

        Map<Decimal, String> profileByValue = totalValuesForRecalc.isEmpty()
            ? new Map<Decimal, String>()
            : getFinalApproverProfileByValue(totalValuesForRecalc);

        for (Quote q : newQuotes) {
            Quote oldQ = oldQuoteMap.get(q.Id);
            if (oldQ == null) continue;

            Boolean becameEligible = isEntryEligible(q) && !isEntryEligible(oldQ);
            Boolean totalChangedWithinEligible = isEntryEligible(q) && q.Total_Value__c != oldQ.Total_Value__c;

            if (becameEligible || totalChangedWithinEligible) {
                resetApprovalFields(q);
                String finalApproverProfile = profileByValue.get(q.Total_Value__c);
                if (String.isBlank(finalApproverProfile)) {
                    finalApproverProfile = PROFILE_GLOBAL_SALES_HEAD;
                }
                applyInitialApprovalState(q, q, finalApproverProfile);
            }
        }

        if (anyStatusChanged) {
            handleApprovalProgression(newQuotes, oldQuoteMap);
        }
    }

    private static Boolean isEntryEligible(Quote q) {
        return q != null
            && q.Status == 'Draft'
            && q.Is_Small_Order_Handling__c == true
            && q.Total_Value__c != null
            && q.Total_Value__c < 25000;
    }

    private static Map<Decimal, String> getFinalApproverProfileByValue(Set<Decimal> totalValues) {
        Map<Decimal, String> profileByValue = new Map<Decimal, String>();
        if (totalValues == null || totalValues.isEmpty()) return profileByValue;

        List<SOA_Matrix__c> rows = [
            SELECT SOA_Profile__c, Min_Minimum_Offer_Value__c, Max_Minimum_Offer_Value__c
            FROM SOA_Matrix__c
            WHERE Min_Minimum_Offer_Value__c != null
              AND Max_Minimum_Offer_Value__c != null
        ];

        for (Decimal value : totalValues) {
            if (value == null) continue;
            for (SOA_Matrix__c row : rows) {
                if (value > row.Min_Minimum_Offer_Value__c && value <= row.Max_Minimum_Offer_Value__c) {
                    profileByValue.put(value, row.SOA_Profile__c);
                    break;
                }
            }
        }
        return profileByValue;
    }

    private static void applyInitialApprovalState(Quote target, Quote sourceQuote, String finalApproverProfile) {
        if (finalApproverProfile == PROFILE_SALES_REP ||
            finalApproverProfile == PROFILE_SALES_MANAGER ||
            finalApproverProfile == PROFILE_COUNTRY_HEAD) {
            target.Is_Minimum_Offer_Value_Approved__c = true;
            target.Final_Minimum_Offer_Value_Approver__c = null;
            return;
        }

        target.Final_Minimum_Offer_Value_Approver__c = resolveApproverUserId(sourceQuote, finalApproverProfile);
        target.GS_Min_Offer_Status__c = STATUS_SUBMITTED;
    }

    private static Id resolveApproverUserId(Quote q, String profileName) {
        if (profileName == PROFILE_GLOBAL_SALES_HEAD)  return q.Global_Sales_Head__c;
        if (profileName == PROFILE_ROTEX_BOARD_MEMBER) return q.Rotex_Board_Member__c;
        if (profileName == PROFILE_MANAGING_DIRECTOR)  return q.Managing_Director_Country_Manager__c;
        return q.Global_Sales_Head__c;
    }

    private static Boolean hasApprovalStatusChanged(Quote newQ, Quote oldQ) {
        return newQ.GS_Min_Offer_Status__c != oldQ.GS_Min_Offer_Status__c
            || newQ.BM_Min_Offer_Status__c != oldQ.BM_Min_Offer_Status__c
            || newQ.MD_Min_Offer_Status__c != oldQ.MD_Min_Offer_Status__c;
    }

    private static void handleApprovalProgression(List<Quote> newQuotes, Map<Id, Quote> oldQuoteMap) {
        Set<Id> quoteIdsForApprover = new Set<Id>();
        Set<Id> quoteIdsForOwner    = new Set<Id>();

        for (Quote q : newQuotes) {
            Quote oldQ = oldQuoteMap.get(q.Id);
            if (oldQ == null) continue;

            Integer finalHierarchy = getApproverHierarchyIndex(q, q.Final_Minimum_Offer_Value_Approver__c);
            if (finalHierarchy == null) finalHierarchy = 3;

            if (q.GS_Min_Offer_Status__c != oldQ.GS_Min_Offer_Status__c) {
                if (q.GS_Min_Offer_Status__c == STATUS_SUBMITTED) {
                    quoteIdsForApprover.add(q.Id);
                } else if (q.GS_Min_Offer_Status__c == STATUS_APPROVED) {
                    q.GS_Min_Offer_Date_Time__c = System.now();
                    if (finalHierarchy > 3) {
                        if (q.BM_Min_Offer_Status__c != STATUS_APPROVED && q.BM_Min_Offer_Status__c != STATUS_REJECTED) {
                            q.BM_Min_Offer_Status__c = STATUS_SUBMITTED;
                            quoteIdsForApprover.add(q.Id);
                        }
                    } else {
                        finalizeApproval(q);
                    }
                } else if (q.GS_Min_Offer_Status__c == STATUS_REJECTED) {
                    quoteIdsForOwner.add(q.Id);
                }
            }

            if (q.BM_Min_Offer_Status__c != oldQ.BM_Min_Offer_Status__c) {
                if (q.BM_Min_Offer_Status__c == STATUS_SUBMITTED) {
                    quoteIdsForApprover.add(q.Id);
                } else if (q.BM_Min_Offer_Status__c == STATUS_APPROVED) {
                    q.BM_Min_Offer_Date_Time__c = System.now();
                    if (finalHierarchy > 4) {
                        if (q.MD_Min_Offer_Status__c != STATUS_APPROVED && q.MD_Min_Offer_Status__c != STATUS_REJECTED) {
                            q.MD_Min_Offer_Status__c = STATUS_SUBMITTED;
                            quoteIdsForApprover.add(q.Id);
                        }
                    } else {
                        finalizeApproval(q);
                    }
                } else if (q.BM_Min_Offer_Status__c == STATUS_REJECTED) {
                    quoteIdsForOwner.add(q.Id);
                }
            }

            if (q.MD_Min_Offer_Status__c != oldQ.MD_Min_Offer_Status__c) {
                if (q.MD_Min_Offer_Status__c == STATUS_SUBMITTED) {
                    quoteIdsForApprover.add(q.Id);
                } else if (q.MD_Min_Offer_Status__c == STATUS_APPROVED) {
                    q.MD_Min_Offer_Date_Time__c = System.now();
                    finalizeApproval(q);
                } else if (q.MD_Min_Offer_Status__c == STATUS_REJECTED) {
                    quoteIdsForOwner.add(q.Id);
                }
            }
        }

        if (!quoteIdsForApprover.isEmpty() || !quoteIdsForOwner.isEmpty()) {
            sendApprovalNotifications(new List<Id>(quoteIdsForApprover), new List<Id>(quoteIdsForOwner));
        }
    }

    private static Integer getApproverHierarchyIndex(Quote q, Id approverId) {
        if (approverId == null) return null;
        if (q.Global_Sales_Head__c == approverId) return 3;
        if (q.Rotex_Board_Member__c == approverId) return 4;
        if (q.Managing_Director_Country_Manager__c == approverId) return 5;
        return null;
    }

    private static void finalizeApproval(Quote q) {
        q.Is_Minimum_Offer_Value_Approved__c = true;
    }

    private static void resetApprovalFields(Quote q) {
        q.Is_Minimum_Offer_Value_Approved__c = false;
        q.Final_Minimum_Offer_Value_Approver__c = null;

        q.SM_Min_Offer_Status__c = null;
        q.SM_Min_Offer_Date_Time__c = null;
        q.SM_Min_Offer_Comments__c = null;

        q.CH_Min_Offer_Status__c = null;
        q.CH_Min_Offer_Date_Time__c = null;
        q.CH_Min_Offer_Comments__c = null;

        q.GS_Min_Offer_Status__c = null;
        q.GS_Min_Offer_Date_Time__c = null;
        q.GS_Min_Offer_Comments__c = null;

        q.BM_Min_Offer_Status__c = null;
        q.BM_Min_Offer_Date_Time__c = null;
        q.BM_Min_Offer_Comments__c = null;

        q.MD_Min_Offer_Status__c = null;
        q.MD_Min_Offer_Date_Time__c = null;
        q.MD_Min_Offer_Comments__c = null;
    }

    @future
    private static void sendApprovalNotifications(List<Id> approverQuoteIds, List<Id> ownerQuoteIds) {
        Set<Id> allIds = new Set<Id>();
        allIds.addAll(approverQuoteIds);
        allIds.addAll(ownerQuoteIds);
        if (allIds.isEmpty()) return;

        Map<Id, Quote> quotesMap = new Map<Id, Quote>([
            SELECT Id, QuoteNumber, OwnerId, Owner.Email, Total_Value__c,
                   Global_Sales_Head__c, Global_Sales_Head__r.Email,
                   Rotex_Board_Member__c, Rotex_Board_Member__r.Email,
                   Managing_Director_Country_Manager__c, Managing_Director_Country_Manager__r.Email,
                   GS_Min_Offer_Status__c, BM_Min_Offer_Status__c, MD_Min_Offer_Status__c
            FROM Quote
            WHERE Id IN :allIds
        ]);

        CustomNotificationType notificationType;
        try {
            notificationType = [
                SELECT Id
                FROM CustomNotificationType
                WHERE DeveloperName = :NOTIFICATION_TYPE_API_NAME
                LIMIT 1
            ];
        } catch (Exception e) {
            System.debug('Custom Notification Type not found: ' + e.getMessage());
        }

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Id quoteId : approverQuoteIds) {
            Quote q = quotesMap.get(quoteId);
            if (q == null) continue;

            Id nextApproverId = getNextApproverId(q);
            String nextApproverEmail = getNextApproverEmail(q);
            if (nextApproverId == null || String.isBlank(nextApproverEmail)) continue;

            Messaging.SingleEmailMessage email = buildEmail(q, nextApproverEmail, false);
            if (email != null) emails.add(email);

            if (notificationType != null) {
                sendCustomNotification(notificationType.Id, q, nextApproverId, false);
            }
        }

        for (Id quoteId : ownerQuoteIds) {
            Quote q = quotesMap.get(quoteId);
            if (q == null || String.isBlank(q.Owner.Email)) continue;

            Messaging.SingleEmailMessage email = buildEmail(q, q.Owner.Email, true);
            if (email != null) emails.add(email);

            if (notificationType != null) {
                sendCustomNotification(notificationType.Id, q, q.OwnerId, true);
            }
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }

    private static Id getNextApproverId(Quote q) {
        if (q.MD_Min_Offer_Status__c == STATUS_SUBMITTED) return q.Managing_Director_Country_Manager__c;
        if (q.BM_Min_Offer_Status__c == STATUS_SUBMITTED) return q.Rotex_Board_Member__c;
        if (q.GS_Min_Offer_Status__c == STATUS_SUBMITTED) return q.Global_Sales_Head__c;
        return null;
    }

    private static String getNextApproverEmail(Quote q) {
        if (q.MD_Min_Offer_Status__c == STATUS_SUBMITTED && q.Managing_Director_Country_Manager__r != null) return q.Managing_Director_Country_Manager__r.Email;
        if (q.BM_Min_Offer_Status__c == STATUS_SUBMITTED && q.Rotex_Board_Member__r != null) return q.Rotex_Board_Member__r.Email;
        if (q.GS_Min_Offer_Status__c == STATUS_SUBMITTED && q.Global_Sales_Head__r != null) return q.Global_Sales_Head__r.Email;
        return null;
    }

    private static Messaging.SingleEmailMessage buildEmail(Quote q, String recipientEmail, Boolean isRejection) {
        if (String.isBlank(recipientEmail)) return null;

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ recipientEmail });
        email.setSaveAsActivity(true);
        email.setWhatId(q.Id);

        String approvalPageUrl = URL.getOrgDomainUrl().toExternalForm() + '/lightning/n/Quote_Discount_Approval';
        String quoteRecordUrl  = URL.getOrgDomainUrl().toExternalForm() + '/' + q.Id;

        if (isRejection) {
            email.setSubject('Quote Minimum Offer Value Approval Rejected — ' + q.QuoteNumber);
            email.setHtmlBody(
                'The minimum offer value approval for Quote ' + q.QuoteNumber +
                ' has been rejected.<br/><br/>Total value: ' + String.valueOf(q.Total_Value__c) +
                '<br/><br/>Please review the approver comments and take necessary action.<br/><br/>' +
                'Quote Record Page: <a href="' + quoteRecordUrl + '">click here</a>'
            );
        } else {
            email.setSubject('Approval Required: Minimum Offer Value — ' + q.QuoteNumber);
            email.setHtmlBody(
                'Your approval is required for minimum offer value on Quote ' + q.QuoteNumber +
                '.<br/><br/>Total value: ' + String.valueOf(q.Total_Value__c) +
                '<br/><br/>Please log in to review and approve or reject.<br/><br/>' +
                'Quote Approval Page: <a href="' + approvalPageUrl + '">click here</a>'
            );
        }
        return email;
    }

    private static void sendCustomNotification(Id notificationTypeId, Quote q, Id recipientId, Boolean isRejection) {
        if (recipientId == null) return;
        try {
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setNotificationTypeId(notificationTypeId);
            notification.setTargetId(q.Id);
            if (isRejection) {
                notification.setTitle('Quote Minimum Offer Value Approval Rejected');
                notification.setBody('Quote ' + q.QuoteNumber + ' minimum offer value approval has been rejected. Total value: ' + String.valueOf(q.Total_Value__c));
            } else {
                notification.setTitle('Minimum Offer Value Approval Required');
                notification.setBody('Your approval is required for minimum offer value on Quote ' + q.QuoteNumber + '. Total value: ' + String.valueOf(q.Total_Value__c));
            }
            notification.send(new Set<String>{ recipientId });
        } catch (Exception e) {
            System.debug('Error sending custom notification: ' + e.getMessage());
        }
    }
}
