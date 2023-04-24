@isTest
public with sharing class DonationPaymentInvocableTest {

    @isTest
    static void testInvoke() {
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

            Donation_Type__c donationType = new Donation_Type__c();
            insert donationType;

            Center_Donation_Type__c centerDonationType = new Center_Donation_Type__c();
            centerDonationType.Center__c = center.Id;
            centerDonationType.Donation_Type__c = donationType.Id;
            centerDonationType.isActive__c = true;
            insert centerDonationType;

            Visit__c visit = new Visit__c();
            visit.Appointment__c = appointment.Id;
            visit.Donor__c = experienceUser.ContactId;
            visit.Status__c = 'Scheduled';
            visit.Center_Donation_Type__c = centerDonationType.Id;
            insert visit;

            DonationPaymentInvocable.DonationPaymentRequest donationPaymentRequest = new DonationPaymentInvocable.DonationPaymentRequest();
            donationPaymentRequest.donorId = experienceUser.ContactId;
            donationPaymentRequest.visitId = visit.Id;

            List<DonationPaymentInvocable.DonationPaymentResponse> donationPaymentResponses = DonationPaymentInvocable.invoke(new List<DonationPaymentInvocable.DonationPaymentRequest>{donationPaymentRequest});

            System.assertEquals(1, donationPaymentResponses.size());
            System.assertEquals(experienceUser.ContactId, donationPaymentResponses[0].donorId);
            System.assertEquals(visit.Id, donationPaymentResponses[0].visitId);
        }
    }

}