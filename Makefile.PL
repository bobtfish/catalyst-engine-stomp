use 5.008008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Catalyst::Engine::Stomp',
    VERSION_FROM      => 'lib/Catalyst/Engine/Stomp.pm', # finds $VERSION
    PREREQ_PM         => {
			  Catalyst::Engine::Embeddable => 0.0.1,
			  Moose => 0,
			  Net::Stomp => 0.34,
			  YAML::XS => 0.32,
			 }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Catalyst/Engine/Stomp.pm', # retrieve abstract from module
       AUTHOR         => 'Chris Andrews <chris@nodnol.org>') : ()),
    LIBS              => [''], # e.g., '-lm'
    DEFINE            => '', # e.g., '-DHAVE_SOMETHING'
    INC               => '-I.', # e.g., '-I. -I/usr/include/other'
);
