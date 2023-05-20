global Interface PaymentServiceInterface {

    String getPaymentServiceName();
    String getPaymentServiceDescription();
    String setupPaymentServiceAccount(String cardPackageId, Id donorId, Decimal initialAccountLoad, String initialPIN);
    void linkPhysicalCard(String cardPackageId, Id donorId, String initialPIN);
    String processPayment(String accountNumber, String comment, Long amount);
    Decimal getBalance(String donorId);
    String getTransaction();
    String getTransactionHistory();

}