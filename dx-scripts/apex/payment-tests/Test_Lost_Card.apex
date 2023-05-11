String application_id = '3037c66b967c3d338751f95d2cdac566';
String puid = '003DE00002RgKDjYAN'; // Expects ContactId
String block_code = 'lost';

OnbeWsManageCard.AccountManagement onbeManageCardBaseObject = new OnbeWsManageCard.AccountManagement();
onbeManageCardBaseObject.reissueCard_Http(application_id, puid, block_code);

// Example XML Response - Waiting for Onbe to get back on why this is happening
/*
    <?xml version="1.0" encoding="UTF-8"?>
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <soapenv:Body>
            <ns1:reissueCardResponse xmlns:ns1="https://webservice-qa.northlane.com:4005/CardManagementV3/services/AccountManagement" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
                <reissueCardReturn href="#id0" />
            </ns1:reissueCardResponse>
            <multiRef xmlns:ns2="urn:AccountManagement" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" id="id0" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns2:ReissueResponse">
                <cardDetail xsi:type="ns2:CardDetail" xsi:nil="true" />
                <code href="#id1" />
                <message xsi:type="soapenc:string">Error fullfilling request.</message>
            </multiRef>
            <multiRef xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" id="id1" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="xsd:int">36099</multiRef>
        </soapenv:Body>
    </soapenv:Envelope>
*/

// We did get one successful response using a PUID they provided, ours still don't work
/*
    <?xml version="1.0" encoding="UTF-8"?>
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <soapenv:Body>
            <ns1:reissueCardResponse xmlns:ns1="https://webservice-qa.northlane.com:4005/CardManagementV3/services/AccountManagement" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
                <reissueCardReturn href="#id0" />
            </ns1:reissueCardResponse>
            <multiRef xmlns:ns2="urn:AccountManagement" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" id="id0" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns2:ReissueResponse">
                <cardDetail href="#id1" />
                <code href="#id2" />
                <message xsi:type="soapenc:string">Card successfully reissued.</message>
            </multiRef>
            <multiRef xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" id="id2" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="xsd:int">0</multiRef>
            <multiRef xmlns:ns3="urn:AccountManagement" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" id="id1" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns3:CardDetail">
                <account_status xsi:type="soapenc:string">active</account_status>
                <card_number xsi:type="soapenc:string">5445XXXXXXXX7590</card_number>
                <created_date xsi:type="xsd:dateTime">2023-05-09T18:02:45.003Z</created_date>
                <expiration xsi:type="soapenc:string">5/2025</expiration>
                <last_plastic_date xsi:type="xsd:dateTime">2023-05-09T18:02:45.517Z</last_plastic_date>
                <program_id href="#id3" />
                <puid xsi:type="soapenc:string">656adb9c-2cde-4cb6-bcd1-4c3450820281</puid>
                <ship_date xsi:type="xsd:dateTime">2023-05-09T18:02:45.868Z</ship_date>
            </multiRef>
            <multiRef xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" id="id3" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="xsd:int">0</multiRef>
        </soapenv:Body>
    </soapenv:Envelope>
*/