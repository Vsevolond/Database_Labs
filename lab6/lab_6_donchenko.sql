use [SMART_HOME]
go

if exists (select 1 from INFORMATION_SCHEMA.TABLES where TABLE_NAME = 'DEVICE')
begin
    drop table [DEVICE]
end

-- 1) Создаем таблицу DEVICE с использованием CHECK, DEFAULT
create table DEVICE
(
    [device_id] int not null identity (1, 1) primary key,
    [chip_id] varchar(16) not null check (upper(chip_id) = chip_id), -- только в верхнем регистре
    [device_name] varchar(20) default 'Device',
    [device_type] tinyint not null check (device_type in (1, 2, 3)), -- 1 - умная колонка, 2 - умный свет, 3 - контроллер воздуха
    [powered_by] bit default 0, -- 0 - только от сети, 1 - с батареей
    constraint DEVICE_AK1 unique (chip_id)
)

-- 2) Добавим данные, указывая все атрибуты
insert into [DEVICE] (chip_id, device_name, device_type, powered_by)
values ('AJDKJKAJ', 'first device', 1, 0),
       ('NDJNLDS', 'second device', 2, 1),
       ('NDJNJDNDKL', 'third device', 3, 1)
go

-- Добавим данные со значениями по умолчанию (device_name, powered_by)
insert into [DEVICE] (chip_id, device_type)
values ('NLDDLMXDNKL', 1),
       ('NKNNNKLNKLN', 2),
       ('OAPPSJAOP', 3)
go

select * from [DEVICE]
go

-- Способы получения последнего сгенерированного значения
select SCOPE_IDENTITY() as ID_1
select @@IDENTITY as ID_2
select IDENT_CURRENT('DEVICE') as ID_3

-- 3) Создадим таблицу с первичным ключом на основе глобального уникального идентификатора

drop table [DEVICE]
go

create table DEVICE
(
    [device_id] UNIQUEIDENTIFIER primary key default NEWID(),
    [chip_id] varchar(16) not null check (upper(chip_id) = chip_id),
    [device_name] varchar(20) default 'Device',
    [device_type] tinyint not null check (device_type in (1, 2, 3)),
    [powered_by] bit default 0,
    constraint DEVICE_AK1 unique (chip_id)
)

insert into [DEVICE] (chip_id, device_name, device_type, powered_by)
values ('AJDKJKAJ', 'first device', 1, 0),
       ('NDJNLDS', 'second device', 2, 1),
       ('NDJNJDNDKL', 'third device', 3, 1)
go

insert into [DEVICE] (chip_id, device_type)
values ('NLDDLMXDNKL', 1),
       ('NKNNNKLNKLN', 2),
       ('OAPPSJAOP', 3)
go

select * from [DEVICE]
go

-- 4) Создадим таблицу с первичным ключом на основе последовательности

drop table [DEVICE]
drop sequence [Devices]
go

if not exists (select 1 from sys.sequences where name = 'Devices')
begin
    create sequence Devices
    as int
    start with 1
    increment by 1
end

create table DEVICE
(
    [device_id] int primary key default next value for Devices,
    [chip_id] varchar(16) not null check (upper(chip_id) = chip_id),
    [device_name] varchar(20) default 'Device',
    [device_type] tinyint not null check (device_type in (1, 2, 3)),
    [powered_by] bit default 0,
    constraint DEVICE_AK1 unique (chip_id)
)

insert into [DEVICE] (chip_id, device_name, device_type, powered_by)
values ('AJDKJKAJ', 'first device', 1, 0),
       ('NDJNLDS', 'second device', 2, 1),
       ('NDJNJDNDKL', 'third device', 3, 1)
go

insert into [DEVICE] (chip_id, device_type)
values ('NLDDLMXDNKL', 1),
       ('NKNNNKLNKLN', 2),
       ('OAPPSJAOP', 3)
go

select * from [DEVICE]
go

-- 5) Создадим две связанные таблицы, и протестируем на них различные варианты действий для ограничений ссылочной целостности

if not exists (select 1 from INFORMATION_SCHEMA.TABLES where TABLE_NAME = 'ACCOUNT')
begin
    create table ACCOUNT
    (
        [account_id] int identity (1, 1) primary key,
        [email] varchar(100) unique not null,
        [users_count_limit] tinyint default 5,
        [create_date] date default GETDATE(),
        constraint ACCOUNT_AK1 unique (email)
    )
end

delete from [ACCOUNT]
DBCC CHECKIDENT(ACCOUNT, RESEED, 0)
go

insert into [ACCOUNT] (email)
values ('boss@gmail.com'),
       ('viking@gmail.com'),
       ('seniorpomidor@mail.ru'),
       ('lovelas@yandex.ru')
go

drop table [DEVICE]
go

-- NO ACTION
create table DEVICE
(
    [device_id] int not null identity (1, 1) primary key,
    [chip_id] varchar(16) not null check (upper(chip_id) = chip_id),
    [account_id] int default 1,
    [device_name] varchar(20) default 'Device',
    [device_type] tinyint not null check (device_type in (1, 2, 3)),
    [powered_by] bit default 0,
    constraint DEVICE_AK1 unique (chip_id),
    constraint FK_DEVICE_ACCOUNT foreign key (account_id) references ACCOUNT(account_id) on delete NO ACTION on update NO ACTION
)

insert into [DEVICE] (chip_id, account_id, device_name, device_type, powered_by)
values ('AJDKJKAJ', 2, 'first device', 1, 0),
       ('NDJNLDS', 2, 'second device', 2, 1),
       ('NDJNJDNDKL', 3, 'third device', 3, 1)
go

insert into [DEVICE] (chip_id, account_id, device_type)
values ('NLDDLMXDNKL', 3, 1),
       ('NKNNNKLNKLN', 4, 2),
       ('OAPPSJAOP', 4, 3)
go

select * from ACCOUNT
select * from DEVICE
go

delete from ACCOUNT where account_id = 4
go

select * from ACCOUNT
select * from DEVICE
go

-- Меняем на CASCADE
alter table [DEVICE]
drop constraint FK_DEVICE_ACCOUNT

alter table [DEVICE]
add constraint FK_DEVICE_ACCOUNT foreign key (account_id) references ACCOUNT(account_id) on delete CASCADE on update CASCADE
go

delete from ACCOUNT where account_id = 3
go

select * from ACCOUNT
select * from DEVICE
go

-- Меняем на SET NULL
alter table [DEVICE]
drop constraint FK_DEVICE_ACCOUNT

alter table [DEVICE]
add constraint FK_DEVICE_ACCOUNT foreign key (account_id) references ACCOUNT(account_id) on delete SET NULL on update SET NULL
go

delete from ACCOUNT where account_id = 4
go

select * from ACCOUNT
select * from DEVICE
go

-- Меняем на SET DEFAULT
alter table [DEVICE]
drop constraint FK_DEVICE_ACCOUNT

alter table [DEVICE]
add constraint FK_DEVICE_ACCOUNT foreign key (account_id) references ACCOUNT(account_id) on delete SET DEFAULT on update SET DEFAULT
go

delete from ACCOUNT where account_id = 2
go

select * from ACCOUNT
select * from DEVICE
go