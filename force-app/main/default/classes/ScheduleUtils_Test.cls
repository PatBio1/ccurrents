@isTest
public with sharing class ScheduleUtils_Test {
    
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
            new Account(
                Name = 'Center 1',
                RecordTypeID = centerRecordTypeID,
                ShippingStreet = '111 1st St',
                CenterId__c = 'center-111'
            ),
            new Account(
                Name = 'Center 2',
                RecordTypeID = centerRecordTypeID,
                ShippingStreet = '222 @nd St',
                CenterId__c = 'center-222'
            ),
            new Account(
                Name = 'Center 3',
                RecordTypeID = centerRecordTypeID,
                ShippingStreet = '333 3rd St',
                CenterId__c = 'center-333'
            )
        };

        upsert centers CenterId__c;

        Schedule__c[] schedules = new Schedule__c[]{
            new Schedule__c(
                Center__c = centers[0].Id, 
                Begin_Date__c =  Date.newInstance(2023, 1, 10).addDays(-10),
                End_Date__c =  Date.newInstance(2023, 1, 10).addDays(30)
            ),
            new Schedule__c(
                Center__c = centers[1].Id,
                Begin_Date__c =  Date.newInstance(2023, 1, 10).addDays(-10),
                End_Date__c =  Date.newInstance(2023, 1, 10).addDays(30)
            ),
            new Schedule__c(
                Center__c = centers[2].Id,
                Begin_Date__c =  Date.newInstance(2023, 1, 10).addDays(-10),
                End_Date__c =  Date.newInstance(2023, 1, 10).addDays(30)
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
        Date endDate = Date.newInstance(2023, 1, 11);
        Id loyaltyTier = null;
        Integer intervalsPerHour = 6; //10 minutes apart
        Integer slotsPerInterval = 5;

        Account center1 = [SELECT Id FROM Account WHERE Name = 'Center 1'];

        //scheduleRange(Id centerId, Date startDate, Date endDate, Id loyaltyTier, Integer intervalsPerHour, Integer slotsPerInterval)
        appointments = ScheduleUtils.scheduleRange(center1.id,startDate,endDate,loyaltyTier,intervalsPerHour,slotsPerInterval);

        insert appointments;

        Test.stopTest();
        //2 days *
         
        // 2 days * 15 hours * 1
        system.assertEquals(180,appointments.size());
        system.assertEquals(slotsPerInterval, appointments[0].Capacity__c);
        
        
        //first appointment should be 9:00AM on first day
        DateTime firstTime = DateTime.newInstance(startDate, Time.newInstance(6, 0, 0, 0));
        system.assertEquals(firstTime, appointments[0].Datetime__c);

        //last appointment should be 8:50PM on last day
        DateTime lastTime = DateTime.newInstance(endDate, Time.newInstance(20, 50, 0, 0));
        system.assertEquals(lastTime, appointments[179].Datetime__c);
        
        system.assertEquals(slotsPerInterval, appointments[179].Capacity__c);
    }
}
