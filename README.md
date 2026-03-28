A simple Unit of Work implementation in the Salesforce Apex programming language.

# Salesforce Unit of Work Implementation

## Key Features

* **Automatic DML Ordering**: Rather than requiring a pre-defined list of `SObjectType`s, the Unit of Work automatically determines the correct insert, update and delete order at commit time using a graph-based topological sort, derived from the relationships you register. Parent records are always inserted before their children; deletions happen in reverse order for dependencies that have been explicitly registered with `registerRelationship`.
* **Standard Record Registration**: Provides explicit methods for registering records to be processed during the commit phase: `registerNew` for insertions, `registerDirty` for updates, `registerDeleted` for soft deletions, and `registerPermanentlyDeleted` for hard deletions.
* **Intelligent Dirty Record Merging**: If a record is registered as dirty multiple times within the same transaction, field values are merged and the most recent registration for each field takes precedence.
* **Relationship Management**: The `registerRelationship` method links records that do not yet have IDs (e.g., a new `Contact` linked to a new `Account`). Foreign keys are resolved automatically at commit time once parent records have been inserted. This method is intentionally flexible and can also be used for simulated relationships, such as custom text fields that store another record's Id.
* **Intra-SObject Relationship Support**: When records of the same `SObjectType` reference each other (e.g., `Account.ParentId`), the Unit of Work splits DML into dependency-ordered waves so parent records are always inserted first.
* **Circular Relationship Support**: When two `SObjectType`s reference each other and only one relationship can be set at insert time, use `prioritiseRelationship( priorityField, secondaryField )` to declare which field can be deferred. The secondary relationship is applied as an update after both records have been inserted.
* **Security and Permission Bypasses**: Offers granular, per-`SObjectType` control over sharing rules (`bypassSharing`) and CRUD/FLS permissions (`bypassPermissions`).
* **Transactional Integrity**: Uses a Database Savepoint to ensure atomicity. Any DML failure during `commitWork` rolls back the entire transaction to its pre-commit state.
* **Single-Use Enforcement**: Each `UnitOfWork` instance can only be committed once. Calling `commitWork` a second time throws a `ValidationException` immediately.
* **Custom Exceptions**: A clear exception hierarchy: `ValidationException`, `CommitException`, and `RelationshipException` identifies exactly where a failure occurred and why.

## Important Behaviour Notes

* **Delete ordering is based on registered relationships**: The Unit of Work does not inspect org schema or infer dependency chains from describes during `commitWork`. If deletion order matters, register the relevant dependencies explicitly with `registerRelationship`.
* **Simulated relationships are supported**: `registerRelationship` does not require the field to be a native Salesforce lookup. This allows patterns such as text fields that store record Ids to participate in the dependency graph.
* **Dirty-then-delete is allowed**: A record may be registered as dirty and then deleted in the same Unit of Work. In that case the update is applied before the delete, which can be useful when business rules require a record to be moved into a deletable state first.
* **Hard delete builds on standard delete semantics**: `registerPermanentlyDeleted` first performs a normal delete, then calls `Database.emptyRecycleBin()` for the registered records. This means the initial delete still enforces the configured access level and sharing behavior before those records are hard deleted.
* **Intra-SObject dependency waves assume one same-type parent per registered field path**: Hierarchies such as parent/child/grandchild work correctly, but more complex cases where one record depends on multiple records of the same `SObjectType` through different fields are not currently supported.

## Usage Examples

### 1. Creating and Relating Records
The Unit of Work automatically determines that `Account` must be inserted before `Contact` based on the registered relationship. No ordering list is required.

```apex
UnitOfWork uow = new UnitOfWork();

Account newAccount = new Account( Name = 'Acme Corp' );
uow.registerNew( newAccount );

Contact newContact = new Contact( LastName = 'Doe' );
uow.registerNew( newContact );
uow.registerRelationship( newContact, Contact.AccountId, newAccount );

uow.commitWork(); // Account inserted first, then Contact with AccountId populated
```

### 2. Updating Records
Use `registerDirty` to update existing records. Multiple updates to the same record are merged into a single DML statement.

```apex
UnitOfWork uow = new UnitOfWork();

Account existingAcct = new Account( Id = '001xx0000000001AAA', Name = 'Updated Name' );
uow.registerDirty( existingAcct );

// Another part of your code updates the same record — changes are merged
Account sameAcctUpdate = new Account( Id = '001xx0000000001AAA', Industry = 'Technology' );
uow.registerDirty( sameAcctUpdate );

uow.commitWork(); // Single update DML with both Name and Industry set
```

### 3. Deleting Records
Records can be marked for deletion. The Unit of Work automatically processes deletions.

```apex
UnitOfWork uow = new UnitOfWork();

Contact contactToDelete = new Contact( Id = '003xx0000000001AAA' );
Account accountToDelete = new Account( Id = '001xx0000000001AAA' );

uow.registerDeleted( accountToDelete );
uow.registerDeleted( contactToDelete );

uow.commitWork();
```

### 4. Intra-SObject Hierarchies
When records of the same SObjectType reference each other, the Unit of Work splits inserts into waves automatically. No special configuration is needed.

```apex
UnitOfWork uow = new UnitOfWork();

Account parentAccount = new Account( Name = 'Parent' );
Account childAccount  = new Account( Name = 'Child' );

uow.registerNew( parentAccount );
uow.registerNew( childAccount );
uow.registerRelationship( childAccount, Account.ParentId, parentAccount );

uow.commitWork(); // Wave 1: parentAccount inserted. Wave 2: childAccount inserted with ParentId set.
```

### 5. Permanently Deleting Records
Use `registerPermanentlyDeleted` when records should be deleted and then removed from the recycle bin.

```apex
UnitOfWork uow = new UnitOfWork();

Account accountToHardDelete = new Account( Id = '001xx0000000001AAA' );

uow.registerPermanentlyDeleted( accountToHardDelete );

uow.commitWork(); // Deletes the record, then calls Database.emptyRecycleBin() for that record
```

### 6. Breaking Circular Relationships
When two records reference each other and both cannot be set at insert time, call `prioritiseRelationship` to declare which field should be deferred to a post-insert update.

```apex
UnitOfWork uow = new UnitOfWork();

Account newAccount = new Account( Name = 'Acme' );
Contact newContact = new Contact( LastName = 'Doe' );

uow.registerNew( newAccount );
uow.registerNew( newContact );

// Contact.AccountId is the priority relationship (set at insert time)
// Account.Primary_Contact__c is the secondary relationship (deferred to an update)
uow.prioritiseRelationship( Contact.AccountId, Account.Primary_Contact__c );

uow.registerRelationship( newContact, Contact.AccountId,           newAccount );
uow.registerRelationship( newAccount, Account.Primary_Contact__c,  newContact );

uow.commitWork();
// 1. Account inserted (no circular field yet)
// 2. Contact inserted with AccountId = newAccount.Id
// 3. Account updated with Primary_Contact__c = newContact.Id
```

### 7. Bypassing Permissions and Sharing
Selectively bypass sharing rules or CRUD/FLS for specific `SObjectType`s. Use sparingly.

```apex
UnitOfWork uow = new UnitOfWork();

uow.bypassSharing( Account.SObjectType );     // Ignore sharing rules for Accounts
uow.bypassPermissions( Account.SObjectType ); // Ignore CRUD/FLS for Accounts

Account exampleAccount = new Account( Name = 'Example' );
uow.registerNew( exampleAccount );

uow.commitWork();
```

## Test Coverage Scenarios

**Registration Safeguards**:
* `registerNew`: rejects null records and records that already have an Id.
* `registerDirty`: rejects null records and records without an Id.
* `registerDeleted`: rejects null records, records without an Id, and records that are already the parent of a registered relationship (prevents a dangling lookup after deletion).
* `registerPermanentlyDeleted`: rejects null records, records without an Id, and records that are already the parent of a registered relationship.
* `registerRelationship`: rejects null arguments, fields belonging to a different `SObjectType` than the record, a field already registered for the same record, and parent records already registered for deletion.
* `prioritiseRelationship`: rejects null arguments for either field.

**Merging Logic**:
* Multiple `registerDirty` calls on the same record Id correctly merge fields, with the most recent registration winning per field.

**Commit Behaviour**:
* A Unit of Work with no registrations issues zero DML statements.
* A `commitWork` call on an already-committed instance throws a `ValidationException` immediately (before any DML).
* Any DML failure rolls back the entire transaction via a Savepoint.
* Hard referential integrity failures (e.g. deleting an Account with an active Contract) roll back and throw a `CommitException`.
* `registerPermanentlyDeleted` deletes the record and then invokes `Database.emptyRecycleBin()` as part of the same commit flow.

**Graph-Based Ordering**:
* Records with inter-type relationships are inserted in the correct dependency order regardless of registration order.
* Intra-SObject relationships (e.g. `Account.ParentId`) split inserts into waves so parents precede children.
* A circular inter-type dependency without a `prioritiseRelationship` call throws a `CommitException` wrapping a `RelationshipException`.
* A circular intra-type dependency (e.g. Account A → Account B → Account A via `ParentId`) throws a `CommitException` wrapping a `RelationshipException`.
* Linear same-type hierarchies such as grandparent → parent → child are supported by the intra-type wave logic.

**Circular Relationships**:
* `prioritiseRelationship` correctly defers the secondary field to a post-insert update for two new records.
* The secondary relationship field is correctly merged with any dirty field changes when the source record was previously registered dirty (no double-update or field overwrite).

**Permission and Sharing Bypasses**:
* `bypassSharing` and `bypassPermissions` reject null inputs.
* `bypassPermissions` causes DML for that `SObjectType` to execute in `SYSTEM_MODE`, bypassing CRUD/FLS checks.
* Permission failures for non-bypassed types trigger a rollback and a `CommitException`.
* `bypassSharing` itself is not directly verified by the tests, because its behaviour depends on org sharing configuration and the package is intended to deploy cleanly even in environments where relevant objects are configured with public read/write access.
* Hard delete tests verify that `Database.emptyRecycleBin()` reports success for registered records, rather than asserting immediate disappearance from `ALL ROWS`, because final physical purge timing is platform-managed.
