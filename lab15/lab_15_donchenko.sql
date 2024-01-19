use [master]
go

drop database if exists [DEVICES]
drop database if exists [ACCOUNTS]
GO

create database ACCOUNTS
create database DEVICES
GO

-- 1) Создать в базах данных связанные таблицы

use [ACCOUNTS]
drop table if exists [ACCOUNT]
GO

create table ACCOUNT
(
    [account_id] int identity(1, 1) primary key,
    [email] varchar(100) unique not null,
    [devices_limit] tinyint default 5,
    constraint ACCOUNT_AK1 unique (email)
)
go

use [DEVICES]
drop table if exists [DEVICE]
GO

create table DEVICE
(
    [device_id] int identity(1, 1) primary key,
    [device_name] varchar(20) default 'Device',
    [chip_id] varchar(16) not null check (upper(chip_id) = chip_id), -- только в верхнем регистре
    [device_type] tinyint not null check (device_type in (1, 2, 3)), -- 1 - умная колонка, 2 - умный свет, 3 - контроллер воздуха
    [account_id] int not null,
    constraint DEVICE_AK1 unique (chip_id)
)
GO

-- 2) Создать необходимые элементы базы данных (представления, триггеры), обеспечивающие работу 
-- с данными связанных таблиц (выборку, вставку, изменение, удаление)

use [ACCOUNTS]
go

create trigger OnUpdateAccount
on [ACCOUNT]
instead of update 
as BEGIN
    if update(account_id) or update(email)
        RAISERROR('Id или почта аккаунта не может быть изменена', 11, 1)
    else
        update [ACCOUNT]
        set [devices_limit] = I.[devices_limit]
        from [ACCOUNT] A 
        inner join inserted I on A.[account_id] = I.[account_id]
END
GO

create trigger OnDeleteAccount
on [ACCOUNT]
after delete 
as BEGIN
    delete from DEVICES.dbo.DEVICE
    where [account_id] in (select D.[account_id] from deleted D)
END
GO

------------------------------------------------------------------

use [DEVICES]
GO

create trigger OnInsertDevice
on [DEVICE]
instead of insert 
as BEGIN
    declare @inserted_cursor cursor 
    set @inserted_cursor = cursor 
    forward_only static for
    select * from inserted

    open @inserted_cursor

    declare @deviceName varchar(20), @chipID varchar(16), @deviceType tinyint, @accountID int

    fetch next from @inserted_cursor into @deviceName, @chipID, @deviceType, @accountID

    while (@@FETCH_STATUS = 0) 
    BEGIN
        if @accountID in (select [account_id] from ACCOUNTS.dbo.ACCOUNT)
            insert into [DEVICE] ([device_name], [chip_id], [device_type], [account_id])
            values (@deviceName, @chipID, @deviceType, @accountID)
        else 
            RAISERROR('Не существует такого аккаунта', 11, 1)

        fetch next from @inserted_cursor into @deviceName, @chipID, @deviceType, @accountID
    END
END
GO

create trigger OnUpdateDevice
on [DEVICE]
instead of update 
as BEGIN
    if update(device_id) or update(chip_id) or update(device_type) or update(account_id)
        RAISERROR('Параметры и id устройства не могут меняться', 11, 1)
    else 
        update [DEVICE]
        set [device_name] = I.[device_name]
        from [DEVICE] D 
        inner join inserted I on D.[chip_id] = I.[chip_id]
end
GO

------------------------------------------------------------------

use [SMART_HOME]
drop view if exists [DEVICE_ACCOUNT_VIEW]
GO

create view DEVICE_ACCOUNT_VIEW
as
select A.[email], D.[device_name], D.[chip_id], D.[device_type]
from ACCOUNTS.dbo.ACCOUNT A 
join DEVICES.dbo.DEVICE D 
on A.[account_id] = D.[account_id]
go

create trigger OnInsert
on [DEVICE_ACCOUNT_VIEW]
instead of insert 
as begin 
    declare @inserted_cursor cursor 
    set @inserted_cursor = cursor 
    forward_only static for
    select * from inserted

    open @inserted_cursor

    declare @email varchar(100), @deviceName varchar(20), @chipID varchar(16), @deviceType tinyint

    fetch next from @inserted_cursor into @email, @deviceName, @chipID, @deviceType

    while (@@FETCH_STATUS = 0)
    begin 
        declare @accountID int
        if @email in (select [email] from ACCOUNTS.dbo.ACCOUNT) -- если аккаунт существует
            begin 
            declare @devicesLimit tinyint
            select @devicesLimit = A.[devices_limit], @accountID = A.[account_id] -- получаем limit устройств и id аккаунта
            from ACCOUNTS.dbo.ACCOUNT A where A.[email] = @email 

            declare @devicesCount tinyint 
            select @devicesCount = count(*) from DEVICES.dbo.DEVICE D where D.[account_id] = @accountID -- текущее количество устройств

            if @devicesCount < @devicesLimit -- можно добавить еще устройство
                insert into DEVICES.dbo.DEVICE ([device_name], [chip_id], [device_type], [account_id])
                values (@deviceName, @chipID, @deviceType, @accountID)
            else 
                begin -- нельзя добавить устройство
                declare @errorMessage nvarchar(200)
                set @errorMessage = N'В аккаунт ' + @email + N' больше нельзя добавить устройства'
                RAISERROR(@errorMessage, 11, 1)
                end
            end
        else -- аккаунт не существует
            begin 
            insert into ACCOUNTS.dbo.ACCOUNT ([email]) -- добавляем аккаунт
            values (@email)

            select @accountID = A.[account_id] from ACCOUNTS.dbo.ACCOUNT A where A.[email] = @email -- получаем его id

            insert into DEVICES.dbo.DEVICE ([device_name], [chip_id], [device_type], [account_id])
            values (@deviceName, @chipID, @deviceType, @accountID)
            end
    
    fetch next from @inserted_cursor into @email, @deviceName, @chipID, @deviceType
    end

    close @inserted_cursor
    deallocate @inserted_cursor
end 
go

create trigger OnUpdate
on [DEVICE_ACCOUNT_VIEW]
instead of update 
as begin 
    if UPDATE(email)
        RAISERROR('Устройство не может быть перемещено в другой аккаунт', 11, 2)
    else if UPDATE(chip_id) or UPDATE(device_type)
        RAISERROR('Нельзя менять параметры устройства', 11, 3)
    else 
        update DEVICES.dbo.DEVICE
        set [device_name] = I.[device_name]
        from DEVICES.dbo.DEVICE D 
        inner join inserted I on D.[chip_id] = I.[chip_id]
end 
GO

create trigger OnDelete
on [DEVICE_ACCOUNT_VIEW]
instead of delete 
as begin 
    delete from DEVICES.dbo.DEVICE
    where [chip_id] in (select [chip_id] from deleted)
end 
go 


insert into [DEVICE_ACCOUNT_VIEW] ([email], [device_name], [chip_id], [device_type])
values ('jack@gmail.com', 'some device', 'NDNKNSKNKS', 1),
       ('jack@gmail.com', 'favourite device', 'MLSMLSLS', 2),
       ('jack@gmail.com', 'new device', 'GSHUSUHUSH', 3),
       ('garry@gmail.com', 'alice', 'KSOSOSKOS', 1),
       ('patrick@gmail.com', 'cool device', 'LSOKSHBSH', 2),
       ('garry@gmail.com', 'device 2', 'SSNSJNSJ', 3),
       ('patrick@gmail.com', 'my device', 'JISNJSJN', 3),
       ('robert@gmail.com', 'first device', 'KPSSHBHJJS', 2)
GO

select * from [DEVICE_ACCOUNT_VIEW]
select * from ACCOUNTS.dbo.ACCOUNT 
select * from DEVICES.dbo.DEVICE
go

insert into [DEVICE_ACCOUNT_VIEW] ([email], [device_name], [chip_id], [device_type])
values ('jack@gmail.com', 'device 4', 'LSJNSKKS', 1),
       ('jack@gmail.com', 'device 5', 'JIWNKSNKS', 1),
       ('jack@gmail.com', 'device 6', 'EWJSNKS', 1)
GO

select * from [DEVICE_ACCOUNT_VIEW]
select * from DEVICES.dbo.DEVICE
go

update [DEVICE_ACCOUNT_VIEW]
set [email] = 'garry@gmail.com'
where [device_name] = 'first device'
go

update [DEVICE_ACCOUNT_VIEW]
set [device_type] = 1
where [email] = 'robert@gmail.com'
go

update [DEVICE_ACCOUNT_VIEW]
set [device_name] = 'alice'
where [device_type] = 1
go

select * from [DEVICE_ACCOUNT_VIEW]
select * from DEVICES.dbo.DEVICE
go

delete from [DEVICE_ACCOUNT_VIEW]
where [device_name] = 'alice'
go

select * from [DEVICE_ACCOUNT_VIEW]
select * from DEVICES.dbo.DEVICE
go