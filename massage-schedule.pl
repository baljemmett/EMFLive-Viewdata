#!/usr/bin/env perl

use strict;
use warnings;

use JSON;
use Storable qw(dclone);
use Data::Dumper;

my $input_filename = shift @ARGV;
my $output_filename = shift @ARGV;
my $input_schedule;
my @output_schedule;

die "Must specify both input and output filenames" unless defined $output_filename;

# Start by reading the schedule JSON...
if (open my $input, "<", $input_filename)
{
    # Read the entire file in one go, decoding into a list-of-hashes.
    local $/ = undef;
    $input_schedule = JSON->new->utf8->decode(<$input>);
    close $input;
}
else
{
    die "Cannot open input $input_filename: $!";
}

for my $event (@$input_schedule)
{
    my $occurrences = scalar @{$event->{occurrences}};
    print "Event $event->{id} occurs $occurrences times\n" unless $occurrences == 1;

    for my $occurrence (@{$event->{occurrences}})
    {
        my $event_occurrence = dclone($event);
        delete $event_occurrence->{occurrences};
        for my $key (keys %$occurrence)
        {
            $event_occurrence->{$key} = $occurrence->{$key};
        }

        $event_occurrence->{id} .= sprintf("%02d", $occurrence->{occurrence_num}) unless $occurrences == 1;

        push @output_schedule, $event_occurrence;
    }
}

open my $file, ">", $output_filename or die "Cannot create $output_filename: $!";
print $file JSON->new->utf8->encode(\@output_schedule);
close $file;
