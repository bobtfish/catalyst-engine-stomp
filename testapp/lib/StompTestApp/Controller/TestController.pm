package # Hide from PAUSE
  StompTestApp::Controller::TestController;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::MessageDriven' };

sub testaction : Local {
    my ($self, $c) = @_;

    # Reply with a minimal response message
    my $response = { type => 'testaction_response' };
    $c->stash->{response} = $response;
}

1;
