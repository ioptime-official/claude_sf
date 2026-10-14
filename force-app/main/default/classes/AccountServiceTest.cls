@IsTest
private class AccountServiceTest {
    @IsTest
    static void applyRating_setsRatingByRevenueBands() {
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Big', AnnualRevenue = 20000000),
            new Account(Name = 'Mid', AnnualRevenue = 5000000),
            new Account(Name = 'Small', AnnualRevenue = 10)
        };
        Test.startTest();
        AccountService.applyRating(accounts);
        Test.stopTest();
        System.assertEquals('Hot', accounts[0].Rating);
        System.assertEquals('Warm', accounts[1].Rating);
        System.assertEquals('Undefined', accounts[2].Rating);
    }

    @IsTest
    static void applyRating_handlesBulk200() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(new Account(Name = 'Acct ' + i, AnnualRevenue = 20000000));
        }
        Test.startTest();
        AccountService.applyRating(accounts);
        Test.stopTest();
        for (Account a : accounts) {
            System.assertEquals('Hot', a.Rating);
        }
    }

    @IsTest
    static void applyRating_ignoresNullRevenueAndNullList() {
        Account noRevenue = new Account(Name = 'None');
        AccountService.applyRating(new List<Account>{ noRevenue });
        AccountService.applyRating(null);
        System.assertEquals(null, noRevenue.Rating);
    }

    @IsTest
    static void applyRating_bandBoundaries() {
        List<Decimal> revenues = new List<Decimal>{ 0, 999999, 1000000, 9999999, 10000000 };
        List<String> expected = new List<String>{ 'Undefined', 'Undefined', 'Warm', 'Warm', 'Hot' };
        List<Account> accounts = new List<Account>();
        for (Decimal revenue : revenues) {
            accounts.add(new Account(Name = 'Boundary ' + revenue, AnnualRevenue = revenue));
        }
        AccountService.applyRating(accounts);
        for (Integer i = 0; i < accounts.size(); i++) {
            System.assertEquals(expected[i], accounts[i].Rating, 'Revenue ' + revenues[i]);
        }
    }
}
