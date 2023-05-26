ExceptionPaymentInvocable.ExceptionPaymentRequest request = new ExceptionPaymentInvocable.ExceptionPaymentRequest();
request.donorId = '0038H00000JSnFqQAL';
request.visitId = 'a0p8H000001ZEVtQAO';
request.amount = 500;
request.reason = 'Cause I want';

ExceptionPaymentInvocable.invoke(new List<ExceptionPaymentInvocable.ExceptionPaymentRequest> { request });