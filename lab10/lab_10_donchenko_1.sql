use [SMART_HOME]
go

--------------------------------------------------

begin TRANSACTION

select * from [DEVICE] -- изначально

update [DEVICE] -- изменяем
set [device_name] = 'my device'
where [device_id] = 1

WAITFOR delay '00:00:05' -- ждем

ROLLBACK TRANSACTION -- откат

select * from [DEVICE] -- изначально
go

-- Неповторяющееся чтение
--------------------------------------------------

set TRANSACTION ISOLATION LEVEL REPEATABLE READ
begin TRANSACTION

select * from [DEVICE] -- изначально

select [resource_type], [resource_database_id], 
[resource_description], [request_mode] 
from sys.dm_tran_locks

WAITFOR delay '00:00:05'

select * from [DEVICE] -- измененное / изначально

commit TRANSACTION
go

-- Фантомное чтение
--------------------------------------------------

set TRANSACTION ISOLATION LEVEL SERIALIZABLE
begin TRANSACTION

select * from [DEVICE] -- изначально

select [resource_type], [resource_database_id], 
[resource_description], [request_mode] 
from sys.dm_tran_locks

WAITFOR delay '00:00:05'

select * from [DEVICE] -- измененное / изначально

commit TRANSACTION
go