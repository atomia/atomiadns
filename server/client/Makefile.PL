use ExtUtils::MakeMaker;
WriteMakefile(
   'NAME' => 'atomiadnsclient',
   'VERSION' => '1.0.26',
   'AUTHOR' => 'Jimmy Bergman <jimmy@atomia.com>',
   'EXE_FILES' => [ 'atomiadnsclient', 'dnssec_zsk_rollover' ]
);
