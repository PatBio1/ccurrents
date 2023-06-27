public without sharing class ProesisAddFundsRequest {
    public Id donorContactId;
    public Id visitId;
    public Id debitTransactionId;
    public String existingOnbeTransactionId;

    public List<AddFundsLineItem> lineItems;
    public String accountNumber;
    public String transactionSubType;
    public List<String> comments;
    public Decimal total;

    public Boolean isExceptionPayment;
    public Boolean isSuccessfullyProcessed;
    public String processResponse; // code - sub_code

    public ProesisAddFundsRequest(Id donorContactId, Id visitId, String accountNumber, String transactionSubType) {
        this(donorContactId, visitId, accountNumber, transactionSubType, null);
    }

    public ProesisAddFundsRequest(Id donorContactId, Id visitId, String accountNumber, String transactionSubType, Id debitTransactionId) {
        this.donorContactId = donorContactId;
        this.visitId = visitId;
        this.accountNumber = accountNumber;
        this.transactionSubType = transactionSubType;
        this.debitTransactionId = debitTransactionId;
        this.existingOnbeTransactionId = '';

        this.comments = new List<String>();
        this.lineItems = new List<AddFundsLineItem>();
        this.total = 0;
        this.isExceptionPayment = false;
    }

    public void setOnbeTransactionId(String transactionId) {
        this.existingOnbeTransactionId = transactionId;
    }

    public void recordAPIResponse(Boolean wasSuccessful, String response) {
        this.isSuccessfullyProcessed = wasSuccessful;
        this.processResponse = response;
    }

    public void addLineItem(String item, String type, Decimal amount) {
        this.lineItems.add(new AddFundsLineItem(item, type, amount));

        if (type == 'Currency') {
            this.total += amount;
        }
    }

    public class AddFundsLineItem {
        public String item;
        public String type;
        public Decimal amount;
        public Integer quantity;

        public AddFundsLineItem(String item, String type, Decimal amount) {
            this(item, type, amount, 1);
        }

        public AddFundsLineItem(String item, String type, Decimal amount, Integer quantity) {
            this.item = item;
            this.type = type;
            this.amount = amount;
            this.quantity = quantity;
        }
    }
}