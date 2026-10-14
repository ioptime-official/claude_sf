public with sharing class AccountService {
    public static final Decimal HOT_THRESHOLD = 10000000;
    public static final Decimal WARM_THRESHOLD = 1000000;

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
                acc.Rating = 'Cold';
            }
        }
    }

    public static final String OWNER_CHANGE_NOTE = 'Owner was recently changed. Previous account owner: ';
    public static final Integer DESCRIPTION_MAX_LENGTH = 32000;

    /**
     * Before update: when OwnerId changes, prepends a note naming the previous owner to
     * Description, keeping existing text. One User query per batch; caller performs the DML.
     */
    public static void recordOwnerChange(List<Account> accounts, Map<Id, Account> oldMap) {
        if (accounts == null || oldMap == null) {
            return;
        }
        Map<Id, Id> previousOwnerByAccount = new Map<Id, Id>();
        for (Account acc : accounts) {
            Account old = oldMap.get(acc.Id);
            if (old != null && old.OwnerId != null && acc.OwnerId != old.OwnerId) {
                previousOwnerByAccount.put(acc.Id, old.OwnerId);
            }
        }
        if (previousOwnerByAccount.isEmpty()) {
            return;
        }
        // No WITH USER_MODE on purpose: FLS on User.Name is not enforced so the note can name the
        // previous owner; Users hidden by sharing are not returned and fall back to the Id below.
        Set<Id> previousOwnerIds = new Set<Id>(previousOwnerByAccount.values());
        Map<Id, User> owners = new Map<Id, User>(
            [SELECT Name FROM User WHERE Id IN :previousOwnerIds]
        );
        for (Account acc : accounts) {
            Id previousOwnerId = previousOwnerByAccount.get(acc.Id);
            if (previousOwnerId == null) {
                continue;
            }
            User previousOwner = owners.get(previousOwnerId);
            String ownerName = previousOwner != null ? previousOwner.Name : String.valueOf(previousOwnerId);
            String note = OWNER_CHANGE_NOTE + ownerName;
            String description = String.isBlank(acc.Description) ? note : note + '\n' + acc.Description;
            acc.Description = description.left(DESCRIPTION_MAX_LENGTH);
        }
    }
}