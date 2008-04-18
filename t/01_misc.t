#!/usr/bin/env perl

use warnings;
use strict;
use Test::More tests => 1;
use Test::Differences;
use YAML;
use DB::Pluggable;


my $handler = DB::Pluggable->new(config => Load <<EOYAML);
global:
  log:
    level: error

plugins:
  - module: BreakOnTestNumber
EOYAML

isa_ok($handler, 'DB::Pluggable');

# hm, it's a bit difficult to test deep debugger magic...

