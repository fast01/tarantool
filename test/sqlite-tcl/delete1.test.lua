#!./tcltestrunner.lua

set testdir [file dirname $argv0]
source $testdir/tester.tcl

execsql { DROP TABLE IF EXISTS test1 }
execsql { CREATE TABLE test1 (id INT, PRIMARY KEY (id)) }
execsql { INSERT INTO test1 values (1)}
execsql { INSERT INTO test1 values (2)}
execsql { INSERT INTO test1 values (3)}

execsql { DROP TABLE IF EXISTS test2 }
execsql { CREATE TABLE test2 (id INT, name TEXT, surname TEXT, bar INT, foo INT, qwerty INT, PRIMARY KEY (id)) }
execsql { CREATE INDEX test2_secondary ON test2 (id, name) }
execsql { CREATE INDEX test2_third ON test2 (surname, bar) }
execsql { CREATE INDEX test2_fourth ON test2 (qwerty) }

execsql { INSERT INTO test2 values (1, "Vlad", "Shpilevoy", 100, 200, 300) }
execsql { INSERT INTO test2 values (2, "Ivan", "Petrov", 200, 300, 400) }
execsql { INSERT INTO test2 values (3, "Maria", "Popova", 300, 400, 500) }
execsql { INSERT INTO test2 values (4, "Albert", "Sukaev", 400, 500, 600) }
execsql { INSERT INTO test2 values (5, "Ksenia", "Ivanova", 100, 200, 700) }
execsql { INSERT INTO test2 values (6, "Brian", "Hankok", 200, 300, 800) }

execsql { DROP TABLE IF EXISTS test3 }
execsql { CREATE TABLE test3 (id INT, name TEXT, surname TEXT, bar INT, foo INT, qwerty INT, PRIMARY KEY (id)) }
execsql { CREATE INDEX test3_secondary ON test3 (id, name) }
execsql { CREATE INDEX test3_third ON test3 (surname, bar) }
execsql { CREATE INDEX test3_fourth ON test3 (qwerty) }

execsql { INSERT INTO test3 values (1, "Vlad", "Shpilevoy", 100, 200, 300) }
execsql { INSERT INTO test3 values (2, "Ivan", "Petrov", 200, 300, 400) }
execsql { INSERT INTO test3 values (3, "Maria", "Popova", 300, 400, 500) }
execsql { INSERT INTO test3 values (4, "Albert", "Sukaev", 400, 500, 600) }
execsql { INSERT INTO test3 values (5, "Ksenia", "Ivanova", 100, 200, 700) }
execsql { INSERT INTO test3 values (6, "Brian", "Hankok", 200, 300, 800) }

execsql { DROP TABLE IF EXISTS test4 }
execsql { CREATE TABLE test4 (id INT, name TEXT, surname TEXT, bar INT, foo INT, qwerty INT, PRIMARY KEY (id)) }
execsql { CREATE INDEX test4_secondary ON test4 (id, name) }
execsql { CREATE INDEX test4_third ON test4 (surname, bar) }
execsql { CREATE INDEX test4_fourth ON test4 (qwerty) }

execsql { INSERT INTO test4 values (1, "Vlad", "Shpilevoy", 100, 200, 300) }
execsql { INSERT INTO test4 values (2, "Ivan", "Petrov", 200, 300, 400) }
execsql { INSERT INTO test4 values (3, "Maria", "Popova", 300, 400, 500) }
execsql { INSERT INTO test4 values (4, "Albert", "Sukaev", 400, 500, 600) }
execsql { INSERT INTO test4 values (5, "Ksenia", "Ivanova", 100, 200, 700) }
execsql { INSERT INTO test4 values (6, "Brian", "Hankok", 200, 300, 800) }

execsql { DROP TABLE IF EXISTS test5 }
execsql { CREATE TABLE test5 (id INT, name TEXT, surname TEXT, bar INT, foo INT, qwerty INT, PRIMARY KEY (id)) }
execsql { CREATE INDEX test5_secondary ON test5 (id, name) }
execsql { CREATE INDEX test5_third ON test5 (surname, bar) }
execsql { CREATE INDEX test5_fourth ON test5 (qwerty) }

execsql { INSERT INTO test5 values (1, "Vlad", "Shpilevoy", 100, 200, 300) }
execsql { INSERT INTO test5 values (2, "Ivan", "Petrov", 200, 300, 400) }
execsql { INSERT INTO test5 values (3, "Maria", "Popova", 300, 400, 500) }
execsql { INSERT INTO test5 values (4, "Albert", "Sukaev", 400, 500, 600) }
execsql { INSERT INTO test5 values (5, "Ksenia", "Ivanova", 100, 200, 700) }
execsql { INSERT INTO test5 values (6, "Brian", "Hankok", 200, 300, 800) }

do_test delete1-1.0 {
  execsql {delete from test1 where id = 2}
  execsql {select * from test1}
} {1 3}

do_test delete1-2.0 {
  execsql {delete from test2 where name = "Ivan"}
  execsql {select name from test2}
} {Vlad Maria Albert Ksenia Brian}

do_test delete1-2.1 {
  execsql {delete from test2 where id > 2}
  execsql {select name from test2}
} {Vlad}

do_test delete1-3.0 {
  execsql {delete from test3 where id >= 2 and id <= 5}
  execsql {select name from test3}
} {Vlad Brian}

do_test delete1-3.1 {
  execsql {delete from test3 where surname = "Hankok"}
  execsql {select id from test3}
} {1}

do_test delete1-4.0 {
  execsql {delete from test4 where foo >= 300}
  execsql {select foo from test4}
} {200 200}

do_test delete1-5.0 {
  execsql {delete from test5 where (foo > 300 or surname = "Petrov")}
  execsql {select id from test5}
} {1 5 6}


finish_test