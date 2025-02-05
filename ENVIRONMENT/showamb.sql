--#/*********************************************************************************************/
--#/* Script                    : showamb.sql                                                   */
--#/* Autor                     : Jose Mario Barduchi                                           */
--#/* E-mail                    : mario.barduchi@gmail.com                                      */
--#/* Data                      : 17/01/2017                                                    */
--#/* Original                  : Sr. Fabio Telles                                              */
--#/* Descricao                 : Coleta informacoes do ambiente                                */
--#/* Localizacao               : /home/oracle/DBA/sql                                          */
--#/* Responsabilidade          : DBA-Executado com usuario SYS                                 */
--#/* Parametros Externos       : Nao Ha                                                        */
--#/* Alteracoes Efetuadas      :                                                               */
--#/*                            Acrescimo de algumas verificacoes e informacoes                */
--#/*                            Alteracao de algumas tabelas fontes                            */
--#/*                            Acertos gerais                                                 */
--#/*                            Adicionada a area de upgrade                                   */
--#/* Observacoes               :                                                               */
--#/*    Baseado no script do Sr. Fabio Telles encontrado abaixo                                */
--#/*    http://www.midstorm.org/~telles/2010/05/13/coletando-informacoes-de-uma-base-oracle/   */
--#/*********************************************************************************************/
SET serveroutput ON SIZE 1000000 FORMAT WRAPPED
SET autotrace    OFF
SET feedback     OFF
SET wrap         OFF
SET trimspool    ON
SET pagesize     100
SET linesize     200
SET VERIFY 		 OFF

ALTER SESSION SET NLS_DATE_FORMAT = 'DD-MON-YYYY HH24:MI:SS';

-- Spool: Nome da base + data
column filename   new_val filename
select 'SNAPSHOT_'||name||'_'|| to_char(sysdate, 'yyyymmdd')||'.rpt' as filename from v$database;
--spool /tmp/&filename

 
DECLARE
	v_media_archive   NUMBER;
	v_spfile          VARCHAR(10);
	v_name            v$database.db_unique_name%TYPE;
	v_log_mode        v$database.log_mode%TYPE;
	v_data		  	  DATE;
	v_version		  NUMBER;

BEGIN
	SELECT SUBSTR(&_O_RELEASE,1) INTO v_version from dual;
	
	SELECT DECODE(COUNT(*),0,'PFILE','SPFILE') INTO v_spfile FROM v$spparameter
	WHERE isspecified != 'FALSE';

	SELECT db_unique_name,log_mode,sysdate INTO v_name,v_log_mode,v_data FROM v$database;

	-- Pula uma linha
	dbms_output.put_line(chr(10));

	dbms_output.put_line('===============================================================================');
	dbms_output.put_line('Informacoes da(s) INSTANCE(s) do database: ' || v_name || ' (' || v_data || ')');
	dbms_output.put_line('===============================================================================');
	dbms_output.put_line('');
		
	for lst in ( SELECT distinct dbid, db_unique_name, created, resetlogs_time, log_mode FROM gv$database) loop
		dbms_output.put_line('DBID.............: ' || lst.dbid);
		dbms_output.put_line('Unique Name......: ' || lst.db_unique_name);
		dbms_output.put_line('DB Created.......: ' || to_char(lst.created,'DD/MM/YYYY HH:MM:SS'));
		dbms_output.put_line('Last ResetLogs...: ' || to_char(lst.resetlogs_time,'DD/MM/YYYY HH:MM:SS'));
		dbms_output.put_line('Archive Mode.....: ' || lst.log_mode);
	end loop;
  
	dbms_output.put_line('Inicializado com.: ' || v_spfile);
	dbms_output.put_line('.........................................');
  
	for lst in (select THREAD#, INSTANCE_NUMBER, INSTANCE_NAME, VERSION, STATUS, STARTUP_TIME, HOST_NAME from gv$instance order by INSTANCE_NUMBER) loop
		dbms_output.put_line('Instance ID......: ' || lst.instance_number);
		dbms_output.put_line('Instance name....: ' || lst.instance_name);
		dbms_output.put_line('DB Version.......: ' || lst.version);
		dbms_output.put_line('Status...........: ' || lst.status);
		dbms_output.put_line('Hostname.........: ' || lst.host_name);
		dbms_output.put_line('Last Startup.....: ' || lst.startup_time);
		dbms_output.put_line('.........................................');
	end loop;
  
	for lst in (select * from database_properties) loop
		if lst.property_name = 'DEFAULT_TEMP_TABLESPACE' then
			dbms_output.put_line('Temp default.....: ' || lst.property_value);
		end if;
	end loop;

	for lst in (select global_name from global_name) loop
		dbms_output.put_line('Global name......: ' || lst.global_name);
	end loop;

	for lst in (SELECT distinct ((length(addr)*4)||'-Bits') as version FROM v$process) loop
		dbms_output.put_line('OS Version.......: ' || lst.version);
	end loop;

	for lst in (select distinct PLATFORM_NAME from gv$database) loop
		dbms_output.put_line('Plataforma.......: ' || lst.platform_name);
	end loop;

	dbms_output.put_line('.........................................');	
	dbms_output.put_line('Database Version.:');
	
	for lst in (select min(inst_id) as inst_id, substr(banner,1,60) version from gv$version group by substr(banner,1,60) order by substr(banner,1,60)) loop
		dbms_output.put_line('.................: ' || lst.version);
	end loop;

	
    IF v_version >= 12 THEN

		dbms_output.put_line('');
		dbms_output.put_line('======================================');
		dbms_output.put_line('PDBs: ');
		dbms_output.put_line('======================================');
		dbms_output.put_line('     CON ID    |     DBID      |     Name      |   Open Mode   |  Restricted   |      Open Time     ');
		dbms_output.put_line('---------------|---------------|---------------|---------------|---------------|--------------------');
	  
	  
		FOR showpdb IN (SELECT 
							RPAD(c.CON_ID,15) 		as CON_ID,
							RPAD(c.DBID,15)			as DBID, 
							RPAD(c.NAME,15)			as NAME, 
							--RPAD(c.CON_UID,30)	as CON_UID, 
							--RPAD(c.GUID,30)		as GUID,
							RPAD(NVL(p.OPEN_MODE,  ' '), 15,' ')	as OPEN_MODE, 
							RPAD(NVL(p.RESTRICTED, ' '), 15,' ')	as RESTRICTED, 
							RPAD(NVL(to_char(p.OPEN_TIME,'DD/MM/YYYY HH:MM:SS'), ' '), 20, ' ')	as OPEN_TIME
						FROM 
							V$CONTAINERS c
						LEFT JOIN V$PDBS p ON
							p.CON_ID = c.CON_ID
						ORDER BY 
							c.CON_ID
					  ) LOOP
			--dbms_output.put_line(showpdb.CON_ID || '|' || showpdb.DBID || '|' || showpdb.NAME || '|' || showpdb.CON_UID || '|' || showpdb.GUID || '|' || showpdb.OPEN_MODE || '|' || showpdb.RESTRICTED || '|' || showpdb.OPEN_TIME);
			dbms_output.put_line(showpdb.CON_ID || '|' || showpdb.DBID || '|' || showpdb.NAME || '|' || showpdb.OPEN_MODE || '|' || showpdb.RESTRICTED || '|' || showpdb.OPEN_TIME);
		END LOOP;
	END IF;
	
	
	
	dbms_output.put_line('');
	dbms_output.put_line('======================================');
	dbms_output.put_line('Atualizacoes/Upgrade: ');
	dbms_output.put_line('======================================');
	dbms_output.put_line('             Action Name           |     Action    |  Versao  |        Comments         |   ID   ');
	dbms_output.put_line('-----------------------------------|---------------|----------|-------------------------|--------');
  
    FOR atuupg IN (SELECT 
						RPAD(NVL(to_char(ACTION_TIME,'DD/MM/YYYY HH:MM:SS'),' '),35,' ') 	as ACTION_TIME,
						RPAD(NVL(ACTION,' '),15,' ') 		as ACTION,
						RPAD(NVL(VERSION,' '),10,' ')		as VERSION, 
						RPAD(NVL(COMMENTS,' '),25,' ')		as COMMENTS, 
						RPAD(ID,8)							as ID 
					FROM 
						dba_registry_history 
					ORDER BY 
						action_time ASC
				  ) LOOP
		dbms_output.put_line(atuupg.ACTION_TIME || '|' || atuupg.ACTION || '|' || atuupg.VERSION || '|' || atuupg.COMMENTS || atuupg.ID);
	END LOOP;

	dbms_output.put_line('');
	dbms_output.put_line('=======================================================================================');
	dbms_output.put_line('                           Options/Feature ativas no database');
	dbms_output.put_line('Importante: Normalmente, mas nem sempre, as OPTIONS devem ser adquiridas separadamente,');
	dbms_output.put_line('            enquanto as features ja sao fornecidas com a versao adquirida do banco.');
	dbms_output.put_line('=======================================================================================');
	
	
	dbms_output.put_line('');
	dbms_output.put_line('======================================');
	dbms_output.put_line('Options/Features: ');
	dbms_output.put_line('======================================');
	 
	FOR options IN (SELECT INST_ID , UPPER(parameter) AS PARAMETER FROM gv$option WHERE VALUE = 'TRUE' ORDER BY INST_ID, PARAMETER) LOOP
		dbms_output.put_line('A option/feature "' || options.parameter  || '" esta ativa - thread '|| options.inst_id ||'.');
	END LOOP;
	
	dbms_output.put_line('');
	dbms_output.put_line('======================================');
	dbms_output.put_line('Componentes instalados: ');
	dbms_output.put_line('======================================');
	dbms_output.put_line('   ID     |                       Nome                       |    Versao     |     Status    |         Data         | Schema');
	dbms_output.put_line('----------|--------------------------------------------------|---------------|---------------|----------------------|---------');
  
	FOR registry IN (SELECT
					RPAD(comp_id,10) AS comp_id, 
					RPAD(comp_name,50) AS comp_name, 
					RPAD(version,15) AS version, 
					RPAD(status,15) as status, 
					RPAD(modified,22) AS modified, 
					RPAD(schema,15) AS schema 
					FROM dba_registry) 
				LOOP
		dbms_output.put_line(registry.comp_id  || '|' || registry.comp_name  || '|' || registry.version  || '|' || registry.status  || '|' || registry.modified  || '|' || registry.schema);
	END LOOP;

	dbms_output.put_line('');
	dbms_output.put_line('======================================');
	dbms_output.put_line('Registro de utilizacao de features: ');
	dbms_output.put_line('======================================');
	dbms_output.put_line('                               Feature                           |  Version   |Usages|Cur. Used | Last Usage | Fisrt Usage');
	dbms_output.put_line('-----------------------------------------------------------------|------------|------|----------|------------|-------------');

	FOR optusage IN (
					select
						RPAD(substr(u1.name,1,60),65)               	   as name,
						RPAD(substr(u1.version,1,10),12)                   as version,
						RPAD(u1.detected_usages,6)                         as detected_usages,
						RPAD(substr(u1.currently_used,1,5),10)             as currently_used,
						RPAD(TO_CHAR(u1.last_usage_date,'DD/MM/YYYY'),12)  as last_usage_date,
						RPAD(TO_CHAR(u1.first_usage_date,'DD/MM/YYYY'),12) as first_usage_date
					FROM DBA_FEATURE_USAGE_STATISTICS u1
					WHERE 
						version = (SELECT MAX(u2.version)
								   FROM   dba_feature_usage_statistics u2
								   WHERE  u2.name = u1.name)
					AND u1.detected_usages > 0
					ORDER BY u1.name, u1.version, u1.last_usage_date desc, u1.first_usage_date desc
	) LOOP
		dbms_output.put_line(optusage.name || '|' || optusage.version || '|' || optusage.detected_usages || '|' || optusage.currently_used || '|' || optusage.first_usage_date || '|' || optusage.last_usage_date);
	END LOOP;
	
	dbms_output.put_line('');
	dbms_output.put_line('========================================================================================');
	dbms_output.put_line('Para mais detalhes, executar o script options_packs_usage_statistics.sql (MOS 1317265.1)');
	dbms_output.put_line('========================================================================================');
	
	dbms_output.put_line('');
	dbms_output.put_line('');
	dbms_output.put_line('=============================');
	dbms_output.put_line('Limites utilizados na Istance');
	dbms_output.put_line('=============================');
	dbms_output.put_line('Instance |   Sessoes  |  Usuarios   |   CPUs  |  Cores  ');
	dbms_output.put_line('---------|------------|-------------|---------|---------');

	FOR license IN (
					SELECT
					RPAD(inst_id,8) inst_id,
					RPAD(sessions_max,10) AS sessions,
					RPAD(users_max,11) AS users,
					RPAD(NVL(cpu_core_count_highwater,0),7) AS cpu,
					RPAD(NVL(cpu_socket_count_highwater,0),7) AS socket
					FROM  gv$license
					ORDER BY inst_id
					) LOOP
		dbms_output.put_line(license.inst_id || ' | ' || license.sessions || ' | ' || license.users || ' | ' || license.cpu || ' | ' || license.socket);
	END LOOP;

	dbms_output.put_line('');
	dbms_output.put_line('');
	dbms_output.put_line('===============================');
	dbms_output.put_line('Parametros de Localizacao (NLS)');
	dbms_output.put_line('===============================');
	dbms_output.put_line('ID | Parametro                                          | Valor');
    dbms_output.put_line('---|----------------------------------------------------|---------------------------------');
    FOR nls IN (
				SELECT
					'  ' AS INST_ID,
					RPAD('DATABASE:',50)    AS NAME,
					' '                     AS VALUE
				FROM DUAL
				UNION ALL
				SELECT
					'  ' AS INST_ID,
					RPAD(PROPERTY_NAME || '(DATABASE)',50)  AS NAME,
					PROPERTY_VALUE                          AS VALUE
				FROM database_properties
				WHERE property_name IN (
					'NLS_CHARACTERSET',
					'NLS_DATE_FORMAT',
					'NLS_LANGUAGE',
					'NLS_DATE_LANGUAGE',
					'NLS_NUMERIC_CHARACTERS',
					'NLS_TERRITORY',
					'DBTIMEZONE')
				UNION ALL
				SELECT
					'  ' AS INST_ID,
					RPAD('SESSION:',50)     AS NAME,
					' '                     AS VALUE
				FROM DUAL
				UNION ALL
				SELECT
					TO_CHAR(INST_ID,9) AS INST_ID,
					RPAD(PARAMETER || '(SESSION)',50)       AS NAME,
					VALUE                                   AS VALUE
				FROM GV$NLS_PARAMETERS
				WHERE PARAMETER IN (
					'NLS_DATE_LANGUAGE',
					'NLS_DATE_FORMAT',
					'NLS_LANGUAGE',
					'NLS_TERRITORY')
				ORDER BY NAME,INST_ID
				) LOOP
		dbms_output.put_line(nls.inst_id || ' | ' || nls.name || ' | ' || nls.value);
    END LOOP;

	dbms_output.put_line('');
	dbms_output.put_line('');
	dbms_output.put_line('=======================================');
	dbms_output.put_line('Parametros de Memoria da Instance(s)');
	dbms_output.put_line('=======================================');
	dbms_output.put_line('ID Parametro                                           | Valor (MB)');
    dbms_output.put_line('--|----------------------------------------------------|---------------------------------');

	FOR mem IN (
				SELECT
				INST_ID,	
				RPAD(name,50) AS parameter, 
				ROUND(VALUE/1024/1024) AS valor_mb
				FROM gv$parameter
				WHERE name IN (
				'db_cache_size',
				'large_pool_size',
				'java_pool_size',
				'sga_max_size',
				'sga_target',
				'shared_pool_size',
				'pga_aggregate_target',
				'memory_target',
				'memory_max_target')
				ORDER BY name,inst_id
				) LOOP
		dbms_output.put_line(mem.inst_id || ' | ' || mem.parameter || ' | ' || mem.valor_mb);
	END LOOP;

	dbms_output.put_line('');
	dbms_output.put_line('');
	dbms_output.put_line('=======================================');
	dbms_output.put_line('Parametros principais da Instance(s)');
	dbms_output.put_line('=======================================');
	dbms_output.put_line('ID Parametro                                           | Valor');
	dbms_output.put_line('--|----------------------------------------------------|---------------------------------');

	FOR mem IN (
						SELECT
						INST_ID,
						RPAD(name,50) AS parameter,
						VALUE AS valor_mb
						FROM gv$parameter
						WHERE name IN (
						'sessions',
						'processes',
						'open_cursors',
						'cursor_sharing',
						'audit_file_dest',
						'audit_syslog_level',
						'audit_sys_operations',
						'audit_trail',
						'background_dump_dest',
						'cluster_database',
						'cluster_database_instances',
						'cluster_interconnects',
						'compatible',
						'control_files',
						'control_management_pack_access',
						'core_dump_dest',
						'cursor_sharing',
						'db_block_size',
						'db_cache_size',
						'db_create_file_dest',
						'db_create_online_log_dest_1',
						'db_create_online_log_dest_2',
						'db_file_multiblock_read_count',
						'db_file_name_convert',
						'db_flashback_retention_target',
						'db_flash_cache_file',
						'db_flash_cache_size',
						'db_name',
						'db_recovery_file_dest',
						'db_recovery_file_dest_size',
						'db_unique_name',
						'dg_broker_config_file1',
						'dg_broker_config_file2',
						'dg_broker_start',
						'diagnostic_dest',
						'enable_ddl_logging',
						'enable_goldengate_replication',
						'global_names',
						'instance_name',
						'instance_number',
						'job_queue_processes',
						'listener_networks',
						'local_listener',
						'log_archive_dest_1',
						'log_archive_format',
						'recyclebin',
						'remote_listener',
						'service_names',
						'spfile',
						'undo_management',
						'undo_retention')
						ORDER BY name,inst_id
						) LOOP
		dbms_output.put_line(mem.inst_id || ' | ' || mem.parameter || ' | ' || mem.valor_mb);
	END LOOP;
	
	dbms_output.put_line('');
	dbms_output.put_line('');
	dbms_output.put_line('=====================================');
	dbms_output.put_line('Informacoes Gerais do tamanho da base');
	dbms_output.put_line('=====================================');
	dbms_output.put_line('   Dados   |     Undo   |    Redos   |    Temp    |   Livre    |   Total   ' );
	dbms_output.put_line('-----------|------------|------------|------------|------------|------------');
	
	FOR tam IN (
				select 	LPAD(to_char(sum(dados) / 1048576, 'fm99g999g990'),10,' ') dados,
						LPAD(to_char(sum(undo) / 1048576,  'fm99g999g990'),10,' ') undo,
						LPAD(to_char(sum(redo) / 1048576,  'fm99g999g990'),10,' ') redo,
						LPAD(to_char(sum(temp) / 1048576,  'fm99g999g990'),10,' ') temp,
						LPAD(to_char(sum(free) / 1048576,  'fm99g999g990'),10,' ') livre,
						LPAD(to_char(sum(dados + undo + redo + temp) / 1048576, 'fm99g999g990'),10,' ') total
				from (
				select sum(decode(substr(t.contents, 1, 1), 'P', bytes, 0)) dados,
					 sum(decode(substr(t.contents, 1, 1), 'U', bytes, 0)) undo,
					 0 redo,
					 0 temp,
					 0 free
				from dba_data_files f, dba_tablespaces t
				where f.tablespace_name = t.tablespace_name
				union all
				select 0 dados,
					 0 undo,
					 0 redo,
					 sum(bytes) temp,
					 0 free
				from dba_temp_files f, dba_tablespaces t
				where f.tablespace_name = t.tablespace_name(+)
				union all
				select 0 dados,
					 0 undo,
					 sum(bytes * members) redo,
					 0 temp,
					 0 free
				from v$log
				union all
				select 0 dados,
					 0 undo,
					0 redo,
					 0 temp,
					 sum(bytes) free
				from dba_free_space f, dba_tablespaces t
				where f.tablespace_name = t.tablespace_name and
					substr(t.contents, 1, 1) = 'P'
					)
	) LOOP
		dbms_output.put_line(tam.dados  || ' | ' ||
						     tam.undo   || ' | ' ||
						     tam.redo   || ' | ' ||
						     tam.temp   || ' | ' ||
						     tam.livre  || ' | ' ||
						     tam.total);
	END LOOP;
	
	dbms_output.put_line('');
	dbms_output.put_line('');
	dbms_output.put_line('===========================');
	dbms_output.put_line('Informacoes das tablespaces');
	dbms_output.put_line('===========================');
	dbms_output.put_line('    Tablespace       | T |   Em Uso (MB)   |   Atual (MB)    |   Maximo (MB    | Atual Livre (MB)| Max. Livre (MB)|  % Ocupada' );
	dbms_output.put_line('---------------------|---|-----------------|-----------------|-----------------|-----------------|----------------|-----------------');

	FOR tbs IN (
				select
				   rpad(t.tablespace_name,20) ktablespace,
				   rpad(substr(t.contents, 1, 1),1) tipo,
				   lpad(trunc((d.tbs_size-nvl(s.free_space, 0))/1024/1024),15) ktbs_em_uso,
				   lpad(trunc(d.tbs_size/1024/1024),15)  ktbs_size,
				   lpad(trunc(d.tbs_maxsize/1024/1024),15)  ktbs_maxsize,
				   lpad(trunc(nvl(s.free_space, 0)/1024/1024),15)  kfree_space,
				   lpad(trunc((d.tbs_maxsize - d.tbs_size + nvl(s.free_space, 0))/1024/1024),14) kspace,
				   lpad(decode(d.tbs_maxsize, 0, 0, trunc((d.tbs_size-nvl(s.free_space, 0))*100/d.tbs_maxsize)),7) kperc
				from
					(select SUM(bytes) tbs_size,
					   SUM(decode(sign(maxbytes - bytes), -1, bytes, maxbytes)) tbs_maxsize,
					   tablespace_name tablespace
				from 
					(select nvl(bytes, 0) bytes, nvl(maxbytes, 0) maxbytes, tablespace_name
					   from dba_data_files
					   union all
					   select nvl(bytes, 0) bytes, nvl(maxbytes, 0) maxbytes, tablespace_name
					   from dba_temp_files
					 )
				group by tablespace_name
				) d,
				(select SUM(bytes) free_space,
				 tablespace_name tablespace
				 from dba_free_space
				 group by tablespace_name
				) s,
				dba_tablespaces t
				where t.tablespace_name = d.tablespace(+) and
						t.tablespace_name = s.tablespace(+)
				order by 1
			) LOOP
		dbms_output.put_line(tbs.KTABLESPACE  || ' | ' ||
						     tbs.TIPO         || ' | ' ||
						     tbs.KTBS_EM_USO  || ' | ' ||
						     tbs.KTBS_SIZE    || ' | ' ||
						     tbs.KTBS_MAXSIZE || ' | ' ||
						     tbs.KFREE_SPACE  || ' | ' ||
						     tbs.KSPACE       || ' | ' ||
						     tbs.KPERC);
	END LOOP;

	dbms_output.put_line('');
	dbms_output.put_line('');
	dbms_output.put_line('=========================');
	dbms_output.put_line('Informacoes dos datafiles');
	dbms_output.put_line('=========================');
	dbms_output.put_line(' ID |    Tablespace   |                      Datafile                      |  Extend  |  Status  | Em Uso(MB) | Maximo(MB)' );
	dbms_output.put_line('----|-----------------|----------------------------------------------------|----------|----------|------------|-----------' );
	FOR dataf IN (
					select 
						rpad(a.file_id,3) 						kfile_id,
						rpad(a.tablespace_name,15) 				ktablespace_name,
						rpad(a.file_name,50) 					kfile_name,
						rpad(a.autoextensible,8) 				kautoextensible,
						rpad(b.status,8) 						kstatus,
						rpad(trunc(a.bytes/1024/1024),10) 		kbytes,
						rpad(trunc(a.maxbytes/1024/1024),10)  	kmaxsize						
					from dba_data_files a, v$datafile b
					where a.file_id = b.file#
					order by a.tablespace_name, a.file_id
				) LOOP
				   
		dbms_output.put_line( 
							  dataf.kfile_id 			|| ' | ' ||
							  dataf.ktablespace_name 	|| ' | ' ||
							  dataf.kfile_name 			|| ' | ' ||
							  dataf.kautoextensible 	|| ' | ' ||
							  dataf.kstatus 			|| ' | ' ||
							  dataf.kbytes	 			|| ' | ' ||
							  dataf.kmaxsize
							  );
	END LOOP;			
	
  dbms_output.put_line('');
  dbms_output.put_line(''); 
  dbms_output.put_line('=============================================');
  dbms_output.put_line('Informacoes dos Grupos e Arquivos de REDOLOGs');
  dbms_output.put_line('=============================================');
  dbms_output.put_line('Grupo | Thread | Tamanho (MB) |                        Arquivo');
  dbms_output.put_line('------|--------|--------------|---------------------------------------------------');
 
  FOR log IN (
    SELECT 
	f.GROUP# AS grupo,
	l.THREAD#,	
	ROUND(l.bytes/1024/1024) AS tamanho, 
	f.member AS arquivo
    FROM v$logfile f, v$log l
    WHERE f.GROUP# = l.GROUP#
    ORDER BY grupo, arquivo) LOOP
    	dbms_output.put_line(lpad( log.grupo,5) || ' | ' || lpad( log.thread#,6) || ' | ' || lpad(log.tamanho,12) || ' | ' || log.arquivo);
  END LOOP;

  dbms_output.put_line('');
  dbms_output.put_line(''); 
  dbms_output.put_line('===========================================');
  dbms_output.put_line('Informacoes de Localizacao dos ControlFiles');
  dbms_output.put_line('===========================================');

  FOR control IN ( SELECT name FROM v$controlfile) LOOP
    dbms_output.put_line('Arquivo: ' || control.name);
  END LOOP;
  
  IF v_log_mode = 'ARCHIVELOG' THEN

  	SELECT 
		ROUND(SUM(blocks * block_size) / to_number( MAX(first_time) - MIN(first_time)) /1024/1024) AS media
	INTO v_media_archive
      	FROM V$ARCHIVED_LOG; 

	dbms_output.put_line('');
	dbms_output.put_line('');
	dbms_output.put_line('===============================================');
    dbms_output.put_line('Informacoes Basicas Sobre a Geracao de ARCHIVES');
    dbms_output.put_line('===============================================');
    dbms_output.put_line(' ');
	dbms_output.put_line('Quantidade media de archive gerados por dia: ' || v_media_archive || 'MB');
	dbms_output.put_line(' ');
    dbms_output.put_line('ID | Status     | Tipo       | Destino    | Arquivo');
    dbms_output.put_line('---|------------|------------|------------|--------');
 
    FOR arch IN (
      		SELECT 
			RPAD(dest_id, 2) as id, 
			RPAD(STATUS,10) as STATUS, 
			RPAD(binding,10) AS tipo,
        	RPAD(target,10) AS destino, 
			destination AS arquivo
        	FROM v$archive_dest 
			WHERE destination IS NOT NULL) LOOP
      		
				dbms_output.put_line(arch.id || ' | ' || arch.STATUS || ' | ' || arch.tipo || ' | ' || arch.destino || ' | ' || arch.arquivo
			
			);
   	END LOOP;


	dbms_output.put_line('');
	dbms_output.put_line('');
	dbms_output.put_line('=====================================');
    dbms_output.put_line('Geracao de ARCHIVES - Ultimos 10 dias');
    dbms_output.put_line('=====================================');
    dbms_output.put_line('');
    dbms_output.put_line('          Dia             | Thread  |   Em MB    |   Em GB    | Total gerado');
    dbms_output.put_line('--------------------------|---------|------------|------------|-------------');

	FOR arch2 IN (
      		select 
				RPAD(trunc(COMPLETION_TIME,'DD'),25,' ') day,
				LPAD(thread#,7,' ') thread, 
				LPAD(round(sum(BLOCKS*BLOCK_SIZE)/1024/1024),10,' ') mb,
				LPAD(round(sum(BLOCKS*BLOCK_SIZE)/1024/1024/1024),10,' ') gb,
				LPAD(count(*),10,' ') total 
			from v$archived_log 
			where COMPLETION_TIME > sysdate-10 AND
			CREATOR != 'RMAN'
			group by trunc(COMPLETION_TIME,'DD'),
			thread# order by 1,2
			) LOOP
      		
				dbms_output.put_line(arch2.day || ' | ' || arch2.thread || ' | ' || arch2.mb || ' | ' || arch2.gb || ' | ' || arch2.total
			
			);
	END LOOP;
	
	dbms_output.put_line('');
	dbms_output.put_line('');
	dbms_output.put_line('======================================');
    dbms_output.put_line('Geracao de ARCHIVES - Ultimas 24 horas');
    dbms_output.put_line('======================================');
    dbms_output.put_line('');
    dbms_output.put_line('          Data            | Thread  |   Em MB    |   Em GB    | Total gerado');
    dbms_output.put_line('--------------------------|---------|------------|------------|-------------');

	FOR arch3 IN (
				SELECT 
					RPAD(trunc(COMPLETION_TIME,'HH'),25,' ') Hour,
					LPAD(thread#,7,' ') thread, 
					LPAD(round(sum(BLOCKS*BLOCK_SIZE)/1024/1024),10,' ') MB,
					LPAD(round(sum(BLOCKS*BLOCK_SIZE)/1024/1024/1024),10,' ') GB,
					LPAD(count(*),10,' ') Total 
				from v$archived_log   
				WHERE COMPLETION_TIME >= SYSDATE-1
				group by trunc(COMPLETION_TIME,'HH'),thread#  
				order by 1 desc
			) LOOP
      		
				dbms_output.put_line(arch3.hour || ' | ' || arch3.thread || ' | ' || arch3.mb || ' | ' || arch3.gb || ' | ' || arch3.total
			
			);
	END LOOP;
	
  END IF;

	dbms_output.put_line('');
	dbms_output.put_line('');
	dbms_output.put_line('==========================================');
	dbms_output.put_line('Informacoes sobre a quantidade de Sessoes');
	dbms_output.put_line('==========================================');
	dbms_output.put_line('       Instance      |       Hostname       |   Status   |  Sessions  ');
	dbms_output.put_line('---------------------|----------------------|------------|------------');
	FOR sess IN (
		select 
		LPAD(c.instance_name,20,' ')								instance_name,
		LPAD(c.host_name,20,' ')									hostname,
		LPAD(c.status,10,' ') 										status,
		LPAD(to_char(l.sessions_current,'fm99g999g990'),10,' ')		sessions
		from gv$instance c,
		gv$license l,
		v$instance i
		where c.instance_number = i.instance_number (+)
		and c.thread# = i.thread# (+)
		and l.inst_id = c.inst_id ) LOOP
			dbms_output.put_line(
								 sess.instance_name   || ' | ' ||
								 sess.hostname   || ' | ' ||
								 sess.status   || ' | ' ||
								 sess.sessions);
	END LOOP;


	dbms_output.put_line('');
	dbms_output.put_line('');
	dbms_output.put_line('======================================================');
	dbms_output.put_line('Informacoes Gerais - Quantidade de Processos');
	dbms_output.put_line('======================================================');
	dbms_output.put_line('       Instance      |       Hostname       |   Total  ');
	dbms_output.put_line('---------------------|----------------------|----------');
	FOR proc IN (
		select
		LPAD(i.instance_name,20,' ')						instance_name,
		LPAD(i.host_name,20,' ')						hostname,
		count(1) as tot 
		from gv$process p 
		join gv$instance i on i.INSTANCE_NUMBER = p.inst_id
		group by i.INSTANCE_NAME, i.HOST_NAME
		order by i.INSTANCE_NAME, i.HOST_NAME
	) LOOP
		dbms_output.put_line(
			proc.instance_name || ' | ' ||
			proc.hostname || ' | ' ||
			proc.tot
	);
	END LOOP;  
  
  
  dbms_output.put_line('');
  dbms_output.put_line('');
  dbms_output.put_line('Logs do grupo ADMIN');
  dbms_output.put_line('===================');
  dbms_output.put_line('Nome            | Diretorio');
  dbms_output.put_line('----------------|----------');
  FOR admin IN (
    SELECT RPAD(name,15) log, VALUE
      FROM v$parameter
      WHERE name IN ('background_dump_dest', 'background_core_dump', 'core_dump_dest','user_dump_dest')
      ORDER BY NAME) LOOP
    dbms_output.put_line(admin.log || ' | ' || admin.VALUE);
  END LOOP;
  dbms_output.put_line('');
 
  dbms_output.put_line('Configuracoes de auditoria e seguranca');
  dbms_output.put_line('======================================');
  dbms_output.put_line('Parametro       | Valor');
  dbms_output.put_line('----------------|------');
  FOR security IN (
    SELECT RPAD(name,15) log, VALUE
      FROM v$parameter
      WHERE name IN ('audit_sys_operations', 'audit_file_dest','audit_trail', 'os_authent_prefix', 'remote_os_authent',
        'remote_login_passwordfile', 'utl_file_dir')
      ORDER BY NAME) LOOP
    dbms_output.put_line(security.log || ' | ' || security.VALUE);
  END LOOP;
  dbms_output.put_line('');
 
END;
/
 
SET serveroutput OFF
SET serveroutput ON SIZE 1000000  FORMAT WRAPPED
 
BEGIN
	dbms_output.put_line('');
	dbms_output.put_line('');
	dbms_output.put_line('======================================');
    dbms_output.put_line('Jobs agendados (Jobs and Scheduller)');
    dbms_output.put_line('======================================');
    dbms_output.put_line('');
	dbms_output.put_line('==================');
    dbms_output.put_line('Jobs - Scheduller');
    dbms_output.put_line('==================');
	--dbms_output.put_line('ID|   Owner    |         Job Name         |          Job Action         |Enable|   State   |           Interval           |      Next Run');
	--dbms_output.put_line('--|------------|--------------------------|-----------------------------|------|-----------|------------------------------|--------------------');
	dbms_output.put_line('ID|   Owner    |            Job Name            |Enable|   State   |           Interval           |      Next Run');
	dbms_output.put_line('--|------------|--------------------------------|------|-----------|------------------------------|--------------------');
	
	FOR job2 IN (
	select
			RPAD(NVL(substr(INSTANCE_ID,1,2),'  '),2) AS ID,
			RPAD(SUBSTR(OWNER,1,10),12)             AS OWNER,
			RPAD(SUBSTR(JOB_NAME,1,30),32)          AS JOB_NAME,
			--RPAD(NVL(SUBSTR(JOB_ACTION,1,27),' '),27) 							  AS JOB_ACTION,
			RPAD(NVL(SUBSTR(ENABLED,1,5),' '),5,' ')             				  AS ENABLE,
			RPAD(NVL(SUBSTR(STATE,1,10),' '),11,' ')   					          AS STATE,
			RPAD(NVL(SUBSTR(REPEAT_INTERVAL,1,30),' '),30,' ')   				  AS REPEAT_INTERVAL,
			RPAD(NVL(TO_CHAR(NEXT_RUN_DATE,'DD/MM/YYYY HH24:Mi:SS'),' '),19, ' ') AS NEXT_RUN_DATE
	FROM
			dba_scheduler_jobs
	WHERE ENABLED != 'FALSE'
	ORDER BY
			STATE DESC, OWNER, ID, JOB_NAME
			) LOOP
					dbms_output.put_line(
							job2.id || '|' ||
							job2.owner || '|' ||
							job2.job_name || '|' ||
							--job2.job_action || '|' ||
							job2.enable || '|' ||
							job2.state || '|' ||
							job2.repeat_interval || '|' ||
							job2.next_run_date);
	END LOOP;

	
	dbms_output.put_line('');
	dbms_output.put_line('==================');
    dbms_output.put_line('Jobs - DBA_JOBS');
    dbms_output.put_line('==================');

    dbms_output.put_line('    Nr |    Esquema      | Dur.(min) | BK|              Intervalo              | SQL');
	dbms_output.put_line('-------|-----------------|-----------|---|-------------------------------------|----------');
	FOR job IN (
			SELECT LPAD(job,6) id, RPAD(schema_user,15) esquema, RPAD(TRUNC(total_time/60),9) dur_mi,
					broken, RPAD(INTERVAL,35) INTERVAL, what
			FROM dba_jobs
			WHERE INTERVAL !='null'
	) LOOP
			dbms_output.put_line(job.id || ' | ' || job.esquema || ' | ' || job.dur_mi || ' | ' || job.broken || ' | ' || job.INTERVAL || ' | ' || job.what);
	END LOOP;
END;
/
 
SET serveroutput OFF
SET serveroutput ON SIZE 1000000  FORMAT WRAPPED
 
BEGIN
  dbms_output.put_line('');
  dbms_output.put_line('');
  dbms_output.put_line('========================================');
  dbms_output.put_line('Segmentos por esquema, tablespace e tipo');
  dbms_output.put_line('========================================');
  dbms_output.put_line('Esquema         | Tablespace      | Tipo de Objeto  | QT   | Tam(MB)');
  dbms_output.put_line('----------------|-----------------|-----------------|------|--------');
  FOR schema IN (
    SELECT
      RPAD(owner,15) schema,
      RPAD(tablespace_name, 15) tablespace,
      RPAD(segment_type,15) TYPE,
      LPAD(COUNT(*),4) qt, LPAD(ROUND(SUM(bytes)/1024/1024),6) mb
        FROM dba_segments
        --WHERE OWNER NOT IN ('SYS','OUTLN','SYSTEM','WMSYS','XDB')
        GROUP BY owner, tablespace_name, segment_type
        ORDER BY owner, tablespace_name, segment_type) LOOP
    dbms_output.put_line(schema.schema || ' | ' || schema.tablespace || ' | '
      || schema.TYPE || ' | ' || schema.qt || ' | ' || schema.mb);
  END LOOP;
  dbms_output.put_line('');
END;
/
 
SET serveroutput OFF
SET serveroutput ON SIZE 1000000  FORMAT WRAPPED
 
BEGIN
  dbms_output.put_line('');
  dbms_output.put_line('====================================');
  dbms_output.put_line('Objetos invalidos por tipo');
  dbms_output.put_line('====================================');
  dbms_output.put_line('      Owner     |                  Object Name             |              Type            ');
  dbms_output.put_line('----------------|------------------------------------------|------------------------------');
  FOR invalid IN (
   SELECT RPAD(owner,15,' ') as owner, RPAD(object_name,40,' ') as name, LPAD(object_type,25,' ') AS type
      FROM dba_objects
      WHERE STATUS != 'VALID'
      order by owner, object_type, object_name
  ) LOOP
        dbms_output.put_line(invalid.owner || ' | ' || invalid.name || ' | ' || invalid.type);
  END LOOP;
  dbms_output.put_line('');
END;
/
 
SET serveroutput OFF
SET serveroutput ON SIZE 1000000 FORMAT WRAPPED FORMAT WRAPPED
 
BEGIN
  dbms_output.put_line('');
  dbms_output.put_line('==========');
  dbms_output.put_line('Diretorios');
  dbms_output.put_line('==========');
  dbms_output.put_line('Esquema         | Nome                           | Diretorio');
  dbms_output.put_line('----------------|--------------------------------|----------');
  FOR directory IN (
    SELECT
      RPAD(owner,15) AS esquema,
      RPAD(directory_name,30) nome,
      directory_path AS path
        FROM dba_directories ORDER BY owner, path) LOOP
    dbms_output.put_line(directory.esquema || ' | ' || directory.nome || ' | ' ||
      directory.path);
  END LOOP;
  dbms_output.put_line('');
  dbms_output.put_line('');
  dbms_output.put_line('==============');
  dbms_output.put_line('Database Links');
  dbms_output.put_line('==============');
  dbms_output.put_line('Esquema         | Nome            | Criacao    |' ||
    ' Esquema remoto  | Host remoto');
  dbms_output.put_line('----------------|-----------------|------------|' ||
    '-----------------|------------');
  FOR dblink IN (
    SELECT
      RPAD(owner,15) AS esquema,
      RPAD(db_link,15) nome,
      RPAD(username,15) esquema_destino,
      host host_destino,
      to_char(created,'DD-MM-YYYY') criacao
        FROM dba_db_links ORDER BY host, owner) LOOP
    dbms_output.put_line(dblink.esquema || ' | ' || dblink.nome || ' | ' ||
      dblink.criacao || ' | ' || dblink.esquema_destino || ' | ' || dblink.host_destino);
  END LOOP;
  
  dbms_output.put_line('');
  dbms_output.put_line('');
  dbms_output.put_line('====================');
  dbms_output.put_line('Views Materializadas');
  dbms_output.put_line('====================');
  dbms_output.put_line('Esquema         | Nome            | Q Len | Atualiz. | DBLink');
  dbms_output.put_line('----------------|-----------------|-------|----------|-------');
  FOR mview IN (
    SELECT RPAD(owner,15) esquema, RPAD(mview_name,15) nome, RPAD(master_link,15) link,
      LPAD(query_len,5) len, last_refresh_date FROM dba_mviews
  ) LOOP
    dbms_output.put_line(mview.esquema || ' | ' || mview.nome || ' | ' || mview.len ||
      ' | ' || mview.last_refresh_date || ' | ' || mview.link);
  END LOOP;
  dbms_output.put_line('');

dbms_output.put_line('');
dbms_output.put_line('');
dbms_output.put_line('====================================');
dbms_output.put_line('Informacoes do Storage - ASM');
dbms_output.put_line('====================================');
END;
/

-- Melhorar isso
COLUMN path format a45
COLUMN type FORMAT a6  HEAD 'Type'
COLUMN TOTAL_GB FORMAT 999,999,999  HEAD 'Total (GB)'
COLUMN FREE_GB  FORMAT 999,999.999  HEAD 'Free (GB)'

select
		GROUP_NUMBER,
		NAME,
		PATH,
		(TOTAL_MB/1024) AS TOTAL_GB,
		(FREE_MB/1024) AS FREE_GB,
		STATE
from
		v$asm_disk
ORDER BY
		GROUP_NUMBER,
		NAME;

select
		GROUP_NUMBER,
		NAME,
		TYPE,
		(TOTAL_MB/1024) AS TOTAL_GB,
		(FREE_MB/1024) AS FREE_GB,
		to_char((100*FREE_MB/TOTAL_MB),999.99) || '%' Livre,
		to_char((((TOTAL_MB - FREE_MB) / TOTAL_MB)  * 100),999.99)|| ' %' Ocupado,
		STATE
from
		v$asm_diskgroup
where
		TOTAL_MB > 0
order by 
		GROUP_NUMBER,
		NAME;


spool off
SET feedback ON
SET LINESIZE  120
