/**
 * Builds and sends Lead stage reminder emails to Lead Owners:
 * - Work In Progress: on the 6th day in stage
 * - Future Prospect: on the 90th day
 *
 * Multiple due leads for the same owner are consolidated into one email
 * with an HTML table of all lead details.
 */
public without sharing class LeadStageReminderService {

    public static final String STATUS_WIP = 'Work In Progress';
    public static final String STATUS_FUTURE = 'Future Prospect';

    public static final Integer WIP_DAYS = 6;
    public static final Integer FUTURE_DAYS = 90;

    public static final String WIP_SUBJECT =
        'Reminder: Pending Action Required for Work In Progress Lead(s)';
    public static final String FUTURE_SUBJECT =
        'Reminder: Follow Up on Future Prospect Lead(s)';

    public class SendSummary {
        public Integer wipCandidates = 0;
        public Integer futureCandidates = 0;
        public Integer emailsSent = 0;
        public Integer emailsFailed = 0;
    }

    /**
     * True when the lead has been in the stage for exactly dayThreshold calendar days.
     */
    public static Boolean isReminderDue(Datetime stageStart, Integer dayThreshold) {
        if (stageStart == null) {
            return false;
        }
        return stageStart.date().daysBetween(Date.today()) == dayThreshold;
    }

    /**
     * Process a batch of leads; groups due leads by owner and sends one email per owner per stage.
     */
    public static SendSummary processLeads(List<Lead> leads) {
        SendSummary summary = new SendSummary();
        if (leads == null || leads.isEmpty()) {
            return summary;
        }

        Map<Id, List<Lead>> wipByOwner = new Map<Id, List<Lead>>();
        Map<Id, List<Lead>> futureByOwner = new Map<Id, List<Lead>>();
        Map<Id, String> ownerEmail = new Map<Id, String>();
        Map<Id, String> ownerName = new Map<Id, String>();

        for (Lead ld : leads) {
            if (ld == null || ld.IsConverted || ld.OwnerId == null) {
                continue;
            }
            if (ld.Owner == null || String.isBlank(ld.Owner.Email)) {
                continue;
            }

            if (ld.Dealer_Status__c == STATUS_WIP && ld.Work_In_Progress_Date_Time__c != null) {
                if (isReminderDue(ld.Work_In_Progress_Date_Time__c, WIP_DAYS)) {
                    summary.wipCandidates++;
                    addToOwnerMap(wipByOwner, ld);
                    ownerEmail.put(ld.OwnerId, ld.Owner.Email);
                    ownerName.put(ld.OwnerId, resolveOwnerDisplayName(ld));
                }
            } else if (ld.Dealer_Status__c == STATUS_FUTURE && ld.Future_Prospect_Date_Time__c != null) {
                if (isReminderDue(ld.Future_Prospect_Date_Time__c, FUTURE_DAYS)) {
                    summary.futureCandidates++;
                    addToOwnerMap(futureByOwner, ld);
                    ownerEmail.put(ld.OwnerId, ld.Owner.Email);
                    ownerName.put(ld.OwnerId, resolveOwnerDisplayName(ld));
                }
            }
        }

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Id ownerId : wipByOwner.keySet()) {
            emails.add(
                buildWipOwnerEmail(
                    ownerName.get(ownerId),
                    ownerEmail.get(ownerId),
                    wipByOwner.get(ownerId)
                )
            );
        }
        for (Id ownerId : futureByOwner.keySet()) {
            emails.add(
                buildFutureOwnerEmail(
                    ownerName.get(ownerId),
                    ownerEmail.get(ownerId),
                    futureByOwner.get(ownerId)
                )
            );
        }

        if (emails.isEmpty()) {
            return summary;
        }

        for (Integer i = 0; i < emails.size(); i += 10) {
            Integer endIdx = Math.min(i + 10, emails.size());
            List<Messaging.SingleEmailMessage> chunk = new List<Messaging.SingleEmailMessage>();
            for (Integer j = i; j < endIdx; j++) {
                chunk.add(emails[j]);
            }
            try {
                Messaging.SendEmailResult[] results = Messaging.sendEmail(chunk, false);
                for (Messaging.SendEmailResult r : results) {
                    if (r.isSuccess()) {
                        summary.emailsSent++;
                    } else {
                        summary.emailsFailed++;
                    }
                }
            } catch (Exception e) {
                summary.emailsFailed += chunk.size();
                System.debug(LoggingLevel.ERROR, 'LeadStageReminderService send failed: ' + e.getMessage());
            }
        }
        return summary;
    }

    private static void addToOwnerMap(Map<Id, List<Lead>> byOwner, Lead ld) {
        if (!byOwner.containsKey(ld.OwnerId)) {
            byOwner.put(ld.OwnerId, new List<Lead>());
        }
        byOwner.get(ld.OwnerId).add(ld);
    }

    private static String resolveOwnerDisplayName(Lead ld) {
        if (ld == null || ld.Owner == null) {
            return '—';
        }
        if (String.isNotBlank(ld.Owner.Name)) {
            return ld.Owner.Name;
        }
        try {
            String lastName = (String) ld.Owner.get('LastName');
            if (String.isNotBlank(lastName)) {
                return lastName;
            }
        } catch (Exception e) {
            // polymorphic Owner may not expose LastName
        }
        return '—';
    }

    private static Messaging.SingleEmailMessage buildWipOwnerEmail(
        String ownerName,
        String toAddress,
        List<Lead> leads
    ) {
        String greetingName = safe(ownerName);
        Integer count = leads.size();

        String plainIntro =
            'Dear ' + greetingName + ',\n\n' +
            'This is a friendly reminder that the following lead(s) assigned to you are currently in the Work In Progress stage and require your attention.\n\n' +
            'Please review the pending activities, update the latest progress, and move the lead(s) to the appropriate stage if applicable.\n\n' +
            'Lead Details (' + count + ')\n';

        String plainRows = '';
        String tableRows = '';
        for (Lead ld : leads) {
            String duration = stageDurationDisplay(ld.Work_In_Progress_Date_Time__c, WIP_DAYS);
            plainRows +=
                '- Lead Name: ' + safe(ld.Name) +
                ' | Company: ' + safe(ld.Company) +
                ' | Last Updated: ' + formatDate(ld.LastModifiedDate) +
                ' | Days in Stage: ' + duration + '\n';
            tableRows +=
                '<tr>' +
                td(safe(ld.Name)) +
                td(safe(ld.Company)) +
                td('Work In Progress') +
                td(formatDate(ld.LastModifiedDate)) +
                td(duration) +
                '</tr>';
        }

        String plainFooter =
            '\nTimely updates help ensure accurate pipeline tracking and enable effective follow-up with prospective customers.\n\n' +
            'If the lead has already been actioned, please update its status in Salesforce accordingly.\n\n' +
            'Thank you for your prompt attention.\n\n' +
            'Regards,\n' +
            'Salesforce CRM Team';

        String htmlBody =
            '<p>Dear ' + escapeHtml(greetingName) + ',</p>' +
            '<p>This is a friendly reminder that the following lead(s) assigned to you are currently in the ' +
            '<strong>Work In Progress</strong> stage and require your attention.</p>' +
            '<p>Please review the pending activities, update the latest progress, and move the lead(s) to the appropriate stage if applicable.</p>' +
            '<p><strong>Lead Details (' + count + ')</strong></p>' +
            tableShell(
                new List<String>{ 'Lead Name', 'Company', 'Current Stage', 'Last Updated', 'Days in Stage' },
                tableRows
            ) +
            '<p>Timely updates help ensure accurate pipeline tracking and enable effective follow-up with prospective customers.</p>' +
            '<p>If the lead has already been actioned, please update its status in Salesforce accordingly.</p>' +
            '<p>Thank you for your prompt attention.</p>' +
            '<p>Regards,<br/>Salesforce CRM Team</p>';

        Id relatedId = leads.size() == 1 ? leads[0].Id : null;
        return buildMessage(toAddress, WIP_SUBJECT, plainIntro + plainRows + plainFooter, htmlBody, relatedId);
    }

    private static Messaging.SingleEmailMessage buildFutureOwnerEmail(
        String ownerName,
        String toAddress,
        List<Lead> leads
    ) {
        String greetingName = safe(ownerName);
        Integer count = leads.size();

        String plainIntro =
            'Dear ' + greetingName + ',\n\n' +
            'This is a reminder that the following lead(s) have reached the scheduled follow-up and are ready for your review.\n\n' +
            'Please reconnect with the prospect to understand their current requirements, assess their interest, and update the lead status in Salesforce based on the outcome.\n\n' +
            'Lead Details (' + count + ')\n';

        String plainRows = '';
        String tableRows = '';
        for (Lead ld : leads) {
            String duration = stageDurationDisplay(ld.Future_Prospect_Date_Time__c, FUTURE_DAYS);
            plainRows +=
                '- Lead Name: ' + safe(ld.Name) +
                ' | Company: ' + safe(ld.Company) +
                ' | Contact: ' + resolveContactName(ld) +
                ' | Email: ' + safe(ld.Email) +
                ' | Phone: ' + safe(ld.Phone) +
                ' | Future Prospect Date: ' + formatDate(ld.Future_Prospect_Date_Time__c) +
                ' | Days Since Marked: ' + duration + '\n';
            tableRows +=
                '<tr>' +
                td(safe(ld.Name)) +
                td(safe(ld.Company)) +
                td(resolveContactName(ld)) +
                td(safe(ld.Email)) +
                td(safe(ld.Phone)) +
                td(formatDate(ld.Future_Prospect_Date_Time__c)) +
                td(duration) +
                '</tr>';
        }

        String plainFooter =
            '\nRecommended Actions\n' +
            'Contact the prospect via phone or email.\n' +
            'Verify if the opportunity is active.\n' +
            'Update the lead status based on the discussion.\n' +
            'Schedule the next follow-up, if required.\n\n' +
            'Keeping future prospects up to date helps ensure no potential business opportunity is missed.\n\n' +
            'Thank you.\n\n' +
            'Regards,\n' +
            'Salesforce CRM Team';

        String htmlBody =
            '<p>Dear ' + escapeHtml(greetingName) + ',</p>' +
            '<p>This is a reminder that the following lead(s) have reached the scheduled follow-up and are ready for your review.</p>' +
            '<p>Please reconnect with the prospect to understand their current requirements, assess their interest, and update the lead status in Salesforce based on the outcome.</p>' +
            '<p><strong>Lead Details (' + count + ')</strong></p>' +
            tableShell(
                new List<String>{
                    'Lead Name', 'Company', 'Contact', 'Email', 'Phone', 'Future Prospect Date', 'Days Since Marked'
                },
                tableRows
            ) +
            '<p><strong>Recommended Actions</strong></p>' +
            '<ul>' +
            '<li>Contact the prospect via phone or email.</li>' +
            '<li>Verify if the opportunity is active.</li>' +
            '<li>Update the lead status based on the discussion.</li>' +
            '<li>Schedule the next follow-up, if required.</li>' +
            '</ul>' +
            '<p>Keeping future prospects up to date helps ensure no potential business opportunity is missed.</p>' +
            '<p>Thank you.</p>' +
            '<p>Regards,<br/>Salesforce CRM Team</p>';

        Id relatedId = leads.size() == 1 ? leads[0].Id : null;
        return buildMessage(toAddress, FUTURE_SUBJECT, plainIntro + plainRows + plainFooter, htmlBody, relatedId);
    }

    private static String stageDurationDisplay(Datetime stageStart, Integer dayFallback) {
        if (stageStart == null) {
            return String.valueOf(dayFallback);
        }
        return String.valueOf(stageStart.date().daysBetween(Date.today()));
    }

    private static String tableShell(List<String> headers, String bodyRows) {
        String head = '';
        for (String h : headers) {
            head +=
                '<th style="padding:8px;border:1px solid #0d6b69;text-align:left;">' +
                escapeHtml(h) +
                '</th>';
        }
        return
            '<table style="border-collapse:collapse;width:100%;max-width:1000px;font-family:Arial,sans-serif;font-size:13px;">' +
            '<thead><tr style="background:#0d6b69;color:#ffffff;">' + head + '</tr></thead>' +
            '<tbody>' + bodyRows + '</tbody></table>';
    }

    private static String td(String value) {
        return '<td style="padding:8px;border:1px solid #d0d0d0;">' + escapeHtml(value) + '</td>';
    }

    private static Messaging.SingleEmailMessage buildMessage(
        String toAddress,
        String subject,
        String plainBody,
        String htmlBody,
        Id leadId
    ) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ toAddress });
        mail.setSubject(subject);
        mail.setPlainTextBody(plainBody);
        mail.setHtmlBody(htmlBody);
        mail.setSaveAsActivity(false);
        if (leadId != null) {
            mail.setWhatId(leadId);
        }
        mail.setUseSignature(false);
        return mail;
    }

    private static String resolveContactName(Lead ld) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(ld.FirstName)) {
            parts.add(ld.FirstName.trim());
        }
        if (String.isNotBlank(ld.LastName)) {
            parts.add(ld.LastName.trim());
        }
        if (!parts.isEmpty()) {
            return String.join(parts, ' ');
        }
        return safe(ld.Name);
    }

    private static String safe(String value) {
        return String.isBlank(value) ? '—' : value;
    }

    private static String escapeHtml(String value) {
        if (value == null) {
            return '';
        }
        return value
            .replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;');
    }

    private static String formatDate(Datetime dt) {
        if (dt == null) {
            return '—';
        }
        return dt.format('dd MMM yyyy');
    }
}