public without sharing class UserCreationQueueable implements Queueable {

    Id centerId;
    Id accountId;
    String userLanguage;
    Id createdUserId;

    public UserCreationQueueable(Id centerId, Id accountId, String userLanguage) {
        this(centerId, accountId, userLanguage, null);
    }

    public UserCreationQueueable(Id centerId, Id accountId, String userLanguage, Id createdUserId) {
        this.centerId = centerId;
        this.accountId = accountId;
        this.userLanguage = userLanguage;
        this.createdUserId = createdUserId;
    }

    public void execute(QueueableContext context) {
        if (String.isEmpty(createdUserId)) {
            Database.DMLOptions userEmailOptions = new Database.DMLOptions();
            userEmailOptions.EmailHeader.triggerUserEmail = true;
            userEmailOptions.EmailHeader.triggerOtherEmail = true;
            userEmailOptions.EmailHeader.triggerAutoResponseEmail = true;

            User user = ProfileController.createUser(centerId, accountId, userLanguage);
            user.setOptions(userEmailOptions);
            insert user;

            ProfileController.assignUserPermissionSet(user.Id);

            if (!Test.isRunningTest()) {
                System.enqueueJob(new UserCreationQueueable(centerId, accountId, userLanguage, user.Id));
            }
        } else {
            update new Account(Id = accountId, User__pc = createdUserId);
        }
    }

}