global class SalesOrderSchedulerJob implements Schedulable {
    global void execute(SchedulableContext sc) {
        System.enqueueJob(new AllScheduler('getSalesOrderMaster'));
    }
}