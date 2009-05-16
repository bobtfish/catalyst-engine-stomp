package Catalyst::Controller::MessageDriven;
use Moose;

BEGIN { extends 'Catalyst::Controller' }

=head1 NAME

Catalyst::Controller::MessageDriven

=head1 SYNOPSIS

  package MyApp::Controller::Queue;
  use Moose;
  BEGIN { extends 'Catalyst::Controller::MessageDriven' }

  sub some_action : Local { 
      my ($self, $c) = @_;
      # Reply with a minimal response message
      my $response = { type => 'testaction_response' };
      $c->stash->{response} = $response;
  }

=head1 DESCRIPTION

A Catalyst controller base class for use with Catalyst::Engine::Stomp,
which handles YAML-serialized messages. A top-level "type" key in the
YAML determines the action dispatched to. 

=cut

__PACKAGE__->config(
		    'default'   => 'text/x-yaml',
		    'stash_key' => 'response',
		    'map'       => { 'text/x-yaml' => 'YAML' },
		   );

sub begin :ActionClass('Deserialize') { }

sub end :ActionClass('Serialize') {
	my ($self, $c) = @_;

	# Engine will send our reply based on the value of this header.
	$c->response->headers->header( 'X-Reply-Address' => $c->req->data->{reply_to} );

	# Custom error handler - steal errors from catalyst and dump them into
	# the stash, to get them serialized out as the reply.
 	if (scalar @{$c->error}) {
 		my $error = join "\n", @{$c->error};
 		$c->stash->{response} = { status => 'ERROR', error => $error };
		$c->error(0); # clear errors, so our response isn't clobbered
 	}
}

sub default : Private {
	my ($self, $c) = @_;
	
	# Forward the request to the appropriate action, based on the
	# message type.
	my $action = $c->req->data->{type};
	$c->forward($action, [$c->req->data]);
}

__PACKAGE__->meta->make_immutable;

1;
