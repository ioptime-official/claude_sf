trigger CaseTrigger on Case (before insert) {
    CaseRouter.setPriority(Trigger.new);
}