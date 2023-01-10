@isTest
public with sharing class ScheduleUtils_Test {
    
    @TestSetup
    static void makeData(){
        Id centerRecordTypeID =  Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Center').getRecordTypeId();
        Id personAccountRecordTypeId =  Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();

        system.debug('centerRecordTypeID' + centerRecordTypeID);
        system.debug('personAccountRecordTypeId' + personAccountRecordTypeId);


        // Create Donors
        Account[] donors = new Account[]{
            new Account(
                FirstName = 'Danny',
                LastName = 'Donor',
                RecordTypeID = personAccountRecordTypeId,
                ExternalID__c = 'donor-12345'
            ),
            new Account(
                FirstName = 'Betty',
                LastName = 'Bleeder',
                RecordTypeID = personAccountRecordTypeId,
                ExternalID__c = 'donor-67890'
            )
        };

        upsert donors ExternalID__c;

        //Create Donation Centers
        Account[] centers = new Account[]{
            new Account(
                Name = 'Center 1',
                RecordTypeID = centerRecordTypeID,
                ShippingStreet = '111 1st St',
                ExternalID__c = 'center-111'
            ),
            new Account(
                Name = 'Center 2',
                RecordTypeID = centerRecordTypeID,
                ShippingStreet = '222 @nd St',
                ExternalID__c = 'center-222'
            ),
            new Account(
                Name = 'Center 3',
                RecordTypeID = centerRecordTypeID,
                ShippingStreet = '333 3rd St',
                ExternalID__c = 'center-333'
            )
        };

        upsert centers ExternalID__c; 


        Schedule__c[] schedules = new Schedule__c[]{
            new Schedule__c(
                Center__c = centers[0].Id, 
                Begin_Date__c = Date.today().addDays(-10),
                End_Date__c = Date.today().addDays(30)
            ),
            new Schedule__c(
                Center__c = centers[1].Id,
                Begin_Date__c = Date.today().addDays(-10),
                End_Date__c = Date.today().addDays(30)
            ),
            new Schedule__c(
                Center__c = centers[2].Id,
                Begin_Date__c = Date.today().addDays(-10),
                End_Date__c = Date.today().addDays(30)
            )
        };

        insert schedules;
    }
    
    
    @isTest
    static void ScheduleUtils_Test() {

        Appointment__c[] appointments;
        Test.startTest();

        // create a set of appointment slots
        Date startDate =  Date.newInstance(2023, 1, 10);
        Date endDate = startDate.addDays(30);
        Id loyaltyTier = null;
        Integer intervalsPerHour = 6; //10 minutes apart
        Integer slotsPerInterval = 1;

        Account center1 = [SELECT Id FROM Account WHERE Name = 'Center 1'];

        //scheduleRange(Id centerId, Date startDate, Date endDate, Id loyaltyTier, Integer intervalsPerHour, Integer slotsPerInterval)
        appointments = ScheduleUtils.scheduleRange(center1.id,startDate,endDate,loyaltyTier,intervalsPerHour,slotsPerInterval);

        insert appointments;

        Test.stopTest();
        system.assertEquals(1980,appointments.size());
    }
}
