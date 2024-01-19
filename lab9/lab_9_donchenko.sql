use [SMART_HOME]
go

drop table if exists [DEVICE]
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

select * from [ACCOUNT]
go

-- 1)  Для одной из таблиц создать триггеры на вставку, удаление и добавление, 
-- при выполнении заданных условий один из триггеров должен инициировать возникновение ошибки (RAISERROR / THROW)

create trigger RenameDevice -- вставка
on [DEVICE]
after insert 
as 
    update [DEVICE]
    set [device_name] = 'Device ' + cast(DEVICE.device_id as varchar(10))
    from inserted
    where DEVICE.device_id = inserted.[device_id] and inserted.[device_name] = 'Device'
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

select * from [DEVICE]
GO

create trigger NotifyDeleteDevice -- удаление
on [DEVICE]
after delete 
as
begin
    declare @deviceName varchar(20)
    declare @inserted_cursor cursor

    set @inserted_cursor = cursor
    forward_only static for
    select [device_name] from deleted

    open @inserted_cursor

    fetch next from @inserted_cursor into @deviceName

    while (@@FETCH_STATUS = 0)
    begin 
        print N'Было удалено устройство с именем ' + @deviceName
        fetch next from @inserted_cursor into @deviceName
    end

    close @inserted_cursor
    deallocate @inserted_cursor
end
go

delete from [DEVICE] where [device_type] = 2
GO

select * from [DEVICE]
go

create trigger AlertWhenUpdateDevice -- изменение
on [DEVICE]
after update 
as
begin 
    if update(chip_id) or update(device_type) or update(powered_by)
    begin
        RAISERROR('Нельзя изменять параметры устройства', 11, 1)
        ROLLBACK TRANSACTION
    end
end
go

update [DEVICE] 
set [device_name] = 'my device' 
where [device_type] = 1

select * from [DEVICE]
go

update [DEVICE]
set [powered_by] = 1
where [device_type] = 1

select * from [DEVICE]
go

-- 2)  Для представления создать триггеры на вставку, удаление и добавление,
-- обеспечивающие возможность выполнения операций с данными непосредственно через представление

drop view if exists [ACCOUNT_DEVICES]
GO

create view ACCOUNT_DEVICES as
select A.email, D.chip_id, D.device_name, D.device_type, D.powered_by
from ACCOUNT A
join DEVICE D on D.account_id = A.account_id
go

select * from ACCOUNT_DEVICES
go

----------------------------------------------------------------------------------------

create trigger InsertAccountDevices -- вставка
on [ACCOUNT_DEVICES]
instead of insert 
as 
begin 
    insert into [ACCOUNT] ([email])
    select distinct [email] from inserted I
    where I.[email] not in (select A.[email] from [ACCOUNT] A)

    insert into [DEVICE] (chip_id, device_name, device_type, powered_by, account_id)
    select [chip_id], [device_name], [device_type], [powered_by], A.account_id
    from inserted I
    inner join ACCOUNT A on A.email = I.email
end 
go

insert into [ACCOUNT_DEVICES] (email, chip_id, device_name, device_type, powered_by)
values ('garry@gmail.com', 'BJSNJNSJNS', 'new device', 2, 0),
       ('jack@gmail.com', 'KSLJSIMN', 'new device', 1, 1),
       ('robert@gmail.com', 'LSSMSMKN', 'new device', 2, 1),
       ('kevin@gmail.com', 'AHSJSNJNBS', 'new device', 3, 0),
        ('kevin@gmail.com', 'GHDFGHFGHD', 'old device', 3, 1)
go

select * from [ACCOUNT]
select * from [DEVICE]
select * from [ACCOUNT_DEVICES]
go

----------------------------------------------------------------------------------------

create trigger DeleteAccountDevices -- удаление
on [ACCOUNT_DEVICES]
instead of delete 
as 
begin 
    delete from [DEVICE]
    where [chip_id] in (select [chip_id] from deleted)
end 
go

delete from [ACCOUNT_DEVICES]
where [email] = 'garry@gmail.com'
go

select * from [DEVICE]
select * from [ACCOUNT_DEVICES]
go

----------------------------------------------------------------------------------------

create trigger UpdateAccountDevices -- изменение
on [ACCOUNT_DEVICES]
instead of update 
as 
begin 
    if update(email)
        RAISERROR('Нельзя переместить устройство в другой аккаунт', 11, 1)
    else if update(chip_id) or update(device_type) or update(powered_by)
        RAISERROR('Параметры устройства не могут меняться', 11, 1)
    else 
        update [DEVICE]
        set [device_name] = I.device_name
        from DEVICE D
        inner join inserted I on D.chip_id = I.chip_id
end 
GO

update [ACCOUNT_DEVICES]
set [device_name] = 'favourite device'
where [email] = 'patrick@mail.ru'
go 

select * from [DEVICE]
select * from [ACCOUNT_DEVICES]
go

update [ACCOUNT_DEVICES]
set [email] = 'robert@gmail.com'
where [device_name] = 'my device'
GO

update [ACCOUNT_DEVICES]
set [powered_by] = 0
where [device_name] = 'new device'
go

select * from [DEVICE]
select * from [ACCOUNT_DEVICES]
go