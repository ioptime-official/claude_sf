@IsTest
private class AccountTriggerTest {
    @IsTest
    static void insert_setsRatingFromRevenue() {
        Account hot = new Account(Name = 'Trigger Hot', AnnualRevenue = 20000000);
        Account low = new Account(Name = 'Trigger Low', AnnualRevenue = 100);
        Test.startTest();
        insert new List<Account>{ hot, low };
        Test.stopTest();
        System.assertEquals('Hot', [SELECT Rating FROM Account WHERE Id = :hot.Id].Rating);
        System.assertEquals('Undefined', [SELECT Rating FROM Account WHERE Id = :low.Id].Rating);
    }

    @IsTest
    static void insert_bulk200_staysWithinLimits() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(new Account(Name = 'Bulk ' + i, AnnualRevenue = 5000000));
        }
        Test.startTest();
        insert accounts;
        Test.stopTest();
        System.assertEquals(200, [SELECT COUNT() FROM Account WHERE Rating = 'Warm' AND Name LIKE 'Bulk %']);
    }

    @IsTest
    static void update_reratesWhenRevenueChanges() {
        Account a = new Account(Name = 'Mover', AnnualRevenue = 100);
        insert a;
        a.AnnualRevenue = 50000000;
        Test.startTest();
        update a;
        Test.stopTest();
        System.assertEquals('Hot', [SELECT Rating FROM Account WHERE Id = :a.Id].Rating);
    }

    @IsTest
    static void update_downgradesToUndefinedWhenRevenueDrops() {
        Account a = new Account(Name = 'Faller', AnnualRevenue = 50000000);
        insert a;
        a.AnnualRevenue = 999999;
        Test.startTest();
        update a;
        Test.stopTest();
        System.assertEquals('Undefined', [SELECT Rating FROM Account WHERE Id = :a.Id].Rating);
    }
}
