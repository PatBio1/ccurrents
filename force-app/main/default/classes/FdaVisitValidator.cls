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
            System.debug(donorContact.Visits__r);
            List<Visit__c> allDonorVisits = getAllDonorVisits(donorContact);
            for(Visit__c visit : allDonorVisits) {
                if (visit.Id != null)
                    System.debug(visit.Id + ' / ' + visit.Appointment_Datetime__c);
            }
            
            // No possible rule violations in this case
            if (allDonorVisits.size() < 2) {
                continue;
            }

            // Analyze the visit list in chuncks of 7 days, starting with the earliest visit date to visit date + 6 days
            // If any donor has more than 2 visits in a 7 day period OR more than 1 visit in a 48 hour period, throw an error

            Datetime currentSevenDayPeriodStart = allDonorVisits[0].Appointment_Datetime__c;
            Datetime currentSevenDayPeriodEnd = Datetime.newInstanceGmt(currentSevenDayPeriodStart.addDays(6).date(), Time.newInstance(23, 59, 59, 999));

            List<FdaValidationRequest> completedValidationRequestsInCurrentSevenDayPeriod = new List<FdaValidationRequest>();
            List<String> visitDatetimeStringsInCurrentSevenDayPeriod = new List<String>();
            Integer visitsInCurrentSevenDayPeriod = 0;
            Datetime lastVisitDatetime = null;
            Boolean isPeriodStillValid = true; // If we find a rule violation, we can automatically mark the rest of the visits in the period as invalid

            for (Visit__c visit : allDonorVisits) {
                FdaValidationRequest createVisitRequest = getCreateVisitRequest(visit.Appointment__c, donorContact.Id);
                Boolean isNewVisit = !visit.isSet('Id');

                if (visit.Appointment_Datetime__c > currentSevenDayPeriodEnd) {
                    currentSevenDayPeriodStart = visit.Appointment_Datetime__c;
                    currentSevenDayPeriodEnd = currentSevenDayPeriodStart.addDays(6);

                    completedValidationRequestsInCurrentSevenDayPeriod = new List<FdaValidationRequest>();
                    visitDatetimeStringsInCurrentSevenDayPeriod = new List<String>();
                    visitsInCurrentSevenDayPeriod = 0;
                    isPeriodStillValid = true;
                }

                // This should only be caused by the donor having more than 2 visits in a 7 day period
                if (!isPeriodStillValid) {
                    if (createVisitRequest != null) {
                        createVisitRequest.addValidationResult(false, 'Donor has more than 2 visits in a 7 day period (Conflicting visits: ' + String.join(visitDatetimeStringsInCurrentSevenDayPeriod, ', ') + ')');
                    }

                    continue;
                }

                // visitDatetimeStringsInCurrentSevenDayPeriod.add(visit.Appointment_Datetime__c.format('MM-dd-yyyy HH:mm'));
                Boolean hasTriggeredSevenDayViolation = (visitsInCurrentSevenDayPeriod + 1 > 2);
                Boolean hasTriggeredTwoDayViolation = (
                    lastVisitDatetime != null && 
                    visitsInCurrentSevenDayPeriod + 1 > 1 &&
                    visit.Appointment_Datetime__c.addHours(-(visit.Appointment_Datetime__c.hourGmt() + 12)) < lastVisitDatetime
                );
                
                if (hasTriggeredSevenDayViolation) {
                    System.debug('7 day Violation Triggered');
                    isPeriodStillValid = false;

                    if (createVisitRequest != null) {
                        createVisitRequest.addValidationResult(false, 'Donor has more than 2 visits in a 7 day period (Conflicting visits: ' + String.join(visitDatetimeStringsInCurrentSevenDayPeriod, ', ') + ')');
                    }

                    // If we had already evaluated other requests in this period, and newVisitComparisons is disabled
                    // We need to invalidate those requests as well
                    if (completedValidationRequestsInCurrentSevenDayPeriod.size() > 0 && dontCompareNewVisits) {
                        for (FdaValidationRequest completedValidationRequest : completedValidationRequestsInCurrentSevenDayPeriod) {
                            completedValidationRequest.addValidationResult(false, 'Donor has more than 2 visits in a 7 day period (Conflicting visits: ' + String.join(visitDatetimeStringsInCurrentSevenDayPeriod, ', ') + ')');
                        }
                    }

                    continue;
                }

                if (hasTriggeredTwoDayViolation) {
                    System.debug('2 day Violation Triggered');
                    if (createVisitRequest != null) {
                        createVisitRequest.addValidationResult(false, 'Donor has more than 1 visit in a 2 day period (Conflicting visits: ' + String.join(visitDatetimeStringsInCurrentSevenDayPeriod, ', ') + ')');
                    }

                    continue;
                }

                if ((dontCompareNewVisits && !isNewVisit) || !dontCompareNewVisits) {
                    System.debug('Setting violation tracking variables');
                    System.debug('visitsInCurrentSevenDayPeriod: ' + visitsInCurrentSevenDayPeriod);
                    System.debug('lastVisitDatetime: ' + lastVisitDatetime);

                    visitDatetimeStringsInCurrentSevenDayPeriod.add(visit.Appointment_Datetime__c.format('MM-dd-yyyy'));
                    visitsInCurrentSevenDayPeriod++;
                    lastVisitDatetime = visit.Appointment_Datetime__c;
                }

                if (createVisitRequest != null) {
                    createVisitRequest.addValidationResult(true, '');

                    if (isNewVisit) {
                        completedValidationRequestsInCurrentSevenDayPeriod.add(createVisitRequest);
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
        if (allDonorVisits == null) {
            allDonorVisits = new List<Visit__c>();
        }

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

    public class ValidationResult {
        public Boolean isValid;
        public String errorMessage;

        public ValidationResult(Boolean isValid, String errorMessage) {
            this.isValid = isValid;
            this.errorMessage = errorMessage;
        }
    }
}