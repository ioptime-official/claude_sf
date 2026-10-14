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
    static void applyRating_boundaries() {
        List<Account> accounts = new List<Account>{
            new Account(Name = 'A', AnnualRevenue = 10000000),
            new Account(Name = 'B', AnnualRevenue = 9999999),
            new Account(Name = 'C', AnnualRevenue = 1000000),
            new Account(Name = 'D', AnnualRevenue = 999999)
        };
        AccountService.applyRating(accounts);
        System.assertEquals('Hot', accounts[0].Rating);
        System.assertEquals('Warm', accounts[1].Rating);
        System.assertEquals('Warm', accounts[2].Rating);
        System.assertEquals('Undefined', accounts[3].Rating);
    }
}
