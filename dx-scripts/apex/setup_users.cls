User guestUser = [SELECT Id FROM User WHERE Name = 'Proesis Donor Site Guest User'];
PermissionSet guestPermissionSet = [SELECT Id FROM PermissionSet WHERE Label = :Constants.EXPERIENCE_GUEST_PERMISSION_SET_NAME];

PermissionSetAssignment psa = new PermissionSetAssignment(
    PermissionSetId = guestPermissionSet.Id,
    AssigneeId = guestUser.Id
);
insert psa;

User adminUser = [SELECT Id FROM User WHERE Name = 'User User'];
UserRole ceoUserRole = [SELECT Id FROM UserRole WHERE Name = 'CEO'];

adminUser.UserRoleId = ceoUserRole.Id;
update adminUser;