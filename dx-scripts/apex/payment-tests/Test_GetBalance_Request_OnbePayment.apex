private static final String application_id = '3037c66b967c3d338751f95d2cdac566';
private static final String card_number ='';
private static final String puid = '003DE00002Rgi2TYAR';
private static final String ppd = ''; // We are unsure of what this property is, we asked Onbe but they couldn't provide an answer. Leave blank for now.
private static final String mobile_phone = '';
private static final Integer balance_detail = 1;
private static final Integer journal_detail = 0;
private static final Integer registration_detail = 0;
private static final Integer start_date = 0;
private static final Integer end_date = 0;
private static final Integer max_items = 20;

OnbeWsManageCard.AccountManagement onbeManageCardBaseObject = new OnbeWsManageCard.AccountManagement();
OnbeWsManageCard.AccountInquiryResponse accountInquiryResponse = onbeManageCardBaseObject.accountInquiry_Http(
	application_id, card_number, puid, ppd,
	mobile_phone, balance_detail, journal_detail, registration_detail, 
	start_date, end_date, max_items
);

System.debug(accountInquiryResponse);

// What does the XML look like?
// The balance properties don't actually return anything, the balance should be pulled from the multiRef with the id of id6
/*
	<?xml version="1.0" encoding="UTF-8"?>
	<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
		<soapenv:Body>
			<ns1:accountInquiryResponse xmlns:ns1="https://webservice-qa.northlane.com:4005/CardManagementV3/services/AccountManagement" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
				<accountInquiryReturn href="#id0" />
			</ns1:accountInquiryResponse>
			<multiRef xmlns:ns2="urn:AccountManagement" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" id="id0" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns2:AccountInquiry">
				<balance href="#id1" />
				<card href="#id2" />
				<comments soapenc:arrayType="ns2:CommentHistory[0]" xsi:type="soapenc:Array" />
				<journal xsi:type="soapenc:Array" xsi:nil="true" />
				<registration href="#id3" />
				<response href="#id4" />
			</multiRef>
			<multiRef xmlns:ns3="urn:AccountManagement" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" id="id1" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns3:Balance">
				<balance_available href="#id5" />
				<balance_date xsi:type="xsd:dateTime">2023-05-09T17:05:35.832Z</balance_date>
				<balance_ledger href="#id6" />
				<balance_pending href="#id7" />
			</multiRef>
			<multiRef xmlns:ns4="urn:AccountManagement" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" id="id3" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns4:Registration">
				<address_1 xsi:type="soapenc:string" xsi:nil="true" />
				<address_2 xsi:type="soapenc:string" xsi:nil="true" />
				<business_phone xsi:type="soapenc:string" xsi:nil="true" />
				<city xsi:type="soapenc:string" xsi:nil="true" />
				<email xsi:type="soapenc:string" />
				<first_name xsi:type="soapenc:string">Andonis</first_name>
				<home_phone xsi:type="soapenc:string" xsi:nil="true" />
				<last_name xsi:type="soapenc:string">Order</last_name>
				<mobile_phone xsi:type="soapenc:string" xsi:nil="true" />
				<state xsi:type="soapenc:string" xsi:nil="true" />
				<zip xsi:type="soapenc:string" xsi:nil="true" />
			</multiRef>
			<multiRef xmlns:ns5="urn:AccountManagement" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" id="id4" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns5:Response">
				<code href="#id8" />
				<message xsi:type="soapenc:string">OK</message>
			</multiRef>
			<multiRef xmlns:ns6="urn:AccountManagement" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" id="id2" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns6:CardDetail">
				<account_status xsi:type="soapenc:string">active</account_status>
				<card_number xsi:type="soapenc:string">5445XXXXXXXX9243</card_number>
				<created_date xsi:type="xsd:dateTime">2023-05-08T15:31:17.083Z</created_date>
				<expiration xsi:type="soapenc:string">4/2026</expiration>
				<last_plastic_date xsi:type="xsd:dateTime">2023-04-06T18:53:39.590Z</last_plastic_date>
				<program_id href="#id9" />
				<puid xsi:type="soapenc:string">003DE00002RgKDOYA3</puid>
				<ship_date xsi:type="xsd:dateTime" xsi:nil="true" />
			</multiRef>
			<multiRef xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" id="id6" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="xsd:int">5000</multiRef>
			<multiRef xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" id="id9" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="xsd:int">1223</multiRef>
			<multiRef xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" id="id8" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="xsd:int">0</multiRef>
			<multiRef xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" id="id7" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="xsd:int">0</multiRef>
			<multiRef xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" id="id5" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="xsd:int">5000</multiRef>
		</soapenv:Body>
	</soapenv:Envelope>
*/