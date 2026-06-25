trigger OrderItemTrigger on OrderItem (After insert) {
OrderItemTriggerHandler.updatequantityontarget(Trigger.new);
}