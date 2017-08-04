use master
go

if DATABASEPROPERTYEX('statsdemo','version') > 0
begin
	alter database statsdemo set single_user with rollback immediate
	drop database statsdemo
end

create database statsdemo

use statsdemo
go

create table t1 (c1 date, c2 int)
create clustered index ci_t1_c1 on t1(c1)

set nocount on;
declare @i int = 0
while @i < 10000
begin
	insert t1 values (dateadd(day,@i%1000,getdate()),@i)
	set @i += 1
end


select c1, count(*) from t1 group by c1 

dbcc show_statistics (t1, ci_t1_c1)
dbcc show_statistics (t1, s_t1_201707)

update t1
set c1 = dateadd(year,10,getdate()), c2 = 9999
where c1 = '2017-07-24'	

select * from t1 where c1 = '2017-07-24' 

update statistics t1 (ci_t1_c1) with fullscan

update statistics t1(s_t1_201707) with fullscan
create statistics s_t1_201707 on t1(c1)
where c1 >= '2017-07-01' and c1 < '2017-08-01' 
with fullscan

SELECT
	s.object_id							AS [Object ID]
	,s.name								AS [Stats Name]
	,OBJECT_SCHEMA_NAME(s.object_id)	AS [Schema]
	,Object_name(s.object_id)			AS [Object Name]
	,s.auto_created						AS [Auto Created]
	,s.no_recompute						AS [No Recompute]
	,s.has_filter						AS [Has Filter]
	,s.filter_definition				AS [Filter Definition]
	,col_name(s.object_id,sc.object_id)	AS [Col Name]
	,sp.rows							AS [Rows]
	,sp.rows_sampled					AS [Rows Sampled]
	,sp.modification_counter			AS [Mod Counter]
	,sp.last_updated					AS [Last Updated]
FROM sys.stats s
	INNER JOIN sys.stats_columns sc ON s.stats_id = sc.stats_id
		AND s.object_id = sc.object_id
	CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
	INNER JOIN sys.objects o on s.object_id = o.object_id
WHERE o.is_ms_shipped = 0
