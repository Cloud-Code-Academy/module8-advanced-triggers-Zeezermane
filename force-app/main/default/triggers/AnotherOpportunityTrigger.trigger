/*
AnotherOpportunityTrigger Overview

This trigger was initially created for handling various events on the Opportunity object. It was developed by a prior developer and has since been noted to cause some issues in our org.

IMPORTANT:
- This trigger does not adhere to Salesforce best practices.
- It is essential to review, understand, and refactor this trigger to ensure maintainability, performance, and prevent any inadvertent issues.

ISSUES:
Avoid nested for loop - 1 instance
Avoid DML inside for loop - 1 instance
Bulkify Your Code - 1 instance
Avoid SOQL Query inside for loop - 2 instances
Stop recursion - 1 instance

RESOURCES: 
https://www.salesforceben.com/12-salesforce-apex-best-practices/
https://developer.salesforce.com/blogs/developer-relations/2015/01/apex-best-practices-15-apex-commandments
*/
trigger AnotherOpportunityTrigger on Opportunity (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    if (Trigger.isBefore){
        if (Trigger.isInsert){
            // Set default Type for new Opportunities
          for(Opportunity opp : Trigger.new){ //For loop added to bulkify code 
            if (opp.Type == null){
                opp.Type = 'New Customer';
            } 
        }       
        } else if (Trigger.isDelete){
            // Prevent deletion of closed Opportunities
            for (Opportunity oldOpp : Trigger.old){
                if (oldOpp.IsClosed){
                    oldOpp.addError('Cannot delete closed opportunity');
                }
            }
        }
    }

    if (Trigger.isAfter){
        if (Trigger.isInsert){
            // Create a new Task for newly inserted Opportunities
            List<Task> tasksToInsert = new List<Task>();
            for (Opportunity opp : Trigger.new){
            if (opp.Primary_Contact__c != null){
                Task tsk = new Task();
                tsk.Subject = 'Call Primary Contact';
                tsk.WhatId = opp.Id;
                tsk.WhoId = opp.Primary_Contact__c;
                tsk.OwnerId = opp.OwnerId;
                tsk.ActivityDate = Date.today().addDays(3);
                tasksToInsert.add(tsk);
            }
        }
        if (!tasksToInsert.isEmpty()){
            insert tasksToInsert;
        }
        } else if (Trigger.isUpdate){
            // Append Stage changes in Opportunity Description
            List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
            for (Integer i = 0; i< Trigger.new.size(); i++){ // trigger.new needs to be removed 
                Opportunity oldOpp = Trigger.old[i];
                 Opportunity newOpp = Trigger.new[i];

                 if(newOpp.StageName != oldOpp.StageName && newOpp.StageName != null){
                    newOpp.Description += '\n Stage Change: ' + newOpp.StageName + ' : ' + DateTime.now().format();
                    OpportunitiesToUpdate.add(newOpp);
                 }
            } 
             if (!opportunitiesToUpdate.isEmpty()){
                update opportunitiesToUpdate;
            }
        }
        // Send email notifications when an Opportunity is deleted 
        if (Trigger.isDelete){
            notifyOwnersOpportunityDeleted(Trigger.old);
        } 
        // Assign the primary contact to undeleted Opportunities
        if (Trigger.isUndelete){
            assignPrimaryContact(Trigger.newMap);
        }
    }

    /*
    notifyOwnersOpportunityDeleted:
    - Sends an email notification to the owner of the Opportunity when it gets deleted.
    - Uses Salesforce's Messaging.SingleEmailMessage to send the email.
    */
    private static void notifyOwnersOpportunityDeleted(List<Opportunity> opps) {
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        Set<Id> ownerIds = new Set<Id>();

        //query through the emails of OwnerIds
        for (Opportunity opp : opps){
            ownerIds.add(opp.OwnerId);
        }

        Map<Id, User> ownerEmailMap = new Map<Id,User>([SELECT Id, Email FROM User WHERE Id IN :ownerIds]);

        for (Opportunity opp : opps){
        if (ownerEmailMap.containsKey(opp.OwnerId)){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { ownerEmailMap.get(opp.OwnerId).Email });
            mail.setSubject('Opportunity Deleted : ' + opp.Name);
            mail.setPlainTextBody('Your Opportunity: ' + opp.Name +' has been deleted.');
            mails.add(mail);
        }
    }        
    if(!mails.isEmpty()){
        try {
            Messaging.sendEmail(mails);
        } catch (Exception e){
            System.debug('Exception: ' + e.getMessage());
        }
    }
}

    /*
    assignPrimaryContact:
    - Assigns a primary contact with the title of 'VP Sales' to undeleted Opportunities.
    - Only updates the Opportunities that don't already have a primary contact.
    */
    private static void assignPrimaryContact(Map<Id,Opportunity> oppNewMap) {        
        Set<Id> accountIds = new Set<Id>();

        for (Opportunity opp : oppNewMap.values()){            
            if (opp.Primary_Contact__c == null && opp.AccountId != null) {
                accountIds.add(opp.AccountId);
            }
        }
        Map<Id, Contact> primaryContacts = new Map<Id,Contact> (
            [SELECT Id, AccountId FROM Contact WHERE Title = 'VP Sales' AND AccountId IN :accountIds]
        );
        
        List<Opportunity> oppsToUpdate = new List <Opportunity>();
        for (Opportunity opp : oppNewMap.values()) {
            if (primaryContacts.containsKey(opp.AccountId) && opp.Primary_Contact__c == null) {
                Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
                oppToUpdate.Primary_Contact__c = primaryContacts.get(opp.AccountId).Id;
                oppsToUpdate.add(oppToUpdate);
            }
        }
        if (oppsToUpdate.size() > 0) {
            update oppsToUpdate;
        }
    }
}