﻿CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_migreate_jobs_to_queues]
as

--this procedure will disable and remove the relevent agent jobs and enable broker based collection
declare @sql varchar(max) = '',
		@database_name sysname = db_name()

select @sql = @sql  + ';' + char(10) + 'exec msdb.dbo.sp_delete_job @job_id=N'''+ convert(varchar(255),job_id) +''', @delete_unused_schedule=1' 
from msdb.dbo.sysjobs
where name like 'SQLWATCH-\[' + @database_name + '\]%' ESCAPE '\'
and name not like '%AZMONITOR'
and name not like '%ACTIONS'
and name not like '%DISK-UTILISATION'
and name not like '%INDEXES'
and name not like '%WHOISACTIVE'

exec (@sql);


--activate queues:
exec [dbo].[usp_sqlwatch_internal_restart_queues];