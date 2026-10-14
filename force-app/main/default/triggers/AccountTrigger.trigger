trigger AccountTrigger on Account (before insert, before update) {
    // One trigger per object; logic lives in the service class.
    AccountService.applyRating(Trigger.new);
}
