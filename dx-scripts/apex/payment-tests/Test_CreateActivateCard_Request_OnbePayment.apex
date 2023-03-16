

//  CREATEACTIVATECARD


OnbeWsPrepaid.AccountManagementApiWebServices createActivateCardRequest = new OnbeWsPrepaid.AccountManagementApiWebServices();

OnbeResponsePrepaid.CreateAccountResponse createActivateCardResponse = new OnbeResponsePrepaid.CreateAccountResponse();


OnbeDomainPrepaid.Card newCard = new OnbeDomainPrepaid.Card();
newCard.cardAccessLevel = 'FullAccess';

OnbeDomainPrepaid.Load newLoad = new OnbeDomainPrepaid.Load();
newLoad.amount = 200;

OnbeDomainPrepaid.Link newLink = new OnbeDomainPrepaid.Link();
newLink.block = 'testBlock';

OnbeDomainPrepaid.Registration newReg = new OnbeDomainPrepaid.Registration();
newReg.lastName = 'Leghorn';


System.debug('createActivateCardRequest : ' + JSON.serializePretty(createActivateCardRequest));



createActivateCardResponse = createActivateCardRequest.createAccount(newCard.cardAccessLevel, true, newCard, newLoad, newLink, newReg);


/**

AsyncOnbeWsPrepaid.AsyncAccountManagementApiWebServices createActivateCard = new AsyncOnbeWsPrepaid.AsyncAccountManagementApiWebServices();

public System.Continuation cont = new Continuation(1);

AsyncOnbeResponsePrepaid.ActivationCardResponseFuture createActivateCardResponse = new AsyncOnbeResponsePrepaid.ActivationCardResponseFuture();

createActivateCardResponse = createActivateCard.beginActivateCard(cont, '10000000009', '000', '20017', '610427493452');

System.debug('createActivateCardRequest: ' + JSON.serializePretty(createActivateCardResponse));


// do we have a callback method for the continuation callout??




//String ContinuationLabel = JSON.serialize(createActivateCardResponse).split(':')[1];

//HttpResponse continuationResponse = New HttpResponse();
//continuationResponse = System.Continuation.getResponse(createActivateCardResponse.);

// System.debug('createActivateCardResponse: ' + JSON.serializePretty(continuationResponse));

//createActivateCard.beginActivateCard(cont, '10000000009', '000', '20017', '610427493452')));

*/
