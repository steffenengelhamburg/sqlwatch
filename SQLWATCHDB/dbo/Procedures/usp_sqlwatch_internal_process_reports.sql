﻿CREATE PROCEDURE [dbo].[usp_sqlwatch_internal_process_reports] (
	@report_batch_id tinyint = null,
	@report_id smallint = null
	)
as
/*
-------------------------------------------------------------------------------------------------------------------
 [usp_sqlwatch_internal_process_reports]

 Change Log:
	1.0 2019-11-03 - Marcin Gminski
-------------------------------------------------------------------------------------------------------------------
*/
set nocount on;
set xact_abort on;

declare @sql_instance varchar(32),
		@report_title varchar(255),
		@report_description varchar(4000),
		@report_definition nvarchar(max),
		@delivery_target_id smallint,
		@definition_type varchar(10),

		@delivery_command nvarchar(max),
		@target_address nvarchar(max),
		@action_exec nvarchar(max),
		@action_exec_type nvarchar(max),

		@css nvarchar(max),
		@html nvarchar(max)

declare @template_build as table (
	[result] nvarchar(max)
)


declare cur_reports cursor for
select cr.[sql_instance]
      ,cr.[report_id]
      ,[report_title]
      ,[report_description]
      ,[report_definition]
	  ,[report_definition_type]
	  ,t.[action_exec]
	  ,t.[action_exec_type]
	  ,rs.style
  from [dbo].[sqlwatch_config_report] cr

  inner join [dbo].[sqlwatch_config_report_action] ra
	on cr.sql_instance = ra.sql_instance
	and cr.report_id = ra.report_id

	inner join dbo.[sqlwatch_config_action] t
	on ra.[action_id] = t.[action_id]

	inner join [dbo].[sqlwatch_config_report_style] rs
		on rs.report_style_id = cr.report_style_id

  where [report_active] = 1
  and t.[action_enabled] = 1
  --and isnull([report_batch_id],0) = isnull(@report_batch_id,0)
  --and cr.report_id = isnull(@report_id,cr.report_id)
  --avoid getting a report that calls actions that has called this routine to avoid circular refernce:
    and convert(varchar(128),ra.action_id) <> isnull(convert(varchar(128),CONTEXT_INFO()),'0')

  --we must either run report by id or by batch. a null batch_id will indicate that we only run report by its id, usually triggred by an action
  --a batch_id indicates that we run reports from a batch job, i.e. some daily scheduled server summary reports etc, something that is not triggered by an action.
  --remember, an action is triggred on the back of a failed check so unsuitable for a "scheduled daily reports"

  and case /* no batch id passed, we are runing individual report */ when @report_batch_id is null then @report_id else @report_batch_id end = case when @report_batch_id is null then cr.[report_id] else cr.[report_batch_id] end
		
open cur_reports

fetch next from cur_reports
into @sql_instance, @report_id, @report_title, @report_description, @report_definition, @definition_type, @action_exec, @action_exec_type, @css

while @@FETCH_STATUS = 0  
	begin
		set @html = ''
		delete from @template_build

		if @definition_type = 'Query'
			begin
				exec [dbo].[usp_sqlwatch_internal_query_to_html_table] @html = @html output, @query = @report_definition

				set @html = '<html><head><style>' + @css + '</style><body><p>' + @report_description + '</p>' + @html + '<p>Email sent from SQLWATCH on host: ' + @@SERVERNAME +'
<a href="https://sqlwatch.io">https://sqlwatch.io</a></p></body></html>'
			end

		if @definition_type = 'Template'
			begin
				insert into @template_build
				exec sp_executesql @report_definition

				select @html = [result] from @template_build
				set @html = '<html><head><style>' + @css + '</style><body><p>' + @report_description + '</p>' + @html + '<p>Email sent from SQLWATCH on host: ' + @@SERVERNAME +'
<a href="https://sqlwatch.io">https://sqlwatch.io</a></p></body></html>'
			end


		if @html is not null
			begin
				set @action_exec = replace(replace(@action_exec,'{BODY}', replace(@html,'''','''''')),'{SUBJECT}',@@SERVERNAME + ': ' + @report_title)
				--now insert into the delivery queue for further processing:
				insert into [dbo].[sqlwatch_meta_action_queue] ([sql_instance], [time_queued], [action_exec_type], [action_exec], [exec_status])
				values (@@SERVERNAME, sysdatetime(), @action_exec_type, @action_exec, 0)

				Print 'Item ( Id: ' + convert(varchar(10),SCOPE_IDENTITY()) + ' ) queued.'
			end
		else
			begin
				Print 'Report Id: ' + convert(varchar(10),@report_id) + ' contains no data.'
			end

		fetch next from cur_reports 
		into @sql_instance, @report_id, @report_title, @report_description, @report_definition, @definition_type, @action_exec, @action_exec_type, @css

	end

close cur_reports
deallocate cur_reports