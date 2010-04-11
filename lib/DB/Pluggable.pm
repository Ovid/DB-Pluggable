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

package                 # hide from PAUSE indexer
  DB;

# switch package so as to get the desired stack trace
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
1;

=for test_synopsis
1;
__END__

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

=back

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
