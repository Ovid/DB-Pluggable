use 5.008;
use strict;
use warnings;

package DB::Pluggable::Plugin;
# ABSTRACT: Base classes for DB::Pluggable plugins
use parent 'Hook::Modular::Plugin';

sub make_command {
    my ($self, $cmd_name, $code) = @_;
    no strict 'refs';
    my $sub_name = "DB::cmd_$cmd_name";
    *{$sub_name} = $code;
    $DB::alias{$cmd_name} = "/./; &$sub_name;";
}

=head1 SYNOPSIS

    package DB::Pluggable::MyCommand;
    use strict;
    use warnings;
    use base 'DB::Pluggable::Plugin';

    sub register {
        my ($self, $context) = @_;
        $self->make_command(
            Th => sub {
                # ...
            }
        );
    }

=head1 DESCRIPTION

This is a base class for plugins for L<DB::Pluggable>. Plugins should inherit
from it, so if we later add some basic functionality to this class, we don't
have to rewrite the plugins.

=method make_command

Takes a command name string and a code reference and makes a new debugger
command. It abuses the debugger's alias mechanism to do so.

