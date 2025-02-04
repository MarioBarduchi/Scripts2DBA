--#/**************************************************************************************/
--#/* Script                    : showsga2.sql                                           */
--#/* Autor                     : Mario Barduchi                                         */
--#/* E-mail                    : mario.barduchi@gmail.com                               */
--#/* Data                      : 03/02/2025                                             */
--#/* Original                  : None                                                   */
--#/* Description               : Configurations - SQL*Plus                              */
--#/* Location                  : /home/oracle/SCRIPTS2DBA                               */
--#/* Responsibility            : DBA                                                    */
--#/* External Parameters       :                                                        */
--#/* Changes Made              :                                                        */
--#/* Observations              :                                                        */
--#/*************************************************************************************/
@../CONFSQL/confsql.sql
SET FEEDBACK OFF

prompt
prompt =================================================================================================================
prompt =================================================================================================================
prompt =================================================================================================================
prompt Instance parameter
prompt
prompt Important:
prompt ==========
prompt DEFAULT - Indicate whether the parameter has been modified.
prompt =================================================================================================================
prompt =================================================================================================================
prompt =================================================================================================================
COLUMN INST_ID          HEADING 'Instance'      FORMAT 999
COLUMN PARAMETER_NAME   HEADING 'Parameter'     FORMAT A40
COLUMN VALUE_GB         HEADING 'Value (GB)'    FORMAT 999,999.99
COLUMN IS_MODIFIED      HEADING 'Default'       FORMAT A10

SELECT
        p.inst_id                           AS INST_ID,
        p.name                              AS PARAMETER_NAME,
        TO_NUMBER((p.value)/1024/1024/1024) AS VALUE_GB,
        CASE
            WHEN p.ismodified = 'TRUE' THEN 'YES'
            ELSE 'NO'
        END                                 AS IS_MODIFIED
    FROM
        gv$parameter p
    WHERE
        p.name IN ('sga_max_size', 'sga_target', 'pga_aggregate_target', 'pga_aggregate_limit',
                'db_cache_size', 'shared_pool_size', 'shared_pool_reserved_size')
    ORDER BY
        p.name, p.inst_id ;

prompt
prompt =================================================================================================================
prompt =================================================================================================================
prompt =================================================================================================================
prompt SGA current allocation
prompt
prompt Important:
prompt ==========
prompt If the values of SGA current size are much lower than SGA max. size, it may indicate underutilization.
prompt If SGA min. size is much smaller than SGA current size, it may indicate the need for excessive shrink or growth.
prompt =================================================================================================================
prompt =================================================================================================================
prompt =================================================================================================================
COLUMN COMPONENT    HEADING 'Component'                 FORMAT A30
COLUMN SIZE_GB      HEADING 'SGA current size (GB)'     FORMAT 999,999,999.99
COLUMN MIN_SIZE_GB  HEADING 'SGA min. size (GB)'        FORMAT 999,999,999.99
COLUMN MAX_SIZE_GB  HEADING 'SGA max. size (GB)'        FORMAT 999,999,999.99

SELECT COMPONENT,
       (CURRENT_SIZE/1024/1024/1024)    AS SIZE_GB,
       (MIN_SIZE/1024/1024/1024)        AS MIN_SIZE_GB,
       (MAX_SIZE/1024/1024/1024)        AS MAX_SIZE_GB
FROM V$SGA_DYNAMIC_COMPONENTS
ORDER BY MAX_SIZE DESC;

prompt
prompt =================================================================================================================
prompt =================================================================================================================
prompt =================================================================================================================
prompt Check for shrink or growth in the last 20 operations.
prompt
prompt Important:
prompt ==========
prompt Operation type
prompt    GROW         - Indicates the growth of the SGA.
prompt    SHRINK       - Indicates that the SGA was reduced.
prompt    RESET        - The SGA was reset to an initial value.
prompt    INITIALIZING - Sizing during database startup.
prompt    STATIC       - Static resizing, requires a database restart.
prompt    DYNAMIC      - Dynamic resizing, no need to restart the database.
prompt    MANUAL       - Manually adjusted.
prompt
prompt Operation mode
prompt    AUTO      - Resizing executed automatically.
prompt    MANUAL    - Manual resizing.
prompt    DEFERRED  - Resizing was deferred, probably due to unavailable resources, and will be performed later.
prompt    IMMEDIATE - Resizing executed immediately.
prompt
prompt Current Size (GB) - The initial size of the component before the operation.
prompt
prompt Final size (GB)   - The final size of the component after the operation.
prompt
prompt Target size (GB)  - The desired target size for the component after the operation.
prompt =================================================================================================================
prompt =================================================================================================================
prompt =================================================================================================================
COLUMN COMPONENT        FORMAT A30                  HEADING 'Component'
COLUMN OPER_TYPE        FORMAT A15                  HEADING 'Operation type'
COLUMN OPER_MODE        FORMAT A15                  HEADING 'Operation mode'
COLUMN START_TIME       FORMAT A20                  HEADING 'Start time'
COLUMN END_TIME         FORMAT A20                  HEADING 'End time'
COLUMN SIZE_GB          FORMAT 999,999,999,999.99   HEADING 'Current size (GB)'
COLUMN FINAL_SIZE_GB    FORMAT 999,999,999,999.99   HEADING 'Final size (GB)'
COLUMN TARGET_SIZE_GB   FORMAT 999,999,999,999.99   HEADING 'Target size (GB)'

SELECT COMPONENT,
       OPER_TYPE,
       OPER_MODE,
       TO_CHAR(START_TIME, 'DD/MM/YYYY HH24:MI:SS') AS START_TIME,
       TO_CHAR(END_TIME, 'DD/MM/YYYY HH24:MI:SS') AS END_TIME,
       ROUND(INITIAL_SIZE/1024/1024/1024, 4) AS SIZE_GB,
       ROUND(FINAL_SIZE/1024/1024/1024, 4) AS FINAL_SIZE_GB,
       ROUND(TARGET_SIZE/1024/1024/1024, 4) AS TARGET_SIZE_GB
FROM V$SGA_RESIZE_OPS
ORDER BY END_TIME FETCH FIRST 20 ROWS ONLY;

prompt
prompt =================================================================================================================
prompt =================================================================================================================
prompt =================================================================================================================
prompt SGA advice - for tuning
prompt
prompt Important:
prompt ==========
prompt Remember: This is just a SUGGESTION, and should be analyzed carefully considering the entire customers scenario.
prompt
prompt In this advisor, all configuration suggestions will be listed, and the current value of the SGA, an acceptable
prompt value for the SGA, and the ideal value for the SGA will be marked.
prompt
prompt SGA size factor - Ratio between the SGA size (GB) and the current/estimated size of the SGA.
prompt
prompt DB Time size factor - Ratio between Estimated DB Time (ms) and the DB Time for the current size of the SGA.
prompt
prompt DB Time (ms) - This is the estimate for the DB Time for this SGA. The advisor aims to achieve the lowest value
prompt                combined with physical reads and the minimum allocated SGA.
prompt
prompt Estimated size Buffer Cache (GB) - Estimated size of the shared pool.
prompt
prompt Estimated size Shared Pool (GB) - Estimated size of the buffer cache.
prompt
prompt Estimated physical reads (GB) - Estimated number of physical reads - for this analysis, the lower the value, the
prompt                                 better the result.
prompt
prompt When analyzing the data, you should look for the possible SGA value that:
prompt    1) Provides the lowest Estimated DB Time (ms) - indicating better performance.
prompt    2) Minimizes Estimated physical reads (GB) - indicating that more data is being read from memory and less from disk.
prompt    3) Has an appropriate SGA size factor, meaning a reasonable value for the available memory in the system without causing overload.
prompt =================================================================================================================
prompt =================================================================================================================
prompt =================================================================================================================
COLUMN SGA_SIZE_GB              FORMAT 999,999,999,999,999      HEADING 'SGA size (GB)'
COLUMN SGA_SIZE_FACTOR          FORMAT 99.99                    HEADING 'SGA size factor'
COLUMN ESTD_DB_TIME_FACTOR      FORMAT 99.99                    HEADING 'DB Time factor'
COLUMN ESTD_DB_TIME_MS          FORMAT 99,999,999.99            HEADING 'Estimated DB Time (ms)'
COLUMN ESTD_PHYSICAL_READS      FORMAT 999,999,999,999,999.99   HEADING 'Estimated physical | reads (GB)'
COLUMN ESTD_BUFFER_CACHE_SIZE   FORMAT 999,999,999,999,999.99   HEADING 'Estimated size | Buffer Cache (GB)'
COLUMN ESTD_SHARED_POOL_SIZE    FORMAT 999,999,999,999,999.99   HEADING 'Estimated size | Shared Pool (GB)'
COLUMN SUGGESTION               FORMAT A15                      HEADING 'Suggestion'

WITH SGA_ADVICE_RANK AS (
    SELECT
        SGA_SIZE,
        SGA_SIZE_FACTOR,
        ESTD_DB_TIME,
        ESTD_DB_TIME_FACTOR,
        ESTD_BUFFER_CACHE_SIZE,
        ESTD_SHARED_POOL_SIZE,
        ESTD_PHYSICAL_READS,
        ROW_NUMBER() OVER (
            ORDER BY ESTD_PHYSICAL_READS ASC, ESTD_DB_TIME ASC, SGA_SIZE_FACTOR ASC
        ) AS ideal,
        ROW_NUMBER() OVER (
            ORDER BY ESTD_PHYSICAL_READS ASC, SGA_SIZE_FACTOR ASC
        ) AS good
    FROM V$SGA_TARGET_ADVICE
)
SELECT
    SGA_SIZE / 1024 AS SGA_SIZE_GB,
    SGA_SIZE_FACTOR,
    ESTD_DB_TIME / 1000 AS ESTD_DB_TIME_MS,
    ESTD_DB_TIME_FACTOR,
    ESTD_BUFFER_CACHE_SIZE,
    ESTD_SHARED_POOL_SIZE,
    ESTD_PHYSICAL_READS,
    CASE
        WHEN SGA_SIZE_FACTOR = 1 THEN 'Current value'
        WHEN ideal = 1           THEN 'Best value'
        WHEN good  = 1           THEN 'Accetable value'
        ELSE NULL
    END AS SUGGESTION
FROM SGA_ADVICE_RANK
ORDER BY SGA_SIZE;

prompt
prompt =================================================================================================================
prompt =================================================================================================================
prompt =================================================================================================================
prompt Minimum SGA in the last 15 Advisor-based resizes (SQL Tuning Advisor or Memory Advisor)
prompt
prompt Important:
prompt ==========
prompt Shared Size (GB) - SGA current size.
prompt
prompt Advised SGA size (GB) - Maximum size recommended by SQL Tuning Advisor or Memory Advisor in the last 15 operations.
prompt =================================================================================================================
prompt =================================================================================================================
prompt =================================================================================================================
COLUMN OPER_TIME     FORMAT A20                  HEADING 'Operation time'
COLUMN SGA_SIZE_GB   FORMAT 999,999,999,999,999  HEADING 'SGA size (GB)'
COLUMN FINAL_SIZE_GB FORMAT 999,999,999,999,999  HEADING 'Advised SGA size (GB)'
COLUMN HIGHEST_VALUE_FLAG FORMAT A30             HEADING 'Advised SGA size (GB)'

WITH RESULTS AS (
    SELECT TO_CHAR(al.execution_start, 'DD/MM/YYYY HH24:MI:SS') AS OPER_TIME,
           ROUND(aa.num_attr1/1024/1024, 4) AS SGA_SIZE_GB,
           ROUND(aa.num_attr2/1024/1024, 4) AS FINAL_SIZE_GB
    FROM dba_advisor_actions  aa,
         dba_advisor_findings af,
         dba_advisor_log      al
    WHERE al.owner          = af.owner
      AND al.task_name      = af.task_name
      AND aa.owner          = af.owner
      AND aa.task_name      = af.task_name
      AND aa.execution_name = af.execution_name
      AND af.finding_name   = 'Undersized SGA'
      AND aa.attr1          = 'sga_target'
    ORDER BY al.execution_start 
    FETCH FIRST 15 ROWS ONLY
)
SELECT res.*, 
       CASE 
           WHEN FINAL_SIZE_GB = (SELECT MAX(FINAL_SIZE_GB) FROM RESULTS) 
           THEN 'Highest value on Advisor' 
           ELSE '' 
       END AS HIGHEST_VALUE_FLAG
FROM RESULTS res;

prompt
prompt =================================================================================================================
prompt =================================================================================================================
prompt =================================================================================================================
prompt Shared Pool current use
prompt
prompt Important:
prompt ==========
prompt Shared Pool Used (GB) - Shared pool usada efetivamente no período.
prompt
prompt Shared Pool Free (GB) - Espaço livre estimado da Shared Pool.
prompt
prompt Shared Pool Used (%) - % de uso da Shared Pool.
prompt =================================================================================================================
prompt =================================================================================================================
prompt =================================================================================================================
COLUMN SP_SIZE      HEADING 'Shared Pool Size (GB)' FORMAT 999,999.99
COLUMN SP_USED      HEADING 'Shared Pool Used (GB)' FORMAT 999,999.99
COLUMN SD_FREE      HEADING 'Shared Pool Free (GB)' FORMAT 999,999.99
COLUMN SD_USED_PERC HEADING 'Shared Pool Used (%)'  FORMAT 999.99

SELECT
    MAX(B.VALUE)/(1024*1024*1024) SP_SIZE,
    SUM(A.BYTES)/(1024*1024*1024) SP_USED,
    (MAX(B.VALUE)/(1024*1024*1024)) - (SUM(A.BYTES)/(1024*1024*1024)) SD_FREE,
    ((SUM(A.BYTES)/(1024*1024*1024))/(MAX(B.VALUE)/(1024*1024*1024)))*100 SD_USED_PERC
FROM V$SGASTAT A, V$PARAMETER B
WHERE A.POOL= 'shared pool'
AND A.NAME NOT IN ('free memory')
AND B.NAME='shared_pool_size';

prompt
prompt =================================================================================================================
prompt =================================================================================================================
prompt =================================================================================================================
prompt Suggested calculations for SGA and Shared Pool, if necessary.
prompt
prompt Important:
prompt ==========
prompt These are suggestions based on best practices, experience, and manuals. Always analyze your complete environment.
prompt
prompt     DB_CACHE_SIZE - Use 60% of SGA for OLTP and between 40% and 50% for BI
prompt         Formula: DB_CACHE_SIZE = 0.60 X <SGA Value> = <DB Cache Size value> (OLTP)
prompt         Formula: DB_CACHE_SIZE = 0.50 X <SGA Value> = <DB Cache Size value> (BI)
prompt
prompt     SHARED_POOL_SIZE - Between 10% to 20% of SGA for OLTP and BI
prompt         Formula: SHARED_POOL_SIZE = 0.20 X <SGA Value> = <Shared Pool Size value>
prompt
prompt     SHARED_POOL_SIZE_RESERVED - Between 1% to 5% of SHARED_POOL_SIZE for OLTP and BI:
prompt         Formula: SHARED_POOL_SIZE_RESERVED = 0.05 X <Shared Pool Size value> = <Shared Pool Size Reserved value>
prompt =================================================================================================================
prompt =================================================================================================================
prompt =================================================================================================================

SET FEEDBACK ON;
