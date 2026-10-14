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
    static void coldAccount_getsNoTask() {
        Account a = new Account(Name = 'Flow Cold', AnnualRevenue = 100);
        Test.startTest();
        insert a;
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE WhatId = :a.Id]);
    }
<<<<<<< HEAD
}
=======
}
>>>>>>> e2ebfe99cf78b1317530f1b9f387511ea1b525ca
