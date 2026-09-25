@IsTest
@SuppressWarnings('PMD.MethodNamingConventions,PMD.ApexUnitTestClassShouldHaveRunAs')
// The use of underscores to separate method name, scenario and outcome is deliberate
// CPD-OFF Apex tests methods often have similar structure to maintain readability
/**
 * @description Performance regressions for the UnitOfWork class: each test commits a batch large enough
 * to exhaust the synchronous CPU limit under the quadratic relationship handling that preceded issue #20.
 * They insert thousands of records under USER_MODE and take tens of seconds each, so they live apart from
 * the unit tests in UnitOfWorkTest; run them when the relationship or commit paths change.
 * @author Jai Jordan
 * @date 2026-09-25
 */
private class UnitOfWorkPerformanceTest {

    private static final Id MINIMUM_ACCESS_PROFILE_ID = [ SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1 ].Id;
    private static final Integer RECORD_COUNT = 2000;

    @IsTest
    private static void commitWork_whenThousandsOfCrossTypeRelationshipsAreRegisteredInRecordOrder_commitsWithinCpuLimit() {
        UnitOfWork unitOfWork = new UnitOfWork();

        User testUser = createUserWithPermissionsForSobjectsAndFields( new Set<SobjectType> { Account.SObjectType, Contact.SObjectType }, new Set<SobjectField> { Contact.AccountId } );

        List<Account> accounts = new List<Account>();
        List<Contact> contacts = new List<Contact>();
        for ( Integer i = 0; i < RECORD_COUNT; i++ ) {
            accounts.add( new Account( Name = 'Account ' + i ) );
            contacts.add( new Contact( LastName = 'Contact ' + i ) );
        }
        unitOfWork.registerNew( accounts );
        unitOfWork.registerNew( contacts );
        for ( Integer i = 0; i < RECORD_COUNT; i++ ) {
            unitOfWork.registerRelationship( contacts[ i ], Contact.AccountId, accounts[ i ] );
        }

        Test.startTest();
        System.runAs( testUser ) {
            unitOfWork.commitWork();
        }
        Test.stopTest();

        Assert.areEqual( RECORD_COUNT, [ SELECT COUNT() FROM Contact WHERE AccountId IN :accounts ], 'commitWork, when thousands of cross-type relationships are registered in record order, should insert every child under its parent' );
        Assert.areEqual( accounts[ RECORD_COUNT - 1 ].Id, contacts[ RECORD_COUNT - 1 ].AccountId, 'commitWork, when thousands of cross-type relationships are registered in record order, should set each child\'s lookup to its own parent' );
    }

    @IsTest
    private static void commitWork_whenThousandsOfCrossTypeRelationshipsAreRegisteredInReverseOrder_commitsWithinCpuLimit() {
        UnitOfWork unitOfWork = new UnitOfWork();

        User testUser = createUserWithPermissionsForSobjectsAndFields( new Set<SobjectType> { Account.SObjectType, Contact.SObjectType }, new Set<SobjectField> { Contact.AccountId } );

        List<Account> accounts = new List<Account>();
        List<Contact> contacts = new List<Contact>();
        for ( Integer i = 0; i < RECORD_COUNT; i++ ) {
            accounts.add( new Account( Name = 'Account ' + i ) );
            contacts.add( new Contact( LastName = 'Contact ' + i ) );
        }
        unitOfWork.registerNew( accounts );
        unitOfWork.registerNew( contacts );
        // Last record first: the position lookups run against the registration order
        for ( Integer i = RECORD_COUNT - 1; i >= 0; i-- ) {
            unitOfWork.registerRelationship( contacts[ i ], Contact.AccountId, accounts[ i ] );
        }

        Test.startTest();
        System.runAs( testUser ) {
            unitOfWork.commitWork();
        }
        Test.stopTest();

        Assert.areEqual( RECORD_COUNT, [ SELECT COUNT() FROM Contact WHERE AccountId IN :accounts ], 'commitWork, when thousands of cross-type relationships are registered in reverse order, should insert every child under its parent' );
        Assert.areEqual( accounts[ 0 ].Id, contacts[ 0 ].AccountId, 'commitWork, when thousands of cross-type relationships are registered in reverse order, should set each child\'s lookup to its own parent' );
    }

    @IsTest
    private static void commitWork_whenThousandsOfSameTypeParentsAndChildrenAreRegisteredAsGroups_commitsWithinCpuLimit() {
        UnitOfWork unitOfWork = new UnitOfWork();

        User testUser = createUserWithPermissionsForSobjectsAndFields( new Set<SobjectType> { Account.SObjectType, Contact.SObjectType }, new Set<SobjectField> { Account.ParentId } );

        // All parents, then all children: each relationship looks up one record in the parent region and one in
        // the child region, which defeats a single position cursor
        List<Account> parents = new List<Account>();
        List<Account> children = new List<Account>();
        for ( Integer i = 0; i < RECORD_COUNT; i++ ) {
            parents.add( new Account( Name = 'Parent ' + i ) );
            children.add( new Account( Name = 'Child ' + i ) );
        }
        unitOfWork.registerNew( parents );
        unitOfWork.registerNew( children );
        for ( Integer i = 0; i < RECORD_COUNT; i++ ) {
            unitOfWork.registerRelationship( children[ i ], Account.ParentId, parents[ i ] );
        }

        Test.startTest();
        System.runAs( testUser ) {
            unitOfWork.commitWork();
        }
        Test.stopTest();

        Assert.areEqual( RECORD_COUNT, [ SELECT COUNT() FROM Account WHERE ParentId IN :parents ], 'commitWork, when thousands of same-type parents and children are registered as groups, should insert every child under its parent' );
        Assert.areEqual( parents[ RECORD_COUNT - 1 ].Id, children[ RECORD_COUNT - 1 ].ParentId, 'commitWork, when thousands of same-type parents and children are registered as groups, should set each child\'s parent to its own parent' );
    }

    private static User createMinimumAccessUser() {
        User minimumAccessUser = new User(
            ProfileId = MINIMUM_ACCESS_PROFILE_ID,
            LastName = 'Test',
            Email = 'test@example.com',
            Username = 'test' + DateTime.now().getTime() + '@unit.of.work.test',
            Alias = 'test',
            TimeZoneSidKey = 'Europe/London',
            LocaleSidKey = 'en_GB',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert minimumAccessUser;
        return minimumAccessUser;
    }

    private static User createUserWithPermissionsForSobjectsAndFields( Set<SobjectType> sobjectTypes, Set<SobjectField> sobjectFields ) {
        User requestedUser = createMinimumAccessUser();
        PermissionSet requestedPermissionSet = createPermissionSetWithPermissionForSobjectsAndFields( sobjectTypes, sobjectFields );
        assignPermissionSetToUser( requestedUser, requestedPermissionSet );
        return requestedUser;
    }

    // With Person Accounts enabled, the platform refuses an ObjectPermissions row that grants Account
    // without also granting Contact ("Permission Read Account depends on permission(s): Read Contact").
    // Grant both whenever Account is needed, and use Contact as the granted object and Account as the
    // withheld one in tests that prove a permission failure, so the suite passes in either kind of org.
    private static PermissionSet createPermissionSetWithPermissionForSobjectsAndFields( Set<SobjectType> sobjectTypes, Set<SobjectField> sobjectFields ) {
        PermissionSet requestedPermissionSet = new PermissionSet(
            Label = 'Permission Set For Sobjects ' + DateTime.now().getTime(),
            Name = 'Permission_Set_For_Sobjects_' + DateTime.now().getTime()
        );
        insert requestedPermissionSet;

        List<ObjectPermissions> requestedObjectPermissions = new List<ObjectPermissions>();
        for ( SobjectType thisSobjectType : sobjectTypes ) {
            requestedObjectPermissions.add( new ObjectPermissions(
                SobjectType = String.valueOf( thisSobjectType ),
                PermissionsCreate = true,
                PermissionsRead = true,
                PermissionsEdit = true,
                PermissionsDelete = true,
                ParentId = requestedPermissionSet.Id
            ) );
        }
        insert requestedObjectPermissions;

        List<FieldPermissions> requestedFieldPermissions = new List<FieldPermissions>();
        for ( SobjectField thisSobjectField : sobjectFields ) {
            SobjectType thisSobjectType = thisSobjectField.getDescribe().getSobjectType();
            requestedFieldPermissions.add( new FieldPermissions(
                SobjectType = String.valueOf( thisSobjectType ),
                Field = String.valueOf( thisSobjectType ) + '.' + String.valueOf( thisSobjectField ),
                PermissionsRead = true,
                PermissionsEdit = true,
                ParentId = requestedPermissionSet.Id
            ) );
        }
        insert requestedFieldPermissions;

        return requestedPermissionSet;
    }

    private static void assignPermissionSetToUser( User user, PermissionSet permissionSet ) {
        insert new PermissionSetAssignment( AssigneeId = user.Id, PermissionSetId = permissionSet.Id );
    }

}
