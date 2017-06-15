-- SQL and OS Version for current instance
select @@SERVERNAME AS [Server Name], @@VERSION AS [SQL Server and OS Version Info]
go

--Global trace flags
dbcc tracestatus(-1)
go

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
go

--Socket and core count from SQL Server error log
exec master.sys.xp_readerrorlog 0, 1, N'detected', N'socket'
go

--Processor description from Windows Registry
exec master.sys.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'HARDWARE\DESCRIPTION\System\CentralProcessor\0',N'ProcessorNameString'
go

-- Instance Configuration
select 
	name			AS [Name]
	,value			AS [Value]
	,value_in_use	AS [Value In Use]
	,description	AS [Description]
from master.sys.configurations with (nolock)
where name in (
	'backup checksum default'
	,'backup compression default'
	,'cost threshold for parallelism'
	,'max degree of parallelism'
	,'max server memory (MB)'
	,'optimize for ad hoc workloads'
)
order by name
option (recompile)
go

-- Buffer pool extensions
select 
	path							AS [Path]
	,state_description				AS [State Description]
	,current_size_in_kb/1024		AS [Current Size (MB)]
from sys.dm_os_buffer_pool_extension_configuration with (nolock)
option (recompile)
go

-- Buffer pool extension usage by database
select 
	DB_NAME(database_id)						AS [Database Name]
	,count(page_id)								AS [Page Count]
	,cast(count(*)/128.0 AS decimal(10,2))		AS [Buffer Size (MB)]
	,AVG(read_microsec)							AS [Avg Read Time (microseconds)]
from sys.dm_os_buffer_descriptors with (nolock)
where database_id <> 32767
	and is_in_bpool_extension = 1
group by DB_NAME(database_id)
order by [Buffer Size (MB)] DESC
option (recompile)
go


--file name for databases in instance
select
	db_name(database_id)				AS [Database Name]
	,file_id							AS [File ID]
	,name								AS [Logical Filename]
	,physical_name						AS [Physical Filename]
	,type_desc							AS [Type]
	,state_desc							AS [State]
	,is_percent_growth					AS [Percent Growth]
	,growth								AS [Growth]
	,convert(bigint, growth/128.0)		AS [Growth in MB]
	,convert(bigint, size/128.0)		AS [Total Size in MB]
from master.sys.master_files with (nolock)
where database_id <> 32767
order by db_name(database_id)
option (recompile)
go

-- volume info for all luns that host database files
select distinct
	v.volume_mount_point																			AS [Volume Mount Point]
	,v.file_system_type																				AS [File System Type]
	,v.logical_volume_name																			AS [Volume Logical Name]
	,convert(decimal(18,2), v.total_bytes/1073741824.0)												AS [Total Size (GB)]
	,convert(decimal(18,2),v.available_bytes/1073741824.0)											AS [Available Size (GB)]
	,cast(cast(v.available_bytes as float)/ cast(v.total_bytes as float) as decimal(18,2)) * 100	AS [Space Free %]
from sys.master_files f with (nolock)
	cross apply sys.dm_os_volume_stats(f.database_id, f.file_id) v
option (recompile)
go

--Total and free space on the luns w/ database files
create table #IOWarningResults(LogDate datetime, ProcessInfo sysname, LogText nvarchar(1000))
	
	insert into #IOWarningResults
	exec xp_readerrorlog 0, 1, N'taking longer than 15 seconds';

select 
	LogDate
	,ProcessInfo
	,LogText
from #IOWarningResults
order by LogDate Desc

drop table #IOWarningResults
go

-- drive level latency for all volumes
select
	[Drive]														AS [Drive]
	,CASE 
		WHEN num_of_reads = 0 THEN 0 
		ELSE (io_stall_read_ms/num_of_reads)	
	END															AS [Read Latency]
	,CASE
		WHEN num_of_writes = 0 THEN 0
		ELSE (io_stall_write_ms/num_of_writes)	
	END															AS [Write Latency]
	,CASE
		WHEN (num_of_reads = 0 and num_of_writes = 0) THEN 0
		ELSE (io_stall/(num_of_reads + num_of_writes)) 
	END															AS [Overall Latency]
	,CASE 
		WHEN num_of_reads = 0 THEN 0
		ELSE (num_of_bytes_read/num_of_reads)
	END															AS [Avg Bytes/Read]
	,CASE 
		WHEN io_stall_write_ms = 0 THEN 0
		ELSE (num_of_bytes_written/num_of_writes)
	END															AS [Avg Bytes/Write]
	,CASE 
		WHEN (num_of_reads = 0 and num_of_writes = 0) THEN 0
		ELSE (num_of_bytes_read + num_of_bytes_written)/(num_of_reads + num_of_writes)
	END															AS [Avg Bytes/Transfer]
from (
	select 
		left(upper(mf.physical_name),2)				AS [Drive]
		,SUM(num_of_reads)							AS [num_of_reads]
		,SUM(io_stall_read_ms)						AS [io_stall_read_ms]
		,SUM(num_of_writes)							AS [num_of_writes]
		,SUM(io_stall_write_ms)						AS [io_stall_write_ms]
		,SUM(num_of_bytes_read)						AS [num_of_bytes_read]
		,SUM(num_of_bytes_written)					AS [num_of_bytes_written]
		,SUM(io_stall)								AS [io_stall]
	from sys.dm_io_virtual_file_stats(null,null) vfs
		join sys.master_files mf with (nolock)
			on vfs.database_id = mf.database_id and vfs.file_id = mf.file_id
	group by left(upper(mf.physical_name),2)) tab
order by [Overall Latency]
option (recompile)
go

-- io latency at file level
select 
	DB_NAME(fs.database_id)																								AS [Database Name]
	,cast(fs.io_stall_read_ms/(1.0 + fs.num_of_reads) AS numeric(10,1))													AS [Avg Read Stall (ms)]
	,cast(fs.io_stall_write_ms/(1.0 + fs.num_of_writes) as numeric(10,1))												AS [Avg Write Stall (ms)]
	,cast((fs.io_stall_read_ms + fs.io_stall_write_ms) / (1.0 + fs.num_of_reads + fs.num_of_writes) as numeric(10,1))	AS [Avg IO Stall (ms)]
	,convert(decimal(10,1), mf.size/128.0)																				AS [File Size (MB)]
	,mf.physical_name																									AS [Physical Name]
	,mf.type_desc																										AS [Type]
	,fs.io_stall_read_ms																								AS [IO Stall Read (ms)]
	,fs.num_of_reads																									AS [Reads]
	,fs.io_stall_write_ms																								AS [IO Stall Writes (ms)]
	,fs.num_of_writes																									AS [Writes]
	,fs.io_stall_read_ms + fs.io_stall_write_ms																			AS [IO Stall (ms)]
	,fs.num_of_reads + fs.num_of_writes																					AS [Total IO]
from sys.dm_io_virtual_file_stats(null,null) fs
	join sys.master_files mf with (nolock)
		on fs.database_id = mf.database_id and fs.file_id = mf.file_id
order by [Avg IO Stall (ms)] desc
option (recompile)
go

-- VLF counts
create table #VLFInfo
(
	RecoveryUnitID int
	,FileID int
	,FileSize bigint
	,StartOffset bigint
	,FSeqNo bigint
	,Status bigint
	,Parity bigint
	,CreateLSN numeric(38)
);

create table #VLFCountResults
(
	DatabaseName sysname
	,VLFCount int
);

exec sp_MSforeachdb 
	N'Use [?];
		
		INSERT INTO #VLFInfo
		EXEC sp_executesql N''DBCC LOGINFO([?])'';

		INSERT INTO #VLFCountResults
		SELECT DB_NAME(), COUNT(*)
		FROM #VLFInfo;

		TRUNCATE TABLE #VLFInfo;'

SELECT DatabaseName, VLFCount
FROM #VLFCountResults
Order by VLFCount DESC;

drop table #VLFCountResults
drop table #VLFInfo

 

 -- I/O Utilization by database
 with Aggregate_IO_Statistics
 as
 (select 
	db_name(database_id)															AS [Database Name]
	,cast(sum(num_of_bytes_read + num_of_bytes_written)/1048576 AS decimal(12,2))	AS [IO_In_MB]
 from sys.dm_io_virtual_file_stats(null, null) DM_IO_Stats
 group by database_id)
 select 
	Row_number() over (order by A.[IO_In_MB] Desc)						AS [I/O Rank]
	,A.[Database Name]													AS [Database Name]
	,A.[IO_In_MB]														AS [Total I/O (MB)]
	,cast([IO_In_MB]/SUM([IO_In_MB]) OVER() * 100.0 AS decimal(5,2))	AS [I/O Percent]
 from Aggregate_IO_Statistics A

--Top waits for sql server instance since restart or statistics clear
with [Waits]
as (
	SELECT 
		wait_type											AS [Wait_type]
		,wait_time_ms/1000.0								AS [Wait (sec)]
		,(wait_time_ms - signal_wait_time_ms) / 1000.0		AS [Resource (sec)]
		,signal_wait_time_ms / 1000.0						AS [Signal (sec)]
		,waiting_tasks_count								AS [WaitCount]
		,100.0 * wait_time_ms / SUM(wait_time_ms) over()	AS [Percentage]
		,row_number() over(order by wait_time_ms desc)		AS [RowNum]
	FROM sys.dm_os_wait_stats with (nolock)
	where wait_type not in (
        N'BROKER_EVENTHANDLER', N'BROKER_RECEIVE_WAITFOR', N'BROKER_TASK_STOP',
		N'BROKER_TO_FLUSH', N'BROKER_TRANSMITTER', N'CHECKPOINT_QUEUE',
        N'CHKPT', N'CLR_AUTO_EVENT', N'CLR_MANUAL_EVENT', N'CLR_SEMAPHORE',
        N'DBMIRROR_DBM_EVENT', N'DBMIRROR_EVENTS_QUEUE', N'DBMIRROR_WORKER_QUEUE',
		N'DBMIRRORING_CMD', N'DIRTY_PAGE_POLL', N'DISPATCHER_QUEUE_SEMAPHORE',
        N'EXECSYNC', N'FSAGENT', N'FT_IFTS_SCHEDULER_IDLE_WAIT', N'FT_IFTSHC_MUTEX',
        N'HADR_CLUSAPI_CALL', N'HADR_FILESTREAM_IOMGR_IOCOMPLETION', N'HADR_LOGCAPTURE_WAIT', 
		N'HADR_NOTIFICATION_DEQUEUE', N'HADR_TIMER_TASK', N'HADR_WORK_QUEUE',
        N'KSOURCE_WAKEUP', N'LAZYWRITER_SLEEP', N'LOGMGR_QUEUE', N'ONDEMAND_TASK_QUEUE',
        N'PWAIT_ALL_COMPONENTS_INITIALIZED', N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
        N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP', N'QDS_SHUTDOWN_QUEUE', N'REQUEST_FOR_DEADLOCK_SEARCH',
		N'RESOURCE_QUEUE', N'SERVER_IDLE_CHECK', N'SLEEP_BPOOL_FLUSH', N'SLEEP_DBSTARTUP',
		N'SLEEP_DCOMSTARTUP', N'SLEEP_MASTERDBREADY', N'SLEEP_MASTERMDREADY',
        N'SLEEP_MASTERUPGRADED', N'SLEEP_MSDBSTARTUP', N'SLEEP_SYSTEMTASK', N'SLEEP_TASK',
        N'SLEEP_TEMPDBSTARTUP', N'SNI_HTTP_ACCEPT', N'SP_SERVER_DIAGNOSTICS_SLEEP',
		N'SQLTRACE_BUFFER_FLUSH', N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP', N'SQLTRACE_WAIT_ENTRIES',
		N'WAIT_FOR_RESULTS', N'WAITFOR', N'WAITFOR_TASKSHUTDOWN', N'WAIT_XTP_HOST_WAIT',
		N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG', N'WAIT_XTP_CKPT_CLOSE', N'XE_DISPATCHER_JOIN',
        N'XE_DISPATCHER_WAIT', N'XE_TIMER_EVENT')
	)
select
	MAX(W1.Wait_type)														AS [Wait Type]
	,CAST(MAX(W1.[Wait (sec)]) as decimal(16,2))							AS [Wait (sec)]
	,CAST(MAX(W1.[Resource (sec)]) as decimal(16, 2))						AS [Resource (sec)]
	,CAST(MAX(W1.[Signal (sec)]) as decimal(16,2))							AS [Signal (sec)]
	,MAX(W1.WaitCount)														AS [Wait Count]
	,CAST(MAX(W1.Percentage) AS decimal(5,2))								AS [Wait Percentage]
	,CAST((MAX(W1.[Wait (sec)]) / MAX(W1.WaitCount)) as decimal(16,4))		AS [Avg Wait (sec)]
	,CAST((MAX(W1.[Resource (sec)]) / MAX(W1.WaitCount)) as decimal(16,4))	AS [Avg Resource (sec)]
	,CAST((MAX(W1.[Signal (sec)]) / MAX(W1.WaitCount)) as decimal(16,4))	AS [Avg Signal (sec)]
from [Waits] W1
	join [Waits] W2 on W2.RowNum <= W1.RowNum
group by W1.RowNum
having sum(W2.Percentage) - MAX(W1.Percentage) < 99
go

--Get average task counts 
select 
	avg(current_tasks_count)		AS [Avg Task Count]
	,avg(runnable_tasks_count)		AS [Avg Runnable Task Count]
	,avg(pending_disk_io_count)		AS [Avg Pending DiskIO Count]
from sys.dm_os_schedulers with (nolock)
where scheduler_id < 255
option (recompile)


--page life expectency (PLE) value for each NUMA node
select 
	@@SERVERNAME		AS [Server Name]
	,object_name		AS [Object Name]
	,instance_name		AS [Instance Name]
	,cntr_value			AS [Page Life Expectancy]
from sys.dm_os_performance_counters with (nolock)
where object_name like '%Buffer Node%'
	and counter_name = N'Page life expectancy'
option (recompile);

--I/O Statistics by file for current database 
select 
	DB_Name(db_id())																							AS [Database Name]
	,df.name																									AS [Logical Name]
	,vfs.file_id																								AS [File ID]
	,df.physical_name																							AS [Physical Name]
	,vfs.num_of_reads																							AS [Num of Reads]
	,vfs.num_of_writes																							AS [Num of Writes]
	,vfs.io_stall_read_ms																						AS [IO Read Stall (ms)]
	,vfs.io_stall_write_ms																						AS [IO Write Stall (ms)]
	,cast(100. * vfs.io_stall_read_ms/(vfs.io_stall_read_ms + vfs.io_stall_write_ms) as decimal(10,1))			AS [IO Read Stall (Pct)]
	,cast(100. * vfs.io_stall_write_ms/(vfs.io_stall_read_ms + vfs.io_stall_write_ms) as decimal(10,1))			AS [IO Write Stall (Pct)]
	,vfs.num_of_reads + vfs.num_of_writes																		AS [Writes + Reads]
	,cast(vfs.num_of_bytes_read/1048576.0 as decimal(10,2))														AS [MB Read]
	,cast(vfs.num_of_bytes_written/1048576.0 as decimal(10,2))													AS [MB Written]
	,cast(100. * vfs.num_of_reads/(vfs.num_of_reads + vfs.num_of_writes) as decimal(10,1))						AS [# Reads (Pct)]
	,cast(100. * vfs.num_of_writes/(vfs.num_of_writes + vfs.num_of_reads) as decimal(10,1))						AS [# Writes (Pct)]
	,cast(100. * vfs.num_of_bytes_read/(vfs.num_of_bytes_read + vfs.num_of_bytes_written) as decimal(10,1))		AS [Read Bytes (Pct)]
	,cast(100. * vfs.num_of_bytes_written/(vfs.num_of_bytes_read + vfs.num_of_bytes_written) as decimal(10,1))	AS [Write Bytes (Pct)]
from sys.dm_io_virtual_file_stats(DB_ID(),NULL) as vfs
	join sys.database_files df with (nolock)
		on vfs.file_id = df.file_id