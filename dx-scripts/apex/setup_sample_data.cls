
Id centerRecordTypeID =  Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Center').getRecordTypeId();
Id donorRecordTypeId =  Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Donor').getRecordTypeId();

system.debug('centerRecordTypeID' + centerRecordTypeID);
system.debug('donorRecordTypeId' + donorRecordTypeId);

// Cleanup krufty Entitlements, Cases, Opportunities, Contacts and Accounts
List<Entitlement> ent2Del = [select id, Name from entitlement];
delete ent2Del;

List<Case> cases2Del = [select Id from Case];
delete cases2Del;

List<Opportunity> opps2Del = [select Id from Opportunity];
delete opps2Del;

List<Contact> contacts2Del = [select Id from Contact where isPersonAccount=false];
delete contacts2Del;

List<Account> accounts2Del = [select Id from Account];
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
        LastName = 'Bleeder',
        RecordTypeID = donorRecordTypeId,
        ExternalID__c = 'donor-67890'
    )
};

upsert donors ExternalID__c;

//Create Donation Centers
Account[] centers = new Account[]{
    new Account(
        Name = 'Center 1',
        RecordTypeID = centerRecordTypeID,
        ShippingStreet = '111 1st St',
        ExternalID__c = 'center-111',
        Services__c = 'Donation;Medical: New Donor;Medical: Annual Physical;Medical: Consultation'
    ),
    new Account(
        Name = 'Center 2',
        RecordTypeID = centerRecordTypeID,
        ShippingStreet = '222 @nd St',
        ExternalID__c = 'center-222',
        Services__c = 'Donation;Medical: New Donor;Medical: Annual Physical;Medical: Consultation'
    ),
    new Account(
        Name = 'Center 3',
        RecordTypeID = centerRecordTypeID,
        ShippingStreet = '333 3rd St',
        ExternalID__c = 'center-333',
        Services__c = 'Donation;Medical: New Donor;Medical: Annual Physical;Medical: Consultation'
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
