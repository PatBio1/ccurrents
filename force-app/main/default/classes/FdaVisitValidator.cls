public without sharing class FdaVisitValidator {
    final Set<String> VALID_VISIT_STATUSES = new Set<String>{'New', 'Scheduled', 'Checked-In'};
    final Set<String> VALID_VISIT_OUTCOMES = new Set<String>{'Donation', 'No Donation'};
    
    public List<FdaValidationRequest> createVisitRequests;
    
    private Map<Id, List<Visit__c>> donorIdToNewVisits;
    private Map<Id, DateTime> appointmentIdToDateTime;
    private Map<String, FdaValidationRequest> createVisitRequestMap;

    private Set<Id> appointmentIds;
    private Set<Id> donorContactIds;

    private Datetime minimumDateTime;
    private Datetime maximumDateTime;

    public FdaVisitValidator(FdaValidationRequest createVisitRequest) {
        this(new List<FdaValidationRequest>{createVisitRequest});
    }

    public FdaVisitValidator(List<FdaValidationRequest> createVisitRequests) {
        this.createVisitRequests = createVisitRequests;
        buildCreateVisitRequestMap();

        this.appointmentIdToDateTime = new Map<Id, DateTime>();
        this.donorIdToNewVisits = new Map<Id, List<Visit__c>>();
        this.appointmentIds = new Set<Id>();
        this.donorContactIds = new Set<Id>();

        gatherIdSets();
        calculateValidationStartAndEndDatetimes();
        buildRequestedVisitSObjectsForValidation();
    }

    public List<FdaValidationRequest> validateCreateVisitRequests() {
        for(Contact donorContact : [
            SELECT Id, (
                SELECT Id, Appointment_Datetime__c, Appointment__c 
                FROM Visits__r
                WHERE Appointment_Datetime__c >= :minimumDateTime AND 
                    Appointment_Datetime__c <= :maximumDateTime AND 
                    (Status__c IN :VALID_VISIT_STATUSES OR (Status__c = 'Complete' AND Outcome__c IN :VALID_VISIT_OUTCOMES))
                ORDER BY Appointment_Datetime__c ASC
            )
            FROM Contact
            WHERE Id IN :donorContactIds
        ]) {
            List<Visit__c> allDonorVisits = getAllDonorVisits(donorContact);
            
            // No possible rule violations in this case
            if (allDonorVisits.size() < 2) {
                continue;
            }

            // Analyze the visit list in chuncks of 7 days, starting with the earliest visit date to visit date + 6 days
            // If any donor has more than 2 visits in a 7 day period OR more than 1 visit in a 48 hour period, throw an error

            Datetime currentSevenDayPeriodStart = allDonorVisits[0].Appointment_Datetime__c;
            Datetime currentSevenDayPeriodEnd = currentSevenDayPeriodStart.addDays(6);

            Integer visitsInCurrentSevenDayPeriod = 0;
            Datetime lastVisitInCurrentSevenDayPeriod = null;
            Boolean isPeriodStillValid = true; // If we find a rule violation, we can automatically mark the rest of the visits in the period as invalid

            for (Visit__c visit : allDonorVisits) {
                if (visit.Appointment_Datetime__c > currentSevenDayPeriodEnd) {
                    currentSevenDayPeriodStart = visit.Appointment_Datetime__c;
                    currentSevenDayPeriodEnd = currentSevenDayPeriodStart.addDays(6);

                    visitsInCurrentSevenDayPeriod = 0;
                    lastVisitInCurrentSevenDayPeriod = null;
                    isPeriodStillValid = true;
                }

                // This should only be caused by the donor having more than 2 visits in a 7 day period
                if (!isPeriodStillValid) {
                    FdaValidationRequest createVisitRequest = getCreateVisitRequest(visit.Appointment__c, donorContact.Id);
                    if (createVisitRequest != null) {
                        createVisitRequest.addValidationResult(false, 'Donor has more than 2 visits in a 7 day period');
                    }

                    continue;
                }

                visitsInCurrentSevenDayPeriod++;
                if (visitsInCurrentSevenDayPeriod > 2) {
                    isPeriodStillValid = false;

                    FdaValidationRequest createVisitRequest = getCreateVisitRequest(visit.Appointment__c, donorContact.Id);
                    if (createVisitRequest != null) {
                        createVisitRequest.addValidationResult(false, 'Donor has more than 2 visits in a 7 day period');
                    }

                    continue;
                }

                if (
                    lastVisitInCurrentSevenDayPeriod != null && 
                    visitsInCurrentSevenDayPeriod > 1 &&
                    visit.Appointment_Datetime__c.addDays(-2) < lastVisitInCurrentSevenDayPeriod
                ) {
                    FdaValidationRequest createVisitRequest = getCreateVisitRequest(visit.Appointment__c, donorContact.Id);
                    if (createVisitRequest != null) {
                        createVisitRequest.addValidationResult(false, 'Donor has more than 1 visit in a 48 hour period');
                    }

                    continue;
                }

                lastVisitInCurrentSevenDayPeriod = visit.Appointment_Datetime__c;

                FdaValidationRequest createVisitRequest = getCreateVisitRequest(visit.Appointment__c, donorContact.Id);
                if (createVisitRequest != null) {
                    createVisitRequest.addValidationResult(true, '');
                }
            }
        }

        return createVisitRequests;
    }

     private void buildCreateVisitRequestMap() {
        this.createVisitRequestMap = new Map<String, FdaValidationRequest>();
        for (FdaValidationRequest createVisitRequest : createVisitRequests) {
            createVisitRequestMap.put(createVisitRequest.appointmentId + '-' + createVisitRequest.donorContactId, createVisitRequest);
        }

        System.debug(createVisitRequestMap);
    }

    private FdaValidationRequest getCreateVisitRequest(String appointmentId, String donorContactId) {
        return createVisitRequestMap.get(appointmentId + '-' + donorContactId);
    }

    private void gatherIdSets() {
        for (FdaValidationRequest createVisitRequest : createVisitRequests) {
            appointmentIds.add(createVisitRequest.appointmentId);
            donorContactIds.add(createVisitRequest.donorContactId);
        }
    }

    private void calculateValidationStartAndEndDatetimes() {
        for(Appointment__c appointment : [SELECT Id, Datetime__c FROM Appointment__c WHERE Id IN :appointmentIds]) {
            Datetime newMinimumDateTime = appointment.Datetime__c.addDays(-6);
            if (minimumDateTime == null || newMinimumDateTime < minimumDateTime) {
                minimumDateTime = newMinimumDateTime;
            }

            Datetime newMaximumDateTime = appointment.Datetime__c.addDays(6);
            if (maximumDateTime == null || newMaximumDateTime > maximumDateTime) {
                maximumDateTime = newMaximumDateTime;
            }

            appointmentIdToDateTime.put(appointment.Id, appointment.Datetime__c);
        }
    }

    private void buildRequestedVisitSObjectsForValidation() {
        for(FdaValidationRequest createVisitRequest : createVisitRequests) {
            List<Visit__c> newVisitsForDonor = donorIdToNewVisits.get(createVisitRequest.donorContactId);

            if (newVisitsForDonor == null) {
                newVisitsForDonor = new List<Visit__c>();
                donorIdToNewVisits.put(createVisitRequest.donorContactId, newVisitsForDonor);
            }

            newVisitsForDonor.add(new Visit__c(
                Appointment__c = createVisitRequest.appointmentId,
                Donor__c = createVisitRequest.donorContactId,
                Center_Donation_Type__c = createVisitRequest.centerDonationTypeId,
                Status__c = 'Scheduled',
                Appointment_Datetime__c = appointmentIdToDateTime.get(createVisitRequest.appointmentId)
            ));
        }
    }

    private List<Visit__c> getAllDonorVisits(Contact donorContact) {
        List<Visit__c> allDonorVisits = donorContact.Visits__r;
        if (allDonorVisits == null) {
            allDonorVisits = new List<Visit__c>();
        }

        List<Visit__c> newVisitsForDonor = donorIdToNewVisits.get(donorContact.Id);
        if (newVisitsForDonor != null) {
            allDonorVisits.addAll(newVisitsForDonor);
        }

        return allDonorVisits;
    } 

    public class FdaValidationRequest {
        public Id appointmentId;
        public Id donorContactId;
        public Id centerDonationTypeId;

        public ValidationResult validationResult;

        public FdaValidationRequest(Id appointmentId, Id donorContactId, Id centerDonationTypeId) {
            this.appointmentId = appointmentId;
            this.donorContactId = donorContactId;
            this.centerDonationTypeId = centerDonationTypeId;
        }

        public void addValidationResult(Boolean isValid, String errorMessage) {
            this.validationResult = new ValidationResult(isValid, errorMessage);
        }
    }

    public class ValidationResult {
        public Boolean isValid;
        public String errorMessage;

        public ValidationResult(Boolean isValid, String errorMessage) {
            this.isValid = isValid;
            this.errorMessage = errorMessage;
        }
    }
}