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
        System.assertEquals('Cold', accounts[2].Rating);
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

    // Deliberately fake Ids (accounts and the '005...' users): the service runs in memory.
    private static Id fakeAccountId(Integer n) {
        return Id.valueOf('001' + ('000000000000' + n).right(12));
    }

    @IsTest
    static void recordOwnerChange_prependsPreviousOwnerAndKeepsDescription() {
        Id previousOwnerId = UserInfo.getUserId();
        Id accId = fakeAccountId(1);
        Account old = new Account(Id = accId, OwnerId = previousOwnerId);
        Account updated = new Account(Id = accId, OwnerId = Id.valueOf('005000000000001'), Description = 'Key client');
        Test.startTest();
        AccountService.recordOwnerChange(new List<Account>{ updated }, new Map<Id, Account>{ accId => old });
        Test.stopTest();
        System.assertEquals(
            AccountService.OWNER_CHANGE_NOTE + UserInfo.getName() + '\nKey client',
            updated.Description
        );
    }

    @IsTest
    static void recordOwnerChange_leavesDescriptionWhenOwnerUnchanged() {
        Id accId = fakeAccountId(2);
        Account old = new Account(Id = accId, OwnerId = UserInfo.getUserId());
        Account updated = new Account(Id = accId, OwnerId = UserInfo.getUserId(), Description = 'Untouched');
        AccountService.recordOwnerChange(new List<Account>{ updated }, new Map<Id, Account>{ accId => old });
        AccountService.recordOwnerChange(null, null);
        System.assertEquals('Untouched', updated.Description);
    }

    @IsTest
    static void recordOwnerChange_handlesNullDescriptionAndUnknownOwner() {
        Id unknownOwnerId = Id.valueOf('005000000000002');
        Id accId = fakeAccountId(3);
        Account old = new Account(Id = accId, OwnerId = unknownOwnerId);
        Account updated = new Account(Id = accId, OwnerId = UserInfo.getUserId());
        AccountService.recordOwnerChange(new List<Account>{ updated }, new Map<Id, Account>{ accId => old });
        System.assertEquals(AccountService.OWNER_CHANGE_NOTE + String.valueOf(unknownOwnerId), updated.Description);
    }

    @IsTest
    static void recordOwnerChange_truncatesToDescriptionLimit() {
        Id accId = fakeAccountId(4);
        Account old = new Account(Id = accId, OwnerId = UserInfo.getUserId());
        Account updated = new Account(
            Id = accId,
            OwnerId = Id.valueOf('005000000000001'),
            Description = 'x'.repeat(AccountService.DESCRIPTION_MAX_LENGTH)
        );
        AccountService.recordOwnerChange(new List<Account>{ updated }, new Map<Id, Account>{ accId => old });
        System.assertEquals(AccountService.DESCRIPTION_MAX_LENGTH, updated.Description.length());
        System.assert(updated.Description.startsWith(AccountService.OWNER_CHANGE_NOTE + UserInfo.getName()));
    }

    @IsTest
    static void recordOwnerChange_bulk200UsesOneQuery() {
        List<Account> updated = new List<Account>();
        Map<Id, Account> oldMap = new Map<Id, Account>();
        for (Integer i = 0; i < 200; i++) {
            Id accId = fakeAccountId(100 + i);
            oldMap.put(accId, new Account(Id = accId, OwnerId = UserInfo.getUserId()));
            updated.add(new Account(Id = accId, OwnerId = Id.valueOf('005000000000001')));
        }
        Test.startTest();
        AccountService.recordOwnerChange(updated, oldMap);
        System.assertEquals(1, Limits.getQueries());
        Test.stopTest();
        for (Account a : updated) {
            System.assertEquals(AccountService.OWNER_CHANGE_NOTE + UserInfo.getName(), a.Description);
        }
    }
}
