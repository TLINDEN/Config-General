#
# Config::General.pm - Generic Config Module
#
# Purpose: Provide a convenient way
#          for loading config values from a
#          given file and return it as hash
#          structure
#
# Copyright (c) 2000-2001 Thomas Linden <tom@daemon.de>.
# All Rights Reserved. Std. disclaimer applies.
# Artificial License, same as perl itself. Have fun.
#
# 1.23:   - fixed bug, which removed trailing or leading " even
#           no matching " was there.
# 1.22:   - added a new option to new(): -LowerCaseNames, which
#           lowercases all option-names (feature request)
# 1.21:   - lines with just one "#" became an option array named
#           "#" with empty entries, very weird, fixed
# 1.20:   - added an if(exists... to new() for checking of the
#           existence of -AllowMultiOptions.
#         - use now "local $_" because it caused weird results
#           if a user used $_ with the module.
# 1.19:   - you can escape "#" characters using a backslash: "\#"
#           which will now no more treated as a comment.
#         - comments inside here-documents will now remain in the
#           here-doc value.

# namespace
package Config::General;

use FileHandle;
use strict;
use Carp;

$Config::General::VERSION = "1.23";

sub new {
  #
  # create new Config::General object
  #
  my($this, @param ) = @_;
  my($configfile);
  my $class = ref($this) || $this;
  my $self = {};
  bless($self,$class);

  $self->{level} = 1;

  if ($#param >= 1) {
    # use of the new hash interface!
    my %conf = @param;
    $configfile = delete $conf{-file} if(exists $conf{-file});
    $configfile = delete $conf{-hash} if(exists $conf{-hash});
    if (exists $conf{-AllowMultiOptions} ) {
      if ($conf{-AllowMultiOptions} =~ /^no$/) {
	$self->{NoMultiOptions} = 1;
      }
    }
    if (exists $conf{-LowerCaseNames}) {
      if ($conf{-LowerCaseNames}) {
	$self->{LowerCaseNames} = 1;
      }
    }
  }
  elsif ($#param == 0) {
    # use of the old style
    $configfile = $param[0];
  }
  else {
    # this happens if $#param == -1, thus no param was given to new!
    $self->{config} = {};
    return $self;
  }

  # process as usual
  if (ref($configfile) eq "HASH") {
    # initialize with given hash
    $self->{config} = $configfile;
    $self->{parsed} = 1;
  }
  else {
    # open the file and read the contents in
    $self->{configfile} = $configfile;
    $self->_open($self->{configfile});
    # now, we parse immdediately, getall simply returns the whole hash
    $self->{config} = $self->_parse({}, $self->{content});
  }

  return $self;
}



sub getall {
  #
  # just return the whole config hash
  #
  my($this) = @_;
  return (exists $this->{config} ? %{$this->{config}} : () );
}




sub _open {
  #
  # open the config file
  # and store it's contents in @content
  #
  my($this, $configfile) = @_;
  my(@content, $c_comment, $longline, $hier, $hierend, @hierdoc);
  local $_;
  my $fh = new FileHandle;

  if (-e $configfile) {
    open $fh, "<$configfile" or croak "Could not open $configfile!($!)\n";
    while (<$fh>) {
      chomp;

      # patch by "Manuel Valente" <manuel@ripe.net>:
      if (!$hierend) {
	s/(?<!\\)#.+$//;                          # Remove comments
	next if /^#/;                             # Remove lines beginning with "#"
	next if /^\s*$/;                          # Skip empty lines
	s/\\#/#/g;                                # remove the \ char in front of masked "#"
      }
      if (/^\s*(.+?)(\s*=\s*|\s+)<<(.+?)$/) {     # we are @ the beginning of a here-doc
	$hier = $1;                               # $hier is the actual here-doc
	$hierend = $3;                            # the here-doc end string, i.e. "EOF"
      }
      elsif (defined $hierend && /^(\s*)\Q$hierend\E$/) {             # the current here-doc ends here
	my $indent = $1;                          # preserve indentation
	$hier .= " " . chr(182);                  # append a "¶" to the here-doc-name, so _parse will also preserver indentation
	if ($indent) {
	  foreach (@hierdoc) {
	    s/^$indent//;                         # i.e. the end was: "    EOF" then we remove "    " from every here-doc line
	    $hier .= $_ . "\n";                   # and store it in $hier
	  }
	}
	else {
	  $hier .= join "\n", @hierdoc;           # there was no indentation of the end-string, so join it 1:1
	}
	push @{$this->{content}}, $hier;          # push it onto the content stack
	@hierdoc = ();
	undef $hier;
	undef $hierend;
      }
      elsif (/^\s*\/\*/) {                        # the beginning of a C-comment ("/*"), from now on ignore everything.
	if (/\*\/\s*$/) {                         # C-comment end is already there, so just ignore this line!
	  $c_comment = 0;
	}
	else {
	  $c_comment = 1;
	}
      }
      elsif (/\*\//) {
	if (!$c_comment) {
	  warn "invalid syntax: found end of C-comment without previous start!\n";
	}
	$c_comment = 0;                           # the current C-comment ends here, go on 
      }
      elsif (/\\$/) {                             # a multiline option, indicated by a trailing backslash
	chop;
	s/^\s*//;
	$longline .= $_ if(!$c_comment);          # store in $longline
      }
      else {                                      # any "normal" config lines
	if ($longline) {                          # previous stuff was a longline and this is the last line of the longline
	  s/^\s*//;
	  $longline .= $_ if(!$c_comment);
	  push @{$this->{content}}, $longline;    # push it onto the content stack
	  undef $longline;
	}
	elsif ($hier) {                           # we are inside a here-doc
	  push @hierdoc, $_;                      # push onto here-dco stack
	}
	else {
	  if (/^<<include (.+?)>>$/) {            # include external config file
	    $this->_open($1) if(!$c_comment);     # call _open with the argument to include assuming it is a filename
	  }
	  else {                                  # standard config line, push it onto the content stack
	    push @{$this->{content}}, $_ if(!$c_comment);
	  }
	}
      }
    }
    close $fh;
  }
  else {
    croak "The file \"$configfile\" does not exist!\n";
  }
  return 1;
}




sub _parse {
  #
  # parse the contents of the file
  #
  my($this, $config, $content) = @_;
  my(@newcontent, $block, $blockname, $grab, $chunk,$block_level);
  local $_;
  foreach (@{$content}) {                                  # loop over content stack
    chomp;
    $chunk++;
    $_ =~ s/^\s*//;                                        # strip spaces @ end and begin
    $_ =~ s/\s*$//;

    my ($option,$value) = split /\s*=\s*|\s+/, $_, 2;      # option/value assignment, = is optional
    my $indichar = chr(182);                               # ¶, inserted by _open, our here-doc indicator
    $value =~ s/^$indichar// if($value);                   # a here-doc begin, remove indicator
    if ($value && $value =~ /^"/ && $value =~ /"$/) {
      $value =~ s/^"//;                                    # remove leading and trailing "
      $value =~ s/"$//;
    }
    if (!$block) {                                         # not inside a block @ the moment
      if (/^<([^\/]+?.*?)>$/) {                            # look if it is a block
	$this->{level} += 1;
	$block = $1;                                       # store block name
	($grab, $blockname) = split /\s\s*/, $block, 2;    # is it a named block? if yes, store the name separately
	if ($blockname) {
	  $block = $grab;
	}
	$block = lc($block) if $this->{LowerCaseNames};    # only for blocks lc(), if configured via new()
	undef @newcontent;
	next;
      }
      elsif (/^<\/(.+?)>$/) {                              # it is an end block, but we don't have a matching block!
	croak "EndBlock \"<\/$1>\" has no StartBlock statement (level: $this->{level}, chunk $chunk)!\n";
      }
      else {                                               # insert key/value pair into actual node
	$option = lc($option) if $this->{LowerCaseNames};
	if ($this->{NoMultiOptions}) {                     # configurable via special method ::NoMultiOptions()
	  if (exists $config->{$option}) {
	    croak "Option $config->{$option} occurs more than once (level: $this->{level}, chunk $chunk)!\n";
	  }
	  $config->{$option} = $value;
	}
	else {
	  if (exists $config->{$option}) {	           # value exists more than once, make it an array
	    if (ref($config->{$option}) ne "ARRAY") {      # convert scalar to array
	      my $savevalue = $config->{$option};
	      delete $config->{$option};
	      push @{$config->{$option}}, $savevalue;
	    }
	    push @{$config->{$option}}, $value;            # it's still an array, just push
	  }
	  else {
	    $config->{$option} = $value;                   # standard config option, insert key/value pair into node
	  }
	}
      }
    }
    elsif (/^<([^\/]+?.*?)>$/) {                           # found a start block inside a block, don't forget it
      $block_level++;                                      # $block_level indicates wether we are still inside a node
      push @newcontent, $_;                                # push onto new content stack for later recursive call of _parse()
    }
    elsif (/^<\/(.+?)>$/) {
      if ($block_level) {                                  # this endblock is not the one we are searching for, decrement and push
	$block_level--;                                    # if it is 0, then the endblock was the one we searched for, see below
	push @newcontent, $_;                              # push onto new content stack
      }
      else {                                               # calling myself recursively, end of $block reached, $block_level is 0
	if ($blockname) {
	  $config->{$block}->{$blockname} =                # a named block, make it a hashref inside a hash within the current node
	    $this->_parse($config->{$block}->{$blockname}, \@newcontent);
	}
	else {                                             # standard block
	  $config->{$block} = $this->_parse($config->{$block}, \@newcontent);
	}
	undef $blockname;
	undef $block;
	$this->{level} -= 1;
	next;
      }
    }
    else {                                                 # inside $block, just push onto new content stack
      push @newcontent, $_;
    }
  }
  if ($block) {
    # $block is still defined, which means, that it had
    # no matching endblock!
    croak "Block \"<$block>\" has no EndBlock statement (level: $this->{level}, chunk $chunk)!\n";
  }
  return $config;
}


sub NoMultiOptions {
  #
  # turn NoMultiOptions off, still exists for backward compatibility.
  # Since we do parsing from within new(), we must
  # call it again if one turns NoMultiOptions on!
  #
  my($this) = @_;
  $this->{NoMultiOptions} = 1;
  $this->{config} = $this->_parse({}, $this->{content});
}



sub save {
  #
  # save the config back to disk
  #
  my($this,$file, %config) = @_;
  my $fh = new FileHandle;

  open $fh, ">$file" or croak "Could not open $file!($!)\n";
  $this->_store($fh, 0,%config);
}


sub _store {
  #
  # internal sub for saving a block
  #
  my($this, $fh, $level, %config) = @_;
  local $_;
  my $indent = "    " x $level;

  foreach my $entry (sort keys %config) {
    if (ref($config{$entry}) eq "ARRAY") {
      foreach my $line (@{$config{$entry}}) {
	$line =~ s/#/\\#/g;
	print $fh $indent . $entry . "   " . $line . "\n";
      }
    }
    elsif (ref($config{$entry}) eq "HASH") {
      print $fh $indent . "<" . $entry . ">\n";
      $this->_store($fh, $level + 1, %{$config{$entry}});
      print $fh $indent . "</" . $entry . ">\n";
    }
    else {
      # scalar
      if ($config{$entry} =~ /\n/) {
	# it is a here doc
	my @lines = split /\n/, $config{$entry};
	print $fh $indent . $entry . " <<EOF\n";
	foreach my $line(@lines) {
	  print $fh $indent . $line . "\n";
	}
	print $fh $indent . "EOF\n";
      }
      else {
	$config{$entry} =~ s/#/\\#/g;
	print $fh $indent . $entry . "   " . $config{$entry}  . "\n";
      }
    }
  }
}


# keep this one
1;





=head1 NAME

Config::General - Generic Config Module

=head1 SYNOPSIS

 use Config::General;
 $conf = new Config::General("rcfile");
 my %config = $conf->getall;

 # or
 $conf = new Config::General(\%somehash);

=head1 DESCRIPTION

This small module opens a config file and parses it's contents for you. The B<new> method
requires one parameter which needs to be a filename. The method B<getall> returns a hash
which contains all options and it's associated values of your config file.

The format of config files supported by B<Config::General> is inspired by the well known apache config
format, in fact, this module is 100% compatible to apache configs, but you can also just use simple
name/value pairs in your config files.

In addition to the capabilities of an apache config file it supports some enhancements such as here-documents,
C-style comments or multiline options.


=head1 METHODS

=over

=item new()

Possible ways to call B<new()>:

 $conf = new Config::General("rcfile");

 $conf = new Config::General(\%somehash);

 $conf = new Config::General(
                       -file              => "rcfile",
                       -AllowMultiOptions => "no"
                       -LowerCaseNames    => "yes"
                            );

 $conf = new Config::General(
                       -hash => \%somehash,
                            );

This method returns a B<Config::General> object (a hash blessed into "Config::General" namespace.
All further methods must be used from that returned object. see below.

You can use the new style with hash parameters or the old style which is of course
still supported. Possible parameters are:

 a filename of a configfile

 a hash reference

 or a hash with one or more of the following keys set:

    -file               - a filename.
    -hash               - a hash reference.
    -AllowMultiOptions  - if the value is "no", then multiple
                          identical options are disallowed.
    -LowerCaseNames     - if true (1 or "yes") then all options found
                          in the config will be converted to lowercase.
                          This allows you to provide case-in-sensitive configs


=item NoMultiOptions()

This method only exists for compatibility reasons.
Now you should set the new() flag B<-AllowMultiOptions>
to "no".

=over

=item The old description:
This Turns off the feature of allwing multiple options with identical names.
The default behavior is to create an array if an option occurs more than
once. But under certain circumstances you may not be willed to allow that.
In this case use this method before you call B<getall> to turn it off.

=back

Please note, that there is no method provided to turn this feature on.


=item getall()

Returns a hash structure which represents the whole config.


=item save("filename", %confighash)


Writes the config hash back to the harddisk. Please note, that any occurence
of comments will be ignored and thus be lost after you called this method.

You need also to know that named blocks will be converted to nested blocks (which is the same from
the perl point of view). An example:

 <user hans>
   id 13
 </user>

will become the following after saving:

 <user>
   <hans>
      id 13
   </hans>
 </user>
 

=back


=head1 CONFIG FILE FORMAT

Lines begining with B<#> and empty lines will be ignored. (see section COMMENTS!)
Spaces at the begining and the end of a line will also be ignored as well as tabulators.
If you need spaces at the end or the beginning of a value you can use
apostrophs B<">.
An optionline starts with it's name followed by a value. An equalsign is optional.
Some possible examples:

 user    max
 user  = max
 user            max

If there are more than one statements with the same name, it will create an array
instead of a scalar. See the example below.

The method B<getall> returns a hash of all values.


=head1 BLOCKS

You can define a B<block> of options. A B<block> looks much like a block
in the wellknown apache config format. It starts with E<lt>B<blockname>E<gt> and ends
with E<lt>/B<blockname>E<gt>. An example:

 <database>
    host   = muli
    user   = moare
    dbname = modb
    dbpass = D4r_9Iu
 </database>

Blocks can also be nested. Here is a more complicated example:

 user   = hans
 server = mc200
 db     = maxis
 passwd = D3rf$
 <jonas>
        user    = tom
        db      = unknown
        host    = mila
        <tablestructure>
                index   int(100000)
                name    char(100)
                prename char(100)
                city    char(100)
                status  int(10)
                allowed moses
                allowed ingram
                allowed joice
        </tablestructure>
 </jonas>

The hash which the method B<getall> returns look like that:

 print Data::Dumper(\%hash);
 $VAR1 = {
          'passwd' => 'D3rf$',
          'jonas'  => {
                       'tablestructure' => {
                                             'prename' => 'char(100)',
                                             'index'   => 'int(100000)',
                                             'city'    => 'char(100)',
                                             'name'    => 'char(100)',
                                             'status'  => 'int(10)',
                                             'allowed' => [
                                                            'moses',
                                                            'ingram',
                                                            'joice',
                                                          ]
                                           },
                       'host'           => 'mila',
                       'db'             => 'unknown',
                       'user'           => 'tom'
                     },
          'db'     => 'maxis',
          'server' => 'mc200',
          'user'   => 'hans'
        };

If you have turned on B<-LowerCaseNames> (see new()) then blocks as in the
following example:

 <Dir>
   <AttriBUTES>
     Owner  root
   </attributes>
 </dir>

would produce the following hash structure:

 $VAR1 = {
          'dir' => {
                    'attributes' => {
                                     'owner  => "root",
                                    }
                   }
         };

As you can see, the keys inside the config hash are normalized.

Please note, that the above config block would result in a
valid hash structure, even if B<-LowerCaseNames> is not set!
This is because I<Config::General> does not
use the blocknames to check if a block ends, instead it uses an internal
state counter, which indicates a block end.

If the module cannot find an end-block statement, then this block will be ignored.


=head1 IDENTICAL OPTIONS

You may have more than one line of the same option with different values.

Example:
 log  log1
 log  log2
 log  log2

You will get a scalar if the option occured only once or an array if it occured
more than once. If you expect multiple identical options, then you may need to 
check if an option occured more than once:

 $allowed = $hash{jonas}->{tablestructure}->{allowed};
 if(ref($allowed) eq "ARRAY") {
     @ALLOWED = @{$allowed};
 else {
     @ALLOWED = ($allowed);
 }

If you don't want to allow more than one identical options, you may turn it off
by setting the flag I<AllowMutliOptions> in the B<new()> method to "no".
If turned off, Config::General will complain about multiple occuring options
whit identical names!


=head1 NAMED BLOCKS

If you need multiple blocks of the same name, then you have to name every block.
This works much like apache config. If the module finds a named block, it will
create a hashref with the left part of the named block as the key containing
one or more hashrefs with the right part of the block as key containing everything
inside the block(which may again be nested!). As examples says more than words:

 # given the following sample
 <Directory /usr/frisco>
        Limit Deny
        Options ExecCgi Index
 </Directory>
 <Directory /usr/frik>
        Limit DenyAll
        Options None
 </Directory>

 # you will get:
 $VAR1 = {
          'Directory' => {
                           '/usr/frik' => {
                                            'Options' => 'None',
                                            'Limit' => 'DenyAll'
                                          },
                           '/usr/frisco' => {
                                              'Options' => 'ExecCgi Index',
                                              'Limit' => 'Deny'
                                            }
                         }
        };

You cannot have more than one named block with the same name because it will
be stored in a hashref and therefore be overwritten if a block occurs once more.


=head1 LONG LINES

If you have a config value, which is too long and would take more than one line,
you can break it into multiple lines by using the backslash character at the end
of the line. The Config::General module will concatenate those lines to one single-value.

Example:

command = cat /var/log/secure/tripwire | \
           mail C<-s> "report from tripwire" \
           honey@myotherhost.nl

command will become:
 "cat /var/log/secure/tripwire | mail C<-s> 'report from twire' honey@myotherhost.nl"


=head1 HERE DOCUMENTS

You can also define a config value as a so called "here-document". You must tell
the module an identifier which identicates the end of a here document. An
identifier must follow a "<<".

Example:

 message <<EOF
   we want to
   remove the
   homedir of
   root.
 EOF

Everything between the two "EOF" strings will be in the option I<message>.

There is a special feature which allows you to use indentation with here documents.
You can have any amount of whitespaces or tabulators in front of the end
identifier. If the module finds spaces or tabs then it will remove exactly those
amount of spaces from every line inside the here-document.

Example:

 message <<EOF
         we want to
         remove the
         homedir of
         root.
      EOF

After parsing, message will become:

   we want to
   remove the
   homedir of
   root.

because there were the string "     " in front of EOF, which were cutted from every
line inside the here-document.



=head1 INCLUDES

You can include an external file at any posision in you config file using the following statement
in your config file:

 <<include externalconfig.rc>>

This file will be inserted at the position where it was found as if the contents of this file
were directly at this position.

You can also recurively include files, so an included file may include another one and so on.
Beware that you do not recursively load the same file, you will end with an errormessage like
"too many files in system!".

Include statements will be ignored within C-Comments and here-documents.



=head1 COMMENTS

A comment starts with the number sign B<#>, there can be any number of spaces and/or
tabstops in front of the #.

A comment can also occur after a config statement. Example:

 username = max  # this is the comment

If you want to comment out a large block you can use C-style comments. A B</*> signals
the begin of a comment block and the B<*/> signals the end of the comment block.
Example:

 user  = max # valid option
 db    = tothemax
 /*
 user  = andors
 db    = toand
 */

In this example the second options of user and db will be ignored. Please beware of the fact,
if the Module finds a B</*> string which is the start of a comment block, but no matching
end block, it will ignore the whole rest of the config file!

B<NOTE:> If you require the B<#> character (number sign) to remain in the option value, then
you can use a backlsash in front of it, to escape it. Example:

 bgcolor = \#ffffcc

In this example the value of $config{bgcolor} will be "#ffffcc", Config::General will not treat
the number sign as the begin of a comment because of the leading backslash.

Inside here-documents escaping of number signs is NOT required! 


=head1 COPYRIGHT

Copyright (c) 2000-2001 Thomas Linden

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.


=head1 BUGS

none known yet.


=head1 AUTHOR

Thomas Linden <tom@daemon.de>


=head1 VERSION

1.22

=cut

