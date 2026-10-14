public with sharing class CaseRouter {
    private static final Set<String> URGENT_KEYWORDS = new Set<String>{ 'urgent', 'outage' };

    public static void setPriority(List<Case> cases) {
        for (Case c : cases) {
            if (isUrgent(c.Subject)) {
                c.Priority = 'High';
            }
        }
    }

    @TestVisible
    private static Boolean isUrgent(String subject) {
        if (String.isBlank(subject)) {
            return false;
        }
        String lower = subject.toLowerCase();
        for (String keyword : URGENT_KEYWORDS) {
            if (lower.contains(keyword)) {
                return true;
            }
        }
        return false;
    }
}