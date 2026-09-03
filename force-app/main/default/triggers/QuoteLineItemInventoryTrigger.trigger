/**
 * Historical hook for Quote Reserved on QLI insert.
 * Reserved stock is now created from Pick_List_Line_Item__c insert
 * (PicklistLineItemInventoryTrigger → InventoryTransactionQuoteHandler).
 *
 * Body intentionally has no executable Apex so deploy does not require
 * QuoteLineItem insert (org approval automation hits uncatchable SOQL 101).
 * Handler remains available for direct invocation if re-enabled later.
 */
trigger QuoteLineItemInventoryTrigger on QuoteLineItem (after insert) {
}