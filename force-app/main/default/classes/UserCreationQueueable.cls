public with sharing class UserCreationQueueable implements Queueable {
    String accountId;
    String userLanguage;
    String createdUserId;

    public UserCreationQueueable(String accountId, String userLanguage) {
        this(accountId, userLanguage, null);
    }

    public UserCreationQueueable(String accountId, String userLanguage, String createdUserId) {
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

            User user = ProfileController.createUser(accountId, userLanguage);
            user.setOptions(userEmailOptions);
            insert user;

            ProfileController.assignUserPermissionSet(user.Id);

            if (!Test.isRunningTest()) {
                System.enqueueJob(new UserCreationQueueable(accountId, userLanguage, user.Id));
            }
        } else {
            update new Account(Id = accountId, User__pc = createdUserId);
        }
    }
}