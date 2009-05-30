package Catalyst::Controller::MessageDriven;
use Moose;
use Data::Serializer;

BEGIN { extends 'Catalyst::Controller' }

=head1 NAME

Catalyst::Controller::MessageDriven

=head1 SYNOPSIS

  package MyApp::Controller::Queue;
  use Moose;
  BEGIN { extends 'Catalyst::Controller::MessageDriven' }

  sub some_action : Local { 
      my ($self, $c, $message) = @_;

      # Handle message 

      # Reply with a minimal response message
      my $response = { type => 'testaction_response' };
      $c->stash->{response} = $response;
  }

=head1 DESCRIPTION

A Catalyst controller base class for use with Catalyst::Engine::Stomp,
which handles YAML-serialized messages. A top-level "type" key in the
YAML determines the action dispatched to. 

=cut

__PACKAGE__->config( serializer => 'YAML' );

sub begin : Private { 
	my ($self, $c) = @_;
	
	# Deserialize the request message
        my $message;
	my $serializer = $self->config->{serializer};
	my $s = Data::Serializer->new( serializer => $serializer );
	eval {
		my $body = $c->request->body;
		open my $IN, "$body" or die "can't open temp file $body";
		$message = $s->raw_deserialize(do { local $/; <$IN> });
	};
	if ($@) {
		# can't reply - reply_to is embedded in the message
		$c->error("exception in deserialize: $@");
	}
	else {
		$c->stash->{request} = $message;
	}
}

sub end : Private {
	my ($self, $c) = @_;

	# Engine will send our reply based on the value of this header.
	$c->response->headers->header( 'X-Reply-Address' => $c->stash->{request}->{reply_to} );

	# Custom error handler - steal errors from catalyst and dump them into
	# the stash, to get them serialized out as the reply.
 	if (scalar @{$c->error}) {
 		my $error = join "\n", @{$c->error};
 		$c->stash->{response} = { status => 'ERROR', error => $error };
		$c->error(0); # clear errors, so our response isn't clobbered
 	}

	# Serialize the response
	my $output;
	my $serializer = $self->config->{serializer};
	my $s = Data::Serializer->new( serializer => $serializer );
	eval {
		$output = $s->raw_serialize( $c->stash->{response} );
	};
	if ($@) {
 		my $error = "exception in serialize: $@";
		$c->error($error);
 		$c->stash->{response} = { status => 'ERROR', error => $error };
 		$output = Dump( $c->stash->{response} );
	}

	$c->response->output( $output );
}

sub default : Private {
	my ($self, $c) = @_;

	# Forward the request to the appropriate action, based on the
	# message type.
	my $action = $c->stash->{request}->{type};
	$c->forward($action, [$c->stash->{request}]);
}

__PACKAGE__->meta->make_immutable;

1;
