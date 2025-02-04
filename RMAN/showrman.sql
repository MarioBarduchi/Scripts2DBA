--#/*************************************************************************************************/
--#/* Script                    : showrman.sql	                                                    */
--#/* Author                    : Mario Barduchi                                                    */
--#/* E-mail                    : mario.barduchi@gmail.com                                          */
--#/* Date                      : 07/07/2011                                                        */
--#/* Original                  : None                                                              */
--#/* Description               : RMAN info - Task status, Backup level, archives                   */
--#/* Location                  : /home/oracle/SCRIPTS2DBA                                          */
--#/* Responsibility            : DBA                                                               */
--#/* External Parameters       :                                                                   */
--#/* Changes Made              :                                                                   */
--#/*                               07/07/11 (Mario Barduchi) - Script creation.                    */
--#/*                               02/04/13 (Mario Barduchi) - Backup full list.                   */
--#/*                               15/02/24 (Mario Barduchi) - Querys rewrite.                     */
--#/* Observations              :                                                                   */
--#/*                             Some queries were basesd on:                                      */
--#/*                             http://www.pythian.com/blog/viewing-rma-jobs-status-and-output/   */
--#/*************************************************************************************************/
@../CONFSQL/confsql.sql
SET FEEDBACK OFF
set COLSEP "|"

-- Altera o modo de otimizacao devido a BUG 5247609 (NOTES 5247609.8 e 375386.1)
ALTER SESSION SET OPTIMIZER_MODE=RULE;

COL dbid        		            FOR 999999999999 HEADING "DBID";
COL oper        		            FOR a25 		 HEADING "OPERATION";
COL name				            FOR a50 		 HEADING "PARAMETER";
COL value				            FOR a90 		 HEADING "RMAN CONFIGURATION";
COL session_key			            FOR 999999		 HEADING "SESSION";	 
COL operation      		            FOR a19 		 HEADING "OPERATION";
COL input_type			            FOR a12			 HEADING "OPER. TYPE";
COL status        		            FOR a25 		 HEADING "STATUS";
COL optimized      		            FOR a05 		 HEADING "OPT";
COL start_time			            FOR a22	 		 HEADING "START TIME";
COL end_time			            FOR a22			 HEADING "END TIME";
COL time_taken			            FOR a11			 HEADING "TIME TAKEN";
COL input_size			            FOR a11			 HEADING "INPUT SIZE";
COL output_size			            FOR a11			 HEADING "OUTPUT SIZE";
COL input_size_sec  	            FOR a11			 HEADING "INPUT RATE|(PER SEC)";
COL output_size_sec  	            FOR a11			 HEADING "OUTPUT RATE|(PER SEC)";
COL dev         		            FOR a08 TRUNC	 HEADING "DEVICE";
COL compression_ratio 	            FOR 9,999,999    HEADING "COMP. RATIO|(MB PER SEC)";
COL spfile_included 	            FOR a10		 	 HEADING "SPFILE";
COL completion_time					 	             HEADING "DURATION";	
COL handle				            FOR a80		     HEADING "LOCAL";
COL type 				            FOR a20			 HEADING "TYPE";	
COL records_total 						             HEADING "TOTAL RECORD'S";	
COL records_used 						             HEADING "TOTAL USED";	
COL name_database 		            FOR a15			 HEADING "INSTANCE NAME";	
COL session_recid                   FOR 999999       HEADING "RECID"; 
COL session_stamp                   FOR 99999999999  HEADING "SESSION|STAMP";
COL cfile                           FOR 9,999        HEADING "CF";
COL datafile_full                   FOR 9,999        HEADING "DF";
COL level0                          FOR 9,999        HEADING "L0";
COL level1                          FOR 9,999        HEADING "L1";
COL archives_included               FOR 9,999        HEADING "ARC";
COL time_taken_display              FOR a10          HEADING "TIME|TAKEN";
COL output_instance                 FOR 9999         HEADING "OUT|INST";
COL backup_type                     FOR a25          HEADING "BKP TYPE";
COL controlfile_included                             HEADING "CF INC";
COL incremental_level                                HEADING "LEVEL";
COL pieces                          FOR 9999         HEADING "PCS";
COL compressed                      FOR a4           HEADING "COMPRESS";
COL input_file_scan_only            FOR a4           HEADING "SCAN|ONLY";
COL input_bytes_per_sec_display     FOR 9,999,999    HEADING "INPUT|(MB PER SEC)";
COL output_bytes_per_sec_display    FOR 9,999,999    HEADING "OUTPUT|(MB PER SEC)";

ACCEPT NUMBER_OF_DAYS NUM FORMAT 999 DEFAULT '7' PROMPT 'Enter the number of days back to look >> '

prompt
prompt ============================================================================
prompt DBID
prompt ============================================================================
SELECT 
	INST_ID, 
	DBID, 
	NAME AS NAME_DATABASE 
FROM 
	gv$database
ORDER BY
	INST_ID;
      

prompt
prompt ============================================================================
prompt LIST RMAN PARAMETERs
prompt ============================================================================
SELECT  
	NAME,
	VALUE 
FROM  
	V$RMAN_CONFIGURATION
ORDER BY 
	NAME;

prompt
prompt ============================================================================
prompt LIST RMAN - SUMMARY
prompt ============================================================================
SELECT 
	CTIME                                                              as "Date", 
	DECODE(BACKUP_TYPE, 'L', 'BKP contains ArchiveLog', 
                        'D', 'BKP Datafile Full', 
                        'Incremental BKP - L'||INCREMENTAL_LEVEL)      as backup_type,
    BSIZE                                                              as "Size (MB)"
FROM (
		SELECT
			TRUNC(bp.COMPLETION_TIME)           as ctime, 
			bs.BACKUP_TYPE, 
			ROUND(SUM(bp.BYTES/1024/1024),2)    as bsize,
            bs.INCREMENTAL_LEVEL
		FROM V$BACKUP_SET bs, V$BACKUP_PIECE bp
		WHERE 
			bs.SET_STAMP = bp.SET_STAMP AND 
			bs.SET_COUNT = bp.SET_COUNT AND 
			bp.STATUS = 'A' AND
            TRUNC(bp.COMPLETION_TIME) > trunc(SYSDATE)-&NUMBER_OF_DAYS 
		GROUP BY 
			TRUNC(bp.COMPLETION_TIME), bs.BACKUP_TYPE, bs.INCREMENTAL_LEVEL
	 )
ORDER BY 1 DESC, 2 DESC;

prompt
prompt ============================================================================
prompt LIST BACKUPs - LAST &NUMBER_OF_DAYS DAYS
prompt ============================================================================
SELECT
    j.SESSION_RECID, 
    j.SESSION_STAMP,
    j.INPUT_TYPE,
    DECODE(j.INPUT_TYPE, 'ARCHIVELOG',      'BACKUP - ArchiveLog',
						 'DB FULL',         'BACKUP - Full',
						 'RECVR AREA',      'Recovery Area',
						 'DATAFILE FULL',   'BACKUP - Full',
						 'DATAFILE INCR',   'Datafile Incr - L'||x.INCREMENTAL_LEVEL,
						 'CONTROLFILE',     'Controlfile',
						 'SPFILE',          'SPFile',
                         'BACKUP - L'||x.INCREMENTAL_LEVEL) as backup_type,
    j.STATUS, 
    DECODE(TO_CHAR(j.START_TIME, 'd'),  1, 'Sun',   
                                        2, 'Mon',
                                        3, 'Tue',  
                                        4, 'Wed',
                                        5, 'Thu', 
                                        6, 'Fri',
                                        7, 'Sat')   as dow,
    TO_CHAR(j.START_TIME, 'YYYY-MM-DD HH24:mi:ss')  as start_time,
    TO_CHAR(j.END_TIME  , 'YYYY-MM-DD HH24:mi:ss')  as end_time,
    j.TIME_TAKEN_DISPLAY							as time_taken,
    j.INPUT_BYTES_DISPLAY 							as input_size,
    j.OUTPUT_BYTES_DISPLAY 							as output_size,
    j.INPUT_BYTES_PER_SEC_DISPLAY 					as input_size_sec,
    j.OUTPUT_BYTES_PER_SEC_DISPLAY                  as output_size_sec,
    x.COMPRESSED,
    j.COMPRESSION_RATIO,
    j.OUTPUT_DEVICE_TYPE							as dev
FROM V$RMAN_BACKUP_JOB_DETAILS j
LEFT JOIN (SELECT 
                d.SESSION_RECID    , d.SESSION_STAMP, 
                d.BACKUP_TYPE      , d.CONTROLFILE_INCLUDED, 
                d.INCREMENTAL_LEVEL, d.PIECES,
                 d.COMPRESSED
           FROM V$BACKUP_SET_DETAILS d
           JOIN V$BACKUP_SET s ON 
                s.set_stamp = d.set_stamp AND 
                s.set_count = d.set_count
           WHERE s.input_file_scan_only = 'NO'
           GROUP BY d.SESSION_RECID, d.SESSION_STAMP, d.BACKUP_TYPE, d.CONTROLFILE_INCLUDED, d.INCREMENTAL_LEVEL, d.PIECES, d.COMPRESSED
		  ) x
    ON  x.SESSION_RECID = j.SESSION_RECID AND 
        x.SESSION_STAMP = j.SESSION_STAMP
LEFT JOIN (SELECT 
                rs.COMMAND_ID, rs.OPERATION, 
                rs.OBJECT_TYPE 
           FROM V$RMAN_STATUS rs 
		   WHERE rs.OPERATION NOT IN ('CATALOG','LIST','RMAN','CROSSCHECK','REPORT SCHEMA')
          ) rs
	ON rs.COMMAND_ID = j.COMMAND_ID
WHERE
    rs.OBJECT_TYPE LIKE 'DB%'
GROUP BY
	j.SESSION_RECID, j.SESSION_STAMP, j.STATUS, j.START_TIME, j.END_TIME, j.TIME_TAKEN_DISPLAY,
	j.INPUT_TYPE, j.INPUT_BYTES_DISPLAY, j.OUTPUT_BYTES_DISPLAY, j.INPUT_BYTES_PER_SEC_DISPLAY, j.OUTPUT_BYTES_PER_SEC_DISPLAY, j.OUTPUT_DEVICE_TYPE,j.COMPRESSION_RATIO,rs.OPERATION, rs.OBJECT_TYPE, x.INCREMENTAL_LEVEL, x.COMPRESSED
HAVING 
    MAX(TRUNC(j.START_TIME)) > TRUNC(SYSDATE)-&NUMBER_OF_DAYS 
ORDER BY j.START_TIME DESC;

prompt
prompt ============================================================================
prompt ALL OPERATIONS - LAST &NUMBER_OF_DAYS DAYS
prompt ============================================================================
prompt INPUT SIZE              ==> Sum of all input file sizes backed up by this job.
prompt OUTPUT SIZE             ==> Output size of all pieces generated by this job.
prompt INPUT RATE|(PER SEC)    ==> Input read-rate-per-second. Because of RMAN compression.
prompt OUTPUT RATE|(PER SEC)   ==> The OUTPUT RATE|(PER SEC) cannot be used as measurement of backup speed. The appropriate column to measure backup speed is INPUT RATE (PER SEC).
prompt CF                      ==> Number of controlfile backups included in the backup set.
prompt DF                      ==> Number of datafile full backups included in the backup set.
prompt L0                      ==> Number of datafile incremental Level 0 backups included in the backup set.
prompt L1                      ==> Number of datafile incremental Level 1 backups included in the backup set.
prompt ARC                     ==> Number of archived log backups included in the backup set.
prompt INSTANCE                ==> Instance where the job was executed and the output is available. 
prompt COMP. RATIO|(MB PER SEC)==> The ratio between read and written data.
prompt ============================================================================
SELECT
    j.SESSION_RECID, 
    j.SESSION_STAMP,
    j.INPUT_TYPE,
    DECODE(j.INPUT_TYPE, 'ARCHIVELOG',      'BACKUP - ArchiveLog',
						 'DB FULL',         'BACKUP - Full',
						 'RECVR AREA',      'Recovery Area',
						 'DATAFILE FULL',   'BACKUP - Full',
						 'DATAFILE INCR',   'Datafile Incr - L'||xx.INCREMENTAL_LEVEL,
						 'CONTROLFILE',     'Controlfile',
						 'SPFILE',          'SPFile',
                         'BACKUP - L'||xx.INCREMENTAL_LEVEL) as backup_type,
	j.STATUS, 
    DECODE(TO_CHAR(j.START_TIME, 'd'),  1, 'Sun',   
                                        2, 'Mon',
                                        3, 'Tue',  
                                        4, 'Wed',
                                        5, 'Thu', 
                                        6, 'Fri',
                                        7, 'Sat')   as dow,
    TO_CHAR(j.START_TIME, 'YYYY-MM-DD HH24:mi:ss')  as start_time,
    TO_CHAR(j.END_TIME  , 'YYYY-MM-DD HH24:mi:ss')  as end_time,
    j.TIME_TAKEN_DISPLAY							as time_taken,
    j.INPUT_BYTES_DISPLAY 							as input_size,
    j.OUTPUT_BYTES_DISPLAY 							as output_size,
    j.INPUT_BYTES_PER_SEC_DISPLAY 					as input_size_sec,
    j.OUTPUT_BYTES_PER_SEC_DISPLAY                  as output_size_sec,
    x.CFILE, 
	x.DATAFILE_FULL, 
	x.LEVEL0, 
	x.LEVEL1, 
	x.ARCHIVES_INCLUDED,
	xx.INCREMENTAL_LEVEL                       as incremental_level,  
    ro.INST_ID                                      as instance,
    SUM(xx.PIECES)                                  as pieces,
    xx.COMPRESSED,
    j.COMPRESSION_RATIO,							
    j.OUTPUT_DEVICE_TYPE							as dev
FROM V$RMAN_BACKUP_JOB_DETAILS j
LEFT JOIN (SELECT
                d.SESSION_RECID, 
                d.SESSION_STAMP, 
				SUM(CASE WHEN d.CONTROLFILE_INCLUDED = 'YES' THEN d.PIECES ELSE 0 END)                                              as cfile,
				SUM(CASE WHEN d.CONTROLFILE_INCLUDED = 'NO' AND d.BACKUP_TYPE||d.INCREMENTAL_LEVEL = 'D' THEN d.PIECES ELSE 0 END)  as datafile_full,
				SUM(CASE WHEN d.BACKUP_TYPE||d.INCREMENTAL_LEVEL = 'I0' THEN d.PIECES ELSE 0 END)                                   as level0,
				SUM(CASE WHEN d.BACKUP_TYPE||d.INCREMENTAL_LEVEL = 'I1' THEN d.PIECES ELSE 0 END)                                   as level1,
				SUM(CASE WHEN d.BACKUP_TYPE = 'L' THEN d.PIECES ELSE 0 END)                                                         as archives_included
	       FROM V$BACKUP_SET_DETAILS d
	       JOIN V$BACKUP_SET s ON s.SET_STAMP = d.SET_STAMP AND 
                                  s.SET_COUNT = d.SET_COUNT
	       WHERE s.INPUT_FILE_SCAN_ONLY = 'NO'
	       GROUP BY d.SESSION_RECID, 
                    d.SESSION_STAMP
          ) x
ON x.SESSION_RECID = j.SESSION_RECID AND 
   x.SESSION_STAMP = j.SESSION_STAMP
LEFT JOIN (SELECT 
                dd.SESSION_RECID, 
                dd.SESSION_STAMP, 
				dd.BACKUP_TYPE, 
                dd.INCREMENTAL_LEVEL, 
                SUM(dd.PIECES)          as pieces,
				dd.COMPRESSED
           FROM V$BACKUP_SET_DETAILS dd
           JOIN V$BACKUP_SET ss ON ss.SET_STAMP = dd.SET_STAMP AND 
                                   ss.SET_COUNT = dd.SET_COUNT
           WHERE ss.INPUT_FILE_SCAN_ONLY = 'NO'
           GROUP BY dd.SESSION_RECID, 
                    dd.SESSION_STAMP,
			        dd.BACKUP_TYPE, 
                    dd.INCREMENTAL_LEVEL, 
                    dd.COMPRESSED
		 ) xx
ON  xx.SESSION_RECID = j.SESSION_RECID AND 
    xx.SESSION_STAMP = j.SESSION_STAMP
LEFT JOIN (SELECT  
                o.SESSION_RECID, 
                o.SESSION_STAMP,
                MIN(INST_ID)    as inst_id
           FROM GV$RMAN_OUTPUT o
           GROUP BY o.SESSION_RECID, 
                    o.SESSION_STAMP
          ) ro 
ON ro.SESSION_RECID = j.SESSION_RECID AND 
   ro.SESSION_STAMP = j.SESSION_STAMP
WHERE 
    TRUNC(j.START_TIME) > TRUNC(SYSDATE)-&NUMBER_OF_DAYS 
GROUP BY
    j.SESSION_RECID, 
    j.SESSION_STAMP,
    j.INPUT_TYPE,
    j.STATUS, 
    j.START_TIME,
    j.END_TIME  ,
    j.TIME_TAKEN_DISPLAY,
    j.INPUT_BYTES_DISPLAY,
    j.OUTPUT_BYTES_DISPLAY,
    j.INPUT_BYTES_PER_SEC_DISPLAY,
	j.OUTPUT_BYTES_PER_SEC_DISPLAY,
    x.CFILE, 
	x.DATAFILE_FULL, 
	x.LEVEL0, 
	x.LEVEL1, 
	x.ARCHIVES_INCLUDED,
	ro.inst_id,
    xx.COMPRESSED,
	xx.INCREMENTAL_LEVEL ,
    j.COMPRESSION_RATIO,
    j.OUTPUT_DEVICE_TYPE
ORDER BY j.START_TIME DESC;


prompt
prompt ============================================================================
prompt BACKUP RECORD IN CONTROLFILES
prompt ============================================================================
SELECT 
	type, 
	records_total, 
	records_used
FROM 
	v$controlfile_record_section
WHERE 
	type LIKE '%BACKUP%';	
		
prompt
prompt ============================================================================
prompt AUTOBACKUP - CONTROLFILES AND SPFILES - Last 3 days
prompt ============================================================================
SELECT 
	bs.recid, 
	sp.spfile_included, 
	TO_CHAR(bs.completion_time, 'dd/mm/yyyy HH24:MI:SS') completion_time, 
	DECODE(status, 'A', 'Available', 'D', 'Deleted', 'X', 'Expired') status, 
	handle
FROM 
	v$backup_set  bs, v$backup_piece  bp, 
	(select distinct 
		set_stamp, 
		set_count, 
		'YES' spfile_included
	 from 
		v$backup_spfile) sp
WHERE 
	bs.set_stamp = bp.set_stamp AND 
	TRUNC(bs.completion_time) > trunc(sysdate)-&NUMBER_OF_DAYS AND 
	bs.set_count = bp.set_count AND 
	bp.status IN ('A', 'X') AND 
	bs.set_stamp = sp.set_stamp AND 
	bs.set_count = sp.set_count
ORDER BY  
	bs.completion_time desc, bs.recid, piece#;
	
ALTER SESSION SET OPTIMIZER_MODE=ALL_ROWS;
SET FEEDBACK ON
SET VERIFY ON