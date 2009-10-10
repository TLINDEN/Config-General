# -*-perl-*-
# testscript for Config::General Classes by Thomas Linden
#
# needs to be invoked using the command "make test" from
# the Config::General source directory.
#
# Under normal circumstances every test should succeed.

BEGIN { $| = 1; print "1..22\n";}
use lib "blib/lib";
use Config::General;
use Data::Dumper;

sub pause;

print "ok\n";
print STDERR " .. ok # loading Config::General\n";


foreach (2..7) {
  &p("t/cfg." . $_, $_);
  pause;
}

my $conf = new Config::General("t/cfg.8");
my %hash = $conf->getall;
$conf->save_file("t/cfg.out");

my $copy = new Config::General("t/cfg.out");
my %copyhash = $copy->getall;

my $a = \%hash;
my $b = \%copyhash;

# now see if the saved hash is still the same as the
# one we got from cfg.8
if (&comp($a,$b)) {
  print "ok\n";
  print STDERR " ... ok # Writing Config Hash to disk and compare with original\n";
}
else {
  print "8 not ok\n";
  print STDERR "8 ... not ok\n";
}
pause;

############## Extended Tests #################

$conf = new Config::General(
			    -ExtendedAccess => 1,
			    -ConfigFile     => "t/test.rc");
print "ok\n";
print STDERR " ... ok # Creating a new object from config file\n";
pause;



# now test the new notation of new()
my $conf2 = new Config::General(
				-ExtendedAccess    => 1,
				-ConfigFile        => "t/test.rc",
				-AllowMultiOptions => "yes"
			       );
print "ok\n";
print STDERR " ... ok # Creating a new object using the hash parameter way\n";
pause;



my $domain = $conf->obj("domain");
print "ok\n";
print STDERR " .. ok # Creating a new object from a block\n";
pause;



my $addr = $domain->obj("bar.de");
print "ok\n";
print STDERR " .. ok # Creating a new object from a sub block\n";
pause;



my @keys = $conf->keys("domain");
print "ok\n";
print STDERR " .. ok # Getting values from the object\n";
pause;




# test various OO methods
if ($conf->is_hash("domain")) {
  my $domains = $conf->obj("domain");
  foreach my $domain ($conf->keys("domain")) {
    my $domain_obj = $domains->obj($domain);
    foreach my $address ($domains->keys($domain)) {
      my $blah = $domain_obj->value($address);
    }
  }
}
print "ok\n";
print STDERR " .. ok # Using keys() and values() \n";
pause;



# test AUTOLOAD methods
my $conf3 = new Config::General(
				-ExtendedAccess => 1,
				-ConfigHash     => { name => "Moser", prename => "Hannes"}
				);
my $n = $conf3->name;
my $p = $conf3->prename;
$conf3->name("Meier");
$conf3->prename("Max");
$conf3->save_file("t/test.cfg");

print "ok\n";
print STDERR " .. ok # Using AUTOLOAD methods\n";
pause;



# testing variable interpolation
my $conf16 = new Config::General(-ConfigFile => "t/cfg.16", -InterPolateVars => 1, -StrictVars => 0);
my %h16 = $conf16->getall();
if($h16{etc}->{log} eq "/usr/local/log/logfile") {
   print "ok\n";
   print STDERR " .. ok # Testing variable interpolation\n";
}
else {
   print "16 not ok\n";
   print STDERR "16 not ok\n";
}
pause;


# testing value pre-setting using a hash
my $conf17 = new Config::General(
				 -file => "t/cfg.17",
				 -DefaultConfig => { home => "/exports/home", logs => "/var/backlog" },
				 -MergeDuplicateOptions => 1,
				 -MergeDuplicateBlocks => 1
				 );
my %h17 = $conf17->getall();
if ($h17{home} eq "/home/users") {
  print "ok\n";
  print STDERR " .. ok # Testing value pre-setting using a hash\n";
}
else {
  print "17 not ok\n";
  print STDERR "17 not ok\n";
}
pause;


# testing value pre-setting using a string
my $conf18 = new Config::General(
				 -file => "t/cfg.17", # reuse the file
				 -DefaultConfig => "home = /exports/home\nlogs = /var/backlog",
				 -MergeDuplicateOptions => 1,
				 -MergeDuplicateBlocks => 1
				 );
my %h18 = $conf18->getall();
if ($h18{home} eq "/home/users") {
  print "ok\n";
  print STDERR " .. ok # Testing value pre-setting using a string\n";
}
else {
  print "18 not ok\n";
  print STDERR "18 not ok\n";
}
pause;


# testing various otion/value assignment notations
my $conf19 = new Config::General(-file => "t/cfg.19");
my %h19 = $conf19->getall();
my $works = 1;
foreach my $key (keys %h19) {
  if ($key =~ /\s/) {
    $works = 0;
  }
}
if ($works) {
  print "ok\n";
  print STDERR " .. ok # Testing various otion/value assignment notations\n";
}
else {
  print "19 not ok\n";
  print STDERR "19 not ok\n";
}
pause;


# testing files() method
my $conf20 = Config::General->new(
    -file => "t/cfg.20.a",
    -MergeDuplicateOptions => 1
);
my %h20 = $conf20->getall();

my %expected_h20 = (
    'seen_cfg.20.a' => 'true',
    'seen_cfg.20.b' => 'true',
    'seen_cfg.20.c' => 'true',
    'last'          => 'cfg.20.c',
);

my %files = map { $_ => 1 } $conf20->files();

my %expected_files = map { $_ => 1 } (
    't/cfg.20.a',
    't/cfg.20.b',
    't/cfg.20.c',
);

if (&comp(\%h20, \%expected_h20) and &comp(\%files, \%expected_files)) {
  print "ok\n";
  print STDERR " .. ok # testing files() method\n";
}
else {
  print "20 not ok\n";
  print STDERR "20 not ok\n";
}
pause;

# testing improved IncludeRelative option

# First try without -IncludeRelative
# this should fail
eval {
    my $conf21 = Config::General->new(
        -file => "t/sub1/sub2/sub3/cfg.sub3",
        -MergeDuplicateOptions => 1,
    );
};
if ($@) {
  print "ok\n";
  print STDERR " .. ok # prevented from loading relative cfgs without -IncludeRelative\n";
}
else {
  print "21 not ok\n";
  print STDERR "21 not ok\n";
}
pause;

# Now try with -IncludeRelative
# this should fail

my $conf22 = Config::General->new(
    -file => "t/sub1/sub2/sub3/cfg.sub3",
    -MergeDuplicateOptions => 1,
    -IncludeRelative       => 1,
);

my %h22 = $conf22->getall;
my %expected_h22 = (
    'sub3_seen' => 'yup',
    'sub2_seen' => 'yup',
    'sub1_seen' => 'yup',
    'fruit'     => 'mango',
);

if (&comp(\%h22, \%expected_h22)) {
  print "ok\n";
  print STDERR " .. ok # loaded relative to included files\n";
}
else {
  print "22 not ok\n";
  print STDERR "22 not ok\n";
}
pause;




# all subs here

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
  print STDERR " ... ok $fst\n";
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

sub pause {
  # we are pausing between tests
  # so the output gets not confused
  # by stderr/stdout "collisions"
  select undef, undef, undef, 0.3;
}
