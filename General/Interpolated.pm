package Config::General::Interpolated;
$Config::General::Interpolated::VERSION = "1.1";

use strict;
use Carp;
use Config::General;
use Exporter ();


# Import stuff from Config::General
use vars qw(@ISA @EXPORT);
@ISA = qw(Config::General Exporter);
@EXPORT=qw(_set_regex _vars);

sub new {
  #
  # overwrite new() with our own version
  # and call the parent class new()
  #
  my $class = shift;
  my $self  = $class->SUPER::new(@_);

  $self->{regex}  = $self->_set_regex();

  $self->{config} = $self->_vars($self->{config}, {});

  return $self;
}



sub _set_regex {
  #
  # set the regex for finding vars
  #

  # the following regex is provided by Autrijus Tang
  # <autrijus@autrijus.org>, and I made some modifications.
  # thanx, autrijus. :)
  my $regex = qr{
	               (^|[^\\])	# can be the beginning of the line
	                                # but can't begin with a '\'
	               \$		# dollar sign
	               (\{)?		# $1: optional opening curly
	               ([a-zA-Z_]\w*)	# $2: capturing variable name
	               (
	               ?(2)		# $3: if there's the opening curly...
	               \}		#     ... match closing curly
	              )
	             }x;
  return $regex;
}



sub _vars {
    my ($this, $config, $stack) = @_;
    my %varstack;

    $stack = {} unless defined $stack;	# make sure $stack is assigned.

    # collect values that don't need to be substituted first
    while (my ($key, $value) = each %{$config}) {
	$varstack{$key} = $value
	    unless ref($value) or $value =~ $this->{regex};
    }

    my $sub_interpolate = sub {
      my ($value) = @_;

      # this is a scalar
      if ($value =~ m/^'/ and $value =~ m/'$/) {
	# single-quote, remove it and don't do variable interpolation
	$value =~ s/^'//;   $value =~ s/'$//;
      }
      else {
	$value =~ s{$this->{regex}}{
	  my $v = $varstack{$3} || $stack->{$3};
	  $v = '' if ref($v);
	  $1 . $v;
	}egx;
      }

      return $value;
    };

    # interpolate variables
    while (my ($key, $value) = each %{$config}) {
      if (my $reftype = ref($value)) {
	next unless $reftype eq 'ARRAY';

	# we encounter multiple options
	@{$value} = map { $sub_interpolate->($_) } @{$value};
      }
      else {
	$value = $sub_interpolate->($value);
	$config->{$key} = $value;
	$varstack{$key} = $value;
      }
    }

    # traverse the hierarchy part
    while (my ($key, $value) = each %{$config}) {
      # this is not a scalar recursive call to myself
      _vars($value, {%{$stack}, %varstack})
	if ref($value) eq 'HASH';
    }

    return $config;
}

1;

__END__


=head1 NAME

Config::General::Interpolated - Parse variables within Config files


=head1 SYNOPSIS

 use Config::General;
 $conf = new Config::General(
    -file            => 'configfile',
    -InterPolateVars => 1
 );

=head1 DESCRIPTION

This is an internal module which makes it possible to interpolate
perl style variables in your config file (i.e. C<$variable>
or C<${variable}>).

Normally you don't call it directly.


=head1 VARIABLES

Variables can be defined everywhere in the config and can be used
afterwards. If you define a variable inside a block or a named block
then it is only visible within this block or within blocks which
are defined inside this block. Well - let's take a look to an example:

 # sample config which uses variables
 basedir   = /opt/ora
 user      = t_space
 sys       = unix
 <table intern>
     instance  = INTERN
     owner     = $user                 # "t_space"
     logdir    = $basedir/log          # "/opt/ora/log"
     sys       = macos
     <procs>
         misc1   = ${sys}_${instance}  # macos_INTERN
         misc2   = $user               # "t_space"
     </procs>
 </table>

This will result in the following structure:

 {
     'basedir' => '/opt/ora',
     'user'    => 't_space'
     'sys'     => 'unix',
     'table'   => {
	  'intern' => {
	        'sys'      => 'macos',
	        'logdir'   => '/opt/ora/log',
	        'instance' => 'INTERN',
	        'owner' => 't_space',
	        'procs' => {
		     'misc1' => 'macos_INTERN',
		     'misc2' => 't_space'
            }
	 }
     }

As you can see, the variable B<sys> has been defined twice. Inside
the <procs> block a variable ${sys} has been used, which then were
interpolated into the value of B<sys> defined inside the <table>
block, not the sys variable one level above. If sys were not defined
inside the <table> block then the "global" variable B<sys> would have
been used instead with the value of "unix".

Variables inside double quotes will be interpolated, but variables
inside single quotes will B<not> interpolated. This is the same
behavior as you know of perl itself.

In addition you can surround variable names with curly braces to
avoid misinterpretation by the parser.

=head1 SEE ALSO

L<Config::General>

=head1 AUTHORS

 Thomas Linden <tom@daemon.de>
 Autrijus Tang <autrijus@autrijus.org>
 Wei-Hon Chen <plasmaball@pchome.com.tw>

=head1 COPYRIGHT

Copyright 2001 by Wei-Hon Chen E<lt>plasmaball@pchome.com.twE<gt>.
Copyright 2002 by Thomas Linden <tom@daemon.de>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=head1 VERSION

This document describes version 1.1 of B<Config::General::Interpolated>.

=cut

