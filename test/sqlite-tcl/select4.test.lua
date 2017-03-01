#!./tcltestrunner.lua

# 2001 September 15
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
# focus of this file is testing UNION, INTERSECT and EXCEPT operators
# in SELECT statements.
#
# $Id: select4.test,v 1.30 2009/04/16 00:24:24 drh Exp $

set testdir [file dirname $argv0]
source $testdir/tester.tcl

# Most tests in this file depend on compound-select. But there are a couple
# right at the end that test DISTINCT, so we cannot omit the entire file.
#
ifcapable compound {

# Build some test data
#
execsql {
  DROP TABLE IF EXISTS t1;
  CREATE TABLE t1(n int primary key, log int);
  BEGIN;
}
for {set i 1} {$i<32} {incr i} {
  for {set j 0} {(1<<$j)<$i} {incr j} {}
  execsql "INSERT INTO t1 VALUES($i,$j)"
}
execsql {
  COMMIT;
}

do_test select4-1.0 {
  execsql {SELECT DISTINCT log FROM t1 ORDER BY log}
} {0 1 2 3 4 5}

# Union All operator
#
do_test select4-1.1a {
  lsort [execsql {SELECT DISTINCT log FROM t1}]
} {0 1 2 3 4 5}
do_test select4-1.1b {
  lsort [execsql {SELECT n FROM t1 WHERE log=3}]
} {5 6 7 8}
do_test select4-1.1c {
  execsql {
    SELECT DISTINCT log FROM t1
    UNION ALL
    SELECT n FROM t1 WHERE log=3
    ORDER BY log;
  }
} {0 1 2 3 4 5 5 6 7 8}

# do_test select4-1.1d {
#   execsql {
#     DROP TABLE IF EXISTS t2;
#     CREATE TABLE t2 AS
#       SELECT DISTINCT log FROM t1
#       UNION ALL
#       SELECT n FROM t1 WHERE log=3
#       ORDER BY log;
#     SELECT * FROM t2;
#   }
# } {0 1 2 3 4 5 5 6 7 8}
# execsql {DROP TABLE t2}
# do_test select4-1.1e {
#   execsql {
#     CREATE TABLE t2 AS
#       SELECT DISTINCT log FROM t1
#       UNION ALL
#       SELECT n FROM t1 WHERE log=3
#       ORDER BY log DESC;
#     SELECT * FROM t2;
#   }
# } {8 7 6 5 5 4 3 2 1 0}
# execsql {DROP TABLE t2}
do_test select4-1.1f {
  execsql {
    SELECT DISTINCT log FROM t1
    UNION ALL
    SELECT n FROM t1 WHERE log=2
  }
} {0 1 2 3 4 5 3 4}

# do_test select4-1.1g {
#   execsql {
#     CREATE TABLE t2 AS 
#       SELECT DISTINCT log FROM t1
#       UNION ALL
#       SELECT n FROM t1 WHERE log=2;
#     SELECT * FROM t2;
#   }
# } {0 1 2 3 4 5 3 4}
# execsql {DROP TABLE t2}
ifcapable subquery {
  do_test select4-1.2 {
    execsql {
      SELECT log FROM t1 WHERE n IN 
        (SELECT DISTINCT log FROM t1 UNION ALL
         SELECT n FROM t1 WHERE log=3)
      ORDER BY log;
    }
  } {0 1 2 2 3 3 3 3}
}

# EVIDENCE-OF: R-02644-22131 In a compound SELECT statement, only the
# last or right-most simple SELECT may have an ORDER BY clause.
#
do_test select4-1.3 {
  set v [catch {execsql {
    SELECT DISTINCT log FROM t1 ORDER BY log
    UNION ALL
    SELECT n FROM t1 WHERE log=3
    ORDER BY log;
  }} msg]
  lappend v $msg
} {1 {ORDER BY clause should come after UNION ALL not before}}
do_catchsql_test select4-1.4 {
  SELECT (VALUES(0) INTERSECT SELECT(0) UNION SELECT(0) ORDER BY 1 UNION
          SELECT 0 UNION SELECT 0 ORDER BY 1);
} {1 {ORDER BY clause should come after UNION not before}}

# Union operator
#
do_test select4-2.1 {
  execsql {
    SELECT DISTINCT log FROM t1
    UNION
    SELECT n FROM t1 WHERE log=3
    ORDER BY log;
  }
} {0 1 2 3 4 5 6 7 8}
ifcapable subquery {
  do_test select4-2.2 {
    execsql {
      SELECT log FROM t1 WHERE n IN 
        (SELECT DISTINCT log FROM t1 UNION
         SELECT n FROM t1 WHERE log=3)
      ORDER BY log;
    }
  } {0 1 2 2 3 3 3 3}
}
do_test select4-2.3 {
  set v [catch {execsql {
    SELECT DISTINCT log FROM t1 ORDER BY log
    UNION
    SELECT n FROM t1 WHERE log=3
    ORDER BY log;
  }} msg]
  lappend v $msg
} {1 {ORDER BY clause should come after UNION not before}}
do_test select4-2.4 {
  set v [catch {execsql {
    SELECT 0 ORDER BY (SELECT 0) UNION SELECT 0;
  }} msg]
  lappend v $msg
} {1 {ORDER BY clause should come after UNION not before}}
do_execsql_test select4-2.5 {
  SELECT 123 AS x ORDER BY (SELECT x ORDER BY 1);
} {123}

# Except operator
#
do_test select4-3.1.1 {
  execsql {
    SELECT DISTINCT log FROM t1
    EXCEPT
    SELECT n FROM t1 WHERE log=3
    ORDER BY log;
  }
} {0 1 2 3 4}

# do_test select4-3.1.2 {
#   execsql {
#     CREATE TABLE t2 AS 
#       SELECT DISTINCT log FROM t1
#       EXCEPT
#       SELECT n FROM t1 WHERE log=3
#       ORDER BY log;
#     SELECT * FROM t2;
#   }
# } {0 1 2 3 4}
# execsql {DROP TABLE t2}
# do_test select4-3.1.3 {
#   execsql {
#     CREATE TABLE t2 AS 
#       SELECT DISTINCT log FROM t1
#       EXCEPT
#       SELECT n FROM t1 WHERE log=3
#       ORDER BY log DESC;
#     SELECT * FROM t2;
#   }
# } {4 3 2 1 0}
# execsql {DROP TABLE t2}
ifcapable subquery {
  do_test select4-3.2 {
    execsql {
      SELECT log FROM t1 WHERE n IN 
        (SELECT DISTINCT log FROM t1 EXCEPT
         SELECT n FROM t1 WHERE log=3)
      ORDER BY log;
    }
  } {0 1 2 2}
}
do_test select4-3.3 {
  set v [catch {execsql {
    SELECT DISTINCT log FROM t1 ORDER BY log
    EXCEPT
    SELECT n FROM t1 WHERE log=3
    ORDER BY log;
  }} msg]
  lappend v $msg
} {1 {ORDER BY clause should come after EXCEPT not before}}

# Intersect operator
#
do_test select4-4.1.1 {
  execsql {
    SELECT DISTINCT log FROM t1
    INTERSECT
    SELECT n FROM t1 WHERE log=3
    ORDER BY log;
  }
} {5}

do_test select4-4.1.2 {
  execsql {
    SELECT DISTINCT log FROM t1
    UNION ALL
    SELECT 6
    INTERSECT
    SELECT n FROM t1 WHERE log=3
    ORDER BY t1.log;
  }
} {5 6}

# do_test select4-4.1.3 {
#   execsql {
#     CREATE TABLE t2 AS
#       SELECT DISTINCT log FROM t1 UNION ALL SELECT 6
#       INTERSECT
#       SELECT n FROM t1 WHERE log=3
#       ORDER BY log;
#     SELECT * FROM t2;
#   }
# } {5 6}
# execsql {DROP TABLE t2}
# do_test select4-4.1.4 {
#   execsql {
#     CREATE TABLE t2 AS
#       SELECT DISTINCT log FROM t1 UNION ALL SELECT 6
#       INTERSECT
#       SELECT n FROM t1 WHERE log=3
#       ORDER BY log DESC;
#     SELECT * FROM t2;
#   }
# } {6 5}
# execsql {DROP TABLE t2}
ifcapable subquery {
  do_test select4-4.2 {
    execsql {
      SELECT log FROM t1 WHERE n IN 
        (SELECT DISTINCT log FROM t1 INTERSECT
         SELECT n FROM t1 WHERE log=3)
      ORDER BY log;
    }
  } {3}
}
do_test select4-4.3 {
  set v [catch {execsql {
    SELECT DISTINCT log FROM t1 ORDER BY log
    INTERSECT
    SELECT n FROM t1 WHERE log=3
    ORDER BY log;
  }} msg]
  lappend v $msg
} {1 {ORDER BY clause should come after INTERSECT not before}}
do_catchsql_test select4-4.4 {
  SELECT 3 IN (
    SELECT 0 ORDER BY 1
    INTERSECT
    SELECT 1
    INTERSECT 
    SELECT 2
    ORDER BY 1
  );
} {1 {ORDER BY clause should come after INTERSECT not before}}

# Various error messages while processing UNION or INTERSECT
#
do_test select4-5.1 {
  set v [catch {execsql {
    SELECT DISTINCT log FROM t2
    UNION ALL
    SELECT n FROM t1 WHERE log=3
    ORDER BY log;
  }} msg]
  lappend v $msg
} {1 {no such table: t2}}
do_test select4-5.2 {
  set v [catch {execsql {
    SELECT DISTINCT log AS "xyzzy" FROM t1
    UNION ALL
    SELECT n FROM t1 WHERE log=3
    ORDER BY xyzzy;
  }} msg]
  lappend v $msg
} {0 {0 1 2 3 4 5 5 6 7 8}}
do_test select4-5.2b {
  set v [catch {execsql {
    SELECT DISTINCT log AS xyzzy FROM t1
    UNION ALL
    SELECT n FROM t1 WHERE log=3
    ORDER BY "xyzzy";
  }} msg]
  lappend v $msg
} {0 {0 1 2 3 4 5 5 6 7 8}}
do_test select4-5.2c {
  set v [catch {execsql {
    SELECT DISTINCT log FROM t1
    UNION ALL
    SELECT n FROM t1 WHERE log=3
    ORDER BY "xyzzy";
  }} msg]
  lappend v $msg
} {1 {1st ORDER BY term does not match any column in the result set}}
do_test select4-5.2d {
  set v [catch {execsql {
    SELECT DISTINCT log FROM t1
    INTERSECT
    SELECT n FROM t1 WHERE log=3
    ORDER BY "xyzzy";
  }} msg]
  lappend v $msg
} {1 {1st ORDER BY term does not match any column in the result set}}
do_test select4-5.2e {
  set v [catch {execsql {
    SELECT DISTINCT log FROM t1
    UNION ALL
    SELECT n FROM t1 WHERE log=3
    ORDER BY n;
  }} msg]
  lappend v $msg
} {0 {0 1 2 3 4 5 5 6 7 8}}
do_test select4-5.2f {
  catchsql {
    SELECT DISTINCT log FROM t1
    UNION ALL
    SELECT n FROM t1 WHERE log=3
    ORDER BY log;
  }
} {0 {0 1 2 3 4 5 5 6 7 8}}
do_test select4-5.2g {
  catchsql {
    SELECT DISTINCT log FROM t1
    UNION ALL
    SELECT n FROM t1 WHERE log=3
    ORDER BY 1;
  }
} {0 {0 1 2 3 4 5 5 6 7 8}}
do_test select4-5.2h {
  catchsql {
    SELECT DISTINCT log FROM t1
    UNION ALL
    SELECT n FROM t1 WHERE log=3
    ORDER BY 2;
  }
} {1 {1st ORDER BY term out of range - should be between 1 and 1}}
do_test select4-5.2i {
  catchsql {
    SELECT DISTINCT 1, log FROM t1
    UNION ALL
    SELECT 2, n FROM t1 WHERE log=3
    ORDER BY 2, 1;
  }
} {0 {1 0 1 1 1 2 1 3 1 4 1 5 2 5 2 6 2 7 2 8}}
do_test select4-5.2j {
  catchsql {
    SELECT DISTINCT 1, log FROM t1
    UNION ALL
    SELECT 2, n FROM t1 WHERE log=3
    ORDER BY 1, 2 DESC;
  }
} {0 {1 5 1 4 1 3 1 2 1 1 1 0 2 8 2 7 2 6 2 5}}
do_test select4-5.2k {
  catchsql {
    SELECT DISTINCT 1, log FROM t1
    UNION ALL
    SELECT 2, n FROM t1 WHERE log=3
    ORDER BY n, 1;
  }
} {0 {1 0 1 1 1 2 1 3 1 4 1 5 2 5 2 6 2 7 2 8}}
do_test select4-5.3 {
  set v [catch {execsql {
    SELECT DISTINCT log, n FROM t1
    UNION ALL
    SELECT n FROM t1 WHERE log=3
    ORDER BY log;
  }} msg]
  lappend v $msg
} {1 {SELECTs to the left and right of UNION ALL do not have the same number of result columns}}
do_test select4-5.3-3807-1 {
  catchsql {
    SELECT 1 UNION SELECT 2, 3 UNION SELECT 4, 5 ORDER BY 1;
  }
} {1 {SELECTs to the left and right of UNION do not have the same number of result columns}}
do_test select4-5.4 {
  set v [catch {execsql {
    SELECT log FROM t1 WHERE n=2
    UNION ALL
    SELECT log FROM t1 WHERE n=3
    UNION ALL
    SELECT log FROM t1 WHERE n=4
    UNION ALL
    SELECT log FROM t1 WHERE n=5
    ORDER BY log;
  }} msg]
  lappend v $msg
} {0 {1 2 2 3}}

do_test select4-6.1 {
  execsql {
    SELECT log, count(*) as cnt FROM t1 GROUP BY log
    UNION
    SELECT log, n FROM t1 WHERE n=7
    ORDER BY cnt, log;
  }
} {0 1 1 1 2 2 3 4 3 7 4 8 5 15}
do_test select4-6.2 {
  execsql {
    SELECT log, count(*) FROM t1 GROUP BY log
    UNION
    SELECT log, n FROM t1 WHERE n=7
    ORDER BY count(*), log;
  }
} {0 1 1 1 2 2 3 4 3 7 4 8 5 15}

# NULLs are indistinct for the UNION operator.
# Make sure the UNION operator recognizes this
#
do_test select4-6.3 {
  execsql {
    SELECT NULL UNION SELECT NULL UNION
    SELECT 1 UNION SELECT 2 AS 'x'
    ORDER BY x;
  }
} {{} 1 2}
do_test select4-6.3.1 {
  execsql {
    SELECT NULL UNION ALL SELECT NULL UNION ALL
    SELECT 1 UNION ALL SELECT 2 AS 'x'
    ORDER BY x;
  }
} {{} {} 1 2}

# Make sure the DISTINCT keyword treats NULLs as indistinct.
#
ifcapable subquery {
  do_test select4-6.4 {
    execsql {
      SELECT * FROM (
         SELECT NULL, 1 UNION ALL SELECT NULL, 1
      );
    }
  } {{} 1 {} 1}
  do_test select4-6.5 {
    execsql {
      SELECT DISTINCT * FROM (
         SELECT NULL, 1 UNION ALL SELECT NULL, 1
      );
    }
  } {{} 1}
  do_test select4-6.6 {
    execsql {
      SELECT DISTINCT * FROM (
         SELECT 1,2  UNION ALL SELECT 1,2
      );
    }
  } {1 2}
}

# Test distinctness of NULL in other ways.
#
do_test select4-6.7 {
  execsql {
    SELECT NULL EXCEPT SELECT NULL
  }
} {}

execsql {DROP TABLE IF EXISTS t2;
CREATE TABLE t2 (x int primary key, y int);
INSERT INTO t2 VALUES (0, 1), (1, 1), (2, 2), (3, 4), (4, 8), (5, 15);}

# # Make sure column names are correct when a compound select appears as
# # an expression in the WHERE clause.
# #
# do_test select4-7.1 {
#   execsql {
#     CREATE TABLE t2 AS SELECT log AS 'x', count(*) AS 'y' FROM t1 GROUP BY log;
#     SELECT * FROM t2 ORDER BY x;
#   }
# } {0 1 1 1 2 2 3 4 4 8 5 15}  
ifcapable subquery {
  do_test select4-7.2 {
    execsql2 {
      SELECT * FROM t1 WHERE n IN (SELECT n FROM t1 INTERSECT SELECT x FROM t2)
      ORDER BY n
    }
  } {n 1 log 0 n 2 log 1 n 3 log 2 n 4 log 2 n 5 log 3}
  do_test select4-7.3 {
    execsql2 {
      SELECT * FROM t1 WHERE n IN (SELECT n FROM t1 EXCEPT SELECT x FROM t2)
      ORDER BY n LIMIT 2
    }
  } {n 6 log 3 n 7 log 3}
  do_test select4-7.4 {
    execsql2 {
      SELECT * FROM t1 WHERE n IN (SELECT n FROM t1 UNION SELECT x FROM t2)
      ORDER BY n LIMIT 2
    }
  } {n 1 log 0 n 2 log 1}
} ;# ifcapable subquery

} ;# ifcapable compound

# Make sure DISTINCT works appropriately on TEXT and NUMERIC columns.
do_test select4-8.1 {
  execsql {
    BEGIN;
    CREATE TABLE t3(a text primary key, b float, c text);
    INSERT INTO t3 VALUES(1, 1.1, '1.1');
    INSERT INTO t3 VALUES(2, 1.10, '1.10');
    INSERT INTO t3 VALUES(3, 1.10, '1.1');
    INSERT INTO t3 VALUES(4, 1.1, '1.10');
    INSERT INTO t3 VALUES(5, 1.2, '1.2');
    INSERT INTO t3 VALUES(6, 1.3, '1.3');
    COMMIT;
  }
  execsql {
    SELECT DISTINCT b FROM t3 ORDER BY c;
  }
} {1.1 1.2 1.3}
do_test select4-8.2 {
  execsql {
    SELECT DISTINCT c FROM t3 ORDER BY c;
  }
} {1.1 1.10 1.2 1.3}

# Make sure the names of columns are taken from the right-most subquery
# right in a compound query.  Ticket #1721
#
ifcapable compound {

do_test select4-9.1 {
  execsql2 {
    SELECT x, y FROM t2 UNION SELECT a, b FROM t3 ORDER BY x LIMIT 1
  }
} {x 0 y 1}
do_test select4-9.2 {
  execsql2 {
    SELECT x, y FROM t2 UNION ALL SELECT a, b FROM t3 ORDER BY x LIMIT 1
  }
} {x 0 y 1}
do_test select4-9.3 {
  execsql2 {
    SELECT x, y FROM t2 EXCEPT SELECT a, b FROM t3 ORDER BY x LIMIT 1
  }
} {x 0 y 1}
do_test select4-9.4 {
  execsql2 {
    SELECT x, y FROM t2 INTERSECT SELECT 0 AS a, 1 AS b;
  }
} {x 0 y 1}
do_test select4-9.5 {
  execsql2 {
    SELECT 0 AS x, 1 AS y
    UNION
    SELECT 2 AS p, 3 AS q
    UNION
    SELECT 4 AS a, 5 AS b
    ORDER BY x LIMIT 1
  }
} {x 0 y 1}

ifcapable subquery {
do_test select4-9.6 {
  execsql2 {
    SELECT * FROM (
      SELECT 0 AS x, 1 AS y
      UNION
      SELECT 2 AS p, 3 AS q
      UNION
      SELECT 4 AS a, 5 AS b
    ) ORDER BY 1 LIMIT 1;
  }
} {x 0 y 1}
do_test select4-9.7 {
  execsql2 {
    SELECT * FROM (
      SELECT 0 AS x, 1 AS y
      UNION
      SELECT 2 AS p, 3 AS q
      UNION
      SELECT 4 AS a, 5 AS b
    ) ORDER BY x LIMIT 1;
  }
} {x 0 y 1}
} ;# ifcapable subquery

do_test select4-9.8 {
  execsql {
    SELECT 0 AS x, 1 AS y
    UNION
    SELECT 2 AS y, -3 AS x
    ORDER BY x LIMIT 1;
  }
} {0 1}

do_test select4-9.9.1 {
  execsql2 {
    SELECT 1 AS a, 2 AS b UNION ALL SELECT 3 AS b, 4 AS a
  }
} {a 1 b 2 a 3 b 4}

ifcapable subquery {
do_test select4-9.9.2 {
  execsql2 {
    SELECT * FROM (SELECT 1 AS a, 2 AS b UNION ALL SELECT 3 AS b, 4 AS a)
     WHERE b=3
  }
} {}
do_test select4-9.10 {
  execsql2 {
    SELECT * FROM (SELECT 1 AS a, 2 AS b UNION ALL SELECT 3 AS b, 4 AS a)
     WHERE b=2
  }
} {a 1 b 2}
do_test select4-9.11 {
  execsql2 {
    SELECT * FROM (SELECT 1 AS a, 2 AS b UNION ALL SELECT 3 AS e, 4 AS b)
     WHERE b=2
  }
} {a 1 b 2}
do_test select4-9.12 {
  execsql2 {
    SELECT * FROM (SELECT 1 AS a, 2 AS b UNION ALL SELECT 3 AS e, 4 AS b)
     WHERE b>0
  }
} {a 1 b 2 a 3 b 4}
} ;# ifcapable subquery

# Try combining DISTINCT, LIMIT, and OFFSET.  Make sure they all work
# together.
#
do_test select4-10.1 {
  execsql {
    SELECT DISTINCT log FROM t1 ORDER BY log
  }
} {0 1 2 3 4 5}
do_test select4-10.2 {
  execsql {
    SELECT DISTINCT log FROM t1 ORDER BY log LIMIT 4
  }
} {0 1 2 3}
do_test select4-10.3 {
  execsql {
    SELECT DISTINCT log FROM t1 ORDER BY log LIMIT 0
  }
} {}
do_test select4-10.4 {
  execsql {
    SELECT DISTINCT log FROM t1 ORDER BY log LIMIT -1
  }
} {0 1 2 3 4 5}
do_test select4-10.5 {
  execsql {
    SELECT DISTINCT log FROM t1 ORDER BY log LIMIT -1 OFFSET 2
  }
} {2 3 4 5}
do_test select4-10.6 {
  execsql {
    SELECT DISTINCT log FROM t1 ORDER BY log LIMIT 3 OFFSET 2
  }
} {2 3 4}
do_test select4-10.7 {
  execsql {
    SELECT DISTINCT log FROM t1 ORDER BY +log LIMIT 3 OFFSET 20
  }
} {}
do_test select4-10.8 {
  execsql {
    SELECT DISTINCT log FROM t1 ORDER BY log LIMIT 0 OFFSET 3
  }
} {}
do_test select4-10.9 {
  execsql {
    SELECT DISTINCT max(n), log FROM t1 ORDER BY +log; -- LIMIT 2 OFFSET 1
  }
} {31 5}

execsql {DROP TABLE IF EXISTS t2;
CREATE TABLE t2 (rowid int primary key, x, y);}

# Make sure compound SELECTs with wildly different numbers of columns
# do not cause assertion faults due to register allocation issues.
#
do_test select4-11.1 {
  catchsql {
    SELECT x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x FROM t2
    UNION
    SELECT x FROM t2
  }
} {1 {SELECTs to the left and right of UNION do not have the same number of result columns}}
do_test select4-11.2 {
  catchsql {
    SELECT x FROM t2
    UNION
    SELECT x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x FROM t2
  }
} {1 {SELECTs to the left and right of UNION do not have the same number of result columns}}
do_test select4-11.3 {
  catchsql {
    SELECT x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x FROM t2
    UNION ALL
    SELECT x FROM t2
  }
} {1 {SELECTs to the left and right of UNION ALL do not have the same number of result columns}}
do_test select4-11.4 {
  catchsql {
    SELECT x FROM t2
    UNION ALL
    SELECT x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x FROM t2
  }
} {1 {SELECTs to the left and right of UNION ALL do not have the same number of result columns}}
do_test select4-11.5 {
  catchsql {
    SELECT x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x FROM t2
    EXCEPT
    SELECT x FROM t2
  }
} {1 {SELECTs to the left and right of EXCEPT do not have the same number of result columns}}
do_test select4-11.6 {
  catchsql {
    SELECT x FROM t2
    EXCEPT
    SELECT x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x FROM t2
  }
} {1 {SELECTs to the left and right of EXCEPT do not have the same number of result columns}}
do_test select4-11.7 {
  catchsql {
    SELECT x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x FROM t2
    INTERSECT
    SELECT x FROM t2
  }
} {1 {SELECTs to the left and right of INTERSECT do not have the same number of result columns}}
do_test select4-11.8 {
  catchsql {
    SELECT x FROM t2
    INTERSECT
    SELECT x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x FROM t2
  }
} {1 {SELECTs to the left and right of INTERSECT do not have the same number of result columns}}

do_test select4-11.11 {
  catchsql {
    SELECT x FROM t2
    UNION
    SELECT x FROM t2
    UNION ALL
    SELECT x FROM t2
    EXCEPT
    SELECT x FROM t2
    INTERSECT
    SELECT x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x FROM t2
  }
} {1 {SELECTs to the left and right of INTERSECT do not have the same number of result columns}}
do_test select4-11.12 {
  catchsql {
    SELECT x FROM t2
    UNION
    SELECT x FROM t2
    UNION ALL
    SELECT x FROM t2
    EXCEPT
    SELECT x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x FROM t2
    EXCEPT
    SELECT x FROM t2
  }
} {1 {SELECTs to the left and right of EXCEPT do not have the same number of result columns}}
do_test select4-11.13 {
  catchsql {
    SELECT x FROM t2
    UNION
    SELECT x FROM t2
    UNION ALL
    SELECT x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x FROM t2
    UNION ALL
    SELECT x FROM t2
    EXCEPT
    SELECT x FROM t2
  }
} {1 {SELECTs to the left and right of UNION ALL do not have the same number of result columns}}
do_test select4-11.14 {
  catchsql {
    SELECT x FROM t2
    UNION
    SELECT x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x FROM t2
    UNION
    SELECT x FROM t2
    UNION ALL
    SELECT x FROM t2
    EXCEPT
    SELECT x FROM t2
  }
} {1 {SELECTs to the left and right of UNION do not have the same number of result columns}}
do_test select4-11.15 {
  catchsql {
    SELECT x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x,x FROM t2
    UNION
    SELECT x FROM t2
    INTERSECT
    SELECT x FROM t2
    UNION ALL
    SELECT x FROM t2
    EXCEPT
    SELECT x FROM t2
  }
} {1 {SELECTs to the left and right of UNION do not have the same number of result columns}}
do_test select4-11.16 {
  catchsql {
    INSERT INTO t2(rowid) VALUES(2) UNION SELECT 3,4 UNION SELECT 5,6 ORDER BY 1;
  }
} {1 {SELECTs to the left and right of UNION do not have the same number of result columns}}

# MUST_WORK_TEST

# do_test select4-12.1 {
#   catchsql {
#     SELECT 1 UNION SELECT 2,3 UNION SELECT 4,5 ORDER BY 1;
#   } db2
# } {1 {SELECTs to the left and right of UNION do not have the same number of result columns}}

} ;# ifcapable compound


# Ticket [3557ad65a076c] - Incorrect DISTINCT processing with an
# indexed query using IN.
#
do_test select4-13.1 {
  db eval {
    CREATE TABLE t13(id int primary key,a,b);
    INSERT INTO t13 VALUES(0, 1,1);
    INSERT INTO t13 VALUES(1, 2,1);
    INSERT INTO t13 VALUES(2, 3,1);
    INSERT INTO t13 VALUES(3, 2,2);
    INSERT INTO t13 VALUES(4, 3,2);
    INSERT INTO t13 VALUES(5, 4,2);
    CREATE INDEX t13ab ON t13(a,b);
    SELECT DISTINCT b from t13 WHERE a IN (1,2,3);
  }
} {1 2}

# 2014-02-18: Make sure compound SELECTs work with VALUES clauses
#
do_execsql_test select4-14.1 {
  CREATE TABLE t14(a primary key,b,c);
  INSERT INTO t14 VALUES(1,2,3),(4,5,6);
  SELECT * FROM t14 INTERSECT VALUES(3,2,1),(2,3,1),(1,2,3),(2,1,3);
} {1 2 3}
execsql {DROP TABLE IF EXISTS t14;
CREATE TABLE t14 (a int primary key, b int, c int);
INSERT INTO t14 VALUES (1, 2, 3),(4, 5, 6);}

do_execsql_test select4-14.2 {
  SELECT * FROM t14 INTERSECT VALUES(1,2,3);
} {1 2 3}
do_execsql_test select4-14.3 {
  SELECT * FROM t14
   UNION VALUES(3,2,1),(2,3,1),(1,2,3),(7,8,9),(4,5,6)
   UNION SELECT * FROM t14 ORDER BY 1, 2, 3
} {1 2 3 2 3 1 3 2 1 4 5 6 7 8 9}
do_execsql_test select4-14.4 {
  SELECT * FROM t14
   UNION VALUES(3,2,1)
   UNION SELECT * FROM t14 ORDER BY 1, 2, 3
} {1 2 3 3 2 1 4 5 6}
do_execsql_test select4-14.5 {
  SELECT * FROM t14 EXCEPT VALUES(3,2,1),(2,3,1),(1,2,3),(2,1,3);
} {4 5 6}
do_execsql_test select4-14.6 {
  SELECT * FROM t14 EXCEPT VALUES(1,2,3)
} {4 5 6}
do_execsql_test select4-14.7 {
  SELECT * FROM t14 EXCEPT VALUES(1,2,3) EXCEPT VALUES(4,5,6)
} {}
do_execsql_test select4-14.8 {
  SELECT * FROM t14 EXCEPT VALUES('a','b','c') EXCEPT VALUES(4,5,6)
} {1 2 3}
do_execsql_test select4-14.9 {
  SELECT * FROM t14 UNION ALL VALUES(3,2,1),(2,3,1),(1,2,3),(2,1,3);
} {1 2 3 4 5 6 3 2 1 2 3 1 1 2 3 2 1 3}
do_execsql_test select4-14.10 {
  SELECT (VALUES(1),(2),(3),(4))
} {1}
do_execsql_test select4-14.11 {
  SELECT (SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4)
} {1}
do_execsql_test select4-14.12 {
  VALUES(1) UNION VALUES(2);
} {1 2}
do_execsql_test select4-14.13 {
  VALUES(1),(2),(3) EXCEPT VALUES(2);
} {1 3}
do_execsql_test select4-14.14 {
  VALUES(1),(2),(3) EXCEPT VALUES(1),(3);
} {2}
do_execsql_test select4-14.15 {
  SELECT * FROM (SELECT 123), (SELECT 456) ON likely(0 OR 1) OR 0;
} {123 456}
do_execsql_test select4-14.16 {
  VALUES(1),(2),(3),(4) UNION ALL SELECT 5 LIMIT 99;
} {1 2 3 4 5}
do_execsql_test select4-14.17 {
  VALUES(1),(2),(3),(4) UNION ALL SELECT 5 LIMIT 3;
} {1 2 3}

finish_test
