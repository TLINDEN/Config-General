#
# Makefile.PL - build file for Config::General
#
# Copyright (c) 2000-2005 Thomas Linden <tom@daemon.de>.
# All Rights Reserved. Std. disclaimer applies.
# Artificial License, same as perl itself. Have fun.
#

use ExtUtils::MakeMaker;


WriteMakefile(
	      'NAME'	=> 'Config::General',
	      'VERSION_FROM' => 'General.pm', # finds $VERSION
	      'clean' => { FILES => 't/cfg.out t/test.cfg *~ */*~' },
);
