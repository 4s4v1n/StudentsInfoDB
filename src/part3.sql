-- 1) Write a function that returns the TransferredPoints table in a more
-- human-readable form
-- Peer's nickname 1, Peer's nickname 2, number of transferred peer points.
-- The number is negative if peer 2 received more points from peer 1.
CREATE OR REPLACE PROCEDURE has_block(x_block VARCHAR) AS $$
BEGIN
    IF (SELECT count(*) FROM "Tasks" WHERE fnc_get_task_block(title) = x_block) = 0
        THEN RAISE EXCEPTION 'block does NOT exist OR have no tasks';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fnc_hr_transferred_points()
RETURNS TABLE (peer1 VARCHAR, peer2 VARCHAR, points_amount BIGINT) AS $$
SELECT peer1, peer2, sum(points_amount)::BIGINT AS points_amount
FROM (
    SELECT checking_peer AS peer1, checked_peer AS peer2, points_amount
    FROM "TransferredPoints" tp1
    WHERE checking_peer < checked_peer
    UNION ALL
    SELECT checked_peer, checking_peer, (-points_amount)
    FROM "TransferredPoints"
    WHERE checked_peer < checking_peer
) AS foo
GROUP BY (peer1, peer2)
ORDER BY 1, 2
$$ LANGUAGE sql;

-- SELECT * FROM fnc_hr_transferred_points();

-- 2) Write a FUNCTION that RETURNS a TABLE of the following form: user name, name
-- of the checked task, number of XP received
-- Include in the table only tasks that have successfully passed the check (according
-- to the Checks table).
-- One task can be completed successfully several times. In this case, include all
-- successful checks in the table.
CREATE OR REPLACE FUNCTION fnc_hr_xp_earned()
RETURNS TABLE (peer VARCHAR, task VARCHAR, xp_amount BIGINT) AS $$
SELECT peer, task, xp_amount
FROM "Checks" ch
JOIN "XP" xp ON xp.check_id = ch.id
WHERE is_task_completed(ch.id) = TRUE
$$ LANGUAGE sql;

-- SELECT * FROM fnc_hr_xp_earned();

-- 3) Write a function that finds the peers who have not left campus for the whole day
-- (except the last exit, so there will be a list of peers who entered once and left
-- once during this day)
-- Function parameters: day, for example 12.05.2022.
-- The function returns only a list of peers.
CREATE OR REPLACE FUNCTION fnc_peers_not_leaving_during_day(p_day DATE)
RETURNS TABLE (peer VARCHAR) AS $$
WITH
peers_entered AS (
    SELECT peer, count(*)
    FROM "TimeTracking"
    WHERE event_date = p_day AND event_state = 1
    GROUP BY peer
),
peers_exited AS (
    SELECT peer, count(*)
    FROM "TimeTracking"
    WHERE event_date = p_day AND event_state = 2
    GROUP BY peer
)
SELECT ent.peer
FROM peers_entered ent
JOIN peers_exited ext ON ent.peer = ext.peer
WHERE ext.count = 1 AND ent.count = 1
$$ LANGUAGE sql;

-- SELECT * FROM fnc_peers_not_leaving_during_day('2022-01-01');

-- 4) Find the percentage of successful and unsuccessful checks for
-- all time
-- Output format: percentage of successful checks, percentage of 
-- unsuccessful ones
CREATE OR REPLACE FUNCTION is_verter_finished(ch_id BIGINT)
RETURNS BOOL AS $$
DECLARE res BOOL := FALSE;
BEGIN
CALL has_check(ch_id);
IF (SELECT count(*) FROM "Verter" WHERE check_id = ch_id AND check_state = 'start') > 0
    AND (SELECT count(*) FROM "Verter" WHERE check_id = ch_id AND check_state != 'start') > 0
THEN res = TRUE;
END IF;
RETURN res;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_check_overall_status(ch_id BIGINT)
RETURNS check_status_type AS $$
DECLARE res check_status_type := 'start';
BEGIN
IF is_p2p_finished(ch_id) THEN
    IF is_verter_needed((SELECT task FROM "Checks" WHERE id = ch_id)) THEN
        IF is_verter_finished(ch_id) THEN
            res = (SELECT check_state FROM "Verter" WHERE check_id = ch_id AND check_state != 'start');
        ELSE
            res = (SELECT check_state FROM "P2P" WHERE check_id = ch_id AND check_state != 'start');
        END IF;
    ELSE
        res = (SELECT check_state FROM "P2P" WHERE check_id = ch_id AND check_state != 'start');
    END IF;
END IF;
RETURN res;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE success_percentage(res REFCURSOR) AS $$
BEGIN
OPEN res FOR
WITH
sum_success AS (
    SELECT count(*) AS sum_s
    FROM (
        SELECT get_check_overall_status(id) AS ov_st
        FROM "Checks"
        ) AS foo
    WHERE ov_st = 'success'
),
sum_failure AS (
    SELECT count(*) AS sum_f
    FROM (
        SELECT get_check_overall_status(id) AS ov_st
        FROM "Checks"
        ) AS foo
    WHERE ov_st = 'failure'
),
sum_all AS (
    SELECT count(*) AS sum_a
    FROM (
        SELECT get_check_overall_status(id) AS ov_st
        FROM "Checks"
        ) AS foo
    WHERE ov_st != 'start'
)
SELECT (100 * (SELECT sum_s FROM sum_success)::FLOAT / (SELECT sum_a FROM sum_all)::FLOAT)::BIGINT AS successful,
       (100 * (SELECT sum_f FROM sum_failure)::FLOAT / (SELECT sum_a FROM sum_all)::FLOAT)::BIGINT AS unsuccessful;
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
-- CALL success_percentage('res');
-- fetch ALL FROM "res";
-- close "res";
-- END;

-- 5) Calculate the change in the number of peer points of each peer
-- using the TransferredPoints table
-- Output the result sorted by the change in the number of points.
-- Output format: peer's nickname, change in the number of peer points
CREATE OR REPLACE PROCEDURE points_change(res REFCURSOR) AS $$
BEGIN
OPEN res FOR
WITH
foo AS (
    SELECT ps.nickname, coalesce(sum(tp.points_amount), 0) AS increase
    FROM "Peers" ps
    LEFT JOIN "TransferredPoints" tp ON ps.nickname = tp.checking_peer
    GROUP BY ps.nickname
),
bar AS (
    SELECT ps.nickname, coalesce(sum(tp.points_amount), 0) AS decrease
    FROM "Peers" ps
    LEFT JOIN "TransferredPoints" tp ON ps.nickname = tp.checked_peer
    GROUP BY ps.nickname
)
SELECT nickname AS "Peer", (increase - decrease)::BIGINT AS "PointsChange"
FROM foo
NATURAL JOIN bar
ORDER BY 2 DESC;
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
-- CALL points_change('res');
-- fetch ALL FROM "res";
-- close "res";
-- END;

-- 6) Calculate the change in the number of peer points of each peer using
-- the table returned by the first function from Part 3
-- Output the result sorted by the change in the number of points.
-- Output format: peer's nickname, change in the number of peer points
CREATE OR REPLACE PROCEDURE points_change_from_hr(res REFCURSOR) AS $$
BEGIN
OPEN res FOR
WITH
foo AS (
    SELECT *
    FROM fnc_hr_transferred_points()
    UNION ALL
    SELECT peer2, peer1, -points_amount
    FROM fnc_hr_transferred_points()
)
SELECT peer1 AS "Peer", sum(points_amount)::BIGINT AS "PointsChange"
FROM foo
GROUP BY peer1
ORDER BY 2 DESC;
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
-- CALL points_change_from_hr('res');
-- fetch ALL FROM "res";
-- close "res";
-- END;

-- 7) Find the most frequently checked task for each day
-- If there is the same number of checks for some tasks in a certain day,
-- output all of them.
-- Output format: day, task name
CREATE OR REPLACE PROCEDURE most_checked_task_daily(res REFCURSOR) AS $$
BEGIN
OPEN res FOR
WITH
foo AS (
    SELECT check_date, task, count(*) AS cnt
    FROM "Checks"
    GROUP BY check_date, task
),
bar AS (
    SELECT check_date, max(cnt) AS mx_cnt
    FROM foo
    GROUP BY check_date
)
SELECT bar.check_date AS "Day", foo.task AS "Task"
FROM bar
JOIN foo ON foo.check_date = bar.check_date AND foo.cnt = bar.mx_cnt
ORDER BY 1;
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
-- CALL most_checked_task_daily('res');
-- fetch ALL FROM "res";
-- close "res";
-- END;

-- 8) Determine the duration of the last P2P CHECK
-- Duration means the difference between the time specified in the record
-- with the status "start" and the time specified in the record with the
-- status "success" or "failure".
-- Output format: CHECK duration
CREATE OR REPLACE PROCEDURE last_p2p_duration(res REFCURSOR) AS $$
BEGIN
OPEN res FOR
WITH
last_day AS (
      SELECT id AS check_id
      FROM "Checks"
      WHERE check_date = (SELECT max(check_date) FROM "Checks")
),
last_finished AS (
      SELECT check_id
      FROM last_day
      NATURAL JOIN "P2P"
      WHERE check_state != 'start'
      ORDER BY check_time DESC
      LIMIT 1
)
SELECT (
      (
        SELECT check_time
        FROM "P2P"
        WHERE check_state != 'start' AND check_id = (SELECT * FROM last_finished)
      ) - (
        SELECT check_time
        FROM "P2P"
        WHERE check_state = 'start' AND check_id = (SELECT * FROM last_finished)
      )
)::TIME AS "CheckDuration";
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
-- CALL last_p2p_duration('res');
-- fetch ALL FROM "res";
-- close "res";
-- END;

-- 9) Find all peers who have completed the whole given block of tasks and
-- the completion date of the last task
-- Procedure parameters: name of the block, for example “CPP”.
-- The result is sorted by the date of completion.
-- Output format: peer's name, date of completion of the block (i.e. the
-- last completed task from that block)
CREATE OR REPLACE FUNCTION fnc_tasks_of_the_block(block_name VARCHAR)
RETURNS TABLE (title VARCHAR) AS $$
CALL has_block(block_name);
SELECT title
FROM "Tasks"
WHERE fnc_get_task_block(title) = block_name
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION fnc_has_peer_completed_task(x_peer VARCHAR, x_task VARCHAR)
RETURNS BOOL AS $$
DECLARE res BOOL := FALSE;
BEGIN
res := (
    WITH
        foo AS (
            SELECT id, peer, task, is_task_completed(id) AS mark
            FROM "Checks"
        )
    SELECT count(mark = TRUE)
    FROM foo
    WHERE peer = x_peer AND task = x_task AND mark
    ) > 0;
RETURN res;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fnc_has_peer_completed_block(x_peer VARCHAR, x_block VARCHAR)
RETURNS BOOL AS $$
SELECT (
    WITH
        foo AS (
            SELECT tk.title, fnc_has_peer_completed_task(x_peer, tk.title) AS mark
            FROM "Tasks" tk
            WHERE fnc_get_task_block(title) = x_block
        )
    SELECT count(*) FROM foo WHERE mark = FALSE
) = 0
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION fnc_when_peer_completed_block(x_peer VARCHAR, x_block VARCHAR)
RETURNS DATE AS $$
WITH
foo AS (
    SELECT tk.title, max(ch.check_date) AS max_date
    FROM "Tasks" tk
    JOIN "Checks" ch ON ch.peer = x_peer AND tk.title = ch.task
    WHERE fnc_get_task_block(title) = x_block
    AND get_check_overall_status(ch.id) = 'success'
    GROUP BY tk.title
)
SELECT max(max_date)
FROM foo
$$ LANGUAGE sql;

CREATE OR REPLACE PROCEDURE who_and_when_completed_block(res REFCURSOR, x_block VARCHAR) AS $$
BEGIN
CALL has_block(x_block);
OPEN res FOR
WITH
foo AS (
    SELECT nickname
    FROM "Peers"
    WHERE fnc_has_peer_completed_block(nickname, x_block)
)
SELECT nickname, fnc_when_peer_completed_block(nickname, x_block) AS "DATE"
FROM foo;
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
-- CALL who_and_when_completed_block('res', 'C');
-- fetch ALL FROM "res";
-- close "res";
-- END;

-- 10) Determine which peer each student should go to for a check.
-- You should determine it according to the recommendations of the peer's
-- friends, i.e. you need to find the peer with the greatest number of
-- friends who recommend to be checked by him.
-- Output format: peer's nickname, nickname of the checker found
CREATE OR REPLACE FUNCTION fnc_recommended_for_peer(x_peer VARCHAR)
RETURNS TABLE ("RecommendedPeer" VARCHAR) AS $$
WITH
foo AS (
    SELECT fr.peer2 AS friend
    FROM "Friends" fr WHERE fr.peer1 = x_peer
    UNION
    SELECT fr.peer1 AS friend
    FROM "Friends" fr WHERE fr.peer2 = x_peer
),
bar AS (
    SELECT re.recommended_peer AS recommended, count(DISTINCT(re.recommended_peer)) AS cnt
    FROM foo
    JOIN "Recommendations" re ON foo.friend = re.peer AND x_peer != re.recommended_peer
    GROUP BY re.recommended_peer
)
SELECT recommended
FROM bar
WHERE cnt = (SELECT max(cnt) FROM bar)
ORDER BY recommended
$$ LANGUAGE sql;

CREATE OR REPLACE PROCEDURE recommended_to_check(res REFCURSOR) AS $$
BEGIN
OPEN res FOR
SELECT pp1.nickname AS peer, pp2.nickname AS checker
FROM "Peers" pp1
JOIN "Peers" pp2 ON pp2.nickname
    IN (
        SELECT *
        FROM fnc_recommended_for_peer(pp1.nickname)
    );
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
-- CALL recommended_to_check('res');
-- fetch ALL FROM "res";
-- close "res";
-- END;

-- 11) Determine the percentage of peers who:
-- Started block 1
-- Started block 2
-- Started both
-- Have not started any of them
-- Procedure parameters: name of block 1, for example CPP, name of block 2,
-- for example A.
-- Output format: percentage of those who started the first block, 
-- percentage of those who started the second block, percentage of those 
-- who started both blocks, percentage of those who did not started any of
-- them
CREATE OR REPLACE FUNCTION fnc_peer_overall_task_status(x_peer VARCHAR, x_task VARCHAR)
RETURNS check_status_type AS $$
DECLARE
    res check_status_type := NULL;
    tmp check_status_type;
    each BIGINT;
BEGIN
FOR each IN (SELECT id FROM "Checks" WHERE peer = x_peer AND task = x_task)
    LOOP
        tmp := get_check_overall_status(each);
    IF (tmp = 'success') THEN res := 'success';
        EXIT;
    ELSEIF (tmp = 'failure' AND (res != 'success' OR res IS NULL)) THEN res := 'failure';
    ELSEIF (tmp = 'start' AND (res NOT IN ('success', 'failure') OR res IS NULL)) THEN res := 'start';
    END IF;
    END LOOP;
RETURN res;
END 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fnc_has_peer_started_block(x_peer VARCHAR, x_block VARCHAR)
RETURNS BOOL AS $$
BEGIN
RETURN (
    WITH
    foo AS (
        SELECT title, fnc_peer_overall_task_status(x_peer, title) AS st
        FROM fnc_tasks_of_the_block(x_block)
    )
    SELECT count(*)
    FROM foo
    WHERE st IS NOT NULL
    ) > 0;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE two_block_stats(res REFCURSOR, block_1 VARCHAR, block_2 VARCHAR) AS $$
DECLARE
    total FLOAT := 0.01 * (SELECT count(*) FROM "Peers")::FLOAT;
BEGIN
OPEN res FOR
WITH
foo AS (
    SELECT fnc_has_peer_started_block(nickname, block_1) AS bar1,
           fnc_has_peer_started_block(nickname, block_2) AS bar2
    FROM "Peers"
)
SELECT
    ((SELECT count(*) FROM foo WHERE bar1 = TRUE AND bar2 = FALSE)::FLOAT / total)::BIGINT AS "started 1",
    ((SELECT count(*) FROM foo WHERE bar1 = FALSE AND bar2 = TRUE)::FLOAT / total)::BIGINT AS "started 2",
    ((SELECT count(*) FROM foo WHERE bar1 = TRUE AND bar2 = TRUE)::FLOAT / total)::BIGINT AS "started both",
    ((SELECT count(*) FROM foo WHERE bar1 = FALSE AND bar2 = FALSE)::FLOAT / total)::BIGINT AS "started none";
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
-- CALL two_block_stats('res', 'C', 'CPP');
-- fetch ALL FROM "res";
-- close "res";
-- END;

-- 12) Determine N peers with the greatest number of friends
-- Parameters of the procedure: the N number of peers .
-- The result IS sorted BY the number of friends.
-- Output format: peer's name, number of friends
CREATE OR REPLACE PROCEDURE most_friendly_peers(res REFCURSOR, N BIGINT) AS $$
BEGIN
OPEN res FOR
WITH
foo AS (
    SELECT pp.nickname AS peer1, peer2
    FROM "Peers" pp
    LEFT JOIN "Friends" ff ON pp.nickname = ff.peer1
    UNION
    SELECT peer2, peer1
    FROM "Friends"
)
SELECT peer1 AS "Peer", count(DISTINCT(peer2))::BIGINT AS "FriendsCount"
FROM foo
GROUP BY peer1
ORDER BY 2 DESC, 1
LIMIT N;
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
-- CALL most_friendly_peers('res', 3);
-- fetch ALL FROM "res";
-- close "res";
-- END;

-- 13) Determine the percentage of peers who have ever successfully passed 
-- a check on their birthday
-- Also determine the percentage of peers who have ever failed a check on
-- their birthday.
-- Output format: percentage of successes on birthday, percentage of
-- failures on birthday
CREATE OR REPLACE PROCEDURE birthday_checks_stats(res REFCURSOR) AS $$
DECLARE
    total FLOAT := 0.01 * (SELECT count(*) FROM "Peers")::FLOAT;
BEGIN
OPEN res FOR
WITH
foo AS (
    SELECT pp.nickname AS peer, get_check_overall_status(cc.id) AS st
    FROM "Peers" pp
    JOIN "Checks" cc ON pp.nickname = cc.peer
    WHERE extract(MONTH FROM pp.birthday) = extract(MONTH FROM cc.check_date)
        AND extract(DAY FROM pp.birthday) = extract(DAY FROM cc.check_date)
)
SELECT (
        SELECT (count(DISTINCT(peer))::FLOAT / total)::BIGINT
        FROM foo
        WHERE st = 'success'
      ) AS "SuccessfulChecks",
      (
        SELECT (count(DISTINCT(peer))::FLOAT / total)::BIGINT
        FROM foo
        WHERE st = 'failure'
      ) AS "UnsuccessfulChecks";
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
-- CALL birthday_checks_stats('res');
-- fetch ALL FROM "res";
-- close "res";
-- END;

-- 14) Determine the total amount of XP gained BY each peer
-- If one task is performed more than once, the amount of XP received FOR
--  it equals its maximum amount FOR that task.
-- Output the result sorted by number of XP.
-- Output format: peer's name, the number of XP
CREATE OR REPLACE PROCEDURE peers_total_xp(res REFCURSOR) AS $$
BEGIN
OPEN res FOR
WITH
foo AS (
    SELECT pp.nickname, cc.task, max(xp.xp_amount) AS max_xp
    FROM "Peers" pp
    LEFT JOIN "Checks" cc ON pp.nickname = cc.peer
    LEFT JOIN "XP" xp ON cc.id = xp.check_id
    GROUP BY (nickname, task)
)
SELECT nickname AS "Peer", coalesce(sum(max_xp), 0)::BIGINT AS "XP"
FROM foo
GROUP BY "Peer"
ORDER BY "XP" DESC, "Peer";
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
-- CALL peers_total_xp('res');
-- fetch ALL FROM "res";
-- close "res";
-- END;

-- 15) Determine all peers who did the given tasks 1 and 2, but did not do
-- task 3
-- Procedure parameters: names of tasks 1, 2 and 3.
-- Output format: list of peers
CREATE OR REPLACE PROCEDURE duck_duck_goose(res REFCURSOR, task_1 VARCHAR, task_2 VARCHAR, task_3 VARCHAR) AS $$
BEGIN
OPEN res FOR
WITH
foo AS (
    SELECT pp.nickname AS peer,
        fnc_has_peer_completed_task(pp.nickname, task_1) AS res_1,
        fnc_has_peer_completed_task(pp.nickname, task_2) AS res_2,
        fnc_has_peer_completed_task(pp.nickname, task_3) AS res_3
    FROM "Peers" pp
)
SELECT peer
FROM foo
WHERE res_1 = TRUE AND res_2 = TRUE AND res_3 = FALSE;
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
-- CALL duck_duck_goose('res', 'C2_SimpleBash', 'C3_s21_string', 'C4_s21_math');
-- fetch ALL FROM "res";
-- close "res";
-- END;

-- 16) Using a recursive common table expression, for each task print the number of previous tasks
-- That is, how many tasks need to be completed, based on the login conditions,
-- in order to gain access to the current one.
-- Output format: task name, number of previous ones
CREATE OR REPLACE PROCEDURE prc_previous_tasks(res REFCURSOR) AS $$
BEGIN
OPEN res FOR
WITH RECURSIVE
prev(title, parent, count) AS (
    SELECT "Tasks".title, "Tasks".parent_task, 0
    FROM "Tasks"
    UNION
    SELECT "Tasks".title, "Tasks".parent_task, count + 1
    FROM "Tasks"
    INNER JOIN  prev ON prev.title = "Tasks".parent_task
)
SELECT title, max(count)
FROM prev
GROUP BY title;
END
$$ LANGUAGE plpgsql;

-- BEGIN;
--     CALL prc_previous_tasks(res := 'res');
--     FETCH ALL FROM "res";
--     CLOSE "res";
-- END;

-- 17) Find "lucky" days FOR checks. A dat is considered "lucky" if it has
-- at least N consecutive successful checks
-- Parameters of the procedure: the N number of consecutive successful checks.
-- The time of the check is the start time of the P2P step.
-- Successful consecutive checks are the checks with no unsuccessful checks
-- in between.
-- The amount of XP for each of these checks must be at least 80% of the
-- maximum. 
-- Output format: list of days
CREATE OR REPLACE PROCEDURE prc_lucky_days(IN ref REFCURSOR, IN N INTEGER) AS $$
BEGIN
OPEN ref FOR
WITH 
tmp AS (
	SELECT id, task, check_state, prev, check_date,
	CASE WHEN "check_state" = 'success' AND ("check_state" = prev OR prev IS NULL) THEN 1
		ELSE 0
	END, "max_xp", "xp_amount"
    FROM (
        SELECT "Checks".id, "Checks".check_date, "Checks".peer, "Checks".task, "P2P".check_state,
                LAG("P2P".check_state) OVER(PARTITION BY "Checks".check_date ORDER BY "Checks".check_date) AS prev,
		        "max_xp", "xp_amount"
        FROM "P2P"
		JOIN "Checks" ON "Checks".id = "P2P".check_id
		LEFT JOIN "XP" ON "XP".check_id = "Checks".id
		LEFT JOIN "Tasks" ON "Tasks".title = "Checks".task
		WHERE check_state = 'success' OR check_state = 'failure'
    ) AS res
    ORDER BY check_date
)
SELECT t1.check_date
FROM (
	SELECT check_date, COUNT(check_date) AS "count"
	FROM tmp
	WHERE "check_state" = 'success' AND ("check_state" = prev OR prev IS NULL) AND tmp.xp_amount > tmp."max_xp" * 0.8
	GROUP BY check_date
) AS t1
GROUP BY t1.check_date
HAVING MAX(count) >= N;
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
--   CALL prc_lucky_days('res', 3);
--   FETCH ALL FROM "res";
--   CLOSE "res";
-- END;

-- 18) Determine the peer with the highest number of completed tasks
-- Output format: peer nickname, number of tasks completed
CREATE OR REPLACE PROCEDURE prc_peer_max_tasks(res REFCURSOR) AS $$
BEGIN
    OPEN res FOR
    WITH tasks AS (
        SELECT "Tasks".title AS task_name
        FROM "Tasks"
    )
    SELECT "Peers".nickname nick,
       count(fnc_has_peer_completed_task("Peers".nickname, task_name)) amount
    FROM "Peers"
    JOIN tasks ON fnc_has_peer_completed_task("Peers".nickname, task_name)
    GROUP BY nick
    ORDER BY amount DESC
    LIMIT 1;
END
$$ LANGUAGE plpgsql;

-- BEGIN;
--     CALL prc_peer_max_tasks(res := 'res');
--     FETCH ALL FROM "res";
--     CLOSE "res";
-- END;


-- 19) Find the peer with the highest amount of XP
-- Output format: peer's nickname, amount of XP
CREATE OR REPLACE PROCEDURE prc_get_max_xp(IN ref REFCURSOR) AS $$
BEGIN
OPEN ref FOR
WITH
foo AS (
    SELECT pp.nickname, cc.task, max(xp.xp_amount) AS max_xp
    FROM "Peers" pp
    LEFT JOIN "Checks" cc ON pp.nickname = cc.peer
    LEFT JOIN "XP" xp ON cc.id = xp.check_id
    GROUP BY (nickname, task)
)
SELECT nickname AS "Peer", coalesce(sum(max_xp), 0)::BIGINT AS "XP"
FROM foo
GROUP BY "Peer"
ORDER BY "XP" DESC
LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
--   CALL prc_get_max_xp('res');
--   FETCH ALL FROM "res";
--   CLOSE "res";
-- END;

-- 20) Identify the peer who spent the most time on campus today
-- Output format: peer nickname
CREATE OR REPLACE PROCEDURE prc_peer_max_time(res REFCURSOR) AS $$
BEGIN
OPEN res FOR
SELECT visits."Peer"
FROM fnc_peers_visiting_times() visits
GROUP BY visits."Peer"
ORDER BY sum(visits."Finish" - visits."Start") DESC
LIMIT 1;
END
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS fnc_peers_visiting_times();
CREATE OR REPLACE FUNCTION fnc_peers_visiting_times()
RETURNS TABLE ("Peer" VARCHAR, "Start" TIME, "Finish" TIME) AS $$
WITH
start AS (
    SELECT id, peer, event_time
    FROM "TimeTracking"
    WHERE event_date = CURRENT_DATE AND event_state = 1
),
finish AS (
    SELECT id, peer, event_time
    FROM "TimeTracking"
    WHERE event_date = CURRENT_DATE AND event_state = 2
),
join_table AS (
    SELECT DISTINCT ON (start.id) start.id AS start_id,
                        start.peer         AS start_peer,
                        start.event_time   AS start_time,
                        finish.id          AS finish_id,
                        finish.peer        AS finish_peer,
                        finish.event_time  AS finish_time
    FROM start
    INNER JOIN finish ON start.peer = finish.peer AND start.event_time < finish.event_time
    ORDER BY 1, 2, 3, 6
)
SELECT start_peer, start_time, finish_time
FROM join_table;
$$ LANGUAGE sql;

-- BEGIN;
--     CALL prc_peer_max_time(res := 'res');
--     FETCH ALL FROM "res";
--     CLOSE "res";
-- END;

-- 21) Determine the peers that came before the given time at least N times during the whole time
-- Procedure parameters: time, N number of times
CREATE OR REPLACE PROCEDURE prc_get_came_ahead_time(IN ref REFCURSOR, search_time TIME, n INTEGER) AS $$
BEGIN
OPEN ref FOR
WITH
cameAheadTime AS (
	SELECT peer, event_date, min(event_time)
	FROM "TimeTracking"
	WHERE "event_state" = '1' AND "event_time" < search_time
	GROUP BY peer, event_date
	ORDER BY event_date
)
SELECT peer
FROM cameAheadTime
GROUP BY peer
HAVING count("event_date") >= n;
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
--   CALL prc_get_came_ahead_time('res', '12:00', 2);
--   FETCH ALL FROM "res";
--   CLOSE "res";
-- END;

-- 22) Find peers who have left the campus more than M times IN the last N days
-- Procedure parameters: number of days N, number of times M.
-- Output format: list of peers
CREATE OR REPLACE PROCEDURE prc_peers_exited_times(res REFCURSOR, N BIGINT, M BIGINT) AS $$
BEGIN
OPEN res FOR
SELECT peer
FROM "TimeTracking"
WHERE "TimeTracking".event_state = 2 AND current_date - "TimeTracking".event_date <= N
GROUP BY peer
HAVING count(peer) > M;
END
$$ LANGUAGE plpgsql;

-- BEGIN;
--     CALL prc_peers_exited_times(res := 'res', N := 15, M := 1);
--     FETCH ALL FROM "res";
--     CLOSE "res";
-- END;

-- 23) Determine which peer was the last to come IN today
CREATE OR REPLACE PROCEDURE prc_get_came_last_peer(IN ref REFCURSOR) AS $$
BEGIN
OPEN ref FOR
WITH
cameLast AS (
	SELECT peer, "event_date", min("event_time") AS first_entry
	FROM "TimeTracking"
	WHERE "event_state" = '1' AND "event_date" = now()::DATE
	GROUP BY peer, "event_date"
)
SELECT peer
FROM cameLast
ORDER BY first_entry DESC
LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
--   CALL prc_get_came_last_peer('res');
--   FETCH ALL FROM "res";
--   CLOSE "res";
-- END;

-- 24) Determine the peers who left the campus yesterday for more than N minutes
-- Procedure parameters: number of minutes N.
-- Output format: list of peers
CREATE OR REPLACE FUNCTION fnc_peers_exited_times()
RETURNS TABLE ("Peer" VARCHAR, "Start" TIME, "Finish" TIME) AS $$
WITH
start AS (
    SELECT id, peer, event_time
    FROM "TimeTracking"
    WHERE event_date = CURRENT_DATE - 1 AND event_state = 2
),
finish AS (
    SELECT id, peer, event_time
    FROM "TimeTracking"
    WHERE event_date = CURRENT_DATE - 1 AND event_state = 1
),
join_table AS (
    SELECT DISTINCT ON (start.id) start.id AS start_id,
                        start.peer         AS start_peer,
                        start.event_time   AS start_time,
                        finish.id          AS finish_id,
                        finish.peer        AS finish_peer,
                        finish.event_time  AS finish_time
    FROM start
    INNER JOIN finish ON start.peer = finish.peer AND start.event_time < finish.event_time
    ORDER BY 1, 2, 3, 6
)
SELECT start_peer, start_time, finish_time
FROM join_table;
$$ LANGUAGE sql;

CREATE OR REPLACE PROCEDURE prc_peers_exited_minutes(res REFCURSOR , N BIGINT) AS $$
BEGIN
OPEN res FOR
SELECT visits."Peer" peer
FROM fnc_peers_exited_times() visits
GROUP BY peer
HAVING sum(visits."Finish" - visits."Start") > concat(N, 'minutes')::INTERVAL;
END
$$ LANGUAGE plpgsql;

-- BEGIN;
--     CALL prc_peers_exited_minutes(res := 'res', N := 15);
--     FETCH ALL FROM "res";
--     CLOSE "res";
-- END;

-- 25) Determine for each month the percentage of early entries
-- For each month, count how many times people born in that month came
-- to campus during the whole time (we'll call this the total number of
-- entries). 
-- For each month, count the number of times people born in that month
-- have come to campus before 12:00 in all time (we'll call this the
-- number of early entries). 
-- For each month, count the percentage of early entries to campus
-- relative to the total number of entries. 
-- Output format: month, percentage of early entries
CREATE OR REPLACE PROCEDURE prc_visits_in_month_of_birth(IN ref REFCURSOR) AS $$
BEGIN
OPEN ref FOR
WITH
VisitsInMonthOfBirth AS (
	SELECT TO_CHAR(TO_DATE(month_num::text, 'MM'), 'Month') AS "Month",
	    (
	    SELECT count(tt.peer)
		FROM (
			SELECT peer, event_date FROM "TimeTracking"
			WHERE peer IN (SELECT nickname FROM "Peers" WHERE EXTRACT(MONTH FROM birthday) = month_num)
			GROUP BY peer, event_date HAVING min("event_time") <= '24:00:00') AS tt) AS "AllVisits",
			   (
			    SELECT count(tt.peer)
				FROM (
				    SELECT peer, event_date FROM "TimeTracking"
					WHERE peer IN (SELECT nickname FROM "Peers" WHERE EXTRACT(MONTH FROM birthday) = month_num)
					GROUP BY peer, event_date HAVING min("event_time") <= '12:00:00') AS tt) AS "EarlyVisits"
		FROM generate_series(1, 12) AS month_num
)
SELECT "Month",
	CASE WHEN "AllVisits" = 0 THEN 0
	    ELSE ("EarlyVisits" * 100 / "AllVisits")
	END AS "EarlyEntries"
FROM VisitsInMonthOfBirth
ORDER BY to_date("Month", 'Mon');
END;
$$ LANGUAGE plpgsql;

-- BEGIN;
--   CALL prc_visits_in_month_of_birth('res');
--   FETCH ALL FROM "res";
--   CLOSE "res";
-- END;
