-- SQL and OS Version for current instance
select @@SERVERNAME AS [Server Name], @@VERSION AS [SQL Server and OS Version Info]

--Global trace flags
dbcc tracestatus(-1)

--Hardware info
select
	o.cpu_count							AS [Logical CPU Count]
	,o.scheduler_count					AS [Scheduler Count]
	,o.hyperthread_ratio				AS [Hyperthread Ratio]
	,o.cpu_count/o.hyperthread_ratio	AS [Physical CPU Count]
	,o.physical_memory_kb/1024			AS [Physical Memory (MB)]
	,o.committed_kb/1024				AS [Committed Memory (MB)]
	,o.committed_target_kb/1024			AS [Committed Target Memory (MB)]
	,o.max_workers_count				AS [Max Worker Count]
	,affinity_type_desc					AS [Affinity Type]
	,sqlserver_start_time				AS [SQL Server Start Time]
	,virtual_machine_type_desc			AS [Virtual Machine Type]
from sys.dm_os_sys_info o with (nolock)
option (recompile)

--Socket and core count from SQL Server error log
exec master.sys.xp_readerrorlog 0, 1, N'detected', N'socket'

--Processor description from Windows Registry
exec master.sys.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'HARDWARE\DESCRIPTION\System\CentralProcessor\0',N'ProcessorNameString'

