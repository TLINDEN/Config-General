use ExtUtils::MakeMaker;


WriteMakefile(
	      'NAME'	=> 'Config::General',
	      'VERSION_FROM' => 'General.pm', # finds $VERSION
	      'clean' => { FILES => 't/cfg.out t/test.cfg *~ t/~' },
);
