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

my @force_build_requires_if_author = qw(
  Test::NoTabs
  Test::Pod
  Test::Pod::Coverage
  Pod::Coverage
);

if ($Module::Install::AUTHOR) {
    foreach my $module (@force_build_requires_if_author) {
        build_requires $module;
    }
    darwin_check_no_resource_forks();
}

install_script glob('script/*.pl');
auto_install;
WriteAll;

if ($Module::Install::AUTHOR) {

  # Strip out the author only build_requires from META.yml
  # Need to do this _after_ WriteAll else it looses track of them
  strip_author_only_build_requires(@force_build_requires_if_author);

  Meta->{values}{resources} = [
    [ 'license',    => 'http://dev.perl.org/licenses/' ],
    [ 'repository', => 'git://github.com/chrisa/catalyst-engine-stomp.git' ],
  ];

  Meta->write;
}

sub darwin_check_no_resource_forks {
    if ($^O eq 'darwin') {
        my $osx_ver = `/usr/bin/sw_vers -productVersion`;
        chomp $osx_ver;

        # TAR on 10.4 wants COPY_EXTENDED_ATTRIBUTES_DISABLE
        # On 10.5 (Leopard) it wants COPYFILE_DISABLE
        my $attr = $osx_ver eq '10.5' ? 'COPYFILE_DISABLE' : 'COPY_EXTENDED_ATTRIBUTES_DISABLE';

        makemaker_args(dist => { PREOP => qq{\@if [ "\$\$$attr" != "true" ]; then}.
                                          qq{ echo "You must set the ENV variable $attr to true,"; }.
                                          ' echo "to avoid getting resource forks in your dist."; exit 255; fi' });
        }
}

sub strip_author_only_build_requires {
    my @build_requires_to_strip = @_;
    Meta->{values}{build_requires} = [ grep {
      my $ok = 1;
      foreach my $module (@build_requires_to_strip) {
        if ($_->[0] =~ /$module/) {
          $ok = 0;
          last;
        }
      }
      $ok;
    } @{Meta->{values}{build_requires}} ];
}

