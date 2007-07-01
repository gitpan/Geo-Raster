## @class Geo::Raster::IO
# @brief Adds input/output methods into Geo::Raster
package Geo::Raster;

## @method void gdal_open(%params)
#
# @brief The subroutine opens a saved raster dataset from a file.
#
# @param[in] params is a list of named parameters:
# - <I>filename</I>.
# - <I>band</I> (optional). Default is 1.
# - <I>load</I> (optional). Default is false, calls cache without parameters if 
# true.
# @exception The file has a raster grid, whose cells are not squares.
# @exception The file has a raster grid, which is not a strict north up grid.
# @note This subroutine is usually called internally from the constructor.
sub gdal_open {
    my($self, %params) = @_;
    my $dataset = Geo::GDAL::Open($params{filename});
    croak "Geo::GDAL::Open failed for ".$params{filename} unless $dataset;
    my $t = $dataset->GetGeoTransform;
    unless ($t) {
		@$t = (0,1,0,0,0,1);
    }
    $t->[5] = abs($t->[5]);
    croak "Cells are not squares: dx=$t->[1] != dy=$t->[5]" 
	unless $t->[1] == $t->[5];
    croak "The raster is not a strict north up image."
	unless $t->[2] == $t->[4] and $t->[2] == 0;
    my @world = ($t->[0], $t->[3]-$dataset->{RasterYSize}*$t->[1],
		 $t->[0]+$dataset->{RasterXSize}*$t->[1], $t->[3]);
    my $band = $params{band} || 1;

    $self->{GDAL}->{dataset} = $dataset;
    $self->{GDAL}->{world} = [@world];
    $self->{GDAL}->{cell_size} = $t->[1];
    $self->{GDAL}->{band} = $band;

    my $b = $dataset->GetRasterBand($band);
    my $colortable = $b->GetRasterColorTable;

    Geo::Layer::color_table($self, $colortable) if $colortable;

    if ($params{load}) {
	cache($self);
	delete $self->{GDAL};
    }
    return 1;
}

## @cmethod Geo::Raster cache($min_x, $min_y, $max_x, $max_y, $cell_size)
#
# @brief Creates a new raster grid using libral and creates the boundaries and 
# cell sizes with the given parameters.
#
# - The created grid is returned only if needed, else this object is 
# switched with the created object.
# - The given bounding box clipped to the bounding box of the dataset. The
# resulting bounding box of the work raster is always adjusted to pixel
# boundaries of the dataset.
# - If the cell_size is not given, the cell_size of the dataset is used.
# - If the cell_size is specified, it is used if it is larger than the
# cell_size of the dataset.
#
# @param[in] min_x The smallest x value of the datasets bounding box.
# @param[in] min_y The smallest y value of the datasets bounding box.
# @param[in] max_x The highest x value of the datasets bounding box.
# @param[in] max_y The highest y value of the datasets bounding box.
# @param[in] cell_size Lenght of cells one edge.
# @return Geo::Raster.

## @cmethod Geo::Raster cache(Geo::Raster model_grid)
#
# @brief Creates a new raster grid from a GDAL raster.
#
# - The created grid is returned only if needed, else this object is 
# switched with the created object.
# - Uses the other raster grids world (bounding box, cell_size). 
# - If no Geo::Raster is given, gets all data into a libral raster 1:1.
# - The bounding box of the model is clipped to the bounding box of the dataset. 
# The resulting bounding box of the work raster is always adjusted to pixel
# boundaries of the dataset.
#
# @param[in] model_grid (optional) A reference to an another Geo::Raster object, 
# which is used as a model for world boundaries and cell size. Else these 
# parameters are gotten from this object.
# @return The cached raster in a scalar context, otherwise changes the
# object self.
# @exception The given parameter is not a reference to an object of type 
# Geo::Raster.
sub cache {
    my $self = shift;

    my $gdal = $self->{GDAL};

    croak "no GDAL" unless $gdal;
    
    my $clip = $gdal->{world};
    my $cell_size = $gdal->{cell_size};

    if (defined $_[0]) {
	if (@_ == 1) { # use the given grid as a model

	    croak "usage: \$grid->cache(\$another_grid)" unless isa($_[0], 'Geo::Raster');

	    if ($_[0]->{GDAL}) {
		$clip = $_[0]->{GDAL}->{world};
		$cell_size = $_[0]->{GDAL}->{cell_size};
	    } else {
		$clip = ral_grid_get_world($_[0]->{GRID}); 
		$cell_size = ral_grid_get_cell_size($_[0]->{GRID});
	    }
	} else {
	    $clip = [@_[0..3]];
	    if ($clip->[1] > $clip->[3]) { # cope with ul,dr
		my $tmp = $clip->[3];
		$clip->[3] = $clip->[1];
		$clip->[1] = $tmp;
	    }
	    $cell_size = $_[4] if defined($_[4]) and $_[4] > $cell_size;
	}
    }

    my $gd = ral_grid_create_using_GDAL($gdal->{dataset},
	    $gdal->{band}, @$clip, $cell_size);

    return unless $gd;

    my $band = $gdal->{dataset}->GetRasterBand($gdal->{band});
    my $nodata_value = $band->GetNoDataValue;
    if (defined $nodata_value and $nodata_value ne '') {
	ral_grid_set_nodata_value($gd, $nodata_value);
    }
    
    if (defined wantarray) {
	$gd = Geo::Raster::new($gd);
	return $gd;
    } else {
	ral_grid_destroy($self->{GRID}) if $self->{GRID};
	delete $self->{GRID};
	$self->{GRID} = $gd;
	attributes($self);
    }
}

## @method void save($filename, $format)
#
# @brief Save libral raster into a pair of hdr and bil files.
#
# Possibly also the color table and color bins are saved into a
# clr-file. Only genuine libral rasters are saved. Typically the
# extension is chopped of from the filename, but if it is .asc, the
# format is set to Arc/Info ASCII.
# @param[in] filename (optional) Filename for the data files, without the 
# extension. If not given then the method tries to use the name attribute of the 
# grid.
# @param[in] format (optional). If given and contains Arc/Info ASCII, the grid 
# is saved as such.
# @exception The given filename is not valid, or the file does not open with 
# writing permissions.
sub save {
    my($self, $filename, $format) = @_;

    croak "Geo::Raster object not saved because it is a GDAL dataset."if $self->{GDAL};

    $filename = $self->name() unless defined $filename;
    croak "usage: \$grid->save(\$filename)" unless defined $filename;

    my $ext;
    $ext = $1 if $filename =~ /\.(\w+)$/;
    $ext = '' unless defined $ext;
    $filename =~ s/\.(\w+)$//;

    if ($ext eq 'asc' or ($format and $format =~ /arc\/info ascii/i)) {
	ral_grid_save_ascii($self->{GRID}, "$filename.asc");
	return;
    }

    my $fh = new FileHandle;
    croak "Can't write to $filename.hdr: $!\n" unless $fh->open(">$filename.hdr");

    my($datatype, $M, $N, $cell_size, $minX, $maxX, $minY, $maxY, $nodata_value) = 
	$self->attributes();

    # these depend on how libral is configured! lookup needed
    my $nbits = $datatype == $REAL_GRID ? 32 : 16;
    my $pt = $datatype == $REAL_GRID ? 'F' : 'S';
    my $byteorder = $Config{byteorder} == 4321 ? 'M' : 'I';

    print $fh "BYTEORDER     $byteorder\n";
    print $fh "LAYOUT      BIL\n";
    print $fh "NROWS         $M\n";
    print $fh "NCOLS         $N\n";
    print $fh "NBANDS        1\n";
    
    print $fh "PIXELTYPE     $pt\n";
    
    print $fh "NBITS         $nbits\n";
    my $rowbytes = $nbits/8*$N;
    print $fh "BANDROWBYTES         $rowbytes\n";
    print $fh "TOTALROWBYTES        $rowbytes\n";
    print $fh "BANDGAPBYTES         0\n";
    print $fh "NODATA        $nodata_value\n" if defined $nodata_value;
    $minX += $cell_size / 2;
    $maxY -= $cell_size / 2;
    print $fh "ULXMAP        ",_with_decimal_point($minX),"\n";
    print $fh "ULYMAP        ",_with_decimal_point($maxY),"\n";
    print $fh "XDIM          ",_with_decimal_point($cell_size),"\n";
    print $fh "YDIM          ",_with_decimal_point($cell_size),"\n";
    $fh->close;
    ral_grid_write($self->{GRID}, $filename.'.bil');
    
    if ($datatype == $INTEGER_GRID and $self->{COLOR_TABLE} and @{$self->{COLOR_TABLE}}) {
	croak "can't write to $filename.clr: $!\n" unless $fh->open(">$filename.clr");
	for my $color (@{$self->{COLOR_TABLE}}) {
	    next if $color->[0] < 0 or $color->[0] > 255;
	    # skimming out data because this format does not support all
	    print $fh "@$color[0..3]\n";
	}
	$fh->close;
	eval {
	    $self->save_color_table("$filename.color_table");
	};
	print STDERR "warning: $@" if $@;
    }
    if ($self->{COLOR_BINS} and @{$self->{COLOR_BINS}}) {
	eval {
	    $self->save_color_bins("$filename.color_bins");
	};
	print STDERR "warning: $@" if $@;
    }
}

## @method void print(%param) 
#
# @brief Prints the values of the raster grid into stdout.
# @param[in] param NOT USED!
# @todo Check what param should be used for, for example to give the coordinates 
# of a single cells values to be printed.
sub print {
    my($self,%param) = @_;
    ral_grid_print($self->{GRID});
}

## @method void dump($to)
#
# @brief Prints the data (but not metadata, like size or other attributes of the 
# grid) of the raster into a file or stdout.
# @param[in] to (optional). Filename or a filehandle.
# @exception The given filename is not valid, or the file does not open with 
# writing permissions.
sub dump {
    my($self, $to) = @_;
    my $close;
    if ($to) {
	unless (ref($to) eq 'GLOB' or ref($to) eq 'FileHandle') {
	    my $fh = new FileHandle;
	    croak "Can't dump to $to: $!" unless $fh->open(">$to");
	    $to = $fh;
	    $close = 1;
	}
    } else {
	$to = \*STDOUT;
    }
    my $points = $self->array();
    for my $point (@$points) {
	print $to "$point->[0], $point->[1], $point->[2]\n";
    }
    $to->close if $close;
}

## @method void restore($from)
#
# @brief Reads the data (but not metadata, like size or other attributes of the 
# grid) of the raster from a file or stdin.
# @param[in] from (optional) filename or a filehandle. If not given data is read 
# from stdin.
# @exception The given filename is not valid, or the file does not open.
sub restore {
    my($self, $from) = @_;
    my $close;
    if ($from) {
	unless (ref($from) eq 'GLOB' or ref($from) eq 'FileHandle') {
	    my $fh = new FileHandle;
	    croak "Can't restore from $from: $!" unless $fh->open($from);
	    $from = $fh;
	    $close = 1;
	}
    } else {
	$from = \*STDIN;
    }
    ral_grid_set_all($self->{GRID}, 0);
    while (<$from>) {
	my($i, $j, $x) = split /,/;
	ral_grid_set($self->{GRID}, $i, $j, $x);
    }
    $from->close if $close;
}

## @method void save_as_image($filename, $type, listref option_keys, listref option_values)
#
# @brief Saves the grid as image (*.jpeg, *.png, *.tiff, *.ico or *.bmp).
#
# @param[in] filename A string containing the filename where the image is saved.
# @param[in] type Name of format of the image to create. 
# Supported are jpeg, png, tiff, ico and bmp.
# @param[in] option_keys (optional). Name of options to set. Can be used for passing metadata.
# @param[in] option_values (optional). Values for the named options.
sub save_as_image {
    my($self, $filename, $type, $option_keys, $option_values) = @_;
    my $b = ral_pixbuf_create_from_grid($self->{GRID});
    $self->render($b, 255);
    $option_keys = [] unless $option_keys;
    $option_values = [] unless $option_values;
    ral_pixbuf_save($b, $filename, $type, $option_keys, $option_values);
    ral_pixbuf_destroy($b);
}

1;
