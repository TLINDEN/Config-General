#
# testscript for Conf.pm by Thomas Linden
# needs to be invoked using the command "make test" from
# the Conf.pm source directory.
# Under normal circumstances every test should run.

BEGIN { $| = 1; print "1..7\n";}
use lib "blib/lib";
use Config::General;
print "ok\n";
print STDERR "\n1 .. ok # loading Config::General\n";

foreach (2..6) {
  &p("t/cfg." . $_, $_);
}

my $conf = new Config::General("t/cfg.7");
my %hash = $conf->getall;
$conf->save("t/cfg.out", %hash);

my $copy = new Config::General("t/cfg.out");
my %copyhash = $copy->getall;

my $a = \%hash;
my $b = \%copyhash;

# now see if the saved hash is still the same as the
# one we got from cfg.7
if (&comp($a,$b)) {
  print "ok\n";
  print STDERR "7 .. ok # Writing Config Hash to disk and compare with original\n";
}
else {
  print "7 not ok\n";
  print STDERR "7 .. not ok\n";
}


sub p {
  my($cfg, $t) = @_;
  open T, "<$cfg";
  my @file = <T>;
  close T;
  @file = map { chomp($_); $_} @file;
  my $fst = $file[0];
  my $conf = new Config::General($cfg);
  my %hash = $conf->getall;
  print "ok\n";
  print STDERR "$t .. ok $fst\n";
}

sub comp {
  my($a, $b) = @_;
  foreach my $key (keys %{$a}) {
    if(ref($a->{$key}) eq "HASH") {
       &comp($a->{$key},$b->{$key});
       next;
    }
    elsif(ref($a->{$key}) eq "ARRAY") {
       # ignore arrays for simplicity
       next;
    }
    return 0 if($a->{$key} ne $b->{$key});
  }
  return 1;
}
