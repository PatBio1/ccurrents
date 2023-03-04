public without sharing class CenterController {

    public static final Map<Decimal, String> BUSINESS_HOURS_INDEX_DAYS = new Map<Decimal, String>{
        1 => Label.Sunday,
        2 => Label.Monday,
        3 => Label.Tuesday,
        4 => Label.Wednesday,
        5 => Label.Thursday,
        6 => Label.Friday,
        7 => Label.Saturday
    };

    @AuraEnabled
    public static List<Center> getCenters(Double latitude, Double longitude) {
        try {
            Util.testExceptionHandling();

            List<Account> accounts = [
                SELECT
                    Name, BillingStreet, Geolocation__c
                FROM
                    Account
                WHERE
                    RecordTypeId = :Constants.CENTER_RECORD_TYPE_ID
                AND
                    IsActive__c = true
                ORDER BY
                    DISTANCE(Geolocation__c, GEOLOCATION(:latitude, :longitude), 'mi')
                LIMIT
                    5
            ];

            List<Center> centers = new List<Center>();

            for (Account account : accounts) {
                Center center = new Center();
                center.id = account.Id;
                center.name = account.Name;
                center.address = account.BillingStreet;
                center.distance = Decimal.valueOf(Location.getDistance(account.Geolocation__c, Location.newInstance(latitude, longitude), 'mi')).setScale(1);
                center.distanceUnit = 'mi';
                centers.add(center);
            }

            return centers;
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static Center getCenter(Id centerId) {
        try {
            Util.testExceptionHandling();

            Account account = [
                SELECT
                    Name, BillingStreet, Geolocation__c,
                    (SELECT Index__c, Open__c, Close__c, isClosed__c FROM Business_Hours__r ORDER BY Index__c ASC)
                FROM
                    Account
                WHERE
                    Id = :centerId
            ];

            Center center = new Center();
            center.id = account.Id;
            center.name = account.Name;
            center.address = account.BillingStreet;

            for (Business_Hours__c bizHours : account.Business_Hours__r) {
                BusinessHours businessHours = new BusinessHours();
                businessHours.day = BUSINESS_HOURS_INDEX_DAYS.get(bizHours.Index__c);
                if (bizHours.Open__c != null) {
                    businessHours.open = DateTime.newInstance(Date.today(), bizHours.Open__c).format('h:mm a');
                }
                if (bizHours.Close__c != null) {
                    businessHours.close = DateTime.newInstance(Date.today(), bizHours.Close__c).format('h:mm a');
                }
                businessHours.isClosed = bizHours.isClosed__c;
                center.businessHoursList.add(businessHours);
            }

            return center;
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static LatLong getLatLong(String postalCode) {
        try {
            Util.testExceptionHandling();

            List<Postal_Code__c> postalCodeRecords = [
                SELECT
                    Location__c
                FROM
                    Postal_Code__c
                WHERE
                    Name = :postalCode
                LIMIT
                    1
            ];

            if (postalCodeRecords.size() > 0) {
                Location location = postalCodeRecords[0].Location__c;

                LatLong latLong = new LatLong();
                latLong.latitude = location.latitude;
                latLong.longitude = location.longitude;

                return latLong;
            } else {
                return null;
            }
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    public class Center {

        @AuraEnabled
        public Id id {get; set;}

        @AuraEnabled
        public String name {get; set;}

        @AuraEnabled
        public String address {get; set;}

        @AuraEnabled
        public Decimal distance {get; set;}

        @AuraEnabled
        public String distanceUnit {get; set;}

        @AuraEnabled
        public List<BusinessHours> businessHoursList {get; set;}

        public Center() {
            businessHoursList = new List<BusinessHours>();
        }

    }

    public class BusinessHours {

        @AuraEnabled
        public String day {get; set;}

        @AuraEnabled
        public String open {get; set;}

        @AuraEnabled
        public String close {get; set;}

        @AuraEnabled
        public Boolean isClosed {get; set;}
    }

    public class LatLong {

        @AuraEnabled
        public Double latitude {get; set;}

        @AuraEnabled
        public Double longitude {get; set;}

    }

}