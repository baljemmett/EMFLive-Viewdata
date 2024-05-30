package TelstarClient;

use strict;
use warnings;

use HTTP::Request;
use HTTP::Cookies;
use LWP::UserAgent;
use JSON::PP;

our $json = JSON::PP->new->utf8;

sub new
{
    my ($class, $frame, $args) = @_;

    my $self = bless {
        server => $args->{server} || $ENV{TELSTAR_API_SERVER} || "",
        username => $args->{username} || $ENV{TELSTAR_API_USERNAME} || "",
        password => $args->{username} || $ENV{TELSTAR_API_PASSWORD} || "",

        _token => undef,
        _ua => new LWP::UserAgent,
        _cookies => new HTTP::Cookies,
    }, $class;

    $self->{server} =~ s#/$##;

    if ($self->{server} !~ m#^https?://#)
    {
        $self->{server} = "http://" . $self->{server};
    }

    if ($self->{server} =~ m#(//)?([^:/]+)(:(\d+))?(/|$)#)
    {
        $self->{_host} = $2;
        $self->{_port} = $4 || 8001;
    }
    else
    {
        $self->{_host} = $self->{_server};
        $self->{_port} = 8001;
    }

    $self->{_ua}->cookie_jar($self->{_cookies});
    $self->{_valid} = $self->{server} && $self->{username} && $self->{password};

    if (! $self->{_valid})
    {
        print "Telstar API connection details not set.  Not updates will be performed.\n";
    }

    $self;
}

sub _login
{
    my $self = shift;
    return 0 unless $self->{_valid};

    my $api_request = {
        "user-id" => $self->{username},
        "password" => $self->{password},
    };

    my $endpoint = $self->{server} . "/login";
    my $headers = ['Content-Type' => 'application/json; charset=utf-8'];
    my $data = $json->encode($api_request);

    my $request = HTTP::Request->new('PUT', $endpoint, $headers, $data);
    my $response = $self->{_ua}->request($request);

    if ($response->is_success)
    {
        print "Telstar API login successful.\n";

        # Duplicate token returned in 'token' cookie to 'jwt' cookie
        # since Telstar either needs both or only wants the latter...
        my $token = $self->{_cookies}->get_cookies($self->{_host}, "token");

        # Not entirely sure what the foible here is but apparently we need
        # to set the cookie on localhost.local even if we're talking to localhost.
        my $host = $self->{_host};
        $host = "localhost.local" if $host eq "localhost";

        $self->{_cookies}->set_cookie(0, "jwt", $token, "/", $host, $self->{_port}, 0, 0, 300, 0);
        1;
    }
    else
    {
        print "Could not log in to Telstar API:\n";
        print $response->decoded_content;
        0;
    }
}

sub addframe($$)
{
    my $self = shift;
    return 0 unless $self->{_valid};

    my $filename = shift;
    my $attempt = 0;
    my $data = undef;

    if (open my $input, "<", $filename)
    {
        local $/ = undef;
        $data = <$input>;
        close $input;
    }
    else
    {
        print "Could not read $filename for upload: $!";
        return;
    }

    my $endpoint = $self->{server} . "/frame";
    my $headers = ['Content-Type' => 'application/json; charset=utf-8'];

RETRY:
    $attempt++;

    my $request = HTTP::Request->new('PUT', $endpoint, $headers, $data);
    my $response = $self->{_ua}->request($request);

    if ($response->is_success)
    {
        print "Telstar frame update successful.\n";
    }
    elsif ($response->code == 401 && $attempt == 1)
    {
        print "Telstar frame update failed as unauthorized; logging in...\n";
        goto RETRY if $self->_login();
    }
    else
    {
        print "Could not update Telstar frame:\n";
        print $response->decoded_content;
    }
}

sub delframe($$)
{
    my $self = shift;
    return 0 unless $self->{_valid};

    my $frame = shift;
    my $attempt = 0;

    my $endpoint = $self->{server} . "/frame/" . $frame . "?purge=true";

RETRY:
    $attempt++;

    my $request = HTTP::Request->new('DELETE', $endpoint);
    my $response = $self->{_ua}->request($request);

    if ($response->is_success)
    {
        print "Telstar frame $frame delete successful.\n";
    }
    elsif ($response->code == 401 && $attempt == 1)
    {
        print "Telstar frame delete failed as unauthorized; logging in...\n";
        goto RETRY if $self->_login();
    }
    else
    {
        print "Could not delete Telstar frame $frame:\n";
        print $response->decoded_content;
    }
}

sub addframes($$)
{
    my $self = shift;
    return 0 unless $self->{_valid};

    my $glob = shift;

    for my $file (glob $glob)
    {
        if ($file =~ m|/(\d+a)\.json|)
        {
            $self->delframe($1);
        }

        $self->addframe($file);
    }
}

1;