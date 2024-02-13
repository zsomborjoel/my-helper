DECLARE @tableName NVARCHAR(128)
DECLARE @constraintName NVARCHAR(128)
DECLARE @indexName NVARCHAR(128)
DECLARE @sql NVARCHAR(MAX)

-- Table to store index names created by the previous script
DECLARE @indexesToDelete TABLE (IndexName NVARCHAR(128))

-- Cursor to loop through all foreign keys without an index
DECLARE curForeignKeys CURSOR FOR
SELECT
    OBJECT_NAME(fkc.parent_object_id) AS TableName,
    fkc.name AS ConstraintName
FROM
    sys.foreign_keys AS fkc
    LEFT JOIN sys.index_columns AS ic ON fkc.parent_object_id = ic.object_id
                                        AND ic.index_id = fkc.unique_index_id
WHERE
    ic.object_id IS NULL

OPEN curForeignKeys

FETCH NEXT FROM curForeignKeys INTO @tableName, @constraintName

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Generate index name
    SET @indexName = 'IX_' + @tableName + '_' + @constraintName

    -- Generate dynamic SQL to drop the index if it exists
    SET @sql = 'IF EXISTS (SELECT * FROM sys.indexes WHERE name = ' + QUOTENAME(@indexName, '''') + ')
                BEGIN
                    DROP INDEX ' + QUOTENAME(@indexName) + ' ON ' + QUOTENAME(@tableName) + '
                END'

    -- Insert index name into the table for later deletion
    INSERT INTO @indexesToDelete (IndexName) VALUES (@indexName)

    -- Execute dynamic SQL to drop the index
    EXEC sp_executesql @sql

    -- Fetch next foreign key
    FETCH NEXT FROM curForeignKeys INTO @tableName, @constraintName
END

CLOSE curForeignKeys
DEALLOCATE curForeignKeys

-- Deleting the indexes created by the previous script
DECLARE curDeleteIndexes CURSOR FOR
SELECT IndexName FROM @indexesToDelete

OPEN curDeleteIndexes

FETCH NEXT FROM curDeleteIndexes INTO @indexName

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Generate dynamic SQL to drop the index
    SET @sql = 'DROP INDEX ' + QUOTENAME(@indexName)

    -- Execute dynamic SQL to drop the index
    EXEC sp_executesql @sql

    -- Fetch next index name
    FETCH NEXT FROM curDeleteIndexes INTO @indexName
END

CLOSE curDeleteIndexes
DEALLOCATE curDeleteIndexes
