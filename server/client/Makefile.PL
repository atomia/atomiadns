use ExtUtils::MakeMaker;
WriteMakefile(
   'NAME' => 'atomiadnsclient',
   'VERSION' => '1.1.55',
   'AUTHOR' => 'Jimmy Bergman <jimmy@atomia.com>',
   'EXE_FILES' => [ 'atomiadnsclient', 'dnssec_zsk_rollover' ]
);
