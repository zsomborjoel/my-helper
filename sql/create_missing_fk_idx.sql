DECLARE @TableName NVARCHAR(255)
DECLARE @ForeignKeyName NVARCHAR(255)
DECLARE @IndexName NVARCHAR(255)
DECLARE @SQL NVARCHAR(MAX)

-- Cursor to iterate through tables and their foreign keys
DECLARE ForeignKeyCursor CURSOR FOR
SELECT 
    OBJECT_NAME(f.parent_object_id) AS TableName,
    f.name AS ForeignKeyName,
    i.name AS IndexName
FROM 
    sys.foreign_keys AS f
INNER JOIN 
    sys.indexes AS i ON f.parent_object_id = i.object_id
WHERE 
    i.is_primary_key = 0 -- Exclude primary keys as they're usually already indexed
    AND i.is_unique_constraint = 0 -- Exclude unique constraints as they're already indexed
ORDER BY 
    TableName, ForeignKeyName;

-- Open cursor
OPEN ForeignKeyCursor;

-- Fetch the first row
FETCH NEXT FROM ForeignKeyCursor INTO @TableName, @ForeignKeyName, @IndexName;

-- Loop through the cursor
WHILE @@FETCH_STATUS = 0
BEGIN
    -- Generate index name
    SET @IndexName = 'IX_' + @TableName + '_' + @ForeignKeyName;

    -- Generate dynamic SQL for creating index
    SET @SQL = 'CREATE INDEX ' + QUOTENAME(@IndexName) + ' ON ' + QUOTENAME(@TableName) + '(' + 
               (SELECT STRING_AGG(QUOTENAME(c.name), ', ') 
                FROM sys.columns AS c 
                INNER JOIN sys.foreign_key_columns AS fk 
                ON c.object_id = fk.referenced_object_id AND c.column_id = fk.referenced_column_id 
                WHERE fk.parent_object_id = OBJECT_ID(@TableName) AND fk.constraint_object_id = OBJECT_ID(@ForeignKeyName)) +
               ')';

    -- Execute dynamic SQL
    EXEC sp_executesql @SQL;

    -- Fetch the next row
    FETCH NEXT FROM ForeignKeyCursor INTO @TableName, @ForeignKeyName, @IndexName;
END

-- Close cursor
CLOSE ForeignKeyCursor;
DEALLOCATE ForeignKeyCursor;
