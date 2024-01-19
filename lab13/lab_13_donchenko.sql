use [master]
go

-- 1)  Создать две базы данных на одном экземпляре СУБД SQL Server 2012

drop database if exists [SMART_HOME_RUS]
go
drop database if exists [SMART_HOME_ENG]
go

create database SMART_HOME_RUS
create database SMART_HOME_ENG
go


-- 2) Создать в базах данных п.1. горизонтально фрагментированные таблицы

use [SMART_HOME_RUS]
drop table if exists [ACCOUNT]
go

create table ACCOUNT
(
    [account_id] int not null primary key,
    [email] varchar(100) unique not null check ([email] like '%.ru'),
    [users_count_limit] tinyint default 5,
    [create_date] date default GETDATE(),
    constraint ACCOUNT_AK1 unique (email)
)
GO

use [SMART_HOME_ENG]
drop table if exists [ACCOUNT]
GO

create table ACCOUNT
(
    [account_id] int not null primary key,
    [email] varchar(100) unique not null check ([email] like '%.com'),
    [users_count_limit] tinyint default 5,
    [create_date] date default GETDATE(),
    constraint ACCOUNT_AK1 unique (email)
)
go

-- 3)  Создать секционированные представления, обеспечивающие работу с данными таблиц (выборку, вставку, изменение, удаление)

use [SMART_HOME_RUS]
drop view if exists [ACCOUNT_VIEW]
go

create view ACCOUNT_VIEW 
as select * from [ACCOUNT] 
union all select * from SMART_HOME_ENG.dbo.ACCOUNT
go

create trigger INSERT_ACCOUNT
on [ACCOUNT_VIEW]
instead of insert 
as 
begin 
    insert into [ACCOUNT] ([account_id], [email], [users_count_limit], [create_date])
    select * from inserted
    where [email] like '%.ru'

    insert into SMART_HOME_ENG.dbo.ACCOUNT ([account_id], [email], [users_count_limit], [create_date])
    select * from inserted
    where [email] like '%.com'
END
GO

create trigger UPDATE_ACCOUNT
on [ACCOUNT_VIEW]
instead of update
as
begin 
    if update(account_id) or update(email) or update(create_date)
        RAISERROR('Account ID, Email or Creation Date can not be changed', 11, 1)
    else
    begin 
        update [ACCOUNT]
        set [users_count_limit] = I.users_count_limit
        from ACCOUNT A 
        inner join inserted I on A.account_id = I.account_id

        update SMART_HOME_ENG.dbo.ACCOUNT
        set [users_count_limit] = I.users_count_limit
        from SMART_HOME_ENG.dbo.ACCOUNT A 
        inner join inserted I on A.account_id = I.account_id
    end
end 
go

create trigger DELETE_ACCOUNT
on [ACCOUNT_VIEW]
instead of delete 
as 
begin 
    delete from [ACCOUNT]
    where [account_id] in (select [account_id] from deleted)

    delete from SMART_HOME_ENG.dbo.ACCOUNT
    where [account_id] in (select [account_id] from deleted)
end 
go 

-------------------------------------------------------------------------------------------------------

use [SMART_HOME_ENG]
drop view if exists [ACCOUNT_VIEW]
go

create view ACCOUNT_VIEW
as select * from [ACCOUNT] 
union all select * from SMART_HOME_RUS.dbo.ACCOUNT
go

create trigger INSERT_ACCOUNT
on [ACCOUNT_VIEW]
instead of insert 
as 
begin 
    insert into [ACCOUNT] ([account_id], [email], [users_count_limit], [create_date])
    select * from inserted
    where [email] like '%.com'

    insert into SMART_HOME_RUS.dbo.ACCOUNT ([account_id], [email], [users_count_limit], [create_date])
    select * from inserted
    where [email] like '%.ru'
END
GO

create trigger UPDATE_ACCOUNT
on [ACCOUNT_VIEW]
instead of update
as
begin 
    if update(account_id) or update(email) or update(create_date)
        RAISERROR('Account ID, Email or Creation Date can not be changed', 11, 1)
    else
    begin 
        update [ACCOUNT]
        set [users_count_limit] = I.users_count_limit
        from ACCOUNT A 
        inner join inserted I on A.account_id = I.account_id

        update SMART_HOME_RUS.dbo.ACCOUNT
        set [users_count_limit] = I.users_count_limit
        from SMART_HOME_RUS.dbo.ACCOUNT A 
        inner join inserted I on A.account_id = I.account_id
    end
end 
go 

create trigger DELETE_ACCOUNT
on [ACCOUNT_VIEW]
instead of delete 
as 
begin 
    delete from [ACCOUNT]
    where [account_id] in (select [account_id] from deleted)

    delete from SMART_HOME_RUS.dbo.ACCOUNT
    where [account_id] in (select [account_id] from deleted)
end 
go 

-------------------------------------------------------------------------------------------------------

insert into [ACCOUNT_VIEW] (account_id, email, users_count_limit, create_date)
values (1, 'arnold@gmail.com', 5, GETDATE()),
       (2, 'ivan@mail.ru', 5, GETDATE()),
       (3, 'robert@gmail.com', 5, GETDATE()),
       (4, 'kirill@yandex.ru', 5, GETDATE()),
       (5, 'calvin@gmail.com', 5, GETDATE()),
       (6, 'artem@yandex.ru', 5, GETDATE()),
       (7, 'ashley@gmail.com', 5, GETDATE()),
       (8, 'lev@mail.ru', 5, GETDATE())
go

select * from [ACCOUNT_VIEW]
select * from SMART_HOME_RUS.dbo.ACCOUNT
select * from SMART_HOME_ENG.dbo.ACCOUNT
go

update [ACCOUNT_VIEW]
set [users_count_limit] = 10
where [account_id] % 3 = 0
go

select * from [ACCOUNT_VIEW]
select * from SMART_HOME_RUS.dbo.ACCOUNT
select * from SMART_HOME_ENG.dbo.ACCOUNT
go

update [ACCOUNT_VIEW]
set [email] = 'example@gmail.com'
where [account_id] % 3 = 0
go

delete from [ACCOUNT_VIEW]
where [users_count_limit] = 10
go

select * from [ACCOUNT_VIEW]
select * from SMART_HOME_RUS.dbo.ACCOUNT
select * from SMART_HOME_ENG.dbo.ACCOUNT
go