-- Demo Script for Using sys.dm_db_index_physical_stats demo

USE [Company];
GO

-- Drop the session if it exists. 
IF EXISTS (
	SELECT * FROM sys.server_event_sessions
		WHERE [name] = N'EE_WatchIOs')
    DROP EVENT SESSION [EE_WatchIOs] ON SERVER;
GO

-- Create the event session
CREATE EVENT SESSION [EE_WatchIOs] ON SERVER
ADD EVENT [sqlserver].[sql_statement_completed]
	(ACTION ([sqlserver].[sql_text]))
ADD TARGET [package0].[asynchronous_file_target]
    (SET FILENAME = N'C:\Pluralsight\EE_WatchIOs.xel', 
    METADATAFILE = N'C:\Pluralsight\EE_WatchIOs.xem')
	-- METADATAFILE not needed from 2012 onwards
WITH (max_dispatch_latency = 1 seconds);
GO

-- Start the session
ALTER EVENT SESSION [EE_WatchIOs] ON SERVER
STATE = START;
GO

-- With DETAILED option
SELECT * FROM sys.dm_db_index_physical_stats (
	DB_ID (N'Company'),
	NULL,
	NULL,
	NULL,
	N'DETAILED');
GO

-- And now with the SAMPLED option
SELECT * FROM sys.dm_db_index_physical_stats (
	DB_ID (N'Company'),
	NULL,
	NULL,
	NULL,
	N'SAMPLED');
GO

-- And now with the LIMITED option
SELECT * FROM sys.dm_db_index_physical_stats (
	DB_ID (N'Company'),
	NULL,
	NULL,
	NULL,
	N'LIMITED');
GO

-- Stop the event session and examine the IOs
ALTER EVENT SESSION [EE_WatchIOs] ON SERVER
STATE = STOP;
GO

-- And now extract everything nicely: 2012+
SELECT
	[data].[value] (
		'(/event[@name=''sql_statement_completed'']/@timestamp)[1]',
			'DATETIME') AS [Time],
	[data].[value] (
		'(/event/data[@name=''duration'']/value)[1]', 'INT') / 1000 AS [Duration (ms)],
	[data].[value] (
		'(/event/data[@name=''logical_reads'']/value)[1]', 'BIGINT') AS [Logical Reads],
	[data].[value] (
		'(/event/data[@name=''physical_reads'']/value)[1]', 'BIGINT') AS [Physical Reads],
	[data].[value] (
		'(/event/action[@name=''sql_text'']/value)[1]',
			'VARCHAR(MAX)') AS [SQL Statement]
FROM 
	(SELECT CONVERT (XML, [event_data]) AS [data]
	FROM sys.fn_xe_file_target_read_file
		(N'C:\SQLskills\EE_WatchIOs*.xel',
		N'C:\SQLskills\EE_WatchIOs*.xem', null, null)
	) [entries]
ORDER BY [Time] DESC
GO

-- And now extract everything nicely: pre-2012
SELECT
	[data].[value] (
		'(/event[@name=''sql_statement_completed'']/@timestamp)[1]',
			'DATETIME') AS [Time],
	[data].[value] (
		'(/event/data[@name=''cpu'']/value)[1]', 'INT') AS [CPU (ms)],
	[data].[value] (
		'(/event/data[@name=''reads'']/value)[1]', 'BIGINT') AS [Reads],
	[data].[value] (
		'(/event/action[@name=''sql_text'']/value)[1]',
			'VARCHAR(MAX)') AS [SQL Statement]
FROM 
	(SELECT CONVERT (XML, [event_data]) AS [data]
	FROM sys.fn_xe_file_target_read_file
		(N'C:\SQLskills\EE_WatchIOs*.xel',
		N'C:\SQLskills\EE_WatchIOs*.xem', null, null)
	) [entries]
ORDER BY [Time] DESC;
GO

-- And now with a bit more useful info
SELECT
	OBJECT_NAME ([ips].[object_id]) AS [Object Name],
	[si].[name] AS [Index Name],
	ROUND ([ips].[avg_fragmentation_in_percent], 2) AS [Fragmentation %],
	[ips].[page_count] AS [Pages],
	ROUND ([ips].[avg_page_space_used_in_percent], 2) AS [Page Density %]
FROM sys.dm_db_index_physical_stats (
	DB_ID (N'test'),
	NULL,

	NULL,
	NULL,
	N'DETAILED') [ips]
CROSS APPLY [sys].[indexes] [si]
WHERE
	[si].[object_id] = [ips].[object_id]
	AND [si].[index_id] = [ips].[index_id]
	AND [ips].[index_level] = 0 -- Just the leaf level
	AND [ips].[alloc_unit_type_desc] = N'IN_ROW_DATA';
GO

-- Examine index fillfactors
SELECT
	[s].[name] AS [schema_name],
    [o].[name] AS [table_name],
    [i].[name] AS [index_name],
    [i].[fill_factor]
FROM sys.indexes AS [i]
JOIN sys.objects AS [o]
    ON [i].[object_id] = [o].[object_id]
JOIN sys.schemas AS [s]
    ON [o].[schema_id] = [s].[schema_id]
WHERE [o].[is_ms_shipped] = 0;
GO