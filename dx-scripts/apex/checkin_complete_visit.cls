String targetDonor = 'UZD-3HH';
Datetime targetDatetime = Datetime.newInstance(2023, 6, 3, 17, 0, 0);

DonorCheckinInvocable.updateVisitStatus(new List<List<Donor_CheckIn__e>> {
    new List<Donor_CheckIn__e> {
        new Donor_CheckIn__e(
        	Donor_Number__c = targetDonor,
    		Timestamp__c = targetDatetime
        )
    }
});

DonorCompInvocable.handleDonorCompEvent(new List<List<Donor_Comp__e>> {
    new List<Donor_Comp__e> {
        new Donor_Comp__e(
        	Donor_Number__c = targetDonor,
    		hasException__c = 0,
    		Collection_Number__c = 'c1234567890',
    		Collection_Volume__c = 1233,
    		BECS_Device__c = '123456789',
    		Timestamp__c = targetDatetime
        )
    }
});