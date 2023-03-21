
// Test Callout Method:  OnbeWsPrepaid.AccountManagementApiWebServices.linkCard_Http(OnbeDomainPrepaid.Link)

// ## IF YOU WANT TO SEE THE DETAILED RESPONSE OUTPUT, TURN APEX DEBUG LOG LEVELS TO FINE OR FINEST!

OnbeWsPrepaid.AccountManagementApiWebServices createActivateCardRequest = new OnbeWsPrepaid.AccountManagementApiWebServices();


OnbeDomainPrepaid.Link newLink = new OnbeDomainPrepaid.Link();
newLink.block = 'NONE';  // either ALL or NONE
newLink.cardPackageId = '80001';


// NOTE: the first time you call this SOAP Service, you may get a NullPointerException 
//      The second time you call it, you won-t  ???
//Error: System.NullPointerException: Attempt to de-reference a null object
//Error: Class.OnbeWsPrepaid.AccountManagementApiWebServices.linkCard_Http: line 713, column 1

System.debug('createActivateCardRequest : ' + JSON.serializePretty(createActivateCardRequest));

// This method is void
createActivateCardRequest.linkCard_Http(newLink);



/*  some Debug Output - the above request returned an HTTP 200.  Howerver, notice that the output contains the message: 'Missing program id'
ARIABLE_ASSIGNMENT|[712]|bodyNode|"XMLNode[ELEMENT,Body,http://schemas.xmlsoap.org/soap/envelope/,null,null,
[XMLNode[ELEMENT,linkCardReturn, http://ws.accountmanagementapi.prepaid.citi.com,null,[common.apex.api.dom.XmlNode$NamespaceDef@3ce81431],
[XMLNode[ELEMENT,code,http://response.accountmanagementapi.prepaid.citi.com,null,[common.apex.api.dom.XmlNode$NamespaceDef@2c15ab27],
[XMLNode[TEXT,null,null,null,null,null,1,]],null,], 
XMLNode[ELEMENT,description,http://response.accountmanagementapi.prepaid.citi.com,null,[common.apex.api.dom.XmlNode$NamespaceDef@56cc9f21],
[XMLNode[TEXT,null,null,null,null,null,Missing program id,]],null,], 
XMLNode[ELEMENT,existingTransaction,http://response.accountmanagementapi.prepaid.citi.com,null,[common.apex.api.dom.XmlNode$NamespaceDef@12fba24f],
[XMLNode[TEXT,null,null,null,null,null,false,]],null,], 
XMLNode[ELEMENT,keyValue,http://response.accountmanagementapi.prepaid.citi.com,[common.apex.api.dom.XmlNode$Attribute@6ece75bd],[common.apex.api.dom.XmlNode$NamespaceDef@6f83a7d0, common.apex.api.dom.XmlNode$NamespaceDef@5d840896],null,null,], 
XMLNode[ELEMENT,sub_code,http://response.accountmanagementapi.prepaid.citi.com,null,[common.apex.api.dom.XmlNode$NamespaceDef@12a230b3],[XMLNode[TEXT,null,null,null,null,null,MISSING_PROGRAM_ID,]],null,]],null,]],null,]"|0x7d1357cb
SYSTEM_METHOD_EXIT|[713]|dom.XmlNode.getChildElement(String, String)

VARIABLE_ASSIGNMENT|[713]|linkCardReturnNode|"XMLNode[ELEMENT,linkCardReturn,http://ws.accountmanagementapi.prepaid.citi.com,null,[common.apex.api.dom.XmlNode$NamespaceDef@3ce81431],
[XMLNode[ELEMENT,code,http://response.accountmanagementapi.prepaid.citi.com,null,[common.apex.api.dom.XmlNode$NamespaceDef@2c15ab27],
[XMLNode[TEXT,null,null,null,null,null,1,]],null,], 
XMLNode[ELEMENT,description,http://response.accountmanagementapi.prepaid.citi.com,null,[common.apex.api.dom.XmlNode$NamespaceDef@56cc9f21],
[XMLNode[TEXT,null,null,null,null,null,Missing program id,]],null,], 
XMLNode[ELEMENT,existingTransaction,http://response.accountmanagementapi.prepaid.citi.com,null,[common.apex.api.dom.XmlNode$NamespaceDef@12fba24f],
[XMLNode[TEXT,null,null,null,null,null,false,]],null,], 
XMLNode[ELEMENT,keyValue,http://response.accountmanagementapi.prepaid.citi.com,[common.apex.api.dom.XmlNode$Attribute@6ece75bd],[common.apex.api.dom.XmlNode$NamespaceDef@6f83a7d0, common.apex.api.dom.XmlNode$NamespaceDef@5d840896],null,null,], 
XMLNode[ELEMENT,sub_code,http://response.accountmanagementapi.prepaid.citi.com,null,[common.apex.api.dom.XmlNode$NamespaceDef@12a230b3],
[XMLNode[TEXT,null,null,null,null,null,MISSING_PROGRAM_ID,]],null,]],null,]"|0x30aaf49


*/

