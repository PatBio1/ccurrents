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

        Schedule__c schedule = ScheduleUtils.createScheduleRecord(center1.Id, startDate, endDate);
            insert schedule;
        //scheduleRange(Id centerId, Date startDate, Date endDate, Id loyaltyTier, Integer intervalsPerHour, Integer slotsPerInterval)
        appointments = ScheduleUtils.scheduleRange(center1.id,schedule.id,startDate,endDate,loyaltyTier,intervalsPerHour,slotsPerInterval);

        insert appointments;

        Test.stopTest();
        //2 days *
         
        // 2 days * 15 hours * 1
        system.assertEquals(120,appointments.size());
        system.assertEquals(slotsPerInterval, appointments[0].Capacity__c);
        
        
        //first appointment should be 9:00AM on first day
        DateTime firstTime = DateTime.newInstance(startDate, Time.newInstance(8, 0, 0, 0));
        system.assertEquals(firstTime, appointments[0].Datetime__c);

        //last appointment should be 8:50PM on last day
        DateTime lastTime = DateTime.newInstance(endDate, Time.newInstance(17, 50, 0, 0));
        system.assertEquals(lastTime, appointments[119].Datetime__c);
        
        system.assertEquals(slotsPerInterval, appointments[119].Capacity__c);
    }

    @isTest
    static void ScheduleUtilsError_Test() {
        Appointment__c[] appointments;
        Test.startTest();

        // create a set of appointment slots
        Date startDate =  Date.newInstance(2023, 1, 1);
        Date endDate = Date.newInstance(2023, 1, 31);
        Id loyaltyTier = null;
    

        Account center1 = [SELECT Id FROM Account WHERE Name = 'Center 1'];

        Schedule__c schedule = ScheduleUtils.createScheduleRecord(center1.Id, startDate, endDate);
        insert schedule;
        //end date overlaps existing
        try{
            Date newStartDate =  Date.newInstance(2022, 12, 1);
            Date newEndDate = Date.newInstance(2023, 1, 15);
            ScheduleUtils.createScheduleRecord(center1.Id, newStartDate, newEndDate);
        }catch(ScheduleUtils.ScheduleException se){
            system.assertEquals('A Schedule exists for this center in this date range',se.getMessage());
        }
        //start date overlaps existing
        try{
            Date newStartDate =  Date.newInstance(2023, 1, 15);
            Date newEndDate = Date.newInstance(2023, 2, 15);
            ScheduleUtils.createScheduleRecord(center1.Id, newStartDate, newEndDate);
        }catch(ScheduleUtils.ScheduleException se){
            system.assertEquals('A Schedule exists for this center in this date range',se.getMessage());
        }
        //new schedule totally encompasses another schedule
        try{
            Date newStartDate =  Date.newInstance(2022, 12, 1);
            Date newEndDate = Date.newInstance(2023, 3, 1);
            ScheduleUtils.createScheduleRecord(center1.Id, newStartDate, newEndDate);
        }catch(ScheduleUtils.ScheduleException se){
            system.assertEquals('A Schedule exists for this center in this date range',se.getMessage());
        }

        Date newStartDate =  Date.newInstance(2023, 2, 1);
        Date newEndDate = Date.newInstance(2023, 3, 1);
        Schedule__c sched = ScheduleUtils.createScheduleRecord(center1.Id, newStartDate, newEndDate);
       
    }

    @isTest
    static void testCreateFirstVisitCode(){
        String firstVisitCode = ScheduleUtils.createFirstVisitCode();
        system.assertEquals(7, firstVisitCode.length());
    }
}
