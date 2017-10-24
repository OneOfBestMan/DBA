with buffers as (
select 
	case 
		when database_id = 32767 then 'Resource DB'
		else db_name(database_id)
	end								AS DatabaseName
	,sum(case 
		when is_modified = 1 
		then 1 else 0 
	end)							AS DirtyPageCount
	,sum(case 
		when is_modified = 0
		then 1 else 0
	end)							AS CleanPageCount
from sys.dm_os_buffer_descriptors
group by database_id
)
select 
	DatabaseName
	,DirtyPageCount
	,CleanPageCount
	,cast(DirtyPageCount * 8 / 1024.0 as decimal(9,2)) as DirtyPageMB 
	,cast(CleanPageCount * 8 / 1024.0 as decimal(9,2)) as CleanPageMB
from buffers
order by DatabaseName
option (recompile)
