package Paginator;

use strict;
use warnings;
use TelstarFrame;
use Text::Wrapper;
use Data::Dumper;

sub defaults_to
{
    my ($arg, $default) = @_;
    defined $arg ? $arg : $default;
}

sub new
{
    my ($class, $frame, $args) = @_;

    my $self = bless {
        frame => $frame,
        header => defaults_to($args->{header}, []),
        width => defaults_to($args->{width}, 39),
        height => defaults_to($args->{height}, 22),
        prefix => defaults_to($args->{prefix}, ""),
        nav_only  => defaults_to($args->{nav_only},  "[R][n][Y]Press[W]0[Y]to return to index."),
        nav_first => defaults_to($args->{nav_first}, "[R][n][Y]Press[W]0[Y]to return,[W]#[Y]for next page."),
        nav_mid   => defaults_to($args->{nav_mid},   "[R][n][Y]Press[W]*#[Y]for prev,[W]#[Y]for next page."),
        nav_last  => defaults_to($args->{nav_last},  "[R][n][Y]Press[W]*#[Y]for prev or[W]0[Y]for index."),
        continues => defaults_to($args->{continues}, "[Y]... continues on next page"),
        continued => defaults_to($args->{continued}, "[Y]... continued from previous page"),
    }, $class;
}

sub split_page
{
    my ($self, $frame) = @_;

    $frame->add_line($self->{continues}) if $self->{continues};
    $frame->{"navmessage-select"} = $frame->{"pid"}{"frame-id"} eq "a" ? $self->{nav_first} : $self->{nav_mid};

    $frame->write();
    $frame = $frame->next_subpage();
    $self->{frame} = $frame;
    map { $frame->add_line($_) } @{$self->{header}};

    $frame->add_line($self->{continued}) if $self->{continued};

    my $remaining = $self->{height} - $frame->count_lines();

    ($frame, $remaining)
}

sub paginate_text
{
    my ($self, $text) = @_;

    $text =~ s/\t/ /g;

    my $wrapper = Text::Wrapper->new(columns => $self->{width},
                                     par_start => $self->{prefix},
                                     body_start => $self->{prefix});

    my @lines = split /\n/, $wrapper->wrap($text);

    my $frame = $self->{frame};
    my $remaining = $self->{height} - $frame->count_lines();

    my $orphan_threshold = $self->{continues} ? 2 : 1;

    push @lines, "";

    my @paragraph = ();
    while (@lines)
    {
        my $line = shift @lines;

        if ($line !~ /^\s*$/)
        {
            push @paragraph, $line;
            next;
        }

        next if @paragraph == 0;

LAYOUT:
        my $final_para = @lines == 0;
        my $para_lines = @paragraph;

        # Would starting it here leave an orphan on this page?
        if ($remaining < $orphan_threshold && $para_lines > ($final_para ? $orphan_threshold : 1))
        {
            print "Splitting para due to orphan control ($remaining left, $para_lines in para)\n";
            ($frame, $remaining) = $self->split_page($frame);

            # Fall through to lay out paragraph on new page!
        }

        # Does it fit completely?
        if ($para_lines < $remaining || ($para_lines == $remaining && $final_para))
        {
            print "Adding paragraph as-is ($remaining left, $para_lines in para)\n";
            map { $frame->add_line($_) } @paragraph;
            $remaining -= $para_lines;
        }

        # Would it produce a widow on the next page?
        elsif (($para_lines - $remaining) <= $orphan_threshold)
        {
            print "Splitting para due to widow control ($remaining left, $para_lines in para)\n";
            for $line (0..$remaining-($orphan_threshold))
            {
                $frame->add_line(shift @paragraph);
            }

            ($frame, $remaining) = $self->split_page($frame);

            goto LAYOUT;
        }

        # Split the paragraph across as many pages as needed
        else
        {
            print "Splitting paragraph across pages ($remaining left, $para_lines in para)\n";
            while ($remaining-- >= $orphan_threshold)
            {
                $frame->add_line(shift @paragraph);
            }

            goto LAYOUT;
        }

        @paragraph = ();

        # Add blank line between paragraphs unless we're at the bottom of page
        unless ($final_para || $remaining < $orphan_threshold)
        {
            $frame->add_line("");
            $remaining--;
        }
    }

    # Set navigation message on final page appropriately and write it out.
    $frame->{"navmessage-select"} = $frame->{"pid"}{"frame-id"} eq "a" ? $self->{nav_only} : $self->{nav_last};
    $frame->write();
}

1;