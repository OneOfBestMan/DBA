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