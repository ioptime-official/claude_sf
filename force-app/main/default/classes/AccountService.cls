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
}
