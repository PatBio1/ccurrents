@IsTest
public with sharing class EndOfDayVisitBatchableTest {

    static Date startDate =  Date.newInstance(2023, 1, 10).addDays(-10);
    static Date endDate =  Date.newInstance(2023, 1, 10).addDays(30);
    static Integer intervalsPerHour = 1;
    static Integer slotsPerInterval = 1;
    static Datetime now = system.Datetime.now();

    @TestSetup
    static void makeData(){
        Id centerRecordTypeID =  Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Center').getRecordTypeId();
        Id personAccountRecordTypeId =  Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Donor').getRecordTypeId();

        system.debug('centerRecordTypeID' + centerRecordTypeID);
        system.debug('personAccountRecordTypeId' + personAccountRecordTypeId);


        // Create Donors
        Account[] donors = new Account[]{
            new Account(
                FirstName = 'Danny',
                LastName = 'Donor',
                RecordTypeID = personAccountRecordTypeId,
                DonorId__c = 'donor-12345'
            ),
            new Account(
                FirstName = 'Betty',
                LastName = 'Bleeder',
                RecordTypeID = personAccountRecordTypeId,
                DonorId__c = 'donor-67890'
            )
        };

        upsert donors DonorId__c;

        //Create Donation Centers
        Account[] centers = new Account[]{
            TestUtil.createMiramarCenter(),
            TestUtil.createDallasCenter(),
            new Account(
                Name = 'Center 3',
                RecordTypeID = centerRecordTypeID,
                ShippingStreet = '333 3rd St',
                CenterId__c = 'center-3'
            )
        };

        upsert centers CenterId__c;


        Schedule__c[] schedules = new Schedule__c[]{
            new Schedule__c(
                Center__c = centers[0].Id, 
                Begin_Date__c =  Date.newInstance(2022, 1, 10).addDays(-10),
                End_Date__c =  Date.newInstance(2024, 1, 10).addDays(30)
            ),
            new Schedule__c(
                Center__c = centers[1].Id,
                Begin_Date__c =  Date.newInstance(2022, 1, 10).addDays(-10),
                End_Date__c =  Date.newInstance(2024, 1, 10).addDays(30)
            ),
            new Schedule__c(
                Center__c = centers[2].Id,
                Begin_Date__c =  Date.newInstance(2024, 1, 10).addDays(-10),
                End_Date__c =  Date.newInstance(2024, 1, 10).addDays(30)
            )
        };

        List<Business_Hours__c> businessHours = new List<Business_Hours__c>();
        for (Id centerId : new List<Id>{centers[0].Id, centers[1].Id}) {
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

        //create the schedule record
        Schedule__c schedule = ScheduleUtils.createScheduleRecord(centers[0].Id, startDate, endDate);
        insert schedule;

        Appointment__c[] appointments = ScheduleUtils.scheduleRange(centers[0].Id,schedule.Id,startDate,endDate, null,intervalsPerHour,slotsPerInterval);
        appointments[2].Datetime__c = system.now() + 1;
        appointments[3].Datetime__c = system.now() + 1;
        insert appointments;

        Center_Donation_Type__c cdt = new Center_Donation_Type__c(Center__c = centers[0].id);
            insert cdt;

            Contact donor = new Contact(FirstName='Danny', LastName ='Donor');
            insert donor;

            Visit__c[] visits = new Visit__c[]{
                new Visit__c(
                    Appointment__c = appointments[0].id,
                    Center_Donation_Type__c = cdt.Id,
                    Donor__c = donor.id,
                    Status__c = 'Checked-In'
                ),
                new Visit__c(
                    Appointment__c = appointments[1].id,
                    Center_Donation_Type__c = cdt.Id,
                    Donor__c = donor.id,
                    Status__c = 'Scheduled'
                ),
                new Visit__c(
                    Appointment__c = appointments[2].id,
                    Center_Donation_Type__c = cdt.Id,
                    Donor__c = donor.id,
                    Status__c = 'Checked-In'
                ),
                new Visit__c(
                    Appointment__c = appointments[3].id,
                    Center_Donation_Type__c = cdt.Id,
                    Donor__c = donor.id,
                    Status__c = 'Scheduled'
                )
            };
        insert visits;
    }


    @IsTest
	static void testEndOfDayVisitBatchable() {

		Test.startTest();

		EndOfDayVisitBatchable.run();

		Test.stopTest();

        Visit__c [] visits = [SELECT Id, Status__c, Outcome__c, Appointment__r.Datetime__c FROM Visit__c ];

        system.assertEquals(4,visits.size());
    
        
        for(Visit__c v: visits){
            if(v.Appointment__r.Datetime__c < now){

                if(v.Status__c == 'Scheduled'){
                    system.assertEquals('No Show', v.Outcome__c);
                }

                if(v.Status__c == 'Complete'){
                    system.assertEquals('No Donation', v.Outcome__c);
                }
            }else{
                system.assertEquals(null, v.Outcome__c);
            }
        }

	}

    @IsTest
	static void testSchedulable() {

		Test.startTest();

		EndOfDayVisitBatchable.scheduleDaily();

		Test.stopTest();

	}
}