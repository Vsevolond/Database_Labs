use [SMART_HOME]
go

drop table if exists [DEVICE]
GO

create table DEVICE
(
    [device_id] int identity (1, 1) primary key,
    [chip_id] varchar(16) not null check (upper(chip_id) = chip_id), -- только в верхнем регистре
    [device_name] varchar(20) default 'Device',
    [device_type] tinyint not null check (device_type in (1, 2, 3)), -- 1 - умная колонка, 2 - умный свет, 3 - контроллер воздуха
    [powered_by] bit default 0, -- 0 - только от сети, 1 - с батареей
    constraint DEVICE_AK1 unique (chip_id)
)
go

insert into [DEVICE] (chip_id, device_name, device_type, powered_by)
values ('AJDKJKAJ', 'first device', 1, 0),
       ('NDJNLDS', 'second device', 2, 1)
go

insert into [DEVICE] (chip_id, device_type)
values ('NKNNNKLNKLN', 2),
       ('OAPPSJAOP', 3)
go