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

-- Donor Visit Metrics (Large query failing in SFMC - retaining in case support fixes Case #44344859
SELECT c.Id AS SubscriberKey,
s.VisitCount AS CountScheduled,
s.NextScheduleDate AS NextScheduleDate,
s.LatestScheduledDate AS LatestScheduledDate,
d.TotalDonations AS CountTotalDonations,
d.FirstDonationDate AS FirstDonationDate,
d.LastDonationDate AS LastDonationDate,
d2.TotalDonations AS CountDonationsLast365Days

FROM Contact_Salesforce AS c

INNER JOIN
(SELECT v.Donor__c AS DonorId
FROM Visit__c_Salesforce AS v
)
AS allv
ON c.Id = allv.DonorId

-- Lifetime Metrics
LEFT JOIN
(SELECT v2.Donor__c AS DonorId,
COUNT(Id) AS VisitCount,
MIN(Appointment_Datetime__c) AS NextScheduleDate,
MAX(Appointment_Datetime__c) AS LatestScheduledDate
FROM Visit__c_Salesforce AS v2
WHERE v2.Status__c = 'Scheduled'
GROUP BY v2.Donor__c
)
AS s
ON c.Id = s.DonorId

LEFT JOIN
(SELECT v3.Donor__c AS DonorId,
Count(Id) AS TotalDonations,
MIN(Appointment_Datetime__c) AS FirstDonationDate,
MAX(Appointment_Datetime__c) AS LastDonationDate
FROM Visit__c_Salesforce AS v3
WHERE v3.Outcome__c = 'Donation'
GROUP BY v3.Donor__c
)
AS d
ON c.Id = d.DonorId

-- Last 365 Days
LEFT JOIN
(SELECT v4.Donor__c AS DonorId,
Count(Id) AS TotalDonations
FROM Visit__c_Salesforce AS v4
WHERE v4.Outcome__c = 'Donation' AND
v4.Appointment_Datetime__c >= DATEADD(DAY, -365, GETUTCDATE())
GROUP BY v4.Donor__c
)
AS d2
ON c.Id = d2.DonorId

-- Standalone Donations Last 365 Days
SELECT v4.Donor__c AS SubscriberKey,
Count(Id) AS CountDonationsLast365Days
FROM Visit__c_Salesforce AS v4
WHERE v4.Outcome__c = 'Donation' AND
v4.Appointment_Datetime__c >= DATEADD(DAY, -365, GETUTCDATE())
GROUP BY v4.Donor__c

-- Standalone Lifetime Donations
SELECT v3.Donor__c AS SubscriberKey,
Count(Id) AS CountTotalDonations,
MIN(Appointment_Datetime__c) AS FirstDonationDate,
MAX(Appointment_Datetime__c) AS LastDonationDate
FROM Visit__c_Salesforce AS v3
WHERE v3.Outcome__c = 'Donation'
GROUP BY v3.Donor__c

-- Standalone Scheduled Visits
SELECT v2.Donor__c AS SubscriberKey,
COUNT(Id) AS CountScheduled,
MIN(Appointment_Datetime__c) AS NextScheduledDate,
MAX(Appointment_Datetime__c) AS LatestScheduledDate
FROM Visit__c_Salesforce AS v2
WHERE v2.Status__c = 'Scheduled'
GROUP BY v2.Donor__c

-- Post Visit Satisfaction Email
SELECT v.Id AS VisitId,
v.Donor__c AS SubscriberKey,
c.FirstName AS FirstName,
c.Email AS Email

FROM Visit__c_Salesforce AS v

INNER JOIN Contact_Salesforce AS c
ON v.Id = c.Id

LEFT JOIN
(SELECT VisitId
FROM "Post Visit Satisfaction Email"
)
AS pvse
ON v.Id = pvse.VisitId

WHERE v.Status__c = 'Complete' AND
v.Outcome__c = 'Donation' AND
pvse.VisitId IS NULL

-- Welcome New Donor
SELECT c.Id AS SubscriberKey,
v.Id AS VisitId,
c.FirstName AS FirstName,
c.Email AS Email

FROM Visit__c_Salesforce AS v

INNER JOIN Contact_Salesforce AS c
ON v.Donor__c = c.Id

LEFT JOIN
(SELECT SubscriberKey
FROM "Welcome New Donor"
)
AS wnd
ON v.Donor__c = wnd.SubscriberKey

WHERE
v.Status__c = 'Scheduled' AND
v.isFirstVisit__c = 1 AND
wnd.SubscriberKey IS NULL

-- 7 Day Appointment Reminder
SELECT v.Donor__c AS SubscriberKey,
v.Id AS VisitId,
v.Appointment_Datetime__c AS AppointmentDateTime,
c.Email AS Email,
c.FirstName AS FirstName,
cent.Name AS CenterName

FROM Visit__c_Salesforce as v

INNER JOIN
(SELECT Id,
Email,
FirstName
FROM Contact_Salesforce
WHERE Enable_Appointment_Reminders__c = 1
)
AS c
ON v.Donor__c = c.Id

INNER JOIN
(SELECT Id,
Name
FROM Account_Salesforce)
AS cent
ON v.Center__c = cent.Id

LEFT JOIN
(SELECT VisitId
FROM "Appointment Reminder 7 Days"
)
AS ar7
ON v.Id = ar7.VisitId

WHERE ar7.VisitId IS NULL AND
v.Status__c = 'Scheduled' AND
DATEDIFF(DAY, v.Appointment_Datetime__c, GETUTCDATE()) = 7

-- 72 Hour Appointment Reminder
SELECT v.Donor__c AS SubscriberKey,
v.Id AS VisitId,
v.Appointment_Datetime__c AS AppointmentDateTime,
c.Email AS Email,
c.FirstName AS FirstName,
cent.Name AS CenterName

FROM Visit__c_Salesforce as v

INNER JOIN
(SELECT Id,
Email,
FirstName
FROM Contact_Salesforce
WHERE Enable_Appointment_Reminders__c = 1
)
AS c
ON v.Donor__c = c.Id

INNER JOIN
(SELECT Id,
Name
FROM Account_Salesforce)
AS cent
ON v.Center__c = cent.Id

LEFT JOIN
(SELECT VisitId
FROM "Appointment Reminder 72 Hours"
)
AS ar72
ON v.Id = ar72.VisitId

WHERE ar72.VisitId IS NULL AND
v.Status__c = 'Scheduled' AND
DATEDIFF(DAY, v.Appointment_Datetime__c, GETUTCDATE()) = 3

-- 24 Hour Appointment Reminder
SELECT v.Donor__c AS SubscriberKey,
v.Id AS VisitId,
v.Appointment_Datetime__c AS AppointmentDateTime,
c.Email AS Email,
c.FirstName AS FirstName,
cent.Name AS CenterName

FROM Visit__c_Salesforce as v

INNER JOIN
(SELECT Id,
Email,
FirstName
FROM Contact_Salesforce
WHERE Enable_Appointment_Reminders__c = 1
)
AS c
ON v.Donor__c = c.Id

INNER JOIN
(SELECT Id,
Name
FROM Account_Salesforce)
AS cent
ON v.Center__c = cent.Id

LEFT JOIN
(SELECT VisitId
FROM "Appointment Reminder 24 Hours"
)
AS ar24
ON v.Id = ar24.VisitId

WHERE ar24.VisitId IS NULL AND
v.Status__c = 'Scheduled' AND
DATEDIFF(DAY, v.Appointment_Datetime__c, GETUTCDATE()) = 3

-- SPE Reminder
SELECT
c.Id AS SubscriberKey,
c.Email AS Email,
c.FirstName AS FirstName,
c.Last_SPE_Sample_Date__c AS LastSPESampleDate

FROM Contact_Salesforce AS c

LEFT JOIN
(SELECT v.Donor__c
FROM Visit__c_Salesforce AS v
WHERE v.Appointment_Datetime__c > GETDATE()
AND v.SPE_Analysis__c = 1)
AS vis
ON vis.Donor__c = c.Id

LEFT JOIN
(SELECT a.SubscriberKey
FROM "SPE Reminder" AS a
WHERE DATEDIFF(DAY, GETDATE(), a.DateAdded) < 28)
AS apr
ON apr.SubscriberKey = c.Id

WHERE DATEDIFF(DAY, GETDATE(), DATEADD(YEAR, 1, c.Last_Physical_Exam_Date__c)) = 28 AND
vis.Donor__c IS NULL AND
apr.SubscriberKey IS NULL

-- Reschedule Appointment
SELECT v.Donor__c AS SubscriberKey,
v.Id AS VisitId,
v.Appointment_Datetime__c AS AppointmentDateTime,
c.Email AS Email,
c.FirstName AS FirstName,
cent.Name AS CenterName

FROM Visit__c_Salesforce as v

LEFT JOIN
(SELECT Id,
Email,
FirstName
FROM Contact_Salesforce
)
AS c
ON v.Donor__c = c.Id

INNER JOIN
(SELECT Id,
Name
FROM Account_Salesforce)
AS cent
ON v.Center__c = cent.Id

LEFT JOIN
(SELECT VisitId
FROM "Reschedule Appointment"
)
AS ra
ON v.Id = ra.VisitId

WHERE ra.VisitId IS NULL AND
v.Outcome__c = 'No Show'

-- Donation Payment

SELECT t.Id AS TransactionId,
t.Donor__c AS SubscriberKey,
t.Amount_Currency__c AS TotalPayment,
t.Amount_Points__c AS TotalPoints,
dp.TotalAmount AS DonationPayment,
dp2.TotalAmount AS DonationPoints,
bp.TotalAmount AS BonusPayment,
bp2.TotalAmount AS BonusPoints,
tp.TotalAmount AS ThresholdPayment,
tp2.TotalAmount AS ThresholdPoints,
ct.FirstName AS FirstName,
ct.LastName AS LastName,
ct.Email AS Email,
ct.Enable_Email__c AS EnableEmail,
ct.Enable_Payment_Notifications__c AS EnablePaymentNotifications,
ct.Loyalty_Level__c AS LoyaltyLevelId,
ll.Name AS LoyaltyLevelName

FROM Transaction__c_Salesforce AS t

LEFT JOIN (SELECT txn1.Transaction__c AS TransactionId,
SUM(txn1.Total__c) AS TotalAmount
FROM Txn_Line_Item__c_Salesforce AS txn1
WHERE txn1.Item__c = 'Donation Payment'
GROUP BY txn1.Transaction__c
) AS dp
ON t.Id = dp.TransactionId

LEFT JOIN (SELECT txn2.Transaction__c AS TransactionId,
SUM(txn2.Total__c) AS TotalAmount
FROM Txn_Line_Item__c_Salesforce AS txn2
WHERE txn2.Item__c = 'Donation Points'
GROUP BY txn2.Transaction__c
) AS dp2
ON t.Id = dp2.TransactionId

LEFT JOIN (SELECT txn3.Transaction__c AS TransactionId,
SUM(txn3.Total__c) AS TotalAmount
FROM Txn_Line_Item__c_Salesforce AS txn3
WHERE txn3.Item__c LIKE '%Bonus Payment'
GROUP BY txn3.Transaction__c
) AS bp
ON t.Id = bp.TransactionId

LEFT JOIN (SELECT txn4.Transaction__c AS TransactionId,
SUM(txn4.Total__c) AS TotalAmount
FROM Txn_Line_Item__c_Salesforce AS txn4
WHERE txn4.Item__c LIKE '%Bonus Points'
GROUP BY txn4.Transaction__c
) AS bp2
ON t.Id = bp2.TransactionId

LEFT JOIN (SELECT txn5.Transaction__c AS TransactionId,
SUM(txn5.Total__c) AS TotalAmount
FROM Txn_Line_Item__c_Salesforce AS txn5
WHERE txn5.Item__c = 'Threshold Payment'
GROUP BY txn5.Transaction__c
) AS tp
ON t.Id = tp.TransactionId

LEFT JOIN (SELECT txn6.Transaction__c AS TransactionId,
SUM(txn6.Total__c) AS TotalAmount
FROM Txn_Line_Item__c_Salesforce AS txn6
WHERE txn6.Item__c = 'Threshold Points'
GROUP BY txn6.Transaction__c
) AS tp2
ON t.Id = tp2.TransactionId

INNER JOIN (SELECT c.Id,
c.FirstName,
c.LastName,
c.Email,
c.Enable_Email__c,
c.Enable_Payment_Notifications__c,
c.Loyalty_Level__c
FROM Contact_Salesforce AS c)
AS ct
ON t.Donor__c = ct.Id

LEFT JOIN (SELECT l.Id,
l.Name
FROM Level__c_Salesforce AS l)
AS ll
ON ct.Loyalty_Level__c = ll.Id

LEFT JOIN (SELECT dpe.TransactionId
FROM "Donor Payment" AS dpe)
AS dpeEmail
ON t.Id = dpeEmail.TransactionId

WHERE
dpeEmail.TransactionId IS NULL AND
DATEDIFF(DAY, DATEADD(DAY, -7, t.CreatedDate), t.CreatedDate) <= 7
