@IsTest
public class CoreSchedulerHandlerTest {
    final static Integer AMOUNT_OF_DONORS = 50;
    final static Integer BASE_CAPACITY = 2;

    @TestSetup
    static void createTestData() {
        Account centerAccount = TestUtil.createMiramarCenter();
        insert centerAccount;

        Center_Donation_Type__c testCenterDonationType = TestUtil.createCenterDonationType(centerAccount.Id);
        insert testCenterDonationType;

        Datetime testDateTime = Datetime.now();
        Schedule__c testSchedule = TestUtil.createTestSchedule(centerAccount.Id, testDateTime);
        insert testSchedule;

        List<Account> donors = new List<Account>();
        List<Appointment__c> appointments = new List<Appointment__c>();

        Datetime currentDatetime = testDateTime;
        for (Integer i = 0; i < AMOUNT_OF_DONORS; i++) {
            donors.add(TestUtil.createDonor(String.valueOf(i)));

            Appointment__c testAppointment = TestUtil.createTestAppointment(testSchedule.Id, currentDatetime);
            testAppointment.Capacity__c = BASE_CAPACITY;

            appointments.add(testAppointment);
            currentDatetime = testDateTime.addDays(1);
        }

        // Add one more appointment to allow shifting while rescheduling
        appointments.add(TestUtil.createTestAppointment(testSchedule.Id, currentDatetime));

        insert donors;
        insert appointments;
    }

    @IsTest 
    static void testRescheduleVisit() {
        List<Appointment__c> targetAppointments = [SELECT Id, Datetime__c FROM Appointment__c LIMIT 2];
        Contact targetDonor = [SELECT Id FROM Contact LIMIT 1];
        Center_Donation_Type__c targetCenterDonationType = [SELECT Id FROM Center_Donation_Type__c LIMIT 1];

        Visit__c testVisit = new Visit__c(
            Appointment__c = targetAppointments[0].Id,
            Donor__c = targetDonor.Id,
            Center_Donation_Type__c = targetCenterDonationType.Id,
            Status__c = 'Scheduled'
        );
        insert testVisit;

        Test.startTest();
        CoreSchedulerHandler.rescheduleVisit(new CoreSchedulerHandler.RescheduleRequest(
            testVisit.Id,    
            targetAppointments[1].Id
        ));
        Test.stopTest();

        Visit__c updatedOriginalVisit = [SELECT Id, Status__c, Outcome__c FROM Visit__c WHERE Id = :testVisit.Id LIMIT 1];
        Assert.areEqual('Complete', updatedOriginalVisit.Status__c, 'Original visit should be marked as complete.');
        Assert.areEqual('Rescheduled', updatedOriginalVisit.Outcome__c, 'Original visit should be marked as rescheduled.');

        Visit__c newRescheduledVisit = [SELECT Id, Status__c FROM Visit__c WHERE Appointment__c = :targetAppointments[1].Id LIMIT 1];
        Assert.areEqual('Scheduled', newRescheduledVisit.Status__c, 'New visit should be marked as scheduled.');
    }

    @IsTest
    static void testRescheduleVisits() {
        List<Appointment__c> targetAppointments = [SELECT Id FROM Appointment__c ORDER BY Datetime__c ASC];
        List<Contact> targetDonors = [SELECT Id FROM Contact];
        Center_Donation_Type__c targetCenterDonationType = [SELECT Id FROM Center_Donation_Type__c LIMIT 1];

        List<Visit__c> originalVisits = new List<Visit__c>();
        Integer visitCounter = 0;

        for(Contact targetDonor : targetDonors) {
            originalVisits.add(new Visit__c(
                Appointment__c = targetAppointments[visitCounter++].Id,
                Donor__c = targetDonor.Id,
                Center_Donation_Type__c = targetCenterDonationType.Id,
                Status__c = 'Scheduled'
            ));
        }
        insert originalVisits;

        Map<Id, CoreSchedulerHandler.RescheduleRequest> rescheduleRequests = new Map<Id, CoreSchedulerHandler.RescheduleRequest>();

        for (Integer i = 0; i < originalVisits.size(); i++) {
            rescheduleRequests.put(originalVisits[i].Id, new CoreSchedulerHandler.RescheduleRequest(
                originalVisits[i].Id,
                targetAppointments[i + 1].Id
            ));
        }

        Test.startTest();
        CoreSchedulerHandler.rescheduleVisits(new CoreSchedulerHandler.RescheduleBatchRequest(rescheduleRequests.values()));
        Test.stopTest();

        List<Visit__c> updatedOriginalVisits = [SELECT Id, Status__c, Outcome__c FROM Visit__c WHERE Id IN :originalVisits];
        for (Visit__c updatedOriginalVisit : updatedOriginalVisits) {
            Assert.areEqual('Complete', updatedOriginalVisit.Status__c, 'Original visit should be marked as complete.');
            Assert.areEqual('Rescheduled', updatedOriginalVisit.Outcome__c, 'Original visit should be marked as rescheduled.');
        }

        List<Visit__c> newRescheduledVisits = [SELECT Id, Status__c, Rescheduled_Visit__c FROM Visit__c WHERE Appointment__c IN :targetAppointments AND Id NOT IN :originalVisits];
        Assert.areEqual(originalVisits.size(), newRescheduledVisits.size(), 'There should be the same amount of new visits as there were original visits.');

        for (Visit__c newRescheduledVisit : newRescheduledVisits) {
            Assert.areEqual('Scheduled', newRescheduledVisit.Status__c, 'New visit should be marked as scheduled.');
            Assert.isNotNull(newRescheduledVisit.Rescheduled_Visit__c, 'New visit should have a reference to an old visit');
            
            CoreSchedulerHandler.RescheduleRequest rescheduleRequest = rescheduleRequests.get(newRescheduledVisit.Rescheduled_Visit__c);
            Assert.areEqual(rescheduleRequest.originalVisitId, newRescheduledVisit.Rescheduled_Visit__c, 'New visit should have a reference to the old visit');
        }
    }

    @IsTest 
    static void testCreateVisit() {
        List<Appointment__c> targetAppointments = [SELECT Id, Datetime__c FROM Appointment__c LIMIT 1];
        Contact targetDonor = [SELECT Id FROM Contact LIMIT 1];
        Center_Donation_Type__c targetCenterDonationType = [SELECT Id FROM Center_Donation_Type__c LIMIT 1];

        Visit__c createdVisit, testVisit = new Visit__c(
            Appointment__c = targetAppointments[0].Id,
            Donor__c = targetDonor.Id,
            Center_Donation_Type__c = targetCenterDonationType.Id,
            Status__c = 'Scheduled'
        );

        Test.startTest();
        createdVisit = CoreSchedulerHandler.createVisit(testVisit);
        Test.stopTest();

        Assert.isNotNull(createdVisit.Id, 'Visit should be created.');

        List<Appointment__c> updatedAppointments = [SELECT Id, Booked__c, Availability__c FROM Appointment__c WHERE Id IN :targetAppointments];
        Assert.areEqual(1, updatedAppointments[0].Booked__c, 'Appointment should be marked as booked.');
        Assert.areEqual(BASE_CAPACITY - 1, updatedAppointments[0].Availability__c, 'Appointment should have ' + (BASE_CAPACITY - 1) + ' available slot.');
    }

    @IsTest 
    static void testCreateVisits() {
        List<Appointment__c> targetAppointments = [SELECT Id, Datetime__c FROM Appointment__c];
        List<Contact> targetDonors = [SELECT Id FROM Contact];
        Center_Donation_Type__c targetCenterDonationType = [SELECT Id FROM Center_Donation_Type__c LIMIT 1];

        List<Visit__c> testVisits = new List<Visit__c>();
        Set<Id> bookedAppointmentsSlots = new Set<Id>();

        for (Integer i = 0; i < targetDonors.size(); i++) {
            testVisits.add(new Visit__c(
                Appointment__c = targetAppointments[i].Id,
                Donor__c = targetDonors[i].Id,
                Center_Donation_Type__c = targetCenterDonationType.Id,
                Status__c = 'Scheduled'
            ));

            bookedAppointmentsSlots.add(targetAppointments[i].Id);
        }

        Test.startTest();
        CoreSchedulerHandler.createVisits(testVisits);
        Test.stopTest();

        List<Visit__c> createdVisits = [SELECT Id FROM Visit__c WHERE Appointment__c IN :bookedAppointmentsSlots];
        Assert.areEqual(testVisits.size(), createdVisits.size(), 'There should be the same amount of created visits as there were test visits.');

        List<Appointment__c> updatedAppointments = [SELECT Id, Booked__c, Availability__c, Capacity__c FROM Appointment__c WHERE Id IN :bookedAppointmentsSlots];
        for (Appointment__c updatedAppointment : updatedAppointments) {
            Assert.areEqual(1, updatedAppointment.Booked__c, 'Appointment should be marked as booked.');
            Assert.areEqual(updatedAppointment.Capacity__c - 1, updatedAppointment.Availability__c, 'Appointment should have ' + (updatedAppointment.Capacity__c - 1) + ' available slot.');
        }
    }

    @IsTest 
    static void testCancelVisit() {
        Appointment__c targetAppointment = [SELECT Id, Datetime__c FROM Appointment__c LIMIT 1];
        Contact targetDonor = [SELECT Id FROM Contact LIMIT 1];
        Center_Donation_Type__c targetCenterDonationType = [SELECT Id FROM Center_Donation_Type__c LIMIT 1];

        Visit__c testVisit = CoreSchedulerHandler.createVisit(new Visit__c(
            Appointment__c = targetAppointment.Id,
            Donor__c = targetDonor.Id,
            Center_Donation_Type__c = targetCenterDonationType.Id,
            Status__c = 'Scheduled'
        ));

        Test.startTest();
        CoreSchedulerHandler.cancelVisit(testVisit.Id);
        Test.stopTest();

        Visit__c canceledVisit = [SELECT Id, Status__c, Outcome__c FROM Visit__c WHERE Id = :testVisit.Id LIMIT 1];
        Assert.areEqual('Complete', canceledVisit.Status__c, 'Visit status should be marked as complete.');
        Assert.areEqual('Canceled', canceledVisit.Outcome__c, 'Visit outcome should be marked as canceled.');

        targetAppointment = [SELECT Id, Booked__c FROM Appointment__c WHERE Id = :testVisit.Appointment__c LIMIT 1];
        Assert.areEqual(0, targetAppointment.Booked__c, 'Appointment should be marked as not booked.');
    }

    @IsTest 
    static void testCancelVisits() {
        List<Appointment__c> targetAppointments = [SELECT Id, Datetime__c FROM Appointment__c];
        List<Contact> targetDonors = [SELECT Id FROM Contact];
        Center_Donation_Type__c targetCenterDonationType = [SELECT Id FROM Center_Donation_Type__c LIMIT 1];

        List<Visit__c> testVisits = new List<Visit__c>();
        Set<Id> bookedAppointmentsSlots = new Set<Id>();

        for (Integer i = 0; i < targetDonors.size(); i++) {
            testVisits.add(new Visit__c(
                Appointment__c = targetAppointments[i].Id,
                Donor__c = targetDonors[i].Id,
                Center_Donation_Type__c = targetCenterDonationType.Id,
                Status__c = 'Scheduled'
            ));

            bookedAppointmentsSlots.add(targetAppointments[i].Id);
        }

        CoreSchedulerHandler.createVisits(testVisits);

        List<Id> createdVisitIds = new List<Id>();
        for (Visit__c testVisit : testVisits) {
            createdVisitIds.add(testVisit.Id);
        }

        Test.startTest();
        CoreSchedulerHandler.cancelVisits(createdVisitIds);
        Test.stopTest();

        for(Visit__c testVisit : [SELECT Id, Status__c, Outcome__c FROM Visit__c WHERE Id IN :createdVisitIds]) {
            Assert.areEqual('Complete', testVisit.Status__c, 'Visit status should be marked as complete.');
            Assert.areEqual('Canceled', testVisit.Outcome__c, 'Visit outcome should be marked as canceled.');
        }

        for (Appointment__c updatedAppointment : [SELECT Id, Booked__c FROM Appointment__c WHERE Id IN :bookedAppointmentsSlots]) {
            Assert.areEqual(0, updatedAppointment.Booked__c, 'Appointment should be marked as booked.');
        }
    }

    @IsTest
    static void testGetSoonestNextRescheduleVisitDate() {
        // Contact targetDonor = [SELECT Id, Soonest_Next_Visit__c FROM Contact WHERE Soonest_Next_Visit__c != null LIMIT 1];
        // Datetime returnedSoonestNextVisitDate;

        // Test.startTest();
        // System.runAs(TestUtil.createAdminUser()) {
        //     returnedSoonestNextVisitDate = CoreSchedulerHandler.getSoonestNextRescheduleVisitDate(targetDonor.Id);
        // }
        // Test.stopTest();

        // Assert.areEqual(targetDonor.Soonest_Next_Visit__c, returnedSoonestNextVisitDate, 'The soonest next visit date should be returned');
    }
}