#!./tcltestrunner.lua

# 2005 November 2
#
# The author disclaims copyright to this source code.  In place of
# a legal notice, here is a blessing:
#
#    May you do good and not evil.
#    May you find forgiveness for yourself and forgive others.
#    May you share freely, never taking more than you give.
#
#***********************************************************************
# This file implements regression tests for SQLite library.  The
# focus of this file is testing CHECK constraints
#
# $Id: check.test,v 1.13 2009/06/05 17:09:12 drh Exp $

set testdir [file dirname $argv0]
source $testdir/tester.tcl
set ::testprefix check

# Only run these tests if the build includes support for CHECK constraints
ifcapable !check {
  finish_test
  return
}

# do_test check-1.1 {
#   execsql {
#     CREATE TABLE t1(
#       x INTEGER CHECK( x<5 ),
#       y REAL CHECK( y>x )
#     );
#   }
# } {}
# do_test check-1.2 {
#   execsql {
#     INSERT INTO t1 VALUES(3,4);
#     SELECT * FROM t1;
#   }  
# } {3 4.0}
# do_test check-1.3 {
#   catchsql {
#     INSERT INTO t1 VALUES(6,7);
#   }
# } {1 {CHECK constraint failed: t1}}
# do_test check-1.4 {
#   execsql {
#     SELECT * FROM t1;
#   }  
# } {3 4.0}
# do_test check-1.5 {
#   catchsql {
#     INSERT INTO t1 VALUES(4,3);
#   }
# } {1 {CHECK constraint failed: t1}}
# do_test check-1.6 {
#   execsql {
#     SELECT * FROM t1;
#   }  
# } {3 4.0}
# do_test check-1.7 {
#   catchsql {
#     INSERT INTO t1 VALUES(NULL,6);
#   }
# } {0 {}}
# do_test check-1.8 {
#   execsql {
#     SELECT * FROM t1;
#   }  
# } {3 4.0 {} 6.0}
# do_test check-1.9 {
#   catchsql {
#     INSERT INTO t1 VALUES(2,NULL);
#   }
# } {0 {}}
# do_test check-1.10 {
#   execsql {
#     SELECT * FROM t1;
#   }  
# } {3 4.0 {} 6.0 2 {}}
# do_test check-1.11 {
#   execsql {
#     DELETE FROM t1 WHERE x IS NULL OR x!=3;
#     UPDATE t1 SET x=2 WHERE x==3;
#     SELECT * FROM t1;
#   }
# } {2 4.0}
# do_test check-1.12 {
#   catchsql {
#     UPDATE t1 SET x=7 WHERE x==2
#   }
# } {1 {CHECK constraint failed: t1}}
# do_test check-1.13 {
#   execsql {
#     SELECT * FROM t1;
#   }
# } {2 4.0}
# do_test check-1.14 {
#   catchsql {
#     UPDATE t1 SET x=5 WHERE x==2
#   }
# } {1 {CHECK constraint failed: t1}}
# do_test check-1.15 {
#   execsql {
#     SELECT * FROM t1;
#   }
# } {2 4.0}
# do_test check-1.16 {
#   catchsql {
#     UPDATE t1 SET x=4, y=11 WHERE x==2
#   }
# } {0 {}}
# do_test check-1.17 {
#   execsql {
#     SELECT * FROM t1;
#   }
# } {4 11.0}

# do_test check-2.1 {
#   execsql {
#     CREATE TABLE t2(
#       x INTEGER CONSTRAINT one CHECK( typeof(coalesce(x,0))=="integer" ),
#       y REAL CONSTRAINT two CHECK( typeof(coalesce(y,0.1))=='real' ),
#       z TEXT CONSTRAINT three CHECK( typeof(coalesce(z,''))=='text' )
#     );
#   }
# } {}
# do_test check-2.2 {
#   execsql {
#     INSERT INTO t2 VALUES(1,2.2,'three');
#     SELECT * FROM t2;
#   }
# } {1 2.2 three}
# db close
# sqlite3 db test.db
# do_test check-2.3 {
#   execsql {
#     INSERT INTO t2 VALUES(NULL, NULL, NULL);
#     SELECT * FROM t2;
#   }
# } {1 2.2 three {} {} {}}
# do_test check-2.4 {
#   catchsql {
#     INSERT INTO t2 VALUES(1.1, NULL, NULL);
#   }
# } {1 {CHECK constraint failed: one}}
# do_test check-2.5 {
#   catchsql {
#     INSERT INTO t2 VALUES(NULL, 5, NULL);
#   }
# } {1 {CHECK constraint failed: two}}
# do_test check-2.6 {
#   catchsql {
#     INSERT INTO t2 VALUES(NULL, NULL, 3.14159);
#   }
# } {1 {CHECK constraint failed: three}}

# # Undocumented behavior:  The CONSTRAINT name clause can follow a constraint.
# # Such a clause is ignored.  But the parser must accept it for backwards
# # compatibility.
# #
# do_test check-2.10 {
#   execsql {
#     CREATE TABLE t2b(
#       x INTEGER CHECK( typeof(coalesce(x,0))=='integer' ) CONSTRAINT one,
#       y TEXT PRIMARY KEY constraint two,
#       z INTEGER,
#       UNIQUE(x,z) constraint three
#     );
#   }
# } {}
# do_test check-2.11 {
#   catchsql {
#     INSERT INTO t2b VALUES('xyzzy','hi',5);
#   }
# } {1 {CHECK constraint failed: t2b}}
# do_test check-2.12 {
#   execsql {
#     CREATE TABLE t2c(
#       x INTEGER CONSTRAINT x_one CONSTRAINT x_two
#           CHECK( typeof(coalesce(x,0))=='integer' )
#           CONSTRAINT x_two CONSTRAINT x_three,
#       y INTEGER, z INTEGER,
#       CONSTRAINT u_one UNIQUE(x,y,z) CONSTRAINT u_two
#     );
#   }
# } {}
# do_test check-2.13 {
#   catchsql {
#     INSERT INTO t2c VALUES('xyzzy',7,8);
#   }
# } {1 {CHECK constraint failed: x_two}}
# do_test check-2.cleanup {
#   execsql {
#     DROP TABLE IF EXISTS t2b;
#     DROP TABLE IF EXISTS t2c;
#   }
# } {}

# ifcapable subquery {
#   do_test check-3.1 {
#     catchsql {
#       CREATE TABLE t3(
#         x, y, z,
#         CHECK( x<(SELECT min(x) FROM t1) )
#       );
#     }
#   } {1 {subqueries prohibited in CHECK constraints}}
# }

# do_test check-3.2 {
#   execsql {
#     SELECT name FROM sqlite_master ORDER BY name
#   }
# } {t1 t2}
# do_test check-3.3 {
#   catchsql {
#     CREATE TABLE t3(
#       x, y, z,
#       CHECK( q<x )
#     );
#   }
# } {1 {no such column: q}}
# do_test check-3.4 {
#   execsql {
#     SELECT name FROM sqlite_master ORDER BY name
#   }
# } {t1 t2}
# do_test check-3.5 {
#   catchsql {
#     CREATE TABLE t3(
#       x, y, z,
#       CHECK( t2.x<x )
#     );
#   }
# } {1 {no such column: t2.x}}
# do_test check-3.6 {
#   execsql {
#     SELECT name FROM sqlite_master ORDER BY name
#   }
# } {t1 t2}
# do_test check-3.7 {
#   catchsql {
#     CREATE TABLE t3(
#       x, y, z,
#       CHECK( t3.x<25 )
#     );
#   }
# } {0 {}}
# do_test check-3.8 {
#   execsql {
#     INSERT INTO t3 VALUES(1,2,3);
#     SELECT * FROM t3;
#   }
# } {1 2 3}
# do_test check-3.9 {
#   catchsql {
#     INSERT INTO t3 VALUES(111,222,333);
#   }
# } {1 {CHECK constraint failed: t3}}

# do_test check-4.1 {
#   execsql {
#     CREATE TABLE t4(x, y,
#       CHECK (
#            x+y==11
#         OR x*y==12
#         OR x/y BETWEEN 5 AND 8
#         OR -x==y+10
#       )
#     );
#   }
# } {}
# do_test check-4.2 {
#   execsql {
#     INSERT INTO t4 VALUES(1,10);
#     SELECT * FROM t4
#   }
# } {1 10}
# do_test check-4.3 {
#   execsql {
#     UPDATE t4 SET x=4, y=3;
#     SELECT * FROM t4
#   }
# } {4 3}
# do_test check-4.4 {
#   execsql {
#     UPDATE t4 SET x=12, y=2;
#     SELECT * FROM t4
#   }
# } {12 2}
# do_test check-4.5 {
#   execsql {
#     UPDATE t4 SET x=12, y=-22;
#     SELECT * FROM t4
#   }
# } {12 -22}
# do_test check-4.6 {
#   catchsql {
#     UPDATE t4 SET x=0, y=1;
#   }
# } {1 {CHECK constraint failed: t4}}
# do_test check-4.7 {
#   execsql {
#     SELECT * FROM t4;
#   }
# } {12 -22}
# do_test check-4.8 {
#   execsql {
#     PRAGMA ignore_check_constraints=ON;
#     UPDATE t4 SET x=0, y=1;
#     SELECT * FROM t4;
#   }
# } {0 1}
# do_test check-4.9 {
#   catchsql {
#     PRAGMA ignore_check_constraints=OFF;
#     UPDATE t4 SET x=0, y=2;
#   }
# } {1 {CHECK constraint failed: t4}}
# ifcapable vacuum {
#   do_test check_4.10 {
#     catchsql {
#       VACUUM
#     }
#   } {0 {}}
# }

# do_test check-5.1 {
#   catchsql {
#     CREATE TABLE t5(x, y,
#       CHECK( x*y<:abc )
#     );
#   }
# } {1 {parameters prohibited in CHECK constraints}}
# do_test check-5.2 {
#   catchsql {
#     CREATE TABLE t5(x, y,
#       CHECK( x*y<? )
#     );
#   }
# } {1 {parameters prohibited in CHECK constraints}}

# ifcapable conflict {

# do_test check-6.1 {
#   execsql {SELECT * FROM t1}
# } {4 11.0}
# do_test check-6.2 {
#   execsql {
#     UPDATE OR IGNORE t1 SET x=5;
#     SELECT * FROM t1;
#   }
# } {4 11.0}
# do_test check-6.3 {
#   execsql {
#     INSERT OR IGNORE INTO t1 VALUES(5,4.0);
#     SELECT * FROM t1;
#   }
# } {4 11.0}
# do_test check-6.4 {
#   execsql {
#     INSERT OR IGNORE INTO t1 VALUES(2,20.0);
#     SELECT * FROM t1;
#   }
# } {4 11.0 2 20.0}
# do_test check-6.5 {
#   catchsql {
#     UPDATE OR FAIL t1 SET x=7-x, y=y+1;
#   }
# } {1 {CHECK constraint failed: t1}}
# do_test check-6.6 {
#   execsql {
#     SELECT * FROM t1;
#   }
# } {3 12.0 2 20.0}
# do_test check-6.7 {
#   catchsql {
#     BEGIN;
#     INSERT INTO t1 VALUES(1,30.0);
#     INSERT OR ROLLBACK INTO t1 VALUES(8,40.0);
#   }
# } {1 {CHECK constraint failed: t1}}
# do_test check-6.8 {
#   catchsql {
#     COMMIT;
#   }
# } {1 {cannot commit - no transaction is active}}
# do_test check-6.9 {
#   execsql {
#     SELECT * FROM t1
#   }
# } {3 12.0 2 20.0}

# do_test check-6.11 {
#   execsql {SELECT * FROM t1}
# } {3 12.0 2 20.0}
# do_test check-6.12 {
#   catchsql {
#     REPLACE INTO t1 VALUES(6,7);
#   }
# } {1 {CHECK constraint failed: t1}}
# do_test check-6.13 {
#   execsql {SELECT * FROM t1}
# } {3 12.0 2 20.0}
# do_test check-6.14 {
#   catchsql {
#     INSERT OR IGNORE INTO t1 VALUES(6,7);
#   }
# } {0 {}}
# do_test check-6.15 {
#   execsql {SELECT * FROM t1}
# } {3 12.0 2 20.0}


# }

# #--------------------------------------------------------------------------
# # If a connection opens a database that contains a CHECK constraint that
# # uses an unknown UDF, the schema should not be considered malformed.
# # Attempting to modify the table should fail (since the CHECK constraint
# # cannot be tested).
# #
# reset_db
# proc myfunc {x} {expr $x < 10}
# db func myfunc myfunc

# do_execsql_test  7.1 { CREATE TABLE t6(a CHECK (myfunc(a))) }
# do_execsql_test  7.2 { INSERT INTO t6 VALUES(9)  }
# do_catchsql_test 7.3 { INSERT INTO t6 VALUES(11) } \
#           {1 {CHECK constraint failed: t6}}

# do_test 7.4 {
#   sqlite3 db2 test.db
#   execsql { SELECT * FROM t6 } db2 
# } {9}

# do_test 7.5 {
#   catchsql { INSERT INTO t6 VALUES(8) } db2
# } {1 {unknown function: myfunc()}}

# do_test 7.6 {
#   catchsql { CREATE TABLE t7(a CHECK (myfunc(a))) } db2
# } {1 {no such function: myfunc}}

# do_test 7.7 {
#   db2 func myfunc myfunc
#   execsql { INSERT INTO t6 VALUES(8) } db2
# } {}

# do_test 7.8 {
#   db2 func myfunc myfunc
#   catchsql { INSERT INTO t6 VALUES(12) } db2
# } {1 {CHECK constraint failed: t6}}

# # 2013-08-02:  Silently ignore database name qualifiers in CHECK constraints.
# #
# do_execsql_test 8.1 {
#   CREATE TABLE t810(a, CHECK( main.t810.a>0 ));
#   CREATE TABLE t811(b, CHECK( xyzzy.t811.b BETWEEN 5 AND 10 ));
# } {}

finish_test
