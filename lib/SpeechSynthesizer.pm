package SpeechSynthesizer;

use strict;
use warnings;

use strict;
use warnings;

use Paws;

die "AWS credentials required in environment" unless $ENV{AWS_ACCESS_KEY} && $ENV{AWS_SECRET_KEY};

my $polly = Paws->service('Polly', region => 'eu-west-2');

my %ssml_entities = (
    "'" => "&apos;",
    "\"" => "&quot;",
    "<" => "&lt;",
    ">" => "&gt;",
);

my $newsreader = 1;
my $mp3_dir = "sound-files/mp3";
my $pcm_dir = "sound-files/pcm";

sub make_newsreader_ssml($)
{
    my $text = shift;    

    $text =~ s/&/&amp;/g;

    while (my ($char, $entity) = each %ssml_entities)
    {
        $text =~ s/$char/$entity/g;
    }

    '<speak><amazon:domain name="news">' . $text . '</amazon:domain></speak>';
}

sub generate_mp3($$)
{
    my $text = shift;
    my $filename = shift;
    my $type = 'text';

    if (-f $filename)
    {
        print "$filename already exists, not re-generating.\n";
        return 1;
    }

    if ($newsreader)
    {
        $text = make_newsreader_ssml($text);
        $type = 'ssml';
    }

    my $res = $polly->SynthesizeSpeech(
        VoiceId => 'Amy',
        Engine => 'neural',
        Text => $text,
        TextType => $type,
        SampleRate => 8000,
        OutputFormat => 'mp3',
    );

    open(MP3, ">", $filename) or die "Cannot open $filename for writing: $!";
    binmode(MP3);
    print MP3 $res->AudioStream or die "Failed to write to $filename: $!";
    close(MP3);

    1;
}

sub convert_to_pcm($$)
{
    my $mp3 = shift;
    my $pcm = shift;

    if (-f $pcm)
    {
        print "$pcm already exists, not re-generating.\n";
        return 1;
    }

    my $command = "ffmpeg -hide_banner -loglevel error -stats -i \"$mp3\" -f -lavfi -f mulaw \"$pcm\"";

    die "Cannot spawn '$command': $!" if system($command) == -1;
    die "Potential ffmpeg error $?" if $?;
}

sub generate($$)
{
    my $text = shift;
    my $filename = shift;

    generate_mp3($text, "$mp3_dir/$filename.mp3") && convert_to_pcm("$mp3_dir/$filename.mp3", "$pcm_dir/$filename.ulaw");
}

sub create_directories($;$)
{
    my $subdir  = shift || ".";
    my $basedir = shift || "sound-files";

    mkdir $basedir or die "Cannot create directory $basedir: $!" unless -d $basedir;

    for (qw(mp3 pcm))
    {
        mkdir "$basedir/$_" or die "Cannot create directory $basedir/$_: $!" unless -d "$basedir/$_";
    }

    $mp3_dir = "$basedir/mp3";
    $pcm_dir = "$basedir/pcm";

    if ($subdir ne ".")
    {
        for (qw(mp3 pcm))
        {
            mkdir "$basedir/$_/$subdir" or die "Cannot create directory $basedir/$_/$subdir: $!" unless -d "$basedir/$_/$subdir";
        }

        $mp3_dir .= "/$subdir";
        $pcm_dir .= "/$subdir";
    }
}

1;