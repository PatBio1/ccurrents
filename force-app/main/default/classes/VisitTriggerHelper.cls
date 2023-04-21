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
            Set<String> acceptableFirstVisitOutcomes = new Set<String> {
                null, 'Donation', 'No Donation'
            };

            Map<Id, Visit__c> visitRecordsToUpdate = new Map<Id, Visit__c>();
            List<Task> tasksToCreate = new List<Task>();
            Map<Id, Id> visitIdToNewTaskParentId = new Map<Id, Id>();

            Set<Id> annualPhysicalExamVisitTasksToDelete = new Set<Id>();
            Set<Id> triannualSPEVisitTasksToDelete = new Set<Id>();

            // Handle First Visit Flags and Tasks
            // This is handled by a second query in order to reduce looping and heap size (in the event of a large visit backlog for a donor)
            for(Contact donor : [
                SELECT Id, Account.First_Visit_Code__c, (
                    SELECT Id, isFirstVisit__c, Outcome__c
                    FROM Visits__r 
                    WHERE Outcome__c IN :acceptableFirstVisitOutcomes OR 
                        isFirstVisit__c = true 
                    ORDER BY Appointment_Datetime__c ASC 
                    LIMIT 2
                ) 
                FROM Contact 
                WHERE Id IN :donorIds
            ]) {
                if (donor.Visits__r.size() > 0) {
                    Visit__c intendedFirstVisit = donor.Visits__r[0];
                    Visit__c nextSoonestVisit = (donor.Visits__r.size() > 1) ? donor.Visits__r[1] : null;

                    if (!intendedFirstVisit.isFirstVisit__c) {
                        intendedFirstVisit.isFirstVisit__c = true;
                        intendedFirstVisit.Physical_Exam__c = true;
                        intendedFirstVisit.SPE_Analysis__c = true;

                        // Check to see if the nextSoonestVisit was previously marked as a first visit
                        // If it was, we need to unmark it and note that the visit tasks need to be reparented
                        if (nextSoonestVisit != null && nextSoonestVisit.isFirstVisit__c) {
                            nextSoonestVisit.isFirstVisit__c = false;
                            nextSoonestVisit.Physical_Exam__c = false;
                            nextSoonestVisit.SPE_Analysis__c = false;

                            visitRecordsToUpdate.put(nextSoonestVisit.Id, nextSoonestVisit);
                            visitIdToNewTaskParentId.put(nextSoonestVisit.Id, intendedFirstVisit.Id);
                        } else {
                            tasksToCreate.add(new Task(
                                WhatId = intendedFirstVisit.Id,
                                WhoId = donor.Id,
                                Subject = Constants.PHYSICAL_EXAM_TASK_SUBJECT
                            ));

                            tasksToCreate.add(new Task(
                                WhatId = intendedFirstVisit.Id,
                                WhoId = donor.Id,
                                Subject = Constants.SPE_ANALYSIS_TASK_SUBJECT
                            ));

                            tasksToCreate.add(new Task(
                                WhatId = intendedFirstVisit.Id,
                                WhoId = donor.Id,
                                Subject = Constants.FIRST_VISIT_CODE_TASK_SUBJECT,
                                Description = donor.Account.First_Visit_Code__c
                            ));
                        }

                        visitRecordsToUpdate.put(intendedFirstVisit.Id, intendedFirstVisit);
                    } else if (!acceptableFirstVisitOutcomes.contains(intendedFirstVisit.Outcome__c) && nextSoonestVisit != null) {
                        // The soonest visit is no longer a viable first visit, so we need to unmark it
                        intendedFirstVisit.isFirstVisit__c = false;
                        intendedFirstVisit.Physical_Exam__c = false;
                        intendedFirstVisit.SPE_Analysis__c = false;

                        visitRecordsToUpdate.put(intendedFirstVisit.Id, intendedFirstVisit);

                        // Mark the next visit as a first visit
                        nextSoonestVisit.isFirstVisit__c = true;
                        nextSoonestVisit.Physical_Exam__c = true;
                        nextSoonestVisit.SPE_Analysis__c = true;

                        visitRecordsToUpdate.put(nextSoonestVisit.Id, nextSoonestVisit);
                        visitIdToNewTaskParentId.put(nextSoonestVisit.Id, nextSoonestVisit.Id);
                    }
                }
            }

            for(Contact donor : [
                SELECT Id, Account.Days_Until_Annum__pc, Account.Days_until_Triannum__pc, (
                    SELECT Id, Name, Donor__c, Appointment_Datetime__c, Physical_Exam__c, SPE_Analysis__c 
                    FROM Visits__r 
                    ORDER BY Appointment_Datetime__c ASC
                ) 
                FROM Contact 
                WHERE Id IN :donorIds
            ]) {
                Integer closestPhysicalExamDayCount = 999999999;
                Visit__c closestPhysicalExamVisit;

                Integer closestSpeAnalysisDayCount = 999999999;
                Visit__c closestSpeAnalysisVisit;

                List<Visit__c> currentPhysicalExamVisits = new List<Visit__c>();
                List<Visit__c> currentSpeAnalysisVisits = new List<Visit__c>();

                for(Visit__c visit : donor.Visits__r) {
                    // Check for Physical Exam and SPE visit
                    if (donor.Account != null && donor.Account.Days_Until_Annum__pc != null && donor.Account.Days_until_Triannum__pc != null) {
                        Integer daysRemainingUntilVisit = Date.today().daysBetween(visit.Appointment_Datetime__c.date());

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

    public static void updateLastPreviousFields(List<Visit__c> visits) {
        Set<Id> donorIds = new Set<Id>();
        for(Visit__c visit : visits) {
            donorIds.add(visit.Donor__c);
        }

        Map<Id, Contact> donorsToUpdate = new Map<Id, Contact>();
        Map<Id, Boolean> donorIdToFoundLastDonation = new Map<Id, Boolean>(), donorIdToFoundLastPreviousDonation = new Map<Id, Boolean>();
        Map<Id, Boolean> donorIdToFoundLastScheduled = new Map<Id, Boolean>(), donorIdToFoundLastPreviousScheduled = new Map<Id, Boolean>();

        for(Contact donor : [
            SELECT Id, Last_Previous_Donation__c, Last_Previous_Scheduled_Visit__c, (
                SELECT Id, Status__c, Outcome__c 
                FROM Visits__r 
                WHERE (Status__c = 'Complete' AND Outcome__c IN ('Donation', 'No Donation')) OR 
                    Status__c IN ('New', 'Scheduled', 'Checked-In') 
                ORDER BY Appointment_Datetime__c DESC
                LIMIT 4
            ) 
            FROM Contact 
            WHERE Id IN :donorIds
        ]) {
            if (donor.Visits__r != null && donor.Visits__r.size() >= 2) {
                for(Visit__c visit : donor.Visits__r) {
                    // Last Previous Scheduled Visit can be set by any visit that isn't canceled or rescheduled
                    Boolean foundLastScheduled = donorIdToFoundLastScheduled.get(donor.Id);
                    Boolean foundLastPreviousScheduled = donorIdToFoundLastPreviousScheduled.get(donor.Id);
    
                    if (foundLastScheduled != null && foundLastScheduled) {
                        if (foundLastPreviousScheduled != null && foundLastPreviousScheduled) {
                            break;
                        } else {
                            if (donor.Last_Previous_Scheduled_Visit__c == null || donor.Last_Previous_Scheduled_Visit__c != visit.Id) {
                                Contact donorToUpdate = donorsToUpdate.get(donor.Id);
                                if (donorToUpdate == null) {
                                    donorToUpdate = new Contact(Id = donor.Id);
                                }
    
                                donorToUpdate.Last_Previous_Scheduled_Visit__c = visit.Id;
                                donorsToUpdate.put(donor.Id, donorToUpdate);
                            }
    
                            donorIdToFoundLastPreviousScheduled.put(donor.Id, true);
                        }
                    } else {
                        donorIdToFoundLastScheduled.put(donor.Id, true);
                    }
                    
                    if (visit.Status__c == 'Complete' && visit.Outcome__c == 'Donation') {
                        Boolean foundLastDonation = donorIdToFoundLastDonation.get(donor.Id);
                        Boolean foundLastPreviousDonation = donorIdToFoundLastPreviousDonation.get(donor.Id);
    
                        if (foundLastDonation != null && foundLastDonation) {
                            if (foundLastPreviousDonation != null && foundLastPreviousDonation) {
                                break;
                            } else {
                                if (donor.Last_Previous_Donation__c == null || donor.Last_Previous_Donation__c != visit.Id) {
                                    Contact donorToUpdate = donorsToUpdate.get(donor.Id);
                                    if (donorToUpdate == null) {
                                        donorToUpdate = new Contact(Id = donor.Id);
                                    }
    
                                    donorToUpdate.Last_Previous_Donation__c = visit.Id;
                                    donorsToUpdate.put(donor.Id, donorToUpdate);
                                }
    
                                donorIdToFoundLastPreviousDonation.put(donor.Id, true);
                            }
                        } else {
                            donorIdToFoundLastDonation.put(donor.Id, true);
                        }
                    }
                }
            }

            // Check to see if we found valid last scheduled visits
            // If we didn't, clear the Last_Previous_Scheduled_Visit__c field as it's no longer valid
            if ((donorIdToFoundLastScheduled.get(donor.Id) == null || !donorIdToFoundLastScheduled.get(donor.Id)) && donor.Last_Previous_Scheduled_Visit__c != null) {
                Contact donorToUpdate = donorsToUpdate.get(donor.Id);
                if (donorToUpdate == null) {
                    donorToUpdate = new Contact(Id = donor.Id);
                }

                donorToUpdate.Last_Previous_Scheduled_Visit__c = null;
                donorsToUpdate.put(donor.Id, donorToUpdate);
            }
        }

        if (donorsToUpdate.size() > 0) {
            update donorsToUpdate.values();
        }
    }
}