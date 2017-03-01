#!./tcltestrunner.lua

# 2007 May 1
#
# The author disclaims copyright to this source code.  In place of
# a legal notice, here is a blessing:
#
#    May you do good and not evil.
#    May you find forgiveness for yourself and forgive others.
#    May you share freely, never taking more than you give.
#
#***********************************************************************
#
# $Id: icu.test,v 1.2 2008/07/12 14:52:20 drh Exp $
#

set testdir [file dirname $argv0]
source $testdir/tester.tcl

ifcapable !icu {
  finish_test
  return
}

# MUST_WORK_TEST

# # Create a table to work with.
# #
# execsql {CREATE TABLE test1(i1 int, i2 int, r1 real, r2 real, t1 text, t2 text)}
# execsql {INSERT INTO test1 VALUES(1,2,1.1,2.2,'hello','world')}
# proc test_expr {name settings expr result} {
#   do_test $name [format {
#     lindex [db eval {
#       BEGIN; 
#       UPDATE test1 SET %s; 
#       SELECT %s FROM test1; 
#       ROLLBACK;
#     }] 0
#   } $settings $expr] $result
# }

# # Tests of the REGEXP operator.
# #
# test_expr icu-1.1 {i1='hello'} {i1 REGEXP 'hello'}  1
# test_expr icu-1.2 {i1='hello'} {i1 REGEXP '.ello'}  1
# test_expr icu-1.3 {i1='hello'} {i1 REGEXP '.ell'}   0
# test_expr icu-1.4 {i1='hello'} {i1 REGEXP '.ell.*'} 1
# test_expr icu-1.5 {i1=NULL}    {i1 REGEXP '.ell.*'} {}

# # Some non-ascii characters with defined case mappings
# #
# set ::EGRAVE "\xC8"
# set ::egrave "\xE8"

# set ::OGRAVE "\xD2"
# set ::ograve "\xF2"

# # That German letter that looks a bit like a B. The
# # upper-case version of which is "SS" (two characters).
# #
# set ::szlig "\xDF" 

# # Tests of the upper()/lower() functions.
# #
# test_expr icu-2.1 {i1='HellO WorlD'} {upper(i1)} {HELLO WORLD}
# test_expr icu-2.2 {i1='HellO WorlD'} {lower(i1)} {hello world}
# test_expr icu-2.3 {i1=$::egrave} {lower(i1)}     $::egrave
# test_expr icu-2.4 {i1=$::egrave} {upper(i1)}     $::EGRAVE
# test_expr icu-2.5 {i1=$::ograve} {lower(i1)}     $::ograve
# test_expr icu-2.6 {i1=$::ograve} {upper(i1)}     $::OGRAVE
# test_expr icu-2.3 {i1=$::EGRAVE} {lower(i1)}     $::egrave
# test_expr icu-2.4 {i1=$::EGRAVE} {upper(i1)}     $::EGRAVE
# test_expr icu-2.5 {i1=$::OGRAVE} {lower(i1)}     $::ograve
# test_expr icu-2.6 {i1=$::OGRAVE} {upper(i1)}     $::OGRAVE

# test_expr icu-2.7 {i1=$::szlig} {upper(i1)}      "SS"
# test_expr icu-2.8 {i1='SS'} {lower(i1)}          "ss"

# # In turkish (locale="tr_TR"), the lower case version of I
# # is "small dotless i" (code point 0x131 (decimal 305)).
# #
# set ::small_dotless_i "\u0131"
# test_expr icu-3.1 {i1='I'} {lower(i1)}           "i"
# test_expr icu-3.2 {i1='I'} {lower(i1, 'tr_tr')}  $::small_dotless_i
# test_expr icu-3.3 {i1='I'} {lower(i1, 'en_AU')}  "i"

# #--------------------------------------------------------------------
# # Test the collation sequence function.
# #
# do_test icu-4.1 {
#   execsql {
#     CREATE TABLE fruit(name);
#     INSERT INTO fruit VALUES('plum');
#     INSERT INTO fruit VALUES('cherry');
#     INSERT INTO fruit VALUES('apricot');
#     INSERT INTO fruit VALUES('peach');
#     INSERT INTO fruit VALUES('chokecherry');
#     INSERT INTO fruit VALUES('yamot');
#   }
# } {}
# do_test icu-4.2 {
#   execsql {
#     SELECT icu_load_collation('en_US', 'AmericanEnglish');
#     SELECT icu_load_collation('lt_LT', 'Lithuanian');
#   }
#   execsql {
#     SELECT name FROM fruit ORDER BY name COLLATE AmericanEnglish ASC;
#   }
# } {apricot cherry chokecherry peach plum yamot}


# # Test collation using Lithuanian rules. In the Lithuanian
# # alphabet, "y" comes right after "i".
# #
# do_test icu-4.3 {
#   execsql {
#     SELECT name FROM fruit ORDER BY name COLLATE Lithuanian ASC;
#   }
# } {apricot cherry chokecherry yamot peach plum}

# #-------------------------------------------------------------------------
# # Test that it is not possible to call the ICU regex() function with 
# # anything other than exactly two arguments. See also:
# #
# #   http://src.chromium.org/viewvc/chrome/trunk/src/third_party/sqlite/icu-regexp.patch?revision=34807&view=markup
# #
# do_catchsql_test icu-5.1 { SELECT regexp('a[abc]c.*', 'abc') } {0 1}
# do_catchsql_test icu-5.2 { 
#   SELECT regexp('a[abc]c.*') 
# } {1 {wrong number of arguments to function regexp()}}
# do_catchsql_test icu-5.3 { 
#   SELECT regexp('a[abc]c.*', 'abc', 'c') 
# } {1 {wrong number of arguments to function regexp()}}
# do_catchsql_test icu-5.4 { 
#   SELECT 'abc' REGEXP 'a[abc]c.*'
# } {0 1}
# do_catchsql_test icu-5.4 { SELECT 'abc' REGEXP }    {1 {near " ": syntax error}}
# do_catchsql_test icu-5.5 { SELECT 'abc' REGEXP, 1 } {1 {near ",": syntax error}}

finish_test
