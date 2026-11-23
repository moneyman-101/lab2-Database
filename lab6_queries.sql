-- ============================================================
-- VUA-SEN307 Database Systems
-- Week 8 Practical, Lab 6: Aggregate Functions, Grouping and Subqueries
-- Name:        Marquis Daniel
-- Matric No:   VUG/SEN/24/11283
-- Date:        <DATE>
-- File:        lab6_queries.sql
-- ============================================================
-- Tables used (from Week 6):
--   Department(dept_id, dept_name)
--   Student(student_id, full_name, dept_id)
--   Course(course_id, course_title)
--   Enrolment(student_id, course_id)
-- ============================================================

USE university_db;   -- change to the name of your Week 6 database


-- ------------------------------------------------------------
-- Task 1: Count the students enrolled in each course,
--         including courses with zero students.
-- ------------------------------------------------------------
-- LEFT JOIN keeps every course, even one with no matching
-- enrolment. For such a course the join still produces ONE row,
-- but its Enrolment columns are all NULL.
-- COUNT(e.student_id) counts only non-NULL values, so that row
-- contributes 0. COUNT(*) would count the row itself and wrongly
-- report 1 student for an empty course.
SELECT c.course_title,
       COUNT(e.student_id) AS total_students
FROM Course c
LEFT JOIN Enrolment e ON c.course_id = e.course_id
GROUP BY c.course_id, c.course_title
ORDER BY total_students DESC;


-- ------------------------------------------------------------
-- Task 2: Courses with more than a given number of students,
--         using HAVING. Thresholds tried: 3, 5 and 7.
-- ------------------------------------------------------------
-- WHERE cannot be used here because it filters individual rows
-- BEFORE grouping, when the count does not exist yet.
-- HAVING filters the groups AFTER grouping, so it can test
-- the aggregate COUNT(e.student_id).

-- Threshold = 3
SELECT c.course_title,
       COUNT(e.student_id) AS total_students
FROM Course c
LEFT JOIN Enrolment e ON c.course_id = e.course_id
GROUP BY c.course_id, c.course_title
HAVING COUNT(e.student_id) > 3
ORDER BY total_students DESC;

-- Threshold = 5
SELECT c.course_title,
       COUNT(e.student_id) AS total_students
FROM Course c
LEFT JOIN Enrolment e ON c.course_id = e.course_id
GROUP BY c.course_id, c.course_title
HAVING COUNT(e.student_id) > 5
ORDER BY total_students DESC;

-- Threshold = 7
SELECT c.course_title,
       COUNT(e.student_id) AS total_students
FROM Course c
LEFT JOIN Enrolment e ON c.course_id = e.course_id
GROUP BY c.course_id, c.course_title
HAVING COUNT(e.student_id) > 7
ORDER BY total_students DESC;

-- Observation: as the threshold rises, fewer courses pass the
-- HAVING filter, so the result set shrinks (or becomes empty).


-- ------------------------------------------------------------
-- Task 3: Average number of courses taken per student,
--         including students with zero courses.
-- ------------------------------------------------------------
-- Step 1 (inner query): count courses per student. LEFT JOIN
-- keeps students with no enrolments, giving them a count of 0.
SELECT s.student_id,
       s.full_name,
       COUNT(e.course_id) AS course_count
FROM Student s
LEFT JOIN Enrolment e ON s.student_id = e.student_id
GROUP BY s.student_id, s.full_name;

-- Step 2: wrap step 1 as a derived table and average the counts.
-- An aggregate cannot be nested directly (AVG(COUNT(...)) is
-- illegal), which is why the subquery in FROM is needed.
-- With an INNER JOIN the zero-course students would vanish and
-- the average would come out too high.
SELECT ROUND(AVG(course_count), 2) AS avg_courses_per_student
FROM (
    SELECT s.student_id,
           COUNT(e.course_id) AS course_count
    FROM Student s
    LEFT JOIN Enrolment e ON s.student_id = e.student_id
    GROUP BY s.student_id
) AS per_student;


-- ------------------------------------------------------------
-- Task 4 (non-correlated subquery): students not enrolled
--         in any course.
-- ------------------------------------------------------------
-- The inner query does not refer to the outer query, so MySQL
-- runs it ONCE, builds the list of enrolled student ids, and
-- then keeps every student whose id is not in that list.
-- The result matches Week 7, Task 3 (LEFT JOIN ... WHERE
-- e.student_id IS NULL); only the technique differs.
-- Caution: NOT IN returns no rows at all if the list contains
-- a NULL. Enrolment.student_id is part of the primary key so it
-- cannot be NULL here, but the WHERE guard makes that explicit.
SELECT s.student_id,
       s.full_name
FROM Student s
WHERE s.student_id NOT IN (
    SELECT e.student_id
    FROM Enrolment e
    WHERE e.student_id IS NOT NULL
)
ORDER BY s.student_id;


-- ------------------------------------------------------------
-- Task 5 (correlated subquery): for each department, the
--         student with the highest number of enrolments.
--         Ties are allowed.
-- ------------------------------------------------------------
-- Both subqueries in WHERE refer to the outer row s, so they
-- run once PER outer student:
--   left side : how many courses does THIS student take?
--   right side: what is the highest course count among students
--               in the SAME department (s2.dept_id = s.dept_id)?
-- A student is kept only when the two numbers are equal.
-- Using "=" rather than LIMIT on the outer query means every
-- student who shares the top count is returned (ties).
-- The right side uses LEFT JOIN so that a department whose
-- students have no enrolments still yields 0 instead of NULL.
SELECT d.dept_name,
       s.full_name,
       (SELECT COUNT(*)
        FROM Enrolment e
        WHERE e.student_id = s.student_id) AS courses
FROM Student s
JOIN Department d ON s.dept_id = d.dept_id
WHERE (SELECT COUNT(*)
       FROM Enrolment e
       WHERE e.student_id = s.student_id)
      =
      (SELECT COUNT(e2.student_id)
       FROM Student s2
       LEFT JOIN Enrolment e2 ON e2.student_id = s2.student_id
       WHERE s2.dept_id = s.dept_id          -- correlation with outer query
       GROUP BY s2.student_id
       ORDER BY COUNT(e2.student_id) DESC
       LIMIT 1)
ORDER BY d.dept_name, s.full_name;
