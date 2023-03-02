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

}