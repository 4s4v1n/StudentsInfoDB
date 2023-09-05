INSERT INTO "Peers"
  VALUES
    ('aboba', '2000-01-01'),
    ('amogus', '2000-01-01'),
    ('impostor', '2002-05-06'),
    ('pepega', '1999-02-15'),
    ('nyancat', '2001-03-04');

INSERT INTO "Tasks"
  VALUES
    ('C2_SimpleBash', NULL, 250),
    ('C3_s21_string', 'C2_SimpleBash', 500),
    ('C4_s21_math', 'C2_SimpleBash', 300),
    ('DO1_Linux', 'C3_s21_string', 300),
    ('DO2_Linux_Network', 'DO1_Linux', 250),
    ('CPP1_s21_matrix+', 'C3_s21_string', 300),
    ('CPP2_s21_containers', 'CPP1_s21_matrix+', 350);

INSERT INTO "Friends"
  VALUES
    (1, 'aboba', 'amogus'),
    (2, 'amogus', 'impostor'),
    (3, 'impostor', 'aboba'),
    (4, 'impostor', 'nyancat'),
    (5, 'aboba', 'nyancat');

INSERT INTO "Recommendations"
  VALUES
    (1, 'aboba', 'impostor'),
    (2, 'aboba', 'pepega'),
    (3, 'nyancat', 'impostor'),
    (4, 'impostor', 'amogus'),
    (5, 'pepega', 'impostor');

INSERT INTO "Checks"
  VALUES
    (1, 'aboba', 'C2_SimpleBash', '2022-01-01'),
    (2, 'aboba', 'C2_SimpleBash', '2022-01-02'),
    (3, 'amogus', 'C2_SimpleBash', '2022-01-02'),
    (4, 'aboba', 'C2_SimpleBash', '2022-01-03'),
    (5, 'impostor', 'C2_SimpleBash', '2022-01-04'),
    (6, 'impostor', 'C3_s21_string', '2022-01-07'),
    (7, 'amogus', 'C3_s21_string', '2022-01-09'),
    (8, 'impostor', 'C4_s21_math', '2022-01-10'),
    (9, 'amogus', 'DO1_Linux', '2022-01-12'),
    (10, 'amogus', 'CPP1_s21_matrix+', '2022-01-17'),
    (11, 'aboba', 'C2_SimpleBash', '2023-01-01'),
    (12, 'aboba', 'C2_SimpleBash', '2023-01-01'),
    (13, 'aboba', 'C2_SimpleBash', '2023-01-01'),
    (14, 'aboba', 'C2_SimpleBash', '2023-01-01'),
    (15, 'aboba', 'C2_SimpleBash', '2023-01-01');

INSERT INTO "P2P"
  VALUES
    (1, 1, 'amogus', 'start', '12:00:00'),
    (2, 1, 'amogus', 'failure', '12:30:00'),
    (3, 2, 'pepega', 'start', '12:10:00'),
    (4, 3, 'impostor', 'start', '12:13:00'),
    (5, 2, 'pepega', 'success', '12:45:00'),
    (6, 3, 'impostor', 'success', '13:04:00'),
    (7, 4, 'nyancat', 'start', '12:00:00'),
    (8, 4, 'nyancat', 'success', '12:35:00'),
    (9, 5, 'aboba', 'start', '12:07:00'),
    (10, 5, 'aboba', 'success', '12:28:00'),
    (11, 6, 'amogus', 'start', '13:02:00'),
    (12, 6, 'amogus', 'success', '13:57:00'),
    (13, 7, 'impostor', 'start', '12:00:00'),
    (14, 7, 'impostor', 'success', '12:35:00'),
    (15, 8, 'pepega', 'start', '12:00:00'),
    (16, 8, 'pepega', 'success', '12:24:00'),
    (17, 9, 'nyancat', 'start', '12:15:00'),
    (18, 9, 'nyancat', 'failure', '12:42:00'),
    (19, 10, 'aboba', 'start', '11:45:00'),
    (20, 10, 'aboba', 'success', '12:16:00'),
    (21, 11, 'amogus', 'start', '12:00:00'),
    (22, 11, 'amogus', 'success', '13:00:00'),
    (23, 12, 'amogus', 'start', '14:00:00'),
    (24, 12, 'amogus', 'success', '15:00:00'),
    (25, 13, 'amogus', 'start', '16:00:00'),
    (26, 13, 'amogus', 'success', '17:00:00'),
    (27, 14, 'amogus', 'start', '19:00:00'),
    (28, 14, 'amogus', 'failure', '20:00:00'),
    (29, 15, 'amogus', 'start', '21:00:00'),
    (30, 15, 'amogus', 'success', '22:00:00');

INSERT INTO "Verter"
  VALUES
    (1, 2, 'start', '12:45:00'),
    (2, 2, 'failure', '12:48:00'),
    (3, 3, 'start', '13:05:00'),
    (4, 3, 'success', '13:09:00'),
    (5, 4, 'start', '12:37:00'),
    (6, 4, 'success', '12:42:00'),
    (7, 5, 'start', '12:32:00'),
    (8, 5, 'success', '12:37:00'),
    (9, 6, 'start', '13:59:00'),
    (10, 6, 'success', '14:12:00'),
    (11, 7, 'start', '12:35:00'),
    (12, 7, 'success', '12:41:00'),
    (13, 8, 'start', '12:25:00'),
    (14, 8, 'failure', '12:37:00'),
    (15, 11, 'start', '13:00:00'),
    (16, 11, 'success', '14:00:00'),
    (17, 12, 'start', '15:00:00'),
    (18, 12, 'success', '16:00:00'),
    (19, 13, 'start', '17:00:00'),
    (20, 13, 'success', '18:00:00'),
    (21, 15, 'start', '22:00:00'),
    (22, 15, 'success', '23:00:00');

INSERT INTO "XP"
  VALUES
    (1, 3, 225),
    (2, 4, 250),
    (3, 5, 213),
    (4, 6, 250),
    (5, 7, 475),
    (6, 10, 300),
    (7, 11, 230),
    (8, 12, 240),
    (9, 13, 250),
    (10, 15, 250);

INSERT INTO "TimeTracking"
  VALUES
    (1, 'aboba', '2022-01-01', '09:00:00', 1),
    (2, 'impostor', '2022-01-01', '09:30:00', 1),
    (3, 'impostor', '2022-01-01', '11:00:00', 2),
    (4, 'amogus', '2022-01-01', '14:15:00', 1),
    (5, 'aboba', '2022-01-01', '16:00:00', 2),
    (6, 'amogus', '2022-01-01', '16:30:00', 2),
    (7, 'amogus', '2022-01-01', '17:00:00', 1),
    (8, 'amogus', '2022-01-01', '18:10:00', 2),
    (9, 'aboba', '2022-01-02', '09:30:00', 1),
    (10, 'aboba', '2022-01-02', '10:05:00', 2),
    (11, 'aboba', '2022-01-02', '11:15:00', 1),
    (12, 'aboba', '2022-01-02', '12:40:00', 2),
    (13, 'impostor', '2022-02-01', '10:00:00', 1),
    (14, 'pepega', '2022-02-01', '10:15:00', 1),
    (15, 'impostor', '2022-02-01', '10:45:00', 2),
    (16, 'impostor', '2022-02-01', '11:05:00', 1),
    (17, 'impostor', '2022-02-01', '11:45:00', 2),
    (18, 'impostor', '2022-02-01', '12:10:00', 1),
    (19, 'impostor', '2022-02-01', '16:10:00', 2),
    (20, 'pepega', '2022-02-01', '17:00:00', 2),
    (21, 'aboba', CURRENT_DATE - 1, '13:00', 1),
    (22, 'aboba', CURRENT_DATE - 1, '14:00', 2),
    (23, 'amogus', CURRENT_DATE - 1, '14:00', 1),
    (24, 'aboba', CURRENT_DATE - 1, '14:10', 1),
    (25, 'aboba', CURRENT_DATE - 1, '15:00', 2),
    (26, 'amogus', CURRENT_DATE - 1, '15:00', 2),
    (27, 'aboba', CURRENT_DATE - 1, '15:10', 1),
    (28, 'amogus', CURRENT_DATE - 1, '15:15', 1),
    (29, 'aboba', CURRENT_DATE - 1, '16:00', 2),
    (30, 'amogus', CURRENT_DATE - 1, '16:00', 2),
    (31, 'aboba', CURRENT_DATE, '10:00:00', 1),
    (32, 'amogus', CURRENT_DATE, '10:30:00', 1),
    (33, 'aboba', CURRENT_DATE, '11:00:00', 2),
    (34, 'aboba', CURRENT_DATE, '12:00:00', 1),
    (35, 'amogus', CURRENT_DATE, '12:00:00', 2),
    (36, 'aboba', CURRENT_DATE, '13:00:00', 2);
