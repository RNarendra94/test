CREATE proc [dbo].[sp_target] @session_id int =null
as
-- CPU Usage

DECLARE @ts_now bigint = (SELECT cpu_ticks/(cpu_ticks/ms_ticks)FROM sys.dm_os_sys_info);

SET QUOTED_IDENTIFIER ON

SELECT top 1 SQLProcessUtilization AS [SQL Server Process CPU Utilization],

SystemIdle AS [System Idle Process],

100 - SystemIdle - SQLProcessUtilization AS [Other Process CPU Utilization],

DATEADD(ms, -1 * (@ts_now - [timestamp]), GETDATE()) AS [Event Time]

FROM (

SELECT record.value('(./Record/@id)[1]', 'int') AS record_id,

record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int')

AS [SystemIdle],

record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]','int')

AS [SQLProcessUtilization], [timestamp]

FROM (

SELECT [timestamp], CONVERT(xml, record) AS [record]

FROM sys.dm_os_ring_buffers

WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'

AND record LIKE '%%') AS x

) AS y

--WHERE (DATEADD(ms, -1 * (@ts_now - [timestamp]), GETDATE())) > (select max(Event_Time) from MON_CPU_USAGE)

ORDER BY [Event Time] desc

--sp_whoisactive

--go


-- Running processes

SELECT

CASE

WHEN req.total_elapsed_time < 0 THEN

RIGHT

(

REPLICATE('0', 2) + CONVERT(VARCHAR, (-1 * req.total_elapsed_time) / 86400),

2

) +

RIGHT

(

CONVERT(VARCHAR, DATEADD(second, (-1 * req.total_elapsed_time), 0), 120),

9

) +

'.000'

ELSE

RIGHT

(

REPLICATE('0', 2) + CONVERT(VARCHAR, req.total_elapsed_time / 86400000),

2

) +

RIGHT

(

CONVERT(VARCHAR, DATEADD(second, req.total_elapsed_time / 1000, 0), 120),

9

) +

'.' +

RIGHT('000' + CONVERT(VARCHAR, req.total_elapsed_time % 1000), 3)

END AS [dd hh:mm:ss:mss],

ses.login_name [Schema Name],

req.cpu_time,

req.percent_complete,

wait_type,

ses.program_name,

J.NAME Job_Name,

req.session_id,

'kill' lbl,

blocking_session_id,

ses.host_name,

DATEDIFF(mi,start_time,getdate()) diff_min,

OBJECT_NAME(sqltext.objectid,sqltext.dbid) PROCEDURE_NAME,

DB_NAME(req.database_id) DBNAME,

SUBSTRING(sqltext.TEXT, (req.statement_start_offset/2)+1,

((CASE req.statement_end_offset

WHEN -1 THEN DATALENGTH(sqltext.TEXT)

ELSE req.statement_end_offset

END - req.statement_start_offset)/2)+1) QUERY,

req.status,

m.requested_memory_kb/1000 requested_memory_mb,

m.granted_memory_kb/1000 granted_memory_mb,

req.command,

req.total_elapsed_time,

req.logical_reads,

dec.client_net_address ,

--ip.username,

req.*

FROM sys.dm_exec_requests req

CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS sqltext

inner join sys.dm_exec_sessions ses on req.session_id=ses.session_id

INNER JOIN sys.dm_exec_connections AS dec ON ses.session_id = dec.session_id

left join msdb.dbo.sysjobs j on right(job_id,12)=substring(right(ses.program_name,22),1,12)

left join sys.dm_exec_query_memory_grants AS m on req.session_id=m.session_id

--where req.session_id=isnull(@session_id,req.session_id)

--ORDER BY req.cpu_time desc --req.blocking_session_id ASC, req.session_id ASC

ORDER BY req.start_time --req.blocking_session_id ASC, req.session_id ASC


SELECT SUM(pending_disk_io_count) AS [Number of pending I/Os] FROM sys.dm_os_schedulers


SELECT * FROM sys.dm_io_pending_io_requests

