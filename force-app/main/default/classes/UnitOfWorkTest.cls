@isTest
private class UnitOfWorkTest {

    private static final Id minimumAccessProfileId = [ SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1 ].Id;

    @isTest
    private static void constructor_whenCalledWithNullSobjectTypeOperationOrder_throwsValidationException() {
        List<SObjectType> nullSobjectTypeOperationOrder = null;

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            new UnitOfWork( nullSobjectTypeOperationOrder );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'constructor, when called with a null sobjectTypeOperationOrder, should throw an exception' );
        Assert.areEqual( 'UnitOfWork constructed with a null sobjectTypeOperationOrder', thrownException.getMessage(), 'constructor, when called with a null sobjectTypeOperationOrder, should throw a ValidationException' );
    }

    @isTest
    private static void constructor_whenCalledWithEmptySobjectTypeOperationOrder_throwsValidationException() {
        List<SObjectType> emptySobjectTypeOperationOrder = new List<SObjectType>();

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            new UnitOfWork( emptySobjectTypeOperationOrder );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'constructor, when called with an empty sobjectTypeOperationOrder, should throw an exception' );
        Assert.areEqual( 'UnitOfWork constructed with an empty sobjectTypeOperationOrder', thrownException.getMessage(), 'constructor, when called with an empty sobjectTypeOperationOrder, should throw a ValidationException' );
    }

    @isTest
    private static void constructor_whenCalledWithListOfSobjectTypes_buildsUnitOfWorkWithCorrectSobjectTypeOperationOrder() {
        List<SObjectType> sobjectTypeOperationOrder = new List<SObjectType> { Account.SObjectType, Contact.SObjectType };

        UnitOfWork got;

        Test.startTest();
        got = new UnitOfWork( sobjectTypeOperationOrder );
        Test.stopTest();

        Assert.areEqual( sobjectTypeOperationOrder, got.sobjectTypeOperationOrder, 'constructor, when called with a list of sobjectTypes, should build a UnitOfWork with the correct sobjectTypeOperationOrder' );
    }

    @isTest
    private static void registerNew_whenCalledWithNullRecord_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType } );
        Sobject nullRecord;

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerNew( nullRecord );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerNew, when called with a null record, should throw an exception' );
        Assert.areEqual( 'registerNew called with a null record', thrownException.getMessage(), 'registerNew, when called with a null record, should throw a ValidationException' );
    }

    @isTest
    private static void registerNew_whenCalledWithRecordWithId_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType } );
        Account accountWithId = new Account( Id = '001000000000000', Name = 'Account with Id' );

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerNew( accountWithId );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerNew, when called with a record with an Id, should throw an exception' );
        Assert.areEqual( 'registerNew called with a record that already has an Id', thrownException.getMessage(), 'registerNew, when called with a record with an Id, should throw a ValidationException' );
    }

    @isTest
    private static void registerNew_whenCalledWithRecordNotInSobjectTypeOperationOrder_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType } );
        Contact testContact = new Contact( FirstName = 'John', LastName = 'Smith' );

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerNew( testContact );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerNew, when called with a record not in the sobjectTypeOperationOrder, should throw an exception' );
        Assert.areEqual( 'registerNew called with a record whose SObjectType is not in the sobjectTypeOperationOrder', thrownException.getMessage(), 'registerNew, when called with a record not in the sobjectTypeOperationOrder, should throw a ValidationException' );
    }

    @isTest
    private static void registerNew_whenCalledWithRecordInSobjectTypeOperationOrder_registersRecord() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType } );
        Account testAccount = new Account( Name = 'Test Account' );

        Test.startTest();
        unitOfWork.registerNew( testAccount );
        Test.stopTest();

        Assert.areEqual( testAccount, unitOfWork.newRecordsBySobjectType.get( Account.SObjectType )[0], 'registerNew, when called with a record in the sobjectTypeOperationOrder, should register the record' );
    }

    @isTest
    private static void registerDirty_whenCalledWithNullRecord_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType } );
        SObject nullRecord;

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerDirty( nullRecord );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerDirty, when called with a null record, should throw an exception' );
        Assert.areEqual( 'registerDirty called with a null record', thrownException.getMessage(), 'registerDirty, when called with a null record, should throw a ValidationException' );
    }

    @isTest
    private static void registerDirty_whenCalledWithRecordWithNullId_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType } );
        Account accountWithNullId = new Account( Name = 'Account with Null Id' );

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerDirty( accountWithNullId );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerDirty, when called with a record with a null Id, should throw an exception' );
        Assert.areEqual( 'registerDirty called with a record that does not have an Id', thrownException.getMessage(), 'registerDirty, when called with a record with a null Id, should throw a ValidationException' );
    }

    @isTest
    private static void registerDirty_whenCalledWithRecordNotInSobjectTypeOperationOrder_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType } );
        Contact testContact = new Contact( Id = '003000000000000', FirstName = 'John', LastName = 'Smith' );

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerDirty( testContact );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerDirty, when called with a record not in the sobjectTypeOperationOrder, should throw an exception' );
        Assert.areEqual( 'registerDirty called with a record whose SObjectType is not in the sobjectTypeOperationOrder', thrownException.getMessage(), 'registerDirty, when called with a record not in the sobjectTypeOperationOrder, should throw a ValidationException' );
    }

    @isTest
    private static void registerDirty_whenCalledWithRecordInSobjectTypeOperationOrder_registersRecord() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType } );
        Account testAccount = new Account( Id = '001000000000000', Name = 'Test Account' );

        Test.startTest();
        unitOfWork.registerDirty( testAccount );
        Test.stopTest();

        Assert.areEqual( testAccount, unitOfWork.dirtyRecordsBySobjectTypeAndRecordId.get( Account.SObjectType ).get( testAccount.Id ), 'registerDirty, when called with a record in the sobjectTypeOperationOrder, should register the record' );
    }

    @isTest
    private static void registerDirty_whenCalledTwiceWithSameRecord_mergesRecords() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType } );
        Id accountId = '001000000000000';

        Account originalVersionOfAccount = new Account( Id = accountId, Name = 'Test Account', Phone = '1234567890' );
        Account secondVersionOfAccount = new Account( Id = accountId, Description = 'Test description', Phone = null );

        Test.startTest();
        unitOfWork.registerDirty( originalVersionOfAccount );
        unitOfWork.registerDirty( secondVersionOfAccount );
        Test.stopTest();

        Account mergedAccount = (Account)unitOfWork.dirtyRecordsBySobjectTypeAndRecordId.get( Account.SObjectType ).get( accountId );
        Assert.areEqual( 'Test Account', mergedAccount.Name, 'registerDirty, when called twice with the same record, should merge the records' );
        Assert.areEqual( 'Test description', mergedAccount.Description, 'registerDirty, when called twice with the same record, should merge the records' );
        Assert.isNull( mergedAccount.Phone, 'registerDirty, when called twice with the same record, should merge the records' );
    }

    @isTest
    private static void registerDeleted_whenCalledWithNullRecord_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType } );
        SObject nullRecord;

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerDeleted( nullRecord );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerDeleted, when called with a null record, should throw an exception' );
        Assert.areEqual( 'registerDeleted called with a null record', thrownException.getMessage(), 'registerDeleted, when called with a null record, should throw a ValidationException' );
    }

    @isTest
    private static void registerDeleted_whenCalledWithRecordWithNullId_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType } );
        Account accountWithNullId = new Account( Name = 'Account with Null Id' );

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerDeleted( accountWithNullId );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerDeleted, when called with a record with a null Id, should throw an exception' );
        Assert.areEqual( 'registerDeleted called with a record that does not have an Id', thrownException.getMessage(), 'registerDeleted, when called with a record with a null Id, should throw a ValidationException' );
    }

    @isTest
    private static void registerDeleted_whenCalledWithRecordNotInSobjectTypeOperationOrder_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType } );
        Contact testContact = new Contact( Id = '003000000000000', FirstName = 'John', LastName = 'Smith' );

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerDeleted( testContact );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerDeleted, when called with a record not in the sobjectTypeOperationOrder, should throw an exception' );
        Assert.areEqual( 'registerDeleted called with a record whose SObjectType is not in the sobjectTypeOperationOrder', thrownException.getMessage(), 'registerDeleted, when called with a record not in the sobjectTypeOperationOrder, should throw a ValidationException' );
    }

    @isTest
    private static void registerDeleted_whenCalledWithRecordInSobjectTypeOperationOrder_registersRecord() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType } );
        Account testAccount = new Account( Id = '001000000000000', Name = 'Test Account' );

        Test.startTest();
        unitOfWork.registerDeleted( testAccount );
        Test.stopTest();

        Assert.isTrue( unitOfWork.deletedRecordIdsBySobjectType.get( Account.SObjectType ).contains( testAccount.Id ), 'registerDeleted, when called with a record in the sobjectTypeOperationOrder, should register the record' );
    }

    @isTest
    private static void registerRelationship_whenCalledWithNullRecord_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType, Contact.SObjectType } );
        SObject nullRecord;
        SObjectField relationshipField = Contact.AccountId;
        Account parentRecord = new Account( Name = 'Parent Account' );

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerRelationship( nullRecord, relationshipField, parentRecord );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerRelationship, when called with a null record, should throw an exception' );
        Assert.areEqual( 'registerRelationship called with a null record', thrownException.getMessage(), 'registerRelationship, when called with a null record, should throw a ValidationException' );
    }

    @isTest
    private static void registerRelationship_whenCalledWithNullRelationshipField_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType, Contact.SObjectType } );
        Contact testContact = new Contact( FirstName = 'John', LastName = 'Smith' );
        SObjectField nullRelationshipField;
        Account parentRecord = new Account( Name = 'Parent Account' );

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerRelationship( testContact, nullRelationshipField, parentRecord );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerRelationship, when called with a null relationshipField, should throw an exception' );
        Assert.areEqual( 'registerRelationship called with a null relationshipField', thrownException.getMessage(), 'registerRelationship, when called with a null relationshipField, should throw a ValidationException' );
    }

    @isTest
    private static void registerRelationship_whenCalledWithNullParentRecord_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType, Contact.SObjectType } );
        Contact testContact = new Contact( FirstName = 'John', LastName = 'Smith' );
        SObjectField relationshipField = Contact.AccountId;
        SObject nullParentRecord;

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerRelationship( testContact, relationshipField, nullParentRecord );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerRelationship, when called with a null parentRecord, should throw an exception' );
        Assert.areEqual( 'registerRelationship called with a null parentRecord', thrownException.getMessage(), 'registerRelationship, when called with a null parentRecord, should throw a ValidationException' );
    }

    @isTest
    private static void registerRelationship_whenCalledWithRelationshipFieldNotOnRecordSobjectType_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType, Contact.SObjectType } );
        Account testAccount = new Account( Name = 'Test Account' ); // Record is Account, not Contact
        SObjectField relationshipField = Contact.AccountId;
        Account parentRecord = new Account( Name = 'Parent Account' );

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerRelationship( testAccount, relationshipField, parentRecord );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerRelationship, when called with a relationship field from a different SobjectType than the record SobjectType, should throw an exception' );
        Assert.areEqual( 'registerRelationship called with a relationship field from a different SobjectType than the record SobjectType', thrownException.getMessage(), 'registerRelationship, when called with a relationship field not on the record SObjectType, should throw a ValidationException' );
    }

    @isTest
    private static void registerRelationship_whenCalledWithRelationshipFieldNotPointingToParentSobjectType_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType, Contact.SObjectType, User.SObjectType } );
        Contact testContact = new Contact( FirstName = 'John', LastName = 'Smith' );
        SObjectField relationshipField = Contact.AccountId;
        User parentRecord = new User( LastName = 'Parent User' ); // relationshipField points to Account, not User

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerRelationship( testContact, relationshipField, parentRecord );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerRelationship, when called with a relationship field that does not point to the parent record SobjectType, should throw an exception' );
        Assert.areEqual( 'registerRelationship called with a relationship field that does not point to the parent record SobjectType', thrownException.getMessage(), 'registerRelationship, when called with a relationship field not pointing to the parent SObjectType, should throw a ValidationException' );
    }

    @isTest
    private static void registerRelationship_whenCalledWithValidParameters_registersRelationship() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType, Contact.SObjectType } );
        Contact testContact = new Contact( FirstName = 'John', LastName = 'Smith' );
        SObjectField relationshipField = Contact.AccountId;
        Account parentRecord = new Account( Name = 'Parent Account' );

        Test.startTest();
        unitOfWork.registerRelationship( testContact, relationshipField, parentRecord );
        Test.stopTest();

        Assert.isTrue( unitOfWork.relationships.relationshipsBySobjectType.containsKey( Contact.SObjectType ), 'registerRelationship, when called with valid parameters, should register the relationship for the record SObjectType' );
        Assert.areEqual( 1, unitOfWork.relationships.relationshipsBySobjectType.get( Contact.SObjectType ).size(), 'registerRelationship, when called with valid parameters, should register one relationship' );
    }

    @isTest
    private static void bypassSharing_whenCalledWithNullSobjectType_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType } );
        SObjectType nullSobjectType;

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.bypassSharing( nullSobjectType );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'bypassSharing, when called with a null type, should throw an exception' );
        Assert.areEqual( 'bypassSharing called with a null type', thrownException.getMessage(), 'bypassSharing, when called with a null type, should throw a ValidationException' );
    }

    @isTest
    private static void bypassSharing_whenCalledWithSobjectTypeNotInSobjectTypeOperationOrder_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType } );
        SobjectType sobjectTypeNotInSobjectTypeOperationOrder = Contact.SObjectType;

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.bypassSharing( sobjectTypeNotInSobjectTypeOperationOrder );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'bypassSharing, when called with a type not in the sobjectTypeOperationOrder, should throw an exception' );
        Assert.areEqual( 'bypassSharing called with a type that was not specified in the sobjectTypeOperationOrder when the UnitOfWork was constructed', thrownException.getMessage(), 'bypassSharing, when called with a type not in the sobjectTypeOperationOrder, should throw a ValidationException' );
    }

    @isTest
    private static void bypassSharing_whenCalledWithValidSobjectType_registersSharingBypass() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType } );
        SobjectType sobjectTypeToBypassSharing = Account.SObjectType;

        Test.startTest();
        unitOfWork.bypassSharing( sobjectTypeToBypassSharing );
        Test.stopTest();

        Assert.isTrue( unitOfWork.sobjectTypesToBypassSharing.contains( Account.SObjectType ), 'bypassSharing, when called with a valid SobjectType, should register the sharing bypass' );
    }

    @isTest
    private static void bypassPermissions_whenCalledWithNullSobjectType_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType } );
        SObjectType nullSobjectType;

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.bypassPermissions( nullSobjectType );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'bypassPermissions, when called with a null type, should throw an exception' );
        Assert.areEqual( 'bypassPermissions called with a null type', thrownException.getMessage(), 'bypassPermissions, when called with a null type, should throw a ValidationException' );
    }

    @isTest
    private static void bypassPermissions_whenCalledWithSobjectTypeNotInSobjectTypeOperationOrder_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType } );
        SobjectType sobjectTypeNotInSobjectTypeOperationOrder = Contact.SObjectType;

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.bypassPermissions( sobjectTypeNotInSobjectTypeOperationOrder );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'bypassPermissions, when called with a type not in the sobjectTypeOperationOrder, should throw an exception' );
        Assert.areEqual( 'bypassPermissions called with a type that was not specified in the sobjectTypeOperationOrder when the UnitOfWork was constructed', thrownException.getMessage(), 'bypassPermissions, when called with a type not in the sobjectTypeOperationOrder, should throw a ValidationException' );
    }

    @isTest
    private static void bypassPermissions_whenCalledWithValidSobjectType_registersPermissionsBypass() {
        UnitOfWork unitOfWork = new UnitOfWork( new List<SObjectType> { Account.SObjectType } );
        SobjectType sobjectTypeToBypassPermissions = Account.SObjectType;

        Test.startTest();
        unitOfWork.bypassPermissions( sobjectTypeToBypassPermissions );
        Test.stopTest();

        Assert.isTrue( unitOfWork.sobjectTypesToBypassPermissions.contains( Account.SObjectType ), 'bypassPermissions, when called with a valid SobjectType, should register the permissions bypass' );
    }

    // oh so many commitWork test scenarios...
    // TODO: commitWork_whenCalledWithNoRegistrations_issuesNoDmlStatements()
    // ...

    private static User createMinimumAccessUser() {
        User minimumAccessUser = new User(
            ProfileId = minimumAccessProfileId,
            LastName = 'Test',
            Email = 'test@example.com',
            Username = 'test' + DateTime.now().getTime() + '@unit.of.work.test',
            Alias = 'test',
            TimeZoneSidKey = 'Europe/London',
            LocaleSidKey = 'en_GB',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_GB'
        );
        insert minimumAccessUser;
        return minimumAccessUser;
    }

    private static PermissionSet createPermissionSetWithPermissionForSobjectsAndFields( Map<SobjectType, List<SobjectField>> sobjectFieldsBySobjectType ) {
        PermissionSet requestedPermissionSet = new PermissionSet(
            Label = 'Permission Set For Sobjects',
            Name = 'Permission_Set_For_Sobjects'
        );
        insert requestedPermissionSet;

        List<ObjectPermissions> requestedObjectPermissions = new List<ObjectPermissions>();
        for ( SobjectType thisSobjectType : sobjectFieldsBySobjectType.keySet() ) {
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
        for ( SobjectType thisSobjectType : sobjectFieldsBySobjectType.keySet() ) {
            for ( SobjectField thisSobjectField : sobjectFieldsBySobjectType.get( thisSobjectType ) ) {
                requestedFieldPermissions.add( new FieldPermissions(
                    SobjectType = String.valueOf( thisSobjectType ),
                    Field = String.valueOf( thisSobjectField ),
                    PermissionsRead = true,
                    PermissionsEdit = true,
                    ParentId = requestedPermissionSet.Id
                ) );
            }
        }
        insert requestedFieldPermissions;

        return requestedPermissionSet;
    }
}