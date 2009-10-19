#
# Pathobject fake module to test Config::General
# without the need to install Path::Class::File module.
#
# Submitted by Matt S Trout, Copyright (c) 2009 Matt S Trout.


package PathObject;

use overload ('""' => 'stringify');

sub new {
       my $class = shift;
       my $self = {};
       bless $self, $class;
       return $self;
}

sub stringify {
       my ($self) = @_;
       return "t/test.rc";
}

1;
