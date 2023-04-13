public without sharing class VisitTriggerHelper {
    public static void updateAppointmentDateTime(List<Visit__c> visits) {
        Map<Id, List<Visit__c>> appointmentIdToVisitRecord = new Map<Id, List<Visit__c>>(); 
        
        for(Visit__c targetVisit : visits) {
            if (targetVisit.Appointment__c != null) {
                List<Visit__c> existingVisits = appointmentIdToVisitRecord.get(targetVisit.Appointment__c);
                if (existingVisits == null) {
                    existingVisits = new List<Visit__c>();
                }

                existingVisits.add(targetVisit);
                appointmentIdToVisitRecord.put(targetVisit.Appointment__c, existingVisits);
            }
        }

        // No Appointment DateTimes to Link
        if (appointmentIdToVisitRecord.size() == 0) {
            return;
        }

        for (Appointment__c queriedAppointment : [
            SELECT Id, Datetime__c
            FROM Appointment__c
            WHERE Id IN :appointmentIdToVisitRecord.keyset()
        ]) {
            if (queriedAppointment.Datetime__c == null) {
                continue;
            }

            List<Visit__c> relatedVisits = appointmentIdToVisitRecord.get(queriedAppointment.Id);
            if (relatedVisits == null || relatedVisits.size() == 0) {
                continue;
            }

            for(Visit__c relatedVisit : relatedVisits) {
                relatedVisit.Appointment_Datetime__c = queriedAppointment.Datetime__c;
            }
        }
    }

    public static void updateDonorVisitDates(List<Visit__c> visits) {
        List<Id> donorIds = new List<Id>();
        List<Id> appointmentIds = new List<Id>();
    
        for (Visit__c visit : visits) {
            if (visit.Physical_Exam__c || visit.SPE_Analysis__c) {
                if (visit.Donor__c == null || visit.Appointment__c == null) {
                    continue;
                }

                donorIds.add(visit.Donor__c);
                appointmentIds.add(visit.Appointment__c);
            }
        }
        
        if (!donorIds.isEmpty()) {
            Map<Id, Contact> visitIdToDonorRecord = new Map<Id, Contact>([SELECT Id, Last_Physical_Exam_Date__c, Last_SPE_Sample_Date__c FROM Contact WHERE Id IN :donorIds]);
            Map<Id, Appointment__c> visitIdToAppointmentRecord = new Map<Id, Appointment__c>([SELECT Id, DateTime__c FROM Appointment__c WHERE Id IN :appointmentIds]);

            for (Visit__c visit : visits) {
                Contact donor = visitIdToDonorRecord.get(visit.Donor__c);
                Appointment__c appointment = visitIdToAppointmentRecord.get(visit.Appointment__c);
                
                if (donor != null && appointment != null && appointment.DateTime__c != null) {
                    if (visit.Physical_Exam__c) {
                        donor.Last_Physical_Exam_Date__c = appointment.DateTime__c.date();
                    }
                    
                    if (visit.SPE_Analysis__c) {
                        donor.Last_SPE_Sample_Date__c = appointment.DateTime__c.date();
                    }
                    
                    visitIdToDonorRecord.put(donor.Id, donor);
                }
            }
            
            update visitIdToDonorRecord.values();
        }
    }

    public static void manageVisitSpecialNotes(List<Visit__c> visits) {
        Set<Id> donorIds = new Set<Id>();
        for (Visit__c visit : visits) {
            if (visit.Donor__c != null) {
                donorIds.add(visit.Donor__c);
            }
        }

        if (donorIds.size() > 0) {
            Map<Id, Visit__c> visitRecordsToUpdate = new Map<Id, Visit__c>();
            List<Task> tasksToCreate = new List<Task>();
            Map<Id, Id> visitIdToNewTaskParentId = new Map<Id, Id>();

            Set<Id> annualPhysicalExamVisitTasksToDelete = new Set<Id>();
            Set<Id> triannualSPEVisitTasksToDelete = new Set<Id>();

            for(Contact donor : [
                SELECT Id, Account.First_Visit_Code__c, Account.Days_Until_Annum__pc, Account.Days_until_Triannum__pc, (
                    SELECT Id, Name, Donor__c, Appointment_Datetime__c, isFirstVisit__c, Physical_Exam__c, SPE_Analysis__c 
                    FROM Visits__r 
                    ORDER BY Appointment_Datetime__c ASC
                ) 
                FROM Contact 
                WHERE Id IN :donorIds
            ]) {
                if (donor.Visits__r == null || donor.Visits__r.size() == 0) {
                    continue;
                }
                
                // Process First Visit Flag / Tasks
                Visit__c earliestVisit = donor.Visits__r[0];
                if (!earliestVisit.isFirstVisit__c) {
                    earliestVisit.isFirstVisit__c = true;
                    earliestVisit.Physical_Exam__c = true;
                    earliestVisit.SPE_Analysis__c = true;
                    visitRecordsToUpdate.put(earliestVisit.Id, earliestVisit);
                

                    // If a first visit has already been created
                    Boolean hasAlreadyHadFirstVisitCreated = false;
                    Visit__c originalFirstVisit;

                    for(Integer i = 1; i < donor.Visits__r.size(); i++) {
                        if (!donor.Visits__r[i].isFirstVisit__c) {
                            continue;
                        }

                        hasAlreadyHadFirstVisitCreated = true;
                        originalFirstVisit = donor.Visits__r[i];

                        originalFirstVisit.isFirstVisit__c = false;
                        originalFirstVisit.Physical_Exam__c = false;
                        originalFirstVisit.SPE_Analysis__c = false;

                        visitRecordsToUpdate.put(donor.Visits__r[i].Id, donor.Visits__r[i]);

                        // There should only ever be one marked as isFirstVisit__c
                        break;
                    }

                    if (hasAlreadyHadFirstVisitCreated) {
                        visitIdToNewTaskParentId.put(originalFirstVisit.Id, earliestVisit.Id);
                    } else {
                        // No first visit has been created yet so create the SPE, Medical Exam, and First Visit Code Tasks

                        tasksToCreate.add(new Task(
                            WhatId = earliestVisit.Id,
                            WhoId = donor.Id,
                            Subject = Constants.PHYSICAL_EXAM_TASK_SUBJECT
                        ));

                        tasksToCreate.add(new Task(
                            WhatId = earliestVisit.Id,
                            WhoId = donor.Id,
                            Subject = Constants.SPE_ANALYSIS_TASK_SUBJECT
                        ));

                        tasksToCreate.add(new Task(
                            WhatId = earliestVisit.Id,
                            WhoId = donor.Id,
                            Subject = Constants.FIRST_VISIT_CODE_TASK_SUBJECT,
                            Description = donor.Account.First_Visit_Code__c
                        ));
                    }
                }

                // Process Annual Visit Tasks
                if (donor.Account != null && donor.Account.Days_Until_Annum__pc != null && donor.Account.Days_until_Triannum__pc != null) {
                    // First we determine what visit for each donor is the closest to the annual exam date as well as in the acceptable range for the annual exam
                    // Then we mark any visits that are within the acceptable range as annual visits and mark the others as not annual visits (if they were previous)
                    // Also need to delete any tasks if we unmark a visit as a annual exam visit

                    Integer closestPhysicalExamDayCount = 999999999;
                    Visit__c closestPhysicalExamVisit;

                    Integer closestSpeAnalysisDayCount = 999999999;
                    Visit__c closestSpeAnalysisVisit;

                    List<Visit__c> currentPhysicalExamVisits = new List<Visit__c>();
                    List<Visit__c> currentSpeAnalysisVisits = new List<Visit__c>();

                    // Finding the closest SPE / Physical Exam visit
                    for(Integer i = 0; i < donor.Visits__r.size(); i++) {
                        Visit__c visit = donor.Visits__r[i];
                        Integer daysRemainingUntilVisit = Date.today().daysBetween(visit.Appointment_Datetime__c.date());

                        if (visit.isFirstVisit__c || visit.Appointment_Datetime__c == null) {
                            continue;
                        }

                        // Physical Exam
                        Integer daysRemainingForAnnum = (Integer)donor.Account.Days_Until_Annum__pc - daysRemainingUntilVisit;
                        if (daysRemainingForAnnum <= 10 && Math.abs(daysRemainingForAnnum) < closestPhysicalExamDayCount) {
                            closestPhysicalExamDayCount = Math.abs(daysRemainingForAnnum);
                            closestPhysicalExamVisit = visit;
                        }

                        if (visit.Physical_Exam__c) {
                            currentPhysicalExamVisits.add(visit);
                        }
                        
                        // SPE Analysis
                        Integer daysRemainingForTriannum = (Integer)donor.Account.Days_until_Triannum__pc - daysRemainingUntilVisit;  
                        if (daysRemainingForTriannum <= 10 && Math.abs(daysRemainingForTriannum) < closestSpeAnalysisDayCount) {
                            closestSpeAnalysisDayCount = Math.abs(daysRemainingForTriannum);
                            closestSpeAnalysisVisit = visit;
                        }

                        if (visit.SPE_Analysis__c) {
                            currentSpeAnalysisVisits.add(visit);
                        }
                    }

                    // Creating the annual exam task and deleting old tasks, if applicable
                    if (closestPhysicalExamVisit != null && !closestPhysicalExamVisit.Physical_Exam__c) {
                        closestPhysicalExamVisit.Physical_Exam__c = true;
                        visitRecordsToUpdate.put(closestPhysicalExamVisit.Id, closestPhysicalExamVisit);

                        tasksToCreate.add(new Task(
                            WhatId = closestPhysicalExamVisit.Id,
                            WhoId = closestPhysicalExamVisit.Donor__c,
                            Subject = Constants.PHYSICAL_EXAM_TASK_SUBJECT
                        ));

                        for(Visit__c visit : currentPhysicalExamVisits) {
                            visit.Physical_Exam__c = false;

                            annualPhysicalExamVisitTasksToDelete.add(visit.Id);
                            visitRecordsToUpdate.put(visit.Id, visit);
                        }
                    }

                    // Creating the triannual exam task and deleting old tasks, if applicable
                    if (closestSpeAnalysisVisit != null && !closestSpeAnalysisVisit.SPE_Analysis__c) {
                        closestSpeAnalysisVisit.SPE_Analysis__c = true;
                        visitRecordsToUpdate.put(closestSpeAnalysisVisit.Id, closestSpeAnalysisVisit);

                        tasksToCreate.add(new Task(
                            WhatId = closestSpeAnalysisVisit.Id,
                            WhoId = closestSpeAnalysisVisit.Donor__c,
                            Subject = Constants.SPE_ANALYSIS_TASK_SUBJECT
                        ));

                        for(Visit__c visit : currentSpeAnalysisVisits) {
                            visit.SPE_Analysis__c = false;

                            triannualSPEVisitTasksToDelete.add(visit.Id);
                            visitRecordsToUpdate.put(visit.Id, visit);
                        }
                    }
                }
            }

            if (annualPhysicalExamVisitTasksToDelete.size() > 0 || triannualSPEVisitTasksToDelete.size() > 0) {
                delete [
                    SELECT Id 
                    FROM Task 
                    WHERE (WhatId IN :annualPhysicalExamVisitTasksToDelete AND Subject = :Constants.PHYSICAL_EXAM_TASK_SUBJECT) OR 
                        (WhatId IN :triannualSPEVisitTasksToDelete AND Subject = :Constants.SPE_ANALYSIS_TASK_SUBJECT)
                ];
            }

            if (visitRecordsToUpdate.size() > 0) {
                update visitRecordsToUpdate.values();
            }

            if (tasksToCreate.size() > 0) {
                insert tasksToCreate;
            }

            if (visitIdToNewTaskParentId.size() > 0) {
                List<Task> targetTasks = [SELECT Id, WhatId FROM Task WHERE WhatId IN :visitIdToNewTaskParentId.keySet()];
                for(Task targetTask : targetTasks) {
                    targetTask.WhatId = visitIdToNewTaskParentId.get(targetTask.WhatId);
                }

                update targetTasks;
            }
        }
    }

    public static void updateLastPreviousDonation(List<Visit__c> visits) {
        Set<Id> donorIds = new Set<Id>();
        for(Visit__c visit : visits) {
            donorIds.add(visit.Donor__c);
        }

        List<Contact> donorsToUpdate = new List<Contact>();
        for(Contact donor : [SELECT Id, Last_Previous_Donation__c, (SELECT Id FROM Visits__r WHERE Status__c = 'Complete' AND Outcome__c = 'Donation' ORDER BY Appointment_Datetime__c DESC) FROM Contact WHERE Id IN :donorIds]) {
            if (donor.Visits__r == null || donor.Visits__r.size() < 2) {
                continue;
            }

            Visit__c lastPreviousDonationVisit = donor.Visits__r[1];
            if (donor.Last_Previous_Donation__c == null || donor.Last_Previous_Donation__c != lastPreviousDonationVisit.Id) {
                donor.Last_Previous_Donation__c = lastPreviousDonationVisit.Id;
                donorsToUpdate.add(donor);
            }
        }

        if (donorsToUpdate.size() > 0) {
            update donorsToUpdate;
        }
    }
}