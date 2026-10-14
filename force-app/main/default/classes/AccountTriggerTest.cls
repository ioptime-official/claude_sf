@IsTest
private class AccountTriggerTest {
    @IsTest
    static void insert_setsRatingFromRevenue() {
        Account hot = new Account(Name = 'Trigger Hot', AnnualRevenue = 20000000);
        Account cold = new Account(Name = 'Trigger Cold', AnnualRevenue = 100);
        Test.startTest();
        insert new List<Account>{ hot, cold };
        Test.stopTest();
        System.assertEquals('Hot', [SELECT Rating FROM Account WHERE Id = :hot.Id].Rating);
        System.assertEquals('Cold', [SELECT Rating FROM Account WHERE Id = :cold.Id].Rating);
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

    private static User newOwner() {
        User me = [SELECT ProfileId, TimeZoneSidKey, LocaleSidKey, EmailEncodingKey, LanguageLocaleKey
                   FROM User WHERE Id = :UserInfo.getUserId()];
        String unique = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(
            FirstName = 'New', LastName = 'Owner', Alias = 'nown',
            Email = 'new.owner' + unique + '@example.com',
            Username = 'new.owner' + unique + '@example.com.test',
            ProfileId = me.ProfileId, TimeZoneSidKey = me.TimeZoneSidKey,
            LocaleSidKey = me.LocaleSidKey, EmailEncodingKey = me.EmailEncodingKey,
            LanguageLocaleKey = me.LanguageLocaleKey
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }
        return u;
    }

    @IsTest
    static void update_ownerChange_notesPreviousOwnerInDescription() {
        User target = newOwner();
        Account a = new Account(Name = 'Reassigned', Description = 'Existing notes');
        insert a;
        System.assertEquals('Existing notes', [SELECT Description FROM Account WHERE Id = :a.Id].Description,
            'Insert must not add an owner-change note');
        a.OwnerId = target.Id;
        Test.startTest();
        update a;
        Test.stopTest();
        System.assertEquals(
            AccountService.OWNER_CHANGE_NOTE + UserInfo.getName() + '\nExisting notes',
            [SELECT Description FROM Account WHERE Id = :a.Id].Description
        );
    }

    @IsTest
    static void update_bulk200OwnerChange_notesEachAccount() {
        User target = newOwner();
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(new Account(Name = 'Reassign ' + i));
        }
        insert accounts;
        for (Account a : accounts) {
            a.OwnerId = target.Id;
        }
        Test.startTest();
        update accounts;
        Test.stopTest();
        String expected = AccountService.OWNER_CHANGE_NOTE + UserInfo.getName();
        for (Account a : [SELECT Description, OwnerId FROM Account WHERE Id IN :accounts]) {
            System.assertEquals(target.Id, a.OwnerId);
            System.assertEquals(expected, a.Description);
        }
    }
}
