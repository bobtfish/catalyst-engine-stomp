package Catalyst::Engine::Stomp;
use Moose;
extends 'Catalyst::Engine::Embeddable';

our $VERSION = '0.01';

use List::MoreUtils qw/ uniq /;
use HTTP::Request;
use Net::Stomp;

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

  use YAML;

  # configure YAML deserialization; requires Catalyst::Action::REST
  __PACKAGE__->config(
	  	    'default'   => 'text/x-yaml',
		    'stash_key' => 'rest',
		    'map'       => { 'text/x-yaml' => 'YAML' },
		   );

  sub begin :ActionClass('Deserialize') { }

  # have a default action, which forwards to the correct action
  # based on the message contents (the type).
  sub default : Private {
	  my ($self, $c) = @_;

	  my $action = $c->req->data->{type};
	  $c->forward($action);
  }  

  # Send messages back:
  $c->engine->send_message($queue, Dump($msg));

=head1 DESCRIPTION

Write a Catalyst app connected to a Stomp messagebroker, not HTTP. You
need a controller that understands messaging, as well as this engine. 

This is single-threaded and single process - you need to run multiple
instances of this engine to get concurrency, and configure your broker
to load-balance across multiple consumers of the same queue.

=head1 METHODS

=head2 run

App entry point. Starts a loop listening for messages.

=cut

sub run {
        my ($self, $app, $oneshot) = @_;

        die 'No Engine::Stomp configuration found'
	     unless ref $app->config->{'Engine::Stomp'} eq 'HASH';

        # list the path namespaces that will be mapped as queues.
	#
	# this is known to use the deprecated
	# Dispatcher->action_hash() method, but there doesn't appear
	# to be another way to get the relevant strings out.
	#
	# http://github.com/rafl/catalyst-runtime/commit/5de163f4963d9dbb41d7311ca6f17314091b7af3#L2R644
	#
        my @queues =
	    uniq
	    grep { length $_ }
	    map  { $_->namespace }
	    values %{$app->dispatcher->action_hash};

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

Overridden to dump out any errors encountered.

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

Dispatch according to STOMP frame type.

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
		$app->log->debug("Got unknown STOMP command: $command");
	}
}

=head2 handle_stomp_message

Dispatch a STOMP message into the Catalyst app.

=cut

sub handle_stomp_message {
	my ($self, $app, $frame) = @_;

	# queue -> controller
	my $queue = $frame->headers->{destination};
	my ($controller) = $queue =~ m!^/queue/(.*)$!;

	# set up request
        my $config = $app->config->{'Engine::Stomp'};
        my $url = 'stomp://'.$config->{hostname}.':'.$config->{port}.'/'.$controller;
        my $req = HTTP::Request->new(POST => $url);
        $req->content($frame->body);	
	$req->content_length(length $frame->body);

	# dispatch
	my $response;
        $app->handle_request($req, \$response);

	# reply
	my $reply_queue = '/remote-temp-queue/' . ($response->headers->header('X-Reply-Address'));
	$self->connection->send({ destination => $reply_queue, body => $response->content });

	# ack the message off the queue now we've replied
	$self->connection->ack( { frame => $frame } );
}

=head2 handle_stomp_error

Log any STOMP error frames we receive.

=cut

sub handle_stomp_error {
	my ($self, $app, $frame) = @_;
	
	my $error = $frame->headers->{message};
	$app->log->debug("Got STOMP error: $error");
}

1;

