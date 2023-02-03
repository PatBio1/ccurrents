//@RestResource(urlMapping='/Donor/*')
global without sharing class DonorService {
/*
    global class DonorClass {
        public String donor_number;
        public String enroll_id;
        public String birthdate;
        public String last_name;
        public String first_name;
        public String middle_name;
        public String address_line1;
        public String address_line2;
        public String primary_phone;
        public String secondary_phone;
        public String city; 
        public String state;
        public String zipcode;
        public String height;
        public String weight;
        public String ethnicity;
        public String language;
        public Datetime eligibility_datetime;

        public DonorClass(  String donor_number, String enroll_id, String birthdate, String last_name, String first_name, 
                String middle_name, String address_line1, String address_line2, String primary_phone, String secondary_phone, 
                String city, String state, String zipcode, String height, String weight, String ethnicity, String language, 
                Datetime eligibility_datetime) {
                    this.enroll_id = enroll_id;
                    this.birthdate = birthdate;
                    this.last_name = last_name;
                    this.first_name = first_name;
                    this.middle_name = middle_name;
                    this.address_line1 = address_line1;
                    this.address_line2 = address_line2;
                    this.primary_phone = primary_phone;
                    this.secondary_phone = secondary_phone;
                    this.city = city; 
                    this.state = state;
                    this.zipcode = zipcode;
                    this.height = height;
                    this.weight = weight;
                    this.ethnicity = ethnicity;
                    this.language = language;
                    this.eligibility_datetime = eligibility_datetime;
            }
    }

      @HttpPut
      global static String doPut(
        String donor_number,
        String enroll_id,
        String birthdate,
        String last_name,
        String first_name,
        String middle_name,
        String address_line1,
        String address_line2,
        String primary_phone,
        String secondary_phone,
        String city, 
        String state,
        String zipcode,
        String height,
        String weight,
        String ethnicity,
        String language,
        Datetime eligibility_datetime ) {
            DonorClass dc = new DonorClass(
                donor_number,
                enroll_id,
                birthdate,
                last_name,
                first_name,
                middle_name,
                address_line1,
                address_line2,
                primary_phone,
                secondary_phone,
                city, 
                state,
                zipcode,
                height,
                weight,
                ethnicity,
                language,
                eligibility_datetime
            );
            return JSON.serialize(dc, true);
        // For the moment we are merely returning the values passed in
        // A future version will check if entroll_id is not null in the call, and 1) if not null it will 
        // be used to find the new donor and update with the payload values particularly the donor_number (DonorID)
        // otherwise 2) the donor_number will be used to update the existing Donor as an external_ID from the BECS/Nexlynk system
    }
*/
}
