global Interface PaymentServiceInterface {

    String getPaymentServiceName();
    String getPaymentServiceDescription();
    String setupPaymentServiceAccount(String cardPackageId, Id donorId, Decimal initialAccountLoad, String initialPIN);
    String linkPhysicalCard();
    String processPayment(String accountNumber, String comment, Long amount);
    String getBalance();
    String getTransaction();
    String getTransactionHistory();

}