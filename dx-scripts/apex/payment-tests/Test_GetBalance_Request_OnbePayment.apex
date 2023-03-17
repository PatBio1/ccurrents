
// values to set before running the Anon Apex SOAP callout test

// private static final String PROGRAM_ID = '04011223';
// private static final String PROMOTION_ID = '1';
// private static final String TRANSACTION_ID = '1A824434-3605-4CFE-B867-F581437F2947';
// private static final String ACCESS_LEVEL = '1';

// payoutAccountInquiry_Http(){
		// OnbeWsManageCardHttpCalloutMock());
		OnbeWsManageCard.AccountManagement getBalanceRequestObject = new OnbeWsManageCard.AccountManagement();
 
 OnbeCardAccountOperations.Response getBalanceResponseObject = new OnbeCardAccountOperations.Response();
 // OnbeCardAccountOperations.Response 
 //OnbeCardAccountOperations.AccountInquiry;	
//OnbeCardAccountOperations.PayoutAccountInquiry

        //testObject.accountInquiry_Http();
		//testObject.payoutAccountInquiry_Http();		





// NOTE: the first time you call this SOAP Service, you will probably get a NullPointerException 
//      The second time you call it, you won-t  ???
//Error: System.NullPointerException: Attempt to de-reference a null object
//Error: Class.OnbeWsPrepaid.AccountManagementApiWebServices.linkCard_Http: line 713, column 1

System.debug('createActivateCardRequest : ' + JSON.serializePretty(getBalanceRequestObject));

// This method is void
getBalanceRequestObject.accountInquiry_Http();


// What does the XML look like?
/**
String outputString = '"XMLNode[ELEMENT,Body,http://schemas.xmlsoap.org/soap/envelope/,null,null,[XMLNode[ELEMENT,Fault,http://schemas.xmlsoap.org/soap/envelope/,null,null,[XMLNode[ELEMENT,faultcode,null,null,null,[XMLNode[TEXT,null,null,null,null,null,soapenv:Server.generalException,]],null,], XMLNode[ELEMENT,faultstring,null,null,null,[XMLNode[TEXT,null,null,null,null,null,Tried to invoke method public com.ecount.one.cs.AccountInquiry com.ecount.one.cs.AccountManagementJaxRPC.accountInquiry(java.lang.String,java.lang.String,java.lang.String,java.lang.String,java.lang.String,int,int,int,int,int,int) throws java.rmi.RemoteException with arguments null,null,null,null,null,null,null,null,null,null,null.  The arguments do not match the signature.; nested exception is: \n\tjava.lang.IllegalArgumentException,]],null,], XMLNode[ELEMENT,detail,null,null,null,[XMLNode[ELEMENT,hostname,http://xml.apache.org/axis/,null,[common.apex.api.dom.XmlNode$NamespaceDef@254bd317],[XMLNode[TEXT,null,null,null,null,null,q-na-app01,]],null,]],null,]],null,]],null,]"|0x33dece78';


Dom.XmlNode theNode ; //= new Dom.XmlNode();
theNode.
theNode.addChildElement('Body', 'http://schemas.xmlsoap.org/soap/envelope/', '');
theNode.setAttribute('Fault', theNode.getAttribute('Fault', 'http://schemas.xmlsoap.org/soap/envelope/'));

System.debug('theNode contents: ' + theNode.getText());

// System.debug('doc.toXmlString(): ' + theNode.);

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



/*  some Debug Output

*/

