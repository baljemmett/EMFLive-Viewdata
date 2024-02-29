package ScheduleReader;

use strict;
use warnings;

use JSON::PP;
use Text::Unidecode;

# Whether to show the day in the end time, if it differs from the start day.
my $show_end_day = 0;

# UI-friendly conversions for event type names
my %types = (
	talk => "Talk",
	performance => "Performance",
	workshop => "Workshop",
	youthworkshop => "Youth Workshop",
);

# These could probably be computed but whatever
my %dates = (
	"2022-06-02" => "Thu",
	"2022-06-03" => "Fri",
	"2022-06-04" => "Sat",
	"2022-06-05" => "Sun",
	"2022-06-06" => "Mon",
);

# Sort criterion - by start time
sub by_time
{
	defined $a->{"start_date"} or die "$a->{id}: no start date";
	defined $b->{"start_date"} or die "$b->{id}: no start date";
	return $a->{"start_date"} cmp $b->{"start_date"};
}

# Turn an ISO date/timestamp into a friendly 'Day HH:MM' format
sub format_date($)
{
	my $datetime = shift;

	if ($datetime =~ /(\d{4}-\d\d-\d\d) (\d\d:\d\d):\d\d/)
	{
		if (exists $dates{$1})
		{	
			return $dates{$1} . " " . $2;
		}
		else
		{
			print "No date [$1]";
			return $datetime;
		}
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
            id    => $_->{"id"},
            title => unidecode($_->{"title"}),
            desc  => unidecode($_->{"description"}),
            venue => $_->{"venue"},
            type  => $types{$_->{"type"}},
            by    => unidecode($_->{"speaker"}),
            start => format_date($_->{"start_date"}),
            end   => format_end_time($_->{"start_date"}, $_->{"end_date"}),
            sdate => $_->{"start_date"},
            edate => $_->{"end_date"},
        };

        $events[-1]->{day} = (split / /, $events[-1]->{start})[0];
    }

    @events;
}