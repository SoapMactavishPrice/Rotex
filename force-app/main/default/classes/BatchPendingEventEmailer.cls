public class BatchPendingEventEmailer implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
    
    // ─── State (accumulated across all batch chunks) ─────────────────────────
    private Map<Id, List<Event>> ownerEventMap = new Map<Id, List<Event>>();
    
    // ─── Schedulable: execute() ──────────────────────────────────────────────
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new BatchPendingEventEmailer(), 200);
    }
    
    // ─── start() ─────────────────────────────────────────────────────────────
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT  Id,
            Subject,
            OwnerId,
            What.Name,
            StartDateTime,
            EndDateTime
            FROM    Event
            WHERE   Visit_Status__c = 'Scheduled'
            AND     EndDateTime     < TODAY
            AND     StartDateTime  >= 2026-04-01T00:00:00Z
            AND     WhatId         != NULL
            ORDER BY StartDateTime DESC
        ]);
    }
    
    // ─── execute() ───────────────────────────────────────────────────────────
    public void execute(Database.BatchableContext bc, List<Event> events) {
        for (Event ev : events) {
            if (!ownerEventMap.containsKey(ev.OwnerId)) {
                ownerEventMap.put(ev.OwnerId, new List<Event>());
            }
            ownerEventMap.get(ev.OwnerId).add(ev);
        }
    }
    
    // ─── finish() ────────────────────────────────────────────────────────────
    public void finish(Database.BatchableContext bc) {
        
        if (ownerEventMap.isEmpty()) return;
        
        // ── Step 1: Query User records (with Manager self-join) ───────────────
        Map<Id, User> ownerUserMap = new Map<Id, User>([
            SELECT  Id,
            Name,
            Email,
            ManagerId,
            Manager.Name,
            Manager.Email
            FROM    User
            WHERE   Id IN :ownerEventMap.keySet()
        ]);
        
        // ── Step 2: Fetch Org-Wide Email Address once (outside the loop) ──────
        List<OrgWideEmailAddress> oweList = [
            SELECT Id
            FROM   OrgWideEmailAddress
            WHERE  Address = 'enquiry@rotexautomation.com'
            LIMIT  1
        ];
        Id oweId = oweList.isEmpty() ? null : oweList[0].Id;
        
        // ── Step 3: Build and send one email per owner ────────────────────────
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for (Id ownerId : ownerEventMap.keySet()) {
            
            User owner = ownerUserMap.get(ownerId);
            if (owner == null) continue;
            if (String.isBlank(owner.Email)) continue;
            
            List<Event> ownerEvents = ownerEventMap.get(ownerId);
            
            // ── CC: manager ──────────────────────────────────────────────────
            List<String> ccAddresses = new List<String>();
            if (owner.Manager != null && String.isNotBlank(owner.Manager.Email)) {
                ccAddresses.add(owner.Manager.Email);
            }
            
            // ── Compose email ────────────────────────────────────────────────
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ owner.Email });
            if (!ccAddresses.isEmpty()) {
                mail.setCcAddresses(ccAddresses);
            }
            if (oweId != null) {
                mail.setOrgWideEmailAddressId(oweId);   // From: enquiry@rotexautomation.com
            }
            mail.setReplyTo('bhumi.sheth@rotexautomation.com');
            mail.setBccAddresses(new List<String>{ 'bhumi.sheth@rotexautomation.com' });
            mail.setSubject('Pending Scheduled Events — Action Required (' + owner.Name + ')');
            mail.setHtmlBody(buildHtmlEmail(owner.Name, ownerEvents));
            mail.setSaveAsActivity(false);
            
            emails.add(mail);
        }
        
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }
    
    // ─── Helper: HTML email builder ───────────────────────────────────────────
    private String buildHtmlEmail(String ownerName, List<Event> events) {
        
        Integer pendingCount = events.size();
        
        String html =
            '<!DOCTYPE html>'
            + '<html><head><style>'
            + '  body  { font-family: Arial, sans-serif; font-size: 14px; color: #333; margin: 0; padding: 20px; }'
            + '  h2    { color: #c0392b; margin-bottom: 4px; }'
            + '  p     { margin: 6px 0; }'
            + '  table { border-collapse: collapse; width: 100%; margin-top: 16px; }'
            + '  th    { background: #2c3e50; color: #fff; padding: 10px 12px; text-align: left; font-size: 13px; }'
            + '  td    { padding: 9px 12px; border-bottom: 1px solid #ddd; font-size: 13px; vertical-align: top; }'
            + '  tr:nth-child(even) td { background: #f7f7f7; }'
            + '  tr:hover td           { background: #eaf3fb; }'
            + '  .badge  { display:inline-block; background:#e74c3c; color:#fff; padding:2px 9px; border-radius:12px; font-size:12px; }'
            + '  .footer { margin-top:24px; font-size:12px; color:#999; border-top:1px solid #eee; padding-top:10px; }'
            + '</style></head><body>'
            
            + '<p>Dear <strong>' + ownerName + '</strong>,</p>'
            + '<p>The following <strong>' + pendingCount + ' event(s)</strong> are still marked '
            + '<em>Scheduled</em> even though their end date has already passed. '
            + 'Please review and update each record accordingly.</p>'
            
            + '<table><thead><tr>'
            + '<th>#</th>'
            + '<th>Subject</th>'
            + '<th>Related To</th>'
            + '<th>Start Date / Time</th>'
            + '<th>End Date / Time</th>'
            + '<th>Visit Status</th>'
            + '</tr></thead><tbody>';
        
        Integer rowNum = 1;
        for (Event ev : events) {
            String subj    = String.isNotBlank(ev.Subject) ? ev.Subject : '—';
            String what    = (ev.What != null && String.isNotBlank(ev.What.Name))
                ? ev.What.Name : '—';
            String startDT = ev.StartDateTime != null
                ? ev.StartDateTime.format('dd MMM yyyy, hh:mm a') : '—';
            String endDT   = ev.EndDateTime != null
                ? ev.EndDateTime.format('dd MMM yyyy, hh:mm a') : '—';
            
            html += '<tr>'
                + '<td>' + rowNum++  + '</td>'
                + '<td>' + subj      + '</td>'
                + '<td>' + what      + '</td>'
                + '<td>' + startDT   + '</td>'
                + '<td>' + endDT     + '</td>'
                + '<td><span class="badge">Scheduled</span></td>'
                + '</tr>';
        }
        
        html += '</tbody></table>'
            + '<div class="footer">'
            + 'This is an automated notification. For any queries, reply to '
            + '<a href="mailto:bhumi.sheth@rotexautomation.com">bhumi.sheth@rotexautomation.com</a>.<br/>'
            + 'Generated: ' + System.now().format('dd MMM yyyy, hh:mm a')
            + '</div>'
            + '</body></html>';
        
        return html;
    }
}