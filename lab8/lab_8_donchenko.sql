use [SMART_HOME]

drop table if exists[DEVICE]
drop table if exists [ACCOUNT]
go

create table ACCOUNT
(
    [account_id] int identity (1, 1) primary key,
    [email] varchar(100) unique not null,
    [create_date] date default GETDATE()
    constraint ACCOUNT_AK1 unique (email)
)

create table DEVICE
(
    [device_id] int identity (1, 1) primary key,
    [chip_id] varchar(16) not null check (upper(chip_id) = chip_id), -- только в верхнем регистре
    [device_name] varchar(20) default 'Device',
    [device_type] tinyint not null check (device_type in (1, 2, 3)), -- 1 - умная колонка, 2 - умный свет, 3 - контроллер воздуха
    [powered_by] bit default 0, -- 0 - только от сети, 1 - с батареей
    [account_id] int not null
    constraint DEVICE_AK1 unique (chip_id)
    constraint FK_DEVICE_ACCOUNT foreign key (account_id) references ACCOUNT(account_id)
)
go

insert into [ACCOUNT] (email)
values ('jack@gmail.com'),
       ('garry@gmail.com'),
       ('patrick@mail.ru')
go

insert into [DEVICE] (chip_id, device_name, device_type, powered_by, account_id)
values ('AJDKJKAJ', 'first device', 1, 0, 1),
       ('NDJNLDS', 'second device', 2, 1, 3),
       ('NDJNJDNDKL', 'third device', 3, 1, 2)
go

insert into [DEVICE] (chip_id, device_type, account_id)
values ('NLDDLMXDNKL', 1, 2),
       ('NKNNNKLNKLN', 2, 2),
       ('OAPPSJAOP', 3, 3)
go

select * from [ACCOUNT]
select * from [DEVICE]
go

-- 1) Создать хранимую процедуру, производящую выборку из некоторой таблицы и возвращающую результат выборки в виде курсора

drop procedure if exists dbo.getDevicesBy
go

create procedure dbo.getDevicesBy
    @type tinyint,
    @powered_by bit,
    @curCursor cursor varying output
as 
    set @curCursor = cursor 
    forward_only static for
    select [chip_id], [device_name] from [DEVICE]
    where [device_type] = @type and [powered_by] = @powered_by

open @curCursor
GO

declare @myCursor CURSOR
exec dbo.getDevicesBy @type = 1, @powered_by = 0, @curCursor = @myCursor OUTPUT

declare @name varchar(100), @chip varchar(100)

fetch next from @myCursor into @name, @chip
while (@@fetch_status = 0) 
begin
    print @name + ' ' + @chip
    fetch next from @myCursor into @name, @chip
end

close @myCursor
deallocate @myCursor
GO

-- 2) Модифицировать хранимую процедуру п.1. таким образом, чтобы выборка осуществлялась с формированием столбца, 
-- значение которого формируется пользовательской функцией

drop function if exists dbo.getCountOfDevices
drop procedure if exists dbo.getAllDevicesCount
GO

create function dbo.getCountOfDevices (@email varchar(100))
returns int 
as 
begin 
    declare @count int
    select @count = COUNT(*) from [DEVICE] d 
    where d.[account_id] = (select a.account_id from [ACCOUNT] a where a.[email] = @email)
return @count
end 
go

create procedure dbo.getAllDevicesCount
    @curCursor cursor varying output
as
    set @curCursor = cursor
    forward_only static for
    select [email], dbo.getCountOfDevices(email) as devicesCount from [ACCOUNT]

open @curCursor
GO

declare @myCursor CURSOR
exec dbo.getAllDevicesCount @curCursor = @myCursor OUTPUT

declare @email varchar(100), @count int

fetch next from @myCursor into @email, @count
while (@@fetch_status = 0) 
begin
    print @email + ' ' + cast(@count as varchar)
    fetch next from @myCursor into @email, @count
end

close @myCursor
deallocate @myCursor
GO

-- 3) Создать хранимую процедуру, вызывающую процедуру п.1., осуществляющую прокрутку возвращаемого курсора и выводящую сообщения, 
-- сформированные из записей при выполнении условия, заданного еще одной пользовательской функцией

drop function if exists dbo.isDeviceNamed
drop procedure if exists dbo.getNamedDevicesBy
go

create function dbo.isDeviceNamed (@deviceName varchar(100))
returns bit
as 
begin
    declare @isNamed bit
    if @deviceName = 'Device'
        set @isNamed = 0
    else
        set @isNamed = 1

return @isNamed
end 
go

create procedure dbo.getNamedDevicesBy
    @type tinyint,
    @powered_by bit
as 
    declare @localCursor CURSOR
    exec dbo.getDevicesBy @type = @type, @powered_by = @powered_by, @curCursor = @localCursor OUTPUT

    declare @deviceChip varchar(100), @deviceName varchar(100)

    fetch next from @localCursor into @deviceChip, @deviceName
    while (@@fetch_status = 0) 
    begin
        if dbo.isDeviceNamed(@deviceName) = 1
        begin
            print 'device with chip ' + @deviceChip + ' is named'
        end
        fetch next from @localCursor into @deviceChip, @deviceName
    end

    close @localCursor
    deallocate @localCursor
GO

exec dbo.getNamedDevicesBy @type = 1, @powered_by = 0


-- 4) Модифицировать хранимую процедуру п.2. таким образом, чтобы выборка формировалась с помощью табличной функции

drop procedure if exists dbo.getAllDevicesCount
drop function if exists dbo.getCountOfDevicesByAccount
GO

create function dbo.getCountOfDevicesByAccount()
returns table
as 
return (
    select [account_id], [email], dbo.getCountOfDevices(email) as devicesCount 
    from [ACCOUNT]
)
GO

create procedure dbo.getAllDevicesCount
    @curCursor cursor varying output
as
    set @curCursor = cursor
    forward_only static for
    select * from dbo.getCountOfDevicesByAccount() 
    order by devicesCount

open @curCursor
GO

declare @myCursor CURSOR
exec dbo.getAllDevicesCount @curCursor = @myCursor OUTPUT

declare @accountID int, @email varchar(100), @count int

fetch next from @myCursor into @accountID, @email, @count
while (@@fetch_status = 0) 
begin
    print @email + ' ' + cast(@count as varchar)
    fetch next from @myCursor into @accountID, @email, @count
end

close @myCursor
deallocate @myCursor
GO

--------------------------------------------------------

drop function if exists dbo.getCountOfDevicesByAccount
GO

create function dbo.getCountOfDevicesByAccount()
returns @countOfDevicesByAccount table
(
    [account_id] int not null primary key,
    [email] varchar(100) unique not null,
    [devicesCount] int not null
)
as 
begin 
    insert @countOfDevicesByAccount
    select [account_id], [email], dbo.getCountOfDevices(email) as devicesCount 
    from [ACCOUNT] 
return
end 
GO

declare @myCursor CURSOR
exec dbo.getAllDevicesCount @curCursor = @myCursor OUTPUT

declare @accountID int, @email varchar(100), @count int

fetch next from @myCursor into @accountID, @email, @count
while (@@fetch_status = 0) 
begin
    print @email + ' ' + cast(@count as varchar)
    fetch next from @myCursor into @accountID, @email, @count
end

close @myCursor
deallocate @myCursor
GO