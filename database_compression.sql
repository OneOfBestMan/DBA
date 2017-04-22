USE AdventureWorks2008
GO

ALTER PROCEDURE dbo.GetCompressionData 
AS 

DECLARE @tablename NVARCHAR(300)
DECLARE @tableschema NVARCHAR(300)
DECLARE @sql NVARCHAR(3000)
SET NOCOUNT ON;

DECLARE @rowCompressionData TABLE 
(
	[object_name] NVARCHAR(400)
	, [schema_name] NVARCHAR(400)
	, [index_id] INT 
	, [partition_number] INT 
	, [size_with_current_compression_setting(KB)] INT 
	, [size_with_requested_compression_setting(KB)] INT 
	, [sample_size_with_current_compression_setting(KB)] INT 
	, [sample_size_with_requested_compression_setting(KB)] INT 
)

DECLARE @pageCompressionData TABLE 
(
	[object_name] NVARCHAR(400)
	, [schema_name] NVARCHAR(400)
	, [index_id] INT 
	, [partition_number] INT 
	, [size_with_current_compression_setting(KB)] INT 
	, [size_with_requested_compression_setting(KB)] INT 
	, [sample_size_with_current_compression_setting(KB)] INT 
	, [sample_size_with_requested_compression_setting(KB)] INT 
)

DECLARE table_cursor CURSOR 
	LOCAL STATIC READ_ONLY FORWARD_ONLY
FOR 
SELECT TABLE_NAME, TABLE_SCHEMA
FROM information_schema.tables 
WHERE table_type = 'BASE TABLE'

OPEN table_cursor 
FETCH NEXT FROM table_cursor INTO @tablename, @tableschema
WHILE @@FETCH_STATUS = 0
begin
	PRINT 'sp_estimate_data_compression_savings ' + CHAR(39) + @tableschema + CHAR(39) + ',' + CHAR(39) +  @tablename +  CHAR(39) + ',null,null,''ROW'''

	SET @sql = 'sp_estimate_data_compression_savings ' + CHAR(39) + @tableschema + CHAR(39) + ',' + CHAR(39) +  @tablename +  CHAR(39) + ',null,null,''ROW'''
	INSERT INTO @rowCompressionData exec (@sql)

	PRINT 'sp_estimate_data_compression_savings ' + CHAR(39) + @tableschema + CHAR(39) + ',' + CHAR(39) +  @tablename +  CHAR(39) + ',null,null,''PAGE'''

	SET @sql = 'sp_estimate_data_compression_savings ' + CHAR(39) + @tableschema + CHAR(39) + ',' + CHAR(39) +  @tablename +  CHAR(39) + ',null,null,''PAGE'''
	INSERT INTO @pageCompressionData exec (@sql)

	FETCH NEXT FROM table_cursor INTO @tablename, @tableschema
END

SELECT CD.*, [IndexName] = i.name FROM (
	SELECT Type = 'ROW',* 
	FROM @rowCompressionData 
	UNION all
	SELECT Type = 'PAGE',* 
	FROM @pageCompressionData 
) CD
	left join sys.indexes i on CD.index_id = i.index_id and OBJECT_ID('[' + CD.[schema_name] + '].[' + CD.OBJECT_NAME + ']', 'U') = i.OBJECT_ID 
ORDER BY ([size_with_requested_compression_setting(KB)] - [size_with_current_compression_setting(KB)]) 

CLOSE table_cursor
DEALLOCATE table_cursor


