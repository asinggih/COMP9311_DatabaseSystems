
-- --------------------------------------------------------------------------

-- 			Written by Aditya Singgih with blood and tears
-- 					for COMP9311 16s1 Project 1

-- --------------------------------------------------------------------------


-- Q1: students who have taken more than 55 courses
create or replace view Q1(unswid, name)
as
select unswid, name from people p,
(select student s, count(*) c from course_enrolments
group by student) as x
where x.s = p.id and x.c > 55 order by unswid
;


-- Q2: get details of the current Heads of Schools
create or replace view Q2(name, school, starting)
as
select  p.name,
	ou.longname, 
	af.starting
from people p
inner join affiliations af
	on p.id=af.staff
inner join orgunits ou
	on af.orgunit=ou.id
inner join orgunit_types ot
	on ou.utype=ot.id
inner join staff_roles sr
	on af.role=sr.id
where sr.name = 'Head of School' and af.ending is Null and af.isprimary = 't' and ot.name = 'School'
;



-- Q3 UOC/ETFS ratio
create or replace view Q3(ratio,nsubjects)
as
select distinct (uoc/eftsload)::numeric(4,1) as ratio,
	count(*) as nsubjects
from subjects
where eftsload != Null or eftsload != 0
group by ratio
;



------ My view for Q4
create or replace view Q4_staff(staff, occurence)
as
select staff, count(*) as occurence, role 
from course_staff 
group by staff, role 
order by count(*) desc
;

-- Q4: convenor for the most courses
create or replace view Q4(name, ncourses)
as
select distinct p.name,
	qs.occurence 
from people p
join staff s
	on p.id = s.id
join course_staff cs
	on s.id = cs.staff
join staff_roles sr
	on cs.role = sr.id
join Q4_staff qs
	on qs.staff = s.id
where sr.name = 'Course Convenor' and qs.occurence = (select max(occurence) from Q4_staff)
;



-- Q5: program enrolments from 05S2   
create or replace view Q5a(id)
as
select p.unswid 
from people p
join program_enrolments pe
	on p.id=pe.student  -- pair with p.ID not p.UNSWID!!
join programs pro
	on pe.program=pro.id
join semesters s
	on pe.semester=s.id
where s.year = '2005' and s.term = 'S2'and pro.code = '3978'
;

create or replace view Q5b(id)
as
select p.unswid 
from people p
join program_enrolments pe
	on p.id=pe.student  -- pair with p.ID not p.UNSWID!!
join semesters s
	on pe.semester=s.id
join stream_enrolments se
	on pe.id=se.partof
join streams 
	on se.stream = streams.id
where s.year = '2005' and s.term = 'S2'and streams.code = 'SENGA1'
;

create or replace view Q5c(id)
as
select p.unswid 
from people p
join program_enrolments pe
	on p.id=pe.student  -- pair with p.ID not p.UNSWID!!
join semesters s
	on pe.semester=s.id
join programs pro
	on pe.program=pro.id
join orgunits org
	on pro.offeredby=org.id
where s.year = '2005' and s.term = 'S2'and org.longname = 'School of Computer Science and Engineering'
;



-- Q6: semester names
-- Testing case in check.sql: SELECT * FROM Q6(123);
create or replace function
	Q6(x integer) returns text
as
$$
select substring(cast(year as char(50)), 3, 2) || lower(term) 
from semesters 
where id = x
$$ language sql;




------ My views for Q7
create or replace view Q7_totalEnrol(semester, totalEnrol)
as
select semester, count(*) as totalEnrol
from program_enrolments pe
join semesters s
	on pe.semester = s.id
where s.term not like 'X%' and year >= 2005
group by pe.semester
order by pe.semester
;


create or replace view Q7_intl(semester, intl)
as
select pe.semester,
	count(pe.semester) as intl
from program_enrolments pe
join semesters s
	on pe.semester = s.id
join students stu
	on pe.student = stu.id
where stu.stype != 'local' and s.term not like 'X%' and s.year >= 2005 
group by pe.semester
order by pe.semester
;


-- Q7: percentage of international students, S1 and S2, starting from 2005
create or replace view Q7(semester, percent)
as
select (select * from Q6(q7i.semester)) as semester,
	((q7i.intl*1.0)/q7t.totalenrol)::numeric(4, 2) as ratio  -- need to time q7i.intl by 1.0 to convert it into float
from Q7_intl q7i
join Q7_totalenrol q7t
	on q7i.semester = q7t.semester

;


------ My views for Q8
create or replace view Q8_nofferings(subject, nofferings)  ---- subjects offered more than 25 times
as
select subject, count(*) as nofferings
from courses
group by subject
having count(*) > 25;

create or replace view Q8_nostaff(subject, code, name, nofferings)		---- subjects offered more than 25 times with no staff
as
select distinct s.id,
	s.code,
	s.name,
	q8no.nofferings
from courses c
left join course_staff cs
	on c.id = cs.course
inner join q8_nofferings q8no
	on c.subject = q8no.subject
inner join subjects s
	on c.subject = s.id
where cs.course is null;

create or replace view Q8_wstaff(subject, code, name, nofferings)		---- subjects offered more than 25 times with staff
as
select distinct s.id,
	s.code,
	s.name,
	q8no.nofferings
from courses c
inner join course_staff cs
	on c.id = cs.course
inner join q8_nofferings q8no
	on c.subject = q8no.subject
inner join subjects s
	on c.subject = s.id
where cs.course is not Null;


-- Q8: subjects with > 25 course offerings and no staff recorded
create or replace view Q8(subject, nOfferings)
as
select q8ns.code||' ' ||q8ns.name as subject, q8no.nofferings
from q8_nostaff q8ns
join q8_nofferings q8no
	on q8ns.subject = q8no.subject
left join q8_wstaff q8w
	on q8ns.subject = q8w.subject
where q8w is Null;
;



-- Q9: find a good research assistant
create or replace view Q9(unswid, name)
as
select p.unswid,
	p.name
from people p
join course_enrolments ce
	on p.id=ce.student  -- pair with p.ID not p.UNSWID!!
join courses co
	on ce.course=co.id
join subjects s
	on co.subject=s.id
where ce.mark is not Null and s.code like 'COMP34%'
group by p.unswid, p.name
having count(p.name) >= (select count(*) from subjects where code like 'COMP34%') 
;



------ My views for Q10
create or replace view q10o(subject, year) -- popular 'COMP9%' subjects per year
as
select c.subject,
	sem.year,
	count(*) as occurence 
from courses c
join semesters sem
	on c.semester = sem.id
join subjects s
	on c.subject = s.id
where sem.term not like 'X%' and sem.year >= 2003 and sem.year <= 2013 and s.code like 'COMP9%'
group by c.subject, sem.year
having count(*) = 2
order by sem.year
;

create or replace view q10f(id) --- students who have failed popular COMP9% subjects
as
select distinct p.id
from people p
join course_enrolments ce
	on p.id = ce.student
join courses c
	on ce.course = c.id
join q10o
	on c.subject = q10o.subject
where ce.mark < 46 or ce.grade in ('FL', 'GP') 
	and c.subject in (select q10o.subject from q10o)
;

create or replace view q10g(id) --- students who have good grades on all popular subjects
as
select ce.student 
from course_enrolments ce
join courses c
	on ce.course = c.id
join subjects s
	on c.subject = s.id
join q10o
	on s.id = q10o.subject
where ce.grade in ('HD', 'DN') and s.id in (select subject from q10o)
;


-- Q10: find all students who had been enrolled in all popular subjects
create or replace view Q10(unswid, name)
as
select distinct p.unswid,
				p.name
from people p
left join q10f
	on p.id = q10f.id
join course_enrolments ce
	on p.id = ce.student
join courses c
	on ce.course = c.id
join subjects s
	on c.subject = s.id
left join q10o
	on s.id = q10o.subject
join q10g
	on p.id = q10g.id
where q10f.id is null and ce.grade in ('HD', 'DN')
	and s.id in (select q10o.subject from q10o)
order by p.name
;



