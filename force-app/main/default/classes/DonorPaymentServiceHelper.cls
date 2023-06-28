public without sharing class DonorPaymentServiceHelper {
    public static Map<String, Rate__c> getRatesByCenterDonationType() {
        Map<String, Rate__c> centerAndDonationTypeToRate = new Map<String, Rate__c>();

        for (Rate__c rate : [
            SELECT Id, Center__c, Donation_Type__c, Base_Payment__c
            FROM Rate__c
            WHERE Type__c = 'Base'
        ]) {
            centerAndDonationTypeToRate.put(rate.Center__c + '-' + rate.Donation_Type__c, rate);
        }

        return centerAndDonationTypeToRate;
    }

    public static Map<Decimal, List<Level__c>> getBonusLevelsByDonationThreshold() {
        Map<Decimal, List<Level__c>> donationThresholdToBonusLevels = new Map<Decimal, List<Level__c>>();

        for (Level__c bonusLevel : [SELECT Id, Name, Donation_Threshold__c, Threshold_Payment__c, Threshold_Points__c FROM Level__c WHERE isActive__c = true AND isVisible__c = false AND Donation_Threshold__c > 0]) {
            List<Level__c> thresholdBonusLevels = donationThresholdToBonusLevels.get(bonusLevel.Donation_Threshold__c);
            if (thresholdBonusLevels == null) {
                thresholdBonusLevels = new List<Level__c>();
            }

            thresholdBonusLevels.add(bonusLevel);
            donationThresholdToBonusLevels.put(bonusLevel.Donation_Threshold__c, thresholdBonusLevels);
        }

        return donationThresholdToBonusLevels;
    }

    public static Level__c getLowestLoyaltyLevel() {
        List<Level__c> lowestLoyaltyLevelByThreshold = [
            SELECT Id, Donation_Threshold__c, Threshold_Payment__c, Threshold_Points__c
            FROM Level__c
            WHERE Donation_Threshold__c > 0 AND
                isActive__c = true
            ORDER BY Donation_Threshold__c ASC
            LIMIT 1
        ];

        return lowestLoyaltyLevelByThreshold.isEmpty() ? null : lowestLoyaltyLevelByThreshold[0];
    }

    public static Map<Id, Map<Id, AggregateResult>> getDonorLastPromotionDateByLevel(List<Contact> targetContacts) {
        Decimal loyaltyThresholdWindow = Proesis_Settings__c.getInstance()?.Loyalty_Threshold_Window__c;
        if (loyaltyThresholdWindow == null) {
            loyaltyThresholdWindow = 0;
        }

        Map<Id, Map<Id, AggregateResult>> donorIdToActiveLastPromotionDatesByTier = new Map<Id, Map<Id, AggregateResult>>();
        Datetime loyaltyThresholdDate = Datetime.now().addDays(-Integer.valueOf(loyaltyThresholdWindow));

        for (AggregateResult result : [
            SELECT Transaction__r.Donor__c donor, Promotion_Level__c loyaltyTier, MAX(CreatedDate) lastPromotionDate
            FROM Txn_Line_Item__c
            WHERE Promotion_Level__c != null AND CreatedDate >= :loyaltyThresholdDate AND Transaction__r.Donor__c IN :targetContacts
            GROUP BY Transaction__r.Donor__c, Promotion_Level__c
        ]) {
            Map<Id, AggregateResult> activeLastPromotionDatesByTier = donorIdToActiveLastPromotionDatesByTier.get((Id) result.get('donor'));
            if (activeLastPromotionDatesByTier == null) {
                activeLastPromotionDatesByTier = new Map<Id, AggregateResult>();
            }

            activeLastPromotionDatesByTier.put((Id) result.get('loyaltyTier'), result);
            donorIdToActiveLastPromotionDatesByTier.put((Id) result.get('donor'), activeLastPromotionDatesByTier);
        }

        return donorIdToActiveLastPromotionDatesByTier;
    }

    public static List<Contact> queryDonorContactInformation(Set<Id> donorContactIds, Set<Id> visitIds) {
        return [
            SELECT Id, Name, AccountId, Account.Last_Used_Center__pc, Loyalty_Level__c, Loyalty_Level__r.Donation_Points__c, Loyalty_Level__r.Donation_Payment__c, Total_Visits_365d__c,
                Loyalty_Level__r.Next_Level__r.Donation_Threshold__c, Loyalty_Level__r.Next_Level__c, Loyalty_Level__r.Next_Level__r.Threshold_Payment__c, Loyalty_Level__r.Next_Level__r.Threshold_Points__c, (
                SELECT Id, Name, Center_Donation_Type__r.Center__c, Center_Donation_Type__r.Donation_Type__c
                FROM Visits__r
                WHERE Status__c = 'Complete' AND 
                    Outcome__c = 'Donation' AND 
                    Id IN :visitIds
                ORDER BY Appointment_Datetime__c DESC
            ), (
                SELECT Id, Account_Number__c
                FROM Payment_Methods__r
                WHERE Is_Active__c = true AND Days_Until_Expiration__c > 0 AND isDefault__c = true
                LIMIT 1
            )
            FROM Contact
            WHERE Id IN :donorContactIds
        ];
    }

    public static ProesisAddFundsRequest buildBaseAddFundsRequest(Contact donorContact, Visit__c targetVisit) {
        Boolean hasPaymentMethod = (donorContact.Payment_Methods__r != null && donorContact.Payment_Methods__r.size() > 0);
        return new ProesisAddFundsRequest(
            donorContact.Id,
            targetVisit.Id,
            hasPaymentMethod ? donorContact.Payment_Methods__r[0].Account_Number__c : '',
            'Donation Payment'
        );
    }

    public static Transaction__c buildBaseTransaction(Contact donorContact, Visit__c targetVisit) {
        return new Transaction__c(
            Donor__c = donorContact.Id,
            Visit__c = targetVisit.Id,
            Type__c = 'Credit',
            SubType__c = 'Donation Payment',
            Status__c = 'Complete'
        );
    }

    public static List<Txn_Line_Item__c> buildDonationLineItems(Contact donorContact, Rate__c targetRate, ProesisAddFundsRequest addFundsRequest) {
        List<Txn_Line_Item__c> donationLineItems = new List<Txn_Line_Item__c>();
        
        // Points
        if (donorContact.Loyalty_Level__r.Donation_Points__c != null && donorContact.Loyalty_Level__r.Donation_Points__c > 0) {
            donationLineItems.add(new Txn_Line_Item__c(
                Item__c = 'Donation Points',
                Quantity__c = 1,
                Type__c = 'Points',
                Unit_Cost__c = donorContact.Loyalty_Level__r.Donation_Points__c
            ));

            if (addFundsRequest != null) {
                addFundsRequest.addLineItem('Donation Points', 'Points', donorContact.Loyalty_Level__r.Donation_Points__c);
            }
        }

        // Currency
        Decimal loyaltyLevelPaymentBonus = (donorContact.Loyalty_Level__r.Donation_Payment__c != null) ? donorContact.Loyalty_Level__r.Donation_Payment__c : 0;
        if (targetRate != null && targetRate.Base_Payment__c != null && targetRate.Base_Payment__c > 0) {
            Decimal donationPaymentTotal = targetRate.Base_Payment__c + loyaltyLevelPaymentBonus;

            donationLineItems.add(new Txn_Line_Item__c(
                Item__c = 'Donation Payment',
                Quantity__c = 1,
                Type__c = 'Currency',
                Unit_Cost__c = donationPaymentTotal
            ));

            if (addFundsRequest != null) {
                addFundsRequest.comments.add('Donation Payment');
                addFundsRequest.addLineItem('Donation Payment', 'Currency', donationPaymentTotal);
            }
        }

        return donationLineItems;
    }

    public static List<Txn_Line_Item__c> buildBonusLevelLineItems(
        Contact donorContact, List<Level__c> acheivedBonusLevels, Map<Id, AggregateResult> activeLastPromotionDatesByTier, ProesisAddFundsRequest addFundsRequest
    ) {
        List<Txn_Line_Item__c> bonusLevelLineItems = new List<Txn_Line_Item__c>();
        
        for (Level__c bonusLevel : acheivedBonusLevels) {
            // Check to make sure the bonus level hasn't be triggered in the last 'Loyalty Threshold Window'
            // If it has been triggered, skip it
            if (activeLastPromotionDatesByTier != null) {
                AggregateResult lastPromotionDate = activeLastPromotionDatesByTier.get(bonusLevel.Id);

                if (lastPromotionDate != null && lastPromotionDate.get('lastPromotionDate') != null) {
                    continue;
                }
            }

            if (bonusLevel.Threshold_Points__c != null && bonusLevel.Threshold_Points__c > 0) {
                bonusLevelLineItems.add(new Txn_Line_Item__c(
                    Item__c = bonusLevel.Name + ' - Bonus Points',
                    Quantity__c = 1,
                    Type__c = 'Points',
                    Unit_Cost__c = bonusLevel.Threshold_Points__c,
                    Promotion_Level__c = bonusLevel.Id
                ));

                if (addFundsRequest != null) {
                    addFundsRequest.addLineItem(bonusLevel.Name + ' - Bonus Points', 'Points', bonusLevel.Threshold_Points__c);
                }
            }

            if (bonusLevel.Threshold_Payment__c != null && bonusLevel.Threshold_Payment__c > 0) {
                bonusLevelLineItems.add(new Txn_Line_Item__c(
                    Item__c = bonusLevel.Name + ' - Bonus Payment',
                    Quantity__c = 1,
                    Type__c = 'Currency',
                    Unit_Cost__c = bonusLevel.Threshold_Payment__c,
                    Promotion_Level__c = bonusLevel.Id
                ));

                if (addFundsRequest != null) {
                    addFundsRequest.comments.add(bonusLevel.Name + ' - Bonus Payment');
                    addFundsRequest.addLineItem(bonusLevel.Name + ' - Bonus Payment', 'Currency', bonusLevel.Threshold_Payment__c);
                }
            }
        }

        return bonusLevelLineItems;
    }

    public static List<Txn_Line_Item__c> buildPromotionLineItems(Level__c targetPromotionLevel, ProesisAddFundsRequest addFundsRequest) {
        List<Txn_Line_Item__c> promotionLineItems = new List<Txn_Line_Item__c>();

        if (targetPromotionLevel.Threshold_Points__c != null && targetPromotionLevel.Threshold_Points__c > 0) {
            promotionLineItems.add(new Txn_Line_Item__c(
                Item__c = 'Threshold Points',
                Quantity__c = 1,
                Type__c = 'Points',
                Unit_Cost__c = targetPromotionLevel.Threshold_Points__c,
                Promotion_Level__c = targetPromotionLevel.Id
            ));

            if (addFundsRequest != null) {
                addFundsRequest.addLineItem('Threshold Points', 'Points', targetPromotionLevel.Threshold_Points__c);
            }
        }

        if (targetPromotionLevel.Threshold_Payment__c != null && targetPromotionLevel.Threshold_Payment__c > 0) {
            promotionLineItems.add(new Txn_Line_Item__c(
                Item__c = 'Threshold Payment',
                Quantity__c = 1,
                Type__c = 'Currency',
                Unit_Cost__c = targetPromotionLevel.Threshold_Payment__c,
                Promotion_Level__c = targetPromotionLevel.Id
            ));

            if (addFundsRequest != null) {
                addFundsRequest.comments.add('Threshold Payment');
                addFundsRequest.addLineItem('Threshold Payment', 'Currency', targetPromotionLevel.Threshold_Payment__c);
            }
        }

        return promotionLineItems;
    }

    public static Message__c buildDonationNotificationMessage(Contact donorContact, Visit__c donationVisit, Boolean wasPromotionTriggered) {
        return new Message__c(
            Name = (!wasPromotionTriggered) ? System.Label.Donation_Payment_Message_Title : System.Label.Loyalty_Donation_Payment_Message_Title,
            Message_Handler_Type__c = (!wasPromotionTriggered) ? Constants.DONATION_PAYMENT_MESSAGE_HANDLER : Constants.LOYALTY_DONATION_PAYMENT_MESSAGE_HANDLER,
            Body__c = (!wasPromotionTriggered) ? System.Label.Donation_Payment_Message_Body : System.Label.Loyalty_Donation_Payment_Message_Body,
            Donor__c = donorContact.Id,
            Visit__c = donationVisit.Id,
            Trigger_Marketing_Cloud__c = true
        );
    }

    public static void updateDonorLoyaltyLevels(Map<Id, Account> donorsToUpdate) {
        List<Account> donorsToUpdateList = new List<Account>(donorsToUpdate.values());

        if (donorsToUpdateList.size() > 0) {
            update donorsToUpdateList;
        }
    }

    public static void insertTransactionsAndLineItems(List<DonorPaymentService.DonationPaymentResponse> paymentResponses) {
        List<Transaction__c> transactions = new List<Transaction__c>();
        for(DonorPaymentService.DonationPaymentResponse paymentResponse : paymentResponses) {
            transactions.add(paymentResponse.transactionRecord);
        }

        insert transactions;

        List<Txn_Line_Item__c> lineItems = new List<Txn_Line_Item__c>();
        List<Message__c> messages = new List<Message__c>();

        for(DonorPaymentService.DonationPaymentResponse paymentResponse : paymentResponses) {
            for(Txn_Line_Item__c lineItem : paymentResponse.txnLineItems) {
                lineItem.Transaction__c = paymentResponse.transactionRecord.Id;
            }
            lineItems.addAll(paymentResponse.txnLineItems);

            for(Message__c message : paymentResponse.donationMessages) {
                message.Transaction__c = paymentResponse.transactionRecord.Id;
            }
            messages.addAll(paymentResponse.donationMessages);
        }

        insert lineItems;
        insert messages;
    }
}