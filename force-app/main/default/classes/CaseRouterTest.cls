@IsTest
private class CaseRouterTest {
    @IsTest
    static void urgentSubjectSetsHighPriority() {
        Case c = new Case(Subject = 'URGENT: login broken', Origin = 'Web');
        insert c;
        c = [SELECT Priority FROM Case WHERE Id = :c.Id];
        Assert.areEqual('High', c.Priority);
    }

    @IsTest
    static void normalSubjectKeepsPriority() {
        Case c = new Case(Subject = 'Invoice question', Origin = 'Web', Priority = 'Low');
        insert c;
        c = [SELECT Priority FROM Case WHERE Id = :c.Id];
        Assert.areEqual('Low', c.Priority);
    }

    @IsTest
    static void bulkInsertWorks() {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < 200; i++) {
            cases.add(new Case(Subject = 'Outage ' + i, Origin = 'Web'));
        }
        insert cases;
        Assert.areEqual(200, [SELECT COUNT() FROM Case WHERE Priority = 'High']);
    }
}