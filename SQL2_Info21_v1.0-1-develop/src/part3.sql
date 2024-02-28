----------------------------------1----------------------------------

CREATE OR REPLACE FUNCTION fnc_get_transferred_points_summary()
RETURNS TABLE (
    peer1_nickname varchar,
    peer2_nickname varchar,
    points_amount integer
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        tp1.checking_peer AS peer1_nickname,
        tp1.checked_peer AS peer2_nickname,
        CASE
            WHEN tp2.id IS NOT NULL THEN tp1.points_amount - tp2.points_amount
            ELSE tp1.points_amount
        END AS points_amount
    FROM transferred_points tp1
    LEFT JOIN transferred_points tp2 ON tp1.checking_peer = tp2.checked_peer
                                AND tp1.checked_peer = tp2.checking_peer;
END;
$$ LANGUAGE plpgsql;

-- SELECT * FROM fnc_get_transferred_points_summary() ORDER BY peer1_nickname

----------------------------------2----------------------------------

CREATE OR REPLACE FUNCTION fnc_tasks_success()
	RETURNS TABLE(peer varchar,
				  task varchar,
				  XP int) AS $$
BEGIN
	RETURN QUERY (
		SELECT peers.nickname AS peer,
			checks.task,
			xp.xp_amount AS XP
		FROM xp
			JOIN checks ON xp.check_id = checks.id
			JOIN peers ON  checks.peer = peers.nickname
		ORDER BY 1
	);
END;
$$ LANGUAGE plpgsql;

-- SELECT * FROM fnc_tasks_success()

----------------------------------3----------------------------------

CREATE OR REPLACE FUNCTION fnc_get_persistent_peers(in_date date)
RETURNS TABLE (peer_nickname varchar) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT peer
    FROM time_tracking
    WHERE "date" = in_date
    GROUP BY peer
    HAVING MAX("state") = 1;
END;
$$ LANGUAGE plpgsql;

--SELECT * FROM get_persistent_peers('2023-10-10')

/*
SELECT * FROM time_tracking
INSERT INTO time_tracking
VALUES ((SELECT COUNT(*) FROM time_tracking) + 1, 'C', '2023-10-10', '09:10:10', 1),
		((SELECT COUNT(*) FROM time_tracking) + 2, 'C', '2023-10-11', '21:10:10', 2)
		
*/

----------------------------------4----------------------------------

CREATE OR REPLACE PROCEDURE proc_points_change(r REFCURSOR DEFAULT 'ref') 
AS $$
BEGIN
    OPEN r FOR
    SELECT peer, SUM(points) AS points_change
        FROM (SELECT checking_peer AS peer, points_amount AS points FROM transferred_points
        	  UNION ALL
        	  SELECT checked_peer AS peer, 0 - points_amount AS points FROM transferred_points) AS tmp 
        GROUP BY peer
        ORDER BY points_change DESC;
END;
$$ LANGUAGE plpgsql;

--CALL proc_points_change();
--FETCH ALL FROM "ref";

----------------------------------5----------------------------------

CREATE OR REPLACE PROCEDURE proc_points_change_first_func(r REFCURSOR DEFAULT 'ref') 
AS $$
BEGIN
    OPEN r FOR
    SELECT peer, SUM(points) AS points_change
		FROM (SELECT peer1_nickname AS peer, points_amount AS points FROM fnc_get_transferred_points_summary()
			  WHERE peer1_nickname != peer2_nickname AND points_amount >= 0
			  UNION ALL
			  SELECT peer2_nickname AS peer, 0 - points_amount AS points FROM fnc_get_transferred_points_summary()
			 WHERE peer1_nickname != peer2_nickname AND points_amount >= 0) as tmp
	GROUP BY peer
ORDER BY points_change DESC;
END;
$$ LANGUAGE plpgsql;

--CALL proc_points_change_first_func();
--FETCH ALL FROM "ref";

----------------------------------6----------------------------------

CREATE OR REPLACE PROCEDURE proc_most_task(r REFCURSOR DEFAULT 'ref') 
AS $$
BEGIN
    OPEN r FOR
        WITH checks_count AS (SELECT date, task, COUNT(task) AS amount
							  FROM checks
							  GROUP BY date, task),
			 max_count AS (SELECT c.date, c.task, c.amount FROM checks_count AS c
						   WHERE amount = (SELECT MAX(amount) FROM checks_count WHERE checks_count.date = c.date))		
        SELECT date, task, amount
		FROM max_count
		ORDER BY date;

END;
$$ LANGUAGE plpgsql;

--CALL proc_most_task();
--FETCH ALL FROM "ref";

----------------------------------7----------------------------------

CREATE OR REPLACE PROCEDURE proc_finished_block(block varchar, r REFCURSOR DEFAULT 'ref') 
AS $$
BEGIN
    OPEN r FOR
		WITH block_name AS (
			SELECT title AS task
			FROM tasks
			WHERE substring(title FROM '.+?(?=\d{1,2})') = block
			ORDER BY 1 DESC
			LIMIT 1
		)
		SELECT peer, date AS day
		FROM p2p
		JOIN checks ON p2p.check_id = checks.id
		JOIN verter On verter.check_id = checks.id
		WHERE p2p.state = 'Success' 
			AND (verter.state = 'Success' OR verter.state = NULL)
			AND checks.task = (SELECT task FROM block_name);
END;
$$ LANGUAGE plpgsql;		
		
--CALL proc_finished_block('C');
--FETCH ALL FROM "ref";

----------------------------------8----------------------------------

CREATE OR REPLACE PROCEDURE proc_friend_check(r REFCURSOR DEFAULT 'ref') 
AS $$
BEGIN
    OPEN r FOR
		SELECT peer_1 AS peer, recommended_peer
		FROM (SELECT peer_1, peer_2 FROM friends
			  UNION
			  SELECT peer_2 as peer_1, peer_1 AS peer_2 FROm friends) AS fr
		JOIN recommendations AS rc ON fr.peer_2 = rc.peer
		WHERE peer_1 != recommended_peer
		GROUP BY peer_1, recommended_peer
		ORDER BY peer_1, COUNT(recommended_peer);
END;
$$ LANGUAGE plpgsql;


--CALL proc_friend_check();
--FETCH ALL FROM "ref";

----------------------------------9----------------------------------

CREATE OR REPLACE PROCEDURE proc_block_participation(block1 varchar, block2 varchar, r REFCURSOR DEFAULT 'ref') 
AS $$
BEGIN
    OPEN r FOR
	WITH peers_total AS (SELECT COUNT(peers.nickname) as num FROM peers),
     	b1 AS (SELECT peer, 1 AS bl1 FROM checks
                WHERE substring(task FROM '.+?(?=\d{1,2})') = block1),
     	b2 AS  (SELECT peer, 1 AS bl2 FROM checks
                WHERE substring(task FROM '.+?(?=\d{1,2})') = block2),
     	peers_by_block AS (SELECT COALESCE(b1.peer, b2.peer) as peer_name, bl1, bl2, 
                       	COALESCE(b1.bl1, b2.bl2) as "both"
                       	FROM b1
						FULL JOIN b2 ON b1.peer = b2.peer
						GROUP BY peername, b1.bl1, b2.bl2)

SELECT ROUND(CAST(COUNT(peer_by_block.bl1) AS NUMERIC)*100/peers_total.num, 0) AS started_block_1, 
	ROUND(CAST(COUNT(peer_by_block.bl2) AS NUMERIC)*100/peers_total.num, 0) AS started_block_2, 
	ROUND(CAST(COUNT(peer_by_block.both) AS NUMERIC)*100/peers_total.num, 0) AS started_both_blocks, 
	100-ROUND(CAST(COUNT(peer_by_block.both) AS NUMERIC)*100/peers_total.num, 0) AS didnt_start_any_blocs
FROM peer_by_block, peers_total
GROUP BY peers_total.num, peer_by_block.bl1
LIMIT 1; 
END;
$$ LANGUAGE plpgsql;

--CALL proc_block_participation('C', 'SQL');
--FETCH ALL FROM "ref";

----------------------------------10----------------------------------

CREATE OR REPLACE PROCEDURE proc_peer_birthday_pass(r REFCURSOR DEFAULT 'ref') 
AS $$
BEGIN
    OPEN r FOR
        
		WITH peers_total AS (SELECT COUNT(peers.nickname) as num FROM peers),
		bd AS (SELECT * FROM checks 
        			JOIN peers ON checks.peer = peers.nickname 
        			WHERE EXTRACT(MONTH FROM checks.date) = EXTRACT(MONTH FROM peers.birthday)
							AND EXTRACT(DAY FROM checks.date) = EXTRACT(DAY FROM peers.birthday)),
        success AS (SELECT peer, (CASE
								 STATE WHEN 'Success'
								 THEN 1
								 ELSE NULL
								 END) AS ok
					FROM bd
        			JOIN p2p ON p2p.check_id = bd.id), 
        failure AS (SELECT peer, (CASE
								 STATE WHEN 'Failure'
								 THEN 1
								 ELSE NULL
								 END) AS bad
					FROM bd
        			JOIN p2p ON p2p.check_id = bd.id)
        
		SELECT ROUND((SELECT COUNT(DISTINCT peer) FROM success WHERE ok = 1) * 100 / peers_total.num, 0) AS successful_checks,
        	   ROUND((SELECT COUNT(DISTINCT peer) FROM failure WHERE bad = 1) * 100 / peers_total.num, 0) AS unsuccessful_checks
        FROM success, failure, peers_total
		GROUP BY peers_total.num;
		
END;
$$ LANGUAGE plpgsql;

--CALL proc_peer_birthday_pass();
--FETCH ALL FROM "ref";

----------------------------------11----------------------------------

CREATE OR REPLACE PROCEDURE proc_completed_tasks(task1_title varchar,
												 task2_title varchar,
												 task3_title varchar,
												 r REFCURSOR DEFAULT 'ref') 
AS $$
   BEGIN
   OPEN r FOR
        WITH task1 AS (SELECT DISTINCT c.peer
					   FROM checks c, xp
					   WHERE c.id = xp.check_id
                             AND c.task = task1_title),
             task2 AS (SELECT DISTINCT c.peer
					   FROM checks c, xp
					   WHERE c.id = xp.check_id
                             AND c.task = task2_title),
             task3 AS (SELECT DISTINCT c.peer
					   FROM checks c, xp
					   WHERE c.id = xp.check_id
                 			 AND c.task = task3_title)
		SELECT peer FROM task1
        INTERSECT
        SELECT peer FROM task2
        EXCEPT
        SELECT peer FROM task3 
		ORDER BY peer ASC;
END;
$$ LANGUAGE plpgsql;

--CALL proc_completed_tasks('C2_SimpleBashUtils', 'C3_s21_string+', 'DO3_LinuxMonitoring v1.0');
--FETCH ALL FROM "ref";

----------------------------------12----------------------------------

CREATE OR REPLACE PROCEDURE proc_count_parent_tasks(r REFCURSOR DEFAULT 'ref')
AS $$
	BEGIN
		OPEN r FOR
		WITH RECURSIVE ctl AS
		(SELECT
			(SELECT	title
				FROM tasks
				WHERE parent_task IS NULL) AS task,
				0 AS prev_count
			UNION ALL
			SELECT
				t.title,
				prev_count + 1
				FROM ctl
				JOIN tasks t ON t.parent_task = ctl.task)
		SELECT *
		FROM ctl;
	END;
$$ LANGUAGE plpgsql;

--CALL proc_count_parent_tasks();
--FETCH ALL FROM "ref";

----------------------------------13----------------------------------

CREATE OR REPLACE PROCEDURE proc_lucky_days(N int, r REFCURSOR DEFAULT 'ref')
AS $$
BEGIN
	OPEN r FOR
		WITH  total_checks AS (
			SELECT c.id, c.date, p2p.time, p2p.state, xp.xp_amount
			FROM checks c, p2p, xp
			WHERE c.id = p2p.check_id AND (p2p.state = 'Success' OR p2p.state = 'Failure')
				AND c.id = xp.check_id AND xp_amount >= (SELECT tasks.max_xp
														 FROM tasks
														 WHERE tasks.title = c.task) * 0.8
			ORDER BY c.date, p2p.time),
		 succes_in_a_row AS (
			SELECT id, date, time, state,
			(CASE WHEN state = 'Success' THEN row_number() over (partition by state, date) ELSE 0 END) AS amount
												 FROM total_checks ORDER BY date
		 ),
		 max_in_day AS (SELECT s.date, MAX(amount) amount FROM succes_in_a_row s GROUP BY date)

		 SELECT date AS day FROM max_in_day WHERE amount >= N;
END;
$$ LANGUAGE plpgsql;

--CALL proc_lucky_days(2);
--FETCH ALL FROM "ref";

----------------------------------14----------------------------------

CREATE OR REPLACE PROCEDURE proc_max_xp(r REFCURSOR DEFAULT 'ref')
AS $$
BEGIN
	OPEN r FOR
		SELECT peer, SUM(xp_amount) AS XP
		FROM xp
		JOIN checks ON xp.check_id = checks.id
		GROUP BY peer
		ORDER BY XP DESC
		LIMIT 1;
	END;
$$ LANGUAGE plpgsql;

--CALL proc_max_xp();
--FETCH ALL FROM "ref";

----------------------------------15----------------------------------

CREATE OR REPLACE PROCEDURE proc_peer_comming(t time, m int, r REFCURSOR DEFAULT 'ref')
AS $$
BEGIN
	OPEN r FOR
		SELECT tt.peer
		FROM time_tracking AS tt
		WHERE tt.time < t
		GROUP BY tt.peer
		HAVING COUNT(*) >= m
		ORDER BY tt.peer;
END;
$$ LANGUAGE plpgsql;

--CALL proc_peer_comming('09:00:00'::time, 1);
--FETCH ALL FROM "ref";

----------------------------------16----------------------------------

CREATE OR REPLACE PROCEDURE proc_count_out(n int, m int, r REFCURSOR DEFAULT 'ref')
AS $$
BEGIN
	OPEN r FOR
	WITH l AS (
		SELECT *
		FROM (SELECT tt.peer AS peer, date, COUNT(state) AS o
				FROM time_tracking tt
			  WHERE state = 2
				GROUP BY peer, date) AS io
		WHERE (current_date - date) < n)

	SELECT peer FROM l
	GROUP BY peer, o
	HAVING o >= m;
END;
$$ LANGUAGE plpgsql;

--CALL proc_count_out(360, 2);
--FETCH ALL FROM "ref";

----------------------------------17----------------------------------

CREATE OR REPLACE PROCEDURE proc_calculate_early_entry_percentage(r REFCURSOR DEFAULT 'ref')
AS $$
DECLARE
    month_data RECORD;
    early_entries INTEGER;
    total_entries INTEGER;
    percentage FLOAT;
BEGIN
    OPEN r FOR
    WITH ctl AS (
		SELECT
			TO_CHAR(tt.date, 'YYYY-MM') AS "Month",
			COUNT(*) AS "TotalEntries",
			COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM tt.time) < 12) AS "EarlyEntries"
		FROM time_tracking AS tt
			INNER JOIN peers AS pr
				ON (tt.peer = pr.nickname)
		WHERE
			EXTRACT(MONTH FROM pr.birthday) = EXTRACT(MONTH FROM tt.date)
		GROUP BY
			"Month"
		ORDER BY
			"Month" ASC)


	SELECT ctl."Month", CASE ctl."TotalEntries"
					WHEN 0
					THEN 0
					ELSE round(coalesce(ctl."EarlyEntries", 0)::NUMERIC / ctl."TotalEntries"::NUMERIC * 100)
					END AS Percentage
	FROM ctl;

END;
$$ LANGUAGE PLPGSQL;

--CALL proc_calculate_early_entry_percentage();
--FETCH ALL FROM "ref";