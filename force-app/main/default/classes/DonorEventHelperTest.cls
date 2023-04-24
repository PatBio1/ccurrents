@IsTest
public class DonorEventHelperTest {
    // 99 is the max amount of donors that can be checked in to an appointment
    final static Integer AMOUNT_OF_DONORS = 99;
    final static String TEST_BECS_DEVICE_ID = 'becs12345';

    @TestSetup
    static void createTestData() {
        Account centerAccount = TestUtil.createMiramarCenter();
        insert centerAccount;

        Device__c becsDevice = new Device__c(
            Device_Id__c = TEST_BECS_DEVICE_ID,
            Center__c = centerAccount.Id,
            Type__c = 'BECS'
        );
        insert becsDevice;

        Datetime testDateTime = Datetime.now();
        Schedule__c testSchedule = TestUtil.createTestSchedule(centerAccount.Id, testDateTime);
        insert testSchedule;

        List<Appointment__c> testAppointments = new List<Appointment__c> {
            TestUtil.createTestAppointment(testSchedule.Id, testDateTime),
            TestUtil.createTestAppointment(testSchedule.Id, testDateTime.addDays(1))
        };
        
        for(Appointment__c testAppointment : testAppointments) {
            testAppointment.Capacity__c = AMOUNT_OF_DONORS;
        }

        insert testAppointments;

        Center_Donation_Type__c testCenterDonationType = TestUtil.createCenterDonationType(centerAccount.Id);
        insert testCenterDonationType;

        List<Account> donors = new List<Account>();
        for (Integer i = 0; i < AMOUNT_OF_DONORS; i++) {
            Account donorAccount = TestUtil.createDonor(String.valueOf(i));
            donorAccount.Last_Used_Center__pc = centerAccount.Id;

            donors.add(donorAccount);
        }
        insert donors;
    }

    @IsTest
    static void testDonorCheckInNoDonor() {
        // Create Donor_CheckIn__e records for donorIds that don't have a donor
        // Make sure the tasks get created

        List<List<Donor_CheckIn__e>> donorCheckInEvents = new List<List<Donor_CheckIn__e>>();
        for (Integer i = 0; i < AMOUNT_OF_DONORS; i++) {
            Donor_CheckIn__e donorCheckInEvent = new Donor_CheckIn__e();
            donorCheckInEvent.Donor_Number__c = '00Q0' + String.valueOf(i); // Made up Donor Numbers that shouldn\'t exist
            donorCheckInEvent.Timestamp__c = Datetime.now();

            donorCheckInEvents.add(new List<Donor_CheckIn__e> { donorCheckInEvent });
        }

        Test.startTest();
        List<List<SObject>> validatedEvents = DonorEventHelper.validateDonorAndVisitReferences(donorCheckInEvents);
        Test.stopTest();

        // The only time an event is marked as invalid is when the donorId is not found
        Assert.areEqual(0, validatedEvents.size(), 'There should be no valid events');
        Assert.areEqual(AMOUNT_OF_DONORS, [SELECT count() FROM Task], 'A task should have been created for each missing donor');
    }

    @IsTest 
    static void testDonorCheckInValidEvents() {
        // Create Donor_CheckIn__e records for donors(Account) that have a donorId
        // Make sure the event records are returned as validated

        List<Contact> validDonors = [SELECT Id, Account.DonorId__c FROM Contact WHERE Account.DonorId__c != null];
        List<Visit__c> visits = new List<Visit__c>();

        Appointment__c testAppointment = [SELECT Id, Datetime__c FROM Appointment__c LIMIT 1];
        Center_Donation_Type__c testCenterDonationType = [SELECT Id FROM Center_Donation_Type__c LIMIT 1];

        for(Contact validDonor : validDonors) {
            Visit__c visit = new Visit__c();
            visit.Donor__c = validDonor.Id;
            visit.Appointment__c = testAppointment.Id;
            visit.Center_Donation_Type__c = testCenterDonationType.Id;
            visits.add(visit);
        }
        insert visits;

        List<List<Donor_CheckIn__e>> donorCheckInEvents = new List<List<Donor_CheckIn__e>>();
        for(Contact donor : validDonors) {
            Donor_CheckIn__e donorCheckInEvent = new Donor_CheckIn__e();
            donorCheckInEvent.Donor_Number__c = donor.Account.DonorId__c;
            donorCheckInEvent.Timestamp__c = testAppointment.Datetime__c;

            donorCheckInEvents.add(new List<Donor_CheckIn__e> { donorCheckInEvent });
        }

        Test.startTest();
        List<List<SObject>> validatedEvents = DonorEventHelper.validateDonorAndVisitReferences(donorCheckInEvents);
        Test.stopTest();

        Assert.areEqual(AMOUNT_OF_DONORS, validatedEvents.size(), 'There should be ' + AMOUNT_OF_DONORS + ' valid events');
    }

    @IsTest
    static void testDonorCheckInRescheduleVisitEvents() {
        // Create Donor_CheckIn__e records for donors(Account) that have a donorId
        // Make sure the event records are returned as validated

        List<Contact> validDonors = [SELECT Id, Account.DonorId__c FROM Contact WHERE Account.DonorId__c != null];
        List<Visit__c> visits = new List<Visit__c>();

        List<Appointment__c> testAppointments = [SELECT Id, Datetime__c FROM Appointment__c ORDER BY Datetime__c ASC LIMIT 2];
        Center_Donation_Type__c testCenterDonationType = [SELECT Id FROM Center_Donation_Type__c LIMIT 1];

        for(Contact validDonor : validDonors) {
            Visit__c visit = new Visit__c();
            visit.Donor__c = validDonor.Id;
            visit.Appointment__c = testAppointments[1].Id;
            visit.Center_Donation_Type__c = testCenterDonationType.Id;
            visits.add(visit);
        }
        insert visits;

        List<List<Donor_CheckIn__e>> donorCheckInEvents = new List<List<Donor_CheckIn__e>>();
        for(Contact donor : validDonors) {
            Donor_CheckIn__e donorCheckInEvent = new Donor_CheckIn__e();
            donorCheckInEvent.Donor_Number__c = donor.Account.DonorId__c;
            donorCheckInEvent.Timestamp__c = testAppointments[0].Datetime__c;

            donorCheckInEvents.add(new List<Donor_CheckIn__e> { donorCheckInEvent });
        }

        Test.startTest();
        List<List<SObject>> validatedEvents = DonorEventHelper.validateDonorAndVisitReferences(donorCheckInEvents);
        Test.stopTest();

        Assert.areEqual(AMOUNT_OF_DONORS, validatedEvents.size(), 'There should be ' + AMOUNT_OF_DONORS + ' valid events');

        for(Visit__c rescheduledVisit : [SELECT Id, Appointment__c, Status__c, Outcome__c FROM Visit__c WHERE Appointment__c IN :testAppointments]) {
            if (rescheduledVisit.Appointment__c == testAppointments[0].Id) {
                Assert.areEqual('Scheduled', rescheduledVisit.Status__c, 'The new visit should have been status=scheduled');
                Assert.areEqual(null, rescheduledVisit.Outcome__c, 'The new visit should have been outcome=null');
            } else {
                Assert.areEqual('Complete', rescheduledVisit.Status__c, 'The original visit should have been status=completed');
                Assert.areEqual('Rescheduled', rescheduledVisit.Outcome__c, 'The original visit should have been outcome=rescheduled');
            }
        }
    }

    @IsTest
    static void testDonorCheckInMissingVisitEvents() {
        List<Contact> validDonors = [SELECT Id, Account.DonorId__c FROM Contact WHERE Account.DonorId__c != null];
        Appointment__c targetAppointment = [SELECT Id, Datetime__c FROM Appointment__c LIMIT 1];

        List<List<Donor_CheckIn__e>> donorCheckInEvents = new List<List<Donor_CheckIn__e>>();
        for(Contact donor : validDonors) {
            Donor_CheckIn__e donorCheckInEvent = new Donor_CheckIn__e();
            donorCheckInEvent.Donor_Number__c = donor.Account.DonorId__c;
            donorCheckInEvent.Timestamp__c = targetAppointment.Datetime__c;

            donorCheckInEvents.add(new List<Donor_CheckIn__e> { donorCheckInEvent });
        }

        Test.startTest();
        List<List<SObject>> validatedEvents = DonorEventHelper.validateDonorAndVisitReferences(donorCheckInEvents);
        Test.stopTest();

        Assert.areEqual(AMOUNT_OF_DONORS, validatedEvents.size(), 'There should be ' + AMOUNT_OF_DONORS + ' valid events');

        List<Visit__c> missingVisits = [SELECT Id FROM Visit__c WHERE Appointment__c = :targetAppointment.Id];
        Assert.areEqual(AMOUNT_OF_DONORS, missingVisits.size(), 'There should be ' + AMOUNT_OF_DONORS + ' missing visits');
        Assert.areEqual(AMOUNT_OF_DONORS, [SELECT count() FROM Task WHERE WhatId IN :missingVisits AND Subject LIKE 'Missing Visit%'], 'There should be ' + AMOUNT_OF_DONORS + ' missing visit tasks');
    }

    @IsTest
    static void testDonorCompNoDonor() {
        List<List<Donor_Comp__e>> donorCompEvents = new List<List<Donor_Comp__e>>();
        for (Integer i = 0; i < AMOUNT_OF_DONORS; i++) {
            Donor_Comp__e donorCompEvent = new Donor_Comp__e();
            donorCompEvent.Donor_Number__c = '00Q0' + String.valueOf(i); // Made up Donor Numbers that shouldn\'t exist
            donorCompEvent.Timestamp__c = Datetime.now();
            donorCompEvent.BECS_Device__c = TEST_BECS_DEVICE_ID;

            donorCompEvents.add(new List<Donor_Comp__e> { donorCompEvent });
        }

        Test.startTest();
        List<List<SObject>> validatedEvents = DonorEventHelper.validateDonorAndVisitReferences(donorCompEvents);
        Test.stopTest();

        // The only time an event is marked as invalid is when the donorId is not found
        Assert.areEqual(0, validatedEvents.size(), 'There should be no valid events');
        Assert.areEqual(AMOUNT_OF_DONORS, [SELECT count() FROM Task], 'A task should have been created for each missing donor');
    }

    @IsTest 
    static void testDonorCompValidEvents() {
        List<Contact> validDonors = [SELECT Id, Account.DonorId__c FROM Contact WHERE Account.DonorId__c != null];
        List<Visit__c> visits = new List<Visit__c>();

        Appointment__c testAppointment = [SELECT Id, Datetime__c FROM Appointment__c LIMIT 1];
        Center_Donation_Type__c testCenterDonationType = [SELECT Id FROM Center_Donation_Type__c LIMIT 1];

        for(Contact validDonor : validDonors) {
            Visit__c visit = new Visit__c();
            visit.Donor__c = validDonor.Id;
            visit.Appointment__c = testAppointment.Id;
            visit.Center_Donation_Type__c = testCenterDonationType.Id;
            visits.add(visit);
        }
        insert visits;

        List<List<Donor_Comp__e>> donorCompEvents = new List<List<Donor_Comp__e>>();
        for(Contact donor : validDonors) {
            Donor_Comp__e donorCompEvent = new Donor_Comp__e();
            donorCompEvent.Donor_Number__c = donor.Account.DonorId__c;
            donorCompEvent.Timestamp__c = testAppointment.Datetime__c;
            donorCompEvent.BECS_Device__c = TEST_BECS_DEVICE_ID;

            donorCompEvents.add(new List<Donor_Comp__e> { donorCompEvent });
        }

        Test.startTest();
        List<List<SObject>> validatedEvents = DonorEventHelper.validateDonorAndVisitReferences(donorCompEvents);
        Test.stopTest();

        Assert.areEqual(AMOUNT_OF_DONORS, validatedEvents.size(), 'There should be ' + AMOUNT_OF_DONORS + ' valid events');
    }

    @IsTest
    static void testDonorCompRescheduleVisitEvents() {
        List<Contact> validDonors = [SELECT Id, Account.DonorId__c FROM Contact WHERE Account.DonorId__c != null];
        List<Visit__c> visits = new List<Visit__c>();

        List<Appointment__c> testAppointments = [SELECT Id, Datetime__c FROM Appointment__c ORDER BY Datetime__c ASC LIMIT 2];
        Center_Donation_Type__c testCenterDonationType = [SELECT Id FROM Center_Donation_Type__c LIMIT 1];

        for(Contact validDonor : validDonors) {
            Visit__c visit = new Visit__c();
            visit.Donor__c = validDonor.Id;
            visit.Appointment__c = testAppointments[1].Id;
            visit.Center_Donation_Type__c = testCenterDonationType.Id;
            visits.add(visit);
        }
        insert visits;

        List<List<Donor_Comp__e>> donorCompEvents = new List<List<Donor_Comp__e>>();
        for(Contact donor : validDonors) {
            Donor_Comp__e donorCompEvent = new Donor_Comp__e();
            donorCompEvent.Donor_Number__c = donor.Account.DonorId__c;
            donorCompEvent.Timestamp__c = testAppointments[0].Datetime__c;
            donorCompEvent.BECS_Device__c = TEST_BECS_DEVICE_ID;

            donorCompEvents.add(new List<Donor_Comp__e> { donorCompEvent });
        }

        Test.startTest();
        List<List<SObject>> validatedEvents = DonorEventHelper.validateDonorAndVisitReferences(donorCompEvents);
        Test.stopTest();

        Assert.areEqual(AMOUNT_OF_DONORS, validatedEvents.size(), 'There should be ' + AMOUNT_OF_DONORS + ' valid events');

        for(Visit__c rescheduledVisit : [SELECT Id, Appointment__c, Status__c, Outcome__c FROM Visit__c WHERE Appointment__c IN :testAppointments]) {
            if (rescheduledVisit.Appointment__c == testAppointments[0].Id) {
                Assert.areEqual('Scheduled', rescheduledVisit.Status__c, 'The new visit should have been status=scheduled');
                Assert.areEqual(null, rescheduledVisit.Outcome__c, 'The new visit should have been outcome=null');
            } else {
                Assert.areEqual('Complete', rescheduledVisit.Status__c, 'The original visit should have been status=completed');
                Assert.areEqual('Rescheduled', rescheduledVisit.Outcome__c, 'The original visit should have been outcome=rescheduled');
            }
        }
    }

    @IsTest
    static void testDonorCompMissingVisitEvents() {
        List<Contact> validDonors = [SELECT Id, Account.DonorId__c FROM Contact WHERE Account.DonorId__c != null];
        Appointment__c targetAppointment = [SELECT Id, Datetime__c FROM Appointment__c LIMIT 1];

        List<List<Donor_Comp__e>> donorCompEvents = new List<List<Donor_Comp__e>>();
        for(Contact donor : validDonors) {
            Donor_Comp__e donorCompEvent = new Donor_Comp__e();
            donorCompEvent.Donor_Number__c = donor.Account.DonorId__c;
            donorCompEvent.Timestamp__c = targetAppointment.Datetime__c;
            donorCompEvent.BECS_Device__c = TEST_BECS_DEVICE_ID;

            donorCompEvents.add(new List<Donor_Comp__e> { donorCompEvent });
        }

        Test.startTest();
        List<List<SObject>> validatedEvents = DonorEventHelper.validateDonorAndVisitReferences(donorCompEvents);
        Test.stopTest();

        Assert.areEqual(AMOUNT_OF_DONORS, validatedEvents.size(), 'There should be ' + AMOUNT_OF_DONORS + ' valid events');

        List<Visit__c> missingVisits = [SELECT Id FROM Visit__c WHERE Appointment__c = :targetAppointment.Id];
        Assert.areEqual(AMOUNT_OF_DONORS, missingVisits.size(), 'There should be ' + AMOUNT_OF_DONORS + ' missing visits');
        Assert.areEqual(AMOUNT_OF_DONORS, [SELECT count() FROM Task WHERE WhatId IN :missingVisits AND Subject LIKE 'Missing Visit%'], 'There should be ' + AMOUNT_OF_DONORS + ' missing visit tasks');
    }
}