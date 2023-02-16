
// Cleanup krufty Entitlements, Cases, Opportunities, Contacts and Accounts
// delete [SELECT Id FROM Entitlement];

// delete [SELECT Id FROM Case];

// delete [SELECT Id FROM Opportunity];

// delete [SELECT Id FROM Contact WHERE IsPersonAccount = false];

// delete [SELECT Id FROM Account];

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
                DonorId__c = 'center-111',
                Services__c = 'Medical: Consultation'
        ),
        TestUtil.createMiramarCenter(),
        TestUtil.createDallasCenter()
};

// We removed ExternalId__c, but this works.
upsert centers DonorId__c;

List<Business_Hours__c> businessHours = new List<Business_Hours__c>();
businessHours.addAll(TestUtil.createBusinessHours(centers[1].Id));
businessHours.addAll(TestUtil.createBusinessHours(centers[2].Id));
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

List<Business_Hours__c> proesisMiramarHours = new List<Business_Hours__c>();
Id proesisMirimarId = centers[1].Id;

for (Default_Business_Hours__mdt defaultTime : [SELECT Label, Close__c, Index__c, IsClosed__c, Open__c FROM Default_Business_Hours__mdt]) {
    String todayString = String.valueOf(Datetime.now().date());
    Datetime closingTime = Datetime.valueOf(String.valueOf(todayString + ' ' + defaultTime.Close__c) + ':00');
    Datetime openTime = Datetime.valueOf(String.valueOf(todayString + ' ' + defaultTime.Open__c + ':00'));

    Business_Hours__c newBH = new Business_Hours__c();
    newBH.Name = defaultTime.Label;
    newBH.Center__c = proesisMirimarId;
    newBH.Close__c = Time.newInstance(closingTime.hour(), closingTime.minute(), closingTime.second(), closingTime.millisecond());
    newBH.Index__c = defaultTime.Index__c;
    newBH.isClosed__c = defaultTime.IsClosed__c;
    newBH.Open__c = Time.newInstance(openTime.hour(), openTime.minute(), openTime.second(), openTime.millisecond());

    proesisMiramarHours.add(newBH);
}

insert proesisMiramarHours;

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
