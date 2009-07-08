package Catalyst::Controller::MessageDriven;
use Moose;
use Data::Serializer;
use Moose::Util::TypeConstraints;
use MooseX::Types::Moose qw/Str/;
use namespace::autoclean;

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

=head1 METHODS

=head2 begin

Deserializes the request into C<< $c->stash->{request} >>

=head2 default

Dispatches to method named by the key C<< $c->stash->{request}->{type} >>

=head2 end

Serializes the response from C<< $c->stash->{response} >>

=cut

class_type 'Data::Serializer';
my $serializer_t = subtype 'Data::Serializer', where { 1 };
coerce $serializer_t, from 'Str',
    via { Data::Serializer->new( serializer => $_ ) };

has serializer => (
    isa => $serializer_t, is => 'ro', required => 1,
    default => 'YAML', coerce => 1,
);

sub begin : Private {
    my ($self, $c) = @_;

    # Deserialize the request message
        my $message;
    my $s = $self->serializer;
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

    # The wire response
    my $output;

    # Load a serializer
    my $s = $self->serializer;

    # Custom error handler - steal errors from catalyst and dump them into
    # the stash, to get them serialized out as the reply.
     if (scalar @{$c->error}) {
        $c->log->error($_) for @{$c->error}; # Log errors in Catalyst
        my $error = join "\n", @{$c->error};
        $c->stash->{response} = { status => 'ERROR', error => $error };
        $output = $s->serialize( $c->stash->{response} );
        $c->clear_errors;
        $c->response->status(400);
     }

    # Serialize the response
    eval {
        $output = $s->raw_serialize( $c->stash->{response} );
    };
    if ($@) {
         my $error = "exception in serialize: $@";
         $c->stash->{response} = { status => 'ERROR', error => $error };
         $output = $s->serialize( $c->stash->{response} );
        $c->response->status(400);
    }

    $c->response->output( $output );
}

sub default : Private {
    my ($self, $c) = @_;

    # Forward the request to the appropriate action, based on the
    # message type.
    my $action = $c->stash->{request}->{type};
    if (defined $action) {
        $c->forward($action, [$c->stash->{request}]);
    }
    else {
         $c->error('no message type specified');
    }
}

__PACKAGE__->meta->make_immutable;

