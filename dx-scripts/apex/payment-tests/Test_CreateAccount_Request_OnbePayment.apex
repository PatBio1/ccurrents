String cardPackageId = '1084';
Id donorId = '003Dn00000NtJTHIA3';

OnbePaymentService paymentService = new OnbePaymentService();
paymentService.setupPaymentServiceAccount(cardPackageId, donorId, 0, '7899');