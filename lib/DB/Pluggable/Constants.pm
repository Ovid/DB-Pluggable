package DB::Pluggable::Constants;

use strict;
use warnings;


our $VERSION = '0.03';


use base 'Exporter';


our %EXPORT_TAGS = (
    util  => [ qw(HANDLED DECLINED) ],
);


our @EXPORT_OK = @{ $EXPORT_TAGS{all} = [ map { @$_ } values %EXPORT_TAGS ] };


use constant HANDLED  => '200';
use constant DECLINED => '500';


1;


__END__

{% USE p = PodGenerated %}

=head1 NAME

{% p.package %} - Constants for debugger plugin hook methods

=head1 SYNOPSIS

    package DB::Pluggable::MyUsefulCommand;

    use DB::Pluggable::Constants ':all';

    sub do_it {
        my ($self, $context, $args) = @_;
        ...
        if (...) {
            ...
            return HANDLED;
        } else {
            return DECLINED;
        }
    }

=head1 DESCRIPTION

This module defines constants that should be used by hooks as return values.
The following constants are defined:

=over 4

=item HANDLED

This constant should be returned by a command-related hook method to indicate
that it has handled the debugger command.

=item DECLINED

This constant should be returned by a command-related hook method to indicate
that it has not handled the debugger command.

=back

L<DB::Pluggable>'s plugin-enabled replacements for the debugger commands use
these constants to determine whether a command has been handled by one of the
plugins or whether it should be passed on to the default command handler
defined in C<perl5db.pl>.

{% PROCESS standard_pod %}

=cut

