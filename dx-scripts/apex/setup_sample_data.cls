
// Cleanup krufty Entitlements, Cases, Opportunities, Contacts, Accounts, and Visit__c

// delete [SELECT Id FROM Case];

// delete [SELECT Id FROM Opportunity];

// delete [SELECT Id FROM Contact WHERE IsPersonAccount = false];

//delete [SELECT Id FROM Account];

// delete [SELECT Id FROM Appointment__c];

// delete [SELECT Id FROM Visit__c];

// Create Donors
Account[] donors = new Account[]{
        new Account(
            FirstName = 'Danny',
            LastName = 'Donor',
            RecordTypeID = Constants.DONOR_RECORD_TYPE_ID,
            DonorId__c = 'donor-12345',
            First_Visit_Code__c = ScheduleUtils.createFirstVisitCode()
        ),
        new Account(
            FirstName = 'Betty',
            LastName = 'Bond',
            RecordTypeID = Constants.DONOR_RECORD_TYPE_ID,
            DonorId__c = 'donor-67890',
            First_Visit_Code__c = ScheduleUtils.createFirstVisitCode()    
        )
    };
    
    upsert donors DonorId__c;
    
    // Create Donation Centers
    Account[] centers = new Account[]{
        new Account(
            Name = 'Proesis New Center',
            RecordTypeID = Constants.CENTER_RECORD_TYPE_ID,
            CenterId__c = 'center-333',
            Services__c = 'Medical: Consultation',
            Site = 'P-03',
            isActive__c = false,
            Geolocation__Latitude__s = 32.758610,
            Geolocation__Longitude__s = -96.873890
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
            CenterId__c = 'center-111',
            Services__c = 'Donation;Medical: New Donor;Medical: Annual Physical;Medical: Consultation',
            Site = 'P-01',
            isActive__c = true
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
            CenterId__c = 'center-222',
            Services__c = 'Donation;Medical: New Donor;Medical: Annual Physical;Medical: Consultation',
            Site = 'P-02',
            isActive__c = true
        )
    };
    
    // We removed ExternalId__c, but this works. 
    // We needed discrete external IDs for the centers which was the original data model
    upsert centers CenterId__c;
    
    List<Business_Hours__c> businessHours = new List<Business_Hours__c>();
    
    for (Id centerId : new List<Id>{
            centers[1].Id, centers[2].Id
    }) {
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
    
    // create BECS devices
    Device__c[] devices = new Device__c[]{
        new Device__c(
            Type__c = 'BECS',
            Device_Id__c = 'br549',
            Center__c = centers[0].Id
        ),
        new Device__c(
            Type__c = 'BECS',
            Device_Id__c = '9876543210',
            Center__c = centers[1].Id
        ),
        new Device__c(
            Type__c = 'BECS',
            Device_Id__c = '1234567890',
            Center__c = centers[2].Id
        )
    };

    insert devices;
    
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
    
    Rate__c[] centerRates = new Rate__c[]{
        new Rate__c(
            Description__c = 'Base',
            Center__c = centers[0].Id,
            Donation_Type__c = donationType.Id,
            Base_Payment__c = 100.00, 
            UOM__c = 'visit',
            Type__c = 'Base'
        ),
        new Rate__c(
            Description__c = 'Base',
            Center__c = centers[1].Id,
            Donation_Type__c = donationType.Id,
            Base_Payment__c = 50.00, 
            UOM__c = 'visit',
            Type__c = 'Base'
        ),
        new Rate__c(
            Description__c = 'Base',
            Center__c = centers[2].Id,
            Donation_Type__c = donationType.Id,
            Base_Payment__c = 45.00, 
            UOM__c = 'visit',
            Type__c = 'Base'
        ),
        new Rate__c(
            Description__c = 'Inconvenience',
            Center__c = centers[2].Id,
            Donation_Type__c = donationType.Id,
            Base_Payment__c = 5.00, 
            UOM__c = 'visit',
            Type__c = 'Exception'
        ),
        new Rate__c(
            Description__c = 'Inadvertent deferral',
            Center__c = centers[2].Id,
            Donation_Type__c = donationType.Id,
            Base_Payment__c = 15.00, 
            UOM__c = 'visit',
            Type__c = 'Exception'
        ),
        new Rate__c(
            Description__c = 'Blood loss deferral',
            Center__c = centers[2].Id,
            Donation_Type__c = donationType.Id,
            Base_Payment__c = 25.00, 
            UOM__c = 'visit',
            Type__c = 'Exception'
        )
    };
    insert centerRates;
    
    // Create Levels for payment calculations
    // Has self reverential field to link the next level so have to make this verbose
    Level__c levelRoyal = new Level__c (
            Name = 'Royal',
            Donation_Payment__c = 5.00,
            Donation_Points__c = 200,
            Donation_Threshold__c = 90,
            Donation_Type__c = donationType.Id,
            Schedule_Rights__c = '2',
            Threshold_Payment__c = 200.00,
            Threshold_Points__c = 0,
            isVisible__c = true,
            isActive__c = true
    );
    upsert levelRoyal Name;
    
    Level__c levelVIP = new Level__c (
            Name = 'VIP',
            Donation_Payment__c = 0.00,
            Donation_Points__c = 160,
            Donation_Threshold__c = 60,
            Donation_Type__c = donationType.Id,
            Schedule_Rights__c = '1',
            Threshold_Payment__c = 100.00,
            Threshold_Points__c = 0,
            Next_Level__c = levelRoyal.Id,
            isVisible__c = true,
            isActive__c = true
    );
    upsert levelVIP Name;
    
    Level__c levelSignature = new Level__c (
            Name = 'Signature',
            Donation_Payment__c = 0.00,
            Donation_Points__c = 100,
            Donation_Threshold__c = 30,
            Donation_Type__c = donationType.Id,
            Schedule_Rights__c = '1',
            Threshold_Payment__c = 50.00,
            Threshold_Points__c = 0,
            Next_Level__c = levelVIP.Id,
            isVisible__c = true,
            isActive__c = true
    );
    upsert levelSignature Name;
    
    Level__c levelNormal15 = new Level__c (
            Name = 'Normal Donor +15',
            Donation_Payment__c = 0.00,
            Donation_Points__c = 0,
            Donation_Threshold__c = 14,
            Donation_Type__c = donationType.Id,
            Schedule_Rights__c = '0',
            Threshold_Payment__c = 15.00,
            Threshold_Points__c = 0,
            isVisible__c = false,
            isActive__c = true
    );
    upsert levelNormal15 Name;
    
    Level__c levelNormal = new Level__c (
            Name = 'Donor (Default)',
            Donation_Payment__c = -5.00,
            Donation_Points__c = 0,
            Donation_Threshold__c = 0,
            Donation_Type__c = donationType.Id,
            Schedule_Rights__c = '0',
            Threshold_Payment__c = 0,
            Threshold_Points__c = 0,
            Next_Level__c = levelSignature.Id,
            isVisible__c = true,
            isActive__c = true
    );
    upsert levelNormal Name;
    
    // Update Donors Loyalty Level
    Level__c[] loyaltylevels = [select Id from Level__c where Donation_Type__c = :donationType.Id and isActive__c=true and isVisible__c=true];
    System.debug('loyaltylevels: ' + loyaltylevels.size());
    
    
    donors[0].Loyalty_Level__pc = loyaltylevels[0].Id;
    donors[1].Loyalty_Level__pc = loyaltylevels[1].Id;
    
    update donors;
    
    List<Campaign> testCampaigns = new List<Campaign>{
            new Campaign(
                    Name = 'Miramar Center Updates',
                    IsActive = true,
                    Type = 'Email',
                    Status = 'In Progress',
                    StartDate = Date.newInstance(2023, 05, 01),
                    Description = 'Proesis Miramar center updates.'
            ),
            new Campaign(
                    Name = 'Dallas Center Updates',
                    IsActive = true,
                    Type = 'Email',
                    Status = 'In Progress',
                    StartDate = Date.newInstance(2023, 05, 01),
                    Description = 'Proesis Dallas center updates.'
            )
    };
    
    upsert testCampaigns Name;
    
    List<CampaignMemberStatus> cmsUpdates = new List<CampaignMemberStatus>();
    for (CampaignMemberStatus cms : [SELECT Id, Label, HasResponded, IsDefault FROM CampaignMemberStatus WHERE CampaignId IN :testCampaigns]) {
        CampaignMemberStatus cmsUpdate = new CampaignMemberStatus(Id = cms.Id);
        if (cms.Label == 'Sent') {
            cmsUpdate.Label = 'Subscribed';
        } else {
            cmsUpdate.Label = 'Unsubscribed';
        }
        cmsUpdates.add(cmsUpdate);
    }
    
    update cmsUpdates;
    
    //  Create Schedules and Appointments
    Date startDt = Date.today().toStartOfWeek();
    Date endDt = startDt.addDays(27);
    
    //Level__c levelNormal = [SELECT Id, Name FROM Level__c WHERE Name = 'Donor (Default)'][0];
    
    // This method call will create both a Schedule and Appointments
    List<Appointment__c> appts = CenterScheduleController.createAppointmentSlots(centers[1].Id, 
        startDt, endDt, 4, 10, levelNormal.Id);
    
    // Create Visits  - Need:   1. Donors  2. Loyalty Level  3. Donation Type - from Center  4. Appointment Ids and the Appt DateTime
    //      5. Status = 'Scheduled'
    
    Center_Donation_Type__c centerDonationType = [
        SELECT Id FROM Center_Donation_Type__c 
        WHERE Center__r.Name = 'Proesis Dallas' LIMIT 1
    ];
    
    // method to encapsulate population of Map variable
    void addVisitToMap(Map<String, Visit__c> visitMap, Integer indexVariable, 
            Integer FirstSecondThirdVisit, Integer apptIndexFactor, Account donor, 
            List<Appointment__c> appointmentList, Center_Donation_Type__c donationType){
        visitMap.put(donor.LastName + indexVariable + FirstSecondThirdVisit, new Visit__c(Donor__c= donor.PersonContactId,
        Appointment__c = appointmentList[(indexVariable + apptIndexFactor)].Id,
        Center_Donation_Type__c = donationType.Id,
        Status__c = 'Scheduled'));
    }
        
    Map<String, Visit__c> donorToVisit = new Map<String, Visit__c>{};
    
    List<Account> donorList = [SELECT Id, PersonContactId, LastName FROM Account
        WHERE RecordType.Name = 'Donor' AND Name NOT IN ('Danny Donor', 'Betty Bond') LIMIT 10];
    
    // list of Appointments (already loaded)
    List<Appointment__c> apptList = [SELECT Id, Name, DateTime__c 
        FROM Appointment__c 
        WHERE DateTime__c >= TODAY 
        ORDER BY Datetime__c];
    
    Integer v=0;  // integer variable for donor list
    Integer multi=1;  // integer variable for how many visits to create
    
    for(Account donor : donorList) {
    
        //  how many visits per Donor?  1,2, and 3 ( once w/ 4 donors, twice w/ 3 donors , threee w/ 3 donors) = 19 total visits
        System.debug('row and multiplier: ' + v + ', ' + multi);
        if( v <4 && multi ==1) {  // ONE visit per donor 4 times
            addVisitToMap(donorToVisit, v, 5, 3, donor, apptList, centerDonationType);
            // donorToVisit.put(donor.LastName + v, new Visit__c(Donor__c= donor.PersonContactId,
            //     Appointment__c = appts[v+3].Id,
            //     Center_Donation_Type__c = centerDonationType.Id,
            //     Status__c = 'Scheduled'));
            if(v==3) {
                System.debug('### The code reached here to increment variable: multi');
                multi ++;
            }
        }
        
        if(v >= 4 && v <7 && multi == 2) { // TWO visits per donor 3 times
            addVisitToMap(donorToVisit, v, 7, 3, donor, apptList, centerDonationType);
            addVisitToMap(donorToVisit, v, 8, 320, donor, apptList, centerDonationType);
            if(v==6) {
                multi ++;
            }
        }
    
        if(v >= 7 && v <10 && multi==3) {  // THREE visits per donor 3 times
            addVisitToMap(donorToVisit, v, 9, 3, donor, apptList, centerDonationType);
            addVisitToMap(donorToVisit, v, 10, 340, donor, apptList, centerDonationType);
            addVisitToMap(donorToVisit, v, 11, 670, donor, apptList, centerDonationType);
        }
        v++;
    }
    
    List<Visit__c> visitList = new List<Visit__c>();
    
    for(Visit__c vis: donorToVisit.values()) {
        visitList.add(vis);
    }

    insert visitList;

    System.debug('Count of generated visits: ' + visitList.size());
    // System.debug('Visit__c list: ' + JSON.serializePretty(visitList));

    // modify visit records
    List<Visit__c> visits = [SELECT Id, Status__c, Check_In__c, Outcome__c, Donor__c,
                          Collection_Number__c, Donation_Complete__c, Visit_Date_Time__c
                          FROM Visit__c ORDER BY Visit_Date_Time__c LIMIT 6];

    // 1 Complete/Donation
    visits[0].Status__c =  'Complete';
    visits[0].Outcome__c = 'Donation';
    visits[0].Donation_Volume__c = 1000;
    visits[0].Collection_Number__c = 'c9293893939';
    visits[0].Check_In__c = visits[0].Visit_Date_Time__c.addMinutes(3);
    visits[0].Donation_Complete__c = visits[0].Visit_Date_Time__c.addMinutes(55);
    // 1 Complete/Canceled
    visits[1].Status__c =  'Complete';
    visits[1].Outcome__c = 'Canceled';
    visits[1].Donation_Complete__c = visits[1].Visit_Date_Time__c;
    // 1 Sched/No-Show
    visits[2].Status__c =  'Complete';
    visits[2].Outcome__c = 'No Show';
    visits[2].Donation_Complete__c = visits[2].Visit_Date_Time__c;
    // 1 Status Checked-In
    visits[3].Status__c = 'Checked-In';
    // 1 Sched/No Donation
    visits[4].Outcome__c = 'No Donation';
    visits[4].Donation_Complete__c = visits[4].Visit_Date_Time__c.addMinutes(15);
    // 1 Complete/Rescheduled
    visits[5].Outcome__c = 'Rescheduled';

    update visits;
    
    // insert Transaction and Txn Line Item
    Transaction__c donationCreditTxn = new Transaction__c(
        Amount_Currency__c = 50.00,
        Amount_Points__c = 0,
        Donor__c = visits[0].Donor__c,
        Service__c = 'Proesis Bio',
        Status__c = 'Complete',
        Type__c = 'Credit',
        Visit__c = visits[0].Id
    );
    insert donationCreditTxn;

    List<Txn_Line_Item__c> paymentTxnLIs = new List<Txn_Line_Item__c>{
        new Txn_Line_Item__c(
        Item__c = 'Proesis Bio Card',
        Quantity__c = 150.00,
        Type__c = 'Currency',
        Unit_Cost__c = 1.00,
        Unit_of_Measure__c = 'USD',
        Transaction__c = donationCreditTxn.Id
        )
    };
    insert paymentTxnLIs;
            