/*
AccountHelper Overview

The `AccountHelper` class is designed to provide helper methods that assist in performing specific operations on Account records. 
This class is intended to modularize the logic used in the `AccountTrigger` to ensure separation of concerns, improve readability, and ease maintenance. 

This class is currently stubbed out. As part of this exercise, you are expected to:
1. Implement the method bodies to carry out the specified operations on Account records.
2. Refactor the `AccountTrigger` to utilize the methods provided in this `AccountHelper` class.

Methods:
- `setTypeProspect(SObject objects)`: 
    - Purpose: Update the 'Type' field of the given Account record to 'Prospect' if it's not already set.
    - Note: You'll likely need to adjust the method signature to accept the necessary parameters.

- `addressCopy()`: 
    - Purpose: Copy the shipping address of the Account to its billing address. 
    - Note: You'll likely need to adjust the method signature to accept the necessary parameters.

- `setRating`: 
    - Purpose: Evaluate certain conditions on the Account and assign a rating based on that evaluation. You'll need to define the method's signature and implement its logic.

- `defaultContact`: 
    - Purpose: Create a default contact related to the Account after the Account is inserted. You'll need to define the method's signature and implement its logic.

Remember:
Always ensure that your helper methods are bulk-safe to handle multiple records efficiently. 
*/
public with sharing class AccountHelper {
  public static void setTypeProspect(Account acc) {
    if (String.isBlank(acc.Type)) {
      acc.Type = 'Prospect';
    }
  }

  public void addressCopy(Account acc) {
    if (
      String.isBlank(acc.ShippingStreet) && !String.isBlank(acc.BillingStreet)
    ) {
      acc.BillingStreet = acc.ShippingStreet;
      acc.BillingCity = acc.ShippingCity;
      acc.BillingState = acc.ShippingState;
      acc.BillingPostalCode = acc.ShippingPostalCode;
      acc.BillingCountry = acc.ShippingCountry;
    }
  }

  public void setRating(List<Account> accountList) {
    for (Account acc : accountList) {
      if (String.isBlank(acc.Rating)) {
        acc.Rating = 'Warm';
      }
    }
  }

  // defaultContact creates a default contact list based on when an account is inserted
  public void defaultContact(List<Account> accountList) {
    Set<Id> accountIds = new Set<Id>();

    for (Account acc : accountList) {
      if (acc.Name == null) {
        accountIds.add(acc.Id);
      }
    }

    // needed to query for the default primary contact
    List<Contact> primaryContactList = [
      SELECT Id, AccountId
      FROM Contact
      WHERE AccountId IN :accountIds
      ORDER BY LastName
      LIMIT 1
    ];

    // map for the account Ids
    Map<Id, Contact> contactMap = new Map<Id, Contact>();
    for (Contact con : primaryContactList) {
      contactMap.put(con.AccountId, con);
    }

    for (Account acc : accountList) {
      if (acc.Name == null && contactMap.containsKey(acc.Id)) {
        acc.Id = contactMap.get(acc.Id).Id;
      }
    }
  }
}
