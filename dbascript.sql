/*
	License info:
	Created by Daniel Janik
	You are free to use this code. Note that any monitoring tool can cause overhead and 
	by using this code you accept all issues that may arise at your own risk.
*/

USE [master]
GO
/****** Object:  Database [DBA]    Script Date: 3/10/2020 8:08:10 PM ******/
CREATE DATABASE [DBA]
go
USE [DBA]
GO
/****** Object:  Table [dbo].[lockinfo]    Script Date: 3/10/2020 8:08:10 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING OFF
GO
CREATE TABLE [dbo].[lockinfo](
	[query_plan_hash] [binary](8) NULL,
	[query_hash] [binary](8) NULL,
	[resource_type] [nvarchar](60) NOT NULL,
	[resource_subtype] [nvarchar](60) NOT NULL,
	[resource_database_id] [int] NOT NULL,
	[resource_description] [nvarchar](256) NOT NULL,
	[resource_associated_entity_id] [bigint] NULL,
	[request_mode] [nvarchar](60) NOT NULL,
	[request_type] [nvarchar](60) NOT NULL,
	[request_status] [nvarchar](60) NOT NULL,
	[request_reference_count] [smallint] NOT NULL,
	[request_session_id] [int] NOT NULL,
	[request_owner_type] [nvarchar](60) NOT NULL,
	[recorded] [datetime] NOT NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[qryAlerts]    Script Date: 3/10/2020 8:08:10 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[qryAlerts](
	[database_id] [smallint] NOT NULL,
	[session_id] [int] NOT NULL,
	[query_plan_hash] [binary](8) NULL,
	[query_hash] [binary](8) NULL,
	[blocking_session_id] [int] NULL,
	[blocking_query_plan_hash] [binary](8) NULL,
	[blocking_query_hash] [binary](8) NULL,
	[total_elapsed_time] [int] NOT NULL,
	[avg_elapsed_time] [numeric](38, 6) NULL,
	[max_elapsed_time] [numeric](23, 3) NULL,
	[pctdiff] [numeric](38, 6) NULL,
	[pctdiffmax] [numeric](38, 14) NULL,
	[wait_resource] [nvarchar](512) NULL,
	[wait_time] [int] NOT NULL,
	[wait_type] [nvarchar](60) NULL,
	[last_wait_type] [nvarchar](60) NOT NULL,
	[recorded] [datetime2](3) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[qryDuration]    Script Date: 3/10/2020 8:08:10 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[qryDuration](
	[dbid] [smallint] NULL,
	[query_plan_hash] [binary](8) NULL,
	[query_hash] [binary](8) NULL,
	[last_elapsed_time] [bigint] NULL,
	[min_elapsed_time] [bigint] NULL,
	[max_elapsed_time] [bigint] NULL,
	[Avg_Elapsed_time] [bigint] NULL,
	[Recorded] [datetime] NOT NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[qryStatement]    Script Date: 3/10/2020 8:08:10 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[qryStatement](
	[dbid] [smallint] NULL,
	[query_plan_hash] [binary](8) NULL,
	[query_hash] [binary](8) NULL,
	[sql_statement] [nvarchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [ix_cl_qryStatement]    Script Date: 3/10/2020 8:08:10 PM ******/
CREATE CLUSTERED INDEX [ix_cl_qryStatement] ON [dbo].[qryStatement]
(
	[dbid] ASC,
	[query_plan_hash] ASC,
	[query_hash] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [ix_ncl_qryDuration]    Script Date: 3/10/2020 8:08:10 PM ******/
CREATE NONCLUSTERED INDEX [ix_ncl_qryDuration] ON [dbo].[qryDuration]
(
	[dbid] ASC,
	[query_plan_hash] ASC,
	[query_hash] ASC
)
INCLUDE ( 	[max_elapsed_time],
	[Avg_Elapsed_time]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
/****** Object:  StoredProcedure [dbo].[sproc_MonitorInstance]    Script Date: 3/10/2020 8:08:10 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[sproc_MonitorInstance]
AS
BEGIN
	SELECT r.database_id, r.query_plan_hash, r.query_hash,  
		r.total_elapsed_time, /* Total time elapsed in milliseconds since the request arrived. */	
		d.Avg_Elapsed_time * 0.001 avg_elapsed_time,
		d.max_elapsed_time,
		(r.total_elapsed_time - d.Avg_Elapsed_time)/d.Avg_Elapsed_time as pctdiff,
		(r.total_elapsed_time - d.max_elapsed_time)/d.max_elapsed_time as pctdiffmax,
		wait_time, wait_type, last_wait_type
	FROM sys.dm_exec_requests r
		INNER JOIN sys.dm_exec_sessions s on (s.session_id = r.session_id)
		inner join (select	dbid, query_plan_hash, query_hash, 
							avg(avg_elapsed_time * 0.001) as avg_elapsed_time, 
							max(max_elapsed_time * 0.001) as max_elapsed_time
					from qryDuration
					group by dbid, query_plan_hash, query_hash) d 
								on (	d.dbid = r.database_id 
									and d.query_plan_hash = r.query_plan_hash 
									and d.query_hash = r.query_hash)
	WHERE s.is_user_process = 1
		and (r.total_elapsed_time - d.Avg_Elapsed_time)/d.Avg_Elapsed_time > 1
		and r.total_elapsed_time > d.max_elapsed_time 
		and r.total_elapsed_time > 10
		and s.session_id != @@SPID
END

GO
/****** Object:  StoredProcedure [dbo].[sproc_MonitorInstanceAlert]    Script Date: 3/10/2020 8:08:10 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[sproc_MonitorInstanceAlert] 
AS
BEGIN

	DECLARE @inserted table (dbid smallint, session_id int, query_plan_hash binary(8), query_hash binary(8), blocking_session_id int, blocking_query_plan_hash binary(8), blocking_query_hash binary(8))

	INSERT INTO qryAlerts
	OUTPUT inserted.database_id, inserted.session_id, inserted.query_plan_hash, inserted.query_hash, inserted.blocking_session_id, inserted.blocking_query_plan_hash, inserted.blocking_query_hash INTO @Inserted
	SELECT r.database_id, r.session_id, r.query_plan_hash, r.query_hash,  
		b.session_id, b.query_plan_hash, b.query_hash,  
		r.total_elapsed_time, /* Total time elapsed in milliseconds since the request arrived. */	
		d.Avg_Elapsed_time * 0.001 avg_elapsed_time,
		d.max_elapsed_time,
		(r.total_elapsed_time - d.Avg_Elapsed_time)/d.Avg_Elapsed_time as pctdiff,
		(r.total_elapsed_time - d.max_elapsed_time)/d.max_elapsed_time as pctdiffmax,
		r.wait_resource, r.wait_time, r.wait_type, r.last_wait_type, getdate() as recorded
	FROM sys.dm_exec_requests r
		INNER JOIN sys.dm_exec_sessions s on (s.session_id = r.session_id)
		LEFT JOIN sys.dm_exec_requests b on (b.session_id = r.blocking_session_id)
		inner join (select	dbid, query_plan_hash, query_hash, 
							avg(avg_elapsed_time * 0.001) as avg_elapsed_time, 
							max(max_elapsed_time * 0.001) as max_elapsed_time
					from qryDuration
					group by dbid, query_plan_hash, query_hash) d 
								on (	d.dbid = r.database_id 
									and d.query_plan_hash = r.query_plan_hash 
									and d.query_hash = r.query_hash)
	WHERE s.is_user_process = 1
		and (r.total_elapsed_time - d.Avg_Elapsed_time)/d.Avg_Elapsed_time > 1
		and r.total_elapsed_time > d.max_elapsed_time 
		and r.total_elapsed_time > 10
		and s.session_id != @@SPID

	INSERT INTO dbo.lockinfo
	SELECT distinct
		query_plan_hash
		,query_hash
		,resource_type
		,resource_subtype
		,resource_database_id
		,resource_description
		,resource_associated_entity_id
		,request_mode
		,request_type
		,request_status
		,request_reference_count
		--,request_lifetime
		,request_session_id
		,request_owner_type
		,getdate() as recorded
	FROM sys.dm_tran_locks tl
	inner join @inserted i on (tl.request_session_id = i.session_id) and (i.blocking_session_id > 0)

	INSERT INTO dbo.lockinfo
	SELECT distinct
		i.blocking_query_plan_hash
		,i.blocking_query_hash
		,resource_type
		,resource_subtype
		,resource_database_id
		,resource_description
		,resource_associated_entity_id
		,request_mode
		,request_type
		,request_status
		,request_reference_count
		--,request_lifetime
		,request_session_id
		,request_owner_type
		,getdate() as recorded
	FROM sys.dm_tran_locks tl
	inner join @inserted i on (tl.request_session_id = i.blocking_session_id) and (i.blocking_session_id > 0)
END



GO
/****** Object:  StoredProcedure [dbo].[sproc_updatemetrics]    Script Date: 3/10/2020 8:08:10 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[sproc_updatemetrics]
AS
BEGIN	
	SELECT s2.dbid, qs.query_plan_hash, qs.query_hash, 
		/* Maximum elapsed time, reported in microseconds, for any completed execution of this plan. */
		qs.last_elapsed_time, 
		qs.min_elapsed_time, 
		qs.max_elapsed_time, 
		total_elapsed_time / execution_count as Avg_Elapsed_time,
		SUBSTRING(s2.text, (qs.statement_start_offset/2)+1, 
			((CASE qs.statement_end_offset
			  WHEN -1 THEN DATALENGTH(s2.text)
			 ELSE qs.statement_end_offset
			 END - qs.statement_start_offset)/2) + 1) AS sql_statement
	INTO #qstat
	FROM sys.dm_exec_query_stats qs
	CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) s2
	WHERE s2.dbid not in (1,3,4,32767, 692, db_id()) -- nolio = 692
	
	INSERT INTO dbo.qryDuration (dbid, query_plan_hash, query_hash, last_elapsed_time, min_elapsed_time, max_elapsed_time, Avg_Elapsed_time, Recorded)
	SELECT dbid, query_plan_hash, query_hash, 
		max(last_elapsed_time) as last_elapsed_time, 
		max(min_elapsed_time) as min_elapsed_time, 
		max(max_elapsed_time) as max_elapsed_time, 
		max(Avg_Elapsed_time) as Avg_Elapsed_time,
		GETDATE() as Recorded
	FROM #qstat
	GROUP BY dbid, query_plan_hash, query_hash

	INSERT INTO dbo.qryStatement (dbid, query_plan_hash, query_hash, sql_statement)
	SELECT q.dbid, q.query_plan_hash, q.query_hash, q.sql_statement
	FROM #qstat q
	left join dbo.qryStatement s on (s.dbid = q.dbid) 
		and (s.query_plan_hash = q.query_plan_hash) 
		and (s.query_hash = q.query_hash) 
		and (s.sql_statement = q.sql_statement)
	where s.query_hash is null

	DELETE a 
	FROM (	SELECT dbid, query_plan_hash, query_hash, Recorded, 
					ROW_NUMBER() over (partition by dbid, query_plan_hash, query_hash order by recorded desc) as rn
			FROM dbo.qryDuration) a
	WHERE a.rn > 5

	DELETE FROM dbo.qryDuration WHERE Recorded > dateadd(d, 5, getdate())
	
	DELETE s
	FROM dbo.qryStatement s
	LEFT JOIN dbo.qryDuration d on (s.dbid = d.dbid) and (s.query_plan_hash = d.query_plan_hash) and (s.query_hash = d.query_hash) 
	WHERE d.query_hash is null

	DELETE s 
	FROM (	SELECT dbid, query_plan_hash, query_hash,  
					ROW_NUMBER() over (partition by dbid, query_plan_hash, query_hash order by dbid, query_plan_hash, query_hash) as rn
			FROM dbo.qryStatement) s
	WHERE s.rn > 1

	DELETE FROM dbo.lockinfo WHERE recorded < DATEADD(d, -7, getdate())	
END

GO
USE [master]
GO
ALTER DATABASE [DBA] SET  READ_WRITE 
GO
