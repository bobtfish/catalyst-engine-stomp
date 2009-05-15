use inc::Module::Install;
use 5.008006;
  
name     'Catalyst-Engine-Stomp';
all_from 'lib/Catalyst/Engine/Stomp.pm';
  
requires 'Catalyst::Engine::Embeddable'  => '0.0.1';
requires 'Catalyst::Action::REST' => undef;
requires 'Catalyst::Runtime'  => '5.80003';
requires 'Moose' => undef;
requires 'MooseX::Workers' => '0.05';
requires 'Net::Stomp' => '0.34';  
requires 'YAML::XS' => '0.32';
requires 'namespace::autoclean' => '0.05';

auto_install;
WriteAll;

