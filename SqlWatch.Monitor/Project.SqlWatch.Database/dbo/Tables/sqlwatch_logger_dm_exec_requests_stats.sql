﻿CREATE TABLE [dbo].[sqlwatch_logger_dm_exec_requests_stats]
(
	[type] bit not null, -- 1 user, 0 system
	snapshot_time datetime2(0) not null,
	snapshot_type_id tinyint not null,
	sql_instance varchar(32) not null,
	background real not null,
	running real not null,
	runnable real not null,
	sleeping real not null,
	suspended real not null,
	waiting_tasks real not null,
	wait_duration_ms real not null,

	constraint pk_sqlwatch_logger_dm_exec_requests 
		primary key clustered ([type], snapshot_time, sql_instance, snapshot_type_id),

	constraint fk_sqlwatch_logger_dm_exec_requests_snapshot_header 
		foreign key ([snapshot_time], [sql_instance], [snapshot_type_id]) 
		references [dbo].[sqlwatch_logger_snapshot_header]([snapshot_time], [sql_instance], [snapshot_type_id]) 
		on delete cascade on update cascade
)
