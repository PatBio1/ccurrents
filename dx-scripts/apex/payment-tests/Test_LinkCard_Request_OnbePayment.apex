private static final String PROGRAM_ID = '04011223';
private static final String PROMOTION_ID = '1';
private static final String TRANSACTION_ID = '1A824434-3605-4CFE-B867-F581437F2947';
private static final String ACCESS_LEVEL = '1';

OnbeWsPrepaid.AccountManagementApiWebServices createActivateCardRequest = new OnbeWsPrepaid.AccountManagementApiWebServices();

//OnbeResponsePrepaid.CreateAccountResponse createActivateCardResponse = new OnbeResponsePrepaid.CreateAccountResponse();

OnbeDomainPrepaid.Card newCard = new OnbeDomainPrepaid.Card();
newCard.cardAccessLevel = ACCESS_LEVEL;

OnbeDomainPrepaid.Load newLoad = new OnbeDomainPrepaid.Load();
newLoad.amount = 200;
newLoad.comment = 'Add funds';

OnbeDomainPrepaid.Link newLink = new OnbeDomainPrepaid.Link();
newLink.block = 'NONE';  // either ALL or NONE
newLink.cardPackageId = '80001';


// NOTE: the first time you call this SOAP Service, you will probably get a NullPointerException 
//      The second time you call it, you won-t  ???
//Error: System.NullPointerException: Attempt to de-reference a null object
//Error: Class.OnbeWsPrepaid.AccountManagementApiWebServices.linkCard_Http: line 713, column 1

System.debug('createActivateCardRequest : ' + JSON.serializePretty(createActivateCardRequest));

// This method is void
createActivateCardRequest.linkCard_Http(newLink);

// PROGRAM_ID,  PROMOTION_ID, TRANSACTION_ID, '', ACCESS_LEVEL, true, newCard, newLoad, 

/*  some Debug Output
linkCardReturnNode|"XMLNode[ELEMENT,linkCardReturn,http://ws.accountmanagementapi.prepaid.citi.com,null,[common.apex.api.dom.XmlNode$NamespaceDef@26f822cd],
[XMLNode[ELEMENT,code,http://response.accountmanagementapi.prepaid.citi.com,null,[common.apex.api.dom.XmlNode$NamespaceDef@712af2eb],
[XMLNode[TEXT,null,null,null,null,null,1,]],null,], 
XMLNode[ELEMENT,description,http://response.accountmanagementapi.prepaid.citi.com,null,[common.apex.api.dom.XmlNode$NamespaceDef@1ac349c3],
[XMLNode[TEXT,null,null,null,null,null,Missing program id,]],null,], 
XMLNode[ELEMENT,existingTransaction,http://response.accountmanagementapi.prepaid.citi.com,null,[common.apex.api.dom.XmlNode$NamespaceDef@1fdc077],
[XMLNode[TEXT,null,null,null,null,null,false,]],null,], 
XMLNode[ELEMENT,keyValue,http://response.accountmanagementapi.prepaid.citi.com,[common.apex.api.dom.XmlNode$Attribute@667474cf],[common.apex.api.dom.XmlNode$NamespaceDef@40ef7f40, common.apex.api.dom.XmlNode$NamespaceDef@4062bbcf],null,null,], 
XMLNode[ELEMENT,sub_code,http://response.accountmanagementapi.prepaid.citi.com,null,[common.apex.api.dom.XmlNode$NamespaceDef@2ff325cc],
[XMLNode[TEXT,null,null,null,null,null,MISSING_PROGRAM_ID,]],null,]],null,]"|0x324864aa

*/

