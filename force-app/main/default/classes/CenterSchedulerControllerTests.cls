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

    @IsTest
    public static void testGetCenters(){
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User']; 
        User contextuser = new User(Alias = 'standt', Email='phantomTestUser@testorg.com', 
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='phantomTestUser@testorg.com');
        Insert contextuser;
        PermissionSet ps = [Select ID from PermissionSet WHERE Name = 'ProesisAdministratorSalesforceLicense'];
        PermissionSetAssignment psa = 
            new PermissionSetAssignment(
                PermissionSetId = ps.id, 
                AssigneeId = contextuser.id
            );
        insert psa;

        CenterScheduleController.Center[] centers = new CenterScheduleController.Center[]{};
        Test.startTest();
        System.runAs(contextuser){
            centers = CenterScheduleController.getCenters();
        }
        Test.stopTest();
        system.assertEquals(3, centers.size());
    }

    @IsTest
    public static void testGetAppointments(){
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User']; 
        User contextuser = new User(Alias = 'standt', Email='phantomTestUser@testorg.com', 
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='phantomTestUser@testorg.com');
        Insert contextuser;
        PermissionSet ps = [Select ID from PermissionSet WHERE Name = 'ProesisAdministratorSalesforceLicense'];
        PermissionSetAssignment psa = 
            new PermissionSetAssignment(
                PermissionSetId = ps.id, 
                AssigneeId = contextuser.id
            );
        insert psa;

        CenterScheduleController.AppointmentSlot[] slots = new CenterScheduleController.AppointmentSlot[]{};
        Id centerId = [SELECT Id FROM Account WHERE NAME = 'Center 1'].Id;
        Test.startTest();
        System.runAs(contextuser){
            slots = CenterScheduleController.getAppointments(centerId,Date.today());
        }
        Test.stopTest();
        system.assertEquals(0, slots.size());
    }


}