trigger AccountTrigger on Account (before insert, before update) {
    // One trigger per object; logic lives in the service class.
    AccountService.applyRating(Trigger.new);
<<<<<<< HEAD
}
=======
}
>>>>>>> e2ebfe99cf78b1317530f1b9f387511ea1b525ca
