package # Hide from PAUSE
  StompTestApp::Controller::TestController;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::MessageDriven' };

sub testaction : Local {
    my ($self, $c, $request) = @_;

    # Reply with a minimal response message
    my $response = { type => 'testaction_response' };
    $c->stash->{response} = $response;
}

sub badaction : Local {
    my ($self, $c, $request) = @_;
    die "oh noes";
}

sub ping : Local {
    my ($self, $c, $request) = @_;
    if ($request->{type} eq 'ping') {
	    $c->stash->{response} = { status => 'PONG' };
	    return;
    }
    die "not a ping request?";
}

1;
