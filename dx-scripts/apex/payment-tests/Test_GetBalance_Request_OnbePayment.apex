
// Test Callout Method:  OnbeWsManageCard.AccountManagement.accountInquiry_Http(String application_id,
			// String card_number,
			// String puid,
		 	// String ppd, 
			// String mobile_phone,
			// Integer balance_detail, 
			// Integer journal_detail, 
			// Integer registration_detail, 
			// Integer start_date, 
			// Integer end_date,
			// Integer max_items)

// ## IF YOU WANT TO SEE THE DETAILED RESPONSE OUTPUT, TURN APEX DEBUG LOG LEVELS TO FINE OR FINEST!

// values to set before running the Anon Apex SOAP callout test

private static final String application_id = '1036853311';
private static final String card_number ='';
private static final String puid = '';
private static final String ppd = '';
private static final String mobile_phone = '2016321890';
private static final Integer balance_detail = 1;
private static final Integer journal_detail = 0;
private static final Integer registration_detail = 0;
private static final Integer start_date = 0;  // Don-t use start_date
private static final Integer end_date = 0;	// Don-t use end_date
private static final Integer max_items = 20;


	OnbeWsManageCard.AccountManagement onbeManageCardBaseObject = new OnbeWsManageCard.AccountManagement();
	
//OnbeCardAccountOperations.PayoutAccountInquiry
// payoutAccountInquiry_Http(){

// NOTE: the first time you call this SOAP Service, you <MAY>?? get a NullPointerException 
//      The second time you call it, you won-t  ???
//Error: System.NullPointerException: Attempt to de-reference a null object

System.debug('createActivateCardRequest : ' + JSON.serializePretty(onbeManageCardBaseObject));

// This method is void
onbeManageCardBaseObject.accountInquiry_Http( application_id, card_number, puid, ppd,
	mobile_phone, balance_detail, journal_detail, registration_detail, start_date, end_date, max_items);

// Notice how the Response body below includes a message node which says 'Invalid Application Identifier'

// What does the XML look like?
/**
VARIABLE_ASSIGNMENT|[149]|rootNode|"XMLNode[ELEMENT,Envelope,http://schemas.xmlsoap.org/soap/envelope/,null,[common.apex.api.dom.XmlNode$NamespaceDef@757dfc2a, common.apex.api.dom.XmlNode$NamespaceDef@6956c1ec, common.apex.api.dom.XmlNode$NamespaceDef@244c77a4],
[XMLNode[ELEMENT,Body,http://schemas.xmlsoap.org/soap/envelope/,null,null,
[XMLNode[ELEMENT,accountInquiryResponse,https://webservice-qa.northlane.com:4005/CardManagementV3/services/AccountManagement,[common.apex.api.dom.XmlNode$Attribute@7089d08d],[common.apex.api.dom.XmlNode$NamespaceDef@6a0ffe1a, common.apex.api.dom.XmlNode$NamespaceDef@35891b16],
[XMLNode[ELEMENT,accountInquiryReturn,null,[common.apex.api.dom.XmlNode$Attribute@723fbb54],null,null,null,]],null,], 
XMLNode[ELEMENT,multiRef,null,[common.apex.api.dom.XmlNode$Attribute@4c8c0026, common.apex.api.dom.XmlNode$Attribute@59e6c883, common.apex.api.dom.XmlNode$Attribute@24ca3902, common.apex.api.dom.XmlNode$Attribute@2ba0c3d4],[common.apex.api.dom.XmlNode$NamespaceDef@7816bb6, common.apex.api.dom.XmlNode$NamespaceDef@684c1915, common.apex.api.dom.XmlNode$NamespaceDef@1d3b3f37, common.apex.api.dom.XmlNode$NamespaceDef@3028e127],
[XMLNode[ELEMENT,balance,null,[common.apex.api.dom.XmlNode$Attribute@3cf8f04f, common.apex.api.dom.XmlNode$Attribute@3474d274],[common.apex.api.dom.XmlNode$NamespaceDef@7072814a, common.apex.api.dom.XmlNode$NamespaceDef@7a477ba],null,null,], 
XMLNode[ELEMENT,card,null,[common.apex.api.dom.XmlNode$Attribute@7ca59589, common.apex.api.dom.XmlNode$Attribute@6e501f1b],[common.apex.api.dom.XmlNode$NamespaceDef@accab4a, common.apex.api.dom.XmlNode$NamespaceDef@2e71140e],null,null,], 
XMLNode[ELEMENT,comments,null,[common.apex.api.dom.XmlNode$Attribute@7ea8d594, common.apex.api.dom.XmlNode$Attribute@106eb59d],[common.apex.api.dom.XmlNode$NamespaceDef@7f97da21, common.apex.api.dom.XmlNode$NamespaceDef@596060b9],null,null,], 
XMLNode[ELEMENT,journal,null,[common.apex.api.dom.XmlNode$Attribute@615c1a74, common.apex.api.dom.XmlNode$Attribute@4fb899f],[common.apex.api.dom.XmlNode$NamespaceDef@457c1df3, common.apex.api.dom.XmlNode$NamespaceDef@1f43c84d],null,null,], 
XMLNode[ELEMENT,registration,null,[common.apex.api.dom.XmlNode$Attribute@1e4dee6b, common.apex.api.dom.XmlNode$Attribute@46222b4c],[common.apex.api.dom.XmlNode$NamespaceDef@639425fe, common.apex.api.dom.XmlNode$NamespaceDef@62149861],null,null,], 
XMLNode[ELEMENT,response,null,[common.apex.api.dom.XmlNode$Attribute@135b1cfe],null,null,null,]],null,], 
XMLNode[ELEMENT,multiRef,null,[common.apex.api.dom.XmlNode$Attribute@44f42d92, common.apex.api.dom.XmlNode$Attribute@60d5b27, common.apex.api.dom.XmlNode$Attribute@401c0c17, common.apex.api.dom.XmlNode$Attribute@b6b5406],[common.apex.api.dom.XmlNode$NamespaceDef@6e966044, common.apex.api.dom.XmlNode$NamespaceDef@2aecad2, common.apex.api.dom.XmlNode$NamespaceDef@22720224, common.apex.api.dom.XmlNode$NamespaceDef@7368b908],
[XMLNode[ELEMENT,code,null,[common.apex.api.dom.XmlNode$Attribute@2ea16361],null,null,null,], 
XMLNode[ELEMENT,message,null,[common.apex.api.dom.XmlNode$Attribute@5a2dc43d],[common.apex.api.dom.XmlNode$NamespaceDef@687c8e7e, common.apex.api.dom.XmlNode$NamespaceDef@5eeada80],
[XMLNode[TEXT,null,null,null,null,null,Invalid Application Identifier,]],null,]],null,], 
XMLNode[ELEMENT,multiRef,null,[common.apex.api.dom.XmlNode$Attribute@7b750057, common.apex.api.dom.XmlNode$Attribute@4f4d2f28, common.apex.api.dom.XmlNode$Attribute@43ce57c1, common.apex.api.dom.XmlNode$Attribute@4bf8abe2],[common.apex.api.dom.XmlNode$NamespaceDef@185c7d72, common.apex.api.dom.XmlNode$NamespaceDef@3e4e253e, common.apex.api.dom.XmlNode$NamespaceDef@f8f0d69, common.apex.api.dom.XmlNode$NamespaceDef@12600c1],
[XMLNode[TEXT,null,null,null,null,null,34001,]],null,]],null,]],null,]"|0x7a6a4a7a

*/

//XmlStreamReader xmlReader = new XmlStreamReader();
//xmlReader.
//doc.load(theNode.);

// System.debug('doc.toXmlString(): ' + doc.toXmlString());

//XmlStreamWriter xmlWriter = new XmlStreamWriter();
//xmlWriter.(outputString);


//XmlStreamReader xmlReader = new XmlStreamReader();
//xmlReader.
//xmlReader.getAttributeCount()
