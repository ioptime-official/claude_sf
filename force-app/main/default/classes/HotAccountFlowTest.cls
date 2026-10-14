@IsTest
private class HotAccountFlowTest {
    @IsTest
    static void hotAccount_getsFollowUpTask() {
        Account a = new Account(Name = 'Flow Hot', AnnualRevenue = 20000000);
        Test.startTest();
        insert a;
        Test.stopTest();
        List<Task> tasks = [SELECT Subject, Priority FROM Task WHERE WhatId = :a.Id];
        System.assertEquals(1, tasks.size(), 'Flow should create exactly one task');
        System.assertEquals('High', tasks[0].Priority);
    }

    @IsTest
    static void lowRevenueAccount_getsNoTask() {
        Account a = new Account(Name = 'Flow Low', AnnualRevenue = 100);
        Test.startTest();
        insert a;
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE WhatId = :a.Id]);
    }

    @IsTest
    static void warmAccount_getsNormalTaskForOwner() {
        Account a = new Account(Name = 'Flow Warm', AnnualRevenue = 5000000);
        Test.startTest();
        insert a;
        Test.stopTest();
        Account saved = [SELECT OwnerId FROM Account WHERE Id = :a.Id];
        List<Task> tasks = [SELECT Subject, Priority, OwnerId FROM Task WHERE WhatId = :a.Id];
        System.assertEquals(1, tasks.size(), 'Flow should create exactly one task');
        System.assertEquals('Normal', tasks[0].Priority);
        System.assertEquals('Follow up with new Warm account', tasks[0].Subject);
        System.assertEquals(saved.OwnerId, tasks[0].OwnerId);
    }

    @IsTest
    static void warmAccount_resaveWithoutRatingChange_noSecondTask() {
        Account a = new Account(Name = 'Flow Warm Resave', AnnualRevenue = 5000000);
        insert a;
        a.Name = 'Flow Warm Renamed';
        Test.startTest();
        update a;
        Test.stopTest();
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhatId = :a.Id]);
    }

    @IsTest
    static void hotToWarm_createsWarmTask() {
        Account a = new Account(Name = 'Flow Downgrade', AnnualRevenue = 20000000);
        insert a;
        a.AnnualRevenue = 5000000;
        Test.startTest();
        update a;
        Test.stopTest();
        System.assertEquals(2, [SELECT COUNT() FROM Task WHERE WhatId = :a.Id], 'Hot task kept, Warm task added');
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhatId = :a.Id AND Subject = 'Follow up with new Warm account']);
    }

    @IsTest
    static void warmBulk200_createsOneTaskEach() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(new Account(Name = 'Flow Bulk ' + i, AnnualRevenue = 5000000));
        }
        Test.startTest();
        insert accounts;
        Test.stopTest();
        System.assertEquals(200, [SELECT COUNT() FROM Task WHERE WhatId IN :accounts]);
    }
}
