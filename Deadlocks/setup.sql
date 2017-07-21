use master
go

if db_id(N'DeadlockDemo') is not null
begin
	alter database [DeadlockDemo] set single_user with rollback immediate;
	drop database [DeadlockDemo];
end
go

create database [DeadlockDemo]
go

use [DeadlockDemo]
go

set nocount on
go

create table A (
	c1 int,
	c2 int,
	c3 int,
	c4 char(100) default 'abc' 
);
go

declare @i int = 1
while (@i <= 1000)
begin
	insert A values (@i, @i*2, @i*3, char(@i % 256))
	set @i += 1
end
go

create clustered index CI_A_c1 on A(c1)
go

delete A where c1 in (100,101)
go

create table B (
	c1 int identity primary key,
	c2 char(100) default 'abc'
);
go

insert B default values
go

create nonclustered index NC_A_c2 on A(c2)
go

create procedure BookmarkLookupSelect (
	@col2 int) 
AS 
begin
	declare @out1 int, @out2 int

	select @out1 = c2, @out2 = c3
	from A 
	where c2 between @col2 AND @col2 + 1 
end
go

create procedure BookmarkLookupUpdate (
	@col1 int)
AS
begin
	update A
	set c2 = c2 + 1
	where c1 = @col1

	update A
	set c2 = c2 - 1
	where c1 = @col1
end
go

alter database DeadlockDemo set single_user with rollback immediate
alter database DeadlockDemo set allow_snapshot_isolation on
--alter database DeadlockDemo set read_committed_snapshot on
alter database DeadlockDemo set multi_user
go