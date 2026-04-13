public with sharing class CreateTaskFromTaskController {
    
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

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getRelatedToObjects() {
        try {

            // Get valid WhatId reference fields from Task object
            Set<String> validWhatIdObjects = getValidWhatIdObjects();

            List<Map<String, String>> objectList = new List<Map<String, String>>();
            
            // Get all global describe
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            
            for (String objectName : globalDescribe.keySet()) {
                Schema.SObjectType objectType = globalDescribe.get(objectName);
                Schema.DescribeSObjectResult objectDescribe = objectType.getDescribe();
                
                // Check if object label is in allowed list AND it's a valid WhatId object
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

    private static Set<String> getValidWhatIdObjects() {
        Set<String> validObjects = new Set<String>();
        
        try {
            // Get the WhatId field describe
            Schema.DescribeFieldResult whatIdField = Task.WhatId.getDescribe();
            
            // Get all reference objects for WhatId (polymorphic relationship)
            List<Schema.SObjectType> referenceObjects = whatIdField.getReferenceTo();
            
            for (Schema.SObjectType objType : referenceObjects) {
                validObjects.add(objType.getDescribe().getName());
            }
        } catch (Exception e) {
            System.debug('Error getting valid WhatId objects: ' + e.getMessage());
        }
        
        return validObjects;
    }

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

    @AuraEnabled
    public static Id createTask(Task newTask, Id parentTaskId) {
        try {
            if (newTask == null) {
                throw new AuraHandledException('Task data is required');
            }

            // Set parent task reference
            newTask.Parent_Task_Id__c = parentTaskId;

            // Server-side validation
            validateTask(newTask);

            // Insert the new task
            insert newTask;

            return newTask.Id;
        } catch (DmlException e) {
            throw new AuraHandledException('Error creating task: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException('Error creating task: ' + e.getMessage());
        }
    }

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
}