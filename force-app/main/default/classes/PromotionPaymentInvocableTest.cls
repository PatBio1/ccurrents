@isTest
public with sharing class PromotionPaymentInvocableTest {

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

            PromotionPaymentInvocable.PromotionPaymentRequest promotionPaymentRequest = new PromotionPaymentInvocable.PromotionPaymentRequest();
            promotionPaymentRequest.donorId = experienceUser.ContactId;
            promotionPaymentRequest.visitId = visit.Id;
            promotionPaymentRequest.amount = 100;

            List<PromotionPaymentInvocable.PromotionPaymentResponse> promotionPaymentResponses = PromotionPaymentInvocable.invoke(new List<PromotionPaymentInvocable.PromotionPaymentRequest>{promotionPaymentRequest});

            System.assertEquals(1, promotionPaymentResponses.size());
            System.assertEquals(experienceUser.ContactId, promotionPaymentResponses[0].donorId);
            System.assertEquals(visit.Id, promotionPaymentResponses[0].visitId);
            System.assertEquals(100, promotionPaymentResponses[0].amount);
        }
    }

}