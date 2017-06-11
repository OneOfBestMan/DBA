
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
	 
from sys.procedures p
	join sys.dm_exec_procedure_stats ps on p.object_id = ps.object_id
where ps.database_id = db_id()
order by ps.execution_count desc 
--order by [Avg Elapsed Time] desc
--order by ps.total_worker_time	desc
--order by ps.total_logical_reads
--order by ps.total_physical_reads
option (recompile)