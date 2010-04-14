use 5.008;
use strict;
use warnings;

package DB::Pluggable::BreakOnTestNumber;
# ABSTRACT: Debugger plugin to break on Test::Builder-based tests
use DB::Pluggable::Constants ':all';
use parent 'Hook::Modular::Plugin';

sub register {
    my ($self, $context) = @_;
    $context->register_hook(
        $self,
        'plugin.init'      => $self->can('plugin_init'),
        'db.cmd.b'         => $self->can('cmd_b'),
        'db.watchfunction' => $self->can('watchfunction'),
    );
}

sub plugin_init {
    @DB::testbreak = ();
}

sub cmd_b {
    my ($self, $context, $args) = @_;
    if ($args->{line} =~ /\s*#\s*(\d+(?:\s*,\s*\d+)*)$/) {
        my %seen;
        @DB::testbreak = grep { !$seen{$_}++ }
          sort { $a <=> $b } (split(/\s*,\s*/, $1), @DB::testbreak);

        # enable the watchfunction JIT so we don't waste time at the beginning
        $context->enable_watchfunction;
        return HANDLED;
    } else {
        return DECLINED;
    }
}

sub watchfunction {
    my $self = shift;
    if (@DB::testbreak && exists $INC{'Test/Builder.pm'}) {
        my $next = Test::Builder->new->current_test + 1;
        if ($next >= $DB::testbreak[0]) {
            shift @DB::testbreak
              while @DB::testbreak && $next >= $DB::testbreak[0];
            my $depth = 1;
            while (1) {
                my $package = (caller $depth)[0];
                last unless defined $package;
                last unless $package =~ /^(DB(::|$)|Test::)/;
                $depth++;
            }

            no warnings 'once';
            $DB::stack[ -$depth ] = 1;
        }
    }
    return;
}
1;

=begin :prelude

=for stopwords watchfunction

=for test_synopsis
1;
__END__

=end :prelude

=head1 SYNOPSIS

    $ cat ~/.perldb

    use DB::Pluggable;
    use YAML;

    $DB::PluginHandler = DB::Pluggable->new(config => Load <<EOYAML);
    global:
      log:
        level: error

    plugins:
      - module: BreakOnTestNumber
    EOYAML

    $DB::PluginHandler->run;

    $ perl -d foo.pl

    Loading DB routines from perl5db.pl version 1.28
    Editor support available.

    Enter h or `h h' for help, or `man perldebug' for more help.

    1..9
    ...
      DB<1> b #5
      DB<2> r

=head1 DESCRIPTION

This debugger plugin extends the debugger's C<b> command - used to set
breakpoints - with the ability to stop at a specific test number. Andy
Armstrong had the idea and wrote the original code, see
L<http://use.perl.org/~AndyArmstrong/journal/35792>.

=method register

Registers the hooks.

=method plugin_init

Hook handler for the C<plugin.init> hook. Does some initializations,
surprisingly.

=method cmd_b

Hook handler for the C<db.cmd.b> hook. Checks whether the command is of the
form C<b #12> or C<b #12, 34, ...>. If so, it sets breakpoints to break as
soon as the code leading up to the given test is encountered. For example,
given C<b #12>, it breaks as soon as test 11 has been finished. If it has
handled the command, it returns the L<DB::Pluggable::Constants>
C<HANDLED>. If not, it returns C<DECLINED>.

If it handles the command, it enables the C<watchfunction()>.

=method watchfunction

Hook handler for the C<db.watchfunction> hook. Checks the current test number
from L<Test::Builder> and instructs the debugger to stop if an appropriate
test number has been reached.

