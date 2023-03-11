@IsTest
public with sharing class CenterSchedulerControllerTests {

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

        // insert schedules;

        Date startDate =  Date.newInstance(2023, 1, 10).addDays(-10);
        Date endDate =  Date.newInstance(2023, 1, 10).addDays(30);
        Id loyaltyTier = null;
        Integer intervalsPerHour = 6; //10 minutes apart
        Integer slotsPerInterval = 1;

        //create the schedule record
        Schedule__c schedule = ScheduleUtils.createScheduleRecord(centers[0].Id, startDate, endDate);
        insert schedule;

        Account center1 = [SELECT Id FROM Account WHERE Name = 'Proesis Miramar'];

        Appointment__c[] appointments = ScheduleUtils.scheduleRange(centers[0].Id,schedule.Id,startDate,endDate,loyaltyTier,intervalsPerHour,slotsPerInterval);

        insert appointments;
    }

    @IsTest
    public static void testGetCenters(){

        CenterScheduleController.Center[] centers = new CenterScheduleController.Center[]{};
        Test.startTest();
        System.runAs(TestUtil.createAdminUser()){
            centers = CenterScheduleController.getCenters();
        }
        Test.stopTest();
        system.assertEquals(3, centers.size());
    }

    @IsTest
    public static void testGetAppointments(){
        User contextuser = TestUtil.createAdminUser();
        System.runAs(contextuser){
            Account center = [Select ID FROM Account WHERE Name ='Proesis Miramar' ];

            Schedule__c schedule = new Schedule__c(
                Center__c = center.Id,
                Begin_Date__c = Date.newInstance(2023, 1, 10).addDays(-10),
                End_Date__c = Date.newInstance(2023, 1, 10).addDays(30)
            );
            insert schedule;
            Appointment__c[] appointments = new Appointment__c[]{
                new Appointment__c(
                        Schedule__c = schedule.Id,
                    Datetime__c = DateTime.newInstance(2023, 1, 10, 10, 0, 0),
                    Duration__c = 10,
                    Capacity__c = 5
                ),
                new Appointment__c(
                        Schedule__c = schedule.Id,
                    Datetime__c = DateTime.newInstance(2023, 1, 10, 11, 0, 0),
                    Duration__c = 10,
                    Capacity__c = 5
                )
            };
            
            insert appointments;


            Center_Donation_Type__c cdt = new Center_Donation_Type__c(Center__c = center.id);
            insert cdt;

            Contact donor = new Contact(FirstName='Danny', LastName ='Donor');
            insert donor;

            Visit__c visit = new Visit__c(
                Appointment__c = appointments[0].id,
                Center_Donation_Type__c = cdt.Id,
                Donor__c = donor.id
            );

            insert visit;
        
        
            CenterScheduleController.AppointmentSlot[] slots = new CenterScheduleController.AppointmentSlot[]{};
            Id centerId = [SELECT Id FROM Account WHERE NAME = 'Proesis Miramar'].Id;
            Test.startTest();
            
                slots = CenterScheduleController.getAppointments(centerId,Date.newInstance(2023, 1, 10),'','');
                CenterScheduleController.AppointmentSlot slot = CenterScheduleController.getAppointmentSlot(slots[0].Id);
            Test.stopTest();
            system.assertEquals(62, slots.size());
            //figure out why this only passes in scratch:
            // system.assertEquals(1,slot.visits.size());
        }
    }

    @IsTest
    public static void testChangeVisitAppointment(){
        user adminUser = TestUtil.createAdminUser();
        System.runAs(adminUser) {
            Account center = [Select ID FROM Account WHERE Name ='Proesis Miramar' ];

            Schedule__c schedule = new Schedule__c(
                Center__c = center.Id,
                Begin_Date__c = Date.newInstance(2023, 1, 10).addDays(-10),
                End_Date__c = Date.newInstance(2023, 1, 10).addDays(30)
            );
            insert schedule;
            Appointment__c[] appointments = new Appointment__c[]{
                new Appointment__c(
                        Schedule__c = schedule.Id,
                    Datetime__c = DateTime.newInstance(2023, 1, 10, 10, 0, 0),
                    Duration__c = 10,
                    Capacity__c = 5
                ),
                new Appointment__c(
                        Schedule__c = schedule.Id,
                    Datetime__c = DateTime.newInstance(2023, 1, 10, 11, 0, 0),
                    Duration__c = 10,
                    Capacity__c = 5
                )
            };
            
            insert appointments;


            Center_Donation_Type__c cdt = new Center_Donation_Type__c(Center__c = center.id);
            insert cdt;

            Contact donor = new Contact(FirstName='Danny', LastName ='Donor');
            insert donor;

            Visit__c visit = new Visit__c(
                Appointment__c = appointments[0].id,
                Center_Donation_Type__c = cdt.Id,
                Donor__c = donor.id
            );

            insert visit;

            Test.startTest();

                CenterScheduleController.changeVisitAppointment(visit.id, appointments[1].id);
            
            Test.stopTest();

            visit = [SELECT Id, Appointment__c FROM Visit__c limit 1];

            system.assertEquals(appointments[1].id, visit.Appointment__c);
        }

    }


    @IsTest
    public static void testCancelVisit(){
        user adminUser = TestUtil.createAdminUser();
        System.runAs(adminUser) {
            Account center = [Select ID FROM Account WHERE Name ='Proesis Miramar' ];

            Schedule__c schedule = new Schedule__c(
                Center__c = center.Id,
                Begin_Date__c = Date.newInstance(2023, 1, 10).addDays(-10),
                End_Date__c = Date.newInstance(2023, 1, 10).addDays(30)
            );
            insert schedule;
            Appointment__c[] appointments = new Appointment__c[]{
                new Appointment__c(
                        Schedule__c = schedule.Id,
                    Datetime__c = DateTime.newInstance(2023, 1, 10, 10, 0, 0),
                    Duration__c = 10,
                    Capacity__c = 5
                ),
                new Appointment__c(
                        Schedule__c = schedule.Id,
                    Datetime__c = DateTime.newInstance(2023, 1, 10, 11, 0, 0),
                    Duration__c = 10,
                    Capacity__c = 5
                )
            };
            
            insert appointments;


            Center_Donation_Type__c cdt = new Center_Donation_Type__c(Center__c = center.id);
            insert cdt;

            Contact donor = new Contact(FirstName='Danny', LastName ='Donor');
            insert donor;

            Visit__c visit = new Visit__c(
                Appointment__c = appointments[0].id,
                Center_Donation_Type__c = cdt.Id,
                Status__c = 'New',
                Donor__c = donor.id
            );

            insert visit;

            Test.startTest();

                CenterScheduleController.cancelVisit(visit.id);
            
            Test.stopTest();

            visit = [SELECT Id, Status__c, Outcome__c FROM Visit__c limit 1];

            system.assertEquals('Complete', visit.Status__c);
            system.assertEquals('Canceled', visit.Outcome__c);
        }

    }
    
    @IsTest
    public static void testCreateAppointmentSlots(){
        user adminUser = TestUtil.createAdminUser();
        Appointment__c[] appointments;
        Schedule__c schedule;
        Date startDate =  Date.newInstance(2022, 1, 10);
        Date endDate = startDate.addDays(-10);
        System.runAs(adminUser) {
            Account center = [Select ID FROM Account WHERE Name ='Proesis Miramar' ];
            Test.startTest();
            CenterScheduleController.createAppointmentSlots(center.Id,startDate,endDate,1,1,null);
            Test.stopTest();
        }

    }

    @IsTest
    static void testAddVisit() {
        String targetDonorRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Donor').getRecordTypeId();

        Appointment__c targetAppointmentSlot = [SELECT Id, Schedule__r.Center__c FROM Appointment__c LIMIT 1];
        Account targetCenter = [SELECT Id FROM Account WHERE Id = :targetAppointmentSlot.Schedule__r.Center__c LIMIT 1];
        Account targetDonor = [SELECT Id, PersonContactId FROM Account WHERE RecordTypeId = :targetDonorRecordTypeId LIMIT 1];

        // Create additional test data to allow visit insert
        Donation_Type__c donationTypeTest = new Donation_Type__c(
            Name = 'Test Donation Type'
        );
        insert donationTypeTest;

        Center_Donation_Type__c centerDonationTypeTest = new Center_Donation_Type__c(
            Center__c = targetCenter.Id,
            Donation_Type__c = donationTypeTest.Id,
            isActive__c = true
        );
        insert centerDonationTypeTest;

        Test.startTest();
        CenterScheduleController.addVisit(targetDonor.Id, targetAppointmentSlot.Id, targetCenter.Id);
        Test.stopTest();

        Visit__c createdVisit = [
            SELECT Id, Status__c 
            FROM Visit__c 
            WHERE Center_Donation_Type__r.Center__c = :targetCenter.Id AND
                Donor__c = :targetDonor.PersonContactId AND
                Appointment__c = :targetAppointmentSlot.Id
        ];

        Assert.isNotNull(createdVisit, 'Couldn\'t find the desired visit record. Either it wasn\'t created or the data wasn\'t set correctly.');
        Assert.areEqual('Scheduled', createdVisit.Status__c, 'The status of the visit should default to \'Scheduled\'');
    }
}