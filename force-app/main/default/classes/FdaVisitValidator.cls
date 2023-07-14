public without sharing class FdaVisitValidator {
    final Set<String> VALID_VISIT_STATUSES = new Set<String>{'New', 'Scheduled', 'Checked-In'};
    final Set<String> VALID_VISIT_OUTCOMES = new Set<String>{'Donation', 'No Donation'};
    
    public List<FdaValidationRequest> createVisitRequests;

    // If true, the validator will not compare new visits against other new visits
    // This allows us to pass in multiple validation requests for potential new visits without validation rules getting unnecessarily triggered
    public Boolean dontCompareNewVisits = false;
    
    private Map<Id, List<Visit__c>> donorIdToNewVisits;
    private Map<Id, DateTime> appointmentIdToDateTime;
    private Map<String, FdaValidationRequest> createVisitRequestMap;

    private Set<Id> appointmentIds;
    private Set<Id> donorContactIds;

    private DateTime minimumDateTime;
    private DateTime maximumDateTime;

    public FdaVisitValidator(FdaValidationRequest createVisitRequest) {
        this(new List<FdaValidationRequest>{createVisitRequest}, false);
    }

    public FdaVisitValidator(FdaValidationRequest createVisitRequest, Boolean dontCompareNewVisits) {
        this(new List<FdaValidationRequest>{createVisitRequest}, dontCompareNewVisits);
    }

    public FdaVisitValidator(List<FdaValidationRequest> createVisitRequests) {
        this(createVisitRequests, false);
    }

    public FdaVisitValidator(List<FdaValidationRequest> createVisitRequests, Boolean dontCompareNewVisits) {
        this.createVisitRequests = createVisitRequests;
        this.dontCompareNewVisits = dontCompareNewVisits;
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
                WHERE (Status__c IN :VALID_VISIT_STATUSES OR (Status__c = 'Complete' AND Outcome__c IN :VALID_VISIT_OUTCOMES)) AND
                    Appointment_Datetime__c >= :minimumDateTime AND
                    Appointment_Datetime__c <= :maximumDateTime
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

            List<FdaValidationRequest> completedValidationRequestsInCurrentSevenDayPeriod = new List<FdaValidationRequest>();
            List<EvaluatedVisit> evaluatedVisitsForLastSevenDays = new List<EvaluatedVisit>();
            List<String> visitDatetimeStringsInCurrentSevenDayPeriod = new List<String>();

            for (Visit__c visit : allDonorVisits) {
                Boolean was7DayPeriodViolationFound = false;
                Boolean isNewVisit = !visit.isSet('Id');
                
                FdaValidationRequest createVisitRequest = getCreateVisitRequest(visit.Appointment__c, donorContact.Id);
                EvaluatedVisit evaluatedVisit = new EvaluatedVisit(visit, createVisitRequest, isNewVisit);

                // Check all the stored visits to see if they fall outside the current 7 day period (from the current visit)
                // If they do, remove them from the list to avoid unnecessary comparisons
                for(Integer currentEvaluatedVisitIndex = 0; currentEvaluatedVisitIndex < evaluatedVisitsForLastSevenDays.size(); currentEvaluatedVisitIndex++) {
                    EvaluatedVisit evaluatedVisitIterator = evaluatedVisitsForLastSevenDays[currentEvaluatedVisitIndex];

                    Datetime evaluatedVisitDatetime = evaluatedVisitIterator.visit.Appointment_Datetime__c;
                    Integer daysBetweenTarget = Math.abs(evaluatedVisitDatetime.date().daysBetween(visit.Appointment_Datetime__c.date()));

                    if (daysBetweenTarget > 6) {
                        visitDatetimeStringsInCurrentSevenDayPeriod.remove(currentEvaluatedVisitIndex);
                        evaluatedVisitsForLastSevenDays.remove(currentEvaluatedVisitIndex);

                        currentEvaluatedVisitIndex--; // To account for the shift in the list
                    }
                }

                if (evaluatedVisitsForLastSevenDays.size() > 0) {
                    // 7 Day Period Violation Check (More than 2 visits in a 7 day period)
                    was7DayPeriodViolationFound = (evaluatedVisitsForLastSevenDays.size() + 1 > 2);

                    if (was7DayPeriodViolationFound) {
                        if (!isNewVisit) {
                            // In this case, if we have a 7 day violation, then we need to check to see if any requested visits triggered the 7 day violation
                            // If only new visits triggered the 7 day rule, or a mixture of old/new, then we need to remove the closest "newest" visit as that is the one that triggered the rule
                            // Ex. We get two new requested visits, (6-1-2023, 6-5-2023) for a donor who already has a visit on 6-7-2023
                            // In this case, if we created them one by one, the 6-5 would trigger the 7 day rule, not the existing 6-7-2023 visit

                            for(Integer i = evaluatedVisitsForLastSevenDays.size() - 1; i >= 0; i--) {
                                EvaluatedVisit evaluatedVisitIterator = evaluatedVisitsForLastSevenDays[i];
                                
                                if (evaluatedVisitIterator.isNewVisit) {
                                    evaluatedVisitsForLastSevenDays.remove(i);
                                    visitDatetimeStringsInCurrentSevenDayPeriod.remove(i);

                                    visitDatetimeStringsInCurrentSevenDayPeriod.add(evaluatedVisit.visit.Appointment_Datetime__c.format('MM-dd-yyyy'));
                                    evaluatedVisitsForLastSevenDays.add(evaluatedVisit);

                                    evaluatedVisitIterator.createVisitRequest.addValidationResult(
                                        false, 'Donor has more than 2 visits in a 7 day period (Conflicting visits: ' + String.join(visitDatetimeStringsInCurrentSevenDayPeriod, ', ') + ')'
                                    );

                                    break;
                                }
                            }
                        } else {
                            createVisitRequest?.addValidationResult(false, 'Donor has more than 2 visits in a 7 day period (Conflicting visits: ' + String.join(visitDatetimeStringsInCurrentSevenDayPeriod, ', ') + ')');
                        }

                        was7DayPeriodViolationFound = true;
                    }

                    // 2 Day Period Violation Check (More than 1 visit in a 2 day period)
                    // Since the visits are sorted in ASC order, the last visit in the list will be the most recent
                    Datetime visitToCheck2DayAgainst = evaluatedVisitsForLastSevenDays[evaluatedVisitsForLastSevenDays.size() - 1].visit.Appointment_Datetime__c;
                    Datetime visitTimeToValidate = visit.Appointment_Datetime__c;

                    Integer dateDifference = Math.abs(visitTimeToValidate.date().daysBetween(visitToCheck2DayAgainst.date()));
                    if (dateDifference < 2) {
                        if (isNewVisit) {
                            createVisitRequest?.addValidationResult(false, 'Donor has more than 1 visit in a 2 day period (Conflicting visits: ' + String.join(visitDatetimeStringsInCurrentSevenDayPeriod, ', ') + ')');
                            continue;
                        }

                        // As with the 7 day rule, if we have a 2 day violation triggered by an existing visit
                        // We need to go back and remove the closest "newest" visit as that is the one that triggered the rule
                        // There should only be one visit in the evaluatedVisitsForLastSevenDays list at this point, and it should be a new visit
                        // If it's not, then two conflicting visits got inserted which shouldn't happen

                        EvaluatedVisit evaluatedVisitIterator = evaluatedVisitsForLastSevenDays[0];
                        if (evaluatedVisitIterator.isNewVisit) {
                            evaluatedVisitsForLastSevenDays.remove(0);
                            visitDatetimeStringsInCurrentSevenDayPeriod.remove(0);

                            visitDatetimeStringsInCurrentSevenDayPeriod.add(evaluatedVisit.visit.Appointment_Datetime__c.format('MM-dd-yyyy'));
                            evaluatedVisitsForLastSevenDays.add(evaluatedVisit);

                            evaluatedVisitIterator.createVisitRequest.addValidationResult(
                                false, 'Donor has more than 1 visit in a 2 day period (Conflicting visits: ' + String.join(visitDatetimeStringsInCurrentSevenDayPeriod, ', ') + ')'
                            );
                        }
                    }
                }

                if ((dontCompareNewVisits && !isNewVisit) || !dontCompareNewVisits) {
                    if (!was7DayPeriodViolationFound) {
                        visitDatetimeStringsInCurrentSevenDayPeriod.add(evaluatedVisit.visit.Appointment_Datetime__c.format('MM-dd-yyyy'));
                        evaluatedVisitsForLastSevenDays.add(evaluatedVisit);
                    }
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
        List<Visit__c> newVisitsForDonor = donorIdToNewVisits.get(donorContact.Id);
        
        if (newVisitsForDonor != null) {
            allDonorVisits.addAll(newVisitsForDonor);
        }

        List<VisitDatetimeComparer> visitDatetimeComparers = new List<VisitDatetimeComparer>();
        for(Visit__c visit : allDonorVisits) {
            visitDatetimeComparers.add(new VisitDatetimeComparer(visit));
        }
        visitDatetimeComparers.sort();

        List<Visit__c> sortedAllDonorVisits = new List<Visit__c>();
        for(VisitDatetimeComparer visitDatetimeComparer : visitDatetimeComparers) {
            sortedAllDonorVisits.add(visitDatetimeComparer.visitRecord);
        }

        return sortedAllDonorVisits;
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

    public class EvaluatedVisit {
        public Visit__c visit;
        public Boolean isNewVisit;
        public FdaValidationRequest createVisitRequest;

        public EvaluatedVisit(Visit__c visit, FdaValidationRequest createVisitRequest, Boolean isNewVisit) {
            this.visit = visit;
            this.createVisitRequest = createVisitRequest;
            this.isNewVisit = isNewVisit;
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