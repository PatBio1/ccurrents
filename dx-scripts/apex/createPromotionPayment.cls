PromotionPaymentInvocable.PromotionPaymentRequest request = new PromotionPaymentInvocable.PromotionPaymentRequest();
request.donorId = '0038H00000JSnFqQAL';
request.visitId = 'a0p8H000001ZEVtQAO';
request.amount = 500;
request.reason = 'Cause I\'m testing promo payments';

PromotionPaymentInvocable.invoke(new List<PromotionPaymentInvocable.PromotionPaymentRequest> { request });