--#/*************************************************************************************************/
--#/* Script                    : showplan.sql                                                      */
--#/* Author                    : Mario Barduchi                                                    */
--#/* E-mail                    : mario.barduchi@gmail.com                                          */
--#/* Date                      : 11/06/2024                                                        */
--#/* Original                  : None                                                              */
--#/* Description               : Execution plan info - Top 30 most executed plans at the moment,   */
--#/*                             and other information                                             */
--#/* Location                  : /home/oracle/SCRIPTS2DBA                                          */
--#/* Responsibility            : DBA                                                               */
--#/* External Parameters       :                                                                   */
--#/* Changes Made              :                                                                   */
--#/* Observations              :                                                                   */
--#/*                             Some queries were basesd on:                                      */
--#/*                             coe_xfr_sql_profile.sql from Carlos Sierra                        */
--#/*************************************************************************************************/
@../CONFSQL/confsql.sql

prompt
prompt ========================================================================================================================================================================
prompt ========================================================================================================================================================================
prompt ========================================================================================================================================================================
prompt Execution plans
prompt
prompt Important:
prompt ==========
prompt 
prompt All execution times, elapsed_time_sec, elapsed_time_min, elapsed_time_hr, cpu_time_sec, buffer_gets, disk_reads, and rows_processed are accumulated from 
prompt the moment the SQL enters the Shared Pool. If it expires or is removed from the Shared Pool, these values are reset and start a new count when it re-enters 
prompt the Shared Pool.
prompt 
prompt SQL_ID: Unique SQL identifier of the parent cursor in the library cache.
prompt 
prompt PLAN_HASH_VALUE: The hash value of the current SQL plan for this cursor, used to identify the unique execution plan.
prompt 
prompt EXECUTIONS: Total number of executions of the SQL. It does not matter if the SQL was executed at different time intervals since it was brought into the library cache, 
prompt it is always incremented by 1 .
prompt 
prompt ELAPSED_TIME_SEC, ELAPSED_TIME_MIN and ELAPSED_TIME_HR: Elapsed database time used by this cursor for parsing, executing, and fetching. If the cursor uses parallel 
prompt execution, then ELAPSED_TIME is the cumulative time for the query coordinator, plus all parallel query worker processes. In seconds, minutes, and hours.
prompt In some cases, ELAPSED_TIME can exceed the duration of the query. 
prompt
prompt CPU_TIME_SEC: CPU time consumed by the SQL for parsing, executing and fetching. This may differ significantly from elapsed_time, as there may be periods when the SQL 
prompt is waiting for something, like memory, disk, or other resources, to continue CPU processing.
prompt 
prompt BUFFER_GETS: Number of buffer cache reads performed by the SQL. Ideally, the higher the BUFFER_GETS and the lower the disk_reads, the better the SQL performance.
prompt     
prompt DISK_READS: Similar to BUFFER_GETS, it is the total number of physical reads made directly from disk by the SQL.
prompt 
prompt ROWS_PROCESSED: Total number of rows read and processed by the SQL to return a result.
prompt     
prompt PLAN_COUNT: The number of distinct execution plans that are active and associated with a SQL_ID. It does not consider the history.
prompt 
prompt ATTENTION: Identifies SQLs that could be problematic. Marks as Yes if:
prompt            - SQLs with very long execution times (over 100,000 seconds).
prompt            - SQLs that excessively use buffer cache (over 1 billion buffer gets).
prompt            - SQLs that perform many disk reads (over 100 million disk reads).
prompt            - Excessive parsing may occur (Child Cursors between 11 and 50).
prompt            - Possible contention in the Shared Pool (Child Cursors > 50).
prompt 
prompt Important: These criteria were defined by me, based on my experience, and are not necessarily based on manuals. It is just a starting point for me to analyze 
prompt a SQL in more detail.
prompt 
prompt ========================================================================================================================================================================
prompt Child Cursors
prompt
prompt Important:
prompt ==========
prompt
prompt Child Cursors are variations of the same SQL in the Shared Pool. They arise when changes are made that prevent the original plan from being reused. Too many child 
prompt cursors can, but not necessarily, be an indicator of excessive parsing problems.
prompt 
prompt When multiple Child Cursors can occur for the same SQL:
prompt      - Differences in Bind Variables (Adaptive Cursor Sharing).
prompt 	   - Change in Table Statistics.
prompt 	   - Change in Session Parameters.
prompt 	   - Changes in Privileges (GRANT/REVOKE).
prompt 	   - Sessions with different NLS configurations.
prompt 	   - Changing Structures (DDL such as ALTER TABLE, CREATE INDEX).
prompt 
prompt ========================================================================================================================================================================
prompt ========================================================================================================================================================================
prompt ========================================================================================================================================================================


-- Formatação das colunas para melhor leitura
-- Formatação das colunas para melhor leitura
COLUMN sql_id FORMAT A15
COLUMN plan_hash_value FORMAT 9999999999
COLUMN executions FORMAT 9999999999
COLUMN elapsed_time_sec FORMAT 999,999,999.99
COLUMN cpu_time_sec FORMAT 999,999,999.99
COLUMN buffer_gets FORMAT 999,999,999,999
COLUMN disk_reads FORMAT 999,999,999,999
COLUMN rows_processed FORMAT 999,999,999,999
COLUMN plan_count FORMAT 99999
COLUMN elapsed_time_min FORMAT 999,999,999.99
COLUMN elapsed_time_hr FORMAT 999,999,999.99
COLUMN attention FORMAT A65

select *
  from (
       select v.sql_id,
              v.plan_hash_value,
              v.executions,
              round(v.elapsed_time / 1e6, 2)          as elapsed_time_sec, 
              round(v.elapsed_time / 1e6 / 60, 2)     as elapsed_time_min, 
              round(v.elapsed_time / 1e6 / 3600, 2)   as elapsed_time_hr, 
              round(v.cpu_time / 1e6, 2)              as cpu_time_sec, 
              v.buffer_gets,
              v.disk_reads,
              v.rows_processed,
              (select count(distinct plan_hash_value) from v$sql where sql_id = v.sql_id )      as plan_count,
              (select count(*) from v$sql where sql_id = v.sql_id )                             as child_cursors,
              case
                     when v.disk_reads > 100000000                                               then 'Disk Reads > 100 Million accumulated.'
                     when v.buffer_gets > 1000000000                                             then 'Buffer Gets > 1 Billion accumulated.'
                     when round(v.elapsed_time / 1e6, 2) > 200000                                then 'Elapsed Time > 200,000s accumulated.'
                     when (select count(*) from v$sql where sql_id = v.sql_id) between 11 and 50 then 'Child Cursors between 11 and 50! Excessive parsing may occur.'
                     when (select count(*) from v$sql where sql_id = v.sql_id) > 50              then 'Child Cursors > 50! Possible contention in the Shared Pool.'
                     else ''
              end as attention
       from v$sql v
       where v.plan_hash_value > 0 
       order by v.cpu_time desc
)
where rownum <= 30;

SET SERVEROUTPUT ON
--SET FEEDBACK OFF

prompt 
prompt ========================================================================================================================================================================
ACCEPT sql_id CHAR PROMPT 'Do you want to see details of any SQL_ID? (Press Enter to finish): '
prompt ========================================================================================================================================================================

declare
       v_sql_id varchar2(20) := trim('&&sql_id');
begin
   
       if v_sql_id is null or length(v_sql_id) = 0 then
              return;
       else
              dbms_output.put_line(chr(10));
              dbms_output.put_line('============================================');
              dbms_output.put_line('Execution Plans for SQL_ID: ' || v_sql_id);
              dbms_output.put_line('============================================');
              dbms_output.put_line(rpad('Plan Hash Value',20) || rpad('Avg Elapsed Time (s)',25)|| rpad('Status',25));
              dbms_output.put_line('------------------- ------------------------ ---------------------');
       for rec in (
              with p as (
              select plan_hash_value
                     from gv$sql_plan
                     where sql_id = v_sql_id
                     and other_xml is not null
              union
              select plan_hash_value
                     from dba_hist_sql_plan
                     where sql_id = v_sql_id
                     and other_xml is not null
         ),m as (
              select plan_hash_value,
                     sum(elapsed_time) / sum(executions) avg_et_secs
                     from gv$sql
                     where sql_id = v_sql_id
                     and executions > 0
                     group by plan_hash_value
         ),a as (
              select plan_hash_value,
                     sum(elapsed_time_total) / sum(executions_total) avg_et_secs
                     from dba_hist_sqlstat
                     where sql_id = v_sql_id
                     and executions_total > 0
                     group by plan_hash_value
         ), 
         active_plans as (
              select distinct plan_hash_value
                     from gv$sql_plan
                     where sql_id = v_sql_id
         )
         select p.plan_hash_value,
              round(nvl(m.avg_et_secs,a.avg_et_secs) / 1e6, 3) avg_et_secs,
              case
                     when p.plan_hash_value in (select plan_hash_value from active_plans) then 'Active'
                     else 'Historical Execution Plan'
              end 
         as status
         from p
         left join m on p.plan_hash_value = m.plan_hash_value
         left join a on p.plan_hash_value = a.plan_hash_value
          order by status, avg_et_secs nulls last
      ) loop
              dbms_output.put_line(rpad(rec.plan_hash_value,20) || rpad(nvl(to_char(rec.avg_et_secs,'999,999,999.999'),'                         '),25) || rpad(nvl(rec.status,' '),25));
      end loop;

      dbms_output.put_line(chr(10));
      dbms_output.put_line('============================================');
      dbms_output.put_line(' Child Cursors for SQL_ID: ' || v_sql_id);
      dbms_output.put_line('============================================');
      dbms_output.put_line(rpad('Child Number',18)|| rpad('Reason',50));
      dbms_output.put_line('----------------- ------------------------------------------------');
      
      for rec2 in (
              select s.child_number,
                     regexp_substr(to_clob(s.reason),'<reason>(.*?)</reason>',1,1,null,1) as clean_reason
              from v$sql_shared_cursor s
              where s.sql_id = v_sql_id
              order by s.child_number
      ) loop
              dbms_output.put_line(rpad(to_char(rec2.child_number,'999'),21) || rpad(rec2.clean_reason,50));
      end loop;
   end if;
end;
/