#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use Search::Indexer;
use ScheduleReader;
use TelstarFrame;
use Paginator;

###
# Various settings and suchlike
###

# Which year are we in, and where are the index and schedule files?
my $year     = 2026;
my $basedir  = ".";
my $filename = "$basedir/schedule.json";

# Maximum number of results to return so the frame list doesn't get out of hand!
my $max_results = 100;

$TelstarFrame::service = "[R][n][C] EMF ${year}[W]Live   [-]";
$TelstarFrame::directory = "output_frames";

# Wrap widths are one less than expected because if the text runs into the
# final column, adding a linebreak causes a blank line.  Until TelstarFrame
# can correctly calculate line widths accounting for markup, we work around
# this by just avoiding the last column!
my $index_wrapper = Text::Wrapper->new(columns => 36);
my $event_wrapper = Text::Wrapper->new(columns => 38);

# How to display the various flags in schedule entry pages...
# (note the trailing spaces so that invisible flags don't add
# a joining space if we join(" ") them together)
my %flags = (   # ... when false		... when true
	friendly => ["",					"[G]Family Friendly "],
	recorded => ["[R]Not Recorded ",	""],
	ticketed => ["",					"[Y]Ticketed "],
);

# Start by reading the schedule JSON...
my %events = ();
for my $event (ScheduleReader::from_file($filename))
{
  $events{$event->{id}} = $event;
}

# Consult the index for matching event IDs
my $ix = new Search::Indexer(dir => $basedir);
my $terms = join(" ", @ARGV);

my $result      = $ix->search($terms);
my $scores      = $result->{scores};
my $n_docs      = keys %$scores;
my @best_docs   = (sort {$scores->{$b} <=> $scores->{$a}} keys %$scores);
my $killedWords = join ", ", @{$result->{killedWords}};

# Keep track of whether we truncated the list to the maximum result count
my $results_truncated = 0;

if (@best_docs > $max_results) {
    $#best_docs = $max_results - 1;
    $results_truncated = 1;
}

sub add_wrapped_event_field($$$)
{
	my ($frame, $field, $value) = @_;

	my $field_wrapper = Text::Wrapper->new(columns => 38,
	                                       par_start => "",
	                                       body_start => " "x(2 + length $field));
	my @wrapped_lines = split /\n/, $field_wrapper->wrap($field . ": " . $value);
	my $wrapped_first = shift @wrapped_lines;
	$wrapped_first =~ s/: /:[C]/;

	$frame->add_line("[W]$wrapped_first");
	map { $frame->add_line("[C]$_"); } @wrapped_lines;
}

# Generate the detail frames for an event
sub generate_event_detail_frames($$$@)
{
	my ($event, $entry_frame_number, $on_new_page, @header) = @_;

	my $schedule_line = sprintf("[C]%s - %s  %-17.17s", $event->{start}, $event->{end}, $event->{venue});
	my @flags = map $flags{$_}->[$event->{$_}], sort keys %flags;
	my $flags_line = join "", @flags;

	my $frame = new TelstarFrame($entry_frame_number, "a", 1);
	my $paginator = new Paginator($frame,
	{
		header => [ @header, $schedule_line ],
		prefix => " ",
		on_new_page => $on_new_page
	});

	$on_new_page->($frame);

	my @wrapped_title = split /\n/, $event_wrapper->wrap($event->{title});
	my @wrapped_by    = split /\n/, $event_wrapper->wrap("$event->{type} by " . $event->{by});

	my $wrapped_first = shift @wrapped_by;
	$wrapped_first =~ s/ by / by[C]/;

	# Add the title over as many lines as needed
	map { $frame->add_line("[Y]$_"); } @wrapped_title;

	# And the event type and first line of speaker list
	$frame->add_line("[W]$wrapped_first");

	# Rest of the speaker list, if any
	map { $frame->add_line("[C]$_"); } @wrapped_by;
	$frame->add_line("");

	# Flags, cost, age range, max. attendees (as appropriate)
	$frame->add_line($flags_line) if $flags_line;
	add_wrapped_event_field($frame, "Cost", $event->{cost}) if $event->{cost};
	add_wrapped_event_field($frame, "Ages", $event->{ages}) if $event->{ages};
	add_wrapped_event_field($frame, "Capacity", $event->{capacity}) if $event->{capacity};

	# Reminder code followed by a blank line to set off the header block
	my $reminderCode = undef; #$event->{reminder};
	# $frame->add_line("[W]ReminderCode (call 555-5555):[C]$reminderCode");

	# A blank line to set off the header block, if needed
	$frame->add_line("") if $flags_line || $event->{cost} || $event->{ages} ||
	                        $event->{capacity} || $reminderCode;

	# Content note (if any) before description
	if (defined $event->{cws} && $event->{cws} ne "")
	{
		my @wrapped_cws = split /\n/, $event_wrapper->wrap("Content notes: " . $event->{cws});
		my $wrapped_first = shift @wrapped_cws;
		$wrapped_first =~ s/: /:[W]/;

		$frame->add_line("[Y]$wrapped_first");
		map { $frame->add_line("[W]$_"); } @wrapped_cws;
		$frame->add_line("");
	}

	if ($frame->count_lines() > 22)
	{
		print "! Event $event->{id} has header block exceeding a single frame, truncating...\n";
		$#{$frame->{content}{lines}} = 21;
	}

	# And finally we can add the complete event description
	# which could easily span several pages.
	$paginator->paginate_text($event->{desc});
}

# Generate a complete set of frames for this search, including the summary list and detail pages
sub generate_search_result_frames($$@)
{
	my ($root, $heading, @events) = @_;

	my @header = (
		"[R][n][D][Y]WHAT'S ON:[W]$heading",
		"",
		"",
        "[Y]Showing results[W]%u[Y]-[W]%u[Y]of over[W]%u",
        ""
	);
    my $result_metadata_line = 3;
    $header[$result_metadata_line] =~ s/ over// unless $results_truncated;

    my @page_header_template = @header;
    $page_header_template[$result_metadata_line] =~ s/s\[W\]%u\[Y\]-//;

 	my $first_index_frame = ($root)      * 1000;
	my $first_entry_frame = ($root + 10) * 1000;

	my $index = new TelstarFrame($first_index_frame, "a", 1);
	my $index_paginator = new Paginator($index,
	{
		header => \@header,
		continues => "",
		continued => "",
		on_new_page => sub {
			my $frame = shift;
			$frame->set_route(0, 1);	# Route 0 back to schedules page
			1;
		}
	});
	my $index_key = 0;

    my $first_result_on_page = 1;
    my $total_results = @events;
    my $update_header = sub($) {
        my $last_result_on_page = shift;

        my $header_line = sprintf($header[$result_metadata_line],
                                  $first_result_on_page,
                                  $last_result_on_page,
                                  $total_results);
        $index_paginator->{frame}->{content}->{lines}->[$result_metadata_line] = $header_line;
    };

	$index->set_route(0, 1);			# Route 0 back to schedules page
	$index->{"pid"}{"sequential"} = 1;

	for my $event_idx (0..$#events)
	{
		my $event = $events[$event_idx];
		my $entry_frame = $first_entry_frame + $event->{id};

		# Build the index entry for this event
		my $schedule_line = sprintf("[C]%s - %s  %-18.18s", $event->{start}, $event->{end}, $event->{venue});
		my @wrapped_title = split /\n/, $index_wrapper->wrap($event->{title});
		my @wrapped_by    = split /\n/, $index_wrapper->wrap("$event->{type} by " . $event->{by});

		my $wrapped_first = shift @wrapped_by;
		$wrapped_first =~ s/ by / by[C]/;
		
		my @index_entry = ();
		push @index_entry, map "  [Y]$_", @wrapped_title;
		push @index_entry, "  [W]$wrapped_first";
		push @index_entry, map "  [C]$_", @wrapped_by;
		push @index_entry, "";

		# Set menu number and add index entry to index page
		if (! $index_paginator->has_room_for(@index_entry))
		{
			$index_paginator->new_page();
			$index_key = 0;
            $first_result_on_page = $event_idx + 1;
		}
        else
        {
            $update_header->($event_idx + 1);
        }

		unshift @index_entry, "[B]" . ++$index_key . $schedule_line;
		$index_paginator->add_text_block(@index_entry);
		$index_paginator->frame()->set_route($index_key, $entry_frame);

		# Work out prev/next routes for event detail frames...
		my $prev_event = $event_idx > 0 ? $events[$event_idx - 1] : undef;
		my $next_event = $event_idx < $#events ? $events[$event_idx + 1] : undef;
		my $prev_entry_frame = defined $prev_event ? $first_entry_frame + $prev_event->{id} : undef;
		my $next_entry_frame = defined $next_event ? $first_entry_frame + $next_event->{id} : undef;

		my $set_routes = sub
		{
			my $frame = shift;

			# Route 0 back to index frame on correct page
			$frame->set_route(0, $index_paginator->frame()->{"pid"}{"page-no"});

			# Route 7 and 9 to prev/next events, if possible
			$frame->set_route(7, $prev_entry_frame) if defined $prev_entry_frame;
			$frame->set_route(9, $next_entry_frame) if defined $next_entry_frame;

			1;
		};
        
        # ... and finally create the detail frames
        my @page_header = @page_header_template;
        $page_header[$result_metadata_line] = sprintf($page_header_template[$result_metadata_line],
                                                      $event_idx + 1, $total_results);
            
		generate_event_detail_frames($event, $entry_frame, $set_routes, @page_header);
	}

	$index_paginator->finish();
}

# Format the result list into a set of frames, which will be sent to stdout
# so surround them with [ ] to form a valid JSON array.  This is ugly.
print "[\n";
generate_search_result_frames(903, "Search Results", map($events{$_}, @best_docs));
print "{}\n]\n";