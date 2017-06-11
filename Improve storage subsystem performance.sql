
-- Top cached SPs 
select 
	p.name																		AS [SP Name]
	,ps.execution_count															AS [Execution Count]
	,ISNULL(ps.execution_count/datediff(Minute,ps.cached_time, GETDATE()),0)	AS [Call Per Minute]
	,ps.total_worker_time/ps.execution_count									AS [Avg Worker Time]
	,ps.total_worker_time														AS [Total Worker Time]
	,ps.total_elapsed_time														AS [Total Elapsed Time]
	,ps.total_elapsed_time/ps.execution_count									AS [Avg Elapsed Time]
	,ps.cached_time																AS [Cached Time]
	,ps.total_logical_reads														AS [Total Logical Reads]
	,ps.total_logical_reads/ps.execution_count									AS [Avg Logical Reads]
	,ps.total_physical_reads													AS [Total Physical Reads]
	,ps.total_physical_reads/ps.execution_count									AS [Avg Physical Reads]
	,ps.total_logical_writes													AS [Total Logical Writes]
	,ps.total_logical_writes/ps.execution_count									AS [Avg Logical Writes]

from sys.procedures p with (nolock)
	join sys.dm_exec_procedure_stats ps with (nolock) on p.object_id = ps.object_id 
where ps.database_id = db_id()
order by ps.execution_count desc 
--order by [Avg Elapsed Time] desc
--order by ps.total_worker_time	desc
--order by ps.total_logical_reads
--order by ps.total_physical_reads
--order by ps.total_logical_writes
option (recompile)


-- Find bad non-clustered indexes
select 
	OBJECT_NAME(s.object_id)													AS [Table Name]
	,i.is_disabled																AS [Disabled]
	,i.is_hypothetical															AS [Hypothetical]
	,i.has_filter																AS [Filter]
	,i.fill_factor																AS [Fill Factor]
	,s.user_updates															AS [Total Writes]
	,s.user_seeks + s.user_scans + s.user_lookups							AS [Total Reads]
	,s.user_updates - (s.user_seeks + s.user_scans + s.user_lookups)	AS [Write Read Difference]
from sys.dm_db_index_usage_stats s with (nolock)
	join sys.indexes i with (nolock) on s.index_id = i.index_id and s.object_id = i.object_id
where OBJECTPROPERTY(s.object_id,'IsUserTable') = 1
	and s.database_id = db_id()
	and user_updates > (user_seeks + user_scans + user_lookups)
	and i.index_id > 1
order by [Write Read Difference] desc
	,[Total Writes] desc
	,[Total Reads] asc
option (recompile)

-- Missing indexes
select 
	CONVERT(decimal(18,2), user_seeks * avg_total_user_cost * (avg_user_impact * 0.01))		AS [Index Advantage]
	,migs.last_user_seek																	AS [Last User Seek]
	,mid.[statement]																		AS [Database Schema Table]
	,mid.equality_columns																	AS [Equality Columns]
	,mid.inequality_columns																	AS [Inequality Columns]
	,mid.included_columns																	AS [Included Columns]
	,migs.unique_compiles																	AS [Unique Compiles]
	,migs.user_seeks																		AS [User Seeks]
	,migs.avg_total_user_cost																AS [Avg Total User Cost]
	,migs.avg_user_impact																	AS [Avg User Impact]
from sys.dm_db_missing_index_group_stats as migs with (nolock)
	join sys.dm_db_missing_index_groups as mig with (nolock)
		on migs.group_handle = mig.index_group_handle
	join sys.dm_db_missing_index_details mid with (nolock)
		on mig.index_handle = mig.index_handle
	join sys.partitions p with (nolock)
		on mid.object_id = p.object_id
where mid.database_id = db_id()
order by [Index Advantage]
option (recompile)

