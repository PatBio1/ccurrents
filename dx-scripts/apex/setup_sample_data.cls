
// Cleanup krufty Entitlements, Cases, Opportunities, Contacts and Accounts
// delete [SELECT Id FROM Entitlement];

// delete [SELECT Id FROM Case];

// delete [SELECT Id FROM Opportunity];

// delete [SELECT Id FROM Contact WHERE IsPersonAccount = false];

//delete [SELECT Id FROM Account];

// Create Donors
Account[] donors = new Account[]{
    new Account(
        FirstName = 'Danny',
        LastName = 'Donor',
        RecordTypeID = Constants.DONOR_RECORD_TYPE_ID,
        DonorId__c = 'donor-12345'
    ),
    new Account(
        FirstName = 'Betty',
        LastName = 'Bond',
        RecordTypeID = Constants.DONOR_RECORD_TYPE_ID,
        DonorId__c = 'donor-67890'
    )
};

upsert donors DonorId__c;

// Create Donation Centers
Account[] centers = new Account[]{
    new Account(
        Name = 'Proesis HQ',
        RecordTypeID = Constants.CENTER_RECORD_TYPE_ID,
        // We removed ExternalId__c, but this works.
        CenterId__c = 'center-111',
        Services__c = 'Medical: Consultation',
        Site = 'P-00'
    ),
    new Account(
        Name = 'Proesis Miramar',
        RecordTypeId = Constants.CENTER_RECORD_TYPE_ID,
        BillingStreet = '7901 Riviera Blvd',
        BillingCity = 'Miramar',
        BillingState = 'FL',
        BillingPostalCode = '33023',
        BillingCountry = 'US',
        Geolocation__Latitude__s = 25.973030,
        Geolocation__Longitude__s = -80.242049,
        CenterId__c = 'center-222',
        Services__c = 'Donation;Medical: New Donor;Medical: Annual Physical;Medical: Consultation',
        Site = 'P-01'
    ),
    new Account(
        Name = 'Proesis Dallas',
        RecordTypeId = Constants.CENTER_RECORD_TYPE_ID,
        BillingStreet = '1080 N Westmoreland Rd',
        BillingCity = 'Dallas',
        BillingState = 'TX',
        BillingPostalCode = '75311',
        BillingCountry = 'US',
        Geolocation__Latitude__s = 32.78411048612642,
        Geolocation__Longitude__s = -96.87149106359581,
        CenterId__c = 'center-333',
        Services__c = 'Donation;Medical: New Donor;Medical: Annual Physical;Medical: Consultation',
        Site = 'P-02'
    )
};

// We removed ExternalId__c, but this works. 
// We needed discrete external IDs for the centers which was the original data model
upsert centers CenterId__c;

List<Business_Hours__c> businessHours = new List<Business_Hours__c>();

for (Id centerId : new List<Id>{centers[1].Id, centers[2].Id}) {
    for (Default_Business_Hours__mdt defaultTime : [SELECT Label, Close__c, Index__c, IsClosed__c, Open__c FROM Default_Business_Hours__mdt]) {
        String todayString = String.valueOf(Datetime.now().date());
        Datetime closingTime = Datetime.valueOf(String.valueOf(todayString + ' ' + defaultTime.Close__c) + ':00');
        Datetime openTime = Datetime.valueOf(String.valueOf(todayString + ' ' + defaultTime.Open__c + ':00'));

        Business_Hours__c newBH = new Business_Hours__c();
        newBH.Name = defaultTime.Label;
        newBH.Center__c = centerId;
        newBH.Close__c = Time.newInstance(closingTime.hour(), closingTime.minute(), closingTime.second(), closingTime.millisecond());
        newBH.Index__c = defaultTime.Index__c;
        newBH.isClosed__c = defaultTime.IsClosed__c;
        newBH.Open__c = Time.newInstance(openTime.hour(), openTime.minute(), openTime.second(), openTime.millisecond());

        businessHours.add(newBH);
    }
}

insert businessHours;

Donation_Type__c donationType = new Donation_Type__c(
        Name = 'Normal Source Plasma'
);
insert donationType;

Center_Donation_Type__c[] centerDonationTypes = new Center_Donation_Type__c[]{
    new Center_Donation_Type__c(
        Center__c = centers[1].Id,
        Donation_Type__c = donationType.Id,
        isActive__c = true
    ),
    new Center_Donation_Type__c(
        Center__c = centers[2].Id,
        Donation_Type__c = donationType.Id,
        isActive__c = true
    )
};
insert centerDonationTypes;

// Create Levels for payment calculations
// Has self reverential field to link the next level so have to make this verbose
Level__c levelRoyal = new Level__c (
    Name = 'Royal',
    Donation_Payment__c = 50.00,
    Donation_Points__c = 200,
    Donation_Threshold__c = 90,
    Donation_Type__c = donationType.Id,
    Schedule_Rights__c = '2',
    Threshold_Payment__c = 200.00,
    Threshold_Points__c = 0
);
upsert levelRoyal Name;

Level__c levelVIP = new Level__c (
    Name = 'VIP',
    Donation_Payment__c = 50.00,
    Donation_Points__c = 160,
    Donation_Threshold__c = 60,
    Donation_Type__c = donationType.Id,
    Schedule_Rights__c = '1',
    Threshold_Payment__c = 100.00,
    Threshold_Points__c = 0,
    Next_Level__c = levelRoyal.Id
);
upsert levelVIP Name;

Level__c levelSignature = new Level__c (
    Name = 'Signature',
    Donation_Payment__c = 50.00,
    Donation_Points__c = 100,
    Donation_Threshold__c = 30,
    Donation_Type__c = donationType.Id,
    Schedule_Rights__c = '1',
    Threshold_Payment__c = 50.00,
    Threshold_Points__c = 0,
    Next_Level__c = levelVIP.Id
);
upsert levelSignature Name;

Level__c levelNormal15 = new Level__c (
    Name = 'Normal Donor +15',
    Donation_Payment__c = 50.00,
    Donation_Points__c = 0,
    Donation_Threshold__c = 14,
    Donation_Type__c = donationType.Id,
    Schedule_Rights__c = '0',
    Threshold_Payment__c = 15.00,
    Threshold_Points__c = 0,
    Next_Level__c = levelSignature.Id
);
upsert levelNormal15 Name;

Level__c levelNormal = new Level__c (
    Name = 'Donor (Default)',
    Donation_Payment__c = 50.00,
    Donation_Points__c = 0,
    Donation_Threshold__c = 0,
    Donation_Type__c = donationType.Id,
    Schedule_Rights__c = '0',
    Threshold_Payment__c = 0,
    Threshold_Points__c = 0,
    Next_Level__c = levelNormal15.Id
);
upsert levelNormal Name;