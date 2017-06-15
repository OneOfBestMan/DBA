USE AW2012
GO

--ALTER PROCEDURE dbo.GetCompressionData 
--AS 

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

SELECT 
	CD.[Type]								AS [Type]
	,CD.[Object]							AS [Object]
	,CD.[Schema]							AS [Schema]
	,CD.[Index ID]							AS [Index ID]
	,i.name									AS [IndexName]
	,CD.[Partition]							AS [Partition
	,count(distinct b.page_id)				AS [Buffer Count]
	,count(distinct b.page_id) / 128		AS [Buffer Count (MB)]
	,CD.[Size (MB)]							AS [Size (MB)]
	,CD.[Size with Compression (MB)]		AS [Size with Compression (MB)]
	,CD.[Size Savings (MB)]					AS [Size Savings (MB)]
	,CD.[Size Savings (Pct)]				AS [Size Savings (Pct)]		
	,CD.[Sample Size (MB)]					AS [Sample Size (MB)]
	,CD.[Sample Size with Compression (MB)] AS [Sample Size with Compression (MB)]
	,CD.[Sample Size Savings (MB)]			AS [Sample Size Savings (MB)]
FROM (
	SELECT 
		'ROW'																												AS [Type]
		,[object_name]																										AS [Object]
		,[schema_name]																										AS [Schema]
		,[index_id]																											AS [Index ID]
		,[partition_number]																									AS [Partition]
		,[size_with_current_compression_setting(KB)]/1024																	AS [Size (MB)]
		,[size_with_requested_compression_setting(KB)]/1024																	AS [Size with Compression (MB)]
		,([size_with_current_compression_setting(KB)]- [size_with_requested_compression_setting(KB)])/1024					AS [Size Savings (MB)]
		,case 
			when [size_with_current_compression_setting(KB)] = 0 THEN 0 
			ELSE cast(100. * (([size_with_current_compression_setting(KB)] - [size_with_requested_compression_setting(KB)])
			/([size_with_current_compression_setting(KB)] * 1.0)) as decimal(10,1)) END										AS [Size Savings (Pct)]		
		,[sample_size_with_current_compression_setting(KB)]/1024															AS [Sample Size (MB)]
		,[sample_size_with_requested_compression_setting(KB)] /1024															AS [Sample Size with Compression (MB)]
		,([sample_size_with_current_compression_setting(KB)] - [sample_size_with_requested_compression_setting(KB)])/1024	AS [Sample Size Savings (MB)]
	FROM @rowCompressionData 
	UNION all
	SELECT 
		'PAGE'																												AS [Type]
		,[object_name]																										AS [Object]
		,[schema_name]																										AS [Schema]
		,[index_id]																											AS [Index ID]
		,[partition_number]																									AS [Partition]
		,[size_with_current_compression_setting(KB)]/1024																	AS [Size (MB)]
		,[size_with_requested_compression_setting(KB)]/1024																	AS [Size with Compression (MB)]
		,([size_with_current_compression_setting(KB)]- [size_with_requested_compression_setting(KB)])/1024					AS [Size Savings (MB)]
		,case 
			when [size_with_current_compression_setting(KB)] = 0 THEN 0 
			ELSE cast(100. * (([size_with_current_compression_setting(KB)] - [size_with_requested_compression_setting(KB)])
			/([size_with_current_compression_setting(KB)] * 1.0)) as decimal(10,1)) END										AS [Size Savings (Pct)]		
		,[sample_size_with_current_compression_setting(KB)]/1024															AS [Sample Size (MB)]
		,[sample_size_with_requested_compression_setting(KB)] /1024															AS [Sample Size with Compression (MB)]
		,([sample_size_with_current_compression_setting(KB)] - [sample_size_with_requested_compression_setting(KB)])/1024	AS [Sample Size Savings (MB)]
	FROM @pageCompressionData 
) CD
	left join sys.indexes i with (nolock)
		on CD.[Index ID] = i.index_id and OBJECT_ID('[' + CD.[Schema] + '].[' + CD.[Object] + ']', 'U') = i.OBJECT_ID 
	left join sys.partitions p with (nolock)
		on p.index_id = i.index_id and p.object_id = i.object_id
	left join sys.allocation_units a with (nolock)
		on p.hobt_id = a.container_id
	left join sys.dm_os_buffer_descriptors b with (nolock)
		on a.allocation_unit_id = b.allocation_unit_id
group by 
	i.name	
	,CD.[Type]
	,CD.[Object]
	,CD.[Schema]
	,CD.[Index ID]
	,CD.[Partition]
	,CD.[Size (MB)]
	,CD.[Size with Compression (MB)]
	,CD.[Size Savings (MB)]
	,CD.[Size Savings (Pct)]		
	,CD.[Sample Size (MB)]
	,CD.[Sample Size with Compression (MB)]
	,CD.[Sample Size Savings (MB)]
ORDER BY [Size Savings (MB)] desc

CLOSE table_cursor
DEALLOCATE table_cursor



--select 
--	object_name(p.object_id)		AS [Object Name]
--	,p.index_id						AS [Index Id]
--	,Count(*)/128					AS [Buffer Size (MB)]
--	,Count(*)						AS [Buffer Count]
--from sys.allocation_units a with (nolock)
--	join sys.dm_os_buffer_descriptors b with (nolock)
--		on a.allocation_unit_id = b.allocation_unit_id
--	join sys.partitions p with (nolock)
--		on a.container_id = p.hobt_id
--where b.database_id = db_id()
--	and OBJECT_NAME(object_id) = 'Person'
--	and p.object_id > 100
--group by p.object_id
--	,p.index_id
--	,p.data_compression_desc
--order by [Buffer Count] desc;