private static final String PROGRAM_ID;
private static final String PROMOTION_ID = '2';

Id donorContactId = '<Actual Donor Id>'; 

OnbeDomainPrepaid.Link newLink = new OnbeDomainPrepaid.Link();
newLink.block = 'ALL';
newLink.cardPackageId = '<Package Id>';

OnbeWsPrepaid.AccountManagementApiWebServices accountManagementAPI = new OnbeWsPrepaid.AccountManagementApiWebServices();
OnbeResponsePrepaid.LinkCardResponse linkCardResponse = accountManagementAPI.linkCard_Http(
    String.valueOf(donorContactId), PROGRAM_ID, PROMOTION_ID, String.valueOf(donorContactId) + '-' + String.valueOf(System.currentTimeMillis()), newLink
);

System.debug(linkCardResponse);