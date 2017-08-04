
SELECT 
	d.database_id
	,d.name
	,d.is_auto_create_stats_on
	,d.is_auto_create_stats_incremental_on
	,d.is_auto_update_stats_on
	,d.is_auto_update_stats_async_on
FROM sys.databases d


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
