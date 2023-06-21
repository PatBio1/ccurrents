public with sharing class Util {

    public static DateTime getTimeZoneDateTime(Date dt, Time tm, String tz) {
        Datetime gmtDateTime = Datetime.newInstanceGmt(dt, tm);

        Integer offset = Timezone.getTimezone(tz).getoffset(gmtDateTime) / 1000;

        return gmtDateTime.addSeconds(-offSet);
    }

    public static Date getTimeZoneDate(DateTime dt, String tz) {
        Integer centerYear = Integer.valueOf(dt.format('yyyy', tz));
        Integer centerMonth = Integer.valueOf(dt.format('M', tz));
        Integer centerDay = Integer.valueOf(dt.format('d', tz));

        return Date.newInstance(centerYear, centerMonth, centerDay);
    }

    public static Time getTimeZoneTime(DateTime dt, String tz) {
        Integer centerHour = Integer.valueOf(dt.format('H', tz));
        Integer centerMinute = Integer.valueOf(dt.format('m', tz));
        Integer centerSecond = Integer.valueOf(dt.format('s', tz));

        return Time.newInstance(centerHour, centerMinute, centerSecond, 0);
    }

    public static String generateVerificationCode() {
        String verificationCode = '';

        // 6 digits long.
        for (Integer i = 0; i < 6; i++) {
            // Only digits 1 - 9 so that "o" and zero don't get confused.
            Double digit = Math.floor(Math.random() * 9) + 1;
            verificationCode += digit.intValue();
        }

        return verificationCode;
    }

    public static Id getOrgWideEmailAddress(String displayName) {
        return (Test.isRunningTest() ? null : [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName = :displayName].Id);
    }

    public static AuraHandledException createAuraHandledException(Exception e) {
        if (e instanceof AuraHandledException) {
            return (AuraHandledException) e;
        } else {
            String message = e.getMessage() + ' -- ' + e.getStackTraceString();

            AuraHandledException ahe = new AuraHandledException(message);
            ahe.setMessage(message);
            return ahe;
        }
    }

    public static void testExceptionHandling() {
        if (TestUtil.throwException) {
            throw new TestUtil.TestException();
        }
    }

}