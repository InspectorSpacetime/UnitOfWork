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

    @testVisible private Map<SObjectType, List<SObject>> newRecordsBySobjectType = new Map<SObjectType, List<SObject>>();
    @testVisible private Map<SObjectType, Map<Id, SObject>> dirtyRecordsBySobjectTypeAndRecordId = new Map<SObjectType, Map<Id, SObject>>();
    @testVisible private Map<SObjectType, Set<Id>> deletedRecordIdsBySobjectType = new Map<SObjectType, Set<Id>>();
    @testVisible private Relationships relationships = new Relationships();
    @testVisible private Set<SobjectType> sobjectTypesToBypassSharing = new Set<SobjectType>();
    @testVisible private Set<SobjectType> sobjectTypesToBypassPermissions = new Set<SobjectType>();
    @testVisible private Set<SObjectField> secondaryFields = new Set<SObjectField>();

    public UnitOfWork() {}

    // Registers a new record so that the unit of work will insert it on commit.
    public void registerNew( SObject record ) {
        validate( record != null, 'registerNew called with a null record' );
        validate( record.Id == null, 'registerNew called with a record that already has an Id' );

        newRecord( record );
    }

    // Registers an existing record as dirty so that the unit of work will update it on commit.
    // If the record has already been registered as dirty, the records are merged with field values on this copy taking precedence.
    public void registerDirty( SObject record ) {
        validate( record != null, 'registerDirty called with a null record' );
        validate( record.Id != null, 'registerDirty called with a record that does not have an Id' );

        dirtyRecord( record );
    }

    // Registers a record as deleted so that the unit of work will delete it on commit.
    public void registerDeleted( SObject record ) {
        validate( record != null, 'registerDeleted called with a null record' );
        validate( record.Id != null, 'registerDeleted called with a record that does not have an Id' );

        deletedRecord( record );
    }

    // Registers a relationship between a record and a parent record so that the unit of work can set the relationship field during commit.
    public void registerRelationship( SObject record, SObjectField relationshipField, SObject parentRecord ) {
        validate( record != null, 'registerRelationship called with a null record' );
        validate( relationshipField != null, 'registerRelationship called with a null relationshipField' );
        validate( parentRecord != null, 'registerRelationship called with a null parentRecord' );

        SobjectType recordSobjectType = record.getSObjectType();
        DescribeFieldResult fieldDescribe = relationshipField.getDescribe();

        validate( fieldDescribe.getSobjectType() == recordSobjectType, 'registerRelationship called with a relationship field from a different SobjectType than the record SobjectType' );

        relationships.addRelationship( record, relationshipField, parentRecord );
    }

    // Declares that priorityField should be set at insert time, and secondaryField should be deferred to a post-insert update.
    // Used to break circular relationships between two SObject types where both cannot be set at insert time.
    public void prioritiseRelationship( SObjectField priorityField, SObjectField secondaryField ) {
        validate( priorityField != null, 'prioritiseRelationship called with a null priorityField' );
        validate( secondaryField != null, 'prioritiseRelationship called with a null secondaryField' );

        secondaryFields.add( secondaryField );
    }

    // Bypasses sharing rules for the given SObjectType during commitWork.
    public void bypassSharing( SObjectType type ) {
        validate( type != null, 'bypassSharing called with a null type' );

        sobjectTypesToBypassSharing.add( type );
    }

    // Bypasses CRUD and FLS rules for the given SObjectType during commitWork.
    public void bypassPermissions( SObjectType type ) {
        validate( type != null, 'bypassPermissions called with a null type' );

        sobjectTypesToBypassPermissions.add( type );
    }

    // Commits all the changes to the database.
    public void commitWork() {
        Savepoint preCommitSavepoint = Database.setSavepoint();

        try {
            List<SObjectType> orderedSobjectTypes = getSobjectTypeOrder();

            List<SObjectType> reversedOrderSobjectTypes = new List<SObjectType>();
            for ( Integer i = orderedSobjectTypes.size() - 1; i >= 0; i-- ) {
                reversedOrderSobjectTypes.add( orderedSobjectTypes[i] );
            }

            // Insert new records in dependency order, splitting intra-type relationships into waves
            for ( SObjectType thisSobjectType : orderedSobjectTypes ) {
                insertRecordsForSobjectTypeInWaves( thisSobjectType );
            }

            // Apply deferred secondary relationships by merging into dirty records
            applySecondaryRelationships();

            // Apply priority relationships for dirty records and update all dirty records
            for ( SObjectType thisSobjectType : orderedSobjectTypes ) {
                applyPriorityRelationshipsForDirtyRecordsOfSobjectType( thisSobjectType );
                updateRecordsForSobjectType( thisSobjectType );
            }

            // Delete records in reverse dependency order
            for ( SObjectType thisSobjectType : reversedOrderSobjectTypes ) {
                deleteRecordsForSobjectType( thisSobjectType );
            }
        }
        catch ( DmlException ex ) {
            Database.rollback( preCommitSavepoint );
            List<String> dmlExceptions = new List<String>();
            for ( Integer i = 0; i < ex.getNumDml(); i++ ) {
                dmlExceptions.add( ex.getDmlMessage( i ) );
            }
            throw new CommitException( 'commitWork failed with DmlExceptions:\n' + String.join( dmlExceptions, '\n' ) );
        }
        catch ( Exception ex ) {
            Database.rollback( preCommitSavepoint );
            throw new CommitException( 'commitWork failed with exception: ' + ex.getMessage() );
        }
    }

    // Builds a topologically sorted list of all SObject types involved in this unit of work,
    // using only the priority (non-secondary) relationships as inter-type dependency edges.
    private List<SObjectType> getSobjectTypeOrder() {

        Set<SObjectType> combinedSobjectTypes = new Set<SObjectType>();
        combinedSobjectTypes.addAll( newRecordsBySobjectType.keySet() );
        combinedSobjectTypes.addAll( dirtyRecordsBySobjectTypeAndRecordId.keySet() );
        combinedSobjectTypes.addAll( deletedRecordIdsBySobjectType.keySet() );
        combinedSobjectTypes.addAll( relationships.relationshipsBySobjectType.keySet() );

        // Collect every type referenced across all three operation maps
        Map<SObjectType, Set<SObjectType>> dependentSobjectTypesBySobjectType = new Map<SObjectType, Set<SObjectType>>();

        for ( SObjectType thisSobjectType : combinedSobjectTypes ) {
            dependentSobjectTypesBySobjectType.put( thisSobjectType, new Set<SObjectType>() );
        }

        // Add inter-type edges from priority relationships: child depends on parent
        for ( SObjectType thisChildType : relationships.relationshipsBySobjectType.keySet() ) {
            for ( Relationship thisRelationship : relationships.relationshipsBySobjectType.get( thisChildType ) ) {
                if ( secondaryFields.contains( thisRelationship.getRelationshipField() ) ) {
                    continue; // deferred — does not constrain insert order
                }
                SObjectType parentType = thisRelationship.getParentRecord().getSObjectType();
                if ( parentType == thisChildType ) {
                    continue; // intra-type — handled at the record level, not the type level
                }
                dependentSobjectTypesBySobjectType.get( thisChildType ).add( parentType );
            }
        }

        return topologicalSortTypes( dependentSobjectTypesBySobjectType );
    }

    // Kahn's algorithm: returns types in an order where every type appears after its dependencies.
    // Throws RelationshipException if a cycle exists where prioritiseRelationship was not called to break it.
    private List<SObjectType> topologicalSortTypes( Map<SObjectType, Set<SObjectType>> dependentSobjectTypesBySobjectType ) {
        Map<SObjectType, Integer> inDegreeBySobjectType = new Map<SObjectType, Integer>();
        Map<SObjectType, Set<SObjectType>> reverseDepsBySobjectType = new Map<SObjectType, Set<SObjectType>>();

        for ( SObjectType thisSobjectType : dependentSobjectTypesBySobjectType.keySet() ) {
            inDegreeBySobjectType.put( thisSobjectType, inDegreeBySobjectType.get( thisSobjectType ) ?? 0 );
            reverseDepsBySobjectType.put( thisSobjectType, reverseDepsBySobjectType.get( thisSobjectType ) ?? new Set<SObjectType>() );

            for ( SObjectType parentSobjectType : dependentSobjectTypesBySobjectType.get( thisSobjectType ) ) {
                reverseDepsBySobjectType.put( parentSobjectType, reverseDepsBySobjectType.get( parentSobjectType ) ?? new Set<SObjectType>() );
                reverseDepsBySobjectType.get( parentSobjectType ).add( thisSobjectType );
                inDegreeBySobjectType.put( thisSobjectType, inDegreeBySobjectType.get( thisSobjectType ) + 1 );
            }
        }

        List<SObjectType> sobjectTypeQueue = new List<SObjectType>();
        for ( SObjectType thisSobjectType : inDegreeBySobjectType.keySet() ) {
            if ( inDegreeBySobjectType.get( thisSobjectType ) == 0 ) {
                sobjectTypeQueue.add( thisSobjectType );
            }
        }

        List<SObjectType> sortedSobjectTypes = new List<SObjectType>();
        while ( !sobjectTypeQueue.isEmpty() ) {
            SObjectType currentSobjectType = sobjectTypeQueue.remove( 0 );
            sortedSobjectTypes.add( currentSobjectType );
            for ( SObjectType dependentSobjectType : reverseDepsBySobjectType.get( currentSobjectType ) ) {
                Integer newDegree = inDegreeBySobjectType.get( dependentSobjectType ) - 1;
                inDegreeBySobjectType.put( dependentSobjectType, newDegree );
                if ( newDegree == 0 ) {
                    sobjectTypeQueue.add( dependentSobjectType );
                }
            }
        }

        if ( sortedSobjectTypes.size() != dependentSobjectTypesBySobjectType.size() ) {
            // TODO: test circular relationship error
            throw new RelationshipException( 'Circular relationship detected between SObject types. Use prioritiseRelationship to resolve the cycle.' );
        }

        return sortedSobjectTypes;
    }

    // Inserts new records for one SObject type. If there are intra-type priority relationships,
    // records are split into dependency-ordered waves so parents are inserted before children.
    private void insertRecordsForSobjectTypeInWaves( SObjectType sobjectType ) {
        List<SObject> recordsToInsert = newRecordsBySobjectType.get( sobjectType );

        if ( recordsToInsert == null || recordsToInsert.isEmpty() ) {
            return;
        }

        // Collect intra-type priority dependencies: record -> its same-type parent record
        Map<SObject, SObject> intraTypeParent = new Map<SObject, SObject>();
        if ( relationships.relationshipsBySobjectType.containsKey( sobjectType ) ) {
            for ( Relationship rel : relationships.relationshipsBySobjectType.get( sobjectType ) ) {
                if ( secondaryFields.contains( rel.getRelationshipField() ) ) continue;
                if ( rel.getParentRecord().getSObjectType() == sobjectType ) {
                    intraTypeParent.put( rel.getRecord(), rel.getParentRecord() );
                }
            }
        }

        if ( intraTypeParent.isEmpty() ) {
            // No intra-type dependencies: apply all priority relationships and insert in one batch
            relationships.applyPriorityRelationshipsForRecords( sobjectType, secondaryFields, new Set<SObject>( recordsToInsert ) );
            insertRecords( recordsToInsert, sobjectType );
        } else {
            // Split into waves so that parent records are inserted before their children
            List<List<SObject>> waves = topologicalSortRecords( recordsToInsert, intraTypeParent );
            for ( List<SObject> wave : waves ) {
                relationships.applyPriorityRelationshipsForRecords( sobjectType, secondaryFields, new Set<SObject>( wave ) );
                insertRecords( wave, sobjectType );
            }
        }
    }

    // Topologically sorts records within a single SObject type into insertion waves.
    // intraTypeParent maps each child record to the same-type parent record it depends on.
    // Returns a list of waves; all records in a wave can be inserted in a single DML statement.
    private List<List<SObject>> topologicalSortRecords( List<SObject> records, Map<SObject, SObject> intraTypeParent ) {
        Map<SObject, Integer> inDegreeByRecord = new Map<SObject, Integer>();
        Map<SObject, List<SObject>> childrenByRecord = new Map<SObject, List<SObject>>();

        for ( SObject thisRecord : records ) {
            inDegreeByRecord.put( thisRecord, inDegreeByRecord.get( thisRecord ) ?? 0 );
            childrenByRecord.put( thisRecord, childrenByRecord.get( thisRecord ) ?? new List<SObject>() );
        }

        for ( SObject record : records ) {
            if ( intraTypeParent.containsKey( record ) ) {
                SObject parent = intraTypeParent.get( record );
                inDegreeByRecord.put( record, inDegreeByRecord.get( record ) + 1 );
                if ( !childrenByRecord.containsKey( parent ) ) {
                    childrenByRecord.put( parent, new List<SObject>() );
                }
                childrenByRecord.get( parent ).add( record );
            }
        }

        List<SObject> currentWave = new List<SObject>();
        for ( SObject thisRecord : records ) {
            if ( inDegreeByRecord.get( thisRecord ) == 0 ) {
                currentWave.add( thisRecord );
            }
        }

        List<List<SObject>> waves = new List<List<SObject>>();
        while ( !currentWave.isEmpty() ) {
            waves.add( currentWave );
            List<SObject> nextWave = new List<SObject>();
            for ( SObject thisRecord : currentWave ) {
                for ( SObject thisChildRecord : childrenByRecord.get( thisRecord ) ) {
                    Integer newInDegree = inDegreeByRecord.get( thisChildRecord ) - 1;
                    inDegreeByRecord.put( thisChildRecord, newInDegree );
                    if ( newInDegree == 0 ) {
                        nextWave.add( thisChildRecord );
                    }
                }
            }
            currentWave = nextWave;
        }
        return waves;
    }

    // After all inserts are complete, sets each secondary (deferred) relationship field and merges the change
    // into the dirty record map so the unified update pass issues a single DML per type.
    // This prevents a double-update race where a separate updateRecordList call would overwrite fields
    // already registered dirty on the same record.
    private void applySecondaryRelationships() {
        if ( ! secondaryFields.isEmpty() ) {
            for ( SObjectType thisChildType : relationships.relationshipsBySobjectType.keySet() ) {
                for ( Relationship thisRelationship : relationships.relationshipsBySobjectType.get( thisChildType ) ) {
                    if ( secondaryFields.contains( thisRelationship.getRelationshipField() ) ) {
                        SObject parentRecord = thisRelationship.getParentRecord();
                        if ( parentRecord.Id == null ) {
                            throw new RelationshipException( 'Unable to set secondary relationship ' + thisRelationship.getRelationshipField() + ' on record ' + thisRelationship.getRecord() + ' because the parent record has no Id after insert.' );
                        }
                        thisRelationship.getRecord().put( thisRelationship.getRelationshipField(), parentRecord.Id );

                        // Merge the modified record into the dirty map so the update pass picks it up.
                        // If the record was already registered dirty this merges the new field in rather than
                        // creating a conflicting second update.
                        dirtyRecord( thisRelationship.getRecord() );
                    }
                }
            }
        }
    }

    // Applies priority (non-secondary) relationships for records that were registered dirty rather than new.
    // New records have their relationships applied during insert waves; dirty records need this separate pass
    // before their update DML so that lookup fields are set correctly.
    private void applyPriorityRelationshipsForDirtyRecordsOfSobjectType( SObjectType sobjectType ) {
        if ( relationships.relationshipsBySobjectType.containsKey( sobjectType ) ) {
            Set<SObject> newRecordsForType = newRecordsBySobjectType.containsKey( sobjectType )
                ? new Set<SObject>( newRecordsBySobjectType.get( sobjectType ) )
                : new Set<SObject>();

            for ( Relationship thisRelationship : relationships.relationshipsBySobjectType.get( sobjectType ) ) {
                if ( secondaryFields.contains( thisRelationship.getRelationshipField() ) ) {
                    continue; // handled by applySecondaryRelationships
                }
                if ( newRecordsForType.contains( thisRelationship.getRecord() ) ) {
                    continue; // already applied during insert wave
                }

                SObject parentRecord = thisRelationship.getParentRecord();
                if ( parentRecord.Id == null ) {
                    throw new RelationshipException( 'Unable to set relationship ' + thisRelationship.getRelationshipField() + ' on record ' + thisRelationship.getRecord() + ' because the parent record has no Id.' );
                }
                thisRelationship.getRecord().put( thisRelationship.getRelationshipField(), parentRecord.Id );

                // Merge the modified record into the dirty map so the update pass issues the DML.
                dirtyRecord( thisRelationship.getRecord() );
            }
        }
    }

    private void insertRecords( List<SObject> records, SObjectType sobjectType ) {
        AccessLevel accessLevel = sobjectTypesToBypassPermissions.contains( sobjectType ) ? AccessLevel.SYSTEM_MODE : AccessLevel.USER_MODE;
        Boolean bypassSharing = sobjectTypesToBypassSharing.contains( sobjectType );

        if ( bypassSharing ) {
            new WithoutSharing().insertRecords( records, accessLevel );
        } else {
            Database.insert( records, accessLevel );
        }
    }

    private void updateRecordsForSobjectType( SObjectType sobjectType ) {
        List<SObject> recordsToUpdate = dirtyRecordsBySobjectTypeAndRecordId.get( sobjectType )?.values();

        if ( recordsToUpdate != null && !recordsToUpdate.isEmpty() ) {
            updateRecordList( recordsToUpdate, sobjectType );
        }
    }

    private void updateRecordList( List<SObject> records, SObjectType sobjectType ) {
        AccessLevel accessLevel = sobjectTypesToBypassPermissions.contains( sobjectType ) ? AccessLevel.SYSTEM_MODE : AccessLevel.USER_MODE;
        Boolean bypassSharing = sobjectTypesToBypassSharing.contains( sobjectType );

        if ( bypassSharing ) {
            new WithoutSharing().updateRecords( records, accessLevel );
        } else {
            Database.update( records, accessLevel );
        }
    }

    private void deleteRecordsForSobjectType( SObjectType sobjectType ) {
        Set<Id> recordIdsToDelete = deletedRecordIdsBySobjectType.get( sobjectType );

        if ( recordIdsToDelete != null && !recordIdsToDelete.isEmpty() ) {
            AccessLevel accessLevel = sobjectTypesToBypassPermissions.contains( sobjectType ) ? AccessLevel.SYSTEM_MODE : AccessLevel.USER_MODE;
            Boolean bypassSharing = sobjectTypesToBypassSharing.contains( sobjectType );

            if ( bypassSharing ) {
                new WithoutSharing().deleteRecords( new List<Id>( recordIdsToDelete ), accessLevel );
            } else {
                Database.delete( new List<Id>( recordIdsToDelete ), accessLevel );
            }
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

        // Sets the lookup fields for the given set of records using only priority (non-secondary) relationships.
        // Throws RelationshipException if a priority relationship's parent has not yet been inserted.
        public void applyPriorityRelationshipsForRecords( SObjectType sobjectType, Set<SObjectField> secondaryFields, Set<SObject> recordsInWave ) {
            if ( !relationshipsBySobjectType.containsKey( sobjectType ) ) return;

            for ( Relationship rel : relationshipsBySobjectType.get( sobjectType ) ) {
                if ( secondaryFields.contains( rel.getRelationshipField() ) ) continue;
                if ( !recordsInWave.contains( rel.getRecord() ) ) continue;

                if ( rel.getParentRecord().Id == null ) {
                    throw new RelationshipException( 'Unable to set relationship ' + rel.getRelationshipField() + ' on record ' + rel.getRecord() + ' because the parent record was not yet inserted.' );
                }
                rel.getRecord().put( rel.getRelationshipField(), rel.getParentRecord().Id );
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

        public SObject getRecord() { return record; }
        public SObjectField getRelationshipField() { return relationshipField; }
        public SObject getParentRecord() { return parentRecord; }
    }

    // Throws a ValidationException if the condition is false
    private void validate( Boolean condition, String message ) {
        if ( !condition ) {
            throw new ValidationException( message );
        }
    }

    // Takes field values from the newRecord and sets them on the existingRecord
    private void mergeRecords( SObject existingRecord, SObject newRecord ) {
        for ( String field : newRecord.getPopulatedFieldsAsMap().keySet() ) {
            existingRecord.put( field, newRecord.get( field ) );
        }
    }
}