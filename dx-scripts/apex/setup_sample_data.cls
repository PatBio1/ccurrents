
Id centerRecordTypeID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Center').getRecordTypeId();
Id donorRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Donor').getRecordTypeId();

System.debug('centerRecordTypeID' + centerRecordTypeID);
System.debug('donorRecordTypeId' + donorRecordTypeId);

// Cleanup krufty Entitlements, Cases, Opportunities, Contacts and Accounts
List<Entitlement> ent2Del = [SELECT Id FROM entitlement];
delete ent2Del;

List<Case> cases2Del = [SELECT Id FROM Case];
delete cases2Del;

List<Opportunity> opps2Del = [SELECT Id FROM Opportunity];
delete opps2Del;

List<Contact> contacts2Del = [SELECT Id FROM Contact WHERE IsPersonAccount = false];
delete contacts2Del;

List<Account> accounts2Del = [SELECT Id FROM Account];
delete accounts2Del;

// Create Donors
Account[] donors = new Account[]{
    new Account(
        FirstName = 'Danny',
        LastName = 'Donor',
        RecordTypeID = donorRecordTypeId,
        ExternalID__c = 'donor-12345'
    ),
    new Account(
        FirstName = 'Betty',
        LastName = 'Bond',
        RecordTypeID = donorRecordTypeId,
        ExternalID__c = 'donor-67890'
    )
};

upsert donors ExternalID__c;

// Create Donation Centers
Account[] centers = new Account[]{
    new Account(
        Name = 'Proesis HQ',
        RecordTypeID = centerRecordTypeID,
        ExternalID__c = 'center-111',
        Services__c = 'Medical: Consultation'
    ),
    new Account(
        Name = 'Proesis Miramar',
        RecordTypeID = centerRecordTypeID,
        BillingStreet = '7901 Riviera Blvd',
        BillingCity = 'Miramar',
        BillingState = 'FL',
        BillingPostalCode = '33023',
        BillingCountry = 'US',
        Geolocation__Latitude__s = 25.973030,
        Geolocation__Longitude__s = -80.242049,
        ExternalID__c = 'center-222',
        Services__c = 'Donation;Medical: New Donor;Medical: Annual Physical;Medical: Consultation',
        Site = 'P-01'
    ),
    new Account(
        Name = 'Proesis Dallas',
        RecordTypeID = centerRecordTypeID,
        BillingStreet = '1080 N Westmoreland Rd',
        BillingCity = 'Dallas',
        BillingState = 'TX',
        BillingPostalCode = '75311',
        BillingCountry = 'US',
        Geolocation__Latitude__s = 32.78411048612642,
        Geolocation__Longitude__s = -96.87149106359581,
        ExternalID__c = 'center-333',
        Services__c = 'Donation;Medical: New Donor;Medical: Annual Physical;Medical: Consultation',
        Site = 'P-02'
    )
};

upsert centers ExternalID__c; 

Schedule__c[] schedules = new Schedule__c[]{
    new Schedule__c(
        Center__c = centers[0].Id, 
        Begin_Date__c = Date.today().addDays(-10),
        End_Date__c = Date.today().addDays(30)
    ),
    new Schedule__c(
        Center__c = centers[1].Id,
        Begin_Date__c = Date.today().addDays(-10),
        End_Date__c = Date.today().addDays(30)
    ),
    new Schedule__c(
        Center__c = centers[2].Id,
        Begin_Date__c = Date.today().addDays(-10),
        End_Date__c = Date.today().addDays(30)
    )
};

insert schedules;
