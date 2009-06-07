package StompRole;
use Moose::Role;
use namespace::autoclean;

after 'disconnect' => sub {
    delete shift->{___activemq};
};

package TestServer;
use strict;
use warnings;
use Alien::ActiveMQ;
use Test::More;
use Exporter qw/import/;
use FindBin;

our $ACTIVEMQ_VERSION = '5.2.0';

our @EXPORT = qw/ start_server /;

sub start_server {
    my ($mq, $stomp);
    eval {
        $stomp = Net::Stomp->new( { hostname => 'localhost', port => 61613 } );
    };
    if ($@) {

        unless (Alien::ActiveMQ->is_version_installed($ACTIVEMQ_VERSION)) {
            plan 'skip_all' => 'No ActiveMQ server installed by Alien::ActiveMQ, try running the "install-activemq" command';
            exit;
        }

        $mq = Alien::ActiveMQ->run_server($ACTIVEMQ_VERSION);

        eval {
            $stomp = Net::Stomp->new( { hostname => 'localhost', port => 61613 } );
        };
        if ($@) {
            plan 'skip_all' => 'No ActiveMQ server listening on 61613: ' . $@;
            exit;
        }
    }

    $SIG{CHLD} = 'IGNORE';
    unless (fork()) {
	    system("$^X -I$FindBin::Bin/lib $FindBin::Bin/script/stomptestapp_stomp.pl --oneshot");
	    exit 0;
    }
    print STDERR "server started, waiting for spinup...";
    sleep 20;

    $stomp->{___activemq} = $mq if $mq;
    StompRole->meta->apply($stomp);
    return $stomp;
}

