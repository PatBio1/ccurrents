global Interface PaymentServiceInterface {

    String getPaymentServiceName();
    String getPaymentServiceDescription();
    String setupPaymentServiceAccount(String cardPackageId, Id donorId, Decimal initialAccountLoad, String initialPIN, Boolean blockCards);
    Boolean linkPhysicalCard(String cardPackageId, Id donorId, String initialPIN, Boolean blockCards);
    String processPayment(String accountNumber, String comment, Long amount, String onbeTransactionId);
    Decimal getBalance(String donorId);
    String getTransaction();
    String getTransactionHistory();

}