/**
 * Created by joshlequire1 on 2/28/23.
 */
@IsTest
public with sharing class LeadTriggerHandlerTest {
    @IsTest
    static void testConsentTransactionBehavior() {
        Test.startTest();
        Lead testLead = new Lead(FirstName = 'Test', LastName = 'Lead');
        insert testLead;

        List<Consent_Transaction__c> testConsents = new List<Consent_Transaction__c>{
            new Consent_Transaction__c(
                Lead__c = testLead.Id,
                Source__c = 'Agent',
                Type_of_Consent__c = 'Opt-in'
            ),
            new Consent_Transaction__c(
                Lead__c = testLead.Id,
                Source__c = 'Web Form',
                Type_of_Consent__c = 'Opt-out'
            )
        };

        insert testConsents;

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(testLead.Id);
        LeadStatus convertStatus = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted = TRUE LIMIT 1];
        lc.setConvertedStatus(convertStatus.MasterLabel);
        Database.LeadConvertResult lcr = Database.convertLead(lc);

        Test.stopTest();

        Lead convertedLead = [SELECT Id, ConvertedContactId FROM Lead WHERE IsConverted = TRUE][0];

        for (Consent_Transaction__c ct : [SELECT Id, Lead__c, Contact__c FROM Consent_Transaction__c WHERE Contact__c != NULL]) {
            Assert.areEqual(convertedLead.ConvertedContactId, ct.Contact__c);
        }

    }

    @IsTest
    static void testLegacyDataMigrationFix() {

        Lead testLead = new Lead (
            FirstName = 'Test',
            LastName = 'Two',
            isLegacyDonor__c = true,
            Date_Migrated__c = Date.newInstance(2023, 05, 05),
            Last_Donation_Date_Migrated__c = Date.newInstance(2023, 05, 01),
            Donations_Last_365_Days_Migrated__c = 20,
            First_Visit_Code__c = '123456'
        );

        insert testLead;

        Test.startTest();

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(testLead.Id);
        LeadStatus convertStatus = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted = TRUE LIMIT 1];
        lc.setConvertedStatus(convertStatus.MasterLabel);
        Database.LeadConvertResult lcr = Database.convertLead(lc);

        Test.stopTest();

        Lead convertedLead = [
            SELECT Id,
                ConvertedAccountId
            FROM Lead
            WHERE IsConverted = TRUE
        ][0];

        Account convertedAccount = [
            SELECT Id,
                isLegacyDonor__pc,
                Date_Migrated__pc,
                Last_Donation_Date_Migrated__pc,
                Donations_Last_365_Days_Migrated__pc,
                First_Visit_Code__c
            FROM Account
            WHERE Id = :convertedLead.ConvertedAccountId
        ][0];

        Assert.areEqual(testLead.isLegacyDonor__c, convertedAccount.isLegacyDonor__pc);
        Assert.areEqual(testLead.Date_Migrated__c, convertedAccount.Date_Migrated__pc);
        Assert.areEqual(testLead.Last_Donation_Date_Migrated__c, convertedAccount.Last_Donation_Date_Migrated__pc);
        Assert.areEqual(testLead.Donations_Last_365_Days_Migrated__c, convertedAccount.Donations_Last_365_Days_Migrated__pc);
        Assert.areEqual(testLead.First_Visit_Code__c, convertedAccount.First_Visit_Code__c);
    }
}