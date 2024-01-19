use [master]
GO

drop database if exists [DEVICES_INFO]
drop database if exists [DEVICES_PARAMS]
GO

create database DEVICES_INFO
create database DEVICES_PARAMS
GO

-- 1)  Создать в базах данных таблицы, содержащие вертикально фрагментированные данные

use [DEVICES_INFO]
drop table if exists [DEVICE]
go

create table DEVICE
(
    [device_id] int not null primary key,
    [device_name] varchar(20) default 'Device',
    [description] varchar(100) default ''
)
go

use [DEVICES_PARAMS]
drop table if exists [DEVICE]
go 

create table DEVICE
(
    [device_id] int not null primary key,
    [chip_id] varchar(16) not null check (upper(chip_id) = chip_id), -- только в верхнем регистре
    [device_type] tinyint not null check (device_type in (1, 2, 3)), -- 1 - умная колонка, 2 - умный свет, 3 - контроллер воздуха
    [powered_by] bit default 0, -- 0 - только от сети, 1 - с батареей
    constraint DEVICE_AK1 unique (chip_id)
)
GO

-- 2)  Создать необходимые элементы базы данных (представления, триггеры), обеспечивающие работу
-- с данными вертикально фрагментированных таблиц (выборку, вставку, изменение, удаление)

use [SMART_HOME]
drop view if exists [DEVICE_VIEW]
GO

create view DEVICE_VIEW
as 
select I.[device_id], I.[device_name], I.[description], P.[chip_id], P.[device_type], P.[powered_by]
from DEVICES_INFO.dbo.DEVICE I 
join DEVICES_PARAMS.dbo.DEVICE P 
on I.device_id = P.device_id
GO

create trigger InsertDevice
on [DEVICE_VIEW]
instead of insert 
as 
begin 
    insert into DEVICES_INFO.dbo.DEVICE ([device_id], [device_name], [description])
    select [device_id], [device_name], [description] from inserted

    insert into DEVICES_PARAMS.dbo.DEVICE ([device_id], [chip_id], [device_type], [powered_by])
    select [device_id], [chip_id], [device_type], [powered_by] from inserted
end 
go

create trigger UpdateDevice
on [DEVICE_VIEW]
instead of update 
as 
begin 
    if UPDATE(device_id)
        RAISERROR('Device ID can not be changed', 11, 1)

    else if UPDATE(chip_id) or UPDATE(device_type) or UPDATE(powered_by)
        RAISERROR('Device parameters can not be changed', 11, 2)

    else 
        update DEVICES_INFO.dbo.DEVICE
        set [device_name] = I.[device_name], [description] = I.[description]
        from inserted I 
        where DEVICES_INFO.dbo.DEVICE.[device_id] = I.[device_id]
end 
go

create trigger DeleteDevice
on [DEVICE_VIEW]
instead of delete 
as 
begin 
    delete from DEVICES_INFO.dbo.DEVICE where [device_id] in (select [device_id] from deleted)
    delete from DEVICES_PARAMS.dbo.DEVICE where [device_id] in (select [device_id] from deleted)
end 
go 



insert into [DEVICE_VIEW] ([device_id], [device_name], [description], [chip_id], [device_type], [powered_by])
values (1, 'Some device', 'For music', 'JSNJSNJSNJ', 1, 0),
       (2, 'Favourite device', 'For disco', 'LSNNSKMS', 2, 1),
       (3, 'New device', 'The gift', 'KSNNSNJ', 3, 0),
       (4, 'Device 4', '', 'OKSKS', 1, 1),
       (5, 'My device', 'do not touch!', 'LSKSNKNSKN', 3, 1)
GO

select * from [DEVICE_VIEW]
select * from DEVICES_INFO.dbo.DEVICE
select * from DEVICES_PARAMS.dbo.DEVICE 
go

update [DEVICE_VIEW]
set [description] = 'Broken'
where [device_id] % 2 = 0
go

select * from [DEVICE_VIEW]
select * from DEVICES_INFO.dbo.DEVICE
select * from DEVICES_PARAMS.dbo.DEVICE 
go

update [DEVICE_VIEW]
set [powered_by] = 0
where [device_id] = 1
go

delete from [DEVICE_VIEW]
where [description] = 'Broken'
GO

select * from [DEVICE_VIEW]
select * from DEVICES_INFO.dbo.DEVICE
select * from DEVICES_PARAMS.dbo.DEVICE 
go
