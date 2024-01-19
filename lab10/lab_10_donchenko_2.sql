use [SMART_HOME]
go

-- Грязное чтение
---------------------------------------------------------------

set TRANSACTION ISOLATION LEVEL READ UNCOMMITTED -- COMMITTED
begin TRANSACTION

select * from [DEVICE] -- измененное / изначально

select [resource_type], [resource_database_id], 
[resource_description], [request_mode] 
from sys.dm_tran_locks

commit TRANSACTION
go

---------------------------------------------------------------

begin TRANSACTION

select * from [DEVICE] -- изначально

update [DEVICE] -- изменяем
set [device_name] = 'my device'
where [device_id] = 1

select * from [DEVICE] -- измененное

commit TRANSACTION
go

----------------------------------------------------------------

begin TRANSACTION

select * from [DEVICE] -- изначально

insert into [DEVICE] (chip_id, device_name, device_type, powered_by)
values ('SKNSNJS', 'new device', 1, 0) -- вставляем

select * from [DEVICE] -- измененное

commit TRANSACTION
go