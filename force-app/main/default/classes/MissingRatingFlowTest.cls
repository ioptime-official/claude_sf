@IsTest
private class MissingRatingFlowTest {
    private static final String SUBJECT = 'Please update rating manually for the account';

    @IsTest
    static void blankRating_createsTaskForOwner() {
        Account a = new Account(Name = 'Missing Rating');
        Test.startTest();
        insert a;
        Test.stopTest();
        Account saved = [SELECT OwnerId FROM Account WHERE Id = :a.Id];
        List<Task> tasks = [SELECT Subject, OwnerId FROM Task WHERE WhatId = :a.Id];
        System.assertEquals(1, tasks.size(), 'Exactly one task expected');
        System.assertEquals(SUBJECT, tasks[0].Subject);
        System.assertEquals(saved.OwnerId, tasks[0].OwnerId);
    }

    @IsTest
    static void autoRatedAccount_getsNoUpdateRatingTask() {
        Account a = new Account(Name = 'Rated', AnnualRevenue = 100);
        Test.startTest();
        insert a;
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE WhatId = :a.Id AND Subject = :SUBJECT]);
    }

    @IsTest
    static void ratingCleared_createsTask() {
        Account a = new Account(Name = 'Cleared', Rating = 'Warm');
        insert a;
        a.Rating = null;
        Test.startTest();
        update a;
        Test.stopTest();
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhatId = :a.Id AND Subject = :SUBJECT]);
    }

    @IsTest
    static void unrelatedUpdate_noSecondTask() {
        Account a = new Account(Name = 'Resave');
        insert a;
        a.Name = 'Resave Renamed';
        Test.startTest();
        update a;
        Test.stopTest();
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhatId = :a.Id AND Subject = :SUBJECT]);
    }

    @IsTest
    static void bulk200_createsOneTaskEach() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(new Account(Name = 'Missing Bulk ' + i));
        }
        Test.startTest();
        insert accounts;
        Test.stopTest();
        System.assertEquals(200, [SELECT COUNT() FROM Task WHERE WhatId IN :accounts AND Subject = :SUBJECT]);
    }
}
