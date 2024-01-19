use SMART_HOME
go

delete from DEVICE
DBCC CHECKIDENT(DEVICE, RESEED, 0)
go

delete from ACCOUNT
DBCC CHECKIDENT(ACCOUNT, RESEED, 0)
go

insert into [ACCOUNT] (email, users_count_limit)
values ('boss@gmail.com', 255),
       ('viking@gmail.com', 10),
       ('seniorpomidor@mail.ru', 10),
       ('lovelas@yandex.ru', 5)
go

insert into [DEVICE] (chip_id, account_id, device_name, device_type, powered_by)
values ('AJDKJKAJ', 1, 'first device', 1, 0),
       ('NDJNLDS', 2, 'second device', 2, 1),
       ('NDJNJDNDKL', 3, 'third device', 3, 1)
go

insert into [DEVICE] (chip_id, account_id, device_type)
values ('NLDDLMXDNKL', 2, 1),
       ('NKNNNKLNKLN', 4, 2),
       ('OAPPSJAOP', 4, 3)
go

select * from DEVICE
go

-- 1) Создадим представление на основе таблицы DEVICE

if exists (select 1 from INFORMATION_SCHEMA.VIEWS where TABLE_NAME = 'DEVICE_COUNT_BY_TYPE')
begin
    drop view DEVICE_COUNT_BY_TYPE
end
go

create view DEVICE_COUNT_BY_TYPE as
select D.device_type as [type], COUNT(D.device_name) as count
from DEVICE D
group by D.device_type
with check option
go

select * from DEVICE_COUNT_BY_TYPE
go

-- 2) Создадим представление на основе таблиц ACCOUNT, DEVICE

if exists (select 1 from INFORMATION_SCHEMA.VIEWS where TABLE_NAME = 'ACCOUNT_DEVICES')
begin
    drop view ACCOUNT_DEVICES
end
go

create view ACCOUNT_DEVICES as
select A.email, D.device_name, D.device_type
from ACCOUNT A
join DEVICE D on D.account_id = A.account_id
with check option
go

select * from ACCOUNT_DEVICES
go

-- 3) Создадим индекс для таблицы DEVICE, включив в него дополнительные неключевые поля

if exists (select 1 from sys.indexes where name = 'DEVICE_PARAMETERS' and object_id = OBJECT_ID('DEVICE'))
begin
    drop index DEVICE_PARAMETERS on [DEVICE]
end
go

create index DEVICE_PARAMETERS
on DEVICE (device_name)
include (device_type, powered_by)
go

select device_type, powered_by from DEVICE D
where device_name = 'Device'
go

-- 4) Создадим индексированное представление

if exists (select 1 from INFORMATION_SCHEMA.VIEWS where TABLE_NAME = 'ACCOUNT_LIMIT')
begin
    drop view ACCOUNT_LIMIT
end
go

create view ACCOUNT_LIMIT with SCHEMABINDING as
select A.email, A.users_count_limit
from dbo.ACCOUNT A
with check option
go

create unique clustered index ACCOUNT_INDEX
on ACCOUNT_LIMIT(email)
select * from ACCOUNT_LIMIT
go

create unique nonclustered index ACCOUNT_nonINDEX
on ACCOUNT_LIMIT(email)
select * from ACCOUNT_LIMIT
go



