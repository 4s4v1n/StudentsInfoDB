-- -- 1) Write a procedure FOR adding P2P check
-- -- Parameters: nickname of the person being checked, checker's nickname, 
-- -- task name, P2P check status, time.
-- -- If the status IS "start", add a record in the Checks table (use today's 
-- -- date).
-- -- Add a record IN the P2P table.
-- -- If the status IS "start", specify the record just added AS a check, 
-- -- otherwise specify the check WITH the latest (by time) unfinished P2P step.
CREATE OR REPLACE PROCEDURE has_peer(peer VARCHAR) AS $$
BEGIN
IF (peer NOT IN (SELECT nickname
                 FROM "Peers")) THEN
    RAISE EXCEPTION 'peer does NOT exist';
END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE has_task(task VARCHAR) AS $$
BEGIN
IF (task NOT IN (SELECT title
                 FROM "Tasks")) THEN
    RAISE EXCEPTION 'task does NOT exist';
END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE has_check(check_id BIGINT) AS $$
BEGIN
IF (check_id NOT IN (SELECT id
                     FROM "Checks")) THEN
    RAISE EXCEPTION 'check does NOT exist';
END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION is_p2p_finished(src BIGINT)
RETURNS BOOL AS $$
DECLARE res BOOL := FALSE;
BEGIN
CALL has_check(src);
IF (SELECT count(*)
    FROM "P2P"
    WHERE check_id = src AND check_state = 'start') > 0 AND
   (SELECT count(*)
    FROM "P2P"
    WHERE check_id = src AND check_state != 'start') > 0
    THEN res = TRUE;
END IF;
RETURN res;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION last_unfinished_p2p(x_peer VARCHAR, x_task VARCHAR)
RETURNS BIGINT AS $$
DECLARE 
    res BIGINT := 0;
BEGIN
res := (SELECT id
        FROM (SELECT id, check_date
              FROM "Checks"
              WHERE (peer = x_peer AND task = x_task AND NOT is_p2p_finished(id))
        ORDER BY check_date DESC
        LIMIT 1
) AS foo
);
RETURN res;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE add_p2p_check(add_peer VARCHAR, add_checker VARCHAR, add_task VARCHAR, 
    add_status check_status_type, add_at time) AS $$
DECLARE
    add_check_id BIGINT := 0;
BEGIN
CALL has_peer(add_peer);
CALL has_peer(add_checker);
CALL has_task(add_task);
IF (add_status = 'start') THEN
    INSERT INTO "Checks" (peer, task, check_date) VALUES (add_peer, add_task, CURRENT_DATE);
    add_check_id := currval('seq_checks_id');
ELSE
    add_check_id := last_unfinished_p2p(add_peer, add_task);
    IF ((SELECT check_time 
         FROM "P2P"
         WHERE check_id = add_check_id) >= add_at) THEN
            RAISE EXCEPTION 'check must be finished AFTER being started';
    END IF;
    IF ((SELECT checking_peer
         FROM "P2P"
         WHERE check_id = add_check_id) != add_checker) THEN
            RAISE EXCEPTION 'checker id does NOT match';
    END IF;
END IF;
    INSERT INTO "P2P" (check_id, checking_peer, check_state, check_time) 
    VALUES (add_check_id, add_checker, add_status, add_at);
END;
$$ LANGUAGE plpgsql;

-- 2) Write a procedure FOR adding checking by Verter
-- Parameters: nickname of the person being checked, task name, Verter check status, time.
-- Add a record to the Verter table (as a check specify the check of the corresponding task
-- WITH the latest (by time) successful P2P step)
CREATE OR REPLACE FUNCTION last_finished_p2p(x_peer VARCHAR, x_task VARCHAR) 
RETURNS BIGINT AS $$
DECLARE
    res BIGINT := 0;
BEGIN
CALL has_peer(x_peer);
CALL has_task(x_task);
res := (SELECT id 
        FROM (SELECT ch.id, check_date
              FROM "Checks" ch
              JOIN "P2P" p2p ON ch.id = p2p.check_id
              WHERE peer = x_peer AND task = x_task AND is_p2p_finished(ch.id) AND p2p.check_state = 'success'
        ORDER BY check_date DESC
        LIMIT 1) AS foo
);
RETURN res;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE add_verter_check(add_peer VARCHAR, add_task VARCHAR,
    add_status check_status_type, add_time time) AS $$
DECLARE
    add_check_id BIGINT;
BEGIN
CALL has_peer(add_peer);
CALL has_task(add_task);
add_check_id = last_finished_p2p(add_peer, add_task);
IF (add_status = 'start') THEN
    IF (SELECT count(*) FROM "Verter" WHERE check_id = add_check_id) > 0 THEN
        RAISE EXCEPTION 'verter check is already started';
    ELSE
    IF (SELECT check_time FROM "P2P" WHERE (check_id = add_check_id AND check_state = 'success')) > add_time THEN
        RAISE EXCEPTION 'verter check must start AFTER p2p is finished';
    END IF;
    INSERT INTO "Verter" (check_id, check_state, check_time) VALUES (add_check_id, add_status, add_time);
    END IF;
ELSE
    IF (SELECT count(*) FROM "Verter" WHERE check_id = add_check_id) != 1 THEN
        RAISE EXCEPTION 'verter check is not started or is already finished';
    ELSE
        IF (SELECT check_time FROM "Verter" WHERE check_id = add_check_id) >= add_time THEN
            RAISE EXCEPTION 'verter check must be finished AFTER being started';
        END IF;
        INSERT INTO "Verter" (check_id, check_state, check_time) VALUES (add_check_id, add_status, add_time);
    END IF;
END IF;
END;
$$ LANGUAGE plpgsql;

-- 3) Write a trigger: AFTER adding a record WITH the "start" status to
-- the P2P table, change the corresponding record in the TransferredPoints
-- table
CREATE OR REPLACE FUNCTION fnc_trg_after_insert_p2p()
RETURNS TRIGGER AS $$
DECLARE
    src_peer VARCHAR;
BEGIN
IF (new.check_state = 'start') THEN
    src_peer = (SELECT peer
                FROM "Checks"
                WHERE id = new.check_id);
    IF (
      SELECT count(*)
      FROM "TransferredPoints" tp
      WHERE (tp.checked_peer = src_peer AND tp.checking_peer = new.checking_peer)
    ) = 0 THEN
        INSERT INTO "TransferredPoints" (checking_peer, checked_peer, points_amount)
        VALUES (new.checking_peer, src_peer, 1);
    ELSE
        WITH old_amount AS (
            SELECT points_amount
            FROM "TransferredPoints" tp
            WHERE tp.checking_peer = new.checking_peer AND tp.checked_peer = src_peer
        )
        UPDATE "TransferredPoints" tp
        SET points_amount = (
            SELECT points_amount + 1
            FROM old_amount)
        WHERE tp.checking_peer = new.checking_peer AND tp.checked_peer = src_peer;
    END IF;
END IF;
RETURN new;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_after_insert_p2p ON "P2P";
CREATE TRIGGER trg_after_insert_p2p AFTER
INSERT ON "P2P" FOR EACH ROW EXECUTE PROCEDURE fnc_trg_after_insert_p2p();

-- 4) Write a TRIGGER: before adding a record to the XP table, check if
-- it is correct
-- The record is considered correct if:

-- The number of XP does not exceed the maximum available FOR the task
-- being checked
-- The Check field refers to a successful check If the record does not
-- pass the check, do not add it to the table.
CREATE OR REPLACE FUNCTION fnc_get_task_block(p_task VARCHAR)
RETURNS VARCHAR AS $$
DECLARE
    res VARCHAR;
BEGIN res := (
    SELECT substring(p_task, '^[A-Z]+')
);
RETURN res;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION is_verter_needed(p_task VARCHAR)
RETURNS BOOL AS $$
DECLARE
    res BOOL;
BEGIN
res := (SELECT * FROM fnc_get_task_block(p_task)) = 'C';
RETURN res;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION is_task_completed(p_check_id BIGINT)
RETURNS BOOL AS $$
DECLARE res BOOL := TRUE;
BEGIN
IF (SELECT count(*) FROM "P2P" WHERE check_id = p_check_id AND check_state = 'success') = 0 THEN
    res := FALSE;
END IF;
IF (is_verter_needed((SELECT task FROM "Checks" WHERE id = p_check_id))) THEN
    IF (SELECT count(*) FROM "Verter" WHERE check_id = p_check_id AND check_state = 'success') = 0 THEN
        res := FALSE;
    END IF;
END IF;
RETURN res;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fnc_trg_insert_xp()
RETURNS TRIGGER AS $trg_insert_xp$
BEGIN
IF (
    new.xp_amount > (
        SELECT max_xp
        FROM "Checks" ch
        JOIN "Tasks" ta ON ta.title = ch.task
        WHERE ch.id = new.check_id
    )
) THEN
    RAISE EXCEPTION 'new.xp is greater than max_xp';
END IF;
IF (is_task_completed(new.check_id) = FALSE) THEN
    RAISE EXCEPTION 'checks failed, cant add xp';
END IF;
RETURN new;
END $trg_insert_xp$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_insert_xp ON "XP";
CREATE TRIGGER trg_insert_xp BEFORE
INSERT ON "XP" FOR EACH ROW EXECUTE PROCEDURE fnc_trg_insert_xp();
