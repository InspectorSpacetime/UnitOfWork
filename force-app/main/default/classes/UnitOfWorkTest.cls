/*
MIT License

Copyright (c) 2026 Jai Jordan

https://github.com/InspectorSpacetime/UnitOfWork

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
@IsTest
@SuppressWarnings('PMD.MethodNamingConventions') // The use of underscores to separate method name, scenario and outcome is deliberate
@SuppressWarnings('PMD.CyclomaticComplexity') // This is a self-contained library test class so cyclomatic complexity is not a concern
@SuppressWarnings('PMD.NcssCount') // This is a self-contained library test class so class length is not a concern
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs') // Tests that test security do use runAs but some tests are for parameter validation
// CPD-OFF Apex tests methods often have similar structure to maintain readability
/**
 * @description Test class for the UnitOfWork class.
 * @author Jai Jordan
 * @date 2026-04-11
 * @version 1.0.2
 */
private class UnitOfWorkTest {

    private static final Id MINIMUM_ACCESS_PROFILE_ID = [ SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1 ].Id;
    private static Integer idsGenerated = 0;

    @IsTest
    private static void registerNew_whenCalledWithNullRecord_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
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

    @IsTest
    private static void registerNew_whenCalledWithRecordWithId_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
        Account accountWithId = new Account( Id = generateId( Account.SObjectType ), Name = 'Account with Id' );

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

    @IsTest
    private static void registerNew_whenCalledWithRecordInSobjectTypeOperationOrder_registersRecord() {
        UnitOfWork unitOfWork = new UnitOfWork();
        Account testAccount = new Account( Name = 'Test Account' );

        Test.startTest();
        unitOfWork.registerNew( testAccount );
        Test.stopTest();

        Assert.areEqual( testAccount, unitOfWork.newRecordsBySobjectType.get( Account.SObjectType )[0], 'registerNew, when called with a record in the sobjectTypeOperationOrder, should register the record' );
    }

    @IsTest
    private static void registerDirty_whenCalledWithNullRecord_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
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

    @IsTest
    private static void registerDirty_whenCalledWithRecordWithNullId_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
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

    @IsTest
    private static void registerDirty_whenCalledWithRecordInSobjectTypeOperationOrder_registersRecord() {
        UnitOfWork unitOfWork = new UnitOfWork();
        Account testAccount = new Account( Id = generateId( Account.SObjectType ), Name = 'Test Account' );

        Test.startTest();
        unitOfWork.registerDirty( testAccount );
        Test.stopTest();

        Assert.areEqual( testAccount, unitOfWork.dirtyRecordsBySobjectTypeAndRecordId.get( Account.SObjectType ).get( testAccount.Id ), 'registerDirty, when called with a record in the sobjectTypeOperationOrder, should register the record' );
    }

    @IsTest
    private static void registerDirty_whenCalledTwiceWithSameRecord_mergesRecords() {
        UnitOfWork unitOfWork = new UnitOfWork();
        Id accountId = generateId( Account.SObjectType );

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

    @IsTest
    private static void registerDeleted_whenCalledWithNullRecord_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
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

    @IsTest
    private static void registerDeleted_whenCalledWithRecordWithNullId_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
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

    @IsTest
    private static void registerDeleted_whenCalledWithRecordInSobjectTypeOperationOrder_registersRecord() {
        UnitOfWork unitOfWork = new UnitOfWork();
        Account testAccount = new Account( Id = generateId( Account.SObjectType ), Name = 'Test Account' );

        Test.startTest();
        unitOfWork.registerDeleted( testAccount );
        Test.stopTest();

        Assert.isTrue( unitOfWork.deletedRecordIdsBySobjectType.get( Account.SObjectType ).contains( testAccount.Id ), 'registerDeleted, when called with a record in the sobjectTypeOperationOrder, should register the record' );
    }

    @IsTest
    private static void registerPermanentlyDeleted_whenCalledWithNullRecord_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
        SObject nullRecord;

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerPermanentlyDeleted( nullRecord );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerPermanentlyDeleted, when called with a null record, should throw an exception' );
        Assert.areEqual( 'registerPermanentlyDeleted called with a null record', thrownException.getMessage(), 'registerPermanentlyDeleted, when called with a null record, should throw a ValidationException' );
    }

    @IsTest
    private static void registerPermanentlyDeleted_whenCalledWithRecordWithNullId_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
        Account accountWithNullId = new Account( Name = 'Account with Null Id' );

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerPermanentlyDeleted( accountWithNullId );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerPermanentlyDeleted, when called with a record with a null Id, should throw an exception' );
        Assert.areEqual( 'registerPermanentlyDeleted called with a record that does not have an Id', thrownException.getMessage(), 'registerPermanentlyDeleted, when called with a record with a null Id, should throw a ValidationException' );
    }

    @IsTest
    private static void registerPermanentlyDeleted_whenCalledWithRecordInSobjectTypeOperationOrder_registersRecord() {
        UnitOfWork unitOfWork = new UnitOfWork();
        Account testAccount = new Account( Id = generateId( Account.SObjectType ), Name = 'Test Account' );

        Test.startTest();
        unitOfWork.registerPermanentlyDeleted( testAccount );
        Test.stopTest();

        Assert.isTrue( unitOfWork.permanentlyDeletedRecordIdsBySobjectType.get( Account.SObjectType ).contains( testAccount.Id ), 'registerPermanentlyDeleted, when called with a record in the sobjectTypeOperationOrder, should register the record' );
    }

    @IsTest
    private static void registerNew_whenCalledWithListOfRecords_registersAllRecords() {
        UnitOfWork unitOfWork = new UnitOfWork();
        Account accountA = new Account( Name = 'Account A' );
        Account accountB = new Account( Name = 'Account B' );

        Test.startTest();
        unitOfWork.registerNew( new List<SObject>{ accountA, accountB } );
        Test.stopTest();

        List<SObject> registeredAccounts = unitOfWork.newRecordsBySobjectType.get( Account.SObjectType );
        Assert.areEqual( 2, registeredAccounts.size(), 'registerNew, when called with a list of records, should register all records' );
        Assert.isTrue( registeredAccounts.contains( accountA ), 'registerNew, when called with a list of records, should register the first record' );
        Assert.isTrue( registeredAccounts.contains( accountB ), 'registerNew, when called with a list of records, should register the second record' );
    }

    @IsTest
    private static void registerNew_whenCalledWithNullList_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
        List<SObject> nullRecords;

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerNew( nullRecords );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerNew, when called with a null records list, should throw an exception' );
        Assert.areEqual( 'registerNew called with a null records list', thrownException.getMessage(), 'registerNew, when called with a null records list, should throw a ValidationException' );
    }

    @IsTest
    private static void registerNew_whenCalledWithEmptyList_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerNew( new List<SObject>() );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerNew, when called with an empty records list, should throw an exception' );
        Assert.areEqual( 'registerNew called with an empty records list', thrownException.getMessage(), 'registerNew, when called with an empty records list, should throw a ValidationException' );
    }

    @IsTest
    private static void registerDirty_whenCalledWithListOfRecords_registersAllRecords() {
        UnitOfWork unitOfWork = new UnitOfWork();
        Account accountA = new Account( Id = generateId( Account.SObjectType ), Name = 'Account A' );
        Account accountB = new Account( Id = generateId( Account.SObjectType ), Name = 'Account B' );
 
        Test.startTest();
        unitOfWork.registerDirty( new List<SObject>{ accountA, accountB } );
        Test.stopTest();

        Map<Id, SObject> registeredAccounts = unitOfWork.dirtyRecordsBySobjectTypeAndRecordId.get( Account.SObjectType );
        Assert.areEqual( 2, registeredAccounts.size(), 'registerDirty, when called with a list of records, should register all records' );
        Assert.areEqual( accountA, registeredAccounts.get( accountA.Id ), 'registerDirty, when called with a list of records, should register the first record' );
        Assert.areEqual( accountB, registeredAccounts.get( accountB.Id ), 'registerDirty, when called with a list of records, should register the second record' );
    }

    @IsTest
    private static void registerDirty_whenCalledWithNullList_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
        List<SObject> nullRecords;

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerDirty( nullRecords );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerDirty, when called with a null records list, should throw an exception' );
        Assert.areEqual( 'registerDirty called with a null records list', thrownException.getMessage(), 'registerDirty, when called with a null records list, should throw a ValidationException' );
    }

    @IsTest
    private static void registerDirty_whenCalledWithEmptyList_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerDirty( new List<SObject>() );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerDirty, when called with an empty records list, should throw an exception' );
        Assert.areEqual( 'registerDirty called with an empty records list', thrownException.getMessage(), 'registerDirty, when called with an empty records list, should throw a ValidationException' );
    }

    @IsTest
    private static void registerDeleted_whenCalledWithListOfRecords_registersAllRecords() {
        UnitOfWork unitOfWork = new UnitOfWork();
        Account accountA = new Account( Id = generateId( Account.SObjectType ), Name = 'Account A' );
        Account accountB = new Account( Id = generateId( Account.SObjectType ), Name = 'Account B' );

        Test.startTest();
        unitOfWork.registerDeleted( new List<SObject>{ accountA, accountB } );
        Test.stopTest();

        Set<Id> registeredAccountIds = unitOfWork.deletedRecordIdsBySobjectType.get( Account.SObjectType );
        Assert.areEqual( 2, registeredAccountIds.size(), 'registerDeleted, when called with a list of records, should register all records' );
        Assert.isTrue( registeredAccountIds.contains( accountA.Id ), 'registerDeleted, when called with a list of records, should register the first record' );
        Assert.isTrue( registeredAccountIds.contains( accountB.Id ), 'registerDeleted, when called with a list of records, should register the second record' );
    }

    @IsTest
    private static void registerDeleted_whenCalledWithNullList_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
        List<SObject> nullRecords;

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerDeleted( nullRecords );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerDeleted, when called with a null records list, should throw an exception' );
        Assert.areEqual( 'registerDeleted called with a null records list', thrownException.getMessage(), 'registerDeleted, when called with a null records list, should throw a ValidationException' );
    }

    @IsTest
    private static void registerDeleted_whenCalledWithEmptyList_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerDeleted( new List<SObject>() );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerDeleted, when called with an empty records list, should throw an exception' );
        Assert.areEqual( 'registerDeleted called with an empty records list', thrownException.getMessage(), 'registerDeleted, when called with an empty records list, should throw a ValidationException' );
    }

    @IsTest
    private static void registerPermanentlyDeleted_whenCalledWithListOfRecords_registersAllRecords() {
        UnitOfWork unitOfWork = new UnitOfWork();
        Account accountA = new Account( Id = generateId( Account.SObjectType ), Name = 'Account A' );
        Account accountB = new Account( Id = generateId( Account.SObjectType ), Name = 'Account B' );

        Test.startTest();
        unitOfWork.registerPermanentlyDeleted( new List<SObject>{ accountA, accountB } );
        Test.stopTest();

        Set<Id> registeredAccountIds = unitOfWork.permanentlyDeletedRecordIdsBySobjectType.get( Account.SObjectType );
        Assert.areEqual( 2, registeredAccountIds.size(), 'registerPermanentlyDeleted, when called with a list of records, should register all records' );
        Assert.isTrue( registeredAccountIds.contains( accountA.Id ), 'registerPermanentlyDeleted, when called with a list of records, should register the first record' );
        Assert.isTrue( registeredAccountIds.contains( accountB.Id ), 'registerPermanentlyDeleted, when called with a list of records, should register the second record' );
    }

    @IsTest
    private static void registerPermanentlyDeleted_whenCalledWithNullList_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
        List<SObject> nullRecords;

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerPermanentlyDeleted( nullRecords );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerPermanentlyDeleted, when called with a null records list, should throw an exception' );
        Assert.areEqual( 'registerPermanentlyDeleted called with a null records list', thrownException.getMessage(), 'registerPermanentlyDeleted, when called with a null records list, should throw a ValidationException' );
    }

    @IsTest
    private static void registerPermanentlyDeleted_whenCalledWithEmptyList_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerPermanentlyDeleted( new List<SObject>() );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerPermanentlyDeleted, when called with an empty records list, should throw an exception' );
        Assert.areEqual( 'registerPermanentlyDeleted called with an empty records list', thrownException.getMessage(), 'registerPermanentlyDeleted, when called with an empty records list, should throw a ValidationException' );
    }

    @IsTest
    private static void registerRelationship_whenCalledWithNullRecord_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
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

    @IsTest
    private static void registerRelationship_whenCalledWithNullRelationshipField_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
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

    @IsTest
    private static void registerRelationship_whenCalledWithNullParentRecord_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
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

    @IsTest
    private static void registerRelationship_whenCalledWithRelationshipFieldNotOnRecordSobjectType_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
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

    @IsTest
    private static void registerRelationship_whenCalledWithValidParameters_registersRelationship() {
        UnitOfWork unitOfWork = new UnitOfWork();
        Contact testContact = new Contact( FirstName = 'John', LastName = 'Smith' );
        SObjectField relationshipField = Contact.AccountId;
        Account parentRecord = new Account( Name = 'Parent Account' );

        Test.startTest();
        unitOfWork.registerRelationship( testContact, relationshipField, parentRecord );
        Test.stopTest();

        Assert.isTrue( unitOfWork.relationships.relationshipsBySobjectType.containsKey( Contact.SObjectType ), 'registerRelationship, when called with valid parameters, should register the relationship for the record SObjectType' );
        Assert.areEqual( 1, unitOfWork.relationships.relationshipsBySobjectType.get( Contact.SObjectType ).size(), 'registerRelationship, when called with valid parameters, should register one relationship' );
    }

    @IsTest
    private static void registerRelationship_whenSameFieldRegisteredTwiceForSameRecord_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
        Contact testContact = new Contact( FirstName = 'John', LastName = 'Smith' );
        Account account1 = new Account( Name = 'Account 1' );
        Account account2 = new Account( Name = 'Account 2' );

        unitOfWork.registerRelationship( testContact, Contact.AccountId, account1 );

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerRelationship( testContact, Contact.AccountId, account2 );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerRelationship, when the same field is registered twice for the same record, should throw an exception' );
        Assert.areEqual( 'registerRelationship called with a relationship field that has already been registered for this record', thrownException.getMessage(), 'registerRelationship, when the same field is registered twice for the same record, should throw a ValidationException' );
    }

    @IsTest
    private static void registerRelationship_whenParentRecordAlreadyRegisteredForDeletion_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
        Contact testContact = new Contact( FirstName = 'John', LastName = 'Smith' );
        Account parentAccount = new Account( Id = generateId( Account.SObjectType ), Name = 'Parent Account' );

        unitOfWork.registerDeleted( parentAccount );

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerRelationship( testContact, Contact.AccountId, parentAccount );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerRelationship, when the parent record has been registered for deletion, should throw an exception' );
        Assert.areEqual( 'registerRelationship called with a parent record that has been registered for deletion', thrownException.getMessage(), 'registerRelationship, when the parent record has been registered for deletion, should throw a ValidationException' );
    }

    @IsTest
    private static void registerRelationship_whenParentRecordAlreadyRegisteredForPermanentDeletion_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
        Contact testContact = new Contact( FirstName = 'John', LastName = 'Smith' );
        Account parentAccount = new Account( Id = generateId( Account.SObjectType ), Name = 'Parent Account' );

        unitOfWork.registerPermanentlyDeleted( parentAccount );

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerRelationship( testContact, Contact.AccountId, parentAccount );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerRelationship, when the parent record has been registered for permanent deletion, should throw an exception' );
        Assert.areEqual( 'registerRelationship called with a parent record that has been registered for deletion', thrownException.getMessage(), 'registerRelationship, when the parent record has been registered for permanent deletion, should throw a ValidationException' );
    }

    @IsTest
    private static void registerDeleted_whenRecordIsParentOfRegisteredRelationship_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
        Contact testContact = new Contact( FirstName = 'John', LastName = 'Smith' );
        Account parentAccount = new Account( Id = generateId( Account.SObjectType ), Name = 'Parent Account' );

        unitOfWork.registerRelationship( testContact, Contact.AccountId, parentAccount );

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerDeleted( parentAccount );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerDeleted, when the record is the parent of a registered relationship, should throw an exception' );
        Assert.areEqual( 'registerDeleted called with a record that is the parent of a registered relationship', thrownException.getMessage(), 'registerDeleted, when the record is the parent of a registered relationship, should throw a ValidationException' );
    }

    @IsTest
    private static void registerPermanentlyDeleted_whenRecordIsParentOfRegisteredRelationship_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
        Contact testContact = new Contact( FirstName = 'John', LastName = 'Smith' );
        Account parentAccount = new Account( Id = generateId( Account.SObjectType ), Name = 'Parent Account' );

        unitOfWork.registerRelationship( testContact, Contact.AccountId, parentAccount );

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.registerPermanentlyDeleted( parentAccount );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'registerPermanentlyDeleted, when the record is the parent of a registered relationship, should throw an exception' );
        Assert.areEqual( 'registerPermanentlyDeleted called with a record that is the parent of a registered relationship', thrownException.getMessage(), 'registerPermanentlyDeleted, when the record is the parent of a registered relationship, should throw a ValidationException' );
    }

    @IsTest
    private static void bypassSharing_whenCalledWithNullSobjectType_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
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

    @IsTest
    private static void bypassSharing_whenCalledWithValidSobjectType_registersSharingBypass() {
        UnitOfWork unitOfWork = new UnitOfWork();
        SobjectType sobjectTypeToBypassSharing = Account.SObjectType;

        Test.startTest();
        unitOfWork.bypassSharing( sobjectTypeToBypassSharing );
        Test.stopTest();

        Assert.isTrue( unitOfWork.sobjectTypesToBypassSharing.contains( Account.SObjectType ), 'bypassSharing, when called with a valid SobjectType, should register the sharing bypass' );
    }

    @IsTest
    private static void bypassPermissions_whenCalledWithNullSobjectType_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
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

    @IsTest
    private static void bypassPermissions_whenCalledWithValidSobjectType_registersPermissionsBypass() {
        UnitOfWork unitOfWork = new UnitOfWork();
            SobjectType sobjectTypeToBypassPermissions = Account.SObjectType;

            Test.startTest();
        unitOfWork.bypassPermissions( sobjectTypeToBypassPermissions );
        Test.stopTest();

        Assert.isTrue( unitOfWork.sobjectTypesToBypassPermissions.contains( Account.SObjectType ), 'bypassPermissions, when called with a valid SobjectType, should register the permissions bypass' );
    }

    @IsTest
    private static void prioritiseRelationship_whenCalledWithNullPriorityField_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
        SObjectField nullField;

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.prioritiseRelationship( nullField, Contact.AccountId );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'prioritiseRelationship, when called with a null priorityField, should throw an exception' );
        Assert.areEqual( 'prioritiseRelationship called with a null priorityField', thrownException.getMessage(), 'prioritiseRelationship, when called with a null priorityField, should throw a ValidationException' );
    }

    @IsTest
    private static void prioritiseRelationship_whenCalledWithNullSecondaryField_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
        SObjectField nullField;

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.prioritiseRelationship( Contact.AccountId, nullField );
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'prioritiseRelationship, when called with a null secondaryField, should throw an exception' );
        Assert.areEqual( 'prioritiseRelationship called with a null secondaryField', thrownException.getMessage(), 'prioritiseRelationship, when called with a null secondaryField, should throw a ValidationException' );
    }

    @IsTest
    private static void commitWork_whenCalledWithNoRegistrations_issuesNoDmlStatements() {
        UnitOfWork unitOfWork = new UnitOfWork();

            Integer dmlStatementsIssuedBefore = Limits.getDmlStatements();

            Test.startTest();
        unitOfWork.commitWork();
        Test.stopTest();

        Integer dmlStatementsIssuedAfter = Limits.getDmlStatements();

        Assert.areEqual( dmlStatementsIssuedBefore, dmlStatementsIssuedAfter, 'commitWork, when called with no registrations, should issue no Dml statements' );
    }

    @IsTest
    private static void commitWork_whenCalledTwice_throwsValidationException() {
        UnitOfWork unitOfWork = new UnitOfWork();
        unitOfWork.commitWork();

        UnitOfWork.ValidationException thrownException;

        Test.startTest();
        try {
            unitOfWork.commitWork();
        }
        catch ( UnitOfWork.ValidationException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'commitWork, when called twice on the same instance, should throw an exception on the second call' );
        Assert.areEqual( 'commitWork has already been called on this UnitOfWork instance', thrownException.getMessage(), 'commitWork, when called twice, should throw a ValidationException' );
    }

    @IsTest
    private static void commitWork_whenInterTypeCircularRelationshipsRegisteredWithoutPrioritise_throwsCommitException() {
        UnitOfWork unitOfWork = new UnitOfWork();

        SobjectField contactLookupOnAccount = Account.Site;

        Account testAccount = new Account( Name = 'Test Account' );
        Contact testContact = new Contact( FirstName = 'Test', LastName = 'Contact' );

        unitOfWork.registerNew( testAccount );
        unitOfWork.registerNew( testContact );

        // Both relationships are registered with neither marked as secondary — this creates an unresolvable cycle
        unitOfWork.registerRelationship( testContact, Contact.AccountId, testAccount );
        unitOfWork.registerRelationship( testAccount, contactLookupOnAccount, testContact );

        UnitOfWork.CommitException thrownException;

        Test.startTest();
        try {
            unitOfWork.commitWork();
        }
        catch ( UnitOfWork.CommitException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'commitWork, when inter-type circular relationships are registered without prioritiseRelationship, should throw an exception' );
        Assert.isTrue( thrownException.getMessage().contains( 'Circular relationship detected between SObject types' ), 'commitWork, when inter-type circular relationships are registered without prioritiseRelationship, should throw a CommitException with a useful message' );
    }

    @IsTest
    private static void commitWork_whenIntraSobjectCircularRelationshipRegistered_throwsCommitException() {
        UnitOfWork unitOfWork = new UnitOfWork();

        Account accountA = new Account( Name = 'Account A' );
        Account accountB = new Account( Name = 'Account B' );

        unitOfWork.registerNew( accountA );
        unitOfWork.registerNew( accountB );

        // A → B → A creates an unresolvable intra-type cycle
        unitOfWork.registerRelationship( accountA, Account.ParentId, accountB );
        unitOfWork.registerRelationship( accountB, Account.ParentId, accountA );

        UnitOfWork.CommitException thrownException;

        Test.startTest();
        try {
            unitOfWork.commitWork();
        }
        catch ( UnitOfWork.CommitException ex ) {
            thrownException = ex;
        }
        Test.stopTest();

        Assert.isNotNull( thrownException, 'commitWork, when an intra-SObject circular relationship is registered, should throw an exception' );
        Assert.isTrue( thrownException.getMessage().contains( 'Circular intra-type relationship detected' ), 'commitWork, when an intra-SObject circular relationship is registered, should throw a CommitException with a useful message' );
    }

    @IsTest
    private static void commitWork_whenCalledAfterRelationshipRegistration_createsRecords() {
        UnitOfWork unitOfWork = new UnitOfWork();

        User testUser = createUserWithPermissionsForSobjectsAndFields( new Set<SobjectType> { Account.SObjectType, Contact.SObjectType }, new Set<SobjectField> { Contact.AccountId } );

        Account testAccount = new Account( Name = 'Test Account' );
        Contact testContact = new Contact( FirstName = 'Test', LastName = 'Contact' );

        Account testAccount2 = new Account( Name = 'Test Account 2' );
        Contact testContact2 = new Contact( FirstName = 'Test', LastName = 'Contact 2' );

        unitOfWork.registerNew( testAccount );
        unitOfWork.registerNew( testContact );
        unitOfWork.registerRelationship( testContact, Contact.AccountId, testAccount );

        unitOfWork.registerNew( testAccount2 );
        unitOfWork.registerNew( testContact2 );
        unitOfWork.registerRelationship( testContact2, Contact.AccountId, testAccount2 );

        Integer dmlStatementsIssuedBefore;
        Integer dmlRowsIssuedBefore;
        Integer dmlStatementsIssuedAfter;
        Integer dmlRowsIssuedAfter;

        Test.startTest();
        System.runAs( testUser ) {
            dmlStatementsIssuedBefore = Limits.getDmlStatements();
            dmlRowsIssuedBefore = Limits.getDmlRows();

            unitOfWork.commitWork();

            dmlStatementsIssuedAfter = Limits.getDmlStatements();
            dmlRowsIssuedAfter = Limits.getDmlRows();
        }
        Test.stopTest();

        Assert.isNotNull( testAccount.Id, 'commitWork, when called with an after relationship registration, should create the parent record' );
        Assert.isNotNull( testContact.Id, 'commitWork, when called with an after relationship registration, should create the child record' );
        Assert.areEqual( testAccount.Id, testContact.AccountId, 'commitWork, when called with an after relationship registration, should set the relationship field' );

        Assert.isNotNull( testAccount2.Id, 'commitWork, when called with an after relationship registration, should create the parent record' );
        Assert.isNotNull( testContact2.Id, 'commitWork, when called with an after relationship registration, should create the child record' );
        Assert.areEqual( testAccount2.Id, testContact2.AccountId, 'commitWork, when called with an after relationship registration, should set the relationship field' );

        // Note that the Savepoint creation consumes 1 DML statement but no DML rows
        Assert.areEqual( dmlStatementsIssuedBefore + 3, dmlStatementsIssuedAfter, 'commitWork, when called with an after relationship registration, should issue 2 only DML statements' );
        Assert.areEqual( dmlRowsIssuedBefore + 4, dmlRowsIssuedAfter, 'commitWork, when called with an after relationship registration, should issue only 4 DML rows' );
    }

    @IsTest
    private static void commitWork_whenCalledAfterDeletionRegisteredWhereHardDependencyPreventsDeletion_throwsExceptionAndRollsBack() {
        // Contract is not available in every org, so this test uses dynamic references to avoid
        // introducing a compile-time dependency on the object while still exercising the same rollback scenario.
        SObjectType contractSObjectType = Schema.getGlobalDescribe().get( 'Contract' );
        if ( contractSObjectType == null ) {
            return;
        }

        UnitOfWork unitOfWork = new UnitOfWork();

        User testUser = createUserWithPermissionsForSobjectsAndFields(
            new Set<SobjectType> { Account.SObjectType, contractSObjectType },
            new Set<SobjectField> {}
        );

        Account testAccount;
        SObject testContract;

        System.runAs( testUser ) {
            testAccount = new Account( Name = 'Test Account' );
            insert testAccount;

            testContract = contractSObjectType.newSObject();
            testContract.put( 'AccountId', testAccount.Id );
            testContract.put( 'Status', 'Draft' );
            insert testContract;

            testContract.put( 'Status', 'Activated' );
            update testContract;
        }

        UnitOfWork.CommitException thrownException;

        Test.startTest();
        System.runAs( testUser ) {
            try {
                unitOfWork.registerDeleted( testAccount );
                unitOfWork.commitWork();
            }
            catch ( UnitOfWork.CommitException ex ) {
                thrownException = ex;
            }
        }
        Test.stopTest();

        Integer numberOfAccountsAfter = [ SELECT COUNT() FROM Account WHERE Id = :testAccount.Id ];
        Integer numberOfContractsAfter = Database.countQuery(
            'SELECT COUNT() FROM Contract WHERE Id = \'' + String.escapeSingleQuotes( String.valueOf( testContract.get( 'Id' ) ) ) + '\' ALL ROWS'
        );

        Assert.isNotNull( thrownException, 'commitWork, when called after deletion registration where hard dependency prevents deletion, should throw an exception' );
        Assert.areEqual( 1, numberOfAccountsAfter, 'commitWork, when called after deletion registration where hard dependency prevents deletion, should roll back the account deletion' );
        Assert.areEqual( 1, numberOfContractsAfter, 'commitWork, when called after deletion registration where hard dependency prevents deletion, should leave the related contract in place' );
    }

    @IsTest
    private static void commitWork_whenInsertingRecordTheUserHasPermissionForAndThenOneItDoesntHavePermissionsFor_throwsExceptionAndRollsBack() {
        UnitOfWork unitOfWork = new UnitOfWork();

        User testUser = createUserWithPermissionsForSobjectsAndFields( new Set<SobjectType> { Account.SObjectType }, new Set<SobjectField> {} );

        Account testAccount = new Account( Name = 'Test Account' );
        Contact testContact = new Contact( FirstName = 'Test', LastName = 'Contact' );

        unitOfWork.registerNew( testAccount );
        unitOfWork.registerNew( testContact );
        unitOfWork.registerRelationship( testContact, Contact.AccountId, testAccount );

        Integer numberOfAccountsBefore = [ SELECT COUNT() FROM Account ];
        Integer numberOfContactsBefore = [ SELECT COUNT() FROM Contact ];

        UnitOfWork.CommitException thrownException;

        Test.startTest();
        System.runAs( testUser ) {
            try {
                unitOfWork.commitWork();
            }
            catch ( UnitOfWork.CommitException ex ) {
                thrownException = ex;
            }
        }
        Test.stopTest();

        Integer numberOfAccountsAfter = [ SELECT COUNT() FROM Account ];
        Integer numberOfContactsAfter = [ SELECT COUNT() FROM Contact ];

        Assert.isNotNull( thrownException, 'commitWork, when inserting a record the user has permission for and then one it doesn\'t have permissions for, should throw an exception' );
        Assert.areEqual( 'commitWork failed with exception: Access to entity \'Contact\' denied', thrownException.getMessage(), 'commitWork, when inserting a record the user has permission for and then one it doesn\'t have permissions for, should throw a CommitException' );

        Assert.areEqual( numberOfAccountsBefore, numberOfAccountsAfter, 'commitWork, when inserting a record the user has permission for and then one it doesn\'t have permissions for, should roll back the transaction' );
        Assert.areEqual( numberOfContactsBefore, numberOfContactsAfter, 'commitWork, when inserting a record the user has permission for and then one it doesn\'t have permissions for, should roll back the transaction' );
    }

    @IsTest
    private static void commitWork_whenUpdatingRecordTheUserHasPermissionForAndThenOneItDoesNot_throwsExceptionAndRollsBack() {
        UnitOfWork unitOfWork = new UnitOfWork();

        User otherUser = createUserWithPermissionsForSobjectsAndFields( new Set<SobjectType> { Contact.SObjectType }, new Set<SobjectField> {} );
        User testUser = createUserWithPermissionsForSobjectsAndFields( new Set<SobjectType> { Account.SObjectType }, new Set<SobjectField> {} );

        Account testAccount = new Account( Name = 'Test Account' );
        Contact testContact = new Contact( FirstName = 'Test', LastName = 'Contact' );

        System.runAs( otherUser ) {
            insert testContact;
        }

        System.runAs( testUser ) {
            insert testAccount;
        }

        UnitOfWork.CommitException thrownException;

        Test.startTest();
        System.runAs( testUser ) {
            try {
                Account modifiedTestAccount = new Account( Id = testAccount.Id, Name = 'Modified Test Account' );

                unitOfWork.registerDirty( modifiedTestAccount );
                unitOfWork.registerDirty( testContact );
                unitOfWork.commitWork();
            }
            catch ( UnitOfWork.CommitException ex ) {
                thrownException = ex;
            }
        }
        Test.stopTest();

        Account updatedTestAccount = [ SELECT Id, Name FROM Account WHERE Id = :testAccount.Id ];

        Assert.isNotNull( thrownException, 'commitWork, when updating a record the user has permission for and then one it does not, should throw an exception' );
        Assert.areEqual( 'commitWork failed with exception: Access to entity \'Contact\' denied', thrownException.getMessage(), 'commitWork, when updating a record the user has permission for and then one it does not, should throw a CommitException' );
        Assert.areEqual( 'Test Account', updatedTestAccount.Name, 'commitWork, when updating a record the user has permission for and then one it does not, should roll back the transaction' );
    }

    @IsTest
    private static void commitWork_whenDeletingRecordTheUserHasPermissionForAndThenOneItDoesNot_throwsExceptionAndRollsBack() {
        UnitOfWork unitOfWork = new UnitOfWork();

        User otherUser = createUserWithPermissionsForSobjectsAndFields( new Set<SobjectType> { Contact.SObjectType }, new Set<SobjectField> {} );
        User testUser = createUserWithPermissionsForSobjectsAndFields( new Set<SobjectType> { Account.SObjectType }, new Set<SobjectField> {} );

        Account testAccount = new Account( Name = 'Test Account' );
        Contact testContact = new Contact( FirstName = 'Test', LastName = 'Contact' );

        System.runAs( otherUser ) {
            insert testContact;
        }

        System.runAs( testUser ) {
            insert testAccount;
        }

        UnitOfWork.CommitException thrownException;

        Test.startTest();
        System.runAs( testUser ) {
            try {
                unitOfWork.registerDeleted( testAccount );
                unitOfWork.registerDeleted( testContact );
                unitOfWork.commitWork();
            }
            catch ( UnitOfWork.CommitException ex ) {
                thrownException = ex;
            }
        }
        Test.stopTest();

        List<Account> testAccountsAfter = [ SELECT Id FROM Account WHERE Id = :testAccount.Id ];
        List<Contact> testContactsAfter = [ SELECT Id FROM Contact WHERE Id = :testContact.Id ];

        Assert.isNotNull( thrownException, 'commitWork, when deleting a record the user has permission for and then one it does not, should throw an exception' );
        Assert.areEqual( 'commitWork failed with exception: Access to entity \'Contact\' denied', thrownException.getMessage(), 'commitWork, when deleting a record the user has permission for and then one it does not, should throw a CommitException' );
        Assert.isFalse( testAccountsAfter.isEmpty(), 'commitWork, when deleting a record the user has permission for and then one it does not, should roll back the transaction - account not deleted' );
        Assert.isFalse( testContactsAfter.isEmpty(), 'commitWork, when deleting a record the user has permission for and then one it does not, should roll back the transaction - contact not deleted' );
    }

    @IsTest
    private static void commitWork_whenInsertingRecordTheUserHasPermissionForAndThenOneItDoesntHavePermissionsForButHasBypassPermission_commitsSuccessfully() {
        UnitOfWork unitOfWork = new UnitOfWork();

        User testUser = createUserWithPermissionsForSobjectsAndFields( new Set<SobjectType> { Account.SObjectType }, new Set<SobjectField> {} );

        Account testAccount = new Account( Name = 'Test Account' );
        Contact testContact = new Contact( FirstName = 'Test', LastName = 'Contact' );

        unitOfWork.registerNew( testAccount );
        unitOfWork.registerNew( testContact );
        unitOfWork.registerRelationship( testContact, Contact.AccountId, testAccount );
        unitOfWork.bypassPermissions( Contact.SObjectType );
        unitOfWork.bypassSharing( Contact.SObjectType );

        Test.startTest();
        System.runAs( testUser ) {
            unitOfWork.commitWork();
        }
        Test.stopTest();

        Assert.isNotNull( testAccount.Id, 'commitWork, when inserting a record the user has permission for and then one it doesn\'t have permissions for but has a bypass permission for, should commit successfully - account' );
        Assert.isNotNull( testContact.Id, 'commitWork, when inserting a record the user has permission for and then one it doesn\'t have permissions for but has a bypass permission for, should commit successfully - contact' );
    }

    @IsTest
    private static void commitWork_whenUpdatingRecordTheUserHasPermissionForAndThenOneItDoesNotButHasBypassPermission_commitsSuccessfully() {
        UnitOfWork unitOfWork = new UnitOfWork();

        User otherUser = createUserWithPermissionsForSobjectsAndFields( new Set<SobjectType> { Contact.SObjectType }, new Set<SobjectField> {} );
        User testUser = createUserWithPermissionsForSobjectsAndFields( new Set<SobjectType> { Account.SObjectType }, new Set<SobjectField> {} );

        Account testAccount = new Account( Name = 'Test Account' );
        Contact testContact = new Contact( FirstName = 'Test', LastName = 'Contact' );

        System.runAs( otherUser ) {
            insert testContact;
        }

        System.runAs( testUser ) {
            insert testAccount;
        }

        Test.startTest();
        System.runAs( testUser ) {
            Account modifiedTestAccount = new Account( Id = testAccount.Id, Name = 'Modified Test Account' );
            Contact modifiedTestContact = new Contact( Id = testContact.Id, FirstName = 'Modified Test', LastName = 'Contact' );

            unitOfWork.registerDirty( modifiedTestAccount );
            unitOfWork.registerDirty( modifiedTestContact );
            unitOfWork.bypassPermissions( Contact.SObjectType );
            unitOfWork.bypassSharing( Contact.SObjectType );
            unitOfWork.commitWork();
        }
        Test.stopTest();

        Account updatedTestAccount = [ SELECT Id, Name FROM Account WHERE Id = :testAccount.Id ];
        Contact updatedTestContact = [ SELECT Id, FirstName, LastName FROM Contact WHERE Id = :testContact.Id ];

        Assert.areEqual( 'Modified Test Account', updatedTestAccount.Name, 'commitWork, when updating a record the user has permission for and then one it does not, should throw an exception' );
        Assert.areEqual( 'Modified Test', updatedTestContact.FirstName, 'commitWork, when updating a record the user has permission for and then one it does not, should throw an exception' );
    }

    @IsTest
    private static void commitWork_whenDeletingRecordTheUserHasPermissionForAndThenOneItDoesNotButHasBypassPermission_commitsSuccessfully() {
        UnitOfWork unitOfWork = new UnitOfWork();

        User otherUser = createUserWithPermissionsForSobjectsAndFields( new Set<SobjectType> { Contact.SObjectType }, new Set<SobjectField> {} );
        User testUser = createUserWithPermissionsForSobjectsAndFields( new Set<SobjectType> { Account.SObjectType }, new Set<SobjectField> {} );

        Account testAccount = new Account( Name = 'Test Account' );
        Contact testContact = new Contact( FirstName = 'Test', LastName = 'Contact' );

        System.runAs( otherUser ) {
            insert testContact;
        }

        System.runAs( testUser ) {
            insert testAccount;
        }

        Test.startTest();
        System.runAs( testUser ) {
            unitOfWork.registerDeleted( testAccount );
            unitOfWork.registerDeleted( testContact );
            unitOfWork.bypassPermissions( Contact.SObjectType );
            unitOfWork.bypassSharing( Contact.SObjectType );
            unitOfWork.commitWork();
        }
        Test.stopTest();

        List<Account> testAccountsAfter = [ SELECT Id FROM Account WHERE Id = :testAccount.Id ];
        List<Contact> testContactsAfter = [ SELECT Id FROM Contact WHERE Id = :testContact.Id ];

        Assert.isTrue( testAccountsAfter.isEmpty(), 'commitWork, when deleting a record the user has permission for and then one it does not have permission for but has a bypass permission for, should commit successfully - account deleted' );
        Assert.isTrue( testContactsAfter.isEmpty(), 'commitWork, when deleting a record the user has permission for and then one it does not have permission for but has a bypass permission for, should commit successfully - contact deleted' );
    }

    @IsTest
    private static void commitWork_whenRecordIsRegisteredForPermanentDeletion_deletesAndCallsHardDeleteSuccessfully() {
        UnitOfWork unitOfWork = new UnitOfWork();

        User testUser = createUserWithPermissionsForSobjectsAndFields( new Set<SobjectType> { Account.SObjectType }, new Set<SobjectField> {} );

        Account testAccount;
        System.runAs( testUser ) {
            testAccount = new Account( Name = 'Test Account' );
            insert testAccount;
        }

        Test.startTest();
        System.runAs( testUser ) {
            unitOfWork.registerPermanentlyDeleted( testAccount );
            unitOfWork.commitWork();
        }
        Test.stopTest();

        List<Account> liveAccountsAfter = [ SELECT Id FROM Account WHERE Id = :testAccount.Id ];

        Assert.isTrue( liveAccountsAfter.isEmpty(), 'commitWork, when a record is registered for permanent deletion, should remove it from normal queries' );
        Assert.isTrue( unitOfWork.successfullyPermanentlyDeletedRecordIds.contains( testAccount.Id ), 'commitWork, when a record is registered for permanent deletion, should record a successful hard delete result for that record' );
    }

    @IsTest
    private static void commitWork_whenIntraSobjectRelationshipRegistered_splitsDmlAndCommitsSuccessfully() {
        UnitOfWork uow = new UnitOfWork();

        User testUser = createUserWithPermissionsForSobjectsAndFields( new Set<SobjectType> { Account.SObjectType, Contact.SObjectType }, new Set<SobjectField> { Account.ParentId, Contact.AccountId } );

        Account childAccount = new Account( Name = 'Child account' );
        uow.registerNew( childAccount );

        Contact childAccountContact = new Contact( LastName = 'Smith' );
        uow.registerNew( childAccountContact );
        uow.registerRelationship( childAccountContact, Contact.AccountId, childAccount );

        Account parentAccount = new Account( Name = 'Parent account' );
        uow.registerNew( parentAccount );
        uow.registerRelationship( childAccount, Account.ParentId, parentAccount );

        Contact parentAccountContact = new Contact( LastName = 'Johnson' );
        uow.registerNew( parentAccountContact );
        uow.registerRelationship( parentAccountContact, Contact.AccountId, parentAccount );

        Map<Id,Account> testAccountsAfter;
        Map<Id,Contact> testContactsAfter;
        Integer dmlStatementsIssuedBefore;
        Integer dmlRowsIssuedBefore;
        Integer dmlStatementsIssuedAfter;
        Integer dmlRowsIssuedAfter;

        Test.startTest();
        System.runAs( testUser ) {
            dmlStatementsIssuedBefore = Limits.getDmlStatements();
            dmlRowsIssuedBefore = Limits.getDmlRows();

            uow.commitWork();

            dmlStatementsIssuedAfter = Limits.getDmlStatements();
            dmlRowsIssuedAfter = Limits.getDmlRows();

            testAccountsAfter = new Map<Id,Account>([ SELECT Id, Name, ParentId FROM Account WHERE Id IN :new List<Id>{ childAccount.Id, parentAccount.Id } ]);
            testContactsAfter = new Map<Id,Contact>([ SELECT Id, LastName, AccountId FROM Contact WHERE Id IN :new List<Id>{ childAccountContact.Id, parentAccountContact.Id } ]);
        }
        Test.stopTest();

        // Note that the Savepoint creation consumes 1 DML statement but no DML rows
        Integer expectedExtraDmlStatements = 1 + 3; // 1 is used by SavePoint, 1 by the parent account, 1 by the child account and 1 by the contacts.
        Integer expectedExtraDmlRows = 4; // 1 by the parent account, 1 by the child account and 1 for each contact.

        Assert.areEqual( dmlStatementsIssuedBefore + expectedExtraDmlStatements, dmlStatementsIssuedAfter, 'commitWork, when called with an intra-sobject relationship registration, should issue the minimum required number of DML statements' );
        Assert.areEqual( dmlRowsIssuedBefore + expectedExtraDmlRows, dmlRowsIssuedAfter, 'commitWork, when called with an intra-sobject relationship registration, should issue the minimum required number of DML rows' );

        Assert.isTrue( testAccountsAfter.size() == 2, 'commitWork, when called with an intra-sobject relationship registration, should commit all accounts' );
        Assert.isTrue( testContactsAfter.size() == 2, 'commitWork, when called with an intra-sobject relationship registration, should commit all contacts' );

        Account parentAccountAfter = testAccountsAfter.get( parentAccount.Id );
        Account childAccountAfter = testAccountsAfter.get( childAccount.Id );
        Contact parentAccountContactAfter = testContactsAfter.get( parentAccountContact.Id );
        Contact childAccountContactAfter = testContactsAfter.get( childAccountContact.Id );

        Assert.areEqual( parentAccount.Name, parentAccountAfter.Name, 'commitWork, when called with an intra-sobject relationship registration, should commit the parent account' );
        Assert.areEqual( childAccount.Name, childAccountAfter.Name, 'commitWork, when called with an intra-sobject relationship registration, should commit the child account' );
        Assert.areEqual( parentAccountContact.LastName, parentAccountContactAfter.LastName, 'commitWork, when called with an intra-sobject relationship registration, should commit the parent account contact' );
        Assert.areEqual( childAccountContact.LastName, childAccountContactAfter.LastName, 'commitWork, when called with an intra-sobject relationship registration, should commit the child account contact' );

        Assert.areEqual( parentAccount.Id, childAccountAfter.ParentId, 'commitWork, when called with an intra-sobject relationship registration, should set the parent account relationship on the child account' );
        Assert.areEqual( childAccount.Id, childAccountContactAfter.AccountId, 'commitWork, when called with an intra-sobject relationship registration, should set the child account relationship on the parent account contact' );
        Assert.areEqual( parentAccount.Id, parentAccountContactAfter.AccountId, 'commitWork, when called with an intra-sobject relationship registration, should set the parent account relationship on the parent account contact' );
    }

    @IsTest
    private static void commitWork_whenCircularRelationshipsRegistered_splitsDmlAndCommitsSuccessfully() {
        UnitOfWork uow = new UnitOfWork();

        // We can't ship a custom field for the UnitOfWork tests so we simulate one using the Site field on Account.
        SobjectField contactLookupOnAccount = Account.Site;

        User testUser = createUserWithPermissionsForSobjectsAndFields( new Set<SobjectType> { Account.SObjectType, Contact.SObjectType }, new Set<SobjectField> { Contact.AccountId, contactLookupOnAccount } );

        Account testAccount = new Account( Name = 'Test account' );
        uow.registerNew( testAccount );

        Contact testContact = new Contact( LastName = 'Test contact' );
        uow.registerNew( testContact );

        uow.registerRelationship( testContact, Contact.AccountId, testAccount );
        uow.registerRelationship( testAccount, contactLookupOnAccount, testContact );
        uow.prioritiseRelationship( Contact.AccountId, contactLookupOnAccount );

        Account testAccountAfter;
        Contact testContactAfter;
        Integer dmlStatementsIssuedBefore;
        Integer dmlRowsIssuedBefore;
        Integer dmlStatementsIssuedAfter;
        Integer dmlRowsIssuedAfter;

        Test.startTest();
        System.runAs( testUser ) {
            dmlStatementsIssuedBefore = Limits.getDmlStatements();
            dmlRowsIssuedBefore = Limits.getDmlRows();

            uow.commitWork();

            dmlStatementsIssuedAfter = Limits.getDmlStatements();
            dmlRowsIssuedAfter = Limits.getDmlRows();

            testAccountAfter = [ SELECT Id, Name, Site FROM Account WHERE Id = :testAccount.Id ];
            testContactAfter = [ SELECT Id, LastName, AccountId FROM Contact WHERE Id = :testContact.Id ];
        }
        Test.stopTest();

        // 1 is used by SavePoint, 1 by the account for the initial insert and 1 by the contact and then 1 more by the account when it's updated to set the lookup field.
        Integer expectedExtraDmlStatements = 1 + 3;
        Integer expectedExtraDmlRows = 3;

        Assert.areEqual( dmlStatementsIssuedBefore + expectedExtraDmlStatements, dmlStatementsIssuedAfter, 'commitWork, when called with a circular relationship registration, should issue the minimum required number of DML statements' );
        Assert.areEqual( dmlRowsIssuedBefore + expectedExtraDmlRows, dmlRowsIssuedAfter, 'commitWork, when called with a circular relationship registration, should issue the minimum required number of DML rows' );

        Assert.isTrue( testAccountAfter != null, 'commitWork, when called with a circular relationship registration, should commit the account - account record exists' );
        Assert.isTrue( testContactAfter != null, 'commitWork, when called with a circular relationship registration, should commit the contact - contact record exists' );

        Assert.areEqual( testAccount.Name, testAccountAfter.Name, 'commitWork, when called with a circular relationship registration, should commit the account - account name is correct' );
        Assert.areEqual( testContact.LastName, testContactAfter.LastName, 'commitWork, when called with a circular relationship registration, should commit the contact - contact last name is correct' );

        Assert.areEqual( testAccount.Id, testContactAfter.AccountId, 'commitWork, when called with a circular relationship registration, should set the account relationship on the contact' );
        Assert.areEqual( testContact.Id, testAccountAfter.get( contactLookupOnAccount ), 'commitWork, when called with a circular relationship registration, should set the contact relationship on the account' );
    }

    @IsTest
    private static void commitWork_whenCircularRelationshipsRegisteredWithDirtyRecord_mergesFieldsAndCommitsSuccessfully() {
        // We can't ship a custom field for the UnitOfWork tests so we simulate one using the Site field on Account.
        SobjectField contactLookupOnAccount = Account.Site;

        User testUser = createUserWithPermissionsForSobjectsAndFields( new Set<SobjectType> { Account.SObjectType, Contact.SObjectType }, new Set<SobjectField> { Contact.AccountId, contactLookupOnAccount } );

        Account existingAccount;
        System.runAs( testUser ) {
            existingAccount = new Account( Name = 'Original name' );
            insert existingAccount;
        }

        UnitOfWork uow = new UnitOfWork();

        // Register the existing account as dirty with a name change
        Account dirtyAccount = new Account( Id = existingAccount.Id, Name = 'Updated name' );
        uow.registerDirty( dirtyAccount );

        // Register a new contact that references the existing account (priority direction)
        Contact testContact = new Contact( LastName = 'Test contact' );
        uow.registerNew( testContact );

        uow.registerRelationship( testContact, Contact.AccountId, dirtyAccount );
        uow.registerRelationship( dirtyAccount, contactLookupOnAccount, testContact );
        uow.prioritiseRelationship( Contact.AccountId, contactLookupOnAccount );

        Account testAccountAfter;
        Contact testContactAfter;

        Test.startTest();
        System.runAs( testUser ) {
            uow.commitWork();

            testAccountAfter = [ SELECT Id, Name, Site FROM Account WHERE Id = :existingAccount.Id ];
            testContactAfter = [ SELECT Id, LastName, AccountId FROM Contact WHERE Id = :testContact.Id ];
        }
        Test.stopTest();

        Assert.isNotNull( testContactAfter, 'commitWork, when called with a circular relationship where the secondary record is dirty, should commit the contact' );
        Assert.isNotNull( testAccountAfter, 'commitWork, when called with a circular relationship where the secondary record is dirty, should commit the account' );

        // Both the dirty field (Name) and the secondary relationship field (Site) must be present on the single update
        Assert.areEqual( 'Updated name', testAccountAfter.Name, 'commitWork, when called with a circular relationship where the secondary record is dirty, should preserve the dirty field change on the account' );
        Assert.areEqual( existingAccount.Id, testContactAfter.AccountId, 'commitWork, when called with a circular relationship where the secondary record is dirty, should set the priority relationship on the contact' );
        Assert.areEqual( testContact.Id, testAccountAfter.get( contactLookupOnAccount ), 'commitWork, when called with a circular relationship where the secondary record is dirty, should set the secondary relationship on the account' );
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

    private static Id generateId( SobjectType sobjectType ) {
        idsGenerated++;
        return sobjectType.getDescribe( SObjectDescribeOptions.DEFERRED ).getKeyPrefix() + idsGenerated.toString().leftPad( 15, '0' );
    }
}
