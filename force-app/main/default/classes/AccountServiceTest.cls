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

    private static User makeUser(String alias) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        return new User(
            Alias = alias, LastName = 'Owner' + alias, Email = alias + '@example.com',
            Username = alias + System.currentTimeMillis() + '@example.com.test',
            ProfileId = p.Id, TimeZoneSidKey = 'GMT', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'
        );
    }

    @IsTest
    static void noteOwnerChanges_appendsNoteAndKeepsDescription() {
        User u1 = makeUser('own1');
        User u2 = makeUser('own2');
        insert new List<User>{ u1, u2 };
        Account a = new Account(Name = 'Owned', OwnerId = u1.Id, Description = 'Existing text');
        insert a;
        Account old = a.clone(true);
        a.OwnerId = u2.Id;
        Test.startTest();
        AccountService.noteOwnerChanges(new List<Account>{ a }, new Map<Id, Account>{ a.Id => old });
        Test.stopTest();
        System.assert(a.Description.startsWith('Existing text\n'));
        System.assert(a.Description.contains('Owner changed recently. Previous owner: ' + u1.LastName));
    }

    @IsTest
    static void noteOwnerChanges_noChangeLeavesDescription() {
        Account a = new Account(Name = 'Same', Description = 'Keep');
        insert a;
        Account old = a.clone(true);
        AccountService.noteOwnerChanges(new List<Account>{ a }, new Map<Id, Account>{ a.Id => old });
        System.assertEquals('Keep', a.Description);
        AccountService.noteOwnerChanges(new List<Account>{ a }, null);
        AccountService.noteOwnerChanges(null, null);
    }

    @IsTest
    static void noteOwnerChanges_bulk200_usesOneQuery() {
        User u1 = makeUser('blk1');
        User u2 = makeUser('blk2');
        insert new List<User>{ u1, u2 };
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(new Account(Name = 'B' + i, OwnerId = u1.Id));
        }
        insert accounts;
        Map<Id, Account> oldMap = new Map<Id, Account>();
        for (Account a : accounts) {
            oldMap.put(a.Id, a.clone(true));
            a.OwnerId = u2.Id;
        }
        Test.startTest();
        AccountService.noteOwnerChanges(accounts, oldMap);
        System.assertEquals(1, Limits.getQueries());
        Test.stopTest();
        for (Account a : accounts) {
            System.assert(a.Description.contains('Owner changed recently'));
        }
    }

    @IsTest
    static void noteOwnerChanges_viaTrigger_notRepeatedOnLaterUpdate() {
        User u1 = makeUser('trg1');
        User u2 = makeUser('trg2');
        insert new List<User>{ u1, u2 };
        Account a = new Account(Name = 'Trg', OwnerId = u1.Id);
        insert a;
        System.assertEquals(null, [SELECT Description FROM Account WHERE Id = :a.Id].Description);
        a.OwnerId = u2.Id;
        update a;
        String d1 = [SELECT Description FROM Account WHERE Id = :a.Id].Description;
        System.assert(d1.contains('Owner changed recently'));
        a = [SELECT Id, Name FROM Account WHERE Id = :a.Id];
        a.Name = 'Trg2';
        update a;
        System.assertEquals(d1, [SELECT Description FROM Account WHERE Id = :a.Id].Description);
    }

    @IsTest
    static void noteOwnerChanges_skipsNoteWhenDescriptionWouldOverflow() {
        Account a = new Account(Name = 'Big', Description = 'x'.repeat(AccountService.DESCRIPTION_MAX - 5));
        Account old = a.clone(false);
        old.OwnerId = UserInfo.getUserId();
        a.OwnerId = UserInfo.getUserId();
        a.Id = '001000000000001AAA';
        old.Id = a.Id;
        old.OwnerId = '005000000000001AAA';
        AccountService.noteOwnerChanges(new List<Account>{ a }, new Map<Id, Account>{ a.Id => old });
        System.assertEquals(AccountService.DESCRIPTION_MAX - 5, a.Description.length());
    }

    @IsTest
    static void noteOwnerChanges_unknownOldOwnerFallsBackToId() {
        Account a = new Account(Name = 'Ghost', OwnerId = UserInfo.getUserId());
        a.Id = '001000000000002AAA';
        Account old = new Account(Name = 'Ghost', Id = a.Id, OwnerId = '005000000000002AAA');
        AccountService.noteOwnerChanges(new List<Account>{ a }, new Map<Id, Account>{ a.Id => old });
        System.assert(a.Description.contains('005000000000002AAA'));
    }
}
