-- Initial drops
DROP TABLE IF EXISTS "Checks" CASCADE;
DROP TABLE IF EXISTS "Friends" CASCADE;
DROP TABLE IF EXISTS "P2P" CASCADE;
DROP TABLE IF EXISTS "Peers" CASCADE;
DROP TABLE IF EXISTS "Recommendations" CASCADE;
DROP TABLE IF EXISTS "Tasks" CASCADE;
DROP TABLE IF EXISTS "TimeTracking" CASCADE;
DROP TABLE IF EXISTS "TransferredPoints" CASCADE;
DROP TABLE IF EXISTS "Verter" CASCADE;
DROP TABLE IF EXISTS "XP" CASCADE;

-- Peers
CREATE TABLE IF NOT EXISTS "Peers" (
    nickname VARCHAR PRIMARY KEY,
    birthday DATE NOT NULL
);

-- Tasks
CREATE TABLE IF NOT EXISTS "Tasks" (
    title VARCHAR PRIMARY KEY,
    parent_task VARCHAR,
    max_xp BIGINT NOT NULL CHECK(max_xp > 0)
);

CREATE OR REPLACE FUNCTION fnc_trg_insert_tasks() RETURNS TRIGGER AS $trg_insert_tasks$
BEGIN
IF (
    (
      (
        SELECT count(*)
        FROM "Tasks"
      ) > 0
      AND new.parent_task NOT IN (
        SELECT title
        FROM "Tasks"
      )
    )
    OR (
      (
        SELECT count(*)
        FROM "Tasks"
      ) = 0
      AND new.parent_task IS NOT NULL
    )
  ) THEN RAISE EXCEPTION '% : There must be one task with no parent', new.title;
END IF;
RETURN new;
END
$trg_insert_tasks$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_insert_tasks ON "Tasks";
CREATE TRIGGER trg_insert_tasks BEFORE
INSERT ON "Tasks" FOR EACH ROW EXECUTE PROCEDURE fnc_trg_insert_tasks();

CREATE OR REPLACE FUNCTION fnc_trg_delete_tasks() RETURNS TRIGGER AS $trg_delete_tasks$
BEGIN
IF (
    old.title IN (
        SELECT parent_task
        FROM "Tasks"
    )
  ) THEN RAISE EXCEPTION 'Cant DELETE a task which serves AS a parent FOR another task';
END IF;
RETURN old;
END
$trg_delete_tasks$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_delete_tasks ON "Tasks";
CREATE TRIGGER trg_delete_tasks BEFORE
DELETE ON "Tasks" FOR EACH ROW EXECUTE PROCEDURE fnc_trg_delete_tasks();

-- Checks
CREATE TABLE IF NOT EXISTS "Checks" (
    id BIGINT PRIMARY KEY,
    peer VARCHAR NOT NULL,
    task VARCHAR NOT NULL,
    check_date DATE NOT NULL,
    CONSTRAINT fk_checks_peer FOREIGN KEY (peer) REFERENCES "Peers"(nickname),
    CONSTRAINT fk_checks_task FOREIGN KEY (task) REFERENCES "Tasks"(title)
);

CREATE SEQUENCE IF NOT EXISTS seq_checks_id
AS BIGINT
INCREMENT BY 1
START 1
OWNED BY "Checks".id;

ALTER TABLE "Checks"
ALTER COLUMN id SET DEFAULT nextval('seq_checks_id');

-- check_status_type enum
DO $$ 
BEGIN 
IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'check_status_type'
) THEN CREATE TYPE check_status_type AS ENUM ('start', 'success', 'failure');
END IF;
END $$;

-- P2P
CREATE TABLE IF NOT EXISTS "P2P" (
    id BIGINT PRIMARY KEY,
    check_id BIGINT NOT NULL,
    checking_peer VARCHAR NOT NULL,
    check_state check_status_type NOT NULL,
    check_time time NOT NULL,
    CONSTRAINT fk_p2p_check_id FOREIGN KEY (check_id) REFERENCES "Checks"(id),
    CONSTRAINT fk_p2p_checking_peer FOREIGN KEY (checking_peer) REFERENCES "Peers"(nickname)
);

CREATE SEQUENCE IF NOT EXISTS seq_p2p_id AS BIGINT
INCREMENT BY 1
START 1
OWNED BY "P2P".id;

ALTER TABLE "P2P"
  ALTER COLUMN id SET DEFAULT nextval('seq_p2p_id');

CREATE OR REPLACE FUNCTION fnc_trg_insert_p2p() RETURNS TRIGGER AS $trg_insert_p2p$
BEGIN IF (
    new.checking_peer = (
        SELECT peer
        FROM "Checks"
        WHERE "Checks".id = new.check_id
    )
  ) THEN RAISE EXCEPTION 'cant p2p CHECK themselves';
END IF;
RETURN new;
END $trg_insert_p2p$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_insert_p2p ON "P2P";
CREATE TRIGGER trg_insert_p2p BEFORE
INSERT ON "P2P" FOR EACH ROW EXECUTE PROCEDURE fnc_trg_insert_p2p();

-- Verter
CREATE TABLE IF NOT EXISTS "Verter" (
    id BIGINT PRIMARY KEY,
    check_id BIGINT NOT NULL,
    check_state check_status_type NOT NULL,
    check_time time NOT NULL,
    CONSTRAINT fk_verter_check_id FOREIGN KEY (check_id) REFERENCES "Checks"(id)
);

CREATE SEQUENCE IF NOT EXISTS seq_verter_id AS BIGINT
INCREMENT BY 1
START 1
OWNED BY "Verter".id;

ALTER TABLE "Verter"
ALTER COLUMN id SET DEFAULT nextval('seq_verter_id');

-- TransferredPoints
CREATE TABLE IF NOT EXISTS "TransferredPoints" (
    id BIGINT PRIMARY KEY,
    checking_peer VARCHAR NOT NULL,
    checked_peer VARCHAR NOT NULL,
    points_amount BIGINT NOT NULL CHECK(points_amount > 0),
    CONSTRAINT fk_transferred_checking FOREIGN KEY (checking_peer) REFERENCES "Peers"(nickname),
    CONSTRAINT fk_transferred_checked FOREIGN KEY (checked_peer) REFERENCES "Peers"(nickname),
    CONSTRAINT ch_tranferred_not_self CHECK(checking_peer != checked_peer),
    UNIQUE(checking_peer, checked_peer)
);

CREATE SEQUENCE IF NOT EXISTS seq_transferred_points_id AS BIGINT
INCREMENT BY 1
START 1
OWNED BY "TransferredPoints".id;

ALTER TABLE "TransferredPoints"
ALTER COLUMN id SET DEFAULT nextval('seq_transferred_points_id');

-- Friends
CREATE TABLE IF NOT EXISTS "Friends" (
    id BIGINT PRIMARY KEY,
    peer1 VARCHAR NOT NULL,
    peer2 VARCHAR NOT NULL,
    CONSTRAINT fk_friends_peer1 FOREIGN KEY (peer1) REFERENCES "Peers"(nickname),
    CONSTRAINT fk_friends_peer2 FOREIGN KEY (peer2) REFERENCES "Peers"(nickname),
    CONSTRAINT ch_friends_not_self CHECK(peer1 != peer2),
    UNIQUE(peer1, peer2)
);

CREATE SEQUENCE IF NOT EXISTS seq_friends_id AS BIGINT
INCREMENT BY 1
START 1
OWNED BY "Friends".id;

ALTER TABLE "Friends"
ALTER COLUMN id SET DEFAULT nextval('seq_friends_id');

CREATE OR REPLACE FUNCTION fnc_trg_insert_friends() RETURNS TRIGGER AS $trg_insert_friends$
BEGIN
IF (
    SELECT count(*)
    FROM "Friends"
    WHERE peer1 = new.peer2 AND peer2 = new.peer1 
  ) THEN RAISE EXCEPTION 'reverse pair of friends already EXISTS';
END IF;
RETURN new;
END
$trg_insert_friends$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_insert_friends ON "Friends";
CREATE TRIGGER trg_insert_friends BEFORE
INSERT ON "Friends" FOR EACH ROW EXECUTE PROCEDURE fnc_trg_insert_friends();

-- Recommendations
CREATE TABLE IF NOT EXISTS "Recommendations" (
    id BIGINT PRIMARY KEY,
    peer VARCHAR NOT NULL,
    recommended_peer VARCHAR NOT NULL,
    CONSTRAINT fk_recommendations_peer FOREIGN KEY (peer) REFERENCES "Peers"(nickname),
    CONSTRAINT fk_recommendations_recommended_peer FOREIGN KEY (recommended_peer) REFERENCES "Peers"(nickname),
    CONSTRAINT ch_recommendations_not_self CHECK(peer != recommended_peer),
    UNIQUE(peer, recommended_peer)
);

CREATE SEQUENCE IF NOT EXISTS seq_recommendations_id AS BIGINT
INCREMENT BY 1
START 1
OWNED BY "Recommendations".id;

ALTER TABLE "Recommendations"
ALTER COLUMN id SET DEFAULT nextval('seq_recommendations_id');

-- XP
CREATE TABLE IF NOT EXISTS "XP" (
    id BIGINT PRIMARY KEY,
    check_id BIGINT NOT NULL,
    xp_amount BIGINT NOT NULL,
    CONSTRAINT fk_xp_check_id FOREIGN KEY (check_id) REFERENCES "Checks"(id),
    CONSTRAINT ch_xp_amount_positive CHECK(xp_amount >= 0),
    UNIQUE(check_id)
);

CREATE SEQUENCE IF NOT EXISTS seq_xp_id AS BIGINT
INCREMENT BY 1
START 1
OWNED BY "XP".id;

ALTER TABLE "XP"
ALTER COLUMN id SET DEFAULT nextval('seq_xp_id');

-- TimeTracking
CREATE TABLE IF NOT EXISTS "TimeTracking" (
    id BIGINT PRIMARY KEY,
    peer VARCHAR NOT NULL,
    event_date DATE NOT NULL,
    event_time time NOT NULL,
    event_state BIGINT NOT NULL,
    CONSTRAINT fk_time_tracking_peer FOREIGN KEY (peer) REFERENCES "Peers"(nickname),
    CONSTRAINT ch_event_state CHECK(event_state IN (1, 2))
);

CREATE SEQUENCE IF NOT EXISTS seq_time_tracking_id AS BIGINT
INCREMENT BY 1
START 1
OWNED BY "TimeTracking".id;

ALTER TABLE "TimeTracking"
ALTER COLUMN id SET DEFAULT nextval('seq_time_tracking_id');

-- export procedures

CREATE OR REPLACE PROCEDURE export_table(table_name VARCHAR, pth VARCHAR, delim NCHAR(1)) AS $$
BEGIN
EXECUTE format('COPY %I TO %L DELIMITER %L CSV HEADER', table_name, pth, delim);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE export_p2p(pth VARCHAR, delim NCHAR(1)) AS $$
BEGIN
CALL export_table('P2P', pth, delim);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE export_transferred_points(pth VARCHAR, delim NCHAR(1)) AS $$
BEGIN
CALL export_table('TransferredPoints', pth, delim);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE export_friends(pth VARCHAR, delim NCHAR(1)) AS $$
BEGIN
CALL export_table('Friends', pth, delim);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE export_recommendations(pth VARCHAR, delim NCHAR(1)) AS $$
BEGIN
CALL export_table('Recommendations', pth, delim);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE export_time_tracking(pth VARCHAR, delim NCHAR(1)) AS $$
BEGIN
CALL export_table('TimeTracking', pth, delim);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE export_checks(pth VARCHAR, delim NCHAR(1)) AS $$
BEGIN
CALL export_table('Checks', pth, delim);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE export_peers(pth VARCHAR, delim NCHAR(1)) AS $$
BEGIN
CALL export_table('Peers', pth, delim);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE export_verter(pth VARCHAR, delim NCHAR(1)) AS $$
BEGIN
CALL export_table('Verter', pth, delim);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE export_xp(pth VARCHAR, delim NCHAR(1)) AS $$
BEGIN
CALL export_table('XP', pth, delim);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE export_tasks(pth VARCHAR,delim NCHAR(1)) AS $$
BEGIN
CALL export_table('Tasks', pth, delim);
END;
$$ LANGUAGE plpgsql;

-- -- import procedures

CREATE OR REPLACE PROCEDURE import_table(table_name VARCHAR, pth VARCHAR, delim NCHAR(1)) AS $$
BEGIN
EXECUTE format('COPY %I FROM %L DELIMITER %L CSV HEADER', table_name, pth, delim);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE import_p2p(pth VARCHAR, delim NCHAR(1)) AS $$
DECLARE
    foo BIGINT;
BEGIN
CALL import_table('P2P', pth, delim);
IF (SELECT count(*) FROM "P2P") > 0 THEN
    foo := (SELECT setval('seq_p2p_id', (SELECT max(id)
                                         FROM "P2P")));
END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE import_transferred_points(pth VARCHAR, delim NCHAR(1)) AS $$
DECLARE
    foo BIGINT;
BEGIN
CALL import_table('TransferredPoints', pth, delim);
IF (SELECT count(*) FROM "TransferredPoints") > 0 THEN
    foo := (SELECT setval('seq_transferred_points_id', (SELECT max(id)
                                                        FROM "TransferredPoints")));
END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE import_friends(pth VARCHAR, delim NCHAR(1)) AS $$
DECLARE
    foo BIGINT;
BEGIN
CALL import_table('Friends', pth, delim);
IF (SELECT count(*) FROM "Friends") > 0 THEN
    foo := (SELECT setval('seq_friends_id', (SELECT max(id)
                                             FROM "Friends")));
END IF;
END;
$$ LANGUAGE plpgsql ;

CREATE OR REPLACE PROCEDURE import_recommendations(pth VARCHAR, delim NCHAR(1)) AS $$
DECLARE
    foo BIGINT;
BEGIN
CALL import_table('Recommendations', pth, delim);
IF (SELECT count(*) FROM "Recommendations") > 0 THEN
    foo := (SELECT setval('seq_recommendations_id', (SELECT max(id)
                                                     FROM "Recommendations")));
END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE import_time_tracking(pth VARCHAR, delim NCHAR(1)) AS $$
DECLARE
    foo BIGINT;
BEGIN
CALL import_table('TimeTracking', pth, delim);
IF (SELECT count(*) FROM "TimeTracking") > 0 THEN
    foo := (SELECT setval('seq_time_tracking_id', (SELECT max(id)
                                                   FROM "TimeTracking")));
END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE import_checks(pth VARCHAR, delim NCHAR(1)) AS $$
DECLARE
    foo BIGINT;
BEGIN
CALL import_table('Checks', pth, delim);
IF (SELECT count(*) FROM "Checks") > 0 THEN
    foo := (SELECT setval('seq_checks_id', (SELECT max(id)
                                            FROM "Checks")));
END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE import_peers(pth VARCHAR, delim NCHAR(1)) AS $$
BEGIN
CALL import_table('Peers', pth, delim);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE import_verter(pth VARCHAR, delim NCHAR(1)) AS $$
DECLARE
    foo BIGINT;
BEGIN
CALL import_table('Verter', pth, delim);
IF (SELECT count(*) FROM "Verter") > 0 THEN
    foo := (SELECT setval('seq_verter_id', (SELECT max(id)
                                            FROM "Verter")));
END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE import_xp(pth VARCHAR, delim NCHAR(1)) AS $$
DECLARE
    foo BIGINT;
BEGIN
CALL import_table('XP', pth, delim);
IF (SELECT count(*) FROM "XP") > 0 THEN
    foo := (SELECT setval('seq_xp_id', (SELECT max(id)
                                        FROM "XP")));
END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE import_tasks(pth VARCHAR, delim NCHAR(1)) AS $$
BEGIN
CALL import_table('Tasks', pth, delim);
END;
$$ LANGUAGE plpgsql;
