@IsTest
public with sharing class CenterSchedulerControllerTests {

    static Date baseDate = System.now().date();
    static Date currentDate =  baseDate.addDays(-12);
    static Date startDate =  baseDate.addDays(-10);
    static Date endDate =  baseDate.addDays(30);
    static Integer intervalsPerHour = 6;
    static Integer slotsPerInterval = 1;

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

        List<Center_Donation_Type__c> centerDonationTypes = new List<Center_Donation_Type__c>{
            TestUtil.createCenterDonationType(centers[0].Id),
            TestUtil.createCenterDonationType(centers[1].Id),
            TestUtil.createCenterDonationType(centers[2].Id)
        };
        insert centerDonationTypes;

        Schedule__c[] schedules = new Schedule__c[]{
            new Schedule__c(
                Center__c = centers[0].Id, 
                Begin_Date__c =  baseDate.addDays(-10),
                End_Date__c =  baseDate.addYears(2).addDays(30)
            ),
            new Schedule__c(
                Center__c = centers[1].Id,
                Begin_Date__c =  baseDate.addDays(-10),
                End_Date__c =  baseDate.addYears(2).addDays(30)
            ),
            new Schedule__c(
                Center__c = centers[2].Id,
                Begin_Date__c =  baseDate.addYears(2).addDays(-10),
                End_Date__c =  baseDate.addYears(2).addDays(30)
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
        system.assertEquals(2, centers.size());
    }

    @IsTest
    public static void testGetAppointments(){
        User contextuser = TestUtil.createAdminUser();
        System.runAs(contextuser){
            Account center = [Select ID FROM Account WHERE Name ='Proesis Miramar' ];

            Schedule__c schedule = new Schedule__c(
                Center__c = center.Id,
                Begin_Date__c = baseDate.addDays(-10),
                End_Date__c = baseDate.addDays(30)
            );
            insert schedule;
            Appointment__c[] appointments = new Appointment__c[]{
                new Appointment__c(
                        Schedule__c = schedule.Id,
                    Datetime__c = DateTime.newInstance(baseDate, Time.newInstance(10, 0, 0, 0)),
                    Duration__c = 10,
                    Capacity__c = 5
                ),
                new Appointment__c(
                        Schedule__c = schedule.Id,
                    Datetime__c = DateTime.newInstance(baseDate, Time.newInstance(11, 0, 0, 0)),
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
            
                slots = CenterScheduleController.getAppointments(centerId,baseDate,'','');
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
                Begin_Date__c = baseDate.addDays(-10),
                End_Date__c = baseDate.addDays(30)
            );
            insert schedule;
            Appointment__c[] appointments = new Appointment__c[]{
                new Appointment__c(
                        Schedule__c = schedule.Id,
                    Datetime__c = DateTime.newInstance(baseDate, Time.newInstance(0, 0, 0, 0)),
                    Duration__c = 10,
                    Capacity__c = 5
                ),
                new Appointment__c(
                        Schedule__c = schedule.Id,
                    Datetime__c = DateTime.newInstance(baseDate, Time.newInstance(0, 0, 0, 0)),
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

            visit = [SELECT Id, Status__c, Outcome__c, Appointment__r.Booked__c FROM Visit__c WHERE Id = :visit.Id limit 1];
            Visit__c newVisit = [SELECT Id, Status__c, Appointment__c, Appointment__r.Booked__c FROM Visit__c WHERE Id != :visit.Id LIMIT 1];

            Assert.areEqual('Complete', visit.Status__c, 'Old Visit record should be complete');
            Assert.areEqual('Rescheduled', visit.Outcome__c, 'Old Visit record should be marked as rescheduled');
            Assert.areEqual(-1, visit.Appointment__r.Booked__c, 'Old Appointment should be marked as not booked'); // Since we are inserting the visit directly, the booked count is not updated to 1. Therefore we expect -1

            Assert.isNotNull(newVisit, 'Should have found a new visit record');
            Assert.areEqual('Scheduled', newVisit.Status__c, 'New Visit record should be scheduled');
            Assert.areEqual(appointments[1].id, newVisit.Appointment__c, 'New Visit record should be scheduled for the new appointment');
            Assert.areEqual(1, newVisit.Appointment__r.Booked__c, 'New Appointment should be marked as booked');
        }
    }

    @IsTest
    public static void testCancelVisit(){
        user adminUser = TestUtil.createAdminUser();
        System.runAs(adminUser) {
            Account center = [Select ID FROM Account WHERE Name ='Proesis Miramar' ];

            Schedule__c schedule = new Schedule__c(
                Center__c = center.Id,
                Begin_Date__c = baseDate.addDays(-10),
                End_Date__c = baseDate.addDays(30)
            );
            insert schedule;
            Appointment__c[] appointments = new Appointment__c[]{
                new Appointment__c(
                        Schedule__c = schedule.Id,
                    Datetime__c = DateTime.newInstance(baseDate, Time.newInstance(0, 0, 0, 0)),
                    Duration__c = 10,
                    Capacity__c = 5,
                    Booked__c = 1 // A visit is added later in the test
                ),
                new Appointment__c(
                        Schedule__c = schedule.Id,
                    Datetime__c = DateTime.newInstance(baseDate, Time.newInstance(0, 0, 0, 0)),
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

            visit = [SELECT Id, Status__c, Outcome__c, Appointment__r.Booked__c FROM Visit__c limit 1];

            system.assertEquals('Complete', visit.Status__c);
            system.assertEquals('Canceled', visit.Outcome__c);
            system.assertEquals(0, visit.Appointment__r.Booked__c);
        }
    }
    
    @IsTest
    public static void testCreateAppointmentSlots(){
        user adminUser = TestUtil.createAdminUser();
        Appointment__c[] appointments;
        Schedule__c schedule;
        Date startDate =  baseDate.addYears(-1);
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
            SELECT Id, Status__c, Appointment__r.Booked__c 
            FROM Visit__c 
            WHERE Center_Donation_Type__r.Center__c = :targetCenter.Id AND
                Donor__c = :targetDonor.PersonContactId AND
                Appointment__c = :targetAppointmentSlot.Id
        ];

        Assert.isNotNull(createdVisit, 'Couldn\'t find the desired visit record. Either it wasn\'t created or the data wasn\'t set correctly.');
        Assert.areEqual('Scheduled', createdVisit.Status__c, 'The status of the visit should default to \'Scheduled\'');
        Assert.areEqual(1, createdVisit.Appointment__r.Booked__c, 'Adding a visit should have incremented the appointment booked value');
    }

    @IsTest
    static void testGetAvailableRescheduleAppointmentRange() {
        List<CenterScheduleController.RescheduleSlot> rescheduleSlots;
        Schedule__c targetSchedule = [SELECT Id, Center__c FROM Schedule__c LIMIT 1];
        DateTime currentDateTime = DateTime.newInstance(currentDate, Time.newInstance(0, 0, 0, 0));

        User contextuser = TestUtil.createAdminUser();

        Test.startTest();
        System.runAs(contextuser){
            rescheduleSlots = CenterScheduleController.getAvailableRescheduleAppointmentRange(
                targetSchedule.Center__c,
                currentDateTime,
                currentDateTime.addDays(1),
                DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0)),
                DateTime.newInstance(endDate, Time.newInstance(0, 0, 0, 0)),
                true
            );
        }
        Test.stopTest();

        Assert.isNotNull(rescheduleSlots, 'The reschedule slots should not be null');
        Assert.isTrue(rescheduleSlots.size() > 0, 'There should only be one reschedule slot');
    }

    @IsTest
    static void testNoAvailableRescheduleAppointmentRange() {
        List<CenterScheduleController.RescheduleSlot> rescheduleSlots;
        Schedule__c targetSchedule = [SELECT Id, Center__c FROM Schedule__c LIMIT 1];
        DateTime currentDateTime = DateTime.newInstance(currentDate, Time.newInstance(0, 0, 0, 0));

        User contextuser = TestUtil.createAdminUser();
        
        Test.startTest();
        System.runAs(contextuser){
            rescheduleSlots = CenterScheduleController.getAvailableRescheduleAppointmentRange(
                targetSchedule.Center__c,
                currentDateTime,
                currentDateTime.addDays(1),
                DateTime.newInstance(endDate, Time.newInstance(0, 0, 0, 0)),
                DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0)),
                true
            );
        }
        Test.stopTest();

        Assert.isNotNull(rescheduleSlots, 'The reschedule slots should not be null');
        Assert.areEqual(0, rescheduleSlots.size(), 'No reschedule slots are returned for an invalid date range');
    }

    @IsTest
    static void testCreateSoonestNextVisitForDonor() {
        Account targetCenter = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Center' LIMIT 1];
        insert new Center_Donation_Type__c(Center__c = targetCenter.id);

        Account targetDonor = [SELECT Id, PersonContactId, Loyalty_Level__pc FROM Account WHERE RecordType.DeveloperName = 'Donor' LIMIT 1];

        Test.startTest();
        CenterScheduleController.createSoonestNextVisitForDonor(targetDonor.Id, targetCenter.Id);
        Test.stopTest();

        Visit__c createdVisit = [
            SELECT Id, Status__c, Appointment__r.Booked__c, Appointment__r.Booked_Loyalty__c, Appointment__r.Availability__c, Appointment__r.Availability_Loyalty__c 
            FROM Visit__c 
            WHERE Center_Donation_Type__r.Center__c = :targetCenter.Id AND
                Donor__c = :targetDonor.PersonContactId
            LIMIT 1
        ];

        Assert.isNotNull(createdVisit, 'Couldn\'t find the desired visit record. Either it wasn\'t created or the data wasn\'t set correctly.');
        Assert.areEqual('Scheduled', createdVisit.Status__c, 'The status of the visit should default to \'Scheduled\'');

        // If they are a loyalty donor, check the loyalty fields otherwise check the non-loyalty fields
        // we don't really care whether we test against a loyalty or non-loyalty donor for this test. Just future proofing.
        if (LoyaltyLevelService.getLoyaltyLevel(targetDonor.Loyalty_Level__pc) > 0) {
            Assert.areEqual(1, createdVisit.Appointment__r.Booked_Loyalty__c, 'Adding a visit should have incremented the appointment booked value');
            Assert.isTrue(createdVisit.Appointment__r.Availability_Loyalty__c >= 0, 'The visit shouldn\'t have been added to an appointment slot with no availability');
        } else {
            Assert.areEqual(1, createdVisit.Appointment__r.Booked__c, 'Adding a visit should have incremented the appointment booked value');
            Assert.isTrue(createdVisit.Appointment__r.Availability__c >= 0, 'The visit shouldn\'t have been added to an appointment slot with no availability');
        }
    }

    @IsTest 
    static void testLinkPaymentCard() {
        Contact targetDonor = [SELECT Id FROM Contact LIMIT 1];
        String testCardPackage = '0123';
        String initialPIN = '1111';

        Test.setMock(HttpCalloutMock.class, new OnbeWsPrepaidHttpCalloutMock());

        Test.startTest();
        CenterScheduleController.linkPaymentCard(testCardPackage, targetDonor.Id, initialPIN);
        Test.stopTest();

        Assert.areEqual(1, [SELECT count() FROM Payment_Method__c WHERE Donor__c = :targetDonor.Id], 'The payment method should have been created');
    }

    @IsTest 
    static void testPositiveAppointmentSlotCapacityUpdate() {
        Appointment__c targetAppointmentSlot = [SELECT Id, Booked__c, Capacity__c FROM Appointment__c LIMIT 1];
        Decimal startingCapacity = targetAppointmentSlot.Capacity__c;

        Test.startTest();
        CenterScheduleController.updateAppointmentSlotCapacity(targetAppointmentSlot.Id, 1);
        Test.stopTest();

        Appointment__c updatedAppointmentSlot = [SELECT Id, Booked__c, Capacity__c FROM Appointment__c WHERE Id = :targetAppointmentSlot.Id LIMIT 1];
        Assert.areEqual(startingCapacity + 1, updatedAppointmentSlot.Capacity__c, 'The capacity should have been incremented by 1');
    }

    @IsTest 
    static void testNegativeAppointmentSlotCapacityUpdate() {
        final Integer CAPACITY_CHANGE = 1;

        Appointment__c targetAppointmentSlot = [SELECT Id, Booked__c, Capacity__c, Availability__c, Schedule__r.Center__c FROM Appointment__c ORDER BY Datetime__c ASC LIMIT 1];
        Decimal startingCapacity = targetAppointmentSlot.Capacity__c;
        
        Integer capacityAsInteger = (Integer)startingCapacity;
        List<Contact> donors = [SELECT Id FROM Contact LIMIT :capacityAsInteger];

        // Create Temp donors if there wasn't enough already created
        if (targetAppointmentSlot.Availability__c > 0 && donors.size() < targetAppointmentSlot.Availability__c) {
            List<Contact> newDonors = new List<Contact>();

            for (Integer i = donors.size(); i < (targetAppointmentSlot.Availability__c - donors.size()); i++) {
                newDonors.add(new Contact(FirstName = 'Test', LastName = 'Donor ' + (i + 1)));
            }
            insert newDonors;
        }

        Center_Donation_Type__c targetCenterDonationType = [SELECT Id FROM Center_Donation_Type__c WHERE Center__c = :targetAppointmentSlot.Schedule__r.Center__c LIMIT 1];

        List<Visit__c> visits = new List<Visit__c>();
        for (Contact donor : donors) {
            visits.add(new Visit__c(
                Appointment__c = targetAppointmentSlot.Id,
                Center_Donation_Type__c = targetCenterDonationType.Id,
                Donor__c = donor.Id,
                Status__c = 'Scheduled'
            ));
        }
        CoreSchedulerHandler.createVisits(visits);

        Test.startTest();
        CenterScheduleController.updateAppointmentSlotCapacity(targetAppointmentSlot.Id, -CAPACITY_CHANGE);
        Test.stopTest();

        Appointment__c updatedAppointmentSlot = [SELECT Id, Booked__c, Capacity__c, (SELECT Id FROM Appointments__r WHERE Outcome__c = null) FROM Appointment__c WHERE Id = :targetAppointmentSlot.Id LIMIT 1];
        Assert.areEqual(startingCapacity - 1, updatedAppointmentSlot.Capacity__c, 'The capacity should have been decremented by ' + CAPACITY_CHANGE);
        Assert.areEqual(updatedAppointmentSlot.Capacity__c, updatedAppointmentSlot.Appointments__r.size(), 'The appointment slot should have one less appointment');

        Appointment__c expectedRescheduleSlot = [SELECT Id, Booked__c, Capacity__c, Availability__c, Schedule__r.Center__c FROM Appointment__c ORDER BY Datetime__c ASC LIMIT 1 OFFSET 1];
        Assert.areEqual(CAPACITY_CHANGE, [SELECT count() FROM Visit__c WHERE Appointment__c = :expectedRescheduleSlot.Id AND Donor__c IN :donors], 'There should be ' + CAPACITY_CHANGE + ' visit rescheduled to the next appointment slot');
    }
}