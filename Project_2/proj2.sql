-- Q1: ...

-- creating function to get XXsX semester name
create or replace function
	sem_name(semesters_id integer) returns text
as
$$
select substring(cast(year as char(50)), 3, 2) || lower(term) 
from semesters 
where id = semesters_id
$$ language sql;


-------- my views for Q1
create or replace view Q1_totalenrol(course, totalEnrols) -- Total students enrolled per course
as 
select distinct course, count(course) 
from course_enrolments ce
where ce.mark is not Null
group by course
order by course
;

create or replace view Q1_course_rank --- adding student rankings per course
as
select 
	course,
	subject,
	(select * from sem_name(semester)) as term,
	student,
	mark,
	grade,
	case   ---- case when .... else .... works like if else except we can use it outside plpgsql function
	when (mark is Null) then Null
	else (rank() over (partition by course order by case when mark is Null then 1 else 0 end, mark DESC))
	end as rank
	--- rank() creates ranking, partition by course means that we refresh ranking each course
	--- order by case when mark is ..... is to throw the Null value marks to the bottom, so it won't be ranked                           
from courses c
join course_enrolments ce
	on c.id = ce.course                                                                      
order by student
;

create or replace view Q1final --- Final view for Q1, just need to pick unswid via the Q1 function below
as
select 	distinct p.unswid,
		s.code,
		q1cr.term,
		q1cr.course,
		prog.code as program,
		s.name,
		mark,
		grade,
		case 
		when (q1cr.grade not in ('SY', 'PC', 'PS', 'CR', 'DN', 'HD', 'PT', 'A', 'B', 'C')) and (q1cr.mark is not Null) then '0'
		else '6'
		end as uoc,
		rank,
		q1t.totalenrols
from q1_course_rank q1cr
join subjects s
	on q1cr.subject = s.id
join people p
	on q1cr.student = p.id
join program_enrolments pe
	on q1cr.student = pe.student
join programs prog
	on pe.program = prog.id
join q1_totalenrol q1t
	on q1cr.course = q1t.course
order by q1cr.term;


--create type TranscriptRecord as (code text, term text, course integer, prog text, name text, mark integer, grade text, uoc integer, rank integer, totalEnrols integer);

create type TranscriptRecord as (code char(8), term char(4), course integer, prog char(4), name text, mark integer, grade char(2), uoc integer, rank integer, totalEnrols integer);

create or replace function Q1(integer) -- if it runs too long when using the check_q1() function,
									   --    please run it manually. select * from q1(2237675); it outputs after approx. 40 seconds
	returns setof TranscriptRecord
as $$
begin
return query
select 	code,
		cast(term as char(4)),
		course,
		program,
		cast(name as text),
		mark,
		cast(grade as char(2)),
		cast(uoc as integer),
		cast(rank as integer),
		cast(totalenrols as integer)
from q1final
where unswid = $1;
end;
$$ language plpgsql;


-- Q2: ...


-- creating a function to find the columns
create or replace function findcol(
    target text,
    tables name[] default '{}',
    schema name[] default '{public}'
)
returns table(sname text, tname text, cname text, nexamples integer)
as $$
begin
  for sname,tname,cname in
      select col.table_schema,col.table_name,col.column_name
      from information_schema.columns col
      join information_schema.tables t on
        (t.table_name=col.table_name and t.table_schema=col.table_schema)
        and col.table_schema=any(schema)
        and t.table_type='BASE TABLE'
  loop
    execute format(
       'select count(ctid) from %I.%I where  cast(%I as text) ~ %L  having count(ctid)>0',
       sname,
       tname,
       cname,
       target
    ) into nexamples;
    if nexamples is not null then
      return next;
    end if;
 end loop;
end;
$$ language plpgsql;



create type MatchingRecord as ("table" text, "column" text, nexamples integer);

create or replace function Q2("table" text, pattern text) 
	returns setof MatchingRecord
as $$
begin
return query
select 	tname,
		cname, 
		nexamples 
from (select * from findcol($2)) fc 
where  tname=$1;
end; 
$$ language plpgsql;


-- Q3: ...

---- creating function to see staff that has more than 1 roles
create type staff_occur as (unswid integer, name text, occuring integer);

create or replace function
	Q3_staff(orgunits_id integer) returns setof staff_occur
as
$$
begin
return query
select	distinct p.unswid,
	   	cast(p.name as text),
	   	cast(count (p.name) as integer)
from people p
join affiliations a
	on p.id = a.staff
join orgunits ou 
	on a.orgunit = ou.id
join staff_roles sr
	on a.role = sr.id
join orgunit_groups og
	on ou.id = og.member
where og.member in (select member from orgunit_groups where owner = $1) 
group by p.unswid, p.name
having count(p.name) > 1;
end;
$$ language plpgsql;
;

create type Q3_test as (unswid integer, name text, roles text, prog text, starting date, ending date);

create or replace function Q3final(integer) --- Final function of Q3 before being formatted as required
	returns setof Q3_test 
as $$

declare
r1 	Q3_test%rowtype;
r2	Q3_test%rowtype;

begin
	for r1 in 
		select	distinct p.unswid,
			   	cast(p.name as text),
			   	cast(sr.name as text) as position,
			   	cast(ou.name as text) as program_name,
			   	cast(a.starting as date),
			   	cast(a.ending as date)
		from people p
		join affiliations a
			on p.id = a.staff
		join orgunits ou 
			on a.orgunit = ou.id
		join staff_roles sr
			on a.role = sr.id
		join orgunit_groups og
			on ou.id = og.member
		join (select * from q3_staff($1)) q3s
			on p.unswid = q3s.unswid
		where og.member in (select member from orgunit_groups where owner = $1) 
		order by a.starting

	loop
		for r2 in
			select	distinct p.unswid,
				   	cast(p.name as text),
				   	cast(sr.name as text) as position,
				   	cast(ou.name as text) as program_name,
				   	cast(a.starting as date),
				   	cast(a.ending as date)
			from people p
			join affiliations a
				on p.id = a.staff
			join orgunits ou 
				on a.orgunit = ou.id
			join staff_roles sr
				on a.role = sr.id
			join orgunit_groups og
				on ou.id = og.member
			join (select * from q3_staff($1)) q3s
				on p.unswid = q3s.unswid
			where og.member in (select member from orgunit_groups where owner = $1) and p.unswid = r1.unswid
			order by a.starting

			loop
				if r2.starting >= r1.ending or r2.ending <= r1.starting then
				return next r2;
				end if;
			end loop;
	end loop;	
end;

$$ language plpgsql;


create type EmploymentRecord as (unswid integer, name text, roles text);

create or replace function Q3(integer) ---- make the Q3final function pretty, basically
    returns setof EmploymentRecord 
as $$
declare
    r EmploymentRecord; 
    curr q3_test;
    prev q3_test;
    roles text := '';

begin
for curr in 
	select distinct * from q3final($1) as q3f 
	order by q3f.name desc, q3f.starting, q3f.ending

loop
    if prev is null then 
        prev := curr;
    end if;

    if prev.unswid = curr.unswid then 
        r.unswid := curr.unswid;
        r.name := curr.name;
        if curr.ending is not null then 
            roles := roles||curr.roles||', '||curr.prog||' ('||curr.starting::text||'..'||curr.ending::text||')'||chr(10);
            r.roles = roles;
        end if;
        if curr.ending is null then
            roles := roles||curr.roles||', '||curr.prog||' ('||curr.starting::text||'..'||')'||chr(10);
            r.roles = roles;
        end if;
    end if;

    if prev.unswid != curr.unswid then 
        r.roles = roles;
        roles := '';
        return next r;
        r.unswid := curr.unswid;
        r.name := curr.name;
        roles := roles||curr.roles||', '||curr.prog||' ('||curr.starting::text||'..'||curr.ending::text||')'||chr(10);
    end if;
    prev := curr;
end loop;
r.roles = roles;
return next r;
end;
$$ language plpgsql;
