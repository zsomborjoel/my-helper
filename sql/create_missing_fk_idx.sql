DECLARE @tableName NVARCHAR(128)
DECLARE @constraintName NVARCHAR(128)
DECLARE @indexName NVARCHAR(128)
DECLARE @sql NVARCHAR(MAX)

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

    -- Generate dynamic SQL to create the index
    SET @sql = 'CREATE INDEX ' + QUOTENAME(@indexName) + ' ON ' + QUOTENAME(@tableName) + ' (' +
               STUFF((
                       SELECT ', ' + QUOTENAME(col_name(ic.parent_object_id, ic.parent_column_id))
                       FROM sys.foreign_key_columns AS ic
                       WHERE fk.name = @constraintName
                       FOR XML PATH('')
                   ), 1, 2, '') + ')'

    -- Execute dynamic SQL
    EXEC sp_executesql @sql

    -- Fetch next foreign key
    FETCH NEXT FROM curForeignKeys INTO @tableName, @constraintName
END

CLOSE curForeignKeys
DEALLOCATE curForeignKeys
