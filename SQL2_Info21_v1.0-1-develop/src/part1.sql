----------------------------------1----------------------------------
-- CREATION OF THE DATABASE --

CREATE TABLE IF NOT EXISTS peers (
 	nickname varchar NOT NULL PRIMARY KEY,
	birthday date NOT NULL
);
 
CREATE TABLE IF NOT EXISTS tasks (
 	title varchar NOT NULL PRIMARY KEY,
	parent_task varchar,
	max_xp integer NOT NULL,
	FOREIGN KEY (parent_task) REFERENCES tasks (title)
);

-- creation of special type --
DROP TYPE IF EXISTS check_status;
CREATE TYPE check_status AS enum ('Start', 'Success', 'Failure');

CREATE TABLE IF NOT EXISTS checks (
 	id bigint PRIMARY KEY,
	peer varchar NOT NULL,
	task varchar NOT NULL,
	"date" date NOT NULL,
	FOREIGN KEY (task) REFERENCES tasks (title),
	FOREIGN KEY (peer) REFERENCES peers (nickname)
);

CREATE TABLE IF NOT EXISTS p2p (
 	id bigint PRIMARY KEY,
	check_id bigint NOT NULL,
	checking_peer varchar NOT NULL,
	"state" check_status NOT NULL,
	"time" time NOT NULL,
	FOREIGN KEY (check_id) REFERENCES checks (id),
	FOREIGN KEY (checking_peer) REFERENCES peers (nickname)
);

CREATE TABLE IF NOT EXISTS verter (
 	id bigint PRIMARY KEY,
	check_id bigint NOT NULL,
	"state" check_status NOT NULL,
	"time" time NOT NULL,
	FOREIGN KEY (check_id) REFERENCES checks (id)
);

CREATE TABLE IF NOT EXISTS transferred_points (
 	id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	checking_peer varchar NOT NULL,
	checked_peer varchar NOT NULL,
	points_amount integer NOT NULL,
	FOREIGN KEY (checking_peer) REFERENCES peers (nickname),
	FOREIGN KEY (checked_peer) REFERENCES peers (nickname)
);

CREATE TABLE IF NOT EXISTS friends (
 	id bigint PRIMARY KEY,
	peer_1 varchar NOT NULL,
	peer_2 varchar NOT NULL,
	FOREIGN KEY (peer_1) REFERENCES peers (nickname),
	FOREIGN KEY (peer_2) REFERENCES peers (nickname)
);

CREATE TABLE IF NOT EXISTS recommendations (
 	id bigint PRIMARY KEY,
	peer varchar NOT NULL,
	recommended_peer varchar NOT NULL,
	FOREIGN KEY (peer) REFERENCES peers (nickname),
	FOREIGN KEY (recommended_peer) REFERENCES peers (nickname)
);

CREATE TABLE IF NOT EXISTS xp (
 	id bigint PRIMARY KEY,
	check_id bigint NOT NULL,
	xp_amount integer NOT NULl,
	FOREIGN KEY (check_id) REFERENCES checks (id)
);

CREATE TABLE IF NOT EXISTS time_tracking (
 	id bigint PRIMARY KEY,
	peer varchar NOT NULL,
	"date" date NOT NULL,
	"time" time NOT NULL,
	"state" integer NOT NULL,
	FOREIGN KEY (peer) REFERENCES peers (nickname),
	CONSTRAINT state_check CHECK ("state" IN (1, 2))
);

----------------------------------2----------------------------------
-- PROCEDURES FOR IMPORT AND EXPORT DATA FROM/TO CSV --

CREATE OR REPLACE PROCEDURE import_from_csv(
    IN p_table_name TEXT,
    IN p_file_path TEXT,
	IN separator char
)
LANGUAGE plpgsql
AS $$
BEGIN
    EXECUTE 'COPY ' || p_table_name || ' FROM ''' || p_file_path || ''' DELIMITER ''' || separator || ''' CSV HEADER;';
END;
$$;

CREATE OR REPLACE PROCEDURE proc_export_to_csv(
    IN p_table_name TEXT,
    IN p_file_path TEXT,
	IN separator char
)
LANGUAGE plpgsql
AS $$
BEGIN
    EXECUTE 'COPY ' || p_table_name || ' TO ''' || p_file_path || ''' DELIMITER ''' || separator || ''' CSV HEADER;';
END;
$$;

----------------------------------3----------------------------------
-- BASIC INSERT OF SIMPLE DATA IN TABLE

INSERT INTO peers (nickname, birthday)
	VALUES 	('A', '1986-01-01');

CALL proc_import_from_csv('peers', '/Users/glenniss/projects/SQL2_Info21_v1.0-1/src/peers.csv', ',');

INSERT INTO tasks (title, parent_task, max_xp)
	VALUES	('C2_SimpleBashUtils', NULL, 250),
			('C3_s21_string+', 'C2_SimpleBashUtils', 500),
			('C4_s21_math', 'C2_SimpleBashUtils', 300),
			('C5_s21_decimal', 'C4_s21_math', 350),
			('C6_s21_matrix', 'C5_s21_decimal', 200),
			('C7_SmartCalc_v1.0', 'C6_s21_matrix', 500),
			('C8_3DViewer_v1.0', 'C7_SmartCalc_v1.0', 750),
			('DO1_Linux', 'C3_s21_string+', 300),
			('DO2_Linux Network', 'DO1_Linux', 250),
			('DO3_LinuxMonitoring v1.0', 'DO2_Linux Network', 350),
			('DO4_LinuxMonitoring v2.0', 'DO3_LinuxMonitoring v1.0', 350),
			('DO5_SimpleDocker', 'DO3_LinuxMonitoring v1.0', 300),
			('DO6_CICD', 'DO5_SimpleDocker', 300),
			('SQL1_Bootcamp', 'C8_3DViewer_v1.0', 1500),
			('SQL2_Info21 v1.0', 'SQL1_Bootcamp', 500),
			('SQL3_RetailAnalitycs v1.0', 'SQL2_Info21 v1.0', 600);
;	
			
INSERT INTO checks (id, peer, task, date)
	VALUES  (1, 'A', 'C2_SimpleBashUtils', '2023-01-01');
	
CALL proc_import_from_csv('checks', '/Users/glenniss/projects/SQL2_Info21_v1.0-1/src/checks.csv', ',');

INSERT INTO p2p (id, check_id, checking_peer, state, time)
	VALUES  (1, 1, 'E', 'Start', '08:00:00');

CALL proc_import_from_csv('p2p', '/Users/glenniss/projects/SQL2_Info21_v1.0-1/src/p2p.csv', ',');
			
INSERT INTO verter (id, check_id, state, time)
	VALUES  (1, 1, 'Start', '08:20:00');

CALL proc_import_from_csv('verter', '/Users/glenniss/projects/SQL2_Info21_v1.0-1/src/verter.csv', ',');

INSERT INTO friends (id, peer_1, peer_2)
	VALUES  (1, 'A', 'B');

CALL proc_import_from_csv('friends', '/Users/glenniss/projects/SQL2_Info21_v1.0-1/src/friends.csv', ',');

INSERT INTO recommendations  (id, peer, recommended_peer)
	VALUES  (1, 'A', 'E');

CALL proc_import_from_csv('recommendations', '/Users/glenniss/projects/SQL2_Info21_v1.0-1/src/recommendations.csv', ',');
 
INSERT INTO xp (id, check_id, xp_amount)
	VALUES  (1, 2, 210);

CALL proc_import_from_csv('xp', '/Users/glenniss/projects/SQL2_Info21_v1.0-1/src/xp.csv', ',');
		
INSERT INTO time_tracking (id, peer, date, time, state)
	VALUES  (1, 'A', '2023-01-01', '07:30:00', 1);

CALL proc_import_from_csv('time_tracking', '/Users/glenniss/projects/SQL2_Info21_v1.0-1/src/time_tracking.csv', ',');

-- 4
-- SPECIAL INSERT INTO TRANSFERRED_POINTS TABLE

INSERT INTO transferred_points (checking_peer, checked_peer, points_amount)
	SELECT checking_peer, peer, count(*)
	  FROM p2p
	  JOIN checks c on c.id = p2p.check_id
	 WHERE state != 'Start'
	 GROUP BY 1,2;

