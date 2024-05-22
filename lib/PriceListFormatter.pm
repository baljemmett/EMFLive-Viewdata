package PriceListFormatter;

use strict;
use warnings;
use TelstarFrame;
use Paginator;
use Text::Wrapper;
use Text::Unidecode;

sub new
{
    my ($class, $format, $frame_number, $parent_frame, $header) = @_;

    my @header = ($header, "", "");

    my $frame = new TelstarFrame($frame_number);
    my $paginator = new Paginator($frame,
    {
        header => \@header,
        continues => " "x12 . "[Y]Continues on next frame...",
        continued => "",
        on_new_page => sub {
            my $frame = shift;
            $frame->set_route(0, $parent_frame);
            1;
        }
    });

    $frame->set_route(0, $parent_frame);

    my $self = bless {
        frame => $frame,
        paginator => $paginator,
        shop => $format eq "shop",
        current_section => undef,
        first_in_section => 1,
    }, $class;
}

sub format_item($$)
{
    my $self = shift;
    my $product = shift;

    # "\x1F£19.99" is 7 chars, "\x1F£19.99/bottle" is 14 chars
    my $right_width = $self->{shop} ? 7 : 14;
    my $left_width = 39 - $right_width;
    my $low_stock_indicator = "\x1DLow stock!";
    my $indent = 2;

    my $description;
    my $pricing;
    my $abv = $product->{abv};
    my $low_stock = 0;
    
    if ($product->{base_units_bought})
    {
        $low_stock = ($product->{base_units_remaining} / $product->{base_units_bought}) < 0.1;
    }

    if ($self->{shop})
    {
        $description = unidecode($product->{description});
        $pricing = "\x1F#" . $product->{price};
    }
    else
    {
        my $manufacturer = unidecode($product->{manufacturer});
        my $name = unidecode($product->{name});

        $description = "$manufacturer\x1F$name";
        $pricing = sprintf("\x1F#%s/%s", $product->{price}, $product->{sale_unit_name});

        $indent = length($manufacturer) + 1;
        $indent = 3 if ($indent > 12);
    }

    my $wrapper = Text::Wrapper->new(columns => $left_width - 1,
                                     par_start => "",
                                     body_start => " "x$indent,
                                     wrap_after => "\x1D\x1E\x1F");

    my @lines = split /\n/, $wrapper->wrap($description);
    my $in_name = $self->{shop};

    # Add (internal) colour codes at start of line - \x1E for the manufacturer,
    # \x1F for the product name - we don't know where these may have wrapped so
    # look for the \x1F embedded in the wrap() call above to tell when we've
    # moved from one to the other.
    for my $idx (0..$#lines)
    {
        $lines[$idx] = ($in_name ? "\x1F" : "\x1E") . $lines[$idx];
        $in_name = 1 if $lines[$idx] =~ /\x1F/;
    }

    # We need at least two lines if there's an ABV or stock indicator to display
    if (@lines == 1 && ($low_stock || defined $abv))
    {
        push @lines, "";
    }

    if ($low_stock)
    {
        # Room for low stock indicator at end of second line, before ABV?
        if (0 && ($left_width - length($lines[1])) > length($low_stock_indicator))
        {
            # Pad line to full width and then replace tail with indicator
            $lines[1] = sprintf("%-*.*s", $left_width, $left_width, $lines[1]);
            substr($lines[1], -length($low_stock_indicator), length($low_stock_indicator)) = $low_stock_indicator;
        }

        # Do we need to add a third line containing just the indicator?
        elsif (defined $abv && @lines == 2)
        {
            push @lines, sprintf("%39s", $low_stock_indicator);
        }

        # Put it at the end of the last line
        else
        {
            my $line = defined $abv ? 2 : 1;
            $lines[$line] = sprintf("%-*.*s%*s", $left_width, $left_width, $lines[$line], $right_width, $low_stock_indicator);
        }
    } 

    # Add ABV and prices to ends of first and second lines
    $lines[0] = sprintf("%-*.*s%*s", $left_width, $left_width, $lines[0], $right_width, $pricing);

    if (defined $abv)
    {
        my $gravity = sprintf("%5s%% ABV", $abv);
        $lines[1] = sprintf("%-*.*s%*s", $left_width, $left_width, $lines[1], $right_width, $gravity);
    }

    for (@lines)
    {
        s/\x1D/[R]/g;
        s/\x1E/[C]/g;
        s/\x1F/[W]/g;
    }

    return @lines;
}

sub new_section
{
    my ($self, $section) = @_;

    $self->{current_section} = unidecode($section);
    $self->{first_in_section} = 1;
}

sub by_id
{
    return $a->{id} <=> $b->{id};
}

sub by_description
{
    return $a->{description} cmp $b->{description};
}

sub by_manuf_name
{
    return $a->{manufacturer} cmp $b->{manufacturer} ||
           $a->{name} cmp $b->{name};
}

sub list_items
{
    my $self = shift;
    my $order = $self->{shop} ? \&by_description : \&by_manuf_name;

    for my $item (sort $order @_)
    {
        next if ! defined $item->{price};

        my $section = $self->{current_section};
        my @listing = ();

        if (defined $section)
        {
            push @listing, "[Y]$section" . 
                 ($self->{first_in_section} ? ":" : " (continued):");
        }

        push @listing, $self->format_item($item);
        push @listing, "";

        if (! $self->{paginator}->has_room_for(@listing, ""))
        {
            $self->{paginator}->new_page();
        }
        elsif (! $self->{first_in_section})
        {
            shift @listing;
        }

        $self->{paginator}->add_text_block(@listing);
        $self->{first_in_section} = 0;
    }
}

sub finish
{
    my $self = shift;

    $self->{paginator}->finish();
}

1;