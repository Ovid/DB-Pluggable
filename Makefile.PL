use inc::Module::Install;
include 'Module::AutoInstall';

name 'DB-Pluggable';
all_from 'lib/DB/Pluggable.pm';
perl_version '5.006';

requires 'Hook::LexWrap';
requires 'Hook::Modular';

test_requires 'Test::Differences';
test_requires 'Test::More' => '0.70';
extra_tests;

auto_install;
auto_include;
WriteAll;
