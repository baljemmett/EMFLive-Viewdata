#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use ScheduleReader;

sub get_preposition_for_venue
{
    my $preposition = "in";
    
    for (@_)
    {
        $preposition = "on" if /Stage/;
        $preposition = "in the" if /Youth|Bar|Lounge|Tent|smiths/;
        $preposition = "at" if /AMSAT|Bomb|SEM/;
        $preposition = "" if /^Outside/;
        last;
    }

    $preposition;
}

sub total_characters
{
    my $total  = 0;
    map { $total += length } @_;
    $total;
}

# Which year are we in, and where's the schedule file?
my $year     = 2022;
my $filename = "$year.json";

# Start by reading the schedule JSON...
my @events = ScheduleReader::from_file($filename);
my @all_venues = ScheduleReader::all_venues(@events);

my %intro_lines = ();
for (@all_venues)
{
    my $preposition = get_preposition_for_venue $_;
    $intro_lines{$_} = "You asked to be reminded about the event starting shortly $preposition $_: ";
}

my @intro_lines = values %intro_lines;
my @title_lines = map $_->{title}, @events;

my @combined_lines = map $intro_lines{$_->{venue}} . $_->{title}, @events;
my @detailed_lines = map {
    my $title = $_->{title};
    my $where = $_->{venue};
    my $what = lc($_->{type});
    my $whom = $_->{by};

    my $preposition = get_preposition_for_venue $where;

    "You asked to be reminded about the $what by $whom starting shortly $preposition $where:\n\n$title";
} @events;

print "A randomly selected event announcement:\n";
my $event = $events[rand @events];
print $intro_lines{$event->{venue}}, $event->{title}, "\n\n";

print "A not-very randomly selected detailed event announcement:\n";
print grep(/copper/, @detailed_lines), "\n\n";

print  "Speech synthesis statistics:\n";
printf "    Venue introduction lines ...: %u lines, %u characters\n", scalar @intro_lines, total_characters(@intro_lines);
printf "    Event description lines ....: %u lines, %u characters\n", scalar @title_lines, total_characters(@title_lines);
printf "    Total size of above ........: %u lines, %u characters\n", scalar @intro_lines + scalar @title_lines, total_characters(@intro_lines, @title_lines);
printf "    Combined announcements .....: %u lines, %u characters\n", scalar @combined_lines, total_characters(@combined_lines);
printf "    Detailed announcements .....: %u lines, %u characters\n", scalar @detailed_lines, total_characters(@detailed_lines);
