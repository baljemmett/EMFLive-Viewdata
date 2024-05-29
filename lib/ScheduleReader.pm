package ScheduleReader;

use strict;
use warnings;

use JSON::PP;
use Text::Unidecode;
use Time::Piece;

# Whether we're operating in an environment that can handle actual Unicode
# rather than requiring it be smashed to ASCII
our $unicode_clean = 0;

# Whether to show the day in the end time, if it differs from the start day.
our $show_end_day = 0;

# On what hour does the logical day ('broadcast day') end?
our $logical_midnight = 3;   # 3 a.m.

# UI-friendly conversions for event type names
our %event_types = (
	talk => "Talk",
	performance => "Performance",
	workshop => "Workshop",
	youthworkshop => "Youth Workshop",
);

# These could probably be computed but whatever
my %days = (
	"2024-05-30" => "Thu",
	"2024-05-31" => "Fri",
	"2024-06-01" => "Sat",
	"2024-06-02" => "Sun",
	"2024-06-03" => "Mon",
);

# Set of regexes used to reorder venues in the canonical list. Venues matching
# these will be moved to the front of the list, in this order. Otherwise the
# default alphabetic ordering is applied.
my @venue_order_regexes = (
    qr/Stage [ABC]/,
    qr/Workshop/,
    qr/Blacksmith/,
    qr/Lounge|Bar/i,
    qr/Null Sector/,
);

# Sort criterion - by start time
sub by_time
{
	defined $a->{"start_date"} or die "$a->{id}: no start date";
	defined $b->{"start_date"} or die "$b->{id}: no start date";
	return $a->{"start_date"} cmp $b->{"start_date"};
}

# Get a day name for a given date string, with caching
sub get_day($)
{
    my $date = shift;

    if (! exists $days{$date})
    {
        $days{$date} = Time::Piece->strptime($date, "%Y-%m-%d")->day;
    }

    $days{$date};
}

# Turn an ISO date/timestamp into a friendly 'Day HH:MM' format
sub format_date($)
{
	my $datetime = shift;

	if ($datetime =~ /(\d{4}-\d\d-\d\d) (\d\d:\d\d):\d\d/)
	{
		return get_day($1) . " " . $2;
	}

	return $datetime;
}

# Given start and end times, format the end time appropriately
# (i.e. including the day if it isn't the same day the event starts)
sub format_end_time($$)
{
	my ($start, $end) = @_;

	my $formatted = format_date($end);

	if (!$show_end_day || (split(/ /, $end))[0] eq (split(/ /, $start))[0])
	{
		$formatted = (split(/ /, $formatted))[1];
	}

	return $formatted;
}

# Smash Unicode to ASCII if required
sub unicode_field($)
{
    my $text = shift;

    return $unicode_clean ? $text : unidecode($text);
}

# Load the schedule from a JSON file
sub from_file($)
{
    my $filename = shift;
    my $schedule;

    # Start by reading the schedule JSON...
    if (open my $input, "<", $filename)
    {
        # Read the entire file in one go, decoding into a list-of-hashes.
        local $/ = undef;
        $schedule = JSON::PP->new->utf8->decode(<$input>);
        close $input;
    }
    else
    {
        die "Cannot open input $filename: $!";
    }

    # .. and then reformatting the complete event list into data more suited
    # to our requirements and display restrictions.
    my @events = ();

    for (sort by_time @$schedule)
    {
        push @events, {
            id       => $_->{"id"},
            title    => unicode_field($_->{"title"}),
            desc     => unicode_field($_->{"description"}),
            venue    => unicode_field($_->{"venue"}),
            type     => $event_types{$_->{"type"}},
            by       => unicode_field($_->{"speaker"}),
            cost     => $_->{"cost"} || "",
            ages     => unicode_field($_->{"age_range"} || ""),
            cws      => unicode_field($_->{"content_note"} || ""),
            capacity => unicode_field($_->{"attendees"} || ""),
            start    => format_date($_->{"start_date"}),
            end      => format_end_time($_->{"start_date"}, $_->{"end_date"}),
            sdate    => $_->{"start_date"},
            edate    => $_->{"end_date"},
            stime    => Time::Piece->strptime($_->{"start_date"}, "%Y-%m-%d %H:%M:%S"),
            etime    => Time::Piece->strptime($_->{"end_date"}, "%Y-%m-%d %H:%M:%S"),
            friendly => $_->{"is_family_friendly"} || 0,
            recorded => $_->{"may_record"} || 0,
            ticketed => $_->{"requires_ticket"} || 0,
        };

        # Convert £ to # because the 80s were a horrible time to ASCII.
        $events[-1]->{cost} =~ s/\x{a3}/#/g;

        # Remove cost if it's one of various forms of free-ness
        if ($events[-1]->{cost} =~ /^(free|none|no cost|#0)$/i)
        {
            $events[-1]->{cost} = "";
        }

        # Pull the (start) day out into its own field for ease of access.
        # Account for logical midnight here, so that when we group by day
        # events in the small hours show up on the previous day.
        $events[-1]->{day} = ($events[-1]->{stime} - $logical_midnight * 60 * 60)->day;
    }

    @events;
}

# Find a list of all venues present in a loaded schedule
sub all_venues
{
    my %venues = ();

    for my $event (@_)
    {
        $venues{$event->{venue}} = 1;
    }

    my @venues = sort keys %venues;

    for my $re (reverse @venue_order_regexes)
    {
        my @matches = grep $_ =~ $re, @venues;
        my @others  = grep $_ !~ $re, @venues;

        @venues = (@matches, @others);
    }

    return @venues;
}

1;