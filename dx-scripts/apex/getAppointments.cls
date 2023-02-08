Id centerId = [SELECT Id from Account WHERE Name = 'Proesis Miramar'].Id;
CenterScheduleController.AppointmentSlot[] slots = CenterScheduleController.getAppointments(centerId, Date.today());

for(CenterScheduleController.AppointmentSlot slot: slots){
    if(slot.visits.size() > 0){
        system.debug(slot);
    }
}