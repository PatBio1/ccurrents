@isTest
public with sharing class AppointmentTriggerHandlerTest {

    @isTest
    static void testSetCenterDateAndTime() {
        User experienceUser = TestUtil.createExperienceUser();

        System.runAs(TestUtil.createAdminUser()) {
            Account center = TestUtil.createMiramarCenter();
            insert center;

            Schedule__c schedule = new Schedule__c(
                Center__c = center.Id,
                Begin_Date__c = Date.newInstance(2023, 1, 10).addDays(-10),
                End_Date__c = Date.newInstance(2023, 1, 10).addDays(30)
            );
            insert schedule;

            Appointment__c appointment = new Appointment__c();
            appointment.Schedule__c = schedule.Id;
            appointment.Datetime__c = DateTime.newInstance(2023, 1, 10, 10, 0, 0);
            appointment.Duration__c = 10;
            appointment.Capacity__c = 5;
            insert appointment;

            Appointment__c updatedAppointment = [SELECT Date_Center__c, Time_Center__c FROM Appointment__c WHERE Id = :appointment.Id];

            System.assertEquals(Util.getTimeZoneDate(appointment.Datetime__c, experienceUser.TimeZoneSidKey), updatedAppointment.Date_Center__c);
            System.assertEquals(Util.getTimeZoneTime(appointment.Datetime__c, experienceUser.TimeZoneSidKey), updatedAppointment.Time_Center__c);
        }
    }

}