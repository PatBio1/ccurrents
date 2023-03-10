public inherited sharing class ErrorLogSelector {

	public static String getErrorLogsOlderThan(Decimal days) {
		String query = '';

		query += 'SELECT Id ';
		query += ' FROM ErrorLog__c ';
		query += ' WHERE CreatedDate < LAST_N_DAYS:' + Integer.valueOf(days);

		return query;
	}
}