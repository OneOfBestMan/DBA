
-- Top cached SPs by Execution Count
select 
	p.name																		AS [SP Name]
	,ps.execution_count															AS [Execution Count]
	,ISNULL(ps.execution_count/datediff(Minute,ps.cached_time, GETDATE()),0)	AS [Call Per Minute]
	,ps.total_worker_time/ps.execution_count									AS [Avg Worker Time]
	,ps.total_elapsed_time														AS [Total Elapsed Time]
	,ps.total_elapsed_time/ps.execution_count									AS [Avg Elapsed Time]
	,ps.cached_time																AS [Cached Time]
from sys.procedures p
	join sys.dm_exec_procedure_stats ps on p.object_id = ps.object_id
where ps.database_id = db_id()
order by ps.execution_count desc 
option (recompile)