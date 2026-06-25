global class CustomerSchedulerJob implements Schedulable {
    global void execute(SchedulableContext sc) {
        System.enqueueJob(new AllScheduler('getCustomerMaster'));
    }
}