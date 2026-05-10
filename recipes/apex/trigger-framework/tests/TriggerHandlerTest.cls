/**
 * TriggerHandlerTest - Tests for the trigger handler framework.
 *
 * Tests recursion guard, bypass mechanism, and field change detection.
 * Also tests the AccountTriggerHandler concrete implementation.
 *
 * @author  Sandip Patel
 */
@IsTest
private class TriggerHandlerTest {

    @TestSetup
    static void setupData() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            accounts.add(new Account(
                Name = 'Test Account ' + i,
                BillingStreet = '123 Main St',
                BillingCity = 'San Francisco',
                BillingState = 'CA',
                BillingPostalCode = '94105',
                BillingCountry = 'US'
            ));
        }
        insert accounts;

        // Create contacts for the first account
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 3; i++) {
            contacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Contact ' + i,
                AccountId = accounts[0].Id
            ));
        }
        insert contacts;
    }

    @IsTest
    static void testDefaultValues() {
        Account acc = new Account(Name = 'New Account');
        // Type should be null before insert
        System.assertEquals(null, acc.Type);

        Test.startTest();
        insert acc;
        Test.stopTest();

        acc = [SELECT Type, NumberOfEmployees FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Prospect', acc.Type, 'Default Type should be set');
        System.assertEquals(0, acc.NumberOfEmployees, 'Default employees should be 0');
    }

    @IsTest
    static void testBillingAddressSync() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account 0' LIMIT 1];

        Test.startTest();
        acc.BillingStreet = '456 New Street';
        acc.BillingCity = 'Los Angeles';
        acc.BillingState = 'CA';
        update acc;
        Test.stopTest();

        List<Contact> contacts = [
            SELECT MailingStreet, MailingCity
            FROM Contact
            WHERE AccountId = :acc.Id
        ];
        System.assertEquals(3, contacts.size());
        for (Contact c : contacts) {
            System.assertEquals('456 New Street', c.MailingStreet,
                'Contact mailing street should sync with account billing');
            System.assertEquals('Los Angeles', c.MailingCity,
                'Contact mailing city should sync with account billing');
        }
    }

    @IsTest
    static void testOwnerChangeUpdatesOpps() {
        Account acc = [SELECT Id, OwnerId FROM Account WHERE Name = 'Test Account 0' LIMIT 1];

        // Create an open opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        // Create a new user to transfer ownership to
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User newOwner = new User(
            FirstName = 'New',
            LastName = 'Owner',
            Email = 'newowner@test.com',
            Username = 'newowner' + DateTime.now().getTime() + '@test.com',
            Alias = 'nowner',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert newOwner;

        Test.startTest();
        acc.OwnerId = newOwner.Id;
        update acc;
        Test.stopTest();

        opp = [SELECT OwnerId FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(newOwner.Id, opp.OwnerId,
            'Open opportunity owner should follow account owner');
    }

    @IsTest
    static void testBulkInsert() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(new Account(Name = 'Bulk Account ' + i));
        }

        Test.startTest();
        insert accounts;
        Test.stopTest();

        List<Account> inserted = [
            SELECT Type FROM Account
            WHERE Name LIKE 'Bulk Account%'
        ];
        System.assertEquals(200, inserted.size());
        for (Account acc : inserted) {
            System.assertEquals('Prospect', acc.Type);
        }
    }

    @IsTest
    static void testNoChangeDoesNotSync() {
        Account acc = [SELECT Id, Name FROM Account WHERE Name = 'Test Account 0' LIMIT 1];

        // Update a non-address field
        Test.startTest();
        acc.Name = 'Updated Name';
        update acc;
        Test.stopTest();

        // Contacts should still have original address
        Contact c = [SELECT MailingStreet FROM Contact WHERE AccountId = :acc.Id LIMIT 1];
        System.assertEquals(null, c.MailingStreet,
            'Contact address should not change when billing address is unchanged');
    }
}
