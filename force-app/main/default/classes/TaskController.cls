public with sharing class TaskController {
    
    /**
     * Retrieves task details by ID.
     */
    @AuraEnabled(cacheable=false)
    public static Task getTaskDetails(Id taskId) {
        try {
            if (taskId == null) {
                throw new AuraHandledException('Task ID is required');
            }

            Task task = [
                SELECT Id, Subject, Priority, OwnerId, WhoId, WhatId, Status, Description
                FROM Task
                WHERE Id = :taskId
                LIMIT 1
            ];

            return task;
        } catch (QueryException e) {
            throw new AuraHandledException('Task not found: ' + e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving task: ' + e.getMessage());
        }
    }

    /**
     * Retrieves a list of objects that can set to Related To (WhatId) field on Task.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getRelatedToObjects() {
        try {

            Set<String> validWhatIdObjects = getValidWhatIdObjects();

            List<Map<String, String>> objectList = new List<Map<String, String>>();
            
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            
            for (String objectName : globalDescribe.keySet()) {
                Schema.SObjectType objectType = globalDescribe.get(objectName);
                Schema.DescribeSObjectResult objectDescribe = objectType.getDescribe();
                
                if (validWhatIdObjects.contains(objectDescribe.getName())) {
                    Map<String, String> objectInfo = new Map<String, String>();
                    objectInfo.put('label', objectDescribe.getLabel());
                    objectInfo.put('apiName', objectDescribe.getName());
                    objectList.add(objectInfo);
                }
            }
            
            return objectList;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving objects: ' + e.getMessage());
        }
    }

    /**
     * Retrieves a list of valid objects that can be set to Related To (WhatId) field on Task.
     */
    private static Set<String> getValidWhatIdObjects() {
        Set<String> validObjects = new Set<String>();
        
        try {

            Schema.DescribeFieldResult whatIdField = Task.WhatId.getDescribe();
            
            List<Schema.SObjectType> referenceObjects = whatIdField.getReferenceTo();
            
            for (Schema.SObjectType objType : referenceObjects) {
                validObjects.add(objType.getDescribe().getName());
            }
        } catch (Exception e) {
            System.debug('Error getting valid WhatId objects: ' + e.getMessage());
        }
        
        return validObjects;
    }

    /**
     * Retrieves the label and API name of an object from its Id.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getObjectInfoFromId(Id recordId) {
        try {
            if (recordId == null) {
                return null;
            }
            
            String objectApiName = recordId.getSObjectType().getDescribe().getName();
            String objectLabel = recordId.getSObjectType().getDescribe().getLabel();
            
            Map<String, String> objectInfo = new Map<String, String>();
            objectInfo.put('apiName', objectApiName);
            objectInfo.put('label', objectLabel);
            
            return objectInfo;
        } catch (Exception e) {
            throw new AuraHandledException('Error getting object info: ' + e.getMessage());
        }
    }

    /**
     * Creates a new Task record.
     */
    @AuraEnabled
    public static Id createTask(Task newTask, Id parentTaskId) {
        try {
            if (newTask == null) {
                throw new AuraHandledException('Task data is required');
            }

            newTask.Parent_Task_Id__c = parentTaskId;

            validateTask(newTask);

            insert newTask;

            return newTask.Id;
        } catch (DmlException e) {
            throw new AuraHandledException('Error creating task: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException('Error creating task: ' + e.getMessage());
        }
    }

    /**
     * Validates the Task fields before creation.
     */
    private static void validateTask(Task task) {
        if (String.isBlank(task.Subject)) {
            throw new AuraHandledException('Subject is required');
        }

        if (String.isBlank(task.Priority)) {
            throw new AuraHandledException('Priority is required');
        }

        if (String.isBlank(task.Status)) {
            throw new AuraHandledException('Status is required');
        }

        if (task.ActivityDate != null && task.ActivityDate < Date.today()) {
            throw new AuraHandledException('Due Date must be today or in the future');
        }
    }

    /**
     * Retrieves the task hierarchy from the given task ID.
     */
    @AuraEnabled(cacheable=true)
    public static List<TaskWrapper> getTaskHierarchy(Id taskId) {
        try {
            if (taskId == null) {
                throw new AuraHandledException('Task ID is required');
            }

            Task rootTask = [
                SELECT Id, Subject, Status, Priority, ActivityDate, Parent_Task_Id__c, Owner.Name
                FROM Task
                WHERE Id = :taskId
                LIMIT 1
            ];

            List<TaskWrapper> hierarchy = new List<TaskWrapper>();
            TaskWrapper rootWrapper = new TaskWrapper();
            rootWrapper.Id = rootTask.Id;
            rootWrapper.Subject = rootTask.Subject;
            rootWrapper.Status = rootTask.Status;
            rootWrapper.Priority = rootTask.Priority;
            rootWrapper.ActivityDate = rootTask.ActivityDate;
            rootWrapper.OwnerName = rootTask.Owner.Name;
            rootWrapper.children = getChildTasks(rootTask.Id);
            
            hierarchy.add(rootWrapper);
            
            return hierarchy;
            
        } catch (QueryException e) {
            throw new AuraHandledException('Task not found: ' + e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving task hierarchy: ' + e.getMessage());
        }
    }

    /**
     * Recursively retrieves child tasks for a given parent task ID.
     */
    private static List<TaskWrapper> getChildTasks(Id parentTaskId) {
        List<TaskWrapper> childWrappers = new List<TaskWrapper>();
        
        List<Task> childTasks = [
            SELECT Id, Subject, Status, Priority, ActivityDate, Parent_Task_Id__c, Owner.Name
            FROM Task
            WHERE Parent_Task_Id__c = :parentTaskId
            ORDER BY CreatedDate ASC
        ];

        for (Task childTask : childTasks) {
            TaskWrapper wrapper = new TaskWrapper();
            wrapper.Id = childTask.Id;
            wrapper.Subject = childTask.Subject;
            wrapper.Status = childTask.Status;
            wrapper.Priority = childTask.Priority;
            wrapper.ActivityDate = childTask.ActivityDate;
            wrapper.OwnerName = childTask.Owner.Name;
            
            wrapper.children = getChildTasks(childTask.Id);
            
            childWrappers.add(wrapper);
        }

        return childWrappers;
    }
    
    public class TaskWrapper {
        @AuraEnabled public String Id { get; set; }
        @AuraEnabled public String Subject { get; set; }
        @AuraEnabled public String Status { get; set; }
        @AuraEnabled public String Priority { get; set; }
        @AuraEnabled public Date ActivityDate { get; set; }
        @AuraEnabled public String OwnerName { get; set; }
        @AuraEnabled public List<TaskWrapper> children { get; set; }

        public TaskWrapper() {
            this.children = new List<TaskWrapper>();
        }
    }
}