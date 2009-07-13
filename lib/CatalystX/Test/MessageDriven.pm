package CatalystX::Test::MessageDriven;
use Class::MOP;
use Sub::Exporter;
use HTTP::Request;

BEGIN {
    $ENV{CATALYST_ENGINE} = 'Test::MessageDriven';
};

=head1 NAME

CatalystX::Test::MessageDriven - test message-driven Catalyst apps

=head1 DESCRIPTION

Derived from Catalyst::Test, this module provides a way to run tests
against message-driven Catalyst applications - those with
Catalyst::Controller::MessageDriven-based controllers, and expect to
run with Catalyst::Engine::Stomp.

=head1 SYNOPSIS

  BEGIN { use_ok 'CatalystX::Test::MessageDriven', 'SomeApp' };

  my $req = '... some message text ...';
  my $queue = 'somequeue';
  my $res = request($queue, $req);
  ok($res);

=head1 EXPORTS

=head2 request(queue, message)

This function accepts a queue and a message, and runs the request in
that context. Returns a response object.

=head1 TODO

Some test wrappers - successful / error message conditions?

=cut

my $message_driven_request = sub {
    my ($app, $path, $req_message) = @_;
    my $url = "message://localhost:61613/$path";

    my $request = HTTP::Request->new( POST => $url );
    $request->content($req_message);
    $request->content_length(length $req_message);
    $request->content_type('application/octet-stream');

    my $response;
    $app->handle_request($request, \$response);

    return $response;
};

my $build_exports = sub {
    my ($self, $meth, $args, $defaults) = @_;

    my $request;
    my $class = $args->{class};

    if (!$class) {
        $request = sub { Catalyst::Exception->throw("Must specify a test app: use CatalystX::Test::MessageDriven 'TestApp'") };
    }
    else {
        unless (Class::MOP::is_class_loaded($class)) {
            Class::MOP::load_class($class);
        }
        $class->import;

        my $app = $class->run();
        $request = sub { $message_driven_request->( $app, @_ ) };
    }

    return {
        request => $request,
    };
};

{
    my $import = Sub::Exporter::build_exporter({
        groups => [ all => $build_exports ],
        into_level => 1,
    });

    sub import {
        my ($self, $class) = @_;
        $import->($self, '-all' => { class => $class });
        return 1;
    }
}

package # Hide from PAUSE
    Catalyst::Engine::Test::MessageDriven;
use base 'Catalyst::Engine::Embeddable';

sub run {
    my ($self, $app) = @_;
    return $app;
}

1;

