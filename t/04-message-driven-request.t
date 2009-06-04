use strict;
use warnings;
use Test::More tests => 3;

use FindBin;
use lib "$FindBin::Bin/../testapp/lib";

BEGIN { use_ok 'Catalyst::Test::MessageDriven', 'StompTestApp' };

my $req = "---\ntype: ping\n";
my $res = request('testcontroller', $req);
ok($res, 'response to ping message');
ok($res->is_success, 'successful response');
