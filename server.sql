/* ========= Server functions ========= */

CREATE OR REPLACE FUNCTION create_server(IN server name, IN server_connstr text, IN server_enabled boolean = TRUE,
IN max_sample_age integer = NULL) RETURNS integer SET search_path=@extschema@,public AS $$
DECLARE
    sserver_id     integer;
BEGIN

    SELECT server_id INTO sserver_id FROM servers WHERE server_name=server;
    IF sserver_id IS NOT NULL THEN
        RAISE 'Server already exists.';
    END IF;

    INSERT INTO servers(server_name,connstr,enabled,max_sample_age)
    VALUES (server,server_connstr,server_enabled,max_sample_age)
    RETURNING server_id INTO sserver_id;

    RETURN sserver_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION create_server(IN server name, IN server_connstr text, IN server_enabled boolean,
IN max_sample_age integer) IS 'Create a new server';

CREATE OR REPLACE FUNCTION drop_server(IN server name) RETURNS integer SET search_path=@extschema@,public AS $$
DECLARE
    del_rows    integer;
    dserver_id  integer;
BEGIN
    SELECT server_id INTO STRICT dserver_id FROM servers WHERE server_name = server;
    DELETE FROM bl_samples WHERE server_id = dserver_id;
    DELETE FROM last_stat_cluster WHERE server_id = dserver_id;
    DELETE FROM last_stat_tables WHERE server_id = dserver_id;
    DELETE FROM last_stat_indexes WHERE server_id = dserver_id;
    DELETE FROM last_stat_user_functions WHERE server_id = dserver_id;
    DELETE FROM last_stat_database WHERE server_id = dserver_id;
    DELETE FROM last_stat_tablespaces WHERE server_id = dserver_id;
    DELETE FROM last_stat_archiver WHERE server_id = dserver_id;
    DELETE FROM sample_stat_tablespaces WHERE server_id = dserver_id;
    DELETE FROM tablespaces_list WHERE server_id = dserver_id;
    DELETE FROM indexes_list WHERE server_id = dserver_id;
    DELETE FROM tables_list WHERE server_id = dserver_id;
    DELETE FROM sample_stat_user_functions WHERE server_id = dserver_id;
    DELETE FROM funcs_list WHERE server_id = dserver_id;
    DELETE FROM servers WHERE server_name = server;
    GET DIAGNOSTICS del_rows = ROW_COUNT;
    RETURN del_rows;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION drop_server(IN server name) IS 'Drop a server';

CREATE OR REPLACE FUNCTION rename_server(IN server name, IN server_new_name name) RETURNS integer SET search_path=@extschema@,public AS $$
DECLARE
    upd_rows integer;
BEGIN
    UPDATE servers SET server_name = server_new_name WHERE server_name = server;
    GET DIAGNOSTICS upd_rows = ROW_COUNT;
    RETURN upd_rows;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION rename_server(IN server name, IN server_new_name name) IS 'Rename existing server';

CREATE OR REPLACE FUNCTION set_server_connstr(IN server name, IN server_connstr text) RETURNS integer SET search_path=@extschema@,public AS $$
DECLARE
    upd_rows integer;
BEGIN
    UPDATE servers SET connstr = server_connstr WHERE server_name = server;
    GET DIAGNOSTICS upd_rows = ROW_COUNT;
    RETURN upd_rows;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION set_server_connstr(IN server name, IN server_connstr text) IS 'Update server connection string';

CREATE OR REPLACE FUNCTION set_server_max_sample_age(IN server name, IN max_sample_age integer) RETURNS integer SET search_path=@extschema@,public AS $$
DECLARE
    upd_rows integer;
BEGIN
    UPDATE servers SET max_sample_age = set_server_max_sample_age.max_sample_age WHERE server_name = server;
    GET DIAGNOSTICS upd_rows = ROW_COUNT;
    RETURN upd_rows;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION set_server_max_sample_age(IN server name, IN max_sample_age integer) IS 'Update server max_sample_age period';

CREATE OR REPLACE FUNCTION enable_server(IN server name) RETURNS integer SET search_path=@extschema@,public AS $$
DECLARE
    upd_rows integer;
BEGIN
    UPDATE servers SET enabled = TRUE WHERE server_name = server;
    GET DIAGNOSTICS upd_rows = ROW_COUNT;
    RETURN upd_rows;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION enable_server(IN server name) IS 'Enable existing server (will be included in take_sample() call)';

CREATE OR REPLACE FUNCTION disable_server(IN server name) RETURNS integer SET search_path=@extschema@,public AS $$
DECLARE
    upd_rows integer;
BEGIN
    UPDATE servers SET enabled = FALSE WHERE server_name = server;
    GET DIAGNOSTICS upd_rows = ROW_COUNT;
    RETURN upd_rows;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION disable_server(IN server name) IS 'Disable existing server (will be excluded from take_sample() call)';

CREATE OR REPLACE FUNCTION set_server_db_exclude(IN server name, IN exclude_db name[]) RETURNS integer SET search_path=@extschema@,public AS $$
DECLARE
    upd_rows integer;
BEGIN
    UPDATE servers SET db_exclude = exclude_db WHERE server_name = server;
    GET DIAGNOSTICS upd_rows = ROW_COUNT;
    RETURN upd_rows;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION set_server_db_exclude(IN server name, IN exclude_db name[]) IS 'Excude databases from object stats collection. Useful in RDS.';

CREATE OR REPLACE FUNCTION show_servers() RETURNS TABLE(server_name name, connstr text, enabled boolean) SET search_path=@extschema@,public AS $$
    SELECT server_name,connstr,enabled FROM servers;
$$ LANGUAGE sql;

COMMENT ON FUNCTION show_servers() IS 'Displays all servers';
