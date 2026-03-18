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
public with sharing class UnitOfWork
{
    public abstract class UnitOfWorkException extends Exception {}
    public class ValidationException extends UnitOfWorkException {}
    public class CommitException extends UnitOfWorkException {}
    public class RelationshipException extends UnitOfWorkException {}

    @testVisible private List<SObjectType> sobjectTypeOperationOrder;
    @testVisible private List<SObjectType> sobjectTypeOperationOrderInReverse;

    @testVisible private Map<SObjectType, List<SObject>> newRecordsBySobjectType = new Map<SObjectType, List<SObject>>();
    @testVisible private Map<SObjectType, Map<Id, SObject>> dirtyRecordsBySobjectTypeAndRecordId = new Map<SObjectType, Map<Id, SObject>>();
    @testVisible private Map<SObjectType, Set<Id>> deletedRecordIdsBySobjectType = new Map<SObjectType, Set<Id>>();
    @testVisible private Relationships relationships = new Relationships();
    @testVisible private Set<SobjectType> sobjectTypesToBypassSharing = new Set<SobjectType>();
    @testVisible private Set<SobjectType> sobjectTypesToBypassPermissions = new Set<SobjectType>();

    public UnitOfWork() {
        // TODO
        throw new ValidationException( 'not yet implemented' );
    }

    public UnitOfWork( List<SObjectType> sobjectTypeOperationOrder ) {
        validate( sobjectTypeOperationOrder != null, 'UnitOfWork constructed with a null sobjectTypeOperationOrder' );
        validate( !sobjectTypeOperationOrder.isEmpty(), 'UnitOfWork constructed with an empty sobjectTypeOperationOrder' );

        this.sobjectTypeOperationOrder = sobjectTypeOperationOrder.clone();
        this.sobjectTypeOperationOrderInReverse = new List<SobjectType>();

        for ( Integer i = this.sobjectTypeOperationOrder.size() - 1; i >= 0; i-- ) {
            this.sobjectTypeOperationOrderInReverse.add( this.sobjectTypeOperationOrder[ i ] );
        }
    }

    // Registers a new record as new so that the unit of work will insert it on commit.
    public void registerNew( SObject record ) {
        validate( record != null, 'registerNew called with a null record' );
        validate( record.Id == null, 'registerNew called with a record that already has an Id' );
        validate( sobjectTypeAllowed( record ), 'registerNew called with a record whose SObjectType is not in the sobjectTypeOperationOrder' );

        newRecord( record );
    }

    // Registers an existing record as dirty so that the unit of work will update it on commit.
    // If the record has already been registered as dirty, this method will merge the records with field values on this copy taking precedence.
    public void registerDirty( SObject record ) {
        validate( record != null, 'registerDirty called with a null record' );
        validate( record.Id != null, 'registerDirty called with a record that does not have an Id' );
        validate( sobjectTypeAllowed( record ), 'registerDirty called with a record whose SObjectType is not in the sobjectTypeOperationOrder' );

        dirtyRecord( record );
    }

    // Registers a record as deleted so that the unit of work will delete it on commit.
    public void registerDeleted( SObject record ) {
        validate( record != null, 'registerDeleted called with a null record' );
        validate( record.Id != null, 'registerDeleted called with a record that does not have an Id' );
        validate( sobjectTypeAllowed( record ), 'registerDeleted called with a record whose SObjectType is not in the sobjectTypeOperationOrder' );

        deletedRecord( record );
    }

    // Registers a relationship between a record and a parent record so that the unit of work can set the relationship field during commit.
    public void registerRelationship( SObject record, SObjectField relationshipField, SObject parentRecord ) {
        validate( record != null, 'registerRelationship called with a null record' );
        validate( relationshipField != null, 'registerRelationship called with a null relationshipField' );
        validate( parentRecord != null, 'registerRelationship called with a null parentRecord' );

        SobjectType recordSobjectType = record.getSObjectType();
        SobjectType parentSobjectType = parentRecord.getSObjectType();
        DescribeFieldResult fieldDescribe = relationshipField.getDescribe();

        validate( fieldDescribe.getSobjectType() == recordSobjectType, 'registerRelationship called with a relationship field from a different SobjectType than the record SobjectType' );
        validate( fieldDescribe.getReferenceTo().contains( parentSobjectType ), 'registerRelationship called with a relationship field that does not point to the parent record SobjectType' );

        relationships.addRelationship( record, relationshipField, parentRecord );
    }

    public void prioritiseRelationship( SObjectField priorityField, SObjectField secondaryField ) {
        // TODO
        throw new ValidationException( 'not yet implemented' );
    }

    // Bypasses sharing rules for the given SObjectType during commitWork.
    public void bypassSharing( SObjectType type ) {
        validate( type != null, 'bypassSharing called with a null type' );
        validate( sobjectTypeAllowed( type ), 'bypassSharing called with a type that was not specified in the sobjectTypeOperationOrder when the UnitOfWork was constructed' );

        sobjectTypesToBypassSharing.add( type );
    }

    // Bypasses CRUD rules and FLS rules for the given SObjectType during commitWork.
    public void bypassPermissions( SObjectType type ) {
        validate( type != null, 'bypassPermissions called with a null type' );
        validate( sobjectTypeAllowed( type ), 'bypassPermissions called with a type that was not specified in the sobjectTypeOperationOrder when the UnitOfWork was constructed' );

        sobjectTypesToBypassPermissions.add( type );
    }

    // Commits all the changes to the database.
    public void commitWork() {
        Savepoint preCommitSavepoint = Database.setSavepoint();

        try {
            // Perform non-destructive DML operations by looping through sobjectTypeOperationOrder
            for ( SobjectType thisSobjectType : sobjectTypeOperationOrder ) {
                // Apply any relationships for the sobject type
                relationships.applyRelationshipsForSobjectType( thisSobjectType );

                // Insert the sobject type
                insertRecordsForSobjectType( thisSobjectType );

                // Update the sobject type
                updateRecordsForSobjectType( thisSobjectType );
            }
            // Perform destructive DML operations by looping through sobjectTypeOperationOrderInReverse
            for ( SobjectType thisSobjectType : sobjectTypeOperationOrderInReverse ) {
                // Delete the sobject type
                deleteRecordsForSobjectType( thisSobjectType );
            }
        }
        catch ( DmlException ex ) {
            Database.rollback( preCommitSavepoint );
            List<String> dmlExceptions = new List<String>();
            for (Integer dmlExceptionIndex = 0; dmlExceptionIndex < ex.getNumDml(); dmlExceptionIndex++) {
                dmlExceptions.add( ex.getDmlMessage( dmlExceptionIndex ) );
            }
            throw new CommitException( 'commitWork failed with DmlExceptions:\n' + String.join( dmlExceptions, '\n' ) );
        }
        catch ( Exception ex ) {
            Database.rollback( preCommitSavepoint );
            throw new CommitException( 'commitWork failed with exception: ' + ex.getMessage() );
        }
    }

    private void insertRecordsForSobjectType( SObjectType sobjectType ) {

        List<SObject> recordsToInsert = newRecordsBySobjectType.get( sobjectType );

        if ( recordsToInsert == null || recordsToInsert.isEmpty() ) {
            return;
        }

        AccessLevel accessLevel = sobjectTypesToBypassPermissions.contains( sobjectType ) ? AccessLevel.SYSTEM_MODE : AccessLevel.USER_MODE;
        Boolean bypassSharing = sobjectTypesToBypassSharing.contains( sobjectType );

        if ( bypassSharing ) {
            new WithoutSharing().insertRecords( recordsToInsert, accessLevel );
        }
        else {
            Database.insert( recordsToInsert, accessLevel );
        }
    }

    private void updateRecordsForSobjectType( SObjectType sobjectType ) {
        List<SObject> recordsToUpdate = dirtyRecordsBySobjectTypeAndRecordId.get( sobjectType )?.values();

        if ( recordsToUpdate == null || recordsToUpdate.isEmpty() ) {
            return;
        }

        AccessLevel accessLevel = sobjectTypesToBypassPermissions.contains( sobjectType ) ? AccessLevel.SYSTEM_MODE : AccessLevel.USER_MODE;
        Boolean bypassSharing = sobjectTypesToBypassSharing.contains( sobjectType );

        if ( bypassSharing ) {
            new WithoutSharing().updateRecords( recordsToUpdate, accessLevel );
        }
        else {
            Database.update( recordsToUpdate, accessLevel );
        }
    }

    private void deleteRecordsForSobjectType( SObjectType sobjectType ) {
        Set<Id> recordIdsToDelete = deletedRecordIdsBySobjectType.get( sobjectType );

        if ( recordIdsToDelete == null || recordIdsToDelete.isEmpty() ) {
            return;
        }

        AccessLevel accessLevel = sobjectTypesToBypassPermissions.contains( sobjectType ) ? AccessLevel.SYSTEM_MODE : AccessLevel.USER_MODE;
        Boolean bypassSharing = sobjectTypesToBypassSharing.contains( sobjectType );

        if ( bypassSharing ) {
            new WithoutSharing().deleteRecords( new List<Id>( recordIdsToDelete ), accessLevel );
        }
        else {
            Database.delete( new List<Id>( recordIdsToDelete ), accessLevel );
        }
    }

    private void newRecord( SObject record ) {
        SobjectType recordSobjectType = record.getSObjectType();

        if ( !newRecordsBySobjectType.containsKey( recordSobjectType ) ) {
            newRecordsBySobjectType.put( recordSobjectType, new List<SObject>() );
        }
        newRecordsBySobjectType.get( recordSobjectType ).add( record );
    }

    private void dirtyRecord( SObject record ) {
        SobjectType recordSobjectType = record.getSObjectType();

        if ( !dirtyRecordsBySobjectTypeAndRecordId.containsKey( recordSobjectType ) ) {
            dirtyRecordsBySobjectTypeAndRecordId.put( recordSobjectType, new Map<Id, SObject>() );
        }

        if ( dirtyRecordsBySobjectTypeAndRecordId.get( recordSobjectType ).containsKey( record.Id ) ) {
            mergeRecords( dirtyRecordsBySobjectTypeAndRecordId.get( recordSobjectType ).get( record.Id ), record );
        } else {
            dirtyRecordsBySobjectTypeAndRecordId.get( recordSobjectType ).put( record.Id, record );
        }
    }

    private void deletedRecord( SObject record ) {
        SobjectType recordSobjectType = record.getSObjectType();

        if ( !deletedRecordIdsBySobjectType.containsKey( recordSobjectType ) ) {
            deletedRecordIdsBySobjectType.put( recordSobjectType, new Set<Id>() );
        }

        deletedRecordIdsBySobjectType.get( recordSobjectType ).add( record.Id );
    }

    private class Relationships {
        @testVisible private Map<SobjectType, List<Relationship>> relationshipsBySobjectType = new Map<SobjectType, List<Relationship>>();

        public void addRelationship( SObject record, SObjectField relationshipField, SObject parentRecord ) {
            SobjectType recordSobjectType = record.getSObjectType();

            if ( !relationshipsBySobjectType.containsKey( recordSobjectType ) ) {
                relationshipsBySobjectType.put( recordSobjectType, new List<Relationship>() );
            }

            relationshipsBySobjectType.get( recordSobjectType ).add( new Relationship( record, relationshipField, parentRecord ) );
        }

        // Sets the lookup fields with the Id from the parent records. Note that this will fail if the sobjectTypeOperationOrder was configured incorrectly leading to the parents not being inserted yet.
        public void applyRelationshipsForSobjectType( SObjectType sobjectType ) {
            if ( relationshipsBySobjectType.containsKey( sobjectType ) ) {
                for ( Relationship thisRelationship : relationshipsBySobjectType.get( sobjectType ) ) {
                    if ( thisRelationship.getParentRecord().Id == null ) {
                        throw new RelationshipException( 'Unable to set relationship ' + thisRelationship.getRelationshipField() + ' on record ' + thisRelationship.getRecord() + ' because the parent record was not yet inserted. You may need to change your sobjectTypeOperationOrder.' );
                    }
                    thisRelationship.getRecord().put( thisRelationship.getRelationshipField(), thisRelationship.getParentRecord().Id );
                }
            }
        }
    }

    private without sharing class WithoutSharing {
        public void insertRecords( List<SObject> records, AccessLevel accessLevel ) {
            Database.insert( records, accessLevel );
        }

        public void updateRecords( List<SObject> records, AccessLevel accessLevel ) {
            Database.update( records, accessLevel );
        }

        public void deleteRecords( List<Id> recordIds, AccessLevel accessLevel ) {
            Database.delete( recordIds, accessLevel );
        }
    }

    private class Relationship {
        private SObject record;
        private SObjectField relationshipField;
        private SObject parentRecord;

        public Relationship( SObject record, SObjectField relationshipField, SObject parentRecord ) {
            this.record = record;
            this.relationshipField = relationshipField;
            this.parentRecord = parentRecord;
        }

        public SObject getRecord() {
            return record;
        }

        public SObjectField getRelationshipField() {
            return relationshipField;
        }

        public SObject getParentRecord() {
            return parentRecord;
        }
    }

    // Throws a ValidationException if the condition is false
    private void validate( Boolean condition, String message ) {
        if ( !condition ) {
            throw new ValidationException( message );
        }
    }

    // Takes field values from the newRecord and sets them on the existingRecord
    private void mergeRecords( SObject existingRecord, SObject newRecord ) {
        for ( String thisPopulatedField : newRecord.getPopulatedFieldsAsMap().keySet() ) {
            existingRecord.put( thisPopulatedField, newRecord.get( thisPopulatedField ) );
        }
    }

    private Boolean sobjectTypeAllowed( SObject record ) {
        return sobjectTypeOperationOrder.contains( record.getSObjectType() );
    }

    private Boolean sobjectTypeAllowed( SObjectType type ) {
        return sobjectTypeOperationOrder.contains( type );
    }
}