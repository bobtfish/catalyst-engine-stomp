package Catalyst::Engine::Stomp;
use Moose;
use List::MoreUtils qw/ uniq /;
use HTTP::Request;
use Net::Stomp;
use namespace::autoclean;

extends 'Catalyst::Engine::Embeddable';

our $VERSION = '0.06';

has connection => (is => 'rw', isa => 'Net::Stomp');
has conn_desc => (is => 'rw', isa => 'Str');

=head1 NAME

Catalyst::Engine::Stomp - write message handling apps with Catalyst.

=head1 SYNOPSIS

  # In a server script:

  BEGIN {
    $ENV{CATALYST_ENGINE} = 'Stomp';
    require Catalyst::Engine::Stomp;
  }

  MyApp->config->{Engine::Stomp} =
   {
     hostname => '127.0.0.1',
     port     => 61613,
   };
  MyApp->run();

  # In a controller, or controller base class:
  use base qw/ Catalyst::Controller::MessageDriven /;

  # then create actions, which map as message types
  sub testaction : Local {
      my ($self, $c) = @_;

      # Reply with a minimal response message
      my $response = { type => 'testaction_response' };
      $c->stash->{response} = $response;
  }

=head1 DESCRIPTION

Write a Catalyst app connected to a Stomp messagebroker, not HTTP. You
need a controller that understands messaging, as well as this engine.

This is single-threaded and single process - you need to run multiple
instances of this engine to get concurrency, and configure your broker
to load-balance across multiple consumers of the same queue.

Controllers are mapped to Stomp queues, and a controller base class is
provided, Catalyst::Controller::MessageDriven, which implements
YAML-serialized messages, mapping a top-level YAML "type" key to
the action.

=head1 METHODS

=head2 run

App entry point. Starts a loop listening for messages.

=cut

sub run {
        my ($self, $app, $oneshot) = @_;

        die 'No Engine::Stomp configuration found'
             unless ref $app->config->{'Engine::Stomp'} eq 'HASH';

        my @queues = grep { length $_ }
                     map  { $app->controller($_)->action_namespace } $app->controllers;

        # connect up
        my %template = %{$app->config->{'Engine::Stomp'}};
        $self->connection(Net::Stomp->new(\%template));
        $self->connection->connect();
        $self->conn_desc($template{hostname}.':'.$template{port});

        # subscribe, with client ack.
        foreach my $queue (@queues) {
                my $queue_name = "/queue/$queue";
                $self->connection->subscribe({
                                              destination => $queue_name,
                                              ack         => 'client'
                                             });
        }

        # enter loop...
        while (1) {
                my $frame = $self->connection->receive_frame();
                $self->handle_stomp_frame($app, $frame);
                last if $ENV{ENGINE_ONESHOT};
        }
        exit 0;
}

=head2 prepare_request

Overridden to add the source broker to the request, in place of the
client IP address.

=cut

sub prepare_request {
    my ($self, $c, $req, $res_ref) = @_;
    shift @_;
    $self->next::method(@_);
    $c->req->address($self->conn_desc);
}

=head2 finalize_headers

Overridden to dump out any errors encountered, since you won't get a
"debugging" message as for HTTP.

=cut

sub finalize_headers {
    my ($self, $c) = @_;
    my $error = join "\n", @{$c->error};
    if ($error) {
        $c->log->debug($error);
    }
    return $self->next::method($c);
}

=head2 handle_stomp_frame

Dispatch according to Stomp frame type.

=cut

sub handle_stomp_frame {
    my ($self, $app, $frame) = @_;

    my $command = $frame->command();
    if ($command eq 'MESSAGE') {
        $self->handle_stomp_message($app, $frame);
    }
    elsif ($command eq 'ERROR') {
        $self->handle_stomp_error($app, $frame);
    }
    else {
        $app->log->debug("Got unknown Stomp command: $command");
    }
}

=head2 handle_stomp_message

Dispatch a Stomp message into the Catalyst app.

=cut

sub handle_stomp_message {
    my ($self, $app, $frame) = @_;

    # queue -> controller
    my $queue = $frame->headers->{destination};
    my ($controller) = $queue =~ m|^/queue/(.*)$|;

    # set up request
    my $config = $app->config->{'Engine::Stomp'};
    my $url = 'stomp://'.$config->{hostname}.':'.$config->{port}.'/'.$controller;
    my $req = HTTP::Request->new(POST => $url);
    $req->content($frame->body);
    $req->content_length(length $frame->body);

    # dispatch
    my $response;
    $app->handle_request($req, \$response);

    # reply, if header set
    if (my $reply_to = $response->headers->header('X-Reply-Address')) {
        my $reply_queue = '/remote-temp-queue/' . $reply_to;
        $self->connection->send({ destination => $reply_queue, body => $response->content });
    }

    # ack the message off the queue now we've replied / processed
    $self->connection->ack( { frame => $frame } );
}

=head2 handle_stomp_error

Log any Stomp error frames we receive.

=cut

sub handle_stomp_error {
    my ($self, $app, $frame) = @_;

    my $error = $frame->headers->{message};
    $app->log->debug("Got Stomp error: $error");
}

__PACKAGE__->meta->make_immutable;

