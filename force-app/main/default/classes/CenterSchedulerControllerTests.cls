@IsTest
public with sharing class CenterSchedulerControllerTests {

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

        Date startDate =  Date.newInstance(2023, 1, 10).addDays(-10);
        Date endDate =  Date.newInstance(2023, 1, 10).addDays(30);
        Id loyaltyTier = null;
        Integer intervalsPerHour = 6; //10 minutes apart
        Integer slotsPerInterval = 1;

        Account center1 = [SELECT Id FROM Account WHERE Name = 'Proesis Miramar'];

        Appointment__c[] appointments = ScheduleUtils.scheduleRange(center1.id,startDate,endDate,loyaltyTier,intervalsPerHour,slotsPerInterval);

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
        system.assertEquals(3, centers.size());
    }

    @IsTest
    public static void testGetAppointments(){
        User contextuser = TestUtil.createAdminUser();
        System.runAs(contextuser){
            Account center = [Select ID FROM Account WHERE Name ='Proesis Miramar' ];

            Schedule__c schedule = new Schedule__c(
                Center__c = center.Id,
                Begin_Date__c = Date.newInstance(2023, 1, 10).addDays(-10),
                End_Date__c = Date.newInstance(2023, 1, 10).addDays(30)
            );
            insert schedule;
            Appointment__c[] appointments = new Appointment__c[]{
                new Appointment__c(
                        Schedule__c = schedule.Id,
                    Datetime__c = DateTime.newInstance(2023, 1, 10, 10, 0, 0),
                    Duration__c = 10,
                    Capacity__c = 5
                ),
                new Appointment__c(
                        Schedule__c = schedule.Id,
                    Datetime__c = DateTime.newInstance(2023, 1, 10, 11, 0, 0),
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
            
                slots = CenterScheduleController.getAppointments(centerId,Date.newInstance(2023, 1, 10));
            
            Test.stopTest();
            system.assertEquals(91, slots.size());
        }
    }

    @IsTest
    public static void testChangeVisitAppointment(){
        user adminUser = TestUtil.createAdminUser();
        System.runAs(adminUser) {
            Account center = [Select ID FROM Account WHERE Name ='Proesis Miramar' ];

            Schedule__c schedule = new Schedule__c(
                Center__c = center.Id,
                Begin_Date__c = Date.newInstance(2023, 1, 10).addDays(-10),
                End_Date__c = Date.newInstance(2023, 1, 10).addDays(30)
            );
            insert schedule;
            Appointment__c[] appointments = new Appointment__c[]{
                new Appointment__c(
                        Schedule__c = schedule.Id,
                    Datetime__c = DateTime.newInstance(2023, 1, 10, 10, 0, 0),
                    Duration__c = 10,
                    Capacity__c = 5
                ),
                new Appointment__c(
                        Schedule__c = schedule.Id,
                    Datetime__c = DateTime.newInstance(2023, 1, 10, 11, 0, 0),
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

            visit = [SELECT Id, Appointment__c FROM Visit__c limit 1];

            system.assertEquals(appointments[1].id, visit.Appointment__c);
        }




        
    }


}