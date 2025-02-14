package TelstarFrame;

use strict;
use warnings;
use JSON::PP;
use Storable qw(dclone);

our $directory = ".";
our $service = undef;

# Initialise the general structure of a Telstar frame,
# given a frame number and optional subpage letter.
sub new
{
    my ($class, $number, $subpage) = @_;
    my $self = bless {
        "pid" => {
            "sequential" => 0,
            "page-no" => $number,
            "frame-id" => defined $subpage ? $subpage : "a"
        },
        "visible" => JSON::PP::true,
        "navmessage-select" => undef,
        "navmessage-notfound" => undef,
        "header-text" => $service,
        "routing-table" => undef,
        "content" => {
            "lines" => [],
            "type" => "markup"
        }
    }, $class;
}

# Append a line of text to our internal representation of the frame.
# The real content.data field won't be generated until write() time.
sub add_line
{
    my ($self, $line) = @_;
    push @{$self->{content}{lines}}, $line;
}

# Append a bunch of lines to our internal representation of the frame.
sub add_lines
{
    my $self = shift;
    map {$self->add_line($_)} @_;
}

# How many lines do we currently have in the frame?
sub count_lines
{
    my $self = shift;
    scalar @{$self->{content}{lines}};
}

# Is a given line an exact multiple of the screen width?
my $lineful = "-"x39;   # for separator graphic lines

sub is_exact_line_width
{
    my $text = shift;

    return 0 if length($text) == 0;

    # Various markup codes take up a character cell in the output
    # so convert them to spaces to the purposes of length checking...
    $text =~ s/\[([WRGBCMYwrgbcmyFSNDn-]|_[-+])\]/ /g;

    # The seven separator-line codes translate into 39-character
    # strings of repeating characters, to fill out a line after
    # the introductory mosaic-colour code.
    $text =~ s/\[([hml][-.]|=)\]/$lineful/g;
    
    return length($text) % 40 == 0;
}

# Write the frame out to a file in an (optional) directory; defaults
# to the current directory if not provided.  Filename will be based
# on the frame number and subpage letter.
sub write
{
    my ($self, $dir) = @_;

    my %output = %{dclone $self};

    my @lines = @{$output{content}{lines}};

    map { $_ .= "\r\n" unless is_exact_line_width($_) } @lines;
    $output{content}{data} = join "", @lines;

    delete $output{content}{lines};
    delete $output{pid}{sequential};

    for my $field (qw(navmessage-select navmessage-notfound header-text routing-table))
    {
        delete $output{$field} unless defined $output{$field};
    }

    $dir = $directory unless defined $dir;
    my $pid = \%{$output{pid}};
    $self->{filename} = $directory . "/" . $pid->{"page-no"} . $pid->{"frame-id"} . ".json";

    open my $file, ">", $self->{filename} or die "Cannot create $self->{filename}: $!";
    print $file JSON::PP->new->pretty->encode(\%output);
    close $file;
}

# Create a new TelstarFrame object representing the successor subpage to
# this object, or if the 'sequential' flag is set the next numeric page.
sub next_subpage
{
    my $self = shift;
    my %pid = %{$self->{pid}};

    if ($pid{"sequential"})
    {
        $pid{"page-no"}++;

        # Route the # key on this frame to the number of the new frame.
        # If we're using successor subframes this happens automatically!
        if (! defined $self->{"routing-table"} ||
            $self->{"routing-table"}[10] == $self->{"pid"}{"page-no"})
        {
            $self->set_route(10, $pid{"page-no"});
        }
    }
    elsif ($pid{"frame-id"} eq "z")
    {
        $pid{"page-no"} *= 10;
        $pid{"frame-id"} = "a";
    }
    else
    {
        $pid{"frame-id"} = chr(ord($pid{"frame-id"}) + 1);
    }

    my $frame = TelstarFrame->new($pid{"page-no"}, $pid{"frame-id"});
    $frame->{"pid"}{"sequential"} = $pid{"sequential"};

    return $frame;
}

# Set a routing table entry [0-9 or -1/10/anything for hash]
sub set_route
{
    my ($self, $route, $frame) = @_;

    if (! defined $self->{"routing-table"})
    {
        my $base = $self->{"pid"}{"page-no"} * 10;

        $self->{"routing-table"} = [ map $base + $_, 0..9 ];
        push @{$self->{"routing-table"}}, $self->{"pid"}{"page-no"};
    }

    if ($route >= 0 && $route <= 9)
    {
        $self->{"routing-table"}->[$route] = $frame;
    }
    else
    {
        $self->{"routing-table"}->[10] = $frame;
    }
}

# Override the service name in the header.
# (Can also be done by changing $self->{"header-text"} but this is cleaner)
sub set_service
{
    my ($self, $service) = @_;
    $self->{"header-text"} = $service;
}

1;