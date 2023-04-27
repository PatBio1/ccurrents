public with sharing class OnbePaymentService implements PaymentServiceInterface {
    
    private static final String PROGRAM_ID = '04011223';
    private static final String PARTNER_USER_ID = '0012';
    private static final String PROMOTION_ID = '2';
    private static final String ACCESS_LEVEL = '01';

    public OnbePaymentService() {

    }

    public String getPaymentServiceName() {
        return 'Onbe';
    }

    public String getPaymentServiceDescription() {
        return 'Onbe Payment Service supports stored value card transfers.';
    }

    public String setupPaymentServiceAccount(String cardPackageId, Id donorId) {
        OnbeDomainPrepaid.Card newCard = new OnbeDomainPrepaid.Card();
        newCard.cardAccessLevel = ACCESS_LEVEL;

        OnbeDomainPrepaid.Load newLoad = new OnbeDomainPrepaid.Load();
        newLoad.amount = 200;
        newLoad.comment = 'Add funds';

        OnbeDomainPrepaid.Link newLink = new OnbeDomainPrepaid.Link();
        newLink.block = 'NONE';  // either ALL or NONE
        newLink.cardPackageId = cardPackageId;

        OnbeDomainPrepaid.Registration newReg = new OnbeDomainPrepaid.Registration();
        newReg.firstName = 'Timothy';
        newReg.lastName = 'Youngblood';
        newReg.address1 = '319 Massey Ln';
        newReg.city = 'Lookout Mountain';
        newReg.state = 'GA';
        newReg.postal = '30750';
        newReg.country = 'US';
        newReg.homePhone = '423-580-4176';

        OnbeWsPrepaid.AccountManagementApiWebServices createActivateCardRequest = new OnbeWsPrepaid.AccountManagementApiWebServices();
        OnbeResponsePrepaid.CreateAccountResponse createActivateCardResponse = createActivateCardRequest.createAccount_Http(
            PROGRAM_ID, PROMOTION_ID, donorId, PARTNER_USER_ID, ACCESS_LEVEL, true, newCard, newLoad, newLink, newReg
        );

        System.debug(createActivateCardResponse.code);
        System.debug(createActivateCardResponse.sub_code);
        return '';
    }

    public String linkPhysicalCard() {
        return 'success';
    }

    public String processPayment(Id donorId, Decimal amount) {
        return 'Onbe Pay';
    }
    
    public String getBalance() {
        return 'Onbe Balance';
    }

    public String getTransaction() {
        return 'Onbe Transaction';
    }

    public String getTransactionHistory() {
        return 'Onbe Transaction History';
    }

}