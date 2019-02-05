/*
Script Name: redaction_demo
Author: Matt DeMarco (matt@memsql.com)
Created: 01.31.2019
Updated: 01.31.2019

Purpose: control exposure of SS numbers via RBAC RLS 

*/


/* create database */
create database if not exists demo;
use demo;


/* create base table holding data */
drop view if exists data_table;
drop table if exists base_table;
create table if not exists base_table
	(
		customer_id	bigint,
		fname	longtext,
		lname	longtext,
		dob	datetime,
		ss_number	longtext,
		access_control	varbinary(1000) default ',' not null,
		fulltext(fname,lname),
		shard key (customer_id),
		key (customer_id) using clustered columnstore
	);


/* access control to the view */
create view data_table as
	select
	customer_id,
	fname,
	lname,
	dob,
	case
		when CURRENT_SECURITY_GROUPS() = 'operator' then concat('xxx-xx-',right(ss_number,4))
		when CURRENT_SECURITY_GROUPS() = 'manager' then concat_ws('-',substring(ss_number,1,3),substring(ss_number,4,2),substring(ss_number,6,4))
		/* when 2 = 2 then concat(‘xxx-xx-‘,right(ssn,4)) */
		else 'Access Denied'
	end ssnumber
from 
base_table
;



/* create roles and groups */
drop role 'manager_role';
drop role 'operator_role';

create role 'manager_role';
create role 'operator_role';

grant select on demo.data_table to role 'manager_role';
grant select on demo.data_table to role 'operator_role';

revoke select,update,delete on demo.base_table from 'root';

drop group 'manager';
drop group 'operator';

create group 'manager';
create group 'operator';

grant role 'manager_role' to 'manager';
grant role 'operator_role' to 'operator';

/* create users and grant groups */
drop user 'alice';
create user 'alice';
grant group 'manager' to 'alice';

drop user 'bob';
create user 'bob';
grant group 'operator' to 'bob';


/* insert example data */
insert into base_table 
	(customer_id,fname,lname,dob,ss_number)
values
	(1,'matt','demarco','2000-01-31','123456789'),
	(2,'dale','deloy','2000-10-01','198121234');


\! echo "This is BOB, the operator.  He can only see the last 4 of the social security number"
\! sleep 3
\! memsql demo -ubob -e 'select * from data_table' --table 

\! echo "This is ALICE, the manager.  She can the ENTIRE social security number"
\! sleep 3
\! memsql demo -ualice -e 'select * from data_table' --table


/* Full Text Search goodness

select * from data_table where match(fname) against ('ma*') and match(lname) against ('de*');

/* 





