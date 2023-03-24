-- Annual Appointment Reminders
SELECT
c.Id AS SubscriberKey,
c.Email AS Email,
c.FirstName AS FirstName,
c.Last_Physical_Exam_Date__c AS LastPhysicalExamDate

FROM Contact_Salesforce AS c

LEFT JOIN
(SELECT v.Donor__c
FROM Visit__c_Salesforce AS v
WHERE v.Appointment_Datetime__c > GETDATE()
AND v.Physical_Exam__c = 0)
AS vis
ON vis.Donor__c = c.Id

LEFT JOIN
(SELECT a.SubscriberKey
FROM "Annual Physical Reminder" AS a
WHERE DATEDIFF(DAY, GETDATE(), a.DateAdded) < 28)
AS apr
ON apr.SubscriberKey = c.Id

WHERE DATEDIFF(DAY, GETDATE(), DATEADD(YEAR, 1, c.Last_Physical_Exam_Date__c)) = 28 AND
vis.Donor__c IS NULL AND
apr.SubscriberKey IS NULL

-- Apology Campaign
SELECT v.Donor__c AS SubscriberKey,
c.Email AS Email,
c.Firstname AS FirstName,
v.Id AS VisitId,
cdt.Center__c AS CenterId,
cent.Apology_Campaign_Payment_Amount__c AS CompensationAmount

FROM Visit__c_Salesforce AS v

INNER JOIN Contact_Salesforce AS c
ON c.Id = v.Donor__c

INNER JOIN Account_Salesforce AS cent
ON cent.Id = v.Center__c

INNER JOIN Center_Donation_Type__c_Salesforce AS cdt
ON cdt.Center__c = cent.Id

LEFT JOIN
(SELECT a.VisitId
FROM "Apology Campaign" AS a)
AS ac
ON ac.VisitId = v.Id

WHERE ac.VisitId IS NULL
AND v.Cycle_Time__c > cent.Apology_Campaign_Time_Threshold__c
AND cent.Apology_Campaign_Active__c = 1