private static final String PROGRAM_ID = '04011223';
private static final String PROMOTION_ID = '2';

Id donorContactId = '0038H00000JSno5QAD'; 

OnbeDomainPrepaid.Link newLink = new OnbeDomainPrepaid.Link();
newLink.block = 'ALL';
newLink.cardPackageId = '1093';

OnbeWsPrepaid.AccountManagementApiWebServices accountManagementAPI = new OnbeWsPrepaid.AccountManagementApiWebServices();
OnbeResponsePrepaid.LinkCardResponse linkCardResponse = accountManagementAPI.linkCard_Http(
    String.valueOf(donorContactId), PROGRAM_ID, PROMOTION_ID, String.valueOf(donorContactId) + '-' + String.valueOf(System.currentTimeMillis()), newLink
);

System.debug(linkCardResponse);

// Response
/*
    <?xml version="1.0" encoding="UTF-8"?>
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <soapenv:Body>
            <linkCardReturn xmlns="http://ws.accountmanagementapi.prepaid.citi.com">
                <ns1:code xmlns:ns1="http://response.accountmanagementapi.prepaid.citi.com">0</ns1:code>
                <ns2:description xmlns:ns2="http://response.accountmanagementapi.prepaid.citi.com">Processed Successfully</ns2:description>
                <ns3:existingTransaction xmlns:ns3="http://response.accountmanagementapi.prepaid.citi.com">false</ns3:existingTransaction>
                <ns4:keyValue xmlns:ns4="http://response.accountmanagementapi.prepaid.citi.com">
                    <item>
                        <ns5:key xmlns:ns5="http://common.accountmanagementapi.prepaid.citi.com">update-inventory</ns5:key>
                        <ns6:value xmlns:ns6="http://common.accountmanagementapi.prepaid.citi.com">processed</ns6:value>
                    </item>
                    <item>
                        <ns7:key xmlns:ns7="http://common.accountmanagementapi.prepaid.citi.com">link-card</ns7:key>
                        <ns8:value xmlns:ns8="http://common.accountmanagementapi.prepaid.citi.com">processed</ns8:value>
                    </item>
                </ns4:keyValue>
                <ns9:sub_code xmlns:ns9="http://response.accountmanagementapi.prepaid.citi.com">PROCESSED_SUCCESSFULLY</ns9:sub_code>
            </linkCardReturn>
        </soapenv:Body>
    </soapenv:Envelope>
*/