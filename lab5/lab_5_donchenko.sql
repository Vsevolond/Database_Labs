-- 1) Создаем базу данных

if DB_ID('SMART_HOME') is null
begin
    create database SMART_HOME
    on primary
    (
        name = 'SMART_HOME',
        filename = '/Users/vsevolond/university/DB_2016/lab5/SmartHomeData_df.mdf',
        size = 10MB,
        maxsize = 100MB,
        filegrowth = 10MB
    )
end
go

-- 2) Создаем таблицу клиента

use [SMART_HOME]

if not exists (select 1 from INFORMATION_SCHEMA.TABLES where TABLE_NAME = 'CLIENT')
begin
    create table CLIENT
    (
        [client_id] int identity (1, 1) primary key,
        [phone_number] varchar(20) not null,
        [name] varchar(20) not null,
        [surname] varchar(20) not null,
        [birth_date] date
        constraint CLIENT_AK1 unique (phone_number)
    )
end
go

-- 3) Создаем файловую группу

alter database [SMART_HOME]
add filegroup SMARTHOME_FILEGROUP
go

-- Создаем файл данных

alter database [SMART_HOME]
add file
(
    name = 'smarthome_data',
    filename = '/Users/vsevolond/university/DB_2016/lab5/smarthome_df.mdf'
)
to filegroup SMARTHOME_FILEGROUP;
go

-- 4) Делаем созданную файловую группу файловой группой по умолчанию
alter database [SMART_HOME]
modify filegroup SMARTHOME_FILEGROUP default
go

-- 5) Создадим еще одну таблицу
if not exists (select 1 from INFORMATION_SCHEMA.TABLES where TABLE_NAME = 'ACCOUNT')
    begin
        create table ACCOUNT
        (
            [account_id] int identity (1, 1) primary key,
            [email] varchar(100) unique not null,
            [users_count_limit] tinyint default 5,
            [last_login_date] date not null,
            [create_date] date default GETDATE(),
            [creator_id] int not null
        )
    end
go

-- Создаем новую таблицу в PRIMARY для переноса данных
create table ACCOUNT_NEW
(
    [account_id] int identity (1, 1) primary key,
    [email] varchar(100) unique not null,
    [users_count_limit] tinyint default 5,
    [last_login_date] date not null,
    [create_date] date default GETDATE(),
    [creator_id] int not null,
    constraint ACCOUNT_AK1 unique (email),
    constraint FK_ACCOUNT_CLIENT foreign key (creator_id) references CLIENT(client_id)
) on [PRIMARY]
go

-- Переносим данные
insert into ACCOUNT_NEW (email, users_count_limit, last_login_date, create_date, creator_id)
select email, users_count_limit, last_login_date, create_date, creator_id from ACCOUNT
go

-- Удаляем таблицу
drop table ACCOUNT
go

-- Меняем название таблицы
exec sp_rename 'ACCOUNT_NEW', 'ACCOUNT'
go

-- Возвращаем дефолтное значение для PRIMARY
alter database [SMART_HOME]
modify filegroup [PRIMARY] default
go

-- Удаляем файл данных
alter database [SMART_HOME]
remove file smarthome_data
go

-- 6) Удаляем пользовательскую файловую группу
alter database [SMART_HOME]
remove filegroup SMARTHOME_FILEGROUP
go

-- 7) Создаем схему
create schema ACCOUNT_SCHEMA
go

-- Перемещаем таблицу в новую схему
alter schema ACCOUNT_SCHEMA
transfer dbo.ACCOUNT
go

-- Перемещаем таблицу в дефолтную схему, чтобы не потерять данные
alter schema dbo
transfer ACCOUNT_SCHEMA.ACCOUNT
go

drop schema ACCOUNT_SCHEMA
go