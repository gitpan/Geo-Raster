## @class Geo::Layer
# @brief An abstract base class for geospatial layers
package Geo::Layer;

use 5.008;
use strict;
use warnings;
use Carp;
use FileHandle;
use File::Basename;
use POSIX;

use vars qw(@ISA);

require Exporter;
require DynaLoader;
use AutoLoader 'AUTOLOAD';

@ISA = qw(Exporter DynaLoader);

use vars qw( %DATA_TYPE );

our %EXPORT_TAGS = ( 'all' => [ qw( ) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

%DATA_TYPE = (Integer => 1, Real => 2, String => 3); # the first two should match those in libral

## @cmethod @datatypes()
#
# @brief Returns a list of valid data types for attribute data.
# @return a list of valid data types for attribute data (strings).
sub data_types {
    my($class) = @_;
    return keys %DATA_TYPE;
}

=pod

=head1 NAME

Geo::Layer - An abstract base class for geospatial data layers

The documentation of this class is in doxygen format.

=cut

## @method Geo::Layer new(%param)
#
# @brief Creates a new layer with the given parameters.
# @param[in] param (optional) Named parameters:
# - name Name of layer as string.
# - alpha Alpha value of the layer as an integer (0 ... 255). 255 is the default
# value.
# - visible Visibility of layer as integer (0/1). 1 means visible, 
# which is also the default option.
# - palette_type A supported palette type as string. All supported datatypes can 
# be gotten from palette_types() method. Default is 'Single color'.
# - symbol_type A supported symbol type as string. All supported symbols can 
# be gotten from symbol_types() method. As default no symbol is used.
# - copy Another Geo::Layer, which values are copied to this layer. If given 
# then all other given values (name, alpha,...) are useless.
# @return The created object.
sub new {
    my($package, %params) = @_;
    my $self = {};
    $self->{COLOR_TABLE} = [];
    bless $self => (ref($package) or $package);
}

sub DESTROY {
    my $self = shift;
}

## @method @color_table($color_table)
#
# @brief Get or set the color table.
# @param[in] color_table (optional) Name of file from where the color table can be 
# read.
# @return Current color table, if no parameter is given.
# @exception A filename is given, which can't be opened/read or does not have a 
# color table.

## @method @color_table(Geo::GDAL::ColorTable color_table)
#
# @brief Get or set the color table.
# @param[in] color_table (optional) Geo::GDAL::ColorTable.
# @return Current color table, if no parameter is given.

## @method @color_table(listref color_table)
#
# @brief Get or set the color table.
# @param[in] color_table (optional) Reference to an array having the color table.
# @return Current color table, if no parameter is given.
sub color_table {
    my($self, $color_table) = @_;
    unless (defined $color_table) {
		$self->{COLOR_TABLE} = [] unless $self->{COLOR_TABLE};
		return $self->{COLOR_TABLE};
    }
    if (ref($color_table) eq 'ARRAY') {
		$self->{COLOR_TABLE} = [];
		for (@$color_table) {
	    	push @{$self->{COLOR_TABLE}}, [@$_];
		}
    } elsif (ref($color_table)) {
		for my $i (0..$color_table->GetCount-1) {
	    	my @color = $color_table->GetColorEntryAsRGB($i);
	    	push @{$self->{COLOR_TABLE}}, [$i,@color];
		}
    } else {
		my $fh = new FileHandle;
		croak "can't read from $color_table: $!\n" unless $fh->open("< $color_table");
		$self->{COLOR_TABLE} = [];
		while (<$fh>) {
	    	next if /^#/;
	    	my @tokens = split /\s+/;
	    	next unless @tokens > 3;
	    	$tokens[4] = 255 unless defined $tokens[4];
	    	for (@tokens) {
				$_ =~ s/\D//g;
	    	}
	    	for (@tokens[1..4]) {
				$_ = 0 if $_ < 0;
				$_ = 255 if $_ > 255;
	    	}
	    	push @{$self->{COLOR_TABLE}},\@tokens;
		}
		$fh->close;
    }
}

## @method save_color_table($filename)
#
# @brief Saves the layers color table into the file, which name is given as 
# parameter.
# @param[in] filename Name of file where the color table is saved.
# @exception A filename is given, which can't be written to.
sub save_color_table {
    my($self, $filename) = @_;
    my $fh = new FileHandle;
    croak "can't write to $filename: $!\n" unless $fh->open("> $filename");
    for my $color (@{$self->{COLOR_TABLE}}) {
	print $fh "@$color\n";
    }
    $fh->close;
}

## @cmethod boolean exists($filename)
# @brief Checks if save with the same filename would overwrite existing data.
sub exists {
}

## @method schema($schema)
#
# @brief Get or set the schema of the layer.
# @param[in] schema (optional) The new schema of the layer.
# @return The current schema of the layer.
sub schema {
    my($self, $schema) = @_;
    return {};
}

## @method select(%params)
#
# @brief Make a selection based on the information provided.
# @param params named params, subclasses may recognize more than what's described here
# - <I>selected_area</I> A Geo::OGR::Geometry object representing the area the user has selected
sub select {
}

## @method features(%params)
#
# @brief Should return features (objects) as an arrayref from the layer based on some criteria.
sub features {
}

## @method selected_features(%params)
#
# @brief Should return selected features (objects) from the layer based on some criteria.
sub selected_features {
}

## @ignore
sub MIN {
    $_[0] > $_[1] ? $_[1] : $_[0];
}

## @ignore
sub MAX {
    $_[0] > $_[1] ? $_[0] : $_[1];
}

1;
__END__
=pod

=head1 SEE ALSO

This module should be discussed in geo-perl@list.hut.fi.

The homepage of this module is http://libral.sf.net.

=head1 AUTHOR

Ari Jolma, E<lt>ari.jolma at tkk.fiE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2007 by Ari Jolma

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut
