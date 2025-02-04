--#/*************************************************************************************/
--#/* Script                    : confsql.sql                                           */
--#/* Author                    : Mario Barduchi                                        */
--#/* E-mail                    : mario.barduchi@gmail.com                              */
--#/* Date                      : 07/07/2020                                            */
--#/* Original                  : None                                                  */
--#/* Description               : Configurations - SQL*Plus                             */
--#/* Location                  : /home/oracle/SCRIPTS2DBA                              */
--#/* Responsibility            : DBA                                                   */
--#/* External Parameters       :                                                       */
--#/* Changes Made              :                                                       */
--#/* Observations              :                                                       */
--#/*************************************************************************************/
SET LINESIZE 1000
SET PAGESIZE 999
SET LONG 32767          
SET LONGCHUNKSIZE 4095  
SET TIME ON
SET TAB OFF
SET VERIFY OFF
SET TRIMOUT OFF
SET TRIMSPOOL OFF
SET TERMOUT ON
SET TRIM ON
SET FEEDBACK ON
SET WRAP OFF
alter session set nls_date_format = 'DD/MM/YYYY HH24:Mi:SS';
