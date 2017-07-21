--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Query 44 - Individual File Sizes and space available for current database  (File Sizes and Space)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SELECT 
	f.name																						AS [File Name] 
	,f.physical_name																			AS [Physical Name]
	,CAST((f.size/128.0) AS DECIMAL(15,2))														AS [Total Size in MB]
	,CAST(f.size/128.0 - CAST(FILEPROPERTY(f.name,'SpaceUsed') AS int)/128.0 AS DECIMAL(15,2))	AS [Available Space In MB]
	,[file_id]																					AS [File ID]
	,fg.name																					AS [Filegroup Name]
	,f.is_percent_growth																		AS [Is Percent Growth]
FROM sys.database_files AS f WITH (NOLOCK) 
	LEFT OUTER JOIN sys.data_spaces AS fg WITH (NOLOCK) ON f.data_space_id = fg.data_space_id 
OPTION (RECOMPILE);

-- Look at how large and how full the files are and where they are located
-- Make sure the transaction log is not full!!

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Query 45 - I/O Statistics by file for the current database  (IO Stats By File)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SELECT 
	DB_NAME(DB_ID())																							AS [Database Name]
	,df.name																									AS [Logical Name]
	,vfs.[file_id]																								AS [file_id]
	,df.physical_name																							AS [Physical Name]
	,vfs.num_of_reads																							AS [num_of_reads]
	,vfs.num_of_writes																							AS [num_of_writes]
	,vfs.io_stall_read_ms																						AS [io_stall_read_ms]
	,vfs.io_stall_write_ms																						AS [io_stall_write_ms]
	,CAST(100. * vfs.io_stall_read_ms/(vfs.io_stall_read_ms + vfs.io_stall_write_ms) AS DECIMAL(10,1))			AS [IO Stall Reads Pct]
	,CAST(100. * vfs.io_stall_write_ms/(vfs.io_stall_write_ms + vfs.io_stall_read_ms) AS DECIMAL(10,1))			AS [IO Stall Writes Pct]
	,(vfs.num_of_reads + vfs.num_of_writes)																		AS [Writes + Reads]
	,CAST(vfs.num_of_bytes_read/1048576.0 AS DECIMAL(10, 2))													AS [MB Read]
	,CAST(vfs.num_of_bytes_written/1048576.0 AS DECIMAL(10, 2))													AS [MB Written]
	,CAST(100. * vfs.num_of_reads/(vfs.num_of_reads + vfs.num_of_writes) AS DECIMAL(10,1))						AS [# Reads Pct]
	,CAST(100. * vfs.num_of_writes/(vfs.num_of_reads + vfs.num_of_writes) AS DECIMAL(10,1))						AS [# Write Pct]
	,CAST(100. * vfs.num_of_bytes_read/(vfs.num_of_bytes_read + vfs.num_of_bytes_written) AS DECIMAL(10,1))		AS [Read Bytes Pct]
	,CAST(100. * vfs.num_of_bytes_written/(vfs.num_of_bytes_read + vfs.num_of_bytes_written) AS DECIMAL(10,1))	AS [Written Bytes Pct]
FROM sys.dm_io_virtual_file_stats(DB_ID(), NULL) AS vfs
	INNER JOIN sys.database_files AS df WITH (NOLOCK) ON vfs.[file_id]= df.[file_id]
OPTION (RECOMPILE);

-- This helps you characterize your workload better from an I/O perspective for this database
-- It helps you determine whether you has an OLTP or DW/DSS type of workload

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Query 46 -Individual File Sizes and space available for current database (File Sizes and Space)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SELECT 
	f.name																						AS [File Name] 
	,f.physical_name																			AS [Physical Name]
	,CAST((f.size/128.0) AS DECIMAL(15,2))														AS [Total Size in MB]
	,CAST(f.size/128.0 - CAST(FILEPROPERTY(f.name, 'SpaceUsed') AS int)/128.0 AS DECIMAL(15,2))	AS [Available Space In MB]
	,[file_id]																					AS [file_id]
	,fg.name																					AS [Filegroup Name]
	,f.is_percent_growth																		AS [is_percent_growth]
FROM sys.database_files AS f WITH (NOLOCK) 
	LEFT OUTER JOIN sys.data_spaces AS fg WITH (NOLOCK) ON f.data_space_id = fg.data_space_id 
OPTION (RECOMPILE);

-- Look at how large and how full the files are and where they are located
-- Make sure the transaction log is not full!!

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Query 47 - Top cached queries by Execution Count (SQL Server 2014) (Query Execution Counts)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SELECT TOP (100) 
	qs.execution_count									AS execution_count
	,qs.total_rows										AS total_rows
	,qs.last_rows										AS last_rows
	,qs.min_rows										AS min_rows
	,qs.max_rows										AS max_rows
	,qs.last_elapsed_time								AS last_elapsed_time
	,qs.min_elapsed_time								AS min_elapsed_time
	,qs.max_elapsed_time								AS max_elapsed_time
	,total_worker_time									AS total_worker_time
	,total_logical_reads								AS total_logical_reads
	,SUBSTRING(qt.TEXT ,qs.statement_start_offset/2 +1,
	(CASE WHEN qs.statement_end_offset = -1
		THEN LEN(CONVERT(NVARCHAR(MAX) , qt.TEXT)) * 2
		ELSE qs.statement_end_offset 
	END - qs.statement_start_offset)/2)					AS query_text 
FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
	CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
WHERE qt.dbid = DB_ID()
ORDER BY qs.execution_count 
DESC OPTION (RECOMPILE);

-- Uses several new rows returned columns to help troubleshoot performance problems

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Query 48 - Top Cached SPs (SQL Server 2014)  (SP Execution Counts)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SELECT TOP(25) 
	p.name																		AS [SP Name]
	,qs.execution_count															AS [execution_count]
	,ISNULL(qs.execution_count/DATEDIFF(Minute, qs.cached_time, GETDATE()), 0)	AS [Calls/Minute]
	,qs.total_worker_time/qs.execution_count									AS [AvgWorkerTime]
	,qs.total_worker_time														AS [TotalWorkerTime]
	,qs.total_elapsed_time														AS [total_elapsed_time]
	,qs.total_elapsed_time/qs.execution_count									AS [avg_elapsed_time]
	,qs.cached_time																AS [cached_time]
FROM sys.procedures AS p WITH (NOLOCK)
	INNER JOIN sys.dm_exec_procedure_stats AS qs WITH (NOLOCK) ON p.[object_id] = qs.[object_id]
WHERE qs.database_id = DB_ID()
ORDER BY qs.execution_count DESC 
OPTION (RECOMPILE);

-- Tells you which cached stored procedures are called the most often
-- This helps you characterize and baseline your workload

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Query 49 - Top cached queries by Execution Count (SQL Server 2014)  (Query Execution Counts)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SELECT TOP (100) 
	qs.execution_count							AS execution_count
	,qs.total_rows								AS total_rows
	,qs.last_rows								AS last_rows
	,qs.min_rows								AS min_rows
	,qs.max_rows								AS max_rows
	,qs.last_elapsed_time						AS last_elapsed_time
	,qs.min_elapsed_time						AS min_elapsed_time
	,qs.max_elapsed_time						AS max_elapsed_time
	,total_worker_time							AS total_worker_time
	,total_logical_reads						AS total_logical_reads
	,SUBSTRING(qt.TEXT ,qs.statement_start_offset/2 +1,
		(CASE WHEN qs.statement_end_offset = -1
			THEN LEN(CONVERT(NVARCHAR(MAX), qt.TEXT)) * 2
			ELSE qs.statement_end_offset 
		END - qs.statement_start_offset)/2)		AS query_text 
FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
	CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
WHERE qt.dbid = DB_ID()
ORDER BY qs.execution_count DESC 
OPTION (RECOMPILE);

-- Uses several new rows returned columns to help troubleshoot performance problems

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Query 50 - Top Cached SPs By Avg Elapsed Time (SQL Server 2014)  (SP Avg Elapsed Time)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SELECT TOP(25) 
	p.name																		AS [SP Name]
	,qs.total_elapsed_time/qs.execution_count									AS [avg_elapsed_time]
	,qs.total_elapsed_time														AS [total_elapsed_time]
	,qs.execution_count															AS [execution_count]
	,ISNULL(qs.execution_count/DATEDIFF(Minute ,qs.cached_time ,GETDATE()), 0)	AS [Calls/Minute]
	,qs.total_worker_time/qs.execution_count									AS [AvgWorkerTime]
	,qs.total_worker_time														AS [TotalWorkerTime]
	,qs.cached_time																AS [cached_time]
FROM sys.procedures AS p WITH (NOLOCK)
	INNER JOIN sys.dm_exec_procedure_stats AS qs WITH (NOLOCK) ON p.[object_id] = qs.[object_id]
WHERE qs.database_id = DB_ID()
ORDER BY avg_elapsed_time DESC 
OPTION (RECOMPILE);

-- This helps you find long-running cached stored procedures that
-- may be easy to optimize with standard query tuning techniques

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Query 51 - Top Cached SPs By Total Worker time (SQL Server 2014). Worker time relates to CPU cost (SP Worker Time)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SELECT TOP(25) 
	p.name																		AS [SP Name]
	,qs.total_worker_time														AS [TotalWorkerTime]
	,qs.total_worker_time/qs.execution_count									AS [AvgWorkerTime]
	,qs.execution_count															AS [execution_count]
	,ISNULL(qs.execution_count/DATEDIFF(Minute, qs.cached_time, GETDATE()), 0)	AS [Calls/Minute]
	,qs.total_elapsed_time														AS [total_elapsed_time]
	,qs.total_elapsed_time/qs.execution_count									AS [avg_elapsed_time]
	,qs.cached_time																AS [cached_time]
FROM sys.procedures AS p WITH (NOLOCK)
	INNER JOIN sys.dm_exec_procedure_stats AS qs WITH (NOLOCK) ON p.[object_id] = qs.[object_id]
WHERE qs.database_id = DB_ID()
ORDER BY qs.total_worker_time DESC 
OPTION (RECOMPILE);

-- This helps you find the most expensive cached stored procedures from a CPU perspective
-- You should	look at this if you see signs of CPU pressure

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Query 52 - Top Cached SPs By Total Logical Reads (SQL Server 2014). Logical reads relate to memory pressure (SP Logical Reads)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SELECT TOP(25) 
	p.name																		AS [SP Name]
	,qs.total_logical_reads														AS [TotalLogicalReads]
	,qs.total_logical_reads/qs.execution_count									AS [AvgLogicalReads]
	,qs.execution_count															AS [execution_count]
	,ISNULL(qs.execution_count/DATEDIFF(Minute, qs.cached_time, GETDATE()), 0)	AS [Calls/Minute]
	,qs.total_elapsed_time														AS [total_elapsed_time]
	,qs.total_elapsed_time/qs.execution_count									AS [avg_elapsed_time]
	,qs.cached_time																AS [cached_time]
FROM sys.procedures AS p WITH (NOLOCK)
	INNER JOIN sys.dm_exec_procedure_stats AS qs WITH (NOLOCK) ON p.[object_id] = qs.[object_id]
WHERE qs.database_id = DB_ID()
ORDER BY qs.total_logical_reads DESC 
OPTION (RECOMPILE);

-- This helps you find the most expensive cached stored procedures from a memory perspective
-- You should look at this if you see signs of memory pressure

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Query 53 - Top Cached SPs By Total Physical Reads (SQL Server 2014). Physical reads relate to disk I/O pressure (SP Physical Reads)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SELECT TOP(25) 
	p.name											AS [SP Name]
	,qs.total_physical_reads						AS [TotalPhysicalReads]
	,qs.total_physical_reads/qs.execution_count		AS [AvgPhysicalReads]
	,qs.execution_count								AS [execution_count]
	,qs.total_logical_reads							AS [total_logical_reads]
	,qs.total_elapsed_time							AS [total_elapsed_time]
	,qs.total_elapsed_time/qs.execution_count		AS [avg_elapsed_time]
	,qs.cached_time									AS [cached_time]
FROM sys.procedures AS p WITH (NOLOCK)
	INNER JOIN sys.dm_exec_procedure_stats AS qs WITH (NOLOCK) ON p.[object_id] = qs.[object_id]
WHERE qs.database_id = DB_ID()
	AND qs.total_physical_reads > 0
ORDER BY qs.total_physical_reads DESC
	,qs.total_logical_reads DESC 
OPTION (RECOMPILE);

-- This helps you find the most expensive cached stored procedures from a read I/O perspective
-- You should look at this if you see signs of I/O pressure or of memory pressure

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Query 54 - Lists the top statements by average input/output usage for the current database (Top IO Statements)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SELECT TOP(50) 
	OBJECT_NAME(qt.objectid, dbid)											AS [SP Name]
	,(qs.total_logical_reads + qs.total_logical_writes) /qs.execution_count AS [Avg IO]
	,qs.execution_count														AS [Execution Count]
	,SUBSTRING(qt.[text] ,qs.statement_start_offset/2 , 
	(CASE 
		WHEN qs.statement_end_offset = -1 
		THEN LEN(CONVERT(nvarchar(max), qt.[text])) * 2 
		ELSE qs.statement_end_offset 
	 END - qs.statement_start_offset)/2)									AS [Query Text]	
FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
	CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
WHERE qt.[dbid] = DB_ID()
ORDER BY [Avg IO] DESC 
OPTION (RECOMPILE);

-- Helps you find the most expensive statements for I/O by SP

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Query 55 - Possible Bad NC Indexes (writes > reads)  (Bad NC Indexes)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SELECT 
	OBJECT_NAME(s.[object_id])									AS [Table Name]
	,i.name														AS [Index Name]
	,i.index_id													AS [index_id]
	,i.is_disabled												AS [is_disabled]
	,i.is_hypothetical											AS [is_hypothetical]
	,i.has_filter												AS [has_filter]
	,i.fill_factor												AS [fill_factor]
	,user_updates												AS [Total Writes]
	,user_seeks + user_scans + user_lookups						AS [Total Reads]
	,user_updates - (user_seeks + user_scans + user_lookups)	AS [Difference]
FROM sys.dm_db_index_usage_stats AS s WITH (NOLOCK)
	INNER JOIN sys.indexes AS i WITH (NOLOCK) ON s.[object_id] = i.[object_id]
		AND i.index_id = s.index_id
WHERE OBJECTPROPERTY(s.[object_id] ,'IsUserTable') = 1
	AND s.database_id = DB_ID()
	AND user_updates > (user_seeks + user_scans + user_lookups)
	AND i.index_id > 1
ORDER BY [Difference] DESC
	,[Total Writes] DESC
	,[Total Reads] ASC 
OPTION (RECOMPILE);

-- Look for indexes with high numbers of writes and zero or very low numbers of reads
-- Consider your complete workload and how long your instance has been running
-- Investigate further before dropping an index!

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Query 56 - Missing Indexes for current database by Index Advantage  (Missing Indexes)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SELECT DISTINCT 
	CONVERT(decimal(18,2), user_seeks * avg_total_user_cost * (avg_user_impact * 0.01)) AS [index_advantage]
	,migs.last_user_seek																AS [last_user_seek]
	,mid.[statement]																	AS [Database.Schema.Table]
	,mid.equality_columns																AS [equality_columns]
	,mid.inequality_columns																AS [inequality_columns]
	,mid.included_columns																AS [included_columns]
	,migs.unique_compiles																AS [unique_compiles]
	,migs.user_seeks																	AS [user_seeks]
	,migs.avg_total_user_cost															AS [avg_total_user_cost]
	,migs.avg_user_impact																AS [avg_user_impact]
	,OBJECT_NAME(mid.[object_id])														AS [Table Name]
	,p.rows																				AS [Table Rows]
FROM sys.dm_db_missing_index_group_stats AS migs WITH (NOLOCK)
	INNER JOIN sys.dm_db_missing_index_groups AS mig WITH (NOLOCK) ON migs.group_handle = mig.index_group_handle
	INNER JOIN sys.dm_db_missing_index_details AS mid WITH (NOLOCK) ON mig.index_handle = mid.index_handle
	INNER JOIN sys.partitions AS p WITH (NOLOCK) ON p.[object_id] = mid.[object_id]
WHERE mid.database_id = DB_ID() 
ORDER BY index_advantage DESC 
OPTION (RECOMPILE);

-- Look at last user seek time, number of user seeks to help determine source and importance
-- SQL Server is overly eager to add included columns
, so beware
-- Do not just blindly add indexes that show up from this query!!!

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Query 57 - Find missing index warnings for cached plans in the current database (Missing Index Warnings)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Note: This query could take some time on a busy instance
SELECT TOP(25) 
	OBJECT_NAME(objectid)	AS [ObjectName]
	,query_plan				AS [query_plan]
	,cp.objtype				AS [objtype]
	,cp.usecounts			AS [usecounts]
FROM sys.dm_exec_cached_plans AS cp WITH (NOLOCK)
	CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) AS qp
WHERE CAST(query_plan AS NVARCHAR(MAX)) LIKE N'%MissingIndex%'
	AND dbid = DB_ID()
ORDER BY cp.usecounts DESC 
OPTION (RECOMPILE);

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
--Query 58 - Get Table names, row counts, and compression status for clustered index or heap (Table Sizes)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SELECT 
	OBJECT_NAME(object_id)	AS [ObjectName]
	,SUM(Rows)				AS [RowCount]
	,data_compression_desc	AS [CompressionType]
FROM sys.partitions WITH (NOLOCK)
WHERE index_id < 2 --ignore the partitions from the non-clustered index if any
	AND OBJECT_NAME(object_id) NOT LIKE N'sys%'
	AND OBJECT_NAME(object_id) NOT LIKE N'queue_%' 
	AND OBJECT_NAME(object_id) NOT LIKE N'filestream_tombstone%' 
	AND OBJECT_NAME(object_id) NOT LIKE N'fulltext%'
	AND OBJECT_NAME(object_id) NOT LIKE N'ifts_comp_fragment%'
	AND OBJECT_NAME(object_id) NOT LIKE N'filetable_updates%'
	AND OBJECT_NAME(object_id) NOT LIKE N'xml_index_nodes%'
GROUP BY object_id, data_compression_desc
ORDER BY SUM(Rows) 
DESC OPTION (RECOMPILE);

-- Gives you an idea of table sizes, and possible data compression opportunities

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Query 59 - Get some key table properties (Table Properties)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SELECT 
	[name]
	,create_date
	,lock_on_bulk_load
	,is_replicated
	,has_replication_filter
	,is_tracked_by_cdc
	,lock_escalation_desc
	,is_memory_optimized
	,durability_desc
FROM sys.tables WITH (NOLOCK) 
ORDER BY [name] 
OPTION (RECOMPILE);

-- Gives you some good information about your tables
-- Is Memory optimized and durability description are Hekaton-related properties that are new in SQL Server 2014

-- Helps you connect missing indexes to specific stored procedures or queries
-- This can help you decide whether to add them or not

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Query 60 - Breaks down buffers used by current database by object (table, index) in the buffer cache (Buffer Usage)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SELECT 
	OBJECT_NAME(p.[object_id])				AS [Object Name]
	,p.index_id								AS [index_id]
	,CAST(COUNT(*)/128.0 AS DECIMAL(10, 2)) AS [Buffer size(MB)]
	,COUNT(*)								AS [BufferCount]
	,p.Rows									AS [Row Count]
	,p.data_compression_desc				AS [Compression Type]
FROM sys.allocation_units AS a WITH (NOLOCK)
	INNER JOIN sys.dm_os_buffer_descriptors AS b WITH (NOLOCK) ON a.allocation_unit_id = b.allocation_unit_id
	INNER JOIN sys.partitions AS p WITH (NOLOCK) ON a.container_id = p.hobt_id
WHERE b.database_id = CONVERT(int ,DB_ID())
	AND p.[object_id] > 100
GROUP BY p.[object_id]
	,p.index_id
	,p.data_compression_desc
	,p.[Rows]
ORDER BY [BufferCount] DESC 
OPTION (RECOMPILE);

-- Tells you what tables and indexes are using the most memory in the buffer cache
-- It can help identify possible candidates for data compression
-- This query can take some time on a large database

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Query 61 - When were Statistics last updated on all indexes? (Statistics Update)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SELECT 
	o.name									AS [name]
	,i.name									AS [Index Name]
	,STATS_DATE(i.[object_id], i.index_id)	AS [Statistics Date]
	,s.auto_created							AS [auto_created]
	,s.no_recompute							AS [no_recompute]
	,s.user_created							AS [user_created]
	,st.row_count							AS [row_count]
	,s.is_incremental						AS [is_incremental]
	,s.is_temporary							AS [is_temporary]
	,st.used_page_count						AS [used_page_count]
FROM sys.objects AS o WITH (NOLOCK)
	INNER JOIN sys.indexes AS i WITH (NOLOCK) ON o.[object_id] = i.[object_id]
	INNER JOIN sys.stats AS s WITH (NOLOCK) ON i.[object_id] = s.[object_id] 
		AND i.index_id = s.stats_id
	INNER JOIN sys.dm_db_partition_stats AS st WITH (NOLOCK) ON o.[object_id] = st.[object_id]
		AND i.[index_id] = st.[index_id]
WHERE o.[type] IN ('U', 'V')
	AND st.row_count > 0
ORDER BY STATS_DATE(i.[object_id], i.index_id) DESC 
OPTION (RECOMPILE);  

-- Helps discover possible problems with out-of-date statistics
-- Also gives you an idea which indexes are most active

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Query 61 - Get fragmentation info for all indexes above a certain size in the current database (Index Fragmentation)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

SELECT 
	DB_NAME(ps.database_id)				AS [Database Name]
	,OBJECT_NAME(ps.OBJECT_ID)			AS [Object Name]
	,i.name								AS [Index Name]
	,ps.index_id						AS [index_id]
	,ps.index_type_desc					AS [index_type_desc]
	,ps.avg_fragmentation_in_percent	AS [avg_fragmentation_in_percent]
	,ps.fragment_count					AS [fragment_count]
	,ps.page_count						AS [page_count]
	,i.fill_factor						AS [fill_factor]
	,i.has_filter						AS [has_filter]
	,i.filter_definition				AS [filter_definition]
FROM sys.dm_db_index_physical_stats(DB_ID(),NULL,NULL,NULL, N'LIMITED') AS ps
	INNER JOIN sys.indexes AS i WITH (NOLOCK) ON ps.[object_id] = i.[object_id] 
		AND ps.index_id = i.index_id
WHERE ps.database_id = DB_ID()
	AND ps.page_count > 2500
ORDER BY ps.avg_fragmentation_in_percent * ps.page_count DESC 
OPTION (RECOMPILE);

-- Helps determine whether you have framentation in your relational indexes
-- and how effective your index maintenance strategy is
-- Note: This could take some time on a very large database

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Query 62 - Index Read/Write stats (all tables in current DB) ordered by Reads (Overall Index Usage - Reads)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SELECT 
	OBJECT_NAME(s.[object_id])				AS [ObjectName]
	,i.index_id								AS [index_id]
	, i.name								AS [IndexName]
	,user_seeks + user_scans + user_lookups AS [Reads]
	,s.user_updates							AS [Writes]
	,i.type_desc							AS [IndexType]
	,i.fill_factor							AS [FillFactor]
	,i.has_filter							AS [has_filter]
	,i.filter_definition					AS [filter_definition]
	,s.last_user_scan						AS [last_user_scan]
	,s.last_user_lookup						AS [last_user_lookup]
	,s.last_user_seek						AS [last_user_seek]
FROM sys.dm_db_index_usage_stats AS s WITH (NOLOCK)
	INNER JOIN sys.indexes AS i WITH (NOLOCK) ON s.[object_id] = i.[object_id]
WHERE OBJECTPROPERTY(s.[object_id],'IsUserTable') = 1
	AND i.index_id = s.index_id
	AND s.database_id = DB_ID()
ORDER BY user_seeks + user_scans + user_lookups DESC 
OPTION (RECOMPILE); -- Order by reads

-- Show which indexes in the current database are most active for Reads

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Query 63 - Index Read/Write stats (all tables in current DB) ordered by Writes (Overall Index Usage - Writes)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SELECT 
	OBJECT_NAME(s.[object_id])				AS [ObjectName]
	,i.index_id								AS [index_id]
	,i.name									AS [IndexName]
	,s.user_updates							AS [Writes]
	,user_seeks + user_scans + user_lookups AS [Reads]
	,i.type_desc							AS [IndexType]
	,i.fill_factor							AS [FillFactor]
	,i.has_filter							AS [has_filter]
	,i.filter_definition					AS [filter_definition]
	,s.last_system_update					AS [last_system_update]
	,s.last_user_update						AS [last_user_update]
FROM sys.dm_db_index_usage_stats AS s WITH (NOLOCK)
	INNER JOIN sys.indexes AS i WITH (NOLOCK) ON s.[object_id] = i.[object_id]
WHERE OBJECTPROPERTY(s.[object_id],'IsUserTable') = 1
	AND i.index_id = s.index_id
	AND s.database_id = DB_ID()
ORDER BY s.user_updates DESC 
OPTION (RECOMPILE);						 -- Order by writes

-- Show which indexes in the current database are most active for Writes

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Query 64 - Look at recent Full backups for the current database (Recent Full Backups)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SELECT TOP (30) 
	bs.machine_name																							AS [machine_name]
	,bs.server_name																							AS [server_name]
	,bs.database_name																						AS [Database Name]
	,bs.recovery_model																						AS [recovery_model]
	,CONVERT (BIGINT,bs.backup_size / 1048576 )																AS [Uncompressed Backup Size (MB)]
	,CONVERT (BIGINT,bs.compressed_backup_size / 1048576 )													AS [Compressed Backup Size (MB)]
	,CONVERT (NUMERIC (20,2),(CONVERT (FLOAT, bs.backup_size) /CONVERT (FLOAT, bs.compressed_backup_size))) AS [Compression Ratio]
	,DATEDIFF (SECOND, bs.backup_start_date, bs.backup_finish_date)											AS [Backup Elapsed Time (sec)]
	,bs.backup_finish_date																					AS [Backup Finish Date]
FROM msdb.dbo.backupset AS bs WITH (NOLOCK)
WHERE DATEDIFF (SECOND, bs.backup_start_date, bs.backup_finish_date) > 0 
	AND bs.backup_size > 0
	AND bs.type = 'D' -- Change to L if you want Log backups
	AND database_name = DB_NAME(DB_ID())
ORDER BY bs.backup_finish_date DESC 
OPTION (RECOMPILE);

-- Are your backup sizes and times changing over time?

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Query 65 - Get the average full backup size by month for the current database (SQL 2012) (Database Size History)
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- This helps you understand your database growth over time
-- Adapted from Erin Stellato
SELECT [database_name]													AS [Database]
	,DATEPART(month,[backup_start_date])								AS [Month]
	,CAST(AVG([backup_size]/1024/1024) AS DECIMAL(15,2))				AS [Backup Size (MB)]
	,CAST(AVG([compressed_backup_size]/1024/1024) AS DECIMAL(15,2))		AS [Compressed Backup Size (MB)]
	,CAST(AVG([backup_size]/[compressed_backup_size]) AS DECIMAL(15,2)) AS [Compression Ratio]
FROM msdb.dbo.backupset WITH (NOLOCK)
WHERE [database_name] = DB_NAME(DB_ID())
	AND [type] = 'D'
	AND backup_start_date >= DATEADD(MONTH, -12, GETDATE())
GROUP BY [database_name]
	,DATEPART(mm
	,[backup_start_date]) 
OPTION (RECOMPILE);

-- The Backup Size (MB) (without backup compression) shows the true size of your database over time
-- This helps you track and plan your data size growth
-- It is possible that your data files may be larger on disk due to empty space within those files