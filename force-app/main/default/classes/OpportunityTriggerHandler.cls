public class OpportunityTriggerHandler extends TriggerHandler {
  public override void beforeInsert() {
    // Set default Type for new Opportunities
    for (Opportunity opp : (List<Opportunity>) Trigger.new) {
      if (opp.Type == null) {
        opp.Type = 'New Customer';
      }
    }
  }

  public override void beforeUpdate() {
    // Validate that the amount is greater than 5000
    for (Opportunity opp : (List<Opportunity>) Trigger.new) {
      if (opp.Amount < 5000) {
        opp.addError('Opportunity amount must be greater than 5000');
      }
    }

    // Set the primary contact to the CEO if the field is empty
    Set<Id> accountIds = new Set<Id>();
    for (Opportunity opp : (List<Opportunity>) Trigger.new) {
      if (opp.AccountId != null) {
        accountIds.add(opp.AccountId);
      }
    }

    if (!accountIds.isEmpty()) {
      Map<Id, Contact> ceoContacts = new Map<Id, Contact>(
        [
          SELECT Id, AccountId
          FROM Contact
          WHERE AccountId IN :accountIds AND Title = 'CEO'
        ]
      );

      for (Opportunity opp : (List<Opportunity>) Trigger.new) {
        if (
          opp.Primary_Contact__c == null &&
          ceoContacts.containsKey(opp.AccountId)
        ) {
          opp.Primary_Contact__c = ceoContacts.get(opp.AccountId).Id;
        }
      }
    }
  }

  public override void afterInsert() {
    // Create a new Task for newly inserted Opportunities with a Primary Contact
    List<Task> tasksToInsert = new List<Task>();
    for (Opportunity opp : (List<Opportunity>) Trigger.new) {
      if (opp.Primary_Contact__c != null) {
        Task tsk = new Task(
          Subject = 'Call Primary Contact',
          WhatId = opp.Id,
          WhoId = opp.Primary_Contact__c,
          OwnerId = opp.OwnerId,
          ActivityDate = Date.today().addDays(3)
        );
        tasksToInsert.add(tsk);
      }
    }
    if (!tasksToInsert.isEmpty()) {
      insert tasksToInsert;
    }
  }

  public override void afterUpdate() {
    // Append Stage changes to the Opportunity Description
    List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
    for (Integer i = 0; i < Trigger.new.size(); i++) {
      Opportunity newOpp = (Opportunity) Trigger.new[i];
      Opportunity oldOpp = (Opportunity) Trigger.old[i];
      if (newOpp.StageName != oldOpp.StageName && newOpp.StageName != null) {
        newOpp.Description +=
          '\n Stage Change: ' +
          newOpp.StageName +
          ' : ' +
          DateTime.now().format();
        opportunitiesToUpdate.add(newOpp);
      }
    }
    if (!opportunitiesToUpdate.isEmpty()) {
      update opportunitiesToUpdate;
    }
  }

  public override void beforeDelete() {
    // Prevent deletion of closed opportunities and check for specific conditions (e.g., closed won, Banking industry)
    Map<Id, Account> accounts = new Map<Id, Account>(
      [
        SELECT Id, Industry
        FROM Account
        WHERE Id IN (SELECT AccountId FROM Opportunity WHERE Id IN :Trigger.old)
      ]
    );

    for (Opportunity opp : (List<Opportunity>) Trigger.old) {
      if (opp.IsClosed) {
        opp.addError('Cannot delete closed opportunity');
      }
      if (
        opp.StageName == 'Closed Won' && accounts.containsKey(opp.AccountId)
      ) {
        if (accounts.get(opp.AccountId).Industry == 'Banking') {
          opp.addError(
            'Cannot delete a closed won opportunity for a banking account'
          );
        }
      }
    }
  }

  public override void afterDelete() {
    // Notify owners that an Opportunity was deleted
    notifyOwnersOpportunityDeleted((List<Opportunity>) Trigger.old);
  }

  public override void afterUndelete() {
    // Assign the Primary Contact to undeleted Opportunities
    assignPrimaryContact((Map<Id, Opportunity>) Trigger.newMap);
  }

  // Helper method to send email notifications when an Opportunity is deleted
  private void notifyOwnersOpportunityDeleted(List<Opportunity> opps) {
    Set<Id> ownerIds = new Set<Id>();
    for (Opportunity opp : opps) {
      ownerIds.add(opp.OwnerId);
    }

    Map<Id, User> ownerEmailMap = new Map<Id, User>(
      [SELECT Id, Email FROM User WHERE Id IN :ownerIds]
    );

    List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
    for (Opportunity opp : opps) {
      if (ownerEmailMap.containsKey(opp.OwnerId)) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(
          new List<String>{ ownerEmailMap.get(opp.OwnerId).Email }
        );
        mail.setSubject('Opportunity Deleted: ' + opp.Name);
        mail.setPlainTextBody(
          'Your Opportunity: ' + opp.Name + ' has been deleted.'
        );
        mails.add(mail);
      }
    }

    if (!mails.isEmpty()) {
      Messaging.sendEmail(mails);
    }
  }

  // Helper method to assign the Primary Contact to undeleted Opportunities
  private void assignPrimaryContact(Map<Id, Opportunity> oppNewMap) {
    Set<Id> accountIds = new Set<Id>();
    for (Opportunity opp : oppNewMap.values()) {
      if (opp.Primary_Contact__c == null && opp.AccountId != null) {
        accountIds.add(opp.AccountId);
      }
    }

    Map<Id, Contact> primaryContacts = new Map<Id, Contact>(
      [
        SELECT Id, AccountId
        FROM Contact
        WHERE Title = 'VP Sales' AND AccountId IN :accountIds
      ]
    );

    List<Opportunity> oppsToUpdate = new List<Opportunity>();
    for (Opportunity opp : oppNewMap.values()) {
      if (
        primaryContacts.containsKey(opp.AccountId) &&
        opp.Primary_Contact__c == null
      ) {
        opp.Primary_Contact__c = primaryContacts.get(opp.AccountId).Id;
        oppsToUpdate.add(opp);
      }
    }

    if (!oppsToUpdate.isEmpty()) {
      update oppsToUpdate;
    }
  }
}
