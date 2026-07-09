#!/usr/bin/env perl

use strict;
use warnings;

use Search::Indexer;
use ScheduleReader;

# Start by reading the schedule JSON...
my %events = ();
for my $event (ScheduleReader::from_file("schedule.json"))
{
  $events{$event->{id}} = $event;
}

# Remove any old index that might exist 
for my $file (glob "*.bdb")
{
  unlink $file;
}

# Feed the salient details of each event into the index
my $ix = new Search::Indexer(dir => ".", writeMode => 1);
for my $event (values %events) {
  my $docId = $event->{id};
  my $docContent = join("\n", map $event->{$_}, qw/title by venue desc/);
  $ix->add($docId, $docContent);
}
