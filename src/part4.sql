-- filling database

CREATE TABLE if NOT EXISTS alpha (
  id BIGINT PRIMARY KEY,
  content VARCHAR NOT NULL
);


CREATE TABLE if NOT EXISTS beta (
  id BIGINT PRIMARY KEY,
  content VARCHAR NOT NULL
);


CREATE TABLE if NOT EXISTS gamma (
  id BIGINT PRIMARY KEY,
  content VARCHAR NOT NULL
);


CREATE TABLE if NOT EXISTS "TableName_foo" (
  id BIGINT PRIMARY KEY,
  content VARCHAR NOT NULL
);


CREATE TABLE if NOT EXISTS "TableNameBar" (
  id BIGINT PRIMARY KEY,
  content VARCHAR NOT NULL
);


CREATE TABLE if NOT EXISTS "Table_Name_Baz" (
  id BIGINT PRIMARY KEY,
  content VARCHAR NOT NULL
);

CREATE OR REPLACE FUNCTION fnc_trg_insert_alpha()
RETURNS TRIGGER AS $trg_insert_alpha$
BEGIN
    new.content = upper(new.content);
    RETURN new;
END 
$trg_insert_alpha$ LANGUAGE plpgsql;

DROP TRIGGER if EXISTS trg_insert_alpha ON alpha;
CREATE TRIGGER trg_insert_alpha
BEFORE INSERT ON alpha
FOR EACH ROW EXECUTE PROCEDURE fnc_trg_insert_alpha();

CREATE OR REPLACE FUNCTION fnc_trg_insert_beta()
RETURNS TRIGGER AS $trg_insert_beta$
BEGIN
    new.content = lower(new.content);
    RETURN new;
END
$trg_insert_beta$ LANGUAGE plpgsql;

DROP TRIGGER if EXISTS trg_insert_beta ON beta;
CREATE TRIGGER trg_insert_beta
BEFORE INSERT ON beta
FOR EACH ROW EXECUTE PROCEDURE fnc_trg_insert_beta();

CREATE OR REPLACE FUNCTION show_some(num INT)
RETURNS TABLE (content VARCHAR) AS $$
SELECT content FROM alpha
UNION ALL
SELECT content FROM beta
UNION ALL
SELECT content FROM gamma
ORDER BY 1 ASC
LIMIT num
$$ LANGUAGE sql;

-- 1) Create a stored procedure that, without destroying the database,
-- destroys all those tables in the current database whose names begin
-- with the phrase 'TableName'.
CREATE OR REPLACE PROCEDURE delete_tablename_tables() AS $$
DECLARE
    EACH VARCHAR;
BEGIN
FOR EACH IN (
    SELECT table_name
    FROM information_schema.tables
    WHERE table_name ~'^TableName'
)
LOOP
    EXECUTE format('DROP TABLE %I', EACH);
END LOOP;
END;
$$ LANGUAGE plpgsql;

-- CALL delete_tablename_tables();

-- 2) Create a stored procedure with an output parameter that lists the names and parameters of all
-- user-defined scalar SQL functions in the current database. Do not display function names without parameters.
-- The names and the list of parameters must be displayed on one line.
-- The output parameter returns the number of features found.

CREATE OR REPLACE PROCEDURE prc_show_scalar_functions(INOUT count_functions INT) AS $$
DECLARE func CURSOR FOR
SELECT routine_name || ' ' || parameters AS user_funstion
FROM (
    SELECT routine_name, string_agg(parameters.parameter_name, ' ') AS parameters
    FROM information_schema.routines
    JOIN information_schema.parameters ON routines.specific_name = parameters.specific_name
    WHERE routine_body = 'SQL' AND routines.specific_schema = 'public' AND routine_type = 'FUNCTION'
        AND routines.data_type NOT IN ('USER-DEFINED', 'record')
    GROUP BY routine_name) func;
DECLARE function_description VARCHAR;
BEGIN
count_functions = 0;
OPEN func;
LOOP
    FETCH func INTO function_description;
    EXIT WHEN NOT found;
    RAISE INFO '%', function_description;
    count_functions = count_functions+1;
END LOOP;
END
$$ LANGUAGE plpgsql;

-- DO $$
-- DECLARE count INT;
-- BEGIN
--     CALL prc_show_scalar_functions(count_functions := count);
--     RAISE NOTICE 'Total found %', count;
-- END;
-- $$ LANGUAGE plpgsql;

-- 3) Create a stored procedure with output parameter, which destroys all SQL DML
-- triggers in the current database. The output parameter returns the number of
-- destroyed triggers.
CREATE OR REPLACE PROCEDURE delete_dml_triggers(INOUT res BIGINT DEFAULT 0) AS $$
DECLARE
    EACH VARCHAR;
    trg_table VARCHAR;
BEGIN
res = 0;
FOR EACH IN (
    SELECT trigger_name, event_object_table
    FROM information_schema.triggers
)
LOOP
    res = res + 1;
    EXECUTE format('(SELECT event_object_table FROM information_schema.triggers WHERE trigger_name = %L)', EACH)
      INTO trg_table;
    EXECUTE format('DROP TRIGGER %I ON %I', EACH, trg_table);
END LOOP;
END;
$$ LANGUAGE plpgsql;

-- CALL delete_dml_triggers();

-- 4) Create a stored procedure with an input parameter that outputs names
-- and descriptions of object types (only stored procedures and scalar functions)
-- that have a string specified by the procedure parameter
CREATE OR REPLACE PROCEDURE objects_names_descriptions(res REFCURSOR, str VARCHAR) AS $$
BEGIN
OPEN res FOR
    SELECT routine_name, routine_type, *
    FROM information_schema.routines
    WHERE routine_type IN ('FUNCTION', 'PROCEDURE') AND position(str IN routine_definition) > 0;
END
$$ LANGUAGE plpgsql;

-- BEGIN;
--     CALL objects_names_descriptions('res', 'foo');
--     FETCH ALL FROM "res";
--     CLOSE "res";
-- END;
