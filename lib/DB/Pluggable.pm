use 5.008;
use strict;
use warnings;

package DB::Pluggable;

# ABSTRACT: Add plugin support for the Perl debugger
use DB::Pluggable::Constants ':all';
use Hook::LexWrap;
use parent 'Hook::Modular';
use constant PLUGIN_NAMESPACE => 'DB::Pluggable';

sub enable_watchfunction {
    my $self = shift;
    no warnings 'once';
    $DB::trace |= 4;    # Enable watchfunction
}

sub run {
    my $self = shift;
    $self->run_hook('plugin.init');
    our $cmd_b_wrapper = wrap 'DB::cmd_b', pre => sub {
        my ($cmd, $line, $dbline) = @_;
        my @result = $self->run_hook(
            'db.cmd.b',
            {   cmd    => $cmd,
                line   => $line,
                dbline => $dbline,
            }
        );

        # short-circuit (i.e., don't call the original debugger function)
        # if a plugin has handled it
        $_[-1] = 1 if grep { $_ eq HANDLED } @result;
    };
}
1;

# switch package so as to get the desired stack trace
package    # hide from PAUSE indexer
  DB;
use DB::Pluggable::Constants ':all';

sub watchfunction {
    return unless defined $DB::PluginHandler;
    my $depth = 1;
    while (1) {
        my ($package, $file, $line, $sub) = caller $depth;
        last unless defined $package;
        return if $sub =~ /::DESTROY$/;
        $depth++;
    }
    $DB::PluginHandler->run_hook('db.watchfunction');
}

sub afterinit {
    return unless defined $DB::PluginHandler;
    $DB::PluginHandler->run_hook('db.afterinit');
}
no warnings 'redefine';
my $eval = \&DB::eval;
*eval = sub {
    my @result = $DB::PluginHandler->run_hook('db.eval', { eval => $eval });
    return if grep { $_ eq HANDLED } @result;
    $eval->();
};
1;

=for test_synopsis
1;
__END__

=head1 SYNOPSIS

    $ cat ~/.perldb

    use DB::Pluggable;
    use Hook::Modular::Builder;
    my $config = builder {
        log_level 'error';
        enable 'BreakOnTestNumber';
        enable 'StackTraceAsHTML';
        enable 'TypeAhead', type => [ '{l', 'c' ] if $ENV{DBTYPEAHEAD};
        enable 'Dumper';
    };

    $DB::PluginHandler = DB::Pluggable->new(config => $config);
    $DB::PluginHandler->run;

Alternatively, build the configuration yourself, for example, using L<YAML>:

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

Then:

    $ perl -d foo.pl

=head1 DESCRIPTION

This class adds plugin support to the Perl debugger. It is based on
L<Hook::Modular>, so see its documentation for details.

You need to have a C<~/.perldb> file (see L<perldebug> for details) that
invokes the plugin mechanism. The one in the synopsis will do, and there is a
more commented one in this distribution's C<etc/perldb> file.

Plugins should live in the C<DB::Pluggable::> namespace, like
L<DB::Pluggable::BreakOnTestNumber> does.

=head1 HOOKS

This class is very much in beta, so it's more like a proof of concept.
Therefore, not all hooks imaginable have been added, only the ones to make
this demo work. If you want more hooks or if the current hooks don't work for
you, let me know.

The following hooks exist:

=over 4

=item C<plugin.init>

Called at the beginning of the C<run()> method. The hook doesn't get any
arguments.

=item C<db.watchfunction>

Called from within C<DB::watchfunction()>. If you want the debugger to call
the function, you need to enable it by calling C<enable_watchfunction()>
somewhere within your plugin. It's a good idea to enable it as late as
possible because it is being called very often. See the
L<DB::Pluggable::BreakOnTestNumber> source code for an example. The hook
doesn't get any arguments.

=item C<db.cmd.b>

Called when the C<b> debugger command (used to set breakpoints) is invoked.
See C<run()> below for what the hook should return.

The hook passes these named arguments:

=over 4

=item C<cmd>

This is the first argument passed to C<DB::cmd_b()>.

=item C<line>

This is the second argument passed to C<DB::cmd_b()>. This is the most
important argument as it contains the command line. See the
L<DB::Pluggable::BreakOnTestNumber> source code for an example.

=item C<dbline>

This is the third argument passed to C<DB::cmd_b()>.

=back

=item C<db.eval>

The debugger's C<eval()> function is overridden so we can hook into it. This
is needed to define new debugger commands that take arguments. Each plugin
that registered this hook will get a chance to inspect the command line, which
is the last line in C<$DB::evalarg> and act on it. Each hook gets passed a
code reference in the original C<DB::eval()> function. If a plugin decides the
handle the command, it needs to call the original function and return
C<HANDLED> - see L<DB::Pluggable::Constants> - to indicate that it has done
so. If a plugin does not want to handle the command, it must return
C<DECLINED>.

The hook passes these named arguments:

=over 4

=item C<eval>

The code reference to the original C<DB::eval()> function.

=back

=back

For example, if you wanted to define a new C<xx> debugger command, you could
use:

    sub register {
        my ($self, $context) = @_;
        $context->register_hook(
            $self,
            'db.eval' => $self->can('eval'),
        );
    }

    sub eval {
        my ($self, $context, $args) = @_;
        return DECLINED unless $DB::evalarg =~ s/\n\s*xx\s+([^\n]+)$/\n $1/;
        ... # handle the actual command
        $args->{eval}->();
        HANDLED;
    }

=method enable_watchfunction

Tells the debugger to call C<DB::watchfunction()>, which in turn calls the
C<db.watchfunction> hook on all plugins that have registered it.

=method run

First it calls the C<plugin.init> hook, then it enables hooks for the relevant
debugger commands (see above for which hooks are available).

Each command-related hook should return the appropriate constant from
L<DB::Pluggable::Constants> - either C<HANDLED> if the hook has handled the
command, or C<DECLINED> if it didn't. If no hook has C<HANDLED> the command,
the default command subroutine (e.g., C<DB::cmd_b()>) from C<perl5db.pl>
will be called.
