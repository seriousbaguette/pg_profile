/* ===== Tables stats functions ===== */

CREATE OR REPLACE FUNCTION tablespace_stats(IN sserver_id integer, IN start_id integer, IN end_id integer)
RETURNS TABLE(
    server_id integer,
    tablespaceid oid,
    tablespacename name,
    tablespacepath text,
    size_delta bigint
) SET search_path=@extschema@,public AS $$
    SELECT
        st.server_id,
        st.tablespaceid,
        st.tablespacename,
        st.tablespacepath,
        sum(st.size_delta)::bigint AS size_delta
    FROM v_sample_stat_tablespaces st
        /* Start sample existance condition
        Start sample stats does not account in report, but we must be sure
        that start sample exists, as it is reference point of next sample
        */
        JOIN samples sample_s ON (st.server_id = sample_s.server_id AND sample_s.sample_id = start_id)
        /* End sample existance condition
        Make sure that end sample exists, so we really account full interval
        */
        JOIN samples sample_e ON (st.server_id = sample_e.server_id AND sample_e.sample_id = end_id)
    WHERE st.server_id = sserver_id
      AND st.sample_id BETWEEN sample_s.sample_id + 1 AND sample_e.sample_id
    GROUP BY st.server_id, st.tablespaceid, st.tablespacename, st.tablespacepath
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION tablespaces_stats_htbl(IN jreportset jsonb, IN sserver_id integer, IN start_id integer, IN end_id integer) RETURNS text SET search_path=@extschema@,public AS $$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    --Cursor for stats
    c_tbl_stats CURSOR FOR
    SELECT
        st.tablespacename,
        st.tablespacepath,
        pg_size_pretty(st_last.size) as size,
        pg_size_pretty(st.size_delta) as size_delta
    FROM tablespace_stats(sserver_id,start_id,end_id) st
      LEFT OUTER JOIN v_sample_stat_tablespaces st_last ON
        (st_last.server_id = st.server_id AND st_last.sample_id = end_id AND st_last.tablespaceid = st.tablespaceid);

    r_result RECORD;
BEGIN
       --- Populate templates

    jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table>'
          '<tr>'
            '<th>Tablespace</th>'
            '<th>Path</th>'
            '<th title="Tablespace size as it was at the moment of last sample in report interval">Size</th>'
            '<th title="Tablespace size increment during report interval">Growth</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'ts_tpl',
        '<tr>'
          '<td>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>');

    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting table stats
    FOR r_result IN c_tbl_stats LOOP
          report := report||format(
              jtab_tpl #>> ARRAY['ts_tpl'],
              r_result.tablespacename,
              r_result.tablespacepath,
              r_result.size,
              r_result.size_delta
          );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;


    RETURN  report;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION tablespaces_stats_diff_htbl(IN jreportset jsonb, IN sserver_id integer, IN start1_id integer, IN end1_id integer,
IN start2_id integer, IN end2_id integer) RETURNS text SET search_path=@extschema@,public AS $$
DECLARE
    report text := '';
    jtab_tpl    jsonb;

    --Cursor for stats
    c_tbl_stats CURSOR FOR
    SELECT
        COALESCE(stat1.tablespacename,stat2.tablespacename) AS tablespacename,
        COALESCE(stat1.tablespacepath,stat2.tablespacepath) AS tablespacepath,
        pg_size_pretty(st_last1.size) as size1,
        pg_size_pretty(st_last2.size) as size2,
        pg_size_pretty(stat1.size_delta) as size_delta1,
        pg_size_pretty(stat2.size_delta) as size_delta2
    FROM tablespace_stats(sserver_id,start1_id,end1_id) stat1
        FULL OUTER JOIN tablespace_stats(sserver_id,start2_id,end2_id) stat2 USING (server_id,tablespaceid)
        LEFT OUTER JOIN v_sample_stat_tablespaces st_last1 ON
        (st_last1.server_id = stat1.server_id AND st_last1.sample_id = end1_id AND st_last1.tablespaceid = stat1.tablespaceid)
        LEFT OUTER JOIN v_sample_stat_tablespaces st_last2 ON
        (st_last2.server_id = stat2.server_id AND st_last2.sample_id = end2_id AND st_last2.tablespaceid = stat2.tablespaceid);

    r_result RECORD;
BEGIN
     -- Tablespace stats template
     jtab_tpl := jsonb_build_object(
      'tab_hdr',
        '<table {difftbl}>'
          '<tr>'
            '<th>Tablespace</th>'
            '<th>Path</th>'
            '<th>I</th>'
            '<th title="Tablespace size as it was at the moment of last sample in report interval">Size</th>'
            '<th title="Tablespace size increment during report interval">Growth</th>'
          '</tr>'
          '{rows}'
        '</table>',
      'ts_tpl',
        '<tr {interval1}>'
          '<td {rowtdspanhdr}>%s</td>'
          '<td {rowtdspanhdr_mono}>%s</td>'
          '<td {label} {title1}>1</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr {interval2}>'
          '<td {label} {title2}>2</td>'
          '<td {value}>%s</td>'
          '<td {value}>%s</td>'
        '</tr>'
        '<tr style="visibility:collapse"></tr>');

    -- apply settings to templates
    jtab_tpl := jsonb_replace(jreportset #> ARRAY['htbl'], jtab_tpl);

    -- Reporting summary databases stats
    FOR r_result IN c_tbl_stats LOOP
        report := report||format(
            jtab_tpl #>> ARRAY['ts_tpl'],
            r_result.tablespacename,
            r_result.tablespacepath,
            r_result.size1,
            r_result.size_delta1,
            r_result.size2,
            r_result.size_delta2
        );
    END LOOP;

    IF report != '' THEN
        report := replace(jtab_tpl #>> ARRAY['tab_hdr'],'{rows}',report);
    END IF;
    RETURN report;

END;
$$ LANGUAGE plpgsql;
