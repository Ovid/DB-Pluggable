use inc::Module::Install;
include 'Module::AutoInstall';

name 'DB-Pluggable';
all_from 'lib/DB/Pluggable.pm';
perl_version '5.006';

requires 'Hook::LexWrap';
requires 'Hook::Modular';

recommends 'Test::Pod';
recommends 'Test::Pod::Coverage';

test_requires 'Test::Differences';
test_requires 'Test::More' => '0.70';
test_requires 'Test::Compile';

auto_install;
auto_include;
WriteAll;
