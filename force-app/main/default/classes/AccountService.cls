public with sharing class AccountService {
    public static final Decimal HOT_THRESHOLD = 10000000;
    public static final Decimal WARM_THRESHOLD = 1000000;
    public static final Integer DESCRIPTION_MAX = 32000;

    /**
     * Sets Rating from AnnualRevenue. Operates in memory only (no SOQL/DML),
     * so it is safe for 200-record trigger batches. Caller performs the DML.
     */
    public static void applyRating(List<Account> accounts) {
        if (accounts == null) {
            return;
        }
        for (Account acc : accounts) {
            if (acc.AnnualRevenue == null) {
                continue;
            }
            if (acc.AnnualRevenue >= HOT_THRESHOLD) {
                acc.Rating = 'Hot';
            } else if (acc.AnnualRevenue >= WARM_THRESHOLD) {
                acc.Rating = 'Warm';
            } else {
                acc.Rating = 'Undefined';
            }
        }
    }

    /**
     * On update, when OwnerId changed, appends a note naming the previous owner to Description.
     * One SOQL on User for the whole batch. Caller performs the DML (before trigger).
     */
    public static void noteOwnerChanges(List<Account> accounts, Map<Id, Account> oldMap) {
        if (accounts == null || oldMap == null) {
            return;
        }
        List<Account> changed = new List<Account>();
        Set<Id> oldOwnerIds = new Set<Id>();
        for (Account acc : accounts) {
            Account old = oldMap.get(acc.Id);
            if (old != null && acc.OwnerId != old.OwnerId) {
                changed.add(acc);
                oldOwnerIds.add(old.OwnerId);
            }
        }
        if (changed.isEmpty()) {
            return;
        }
        Map<Id, User> owners = new Map<Id, User>([SELECT Id, Name FROM User WHERE Id IN :oldOwnerIds WITH USER_MODE]);
        String today = String.valueOf(Date.today());
        for (Account acc : changed) {
            Id oldOwnerId = oldMap.get(acc.Id).OwnerId;
            User oldOwner = owners.get(oldOwnerId);
            String who = oldOwner != null ? oldOwner.Name : String.valueOf(oldOwnerId);
            String note = 'Owner changed recently. Previous owner: ' + who + ' (' + today + ')';
            String existing = String.isBlank(acc.Description) ? '' : acc.Description + '\n';
            String combined = existing + note;
            if (combined.length() <= DESCRIPTION_MAX) {
                acc.Description = combined;
            }
        }
    }
}
