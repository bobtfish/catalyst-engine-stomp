use 5.008008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Catalyst::Engine::Stomp',
    VERSION_FROM      => 'lib/Catalyst/Engine/Stomp.pm', # finds $VERSION
    PREREQ_PM         => {
			  Catalyst::Engine::Embeddable => 0.0.1,
			  Catalyst::Runtime => 5.80003,
			  Moose => 0,
			  Net::Stomp => 0.34,
			  YAML::XS => 0.32,
			 },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Catalyst/Engine/Stomp.pm',
       AUTHOR         => 'Chris Andrews <chris@nodnol.org>') : ()),
);
