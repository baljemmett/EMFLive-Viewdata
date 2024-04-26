#!/usr/bin/env perl

use strict;
use warnings;

use Paws;

die "AWS credentials required in environment" unless $ENV{AWS_ACCESS_KEY} && $ENV{AWS_SECRET_KEY};

my $polly = Paws->service('Polly', region => 'eu-west-2');

my $text = q(You asked to be reminded about the talk by Matthew Harrold starting shortly on Stage B:

Building a copper telephone network at EMF);

my %escapes = (
    "'" => "&apos;",
    "\"" => "&quot;",
    "<" => "&lt;",
    ">" => "&gt;",
);

$text =~ s/&/&amp;/g;

while (my ($char, $entity) = each %escapes)
{
    $text =~ s/$char/$entity/g;
}

my $res = $polly->SynthesizeSpeech(
    VoiceId => 'Amy',
    Engine => 'neural',
    Text => '<speak><amazon:domain name="news">' . $text . '</amazon:domain></speak>',
    TextType => 'ssml',
    SampleRate => 8000,
    OutputFormat => 'mp3',
);

open(MP3, ">", "test-output.mp3");
binmode(MP3);
print MP3 $res->AudioStream;
close(MP3);

print "ffmpeg -i test-output.mp3 -f -lavfi -f mulaw test-output.pcm8000\n";
