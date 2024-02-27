package TelstarFrame;

use strict;
use warnings;
use JSON::PP;

# Initialise the general structure of a Telstar frame,
# given a frame number and optional subpage letter.
sub new
{
    my ($class, $number, $subpage) = @_;
    my $self = bless {
        "pid" => {
            "page-no" => $number,
            "frame-id" => defined $subpage ? $subpage : "a"
        },
        "visible" => JSON::PP::true,
        "navmessage-select" => undef,
        "navmessage-notfound" => undef,
        "header-text" => undef,
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

# Write the frame out to a file in an (optional) directory; defaults
# to the current directory if not provided.  Filename will be based
# on the frame number and subpage letter.
sub write
{
    my ($self, $directory) = @_;

    my %output = %$self;
    
    $output{content}{data} = join "\r\n", @{$output{content}{lines}};
    delete $output{content}{lines};

    for my $field (qw(navmessage-select navmessage-notfound header-text routing-table))
    {
        delete $output{$field} unless defined $output{$field};
    }

    $directory = "." unless defined $directory;
    my $pid = \%{$output{pid}};
    my $filename = $directory . "/" . $pid->{"page-no"} . $pid->{"frame-id"} . ".json";

    open my $file, ">", $filename or die "Cannot create $filename: $!";
    print $file JSON::PP->new->pretty->encode(\%output);
    close $file;
}

# Create a new TelstarFrame object representing the successor subpage
# to this object.
sub next_subpage
{
    my $self = shift;
    my %pid = %{$self->{pid}};

    if ($pid{"frame-id"} eq "z")
    {
        $pid{"page-no"} *= 10;
        $pid{"frame-id"} = "a";
    }
    else
    {
        $pid{"frame-id"} = chr(ord($pid{"frame-id"}) + 1);
    }

    return TelstarFrame->new($pid{"page-no"}, $pid{"frame-id"});
}

1;