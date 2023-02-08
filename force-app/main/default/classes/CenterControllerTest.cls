@isTest
public with sharing class CenterControllerTest {

    @isTest
    static void testGetCenters() {
        System.runAs(TestUtil.createAdminUser()) {
            insert new List<Account>{
                TestUtil.createMiramarCenter(),
                TestUtil.createDallasCenter()
            };
        }

        System.runAs(TestUtil.createExperienceUser()) {
            List<CenterController.Center> centers = CenterController.getCenters(Double.valueOf(33.7488), Double.valueOf(84.3877));

            System.assertEquals(2, centers.size());
        }
    }

    @isTest
    static void testGetCentersException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceUser()) {
            Boolean exceptionThrown = false;

            try {
                CenterController.getCenters(Double.valueOf(33.7488), Double.valueOf(84.3877));
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

    @isTest
    static void testGetCenter() {
        Account centerRecord;

        System.runAs(TestUtil.createAdminUser()) {
            centerRecord = TestUtil.createMiramarCenter();
            insert centerRecord;

            List<Business_Hours__c> businessHoursList = TestUtil.createBusinessHours(centerRecord.Id);
            insert businessHoursList;
        }

        System.runAs(TestUtil.createExperienceUser()) {
            CenterController.Center center = CenterController.getCenter(centerRecord.Id);

            System.assertEquals(centerRecord.Id, center.id);
            System.assertEquals(7, center.businessHoursList.size());
        }
    }

    @isTest
    static void testGetCenterException() {
        TestUtil.throwException = true;

        System.runAs(TestUtil.createExperienceUser()) {
            Boolean exceptionThrown = false;

            try {
                CenterController.getCenter(UserInfo.getUserId());
            } catch (Exception e) {
                exceptionThrown = true;
            }

            System.assert(exceptionThrown);
        }
    }

}