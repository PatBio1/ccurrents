final String PROGRAM_ID = '04011223';
final String PROMOTION_ID = '2';

String accountNumber = '0401122300000040';
String newPIN = '5237';

OnbeWsPrepaid.AccountManagementApiWebServices accountManagementAPI = new OnbeWsPrepaid.AccountManagementApiWebServices();
OnbeResponsePrepaid.SetPinResponse setPinResponse = accountManagementAPI.setPin_Http(
    PROGRAM_ID, PROMOTION_ID, accountNumber, accountNumber + '-' + String.valueOf(System.currentTimeMillis()), newPIN
);

System.debug(setPinResponse);