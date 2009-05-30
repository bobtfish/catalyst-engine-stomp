use inc::Module::Install;
use 5.008006;
  
license  'perl';

name     'Catalyst-Engine-Stomp';
all_from 'lib/Catalyst/Engine/Stomp.pm';
  
requires 'Catalyst::Engine::Embeddable'  => '0.0.1';
requires 'Catalyst::Runtime'  => '5.80004';
requires 'Moose' => undef;
requires 'MooseX::Workers' => '0.05';
requires 'Net::Stomp' => '0.34';  
requires 'YAML::XS' => '0.32';
requires 'Data::Serializer' => '0.49';
requires 'namespace::autoclean' => '0.05';

test_requires 'Alien::ActiveMQ' => '0.00003';

no_index package => 'StompTestApp';
no_index package => 'StompTestApp::Controller::TestController';
no_index package => 'StompTestApp::Controller::TestJsonController';

auto_install;
WriteAll;

