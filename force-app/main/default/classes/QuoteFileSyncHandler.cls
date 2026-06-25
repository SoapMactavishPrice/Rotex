public class QuoteFileSyncHandler {

    public static void copyOpportunityFilesToQuote(List<Quote> newQuotes) {

        try {

            Map<Id, Id> oppToQuoteMap = new Map<Id, Id>();

            for (Quote q : newQuotes) {

                if (q.OpportunityId != null) {
                    oppToQuoteMap.put(q.OpportunityId, q.Id);
                }
            }

            if (oppToQuoteMap.isEmpty()) {
                System.debug('No Opportunity found for Quotes.');
                return;
            }

            System.debug('oppToQuoteMap : ' + oppToQuoteMap);

            List<ContentDocumentLink> oppLinks = [
                SELECT ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :oppToQuoteMap.keySet()
            ];

            System.debug('Opportunity Files Found : ' + oppLinks.size());

            if (oppLinks.isEmpty()) {
                return;
            }

            Set<Id> quoteIds = new Set<Id>();
            quoteIds.addAll(oppToQuoteMap.values());

            Set<String> existingLinks = new Set<String>();

            for (ContentDocumentLink existingCdl :
                 [SELECT ContentDocumentId, LinkedEntityId
                  FROM ContentDocumentLink
                  WHERE LinkedEntityId IN :quoteIds]) {

                existingLinks.add(
                    String.valueOf(existingCdl.LinkedEntityId) +
                    '-' +
                    String.valueOf(existingCdl.ContentDocumentId)
                );
            }

            System.debug('Existing Quote File Links : ' + existingLinks.size());

            List<ContentDocumentLink> quoteLinks =
                new List<ContentDocumentLink>();

            for (ContentDocumentLink cdl : oppLinks) {

                Id quoteId = oppToQuoteMap.get(cdl.LinkedEntityId);

                if (quoteId == null) {
                    continue;
                }

                String uniqueKey =
                    String.valueOf(quoteId) +
                    '-' +
                    String.valueOf(cdl.ContentDocumentId);

                if (!existingLinks.contains(uniqueKey)) {

                    quoteLinks.add(
                        new ContentDocumentLink(
                            ContentDocumentId = cdl.ContentDocumentId,
                            LinkedEntityId    = quoteId,
                            ShareType         = 'V',
                            Visibility        = 'AllUsers'
                        )
                    );
                }
            }

            System.debug('New File Links To Insert : ' + quoteLinks.size());

            if (!quoteLinks.isEmpty()) {

                Database.SaveResult[] results =
                    Database.insert(quoteLinks, false);

                for (Integer i = 0; i < results.size(); i++) {

                    if (!results[i].isSuccess()) {

                        for (Database.Error err :
                             results[i].getErrors()) {

                            System.debug(
                                'File Sync Error : ' +
                                err.getMessage()
                            );
                        }
                    }
                }
            }

        } catch (Exception ex) {

            System.debug(
                'QuoteFileSyncHandler Exception : ' +
                ex.getMessage()
            );
            System.debug(
                'Line Number : ' +
                ex.getLineNumber()
            );
        }
    }
}