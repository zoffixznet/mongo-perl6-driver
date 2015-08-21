#`{{
  Testing;
    Authentication of a user
}}

use v6;
use Test;
use MongoDB::Connection;
use MongoDB::Database::Users;
use MongoDB::Database::Authenticate;

BEGIN { @*INC.unshift( './t' ) }
use Test-support;

my MongoDB::Connection $connection = get-connection();

# Drop database first then create new databases
#
#$connection.database('test').drop;

my MongoDB::Database $database;
my MongoDB::Database::Users $users;
my MongoDB::Database::Authenticate $auth;

my Hash $doc;
my $exit_code;

plan 1;
skip-rest "Some authentication modules not yet supported in perl 6";
exit(0);

#-------------------------------------------------------------------------------
subtest {
  $database = $connection.database('test');
  $users .= new(:$database);

  $doc = $users.drop_all_users_from_database();
  ok $doc<ok>, 'All users dropped';

  $users.set_pw_security(
    :min_un_length(10), 
    :min_pw_length(8),
    :pw_attribs($MongoDB::Database::Users::PW-OTHER-CHARS)
  );

  $doc = $users.create_user(
    :user('site-admin'),
    :password('B3n@Hurry'),
    :custom_data({user-type => 'site-admin'}),
    :roles([{role => 'userAdminAnyDatabase', db => 'admin'}])
  );

  ok $doc<ok>, 'User site-admin created';

  $doc = $users.create_user(
    :user('Dondersteen'),
    :password('w@tD8jeDan'),
    :custom_data(
      { license => 'to_kill',
        user-type => 'database-test-admin'
      }
    ),
    :roles([{role => 'readWrite', db => 'test'}])
  );

  ok $doc<ok>, 'User Dondersteen created';

  $doc = $users.get_users;
#say "Users: ", $doc.perl;
  is $doc<users>.elems, 2, '2 users defined';
  is $doc<users>[0]<user>, 'site-admin', 'User site-admin';
  is $doc<users>[1]<user>, 'Dondersteen', 'User Dondersteen';
}, "User account preparation";


#---------------------------------------------------------------------------------
subtest {
  diag "Change server mode to authenticated mode";
  $exit_code = shell("kill `cat $*CWD/Sandbox/m.pid`");
  sleep 2;

  $exit_code = shell("mongod --auth --config '$*CWD/Sandbox/m-auth.conf'");
  $connection = get-connection-try10();
#  diag "Changed server mode";
}, "Server changed to authentication mode";

#---------------------------------------------------------------------------------
subtest {
  # Must get a new database, users and authentication object because server
  # is restarted.
  #
  $database = $connection.database('test');
  $users .= new(:$database);
  $auth .= new(:$database);

  if 1 {
    $doc = $users.drop_all_users_from_database();
    ok $doc<ok>, 'All users dropped';
    
    CATCH {
      when X::MongoDB::Database {
        ok .message ~~ m:s/not authorized on test to execute/, .error-text;
      }
    }
  }

  if 1 {
    $doc = $auth.authenticate( :user('mt'), :password('mt++'));

    CATCH {
      when X::MongoDB::Database {
        ok .message ~~ m:s/\w/, .error-text;
      }
    }
  }

  $doc = $auth.authenticate( :user('Dondersteen'), :password('w@tD8jeDan'));
  ok $doc<ok>, 'User Dondersteen logged in';

  $doc = $auth.logout(:user('Dondersteen'));
  ok $doc<ok>, 'User Dondersteen logged out';

}, "Authenticate tests";

#---------------------------------------------------------------------------------
subtest {
  diag "Change server mode back to normal mode";
  $exit_code = shell("kill `cat $*CWD/Sandbox/m.pid`");
  sleep 2;

  $exit_code = shell("mongod --config '$*CWD/Sandbox/m.conf'");
  $connection = get-connection-try10();
#  diag "Changed server mode";

  # Must get a new database and user object because server is restarted.
  #
  $database = $connection.database('test');
  $users .= new(:$database);

  $doc = $users.drop_all_users_from_database();
  ok $doc<ok>, 'All users dropped';
}, "Server changed to normal mode";

#-------------------------------------------------------------------------------
# Cleanup
#
$connection.database('test').drop;

done();
exit(0);
