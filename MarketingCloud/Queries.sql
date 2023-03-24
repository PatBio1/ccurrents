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

-- 