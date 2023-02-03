public with sharing class CenterScheduleController {
    
    @AuraEnabled
    public static Center[] getCenters(){
        Center[] centers = new Center[]{};
        try {

            for( Account a: [
                Select Id, Name 
                FROM Account 
                WHERE RecordType.DeveloperName = 'Center'
            ]){
                centers.add(new Center(a));
            }
            return centers;
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class Center {

        @AuraEnabled
        public Id value {get; set;}

        @AuraEnabled
        public String label {get; set;}

        public Center(Account a){
            this.value = a.id;
            this.label = a.name;
        }
    }
}