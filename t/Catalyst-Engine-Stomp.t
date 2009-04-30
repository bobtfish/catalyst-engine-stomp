use Test::More tests => 14;
use Test::Fork;

# Tests which expect a STOMP server like ActiveMQ to exist on
# localhost:61613, which is what you get if you just get the ActiveMQ
# distro and run its out-of-the-box config.

use Net::Stomp;
use YAML::XS qw/ Dump Load /;
use Data::Dumper;

# First fire off the server
my $child_pid = fork_ok(1, sub {
  ok(system("$^X -Ilib -Itestapp/lib testapp/script/testapp_stomp.pl --oneshot"));
  #sleep 3;
});

# Now be a client to that server

my $stomp = Net::Stomp->new( { hostname => 'localhost', port => 61613 } );
ok($stomp, 'Net::Stomp object');

my $frame = $stomp->connect();
ok($frame, 'connect to MQ server ok');

my $reply_to = sprintf '%s:1', $frame->headers->{session};
ok($frame->headers->{session}, 'got a session');
ok(length $reply_to > 2, 'valid-looking reply_to queue');

ok($stomp->subscribe( { destination => '/temp-queue/reply' } ), 'subscribe to temp queue');

my $message = {
	       payload => { foo => 1, bar => 2 },
	       reply_to => $reply_to,
	       type => 'testaction',
	      };
my $text = Dump($message);
ok($text, 'compose message');

$stomp->send( { destination => '/queue/testcontroller', body => $text } );

my $reply_frame = $stomp->receive_frame();
ok($reply_frame, 'got a reply');
ok($reply_frame->headers->{destination} eq "/remote-temp-queue/$reply_to", 'came to correct temp queue');
ok($reply_frame->body, 'has a body');

my $response = Load($reply_frame->body);
ok($response, 'YAML response ok');
ok($response->{type} eq 'testaction_response', 'correct type');

ok($stomp->disconnect, 'disconnected');

