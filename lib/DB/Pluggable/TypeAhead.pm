use 5.008;
use strict;
use warnings;

package DB::Pluggable::TypeAhead;
# ABSTRACT: Debugger plugin to add type-ahead
use DB::Pluggable::Constants ':all';
use base 'Hook::Modular::Plugin';

sub register {
    my ($self, $context) = @_;
    $context->register_hook($self, 'db.afterinit' => $self->can('afterinit'),);
}

sub afterinit {
    my $self = shift;
    my $type = $self->conf->{type};
    die "TypeAhead: need 'type' config key\n" unless defined $type;
    die "TypeAhead: 'type' must be an array reference of things to type\n"
      unless ref $type eq 'ARRAY';
    
    if (my $env_key = $self->conf->{ifenv}) {
        return unless $ENV{$env_key};
    }
    no warnings 'once';
    push @DB::typeahead, @$type;
}
1;

=begin :prelude

=for stopwords typeahead afterinit

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
      - module: TypeAhead
        config:
            type: 
                - '{l'
                - 'c'
        ifenv: DBTYPEAHEAD
    EOYAML

    $DB::PluginHandler->run;

=head1 DESCRIPTION

If you use the debugger a lot, you might find that you enter the same commands
after starting the debugger. For example, suppose that you usually want to
list the next window of lines before the debugger prompt - so you would enter
C<{l> - and that you usually have a breakpoint when running the debugger - so
you would enter C<c>. So you could use a plugin configuration as shown in
the synopsis.

If you want to control whether this typeahead is applied, you can use the
optional C<ifenv> configuration key. If specified, its value is taken to be
the name of an environment variable. When the plugin runs, the typeahead will
only be applied if that environment variable has a true value.

So to continue the example from the synopsis, if you wanted to enable the
typeahead, you would run your program like this:

    DBTYPEAHEAD=1 perl -d ...

The inspiration for this plugin came from Ovid's blog post at
L<http://blogs.perl.org/users/ovid/2010/02/easier-test-debugging.html>.

=method register

Registers the hooks.

=method afterinit

Hook handler for the C<db.afterinit> hook.
