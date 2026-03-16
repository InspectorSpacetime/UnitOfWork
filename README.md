A simple Unit of Work implementation in the Salesforce Apex programming language.

# Salesforce Unit of Work Implementation

## Key Features

* **Ordered DML Execution**: The class enforces a specific sequence for DML operations based on a provided `SObjectType` list, ensuring that parent records are processed before children during insertions and updates. Deletions are automatically handled in the reverse order to maintain referential integrity.
* **Standard Record Registration**: Provides explicit methods for registering records to be processed during the commit phase, including `registerNew` for insertions, `registerDirty` for updates, and `registerDeleted` for removals.
* **Intelligent Dirty Record Merging**: If a record is registered as "dirty" multiple times within the same transaction, the implementation merges the field values, with the most recent registration taking precedence.
* **Relationship Management**: Includes a `registerRelationship` method that allows developers to link records that do not yet have IDs (e.g., a new Contact linked to a new Account). The Unit of Work resolves these foreign keys automatically during the commit process.
* **Security and Permission Bypasses**: Offers granular control over Salesforce security by allowing specific `SObjectType` bypasses for sharing rules (`bypassSharing`) or CRUD and Field Level Security (`bypassPermissions`).
* **Transactional Integrity**: Utilises Database Savepoints to ensure atomicity. If any DML operation fails during `commitWork`, the entire transaction is rolled back to its pre-commit state.
* **Custom Exception Handling**: Features a hierarchy of custom exceptions, including `ValidationException`, `CommitException`, and `RelationshipException`, to provide clear feedback on failure points.

## Usage Examples

Here are some common usage scenarios for the `UnitOfWork` class.

### 1. Creating and Relating Records
This example demonstrates how to create a new `Account` and a related `Contact` in a single transaction. The Unit of Work ensures the `Account` is inserted first and automatically populates the `AccountId` on the `Contact` before it is inserted.

```apex
UnitOfWork uow = new UnitOfWork( new List<SObjectType>{ Account.SObjectType, Contact.SObjectType } );

Account newAccount = new Account( Name = 'Acme Corp' );
uow.registerNew( newAccount );

Contact newContact = new Contact( LastName = 'Doe' );
uow.registerNew( newContact );
uow.registerRelationship( newContact, Contact.AccountId, newAccount );

uow.commitWork();
```

### 2. Updating Records
Use `registerDirty` to update existing records. The class intelligently merges multiple updates to the same record.

```apex
UnitOfWork uow = new UnitOfWork( new List<SObjectType>{ Account.SObjectType } );

// Imagine an Account with an existing Id
Account existingAcct = new Account(Id = '001xx0000000001AAA', Name = 'Updated Name');
uow.registerDirty(existingAcct);

// If another part of your code registers an update to the same record, changes are merged
Account sameAcctUpdate = new Account(Id = '001xx0000000001AAA', Industry = 'Technology');
uow.registerDirty(sameAcctUpdate);

uow.commitWork(); // Only 1 DML update will occur with both Name and Industry updated
```

### 3. Deleting Records
Records can be marked for deletion. The Unit of Work automatically processes deletions in the reverse order of the list provided in the constructor to respect referential integrity.

```apex
UnitOfWork uow = new UnitOfWork( new List<SObjectType>{ Account.SObjectType, Contact.SObjectType } );

Contact contactToDelete = new Contact(Id = '003xx0000000001AAA');
Account accountToDelete = new Account(Id = '001xx0000000001AAA');

uow.registerDeleted( accountToDelete );
uow.registerDeleted( contactToDelete );

// Deletions happen in reverse order: Contacts are deleted before Accounts
uow.commitWork();
```

### 4. Bypassing Permissions and Sharing
You can selectively bypass user permissions (CRUD/FLS) and sharing rules (record visibility) for specific `SObjectType`s during the commit phase. Avoid bypassing permissions or sharing unless absolutely necessary.

```apex
UnitOfWork uow = new UnitOfWork( new List<SObjectType>{ Account.SObjectType } );

// Execute DML for Accounts regardless of the user's sharing rules
uow.bypassSharing( Account.SObjectType );

// Execute DML for Accounts regardless of the user's object/field permissions (system mode)
uow.bypassPermissions( Account.SObjectType );

Account exampleAccount = new Account( Name = 'Example account' );
uow.registerNew( exampleAccount );

uow.commitWork();
```

## Test Coverage and Scenarios

The test class ensures the robustness of the implementation by verifying both "happy path" and "edge case" scenarios:

**Constructor Validation**:
* Throws a `ValidationException` if the class is instantiated with a null or empty list of `SObjectTypes`.
* Confirms the internal operation order is correctly cloned and reversed upon instantiation.


**Registration Safeguards**:
* **registerNew**: Prevents registering null records, records that already possess an ID, or records of an `SObjectType` not defined in the initial operation order.
* **registerDirty/Deleted**: Validates that records must have an ID and must be of a supported `SObjectType`.


**Merging Logic Verification**:
* Specifically tests that multiple `registerDirty` calls on the same record ID correctly merge fields and handle null values as intended.


**Relationship Integrity**:
* Validates that relationship fields belong to the correct `SObjectType`.
* Ensures the relationship field actually points to the `SObjectType` of the parent record.
* Confirms successful registration of valid parent-child links.


* **Permission and Sharing Bypasses**:
* Verifies that bypasses can only be registered for `SObjectTypes` included in the Unit of Work's scope.
* Ensures null inputs for bypass methods are caught and handled via exceptions.
