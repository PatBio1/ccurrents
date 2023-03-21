private static final String PROGRAM_ID = '04011223';
private static final String PROMOTION_ID = '1';
private static final String TRANSACTION_ID = '1A824434-3605-4CFE-B867-F581437F2947';
private static final String ACCESS_LEVEL = '1';

OnbeWsPrepaid.AccountManagementApiWebServices createActivateCardRequest = new OnbeWsPrepaid.AccountManagementApiWebServices();

OnbeResponsePrepaid.CreateAccountResponse createActivateCardResponse = new OnbeResponsePrepaid.CreateAccountResponse();

OnbeDomainPrepaid.Card newCard = new OnbeDomainPrepaid.Card();
newCard.cardAccessLevel = ACCESS_LEVEL;

OnbeDomainPrepaid.Load newLoad = new OnbeDomainPrepaid.Load();
newLoad.amount = 200;
newLoad.comment = 'Add funds';

OnbeDomainPrepaid.Link newLink = new OnbeDomainPrepaid.Link();
newLink.block = 'NONE';  // either ALL or NONE
newLink.cardPackageId = '80001';

OnbeDomainPrepaid.Registration newReg = new OnbeDomainPrepaid.Registration();
newReg.firstName = 'Foghorn';
newReg.lastName = 'Leghorn';
newReg.address1 = '965 Elms Common Drive';
newReg.city = 'Talulah';
newReg.state = 'MS';
newReg.postal = '42023';
newReg.country = 'US';
newReg.homePhone = '345-565-5656';

// NOTE: the first time you call this SOAP Service, you will probably get a NullPointerException 
//      The second time you call it, you won-t  ???
//      Class.OnbeWsPrepaid.AccountManagementApiWebServices.createAccount_Http: line 623, column 1

System.debug('createActivateCardRequest : ' + JSON.serializePretty(createActivateCardRequest));


createActivateCardResponse = createActivateCardRequest.createAccount_Http(PROGRAM_ID, 
    PROMOTION_ID, TRANSACTION_ID, '', ACCESS_LEVEL, true, newCard, newLoad, newLink, newReg);


System.debug('createActivateCardResponse : ' +  JSON.serializePretty(createActivateCardResponse));

