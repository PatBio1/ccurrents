-- Annual Appointment Reminders
SELECT
c.Id AS SubscriberKey,
c.Email AS Email,
c.FirstName AS FirstName,
c.Last_Physical_Exam_Date__c AS LastPhysicalExamDate,
CONCAT(c.Id,c.Last_Physical_Exam_Date__c) AS MailingKey

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
FROM [Annual Physical Reminder] AS a
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
c.Email AS Email,
v.Appointment_Datetime__c

FROM Visit__c_Salesforce AS v

INNER JOIN Contact_Salesforce AS c
ON v.Donor__c = c.Id

LEFT JOIN
(SELECT VisitId
FROM [Post Visit Satisfaction Email]
)
AS pvse
ON v.Id = pvse.VisitId

WHERE v.Status__c = 'Complete' AND
v.Outcome__c = 'Donation' AND
pvse.VisitId IS NULL AND
DATEDIFF(DAY, GETUTCDATE(), v.Appointment_Datetime__c) = 0

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
cent.Name AS CenterName,
v.SPE_Analysis__c AS SPEAnalysis,
v.Physical_Exam__c AS PhysicalExam,
cent.Site__c AS SiteId

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
Name,
Site__c
FROM Account_Salesforce)
AS cent
ON v.Center__c = cent.Name

LEFT JOIN
(SELECT VisitId
FROM [Appointment Reminder 7 Days]
)
AS ar7d
ON v.Id = ar7d.VisitId

WHERE ar7d.VisitId IS NULL AND
v.Status__c = 'Scheduled' AND
DATEDIFF(DAY, GETUTCDATE(), v.Appointment_Datetime__c) = 7 AND
c.Email IS NOT NULL AND
c.FirstName IS NOT NULL AND
cent.Name IS NOT NULL

-- 72 Hour Appointment Reminder
SELECT v.Donor__c AS SubscriberKey,
v.Id AS VisitId,
v.Appointment_Datetime__c AS AppointmentDateTime,
c.Email AS Email,
c.FirstName AS FirstName,
cent.Name AS CenterName,
v.SPE_Analysis__c AS SPEAnalysis,
v.Physical_Exam__c AS PhysicalExam,
cent.Site__c AS SiteId

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
Name,
Site__c
FROM Account_Salesforce)
AS cent
ON v.Center__c = cent.Name

LEFT JOIN
(SELECT VisitId
FROM [Appointment Reminder 72 Hours]
)
AS ar72
ON v.Id = ar72.VisitId

WHERE ar72.VisitId IS NULL AND
v.Status__c = 'Scheduled' AND
DATEDIFF(DAY, GETUTCDATE(), v.Appointment_Datetime__c) = 3 AND
c.Email IS NOT NULL AND
c.FirstName IS NOT NULL AND
cent.Name IS NOT NULL

-- SPE Reminder
SELECT
c.Id AS SubscriberKey,
c.Email AS Email,
c.FirstName AS FirstName,
c.Last_SPE_Sample_Date__c AS LastSPESampleDate,
CONCAT(c.Id,c.Last_SPE_Sample_Date__c) AS MailingKey

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
FROM [SPE Reminder] AS a
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
cent.Name AS CenterName,
cent.Site__c AS SiteId

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
Name,
Site__c
FROM Account_Salesforce)
AS cent
ON v.Center__c = cent.Name

LEFT JOIN
(SELECT VisitId
FROM [Reschedule Appointment]
)
AS ra
ON v.Id = ra.VisitId

WHERE ra.VisitId IS NULL AND
v.Outcome__c = 'No Show' AND
DATEDIFF(DAY, v.Appointment_Datetime__c, GETUTCDATE()) = 0

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
ll.Name AS LoyaltyLevelName,
yl.Name AS YesterdayLoyaltyLevelName,
IIF(ll.Name <> yl.Name, 1, 0) AS IsLoyaltyChange

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

LEFT JOIN (SELECT yln.SubscriberKey AS Id,
yln.LevelName AS Name
FROM "Yesterday Donor Loyalty Status" AS yln)
AS yl
ON yl.Id = t.Donor__c

WHERE
dpeEmail.TransactionId IS NULL AND
DATEDIFF(DAY, DATEADD(DAY, -7, t.CreatedDate), t.CreatedDate) <= 7

-- Post Donation Survey Response Processing
SELECT DISTINCT p.[Visit Id] AS VisitId,
p.Rating AS Rating,
p.Feedback AS Feedback,
p.SubscriberKey AS SubscriberKey,
mp.DateAdded AS DateAdded

FROM [Post Donation Survey Responses] AS p

LEFT JOIN (SELECT VisitId AS VisitId
FROM [Post Donation Survey Response Processing])
AS pdsrp
ON p.[Visit Id] = pdsrp.VisitId

LEFT JOIN (SELECT m.[Visit Id] AS VisitId,
MAX(m.DateAdded) AS DateAdded
FROM [Post Donation Survey Responses] AS m
GROUP BY m.[Visit Id])
AS mp
ON p.[Visit Id] = mp.VisitId

WHERE pdsrp.VisitId IS NULL AND
mp.VisitId IS NOT NULL

-- Post Donation Survey Response Processing v2
SELECT p.[Visit Id] AS VisitId,
p.Rating AS Rating,
p.Feedback AS Feedback,
p.SubscriberKey AS SubscriberKey,
p.DateAdded AS DateAdded,
p.id AS RecordKey

FROM [Post Donation Survey Responses] AS p

LEFT JOIN (SELECT RecordKey AS RecordKey
FROM [Post Donation Survey Response Processing v2])
AS pdsrp2
ON p.id = pdsrp2.RecordKey

WHERE pdsrp2.RecordKey IS NULL

-- Buddy Referral Lead Email
SELECT cm.LeadOrContactId AS SubscriberKey,
l.FirstName AS FirstName,
l.Email AS Email,
cm.Referring_Contact__c AS ReferringContactId,
cm.Id AS CampaignMemberId,
cm.CampaignId AS CampaignId

FROM CampaignMember_Salesforce AS cm

INNER JOIN (
SELECT Id AS Id,
FirstName AS FirstName,
Email AS Email
FROM Lead_Salesforce)
AS l
ON cm.LeadOrContactId = l.Id

INNER JOIN (
SELECT Id,
External_Id__c
FROM Campaign_Salesforce)
AS c
ON cm.CampaignId = c.Id

LEFT JOIN (
SELECT CampaignMemberId
FROM "Buddy Referral New Lead Emails")
AS br
ON cm.Id = br.CampaignMemberId

WHERE
br.CampaignMemberId IS NULL AND
c.External_Id__c = "1"

-- Yesterday Donor Loyalty Status
SELECT c.Id AS SubscriberKey,
c.Level__c AS LevelId,
l.LevelName AS LevelName,
GETDATE() AS DateUpdated

FROM Contact_Salesforce AS c

INNER JOIN (
SELECT lev.Id AS LevelId,
lev.Name AS LevelName
FROM Level__c_Salesforce AS lev)
AS l
ON c.Level__c = l.LevelId

WHERE Level__c IS NOT NULL

-- Welcome New Donor, v2 (off User)
SELECT u.Id AS UserId,
u.UserName AS UserName,
u.FirstName AS FirstName,
u.Email AS Email,
u.IsActive AS IsActive,
u.ContactId AS SubscriberKey,
p.Name AS ProfileName,
IIF(v.VisitCount > 0, 1, 0) AS HasVisit

FROM User_Salesforce AS u

INNER JOIN (
SELECT Id,
Name
FROM Profile_Salesforce)
AS p
ON u.ProfileId = p.Id

LEFT JOIN
(SELECT SubscriberKey
FROM "Welcome New Donor"
)
AS wnd
ON u.ContactId = wnd.SubscriberKey

LEFT JOIN
(SELECT Donor__c AS Donor,
COUNT(Id) AS VisitCount
FROM Visit__c_Salesforce
GROUP BY Donor__c)
AS v
ON u.ContactId = v.Donor

WHERE
p.Name LIKE 'ProesisCustomer%' AND
u.IsActive = 1 AND
wnd.SubscriberKey IS NULL

-- 6 Visits in a Month Query
SELECT
v.Donor__c AS SubscriberKey,
CONCAT(MONTH(GETDATE()),'-',YEAR(GETDATE())) AS MonthYear,
CONCAT(v.Donor__c,'-', MONTH(GETUTCDATE()),'-',YEAR(GETUTCDATE())) AS MailingKey,
COUNT(v.Id) AS VisitCount,
c.FirstName AS FirstName,
c.Email AS Email

FROM Visit__c_Salesforce AS v

INNER JOIN
(SELECT Id,
FirstName,
Email
FROM Contact_Salesforce)
AS c
ON v.Donor__c = c.Id

WHERE YEAR(v.Appointment_Datetime__c) = YEAR(GETDATE()) AND
MONTH(v.Appointment_Datetime__c) = MONTH(GETDATE()) AND
v.Status__c = 'Complete' AND
v.Outcome__c = 'Donation'

GROUP BY v.Donor__c,
c.FirstName,
c.Email

HAVING COUNT(v.Id) >= 6

-- Appointment Reminder 24 hours
SELECT v.Donor__c AS SubscriberKey,
v.Id AS VisitId,
FORMAT(v.Appointment_Datetime__c, 'MM/dd/yyyy') AS AppointmentDateTime,
c.Email AS Email,
c.FirstName AS FirstName,
cent.Name AS CenterName,
v.SPE_Analysis__c AS SPEAnalysis,
v.Physical_Exam__c AS PhysicalExam,
cent.Site__c AS SiteId

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
Name,
Site__c
FROM Account_Salesforce)
AS cent
ON v.Center__c = cent.Name

LEFT JOIN
(SELECT VisitId
FROM [Appointment Reminder 24 Hours]
)
AS ar24
ON v.Id = ar24.VisitId

WHERE ar24.VisitId IS NULL AND
v.Status__c = 'Scheduled' AND
DATEDIFF(DAY, GETUTCDATE(), v.Appointment_Datetime__c) = 1 AND
c.Email IS NOT NULL AND
c.FirstName IS NOT NULL AND
cent.Name IS NOT NULL

-- New Donor Program Query (1st Donation)
SELECT DISTINCT c.Email AS Email,
c.FirstName AS FirstName,
v.Donor__c AS SubscriberKey,
MIN(v.Appointment_Datetime__c) AS ApptDateTime,
MIN(v.Id) AS VisitId

FROM Visit__c_Salesforce AS v

INNER JOIN
(SELECT Id,
FirstName,
Email,
Total_Donations__c,
isLegacyDonor__c,
CreatedDate
FROM Contact_Salesforce
)
AS c
ON v.Donor__c = c.Id

LEFT JOIN
(SELECT SubscriberKey
FROM [NDP First Donation]
)
AS ndp1
ON v.Donor__c = ndp1.SubscriberKey

WHERE v.Status__c = 'Complete' AND
v.Outcome__c = 'Donation' AND
ndp1.SubscriberKey IS NULL AND
c.Total_Donations__c = 1 AND
c.isLegacyDonor__c = 0 AND
c.CreatedDate >=  DATEFROMPARTS(2023, 06, 01)

GROUP BY c.FirstName,
c.Email,
v.Donor__c

--- 6 Donations / Month
SELECT a.SubscriberKey AS SubscriberKey,
a.MonthYear AS MonthYear,
a.MailingKey AS MailingKey,
a.VisitCount AS VisitCount,
a.FirstName AS FirstName,
a.Email AS Email

FROM [Donors with 6 or More Donations By Month] AS a

LEFT JOIN (
SELECT MailingKey
FROM [6 Donations Per Month]
)
AS b
ON a.MailingKey = b.MailingKey

WHERE b.MailingKey IS NULL

-- Buddy Referral Payments
SELECT a.Id AS CampaignMemberId,
a.CampaignId AS CampaignId,
a.Referring_Contact__c AS SubscriberKey,
a.FirstName AS ReferralFirstName,
c.FirstName AS FirstName,
c.Email AS Email,
100 AS AwardAmount

FROM CampaignMember_Salesforce AS a

INNER JOIN (
SELECT Id
FROM Campaign_Salesforce
WHERE External_Id__c = 3)
AS b
ON a.CampaignId = b.Id

INNER JOIN
(SELECT Id,
FirstName,
Email
FROM Contact_Salesforce)
AS c
ON a.Referring_Contact__c = c.Id

LEFT JOIN(
SELECT CampaignMemberId
FROM [Buddy Referral Contact Payments]
)
AS d
ON a.Id = d.CampaignMemberId

WHERE d.CampaignMemberId IS NULL AND
a.Total_Eligible_Donation_Count__c >= 2 AND
a.Incentive_Eligible__c = 1
