use Test::More;

# Tests which expect a STOMP server like ActiveMQ to exist on
# localhost:61613, which is what you get if you just get the ActiveMQ
# distro and run its out-of-the-box config.

use Net::Stomp;

eval {
	use JSON;
};
if ($@) {
	plan 'skip_all' => 'JSON not installed, skipping JSON-format test';
}

use FindBin;
use lib "$FindBin::Bin";
require 'server.pl';

plan tests => 11;

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
my $text = to_json($message);
ok($text, 'compose message');

$stomp->send( { destination => '/queue/testjsoncontroller', body => $text } );

my $reply_frame = $stomp->receive_frame();
ok($reply_frame, 'got a reply');
ok($reply_frame->headers->{destination} eq "/remote-temp-queue/$reply_to", 'came to correct temp queue');
ok($reply_frame->body, 'has a body');

my $response = from_json($reply_frame->body);

ok($response, 'JSON response ok');
ok($response->{type} eq 'testaction_response', 'correct type');

ok($stomp->disconnect, 'disconnected');

