public class ZPR0PricingQueueable implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext qc) {

        ZPR0PricingAPI.ZPR0Pricing();

    }

}