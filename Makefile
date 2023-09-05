CRED=-U postgres -d students_info
SRC=-f src/part1.sql -f src/part2.sql -f src/part3.sql -f src/part4.sql
FILL=-f src/fill_tables.sql

all: create fill

create:
	psql -U postgres -c 'CREATE DATABASE students_info;'
	psql $(CRED) -a $(SRC)

fill:
	psql $(CRED) -a $(FILL)

drop:
	psql -U postgres -c 'DROP DATABASE IF EXISTS students_info;'

.PHONY: all create fill drop
