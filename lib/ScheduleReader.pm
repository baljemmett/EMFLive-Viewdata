package ScheduleReader;

use strict;
use warnings;

use JSON::PP;
use Text::Unidecode;
use Time::Piece;

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
	"2022-06-02" => "Thu",
	"2022-06-03" => "Fri",
	"2022-06-04" => "Sat",
	"2022-06-05" => "Sun",
	"2022-06-06" => "Mon",
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

# Derive a ReminderCode (trademark not applied for) for an event from its JSON.
# This needs to be a stable derivation, since it's used both in the
# schedule-publishing script and the reminder-database populating script!
sub derive_reminder_code($)
{
    my $event = shift;

    sprintf("99%04d", $event->{id});
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
            title    => unidecode($_->{"title"}),
            desc     => unidecode($_->{"description"}),
            venue    => $_->{"venue"},
            type     => $event_types{$_->{"type"}},
            by       => unidecode($_->{"speaker"}),
            cost     => $_->{"cost"} || "",
            ages     => unidecode($_->{"age_range"} || ""),
            cws      => unidecode($_->{"content_note"} || ""),
            capacity => unidecode($_->{"attendees"} || ""),
            start    => format_date($_->{"start_date"}),
            end      => format_end_time($_->{"start_date"}, $_->{"end_date"}),
            sdate    => $_->{"start_date"},
            edate    => $_->{"end_date"},
            stime    => Time::Piece->strptime($_->{"start_date"}, "%Y-%m-%d %H:%M:%S"),
            etime    => Time::Piece->strptime($_->{"end_date"}, "%Y-%m-%d %H:%M:%S"),
            reminder => derive_reminder_code($_),
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