package Geo::Raster;

use strict;
use POSIX;
use Carp;
use FileHandle;
use Statistics::Descriptive; # used in zonalfct
use Config; # for byteorder
use gdalconst;
use gdal;

use vars qw(@ISA @EXPORT %EXPORT_TAGS @EXPORT_OK $AUTOLOAD 
	    $VERSION $BYTE_ORDER $INTEGER_GRID $REAL_GRID
	    %COLOR_SCHEMES);

$VERSION = '0.42';

# TODO: make these constants derived from libral:
$INTEGER_GRID = 1;
$REAL_GRID = 2;

%COLOR_SCHEMES = (Grayscale => 0, Rainbow => 1, Colortable => 2);

require Exporter;
require DynaLoader;
use AutoLoader 'AUTOLOAD';

@ISA = qw(Exporter DynaLoader);
@EXPORT = qw();

%EXPORT_TAGS = (types  => [ qw ( $INTEGER_GRID $REAL_GRID ) ],
		logics => [ qw ( &not &and &or ) ],
		db     => [ qw ( &db_connect &db_close &sql &db_initvd) ] );

@EXPORT_OK = qw ( $INTEGER_GRID $REAL_GRID
		  &not &and &or
		  &db_connect &db_close &sql &db_initvd );

sub dl_load_flags {0x01}

bootstrap Geo::Raster $VERSION;

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

use overload ('fallback' => undef,
	      'bool'     => 'bool',
	      '""'       => 'stringify',
	      '='        => 'clone',
	      'neg'      => 'neg',
	      '+'        => 'plus',
	      '-'        => 'minus',	      
	      '*'        => 'times',
	      '/'        => 'over',
	      '%'        => 'modulo',
	      '**'       => 'power',
	      '+='       => 'add',
	      '-='       => 'subtract',
              '*='       => 'multiply_by',
	      '/='       => 'divide_by',
	      '%='       => 'modulus_with',
	      '**='      => 'to_power_of',
	      '<'        => 'lt',
	      '>'        => 'gt',
	      '<='       => 'le',
	      '>='       => 'ge',
	      '=='       => 'eq',
	      '!='       => 'ne',
	      '<=>'      => 'cmp',
	      'atan2'    => 'atan2',
	      'cos'      => 'cos',
	      'sin'      => 'sin',
	      'exp'      => 'exp',
	      'abs'      => 'abs',
	      'log'      => 'log',
	      'sqrt'     => 'sqrt',
	      );


=pod

=head1 NAME

Geo::Raster - Perl extension for raster algebra

=head1 SYNOPSIS

    use Geo::Raster;
or
    use Geo::Raster qw(:types);
or
    use Geo::Raster qw(:types :logics :db);

=head1 DESCRIPTION

Geo::Raster is an object-oriented interface to libral, a C library for
rasters and raster algebra. Geo::Raster makes using libral easy and
adds some very useful functionality to it. libral rasters are
in-memory for fast and easy processing. libral rasters can be created
from GDAL rasters. GDAL provides access to rasters in many formats.

Geo::Raster also adds the required functionality to display rasters in
Gtk2::Ex::Geo.

Each cell in raster/grid is assumed to be a square. 

The grid point represents the center of the cell and not the area of
the cell (when such distinction needs to be made). TODO: This needs
more attention.

A grid is indexed like this:

                   j = 0..N-1  
               ------------------>
              .
i = 0..M-1    .
              .
              .
              V

there is also a (x,y) world coordinate system

        maxY  ^
              .
              .
     y        .
        minY  .
               ------------------>
               minX           maxX
                              x

minX is the left edge of first cell in line.  maxX is the right edge
of the last cell in a line.  minY and maxY represent similarly the
boundaries of the raster.

=head1 BASIC FUNCTIONALITY

=head2 Constructors

Constructors have either a specified set of parameters
in specified order named parameters.

To start with opening a previously saved grid:

    $gd = new Geo::Raster(filename=>"data/dem", load=>1);

or simply

    $gd = new Geo::Raster("data/dem");

A Geo::Raster object maintains internally a gdal object. To get data
from the gdal object into the grid, use the load option (load is not
assumed if only filename is given) or cache method (see below).

To start with a new grid:

    $gd = new Geo::Raster(datatype=>datatype_string, M=>100, N=>100);

or simply

    $gd = new Geo::Raster(1, 100, 100);

or even more simply

    $gd = new Geo::Raster(100, 100);

$datatype is optional, the default is 'integer', 'real' is another
possibility (actual types of integer and real are defined in
libral). Opening a previously saved grid sets the name attribute of
the grid.

Other constructors exist, this is a copy:

    $g2 = new Geo::Raster(copy=>$g1);

or simply

    $gd = new Geo::Raster($g1); 

See below a note about known extensions.

to create a grid with same size use like:

    $g2 = new Geo::Raster(like=>$g1);

In both copy methods the datatype of the result is the same as in the
original grid. Use named parameter datatype to upgrade an integer grid
to a real grid or downgrade a real grid to an integer grid.

=cut

sub _new_grid {
    my $self = shift;
    my $grid = shift;
    return unless $grid;
    ral_gddestroy($self->{GRID}) if $self->{GRID};
    $self->{GRID} = $grid;
    attributes($self);
}

sub interpret_datatype {
    return 0 unless $_[0];
    return $INTEGER_GRID if $_[0] =~  m/^int/i;
    return $REAL_GRID if $_[0] =~ m/^real/i;
    return $REAL_GRID if $_[0] =~ m/^float/i;
    return $INTEGER_GRID if $_[0] == $INTEGER_GRID;
    return $REAL_GRID if $_[0] == $REAL_GRID;
    croak "invalid datatype: '$_[0]'";
    return -1;
}

sub new {
    my $class = shift;
    my $self = {};

    if (@_ == 1 and ref($_[0]) eq 'ral_gridPtr') {
	
	$self->{GRID} = $_[0];

    } elsif (@_ == 1 and ref($_[0]) eq 'Geo::Raster') {
	
	$self->{GRID} = ral_gdnewcopy($_[0]->{GRID}, 0);
	
    } elsif (@_ == 1) {
	
	my $name = shift;
	
	croak "use of undefined value as name in Geo::Raster->new" unless defined $name;

	$self->{NAME} = $name;
	
	gdal_open($self);

    } elsif (@_ == 2 and ($_[0] =~ /\d+/) and ($_[1] =~ /\d+/)) {

	my $M = shift;
	my $N = shift;

	$self->{GRID} = ral_gdnew($INTEGER_GRID, $M, $N);

    } elsif (@_ == 3) {

	my $datatype = shift;
	my $M = shift;
	my $N = shift;

	$self->{GRID} = ral_gdnew(interpret_datatype($datatype), $M, $N);

    }

    my %opt = @_ if @_ and not $self->{GRID}; # using named arguments

    $opt{datatype} = $opt{datatype} ? interpret_datatype($opt{datatype}) : 0;

    if ($opt{copy} and ref($opt{copy}) eq 'Geo::Raster') {

	$self->{GRID} = ral_gdnewcopy($opt{copy}->{GRID}, $opt{datatype});

    } elsif ($opt{use} and ref($opt{use}) eq 'ral_gridPtr') {
	
	$self->{GRID} = $opt{use};
	
    } elsif ($opt{like}) {

	$self->{GRID} = ral_gdnewlike($opt{like}->{GRID}, $opt{datatype});

    } elsif ($opt{filename}) {

	$self->{NAME} = $opt{filename};

	gdal_open($self, %opt);

    } elsif ($opt{M} and $opt{N}) {

	$opt{datatype} = $INTEGER_GRID unless $opt{datatype};

	$self->{GRID} = ral_gdnew($opt{datatype}, $opt{M}, $opt{N});
       
    }
    attributes($self) if $self->{GRID};
    bless($self, $class);
}

sub gdal_open {
    my($self, %opt) = @_;
    my $dataset = gdal::Open($self->{NAME});
    my $t = $dataset->GetGeoTransform;
    unless ($t) {
	@$t = (0,1,0,0,0,1);
    }
    $t->[5] = abs($t->[5]);
    croak "cells are not squares: dx=$t->[1] != dy=$t->[5]" 
	unless $t->[1] == $t->[5];
    croak "the raster is not a strict north up image"
	unless $t->[2] == $t->[4] and $t->[2] == 0;
    my @world = ($t->[0], $t->[3]-$dataset->{RasterYSize}*$t->[1],
		 $t->[0]+$dataset->{RasterXSize}*$t->[1], $t->[3]);
    my $band = $opt{BAND} || 1;

    $self->{GDAL}->{dataset} = $dataset;
    $self->{GDAL}->{world} = [@world];
    $self->{GDAL}->{cell_size} = $t->[1];
    $self->{GDAL}->{band} = $band;

    cache($self) if $opt{load};
    return 1;
}

sub _min {
    return $_[0] if $_[0] < $_[1];
    return $_[1];
}

sub _max {
    return $_[0] if $_[0] > $_[1];
    return $_[1];
}

=pod

=head2 Caching data into the work raster from the dataset

Read all data:

    $gd->cache();

Use an existing raster as a model (bounding box, cell_size):

    $gd->cache($like_this_grid); 

Use a bounding box:

    $gd->cache($minX,$minY,$maxX,$maxY);
    $gd->cache($minX,$minY,$maxX,$maxY,$cell_size);

If the cell_size is not given, the cell_size of the dataset is used.

If the cell_size is specified, it is used if it is larger than the
cell_size of the dataset.

The given bounding box clipped to the bounding box of the dataset. The
resulting bounding box of the work raster is always adjusted to pixel
boundaries of the dataset.

=cut

sub cache {
    my $self = shift;

    my $gdal = $self->{GDAL};

    croak "no GDAL" unless $gdal;
    
    my $clip = $gdal->{world};
    my $cell_size = $gdal->{cell_size};

    if (defined $_[0]) {

	if (@_ == 1) { # use the given grid as a model

	    croak "usage: cache(\$grid)" unless ref($_[0]) eq 'Geo::Raster';

	    if ($_[0]->{GDAL}) {
		$clip = $_[0]->{GDAL}->{world};
		$cell_size = $_[0]->{GDAL}->{cell_size};
	    } else {
		$clip = ral_gdget_world($_[0]->{GRID}); 
		$cell_size = ral_gdget_cell_size($_[0]->{GRID});
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

    my $gd = ral_gdread_using_GDAL($gdal->{dataset},$gdal->{band},@$clip,$cell_size);

    return unless $gd;
   
    if (defined wantarray) {

	$gd = new Geo::Raster $gd;
	return $gd;

    } else {

	ral_gddestroy($self->{GRID}) if $self->{GRID};
	delete $self->{GRID};
	$self->{GRID} = $gd;
	attributes($self);
	
    }
}

sub DESTROY {
    my $self = shift;
    return unless $self;
    ral_gddestroy($self->{GRID}) if $self->{GRID};
    delete($self->{GRID});
}


=pod

=head2 Saving a grid:

    $gd->save("data/dem");

If no filename is given the method tries to use the name attribute of
the grid.

The default saving format is a pair of hdr/bil files.

=cut

sub save {
    my $self = shift;
    my $name;
    if ($#_ < 0) {
	$name = $self->{NAME};
    } elsif ($#_ == 0) {
	$name = shift;
    }
    my(%opt) = @_;
    $name = $opt{filename} if $opt{filename};
    $self->{NAME} = $name;
    my $ext;
    $ext = $1 if $name =~ /\.(\w+)$/;
    $ext = '' unless defined $ext;
    if ($name) {
	$name =~ s/\.(\w+)$//;
	my $fh = new FileHandle;
        croak "can't write to $name.hdr: $!\n" unless $fh->open(">$name.hdr");

	my($datatype, $M, $N, $cell_size, $minX, $maxX, $minY, $maxY, $nodata_value) = 
	    $self->attributes();

	# should be looked up from libral:!!
	my $nbits = 16;
	$nbits = 32 if $datatype == $REAL_GRID;

	my $pt = 'S';
	$pt = 'F' if $datatype == $REAL_GRID;

	my $byteorder = $Config{byteorder} == 4321 ? 'M' : 'I';

# forget this: and rely on $nbits
#	$byteorder = 'F' if $datatype == $REAL_GRID;

	print $fh "BYTEORDER      $byteorder\n";
	print $fh "LAYOUT       BIL\n";
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
	print $fh "ULXMAP        $minX\n";
	print $fh "ULYMAP        $maxY\n";
	print $fh "XDIM          $cell_size\n";
	print $fh "YDIM          $cell_size\n";
	$fh->close;
	return ral_gdwrite($self->{GRID}, $name.'.bil')
    }
}


=pod

=head2 Dump and Restore

Some grids may contain very little information, then dumping and
restoring is an option which saves disk space. Note, however, that
dumping does not save the size or other attributes of the grid:

$g->dump($to);

Dump is in fact grid print method (see below) using options quiet and
nonzeros with a redirect to $to.  Note that restore is not a
constructor, so you may need to create the grid before restoring it:

$g = new Geo::Raster(like=>$some_other_grid);

$g->restore($from);

$to and $from can be undef (then dump uses STDOUT and restore uses
STDIN), filename, or reference to a filehandle (e.g., \*DUMP).

=cut

sub dump {
    my $self = shift;
    my $to = shift;
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
    for (my $i = 0; $i <= $#$points; $i+=3) {
#	print $to "$points->[$i]->[0], $points->[$i]->[1], $points->[$i]->[2]\n";
	print $to "$points->[$i], $points->[$i+1], $points->[$i+2]\n";
    }
    $to->close if $close;
}

sub restore {
    my $self = shift;
    my $from = shift;
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
    ral_gdset_all_integer($self->{GRID},0);
    while (<$from>) {
	my($i, $j, $x) = split /,/;
	ral_gdset_real($self->{GRID}, $i, $j, $x);
    }
    $from->close if $close;
}


=pod

=head2 The name of the grid

The name of the grid is (or may be) the same as its filename
(including the path) without extension. The name is set when a grid is
constructed from a file (or files).

Setting and getting the name:

    $name = $gd->get_name();
    $gd->set_name("dem");

=cut

sub get_name {
    my($self) = @_;
    return $self->{NAME};
}


sub set_name {
    my($self, $name) = @_;
    $self->{NAME} = $name;
}


sub setbounds {
    my($self,%o) = @_;
    if ($o{cell_size} and defined($o{minX}) and defined($o{minY})) {

	ral_gdset_bounds_csnn($self->{GRID}, $o{cell_size}, $o{minX}, $o{minY});

    } elsif ($o{cell_size} and defined($o{minX}) and defined($o{maxY})) {

	ral_gdset_bounds_csnx($self->{GRID}, $o{cell_size}, $o{minX}, $o{maxY});

    } elsif ($o{cell_size} and defined($o{maxX}) and defined($o{minY})) {

	ral_gdset_bounds_csxn($self->{GRID}, $o{cell_size}, $o{maxX}, $o{minY});

    } elsif ($o{cell_size} and defined($o{maxX}) and defined($o{maxY})) {

	ral_gdset_bounds_csxx($self->{GRID}, $o{cell_size}, $o{maxX}, $o{maxY});

    } elsif (defined($o{minX}) and defined($o{maxX}) and defined($o{minY})) {

	ral_gdset_bounds_nxn($self->{GRID}, $o{minX}, $o{maxX}, $o{minY});

    } elsif (defined($o{minX}) and defined($o{maxX}) and defined($o{maxY})) {

	ral_gdset_bounds_nxx($self->{GRID}, $o{minX}, $o{maxX}, $o{maxY});

    } elsif (defined($o{minX}) and defined($o{minY}) and defined($o{maxY})) {

	ral_gdset_bounds_nnx($self->{GRID}, $o{minX}, $o{minY}, $o{maxY});

    } elsif (defined($o{maxX}) and defined($o{minY}) and defined($o{maxY})) {

	ral_gdset_bounds_xnx($self->{GRID}, $o{maxX}, $o{minY}, $o{maxY});

    } else {

	croak "not enough parameters to set up a world coordinate system";

    }
    $self->attributes;
}


sub copyboundsto {
    my($self, $to) = @_;
    return ral_gdcopy_bounds($self->{GRID}, $to->{GRID});
}

=pod

=head2 Setting the world coordinate system:

    $gd->setbounds(cell_size=>1,
		   minX=>0,
		   minY=>0, 
		   maxX=>10,
		   maxY=>10);

at least three parameters must be set: cell_size, minX and minY; minX,
maxX and minY; or minX, minY and maxY. minX (or easting) is the left
edge of the leftmost cell, i.e. _not_ the center of the leftmost cell.

The world coordinate system can be copied to another grid:

    $g1->copyboundsto($g2);

Conversions between coordinate systems (Cell<->World):

    ($x, $y) = $gd->g2w($i, $j);
    ($i, $j) = $gd->w2g($x, $y);

=cut

sub cell_in {
    my($self, @cell) = @_;
    return ($cell[0] >= 0 and $cell[0] < $self->{M} and $cell[1] >= 0 and $cell[1] < $self->{N})
}

sub point_in {
    my($self, @point) = @_;
    return ($point[0] >= $self->{WORLD}->[0] and $point[0] <= $self->{WORLD}->[3] and 
	    $point[1] >= $self->{WORLD}->[1] and $point[1] <= $self->{WORLD}->[2])
}

sub g2w {
    my($self, @cell) = @_;
    if ($self->{GDAL}) {
	my $gdal = $self->{GDAL};
	my $x = $gdal->{world}->[0] + ($cell[1]+0.5)*$gdal->{cell_size};
	my $y = $gdal->{world}->[3] - ($cell[0]+0.5)*$gdal->{cell_size};
	return ($x,$y);
    }
    my $point = ral_gdcell2point( $self->{GRID}, @cell);
    return @$point;
}


sub w2g {
    my($self, @point) = @_;
    if ($self->{GDAL}) {
	my $gdal = $self->{GDAL};
	$point[0] -= $gdal->{world}->[0];
	$point[0] /= $gdal->{cell_size};
	$point[1] = $gdal->{world}->[3] - $point[1];
	$point[1] /= $gdal->{cell_size};
	return (POSIX::floor($point[1]),POSIX::floor($point[0]));
    }
    my $cell = ral_gdpoint2cell($self->{GRID}, @point);
    return @$cell;
}

sub ga2wa {
    my($self, @ga) = @_;
    if ($self->{GDAL}) {
	my @ul = $self->g2w(@ga[0..1]);
	my @lr = $self->g2w(@ga[2..3]);
	return (@ul,@lr);
    }
    my $ul = ral_gdcell2point($self->{GRID}, @ga[0..1]);
    my $lr = ral_gdcell2point($self->{GRID}, @ga[2..3]);
    return (@$ul,@$lr);
}


sub wa2ga {
    my($self, @wa) = @_;
    if ($self->{GDAL}) {
	my @ul = $self->w2g(@wa[0..1]);
	my @lr = $self->w2g(@wa[2..3]);
	return (@ul,@lr);
    }
    my $ul = ral_gdpoint2cell($self->{GRID}, @wa[0..1]);
    my $lr = ral_gdpoint2cell($self->{GRID}, @wa[2..3]);
    return (@$ul,@$lr);
}


=pod

=head2 Setting and removing a mask

    $gd->setmask();

    $gd->removemask();

The mask is used in ALL grid operations made on _this_ grids.

=cut


sub setmask {
    my($self,$mask) = @_;
    ral_gdsetmask($self->{GRID}, $mask->{GRID});
}


sub getmask {
    my($self) = @_;
    my $mask = new Geo::Raster(use=>ral_gdgetmask($self->{GRID}));
    return $mask;
}


sub removemask {  
    my($self) = @_;
    ral_gdclearmask($self->{GRID});
}


=pod

=head2 Setting a cell value

    $gd->set($i, $j, $x);

If $x is undefined or string "nodata", the cell value is set to nodata_value.

=head2 Setting all cells to a value

    $gd->set($x);

If $x is undefined or string "nodata", the cell value is set to nodata_value.

=head2 Copying values from another grid

    $gd->set($g);

$g needs to be a similar Geo::Raster.

The return value is 0 in the case of an error.

=cut

sub set {
    my($self, $i, $j, $x) = @_;
    if (defined($j)) {
	if (!defined($x) or $x eq 'nodata') {
	    return ral_gdset_nodata($self->{GRID}, $i, $j);
	}
	if ($x =~ /^\d+$/) {
	    return ral_gdset_integer($self->{GRID}, $i, $j, $x);
	} else {
	    return ral_gdset_real($self->{GRID}, $i, $j, $x);
	}
    } else {
	if (ref($i) eq 'Geo::Raster') {
	    return ral_gdcopy($self->{GRID}, $i->{GRID});
	} 
	if (!defined($i) or $i eq 'nodata') {
	    return ral_gdset_all_nodata($self->{GRID});
	} 
	if (!ref($i)) {
	    if ($i =~ /^\d+$/) { # integer
		return ral_gdset_all_integer($self->{GRID}, $i);
	    } else {
		return ral_gdset_all_real($self->{GRID}, $i);
	    }
	} 
	croak "can't copy a ",ref($i)," onto a grid\n";
    }
}

sub setall {
    my($self, $x) = @_;
    if ($x eq 'nodata') {
	return ral_gdsetallnodata($self->{GRID});
    }
    if ($x =~ /^\d+$/) { # integer
	return ral_gdsetall_int($self->{GRID}, $x);
    } else {
	return ral_gdsetall($self->{GRID}, $x);
    }
}

sub setall_nodata {
    my($self) = @_;
    return ral_gdset_all_nodata($self->{GRID});
}

=pod

=head2 Retrieving a cell's value

    $x = $gd->get($i, $j);

The returned value is either a number, 'nodata', or undef if the cell
is not in the grid.

The same in world coordinates

    $x = $gd->wget($x, $y);

=cut


sub get {
    my($self, @cell) = @_;
    if ($self->{GDAL}) {
	my @point = $self->g2w(@cell);
	@cell = $self->w2g(@point);
    }
    return ral_gdget($self->{GRID}, @cell);
}

sub wget {
    my($self, @point) = @_;
    return unless $self->{GRID};
    my $cell = ral_gdpoint2cell($self->{GRID}, @point);
    return ral_gdget($self->{GRID}, $cell->[0], $cell->[1]);
}


=pod

=head2 Nodata values

Both integer and floating point grids may have nodata values.  The
nodata value is a special integer or real value, which is stored in
the grid data structure. Nodata values behave a bit like a mask, they
are not used in queries and in arithmetics operands do not affect
them. For example if c is nodata value then after

a = b + c

a is nodata.

and

b += c

b is nodata.

Also in comparisons the result is nodata if either of the values to be
compared is nodata.

In the construct "if a then b = c" for grids. b is assigned c only
if a is data and c is data.

The method "data", which can be used as in-place or as normal method
which returns a value and does not affect the grid itself, returns a
binary grid, which has 0 where there were nodata values and 1 where
there were data.

    $gd->data();

or

    $b = $a->data();

=cut


sub data {
    my $self = shift;
    $self = new Geo::Raster $self if defined wantarray;
    my $g = ral_gddata($self->{GRID});
    $self->{DATATYPE} = ral_gdget_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray and $g;
}


=pod

=head2 Calculating min and max values

    ($minval, $maxval) = $gd->getminmax(); 

or

    $minval = $gd->min();
    $maxval = $gd->max();

These methods have quite another meaning if a parameter is supplied,
see below.

=cut

sub getminmax {
    my $self = shift;
    return unless $self->{GRID};
    ral_gdset_minmax($self->{GRID});
    my $minmax = ral_gdget_minmax($self->{GRID});
    return @$minmax;
}


=pod

=head2 Retrieving the attributes of a grid (deprecated)

    ($datatype, $M, $N, $cell_size, $minX, $minY, $maxX, $maxY, $nodata_value) = 
    $gd->attributes();

Use the specific methods instead:

    $datatype = $gd->datatype(); # returns a string 

    ($M, $N) = $gd->size();

    $cell_size = $gd->cell_size();

    ($minX,$minY,$maxX,$maxY) = $gd->world();

    $nodata_value = $gd->nodata_value();

 
Size is interpreted as a size of a zone, if a cell is given as a
parameter to size method:

    $zone_size = $gd->size($i,$j);

=cut

sub attributes {
    my $self = shift;
    return unless $self->{GRID};
    my $datatype = $self->{DATATYPE} = ral_gdget_datatype($self->{GRID}); 
    my $M = $self->{M} = ral_gdget_height($self->{GRID});
    my $N = $self->{N} = ral_gdget_width($self->{GRID});
    my $cell_size = $self->{CELL_SIZE} = ral_gdget_cell_size($self->{GRID});
    my $world = $self->{WORLD} = ral_gdget_world($self->{GRID});
    my $nodata = $self->{NODATA} = ral_gdget_nodata_value($self->{GRID});
    return($datatype, $M, $N, $cell_size, @$world, $nodata);
}


sub has_data {
    my $self = shift;
    return ral_gd_has_data($self->{GRID});
}


sub datatype {
    my $self = shift;
    $self->{DATATYPE} = ral_gdget_datatype($self->{GRID});
    return 'integer' if $self->{DATATYPE} == $INTEGER_GRID;
    return 'real' if $self->{DATATYPE} == $REAL_GRID;
}


sub size {
    my($self, $i, $j) = @_;
    if (defined($i) and defined($j)) {
	return _gdzonesize($self->{GRID}, $i, $j);
    } else {
	return ($self->{M}, $self->{N});
    }
}

sub cell_size {
    my $self = shift;
    my $length = $self->{CELL_SIZE} = ral_gdget_cell_size($self->{GRID});
}


sub world {
    my $self = shift;
    my $true = shift;
    my $w;
    if ($true and $self->{GDAL}) {
	$w = $self->{GDAL}->{world};
    } else {
	$w = ral_gdget_world($self->{GRID});
    }
    return @$w;
}

sub nodata_value {
    my $self = shift;
    my $nodata_value = shift;
    if (defined $nodata_value) {
	if ($self->{DATATYPE} == $INTEGER_GRID) {
	    ral_gdset_integer_nodata_value($self->{GRID}, $nodata_value);
	} else {
	    ral_gdset_real_nodata_value($self->{GRID}, $nodata_value);
	}
    } else {
	$nodata_value = $self->{NODATA} = ral_gdget_nodata_value($self->{GRID});
    }
    return $nodata_value;
}


=pod

=head2 Arithmetics

Add/subtract a scalar or another grid to a grid:

    $b = $a + $x; # is equal to $b = $a->plus($x);
    $b = $a - $x; # is equal to $b = $a->minus($x);

In-place versions

    $gd += $x; # is equal to $gd->add($x);
    $gd -= $x; # is equal to $gd->subtract($x);

Multiply/divide the grid by a scalar or by another grid:

    $b = $a * $x; # is equal to $b = $a->times($x);
    $b = $a / $x; # is equal to $b = $a->over($x);

In-place versions

    $gd *= $x; # is equal to $gd->multiply_by($x);
    $gd /= $x; # is equal to $gd->divide_by($x);

NOTE: THIS IS NOT MATRIX MULTIPLICATION: what goes on is, e.g.:

  for all i,j: b[i,j] = a[i,j] * x[i,j]

Modulus:

    $b = $a % $x; # is equal to $b = $a->modulo($x);
    $gd %= $x;    # is equal to $gd->modulus_with($x);

Power:

    $b = $a**$x;  # is equal to $b = $a->power($x);
    $gd **= $x;   # is equal to $gd->to_power_of($x);


DO NOT use void context algebraic operations like $a + 5; The effect
is not what you expect and it will generate a warning if run with the
B<-w> switch.

Integer grids are silently converted to real grids if the operand is a
real number or a real grid or if the operator is "/" (except in
modulus, which is defined only for integer grids).

=cut


sub bool {
    my $self = shift;
    return 1;
}

sub stringify {
    my $self = shift;
    return "Geo::Raster=HASH()"; # the address??
}

sub clone { # thanks to anno4000@lublin.zrz.tu-berlin.de (Anno Siegel)
    my $self = shift;
    bless $self, ref $self;
}


sub neg {
    my $self = shift;
    my $copy = new Geo::Raster($self);
    ral_gdmultinteger($copy->{GRID}, -1);
    return $copy;
}


sub typeconversion {
    my($self,$other) = @_;
    if (ref($other)) {
	if (ref($other) eq 'Geo::Raster') {
	    return $REAL_GRID if 
		$other->{DATATYPE} == $REAL_GRID or 
		    $self->{DATATYPE} == $REAL_GRID;
	    return $INTEGER_GRID;
	} else {
	    croak "$other is not a grid\n";
	}
    } else {
	# perlfaq4: is scalar an integer ?
	return $self->{DATATYPE} if $other =~ /^-?\d+$/;

	# perlfaq4: is scalar a C float ?
	if ($other =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/) {
	    return $REAL_GRID if $self->{DATATYPE} == $INTEGER_GRID;
	    return $self->{DATATYPE};
	}
	
	croak "$other is not numeric\n";
    }
}


sub plus {
    my($self, $second) = @_;
    my $datatype = $self->typeconversion($second);
    return unless defined($datatype);
    my $copy = new Geo::Raster datatype=>$datatype, copy=>$self;
    if (ref($second)) {
	ral_gdaddgd($copy->{GRID}, $second->{GRID});
    } else {
	if ($second =~ /^-?\d+$/) {
	    ral_gdaddinteger($copy->{GRID}, $second);
	} else {
	    ral_gdaddreal($copy->{GRID}, $second);
	}
    }
    return $copy;
}


sub minus {
    my($self, $second, $reversed) = @_;
    my $datatype = $self->typeconversion($second);
    return unless defined($datatype);
    my $copy = new Geo::Raster datatype=>$datatype, copy=>$self;
    if (ref($second)) {
	($copy, $second) = ($second, $copy) if $reversed;
	ral_gdsubgd($copy->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    ral_gdmultinteger($copy->{GRID},-1);
	} else {
	    $second *= -1;
	}
	if ($second =~ /^-?\d+$/) {
	    ral_gdaddinteger($copy->{GRID}, $second);
	} else {
	    ral_gdaddreal($copy->{GRID}, $second);
	}
    }
    return $copy;
}


sub times {
    my($self, $second) = @_;
    my $datatype = $self->typeconversion($second);
    return unless defined($datatype);
    my $copy = new Geo::Raster datatype=>$datatype, copy=>$self;
    if (ref($second)) {
	ral_gdmultgd($copy->{GRID}, $second->{GRID});
    } else {
	if ($second =~ /^-?\d+$/) {
	    ral_gdmultinteger($copy->{GRID},$second);
	} else {
	    ral_gdmultreal($copy->{GRID},$second);
	}
    }
    return $copy;
}


sub over {
    my($self, $second, $reversed) = @_;
    my $copy = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    if (ref($second)) {
	($copy, $second) = ($second, $copy) if $reversed;
	ral_gddivgd($copy->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    if ($second =~ /^-?\d+$/) {
		ral_integerdivgd($second, $copy->{GRID});
	    } else {
		ral_realdivgd($second, $copy->{GRID});
	    }
	} else {
	    if ($second =~ /^-?\d+$/) {
		ral_gddivinteger($copy->{GRID}, $second);
	    } else {
		ral_gddivreal($copy->{GRID}, $second);
	    }
	}
    }
    return $copy;
}

sub modulo {
    my($self, $second, $reversed) = @_;
    my $copy = new Geo::Raster($self);
    if (ref($second)) {
	($copy, $second) = ($second, $copy) if $reversed;
	ral_gdmodulusgd($copy->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    ral_svmodulusgd($second, $copy->{GRID});
	} else {
	    ral_gdmodulussv($copy->{GRID}, $second);
	}
    }
    return $copy;
}


sub power {
    my($self, $second, $reversed) = @_;
    my $datatype = $self->typeconversion($second);
    return unless defined($datatype);
    my $copy = new Geo::Raster datatype=>$datatype, copy=>$self;
    if (ref($second)) {
	($copy, $second) = ($second, $copy) if $reversed;
	ral_gdpowergd($copy->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    ral_realpowergd($second, $copy->{GRID});
	} else {
	    ral_gdpowerreal($copy->{GRID}, $second);
	}
    }
    return $copy;
}


sub add {
    my($self, $second) = @_;
    my $datatype = $self->typeconversion($second);
    return unless defined($datatype);
    $self->_new_grid(ral_gdnewcopy($self->{GRID}, $datatype)) if $datatype != $self->{DATATYPE};
    if (ref($second)) {
	ral_gdaddgd($self->{GRID}, $second->{GRID});
    } else {
	if ($second =~ /^-?\d+$/) {
	    ral_gdaddinteger($self->{GRID}, $second);
	} else {
	    ral_gdaddreal($self->{GRID}, $second);
	}
    }
    return $self;
}


sub subtract {
    my($self, $second) = @_;
    my $datatype = $self->typeconversion($second);
    return unless defined($datatype);
    $self->_new_grid(ral_gdnewcopy($self->{GRID}, $datatype)) if $datatype != $self->{DATATYPE};
    if (ref($second)) {
	ral_gdsubgd($self->{GRID}, $second->{GRID});
    } else {
	if ($second =~ /^-?\d+$/) {
	    ral_gdaddinteger($self->{GRID}, -$second);
	} else {
	    ral_gdaddreal($self->{GRID}, -$second);
	}
    }
    return $self;
}


sub multiply_by {
    my($self, $second) = @_;
    my $datatype = $self->typeconversion($second);
    return unless defined($datatype);
    $self->_new_grid(ral_gdnewcopy($self->{GRID}, $datatype)) if $datatype != $self->{DATATYPE};
    if (ref($second)) {
	ral_gdmultgd($self->{GRID}, $second->{GRID});
    } else {
	if ($second =~ /^-?\d+$/) {
	    ral_gdmultinteger($self->{GRID}, $second);
	} else {
	    ral_gdmultreal($self->{GRID}, $second);
	}
    }
    return $self;
}


sub divide_by {
    my($self, $second) = @_;
    $self->_new_grid(ral_gdnewcopy($self->{GRID}, $REAL_GRID));
    if (ref($second)) {
	ral_gddivgd($self->{GRID}, $second->{GRID});
    } else {
	if ($second =~ /^-?\d+$/) {
	    ral_gddivinteger($self->{GRID}, $second);
	} else {
	    ral_gddivreal($self->{GRID}, $second);
	}
    }
    return $self;
}


sub modulus_with {
    my($self, $second) = @_;
    if (ref($second)) {
	ral_gdmodulusgd($self->{GRID}, $second->{GRID});
    } else {
	ral_gdmodulussv($self->{GRID}, $second);
    }
    return $self;
}


sub to_power_of {
    my($self, $second) = @_;
    my $datatype = $self->typeconversion($second);
    return unless defined($datatype);
    $self->_new_grid(ral_gdnewcopy($self->{GRID}, $datatype)) if $datatype != $self->{DATATYPE};
    if (ref($second)) {
	ral_gdpowergd($self->{GRID}, $second->{GRID});
    } else {
	ral_gdpowerreal($self->{GRID}, $second);
    }
    return $self;
}


=pod

=head2 Mathematical operations

Integer grids are silently converted to real grids if these methods
are applied. The only exception is abs, which is defined for integer
grids:

    $b = $a->abs();
    $b = $a->acos();
    $b = $a->atan();
    $c = $a->atan2($b);
    $b = $a->ceil();
    $b = $a->cos();
    $b = $a->cosh();
    $b = $a->exp();
    $b = $a->floor();
    $b = $a->log();
    $b = $a->log10();
    $b = $a->sin();
    $b = $a->sinh();
    $b = $a->sqrt();
    $b = $a->tan();
    $b = $a->tanh();

abs, atan2, cos, exp, log, sin, sqrt are overloaded

In-place versions (use always methods for in-place versions) change
the original grid:

    $a->abs();
    
...etc.

If $a is not a grid, the functions fall back to standard Perl math
functions.

NOTE: ceil and floor are defined only for real grids and return a real
grid. Geo::Raster method round can be used to convert a real grid to an
integer grid.

    $gd->round();

or 

    $b = $a->round();

=cut


sub atan2 {
    my($self, $second, $reversed) = @_;
    if (ref($self) and ref($second)) {
	if (defined wantarray) {
	    $self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
	} elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	    $self->_new_grid(ral_gdnewcopy($self->{GRID}, $REAL_GRID));
	}
	ral_gdatan2($self->{GRID}, $second->{GRID});
	return $self;
    } else {
	croak "don't mix scalars and grids in atan2, please";
    }
}


sub cos {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_gdnewcopy($self->{GRID}, $REAL_GRID));
    }
    ral_gdcos($self->{GRID});
    return $self;
}


sub sin {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_gdnewcopy($self->{GRID}, $REAL_GRID));
    }
    ral_gdsin($self->{GRID});
    return $self;
}


sub exp {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_gdnewcopy($self->{GRID}, $REAL_GRID));
    }
    ral_gdexp($self->{GRID});
    return $self;
}


sub abs {
    my $self = shift;
    if (defined wantarray) {
	my $copy = new Geo::Raster($self);
	ral_gdabs($copy->{GRID});
	return $copy;
    } else {
	ral_gdabs($self->{GRID});
    }
}


sub log {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_gdnewcopy($self->{GRID}, $REAL_GRID));
    }
    ral_gdlog($self->{GRID});
    return $self;
}


sub sqrt {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_gdnewcopy($self->{GRID}, $REAL_GRID));
    }
    ral_gdsqrt($self->{GRID});
    return $self;
}


sub round {
    my $self = shift;
    if (ref($self)) {
	my $grid = ral_gdround($self->{GRID});
	return unless $grid;
	if (defined wantarray) {
	    my $new = new Geo::Raster $grid;
	    return $new;
	} else {
	    $self->_new_grid($grid);
	}
    } else {
	return $self < 0 ? POSIX::floor($self - 0.5) : POSIX::floor($self + 0.5);
    }
}


{
    no warnings 'redefine';


sub acos {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_gdnewcopy($self->{GRID}, $REAL_GRID));
    }
    ral_gdacos($self->{GRID});
    return $self;
}


sub atan {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_gdnewcopy($self->{GRID}, $REAL_GRID));
    }
    ral_gdatan($self->{GRID});
    return $self;
}


sub ceil {
    my $self = shift;
    if (ref($self)) {
	$self = new Geo::Raster($self) if defined wantarray;
	ral_gdceil($self->{GRID});
	return $self;
    } else {
	return POSIX::ceil($self);
    }
}


sub cosh {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_gdnewcopy($self->{GRID}, $REAL_GRID));
    }
    ral_gdcosh($self->{GRID});
    return $self;
}


sub floor {
    my $self = shift;
    if (ref($self)) {
	$self = new Geo::Raster($self) if defined wantarray;
	ral_gdfloor($self->{GRID});
	return $self;
    } else {
	return POSIX::floor($self);
    }
}


sub log10 {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_gdnewcopy($self->{GRID}, $REAL_GRID));
    }
    ral_gdlog10($self->{GRID});
    return $self;
}


sub sinh {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_gdnewcopy($self->{GRID}, $REAL_GRID));
    }
    ral_gdsinh($self->{GRID});
    return $self;
}

sub tan {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_gdnewcopy($self->{GRID}, $REAL_GRID));
    }
    ral_gdtan($self->{GRID});
    return $self;
}


sub tanh {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_gdnewcopy($self->{GRID}, $REAL_GRID));
    }
    ral_gdtanh($self->{GRID});
    return $self;
}
}


=pod

=head2 Comparisons between grids

Comparison of grid to a scalar or to another grid:

    $g2 = $g1 op $x;

where op is "<", ">", "<=", ">=", "==", "!=", or "<=>". $x may be a
scalar or another grid. The return value is always an integer
grid. For in-place versions of the comparisons use the methods
lt, gt, le, ge, eq, ne, and cmp.

So there are four cases of the use of comparison operations:

                    a unchanged
 1. b = a->lt(0);      yes     
 2. a->lt(0);          no      
 3. b = a < 0;         yes     
 4. b = 0 < a;         yes     

DO NOT use void context comparisons like $a < 0; The effect is not
what you expect and it will generate a warning if run with the
B<-w> switch.

=cut

# there are seven cases of the use of comparison operations:
# 
#                  a unchanged  self second reversed  wantarray defined
# 1a. b = a->lt(0);   yes        a    0       no         yes
# 1b. c = a->lt(b);   yes        a    b       no         yes
# 2a. a->lt(0);       no         a    0       no         no
# 2b. a->lt(b);       no         a    b       no         no
# 3a. b = a < 0;      yes        a    0       no         yes
# 3b. c = a < b;      yes        a    b       no         yes
# 4a. b = 0 < a;      yes        a    0       yes        yes


sub lt {
    my($self, $second, $reversed) = @_;    
    $self = new Geo::Raster $self if defined wantarray;
    if (ref($second)) {
	ral_gdltgd($self->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    if ($second =~ /^-?\d+$/) {
		ral_gdgtinteger($self->{GRID}, $second);
	    } else {
		ral_gdgtreal($self->{GRID}, $second);
	    }
	} else {
	    if ($second =~ /^-?\d+$/) {
		ral_gdltinteger($self->{GRID}, $second);
	    } else {
		ral_gdltreal($self->{GRID}, $second);
	    }
	}
    }
    $self->{DATATYPE} = ral_gdget_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray;
}


sub gt {
    my($self, $second, $reversed) = @_;
    $self = new Geo::Raster $self if defined wantarray;
    if (ref($second)) {
	ral_gdgtgd($self->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    if ($second =~ /^-?\d+$/) {
		ral_gdltinteger($self->{GRID}, $second);
	    } else {
		ral_gdltreal($self->{GRID}, $second);
	    }
	} else {
	    if ($second =~ /^-?\d+$/) {
		ral_gdgtinteger($self->{GRID}, $second);
	    } else {
		ral_gdgtreal($self->{GRID}, $second);
	    }
	}
    }
    $self->{DATATYPE} = ral_gdget_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray;
}


sub le {
    my($self, $second, $reversed) = @_;
    $self = new Geo::Raster $self if defined wantarray;
    if (ref($second)) {
	ral_gdlegd($self->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    if ($second =~ /^-?\d+$/) {
		ral_gdgeinteger($self->{GRID}, $second);
	    } else {
		ral_gdgereal($self->{GRID}, $second);
	    }
	} else {
	    if ($second =~ /^-?\d+$/) {
		ral_gdleinteger($self->{GRID}, $second);
	    } else {
		ral_gdlereal($self->{GRID}, $second);
	    }
	}
    }
    $self->{DATATYPE} = ral_gdget_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray;
}


sub ge {
    my($self, $second, $reversed) = @_;
    $self = new Geo::Raster $self if defined wantarray;
    if (ref($second)) {
	ral_gdgegd($self->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    if ($second =~ /^-?\d+$/) {
		ral_gdleinteger($self->{GRID}, $second);
	    } else {
		ral_gdlereal($self->{GRID}, $second);
	    }
	} else {
	    if ($second =~ /^-?\d+$/) {
		ral_gdgeinteger($self->{GRID}, $second);
	    } else {
		ral_gdgereal($self->{GRID}, $second);
	    }
	}
    }
    $self->{DATATYPE} = ral_gdget_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray;
}


sub eq {
    my $self = shift;
    my $second = shift;
    $self = new Geo::Raster $self if defined wantarray;
    if (ref($second)) {
	ral_gdeqgd($self->{GRID}, $second->{GRID});
    } else {
	if ($second =~ /^-?\d+$/) {
	    ral_gdeqinteger($self->{GRID}, $second);
	} else {
	    ral_gdeqreal($self->{GRID}, $second);
	}
    }
    $self->{DATATYPE} = ral_gdget_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray;
}


sub ne {
    my $self = shift;
    my $second = shift;
    $self = new Geo::Raster $self if defined wantarray;
    if (ref($second)) {
	ral_gdnegd($self->{GRID}, $second->{GRID});
    } else {
	if ($second =~ /^-?\d+$/) {
	    ral_gdneinteger($self->{GRID}, $second);
	} else {
	    ral_gdnereal($self->{GRID}, $second);
	}
    }
    $self->{DATATYPE} = ral_gdget_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray;
}


sub cmp {
    my($self, $second, $reversed) = @_;
    $self = new Geo::Raster $self if defined wantarray;
    if (ref($second)) {
	ral_gdcmpgd($self->{GRID}, $second->{GRID});
    } else {
	if ($second =~ /^-?\d+$/) {
	    ral_gdcmpinteger($self->{GRID}, $second);
	} else {
	    ral_gdcmpreal($self->{GRID}, $second);
	}
	if ($reversed) {
	    if ($second =~ /^-?\d+$/) {
		ral_gdmultinteger($self->{GRID}, -1);
	    } else {
		ral_gdmultreal($self->{GRID}, -1);
	    }
	}
    }
    $self->{DATATYPE} = ral_gdget_datatype($self->{GRID}); # may have been changed
    return $self if defined wantarray;
}

=pod

=head2 Logical operations

    $b = $a->not();
    $c = $a->and($b);
    $c = $a->or($b);

in-place versions (changes a)

    $a->not();
    $a->and($b);
    $a->or($b);

or

use Geo::Raster /:logics/;

    $b = not($a);
    $c = and($a, $b);
    $c = or($a, $b);


=cut

sub not {
    my $self = shift;
    $self = new Geo::Raster $self if defined wantarray;
    ral_gdnot($self->{GRID});
    return $self if defined wantarray;
}


sub and {
    my $self = shift;
    my $second = shift;
    $self = new Geo::Raster $self if defined wantarray;
    ral_gdandgd($self->{GRID}, $second->{GRID});
    return $self if defined wantarray;
}


sub or {
    my $self = shift;
    my $second = shift;
    $self = new Geo::Raster $self if defined wantarray;
    ral_gdorgd($self->{GRID}, $second->{GRID});
    return $self if defined wantarray;
}

=pod

=head2 Minimum and maximum

    $g2 = $g1->min($x);
    $g2 = $g1->max($x);

again, in-place versions also work.

The effect is (for the method "min"):

g2[i,j] = min( g1[i,j] , x[i,j] ) or, if x is scalar, 
g2[i,j] = min( g1[i,j] , x ). 

If $x is undef these methods refer to the minimum and maximum values
of the grid. In scalar context the methods return the minimum value.

=cut

sub min {
    my $self = shift;
    my $second = shift;
    $self = new Geo::Raster $self if defined wantarray;
    if (ref($second)) {
	ral_gdmingd($self->{GRID}, $second->{GRID});
    } else {
	if (defined($second)) {
	    if ($second =~ /^-?\d+$/) {
		ral_gdmininteger($self->{GRID}, $second);
	    } else {
		ral_gdminreal($self->{GRID}, $second);
	    }
	} else {
	    ral_gdset_minmax($self->{GRID});
	    my $minmax = ral_gdget_minmax($self->{GRID});
	    return $minmax->[0];
	}
    }
    return $self if defined wantarray;
}


sub max {
    my $self = shift;
    my $second = shift;   
    $self = new Geo::Raster $self if defined wantarray;
    if (ref($second)) {
	ral_gdmaxgd($self->{GRID}, $second->{GRID});
    } else {
	if (defined($second)) {
	    if ($second =~ /^-?\d+$/) {
		ral_gdmaxinteger($self->{GRID}, $second);
	    } else {
		ral_gdmaxreal($self->{GRID}, $second);
	    }
	} else {
	    ral_gdset_minmax($self->{GRID});
	    my $minmax = ral_gdget_minmax($self->{GRID});
	    return $minmax->[1];
	}
    }
    return $self if defined wantarray;
}


=pod

=head2 Cross product of grids

Cross product of two grids is defined for integer grids only.

    $c = $a->cross($b);

or in-place

    $a->cross($b);

c = a x b

If a has values a1, ..., ana (ai < aj, na distinct values) and b has
values b1, ..., bnb (bi < bj, nb distinct values) then c will have nc = na * nb
distinct values 1, ..., nc. The c will have value 1 where a = a1 and b
= b1, 2 where a = a1 and b = b2, etc.

=cut

sub cross {
    my($a, $b) = @_;
    my $c = ral_gdcross($a->{GRID}, $b->{GRID}); 
    return new Geo::Raster ($c) if defined wantarray;
    $a->_new_grid($c) if $c;
}

=pod

=head2 if ... then construct for grids

    $a->if($b, $c);

$a and $b are grids and $c can be a grid or a scalar, the
effect of this subroutine is:

for all i,j if (b[i,j]) then a[i,j]=c[i,j]

if a return value is requested

    $d = $a->if($b, $c);

then d is a but if b then c

If $c is a reference to a zonal mapping hash, i.e., it has value pairs
k=>v, where k is an integer, which represents a zone in b, then a is
set to v on that zone. A zone mapping hash can, for example, be
obtained using the zonal functions (see below).

=cut

sub if {
    my $a = shift;
    my $b = shift;    
    my $c = shift;
    my $d = shift;
    $a = new Geo::Raster ($a) if defined wantarray;
    croak "usage $a->if($b, $c)" unless defined $c;
    if (ref($c)) {
	if (ref($c) eq 'Geo::Raster') {
	    ral_gdif_then_gd($b->{GRID}, $a->{GRID}, $c->{GRID});
	} elsif (ref($c) eq 'HASH') {
	    my(@k,@v);
	    foreach (keys %{$c}) {
		push @k, int($_);
		push @v, $c->{$_};
	    }
	    ral_gdzonal_if_then_real($b->{GRID}, $a->{GRID}, \@k, \@v, $#k+1);
	} else {
	    croak("usage: $a->if($b, $c)");
	}
    } else {
	unless (defined $d) {
	    if ($c =~ /^-?\d+$/) {
		ral_gdif_then_integer($b->{GRID}, $a->{GRID}, $c);
	    } else {
		ral_gdif_then_real($b->{GRID}, $a->{GRID}, $c);
	    }
	} else {
	    if ($c =~ /^-?\d+$/) {
		ral_gdif_then_else_integer($b->{GRID}, $a->{GRID}, $c, $d);
	    } else {
		ral_gdif_then_else_real($b->{GRID}, $a->{GRID}, $c, $d);
	    }
	}
    }
    return $a if defined wantarray;
}

=pod

=head2 Convert an integer image into a binary image:

    $g->binary();

This has the same effect as writing $g->ne(0);

=cut

sub binary {
    my $self = shift;
    return gdbinary($self->{GRID});
}

=pod

=head2 Bufferzone

    $g2 = $g1->bufferzone($z, $w);

Creates (or converts a grid to) a binary grid g2, where all cells
within distance w of a cell (measured as cell center to cell center)
in g1 having value z will have value 1, all other cells in g2 will
have values 0.

g1 has to be an integer grid. The return value is optional.


=cut

sub bufferzone {
    my($self, $z, $w) = @_;
    croak "method usage: bufferzone($z, $w)" unless defined($w);
    if (defined wantarray) {
	my $g = new Geo::Raster(gdbufferzone($self->{GRID}, $z, $w));
	return $g;
    } else {
	$self->_new_grid(gdbufferzone($self->{GRID}, $z, $w));
    }
}

=pod

=head2 count, sum, mean, ...

    $count = $gd->count();
    $sum = $gd->sum();
    $mean = $gd->mean();
    $variance = $gd->variance();

Return scalars. All cells except those having nodata values are taken
into account.

Similar zonal functions are below. Min and max functions are above.

=cut

sub count {
    my $self = shift;
    return ral_gdcount($self->{GRID});
}

sub sum {
    my($self) = @_;
    return ral_gdsum($self->{GRID});
}

sub mean {
    my $self = shift;
    return ral_gdmean($self->{GRID});
}

sub variance {
    my $self = shift;
    return ral_gdvariance($self->{GRID});
}

=pod

Generating a proximity grid:

    $g->distances();

or

    $d = $g->distances();

The returned grid has in the nodata cells of grid $g the distance to
the nearest data cell in $g.

=cut

sub distances {
    my($self) = @_;
    if (defined wantarray) {
	my $g = new Geo::Raster(ral_gddistances($self->{GRID}));
	return $g;
    } else {
	$self->_new_grid(ral_gddistances($self->{GRID}));
    }
}

=pod

Generating a direction_to grid:

    $g->directions();

or

    $d = $g->directions();

The returned grid has in the nodata cells of grid $g the directions to
the nearest data cell in $g. Directions are given in radians and
direction zero is to the direction of x-axis, Pi/2 is to the direction
of y-axis.

NOTE: The generation of proximity and direction_to grids in the case
of large grids (more than 100 000 cells) and few data cells is
very timeconsuming.

=cut

sub directions {
    my($self) = @_;
    if (defined wantarray) {
	my $g = new Geo::Raster(ral_gddirections($self->{GRID}));
	return $g;
    } else {
	$self->_new_grid(ral_gddirections($self->{GRID}));
    }
}

=pod

=head2 Clipping a grid:

    $g2 = $g1->clip($i1, $j1, $i2, $j2);

or

    $g2 = $g1->clip($g3);

to clip from $g1 a piece which is overlayable with $g3.

If there is no lvalue, $g1 is clipped.

=cut

sub clip {
    my $self = shift;
    if (@_ == 4) {
	my($i1, $j1, $i2, $j2) = @_;
	if (defined wantarray) {
	    my $g = new Geo::Raster(ral_gdclip($self->{GRID}, $i1, $j1, $i2, $j2));
	    return $g;
	} else {
	    $self->_new_grid(ral_gdclip($self->{GRID}, $i1, $j1, $i2, $j2));
	}
    } else {
	my $gd = shift;
	return unless ref($gd) eq 'Geo::Raster';
	my @a = $gd->attrib;
	my($i1,$j1) = $self->w2g($a[4],$a[7]);
	my($i2,$j2) = ($i1+$a[1]-1,$j1+$a[2]-1);
	if (defined wantarray) {
	    my $g = new Geo::Raster(ral_gdclip($self->{GRID}, $i1, $j1, $i2, $j2));
	    return $g;
	} else {
	    $self->_new_grid(ral_gdclip($self->{GRID}, $i1, $j1, $i2, $j2));
	}
    }
}

=pod

=head2 Joining two grids: (NOTE: this is from before gdal/cache)

    $g3 = $g1->join($g2);

The joining is based on the world coordinates of the grids.  clip and
join without assignment clip or join the original grid, so

    $a->clip($i1, $j1, $i2, $j2);
    $a->join($b);

have the effect "clip a to i1, j1, i2, j2" and "join b to a".

=cut

sub join {
    my $self = shift;
    my $second = shift;
    if (defined wantarray) {
	my $g = new Geo::Raster(ral_gdjoin($self->{GRID}, $second->{GRID}));
	return $g;
    } else {
	$self->_new_grid(ral_gdjoin($self->{GRID}, $second->{GRID}));
    }
}

=pod

=head2 Transforming a grid

    $g2 = $g1->transform(\@tr, $M, $N, $pick, $value);

or, again just (changes the g1 instead of creating a new grid):

    $g1->transform(\@tr, $M, $N, $pick, $value);

g2 will be of size M,N, transformation uses eqs:

  i1 = ai + bi * i2 + ci * j2
  j1 = aj + bj * i2 + cj * j2

whose parameters are in array @tr:

    @tr = (ai, bi, ci, aj, bj, cj);

$pick and $value are optional, $pick may be "mean", "variance", "min",
"max", or "count". If $pick is "count" then $value should be the value
which needs to be counted -- this works only for integer grids. Result
grid is the same type as input except for mean and variance which are
always floats. Division by n-1 is used for calculating variance.

In the case when $pick is not defined, the value which is stored into
the target grid is looked up from the source grid using the equations
above, and rounding the indexes to the nearest integer value.

In the case when $pick is defined, the value which is stored into the
target grid is calculated from the (possibly rectangular) area into
which the i2,j2 cell maps to. NOTE: In this case the cell coordinates
are assumed to denote the upper left corner of the cell. This makes
it easy to keep the (x,y) of the upper left the same BUT it is
different than the usual assumption that (i,j) denotes the center of
the cell.


=cut

sub transform {
    my($self, $tr, $M, $N, $pick, $value) = @_;
    $pick = $pick || 0;
    $value = $value || 0;
    unless ($pick =~ /^\d+$/) {
	my %map = (mean=>1,variance=>2,min=>10,max=>11,count=>20);
	$pick = $map{$pick};
	croak "transform: unrecognised pick method: $pick" unless $pick;
    }
    croak "transform: transformation matrix incomplete" if $#$tr<5;
    if (defined wantarray) {
	my $g = new Geo::Raster(ral_gdtransform($self->{GRID}, $tr, $M, $N, $pick, $value));
	return $g;
    } else {
	$self->_new_grid(ral_gdtransform($self->{GRID}, $tr, $M, $N, $pick, $value));
    }
}

=pod

=head2 The print method

    $gd->print();

simply prints the grid to stdout.

=cut

sub print {
    my($self,%opt) = @_;
    ral_gdprint($self->{GRID});
}

=pod

=head2 Making an array of data in a grid

    $aref = $gd->array;

The $aref is a reference to an array of cells and values:

(i0,j0,val0,i1,j1,val1,i2,j2,val2,i3,j3,val3,...).

=cut

sub array {
    my($self,%opt) = @_;
    my $a = ral_gd2list($self->{GRID});
    return $a;
}

=pod

=head2 Framing a grid

    $framed_grid = $grid->frame($with);

$with is a scalar and the border cells of $grid is set to that value.

=cut

sub frame {
    my $self = shift;
    my $with = shift;
    my($datatype, $M, $N) = ($self->attrib())[0..2];
    if (defined wantarray) {
	my $g = new Geo::Raster($datatype, $M, $N);
	ral_gdcopy_bounds($self->{GRID}, $g->{GRID});
	$self = $g;
    }
    my($i, $j);
    for $i (0..$M-1) {
	$self->set($i, 0, $with);
	$self->set($i, $N-1, $with);
    }
    for $j (1..$N-2) {
	$self->set(0, $j, $with);
	$self->set($M-1, $j, $with);
    }
    return $self if defined wantarray;
}


=pod

=head2 Getting an overview of the contents of a grid

Histogram may be calculated using the method "histogram":

    $histogram = $gd->histogram(\@bin);

which returns a reference to an array which holds the counts of cells
in each bin, first bin is values <= $bin[0], second bin is values >
$bin[0] and values <= $bin[1], etc. 

If the parameter is an integer value, the bins are internally created
by splitting the range [minval..maxval] into that many parts and the
return value is a hash where the key is the center value of the bin
(suitable for gnuplot histeps plotting style).

=cut

sub histogram {
    my $self = shift;
    my $bins = shift;
    $bins = 20 unless $bins;
    my $a;
    if (ref($bins)) {
	$a = gdhistogram($self->{GRID}, $bins, $#$bins+1);
	return @$a;
    } else {
	my $bins = int($bins);
	my ($minval,$maxval) = $self->getminmax();
	my @bins;
	my $i;
	my $d = ($maxval-$minval)/$bins;
	$bins[0] = $minval + $d;
	for $i (1..$bins-2) {
	    $bins[$i] = $bins[$i-1]+$d;
	}
	$bins[$bins-1] = $maxval;
	my $counts = _gdhistogram($self->{GRID}, \@bins, $bins+1);
	# now, $$counts[$n] should be zero, right? 
	# (there are no values > maxval)
	unshift @bins, $minval;
	my $a = {};
	for $i (0..$bins-1) {
	    $a->{($bins[$i]+$bins[$i+1])/2} = $counts->[$i];
	}
	return $a;
    }
}

=pod

A simpler tool that resembles histogram is contents:

    $contents = $gd->contents();

which returns a reference to a hash which has, values as keys and
counts as values. This works for both integer and floating point
grids.

=cut

sub contents {
    my $self = shift;
    if ($self->{DATATYPE} == $INTEGER_GRID) {
	return gdcontents($self->{GRID});
    } else {
	my $c = $self->array();
	my %d;
	my $i;
	for ($i=0; $i<=$#$c; $i+=3) {
	    $d{$c->[$i+2]}++;
	}
	return \%d;
    }
}

=pod

=head2 Zonal functions

All zonal functions require two grids: the operand grid and the zones
grid. The operand grid may be any grid. The zones grid has to be an
integer grid. The zonal functions all return a hash, where the keys
are the integers from the zones grid (not nodata but 0 yes). The
values in the hash are either all the values (nodata values skipped)
from the zone (as a reference to an array) or some function (count,
sum, min, max, mean, variance) of them. The method which returns all
the zone data may of course be used to calculate whatever function but
this can take a lot of memory and computing time in the case of large
grids. Division by n-1 is used for calculating variance.

    $zh = $gd->zones($zones);

    $counts = $gd->zonalcount($zones);
    $sums = $gd->zonalsum($zones);
    $mins = $gd->zonalmin($zones);
    $maxs = $gd->zonalmax($zones);
    $means = $gd->zonalmean($zones);
    $variances = $gd->zonalvariance($zones);

The zones grid can be changed using the method 

    $zones->growzones($grow);

or

    $new_zones = $zones->growzones($grow);

which "grows" each zone in the zones grid iteratively to areas
designated by the (binary) grid grow.

Note that also zero zone is also a zone. Only nodata areas are not
zoned.

=cut

sub zones {
    my($self, $zones) = @_;
    return gdzones($self->{GRID}, $zones->{GRID});
}

sub zonalfct {
    my($self, $zones, $fct) = @_;
    my $z = gdzones($self->{GRID}, $zones->{GRID});
    my %m;
    foreach (keys %{$z}) {
	my $stat = Statistics::Descriptive::Full->new();
	$stat->add_data(@{$z->{$_}});
	$m{$_} = $stat->mean();
	undef $stat;
    }
    return \%m;
}

sub zonalcount {
    my($self, $zones) = @_;
    return gdzonalcount($self->{GRID}, $zones->{GRID});
}

sub zonalsum {
    my($self, $zones) = @_;
    return gdzonalsum($self->{GRID}, $zones->{GRID});
}

sub zonalmin {
    my($self, $zones) = @_;
    return gdzonalmin($self->{GRID}, $zones->{GRID});
}

sub zonalmax {
    my($self, $zones) = @_;
    return gdzonalmax($self->{GRID}, $zones->{GRID});
}

sub zonalmean {
    my($self, $zones) = @_;
    return gdzonalmean($self->{GRID}, $zones->{GRID});
}

sub zonalvariance {
    my($self, $zones) = @_;
    return gdzonalvariance($self->{GRID}, $zones->{GRID});
}

sub growzones {
    my($zones, $grow, $connectivity) = @_;
    $connectivity = 8 unless defined($connectivity);
    $zones = new Geo::Raster $zones if defined wantarray;
    ral_gdgrowzones($zones->{GRID}, $grow->{GRID}, $connectivity);
    return $zones if defined wantarray;
}

=pod

=head2 Interpolation

    $g->interpolate(method=>"nn");

or

    $a = $b->interpolate(method=>"nn");

This method interpolates values for all nodata cells.  Currently only
the method of using the value of nearest cell ("nn") is implemented.

=cut

sub interpolate {
    my($self, %o) = @_;
    if (!$o{method}) {
	print "WARNING: interpolation method not set, using nearest data cell\n";
	$o{method} = 'nn';
    }
    my $new;
    if ($o{method} eq 'nn') {
	$new = ral_gdnn($self->{GRID});
	if ($new) {
	    $new = new Geo::Raster $new;
	} else {
	    return;
	}
    } else {
	print "WARNING: interpolation method '$o{method}' not implemented\n";
	return;
    }
    if (defined wantarray) {
	return $new;
    } else {
	my $tmp = $new->{GRID};
	$new->{GRID} = $self->{GRID};
	$self->{GRID} = $tmp;
    }
}

=pod

=head2 Filling a grid using an arbitrary function of x and y

    $g->function("<function of x and y>");

fills the grid by calculating the z value for each grid cell
separately using the world coordinates. An example of a 
function string is '2*$x+3*$y', which creates a plane.

=cut

sub function {
    my($self, $fct) = @_;
    my(undef, $M, $N, $cell_size, $minX, $minY, $maxX, $maxY) = $self->attributes();
    my $y = $minY+$cell_size/2;
    for my $i (0..$M-1) {
	my $x = $minX+$cell_size/2;
	$y += $cell_size;
	for my $j (0..$N-1) {
	    $x += $cell_size;
	    my $z = eval $fct;
	    $self->set($i, $j, $z);
	}
    }
}


sub dijkstra {
    my($self, $i, $j) = @_;
    my $cost = ral_dijkstra($self->{GRID}, $i, $j);
    return unless $cost;
    $cost = new Geo::Raster $cost;
    return $cost;
}


=pod

=head1 GRAPHICS

=head2 Primitives:

Drawing a line to a grid:

    $gd->line($i1, $j1, $i2, $j2, $pen);

a filled rectangle:

    $gd->rect($i1, $j1, $i2, $j2, $pen);

a circle:

    $gd->circle($i, $j, $r, $pen);

Without $pen these change into "extended" get. Then the method returns
an array (i,j,value, i,j,value, ...) of all values under the line,
rect or circle.

=cut

sub line {
    my($self, $i1, $j1, $i2, $j2, $pen) = @_;
    unless (defined $pen) {
	return ral_gdget_line($self->{GRID}, $i1, $j1, $i2, $j2);
    } else {
	ral_gdline($self->{GRID}, $i1, $j1, $i2, $j2, round($pen), $pen);
    }
}


sub rect {
    my($self, $i1, $j1, $i2, $j2, $pen) = @_;
    unless (defined $pen) {
	return ral_gdget_rect($self->{GRID}, $i1, $j1, $i2, $j2);
    } else {
	ral_gdfilledrect($self->{GRID}, $i1, $j1, $i2, $j2, round($pen), $pen);
    }
}

sub circle {
    my($self, $i, $j, $r, $pen) = @_;
    unless (defined $pen) {
	return ral_gdget_circle($self->{GRID}, $i, $j, round($r), round($r*$r));
    } else {
	ral_gdfilledcircle($self->{GRID}, $i, $j, round($r), round($r*$r), round($pen), $pen);
    }
}

sub floodfill {
    my($self, $i, $j, $pen, $connectivity) = @_;
    $connectivity = 8 unless $connectivity;
    ral_gdfloodfill($self->{GRID}, $i, $j, round($pen), $pen, $connectivity);
}

=pod

=head1 IMAGE MANIPULATION METHODS

=head2 Mapping values

    $img2 = $img1->map(\%map);

or

    $img->map(\%map);

or, for example, using an anonymous hash created on the fly

    $img->map({1=>5,2=>3});

Maps cell values (keys in map) in img1 to respective values in map in
img2 or within img.  Works only for integer grids.

Hint: Take the contents of a grid, manipulate it and then feed it to
the map.

=cut

#################################################################
#
# methods for images
#
#################################################################

sub map {
    my($self, $map) = @_;
    my(@source, @destiny);
    foreach (sort {$a<=>$b} keys %{$map}) {
	push @source, $_;
	push @destiny, $$map{$_};
    }
    my $n = $#source+1;
    $self = new Geo::Raster $self if defined wantarray;
    ral_gdmap($self->{GRID}, \@source, \@destiny, $n);
    return $self if defined wantarray;
}


sub neighbors {
    my $self = shift;
    $a = gdneighbors($self->{GRID});
    return $a;
}

=pod

=head2 Creating a colored map

    $colored_map = $img->colored_map();

or

    $img->colored_map();

Uses the least possible number (?) of unique colors to color the map
(= image which consists of areas).


=cut

sub colored_map {
    my $self = shift;
    my $n = $self->neighbors();
    my %map;
    $map{0} = 0;
    my $base;
    my %nn;
    foreach $base (sort {$a<=>$b} keys %{$n}) {
	next if $base == 0;
	my $m = 1;
	$map{$base} = $m unless defined($map{$base});
	my $skip = $map{$base};
	foreach (@{$$n{$base}}) {	
	    if (!defined($map{$_})) {
		$m++;
		$m++ if $m == $skip;
		$map{$_} = $m;
	    } elsif ($map{$_} == $skip) {
		# redefining:
		$m++;
		$m++ if $m == $skip;
		my $m2 = $m;
		while ($nn{$m2}{$_}) {	
		    # some base -> $m2 and $_ is already a neighbor of $m2
		    $m2++;
		    $m2++ if $m2 == $skip;
		}
		$map{$_} = $m2;
	    }
	    $nn{$skip}{$_} = 1;
	}
    }
    if (defined wantarray) {
	return $self->map(\%map);
    } else {
	$self->map(\%map);
    }
}


=pod

=head2 applytempl

The "apply template" method is a generic method which is, e.g., used
in the thinning algorithm below.

    $gd->applytempl(\@templ, $new_val);

applytempl which takes a structuring template and a new value as
parameters. A structuring template is an integer array [0..8] where 0
and 1 mean a binary value and -1 is don't care.  The array is the 3x3
neighborhood:

0 1 2
3 4 5
6 7 8

The cell 4 is the center of the template. If the template matches a
cell's neighborhood, the cell will get the given new value after all
cells are tested. The grid on which applytemp is used should be a 
binary grid. In void context the method changes the grid, otherwise
the method returns a new grid.


=cut

sub applytempl {
    my($self, $templ, $new_val) = @_;
    croak "applytempl: too few values in the template" if $#$templ < 8;
    $new_val = 1 unless $new_val;
    $self = new Geo::Raster $self if defined wantarray;
    ral_gdapplytempl($self->{GRID}, $templ, $new_val); 
    return $self if defined wantarray;
}


=pod

=head2 thin

Thinning:

    $thinned_img = $img->thin(%options);

or

    $img->thin(%options);

This is an implementation of the algorithm in Jang, B-K., Chin,
R.T. 1990. Analysis of Thinning Algorithms Using Mathematical
Morphology. IEEE Trans. Pattern Analysis and Machine
Intelligence. 12(6). 541-551. (Same as in Grass but done in a bit
different, and more generic way, I believe). Options are algorithm=>,
trimming=>, maxiterations=>, and width=>. Algorithm is by default "B"
(other option is "A"), trimming is by default 0 (other option is 1),
and maxiterations is by default 0 (no maximum, will iterate until no
cells are deleted), if width is used, maxiterations is set to
int(width/2). Trimming removes artificial branches which grow on the
side of wide lines in thinnning but it also shortens a bit the real
branches. The thinned grid must be a binary grid.

The thinning algorithm defines a set of structuring templates and
applies them in several passes until there are no matches or until the
maxiterations is reached. Trimming means certain structuring templates
are applied to kill emerging short limbs which appear because of the
noise in the grid.

=cut

sub thin {
    my($self, %opt) = @_;
    $self = new Geo::Raster $self if defined wantarray;
    my @D1 = (+0,+0,-1,
	      +0,+1,+1,
	      -1,+1,-1);
    my @D2 = (-1,+0,+0,
	      +1,+1,+0,
	      -1,+1,-1);
    my @D3 = (-1,+1,-1,
	      +1,+1,+0,
	      -1,+0,+0);
    my @D4 = (-1,+1,-1,
	      +0,+1,+1,
	      +0,+0,-1);
    my @E1 = (-1,+0,-1,
	      +1,+1,+1,
	      -1,+1,-1);
    my @E2 = (-1,+1,-1,
	      +1,+1,+0,
	      -1,+1,-1);
    my @E3 = (-1,+1,-1,
	      +1,+1,+1,
	      -1,+0,-1);
    my @E4 = (-1,+1,-1,
	      +0,+1,+1,
	      -1,+1,-1);
    # G are the trimming templates
    my @G1 = (-1,+1,-1,
	      +0,+1,+0,
	      +0,+0,+0);
    my @G2 = (+0,+0,+1,
	      +0,+1,+0,
	      +0,+0,+0);
    my @G3 = (+0,+0,-1,
	      +0,+1,+1,
	      +0,+0,-1);
    my @G4 = (+0,+0,+0,
	      +0,+1,+0,
	      +0,+0,+1);
    my @G5 = (+0,+0,+0,
	      +0,+1,+0,
	      -1,+1,-1);
    my @G6 = (+0,+0,+0,
	      +0,+1,+0,
	      +1,+0,+0);
    my @G7 = (-1,+0,+0,
	      +1,+1,+0,
	      -1,+0,+0);
    my @G8 = (+1,+0,+0,
	      +0,+1,+0,
	      +0,+0,+0);
    my @trimmer = (\@G1,\@G2,\@G3,\@G4,\@G5,\@G6,\@G7,\@G8);
    my $algorithm = $opt{algorithm};
    $algorithm = 'B' unless $algorithm;
    my $trimming = $opt{trimming};
    $trimming = 0 unless $trimming;
    my $maxiterations = $opt{maxiterations};
    $maxiterations = 0 unless $maxiterations;
    my $width = $opt{width};
    $maxiterations = int($width/2) if $width;
    my @thinner;
    if ($algorithm eq 'B') {
	if ($trimming) {
	    @thinner = (\@D1,\@D2,\@E1,@trimmer,
			\@D2,\@D3,\@E2,@trimmer,
			\@D3,\@D4,\@E3,@trimmer,
			\@D4,\@D1,\@E4,@trimmer);
	} else {
	    @thinner = (\@D1, \@D2, \@E1, \@D2, \@D3, \@E2,
			\@D3, \@D4, \@E3, \@D4, \@D1, \@E4);
	}
    } elsif ($algorithm eq 'A') {
	if ($trimming) {
	    @thinner = (\@D1, \@E1, @trimmer,
			\@D2, \@E2, @trimmer,
			\@D3, \@E3, @trimmer,
			\@D4, \@E4, @trimmer);
	} else {
	    @thinner = (\@D1, \@E1, \@D2, \@E2, \@D3, \@E3, \@D4, \@E4);
	}
    } else {
	croak "thin: $algorithm: unknown algorithm";
    }
    my ($m, $M, $i) = (0,0,1);
    do {
	$M = $m;
	foreach (@thinner) {
	    $m += ral_gdapplytempl($self->{GRID}, $_, 0);
	    print STDERR "#" unless $opt{quiet};
	}
	print STDERR " thinning, pass $i/$maxiterations: deleted ", $m-$M, " cells\n" unless $opt{quiet};
	$i++;
    } while ($m > $M and !($maxiterations > 0 and $i > $maxiterations));
    return $self if defined wantarray;
}

=pod

=head2 Borderizing

    $borders_img = $img->borders(method=>simple|recursive);

or

    $img->borders(method=>simple|recursive);

The default method is "recursive" which finds all areas (8-connected
cells with non-zero values) and marks their borders with respective
values and leaves the rest of the area zero.

=cut

sub borders {
    my($self,%opt) = @_;
    my $method = $opt{method};
    if (!$method) {
	$method = 'recursive';
	print "border: Warning: method not set, using '$method'\n";
    }    
    if ($method eq 'simple') {
	if (defined wantarray) {
	    my $g = new Geo::Raster(ral_gdborders($self->{GRID}));
	    return $g;
	} else {
	    $self->_new_grid(ral_gdborders($self->{GRID}));
	}
    } elsif ($method eq 'recursive') {
	if (defined wantarray) {
	    my $g = new Geo::Raster(ral_gdborders_recursive($self->{GRID}));
	    return $g;
	} else {
	    $self->_new_grid(ral_gdborders_recursive($self->{GRID}));
	}
    } else {
	croak "border: $method: unknown method";
    }
}

=pod

=head2 Find the areas in an image

    $areas_in_img = $img->areas($k);

or

    $img->areas($k);

The $k (3 if not given) is the number of consecutive non-zero
8-neighbors required before the cell is assumed to be a part of an
area.

=cut

sub areas {
    my $self = shift;
    my $k = shift;
    $k = 3 unless $k;
    if (defined wantarray) {
	my $g = new Geo::Raster(ral_gdareas($self->{GRID}, $k));
	return $g;
    } else {
	$self->_new_grid(ral_gdareas($self->{GRID}, $k));
    }
}

=pod

=head2 Connect broken lines

    $img2 = $img1->connect();

or

    $img->connect();

If two 8-neighbor opposite cells (1-5, 2-6, etc) of a cell are the
same and the cell is zero, then the value of this cell is set to the
same value.

=cut

sub connect {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster $self;
	return ral_gdconnect($self->{GRID});
    } else {
	ral_gdconnect($self->{GRID});
    }
}

=pod

=head2 Number areas with unique id in an image

    $map = $img->number_areas($connectivity);

or

    $img->number_areas($connectivity);

$map or $img contains each consecutive area in $img colored with an
unique integer. $img should be a 0,1 grid, the result is a 0,2,3,...
grid. The connectivity of areas is either 8 (default) or 4.

=cut

sub number_areas {
    my($self, $connectivity) = @_;
    $connectivity = 8 unless $connectivity;
    if (defined wantarray) {
	my $g = new Geo::Raster($self);
	if (ral_gdnumber_of_areas($g->{GRID}, $connectivity)) {
	    return $g;
	}
    } else {
	ral_gdnumber_of_areas($self->{GRID}, $connectivity);	
    }
}

sub color_scheme {
    my($self,$color_scheme) = @_;
    if (defined $color_scheme) {
	croak "Unknown color scheme: $color_scheme" unless defined $COLOR_SCHEMES{$color_scheme};
	$self->{COLOR_SCHEME} = $COLOR_SCHEMES{$color_scheme};
    } else {
	unless (defined $self->{COLOR_SCHEME}) {
	    my $ct = $self->get_color_table(1);
	    if ($ct->GetCount) {
		$self->{COLOR_SCHEME} = $COLOR_SCHEMES{Colortable};
	    } else {
		$self->{COLOR_SCHEME} = $COLOR_SCHEMES{Grayscale};
	    }
	}
	return $self->{COLOR_SCHEME};
    }
}

sub get_color_table {
    my($self,$create_allowed) = @_;
    return $self->{COLOR_TABLE} if $self->{COLOR_TABLE};
    if ($self->{GDAL}) {
	$self->{COLOR_TABLE} = $self->{GDAL}->{dataset}->GetRasterBand($self->{GDAL}->{band})->GetRasterColorTable;
    }
    if (!$self->{COLOR_TABLE} and $create_allowed) {
	$self->{COLOR_TABLE} = new gdal::ColorTable;
    }
    return $self->{COLOR_TABLE};
}

sub render {
    my($self, $pb, $alpha) = @_;

    my $pbw = ral_pixbuf_get_world($pb);
    my($minX,$minY,$maxX,$maxY,$pixel_size,$w,$h) = @$pbw;

    my $gdal = $self->{GDAL};
    if ($gdal) {
	$self->cache($minX,$minY,$maxX,$maxY,$pixel_size);
	return unless $self->{GRID} and ral_gdget_height($self->{GRID});
    }

    $alpha = $alpha->{GRID} if $alpha and ref($alpha) eq 'Geo::Raster';
	
    # NOTE: this scales to the view

    # draw arrows for flow direction grids (if it makes sense) 
    if ($self->{FDG} and $self->{CELL_SIZE}/$pixel_size >= 5) {

	ral_render_fdg($pb, $self->{GRID}, 255, 0, 0, $alpha);

    } else {

	my $color_scheme = $self->color_scheme();
	my $min = ($self->{PALETTE_MIN} or 0);
	my $max = ($self->{PALETTE_MAX} or 0);

	if ($self->{DATATYPE} == $INTEGER_GRID) {

	    my $color_table = $self->get_color_table(1);

	    ral_render_igrid($pb, $self->{GRID}, $alpha, $color_scheme, $min, $max, $color_table);

	} elsif ($self->{DATATYPE} == $REAL_GRID) {

	    ral_render_rgrid($pb, $self->{GRID}, $alpha, $color_scheme, $min, $max);

	} else {

	    croak("bad Geo::Raster");

	}
    }
}

sub save_as_image {
    my($self, $filename, $type, $option_keys, $option_values) = @_;
    my $b = ral_pixbuf_new_from_grid($self->{GRID});
    $self->render($b, 255);
    $option_keys = [] unless $option_keys;
    $option_values = [] unless $option_values;
    ral_pixbuf_save($b, $filename, $type, $option_keys, $option_values);
    ral_pixbuf_delete($b);
}

=pod

=head1 TERRAIN ANALYSIS METHODS

=head2 METHODS FOR DIGITAL ELEVATION MODELS (DEMS)

=head2 Slope and aspect

Generate an aspect grid from a DEM:

    $aspect = $dem->aspect();

or

    $dem->aspect(); # to convert the DEM to an aspect grid

The returned aspect grid is a real number grid (-1,0..2*Pi) where -1
denotes flat area, 0 aspect north, Pi/2 aspect east, etc.

=cut

sub aspect {
    my $self = shift;
    my $r = shift;
    $r = 1 unless $r;
    if (defined wantarray) {
	my $g = new Geo::Raster(ral_dem2aspect($self->{GRID}));
	return $g;
    } else {
	$self->_new_grid(ral_dem2aspect($self->{GRID}));
    }
}

=pod

Similar method exist for calculating a slope grid from a DEM:

    $slope = $dem->slope($z_factor);
    $dem->slope($z_factor); # to convert the DEM to a slope grid

Slope and aspect calculations are based on fitting a 9-term quadratic
polynomial:

z = Ax^2y^2 + Bx^2y + Cxy^2 + Dx^2 + Ey^2 + Fxy + Gx + Hy + I

to a 3*3 square grid. See Moore et al. 1991. Hydrol. Proc. 5, 3-30.

Slope is calculated in radians.

z_factor is the unit of z dived by the unit of x and y, the default
value of z_factor is 1.

=cut

sub slope {
    my $self = shift;
    my $z_factor = shift;
    $z_factor = 1 unless $z_factor;
    if (defined wantarray) {
	my $g = new Geo::Raster(ral_dem2slope($self->{GRID}, $z_factor));
	return $g;
    } else {
	$self->_new_grid(ral_dem2slope($self->{GRID}, $z_factor));
    }
}

=pod

=head2 Flow direction grid (FDG) from DEM

    $fdg = $dem->fdg(method=>$method);

or

    $dem->fdg(method=>$method); # to convert the DEM to a FDG 

The method is optional. The default method is D8 (deterministic
eight-neighbors steepest descent) and the returned FDG is of type D8,
i.e., an integer grid (-1..8) where -1 denotes flat area, 0 a pit, 1
flow direction north, 2 north-east, etc.  A pit is the lowest point of
a depression. Another supported method is Rho8 (stochastic
eight-neighbors aspect-based) which also produces a D8 FDG but the
direction is chosen between the two steepest descent directions
(assumed to being next to each other) so that the expected direction
is the true aspect (Fairfield and Leymarie, Water Resour. Res. 27(5)
709-717). The third method is "many" which produces a FDG, where the
bits in each byte (actually a short integer) in each cell denotes the
neighbors having lower elevation, i.e., value 1 (2**0 = 1) means only
the cell in direction 1 is lower, value 3 (2**0+2**1 = 3) means both
cells in direction 1 and in direction 2 are lower, etc.

=cut

sub fdg {
    my($dem,%opt) = @_;
    if (!$opt{method}) {
	$opt{method} = 'D8';
	print "fdg: WARNING: method not set, using '$opt{method}'\n";
    }
    my $method;
    if ($opt{method} eq 'D8') {
	$method = 1;
    } elsif ($opt{method} eq 'Rho8') {
	$method = 2;
    } elsif ($opt{method} eq 'many') {
	$method = 3;
    } else {
	croak "fdg: $opt{method}: unsupported method";
    }
    my $fdg = ral_dem2fdg($dem->{GRID}, $method);
    if (defined wantarray) {
	$fdg = new Geo::Raster $fdg;
	$fdg->{FDG} = 1;
	return $fdg;
    } else {
	$dem->_new_grid($fdg);
	$dem->{FDG} = 1;
    }
}

sub outlet {
    my($fdg,@cell) = @_;
    my $cell = _find_outlet($fdg->{GRID},@cell);
    return @{$cell};
}

sub ucg {
    my($dem) = @_;
    my $ucg = ral_dem2ucg($dem->{GRID});
    if (defined wantarray) {
	$ucg = new Geo::Raster $ucg;
	return $ucg;
    } else {
	$dem->_new_grid($ucg);
    }
}

sub many2ds {
    my($fdg) = @_;
    my %map;
    for my $i (1..255) {
	my $c = 0;
	for my $j (0..7) {
	    $c++ if $i & 1 << $j;
	}
	$map{$i} = $c;
    }
    $fdg->map(\%map);
}

=pod

=head2 METHODS FOR D8 FDGS

=head2 General movecell method for 8-neighborhood

    $gd->movecell(@cell, $dir);

this returns undef if the cell moves outside of the grid.  

If $dir is not given we assume this grid to be a FDG
and then the dir is in the grid.

=cut

sub movecell {
    my($fdg, $i, $j, $dir) = @_;
    $dir = $fdg->get($i, $j) unless $dir;
  SWITCH: {
      if ($dir == 1) { $i--; last SWITCH; }
      if ($dir == 2) { $i--; $j++; last SWITCH; }
      if ($dir == 3) { $j++; last SWITCH; }
      if ($dir == 4) { $i++; $j++; last SWITCH; }
      if ($dir == 5) { $i++; last SWITCH; }
      if ($dir == 6) { $i++; $j--; last SWITCH; }
      if ($dir == 7) { $j--; last SWITCH; }
      if ($dir == 8) { $i--; $j--; last SWITCH; }
      croak "movecell: $dir: bad direction";
  }
    return if ($i < 0 or $j < 0 or $i >= $fdg->{M} or $j >= $fdg->{N});
    return ($i, $j);
}


=pod

=head2 Upstream cells

A method for flow direction grid to get the directions of upstream
cells of a cell:

    ($up,@up) = $fdg->upstream($streams,@cell);

or

    (@up) = $fdg->upstream(@cell);

$up is the direction of upstream stream cell and @up contain
directions of other upstream cells.

=cut

# dirs of upstream cells     <- streams not given
# or upstream stream cells   <- streams given
sub upstream { # (fdg,{streams,}cell)
    my $fdg = shift;
    my $streams;
    my @cell;
    if ($#_ > 1) {
	($streams,@cell) = @_;
    } else {
	@cell = @_;
    }
    my @up;
    my $d;
    for $d (1..8) {
	my @test = $fdg->movecell(@cell, $d);
	next unless @test;
	my $u = $fdg->get(@test);
	next if $streams and !($streams->get(@test));
	if ($u == ($d - 4 <= 0 ? $d + 4 : $d - 4)) {
	    push @up, $d;
	}
    }
    return @up;
}

=pod

=head2 Draining flat areas

    $fixed_fdg = $fdg->fixflats($dem,method=>$method);

or

    $fdg->fixflats($dem,method=>$method);

The method is either "one pour point" (short "o") or "multiple pour
points" (short "m"). The first method, which is the default, finds the
lowest or nodata cell just outside the flat area and, if the cell is
lower than the flat area or a nodatacell, drains the whole area there,
or into the flat area cell (which is made a pit cell), which is next
to the cell in question. This method is guaranteed to produce a FDG
without flat areas. The second method drains the flat area cells
iteratively into their lowest non-higher neighboring cells having flow
direction resolved.

=cut

sub fixflats {
    my($fdg, $dem, %opt) = @_;
    croak "fixflats: no DEM supplied" unless $dem and ref($dem);
    if (defined wantarray) {
	$fdg = new Geo::Raster $fdg;
	$fdg->{FDG} = 1;
    }
    if (!$opt{method}) {
	$opt{method} = 'one pour point';
	print "fixflats: Warning: method not set, using '$opt{method}'\n";
    }
    if ($opt{method} =~ /^m/) {
	ral_fdg_fixflats1($fdg->{GRID}, $dem->{GRID});
    } elsif ($opt{method} =~ /^o/) {
	ral_fdg_fixflats2($fdg->{GRID}, $dem->{GRID});
    } else {
	croak "fixflats: $opt{method}: unknown method";
    }
    return $fdg if defined wantarray;
}

=pod

=head2 Handling the depressions in a DEM

Methods

    $dem->fill($z_limit);

and 

    $dem->cut($z_limit);

raise or lower cells which are lower or higher than all its
8-neigbors.  The z_limit is the minimum elevation difference, which is
needed to consider a cell lower or higher than all its neighbors.
$z_limit is optional, the deafult value is 0.

A depression (or a "pit") is a connected (in the FDG sense) area in
the DEM, which is lower than all its neighbors. To find and look at
all the depressions use this method, which returns a grid:

    $depressions = $dem->depressions($fdg, $inc_m);

The argument $fdg is optional, the default is to calculate it using
the D8 method and then route flow through flat areas using the methods
"multiple pour points" and "one pour point" (in this order). The
depressions grid is a binary grid unless $inc_m is given and is 1.

Depressions may be removed by filling or by breaching. Filling means
raising the depression cells to the elevation of the lowest lying cell
just outside the depression. Breaching means lowering the elevation of
the "dam" cells. The breaching is tried at the lowest cell on the rim
of the depression which has the steepest descent away from the
depression (if there are more than one lowest cells) and the steepest
descent into the depression (if there are more than one lowest cells
with identical slope out) (see Martz, L.W. and Garbrecht,
J. 1998. I<The treatment of flat areas and depressions in automated
drainage analysis of raster digital elevation
models>. Hydrol. Process. 12, 843-855; the breaching algorithm
implemented here is close to but not the same as theirs - the biggest
difference being that the depression cells are not raised
here). Breaching is often limited to a certain number of cells.  Both
of these methods change the DEM. Both methods need to be run
iteratively to remove all removable depressions. Only the filling
method is guaranteed to produce a depressionless DEM.

The non-iterative versions of the methods are:

    $dem->filldepressions($fdg);

and

    $dem->breach($fdg, $limit);

The $limit in breaching is optional, the default is to not limit the
breaching ($limit == 0). The $fdg, which is given to these algorithms
should not contain flat areas.

If the $fdg is not given it is calculated as above in the depressions
method and the depressions are removed iteratively until all
depressions are removed or the number of depressions does not diminish
in one iteration loop.

A method, which produces a pitless FDG is 

    $fdg = $dem->pitless_fdg();

This method is similar to the above methods but it does not change the
DEM. It changes the path in the FDG from the bottom of the pit to the
lowest pour point of the depression. The method is also iterative as
the above methods. It first computes a FDG without flat areas and then
applies the method $fdg->fixpits($dem) until there are not more pits
or there is no change.

=cut

sub fill {
    my($dem, $z_limit) = @_;
    $z_limit = 0 unless defined($z_limit);
    return ral_dem_fillpits($dem->{GRID}, $z_limit);
}

sub cut {
    my($dem, $z_limit) = @_;
    $z_limit = 0 unless defined($z_limit);
    return ral_dem_cutpeaks($dem->{GRID}, $z_limit);
}

sub depressions {
    my($dem, $fdg, $inc_m) = @_;
    $inc_m = 0 unless defined($inc_m) and $inc_m;
    if (!$fdg) {
	$fdg = $dem->fdg(method=>'D8');
	$fdg->fixflats($dem,method=>'m');
	$fdg->fixflats($dem,method=>'o');
    }
    return new Geo::Raster(ral_dem_depressions($dem->{GRID}, $fdg->{GRID}, $inc_m));
}

sub filldepressions {
    my($dem, $fdg) = @_;
    if ($fdg) {
	return ral_dem_filldepressions($dem->{GRID}, $fdg->{GRID});
    } else {
	$fdg = $dem->fdg(method=>'D8');
	$fdg->fixflats($dem,method=>'m');
	$fdg->fixflats($dem,method=>'o');
	my $c = $fdg->contents();
	my $pits = $$c{0} + 0;
	print STDERR "filldepressions: $pits depressions exist\n";
	my $i = 1;
	my $pits_last_time = $pits+1;
	while ($pits > 0 and $pits != $pits_last_time) {
	    my $fixed = ral_dem_filldepressions($dem->{GRID}, $fdg->{GRID});
	    $fdg = $dem->fdg(method=>'D8');
	    $fdg->fixflats($dem,method=>'m');
	    $fdg->fixflats($dem,method=>'o');
	    $c = $fdg->contents();
	    $pits_last_time = $pits;
	    $pits = $$c{0};
	    $pits = 0 unless defined $pits;
	    print STDERR "filldepressions: iteration $i: fixed $fixed depressions and $pits remain\n";
	    $i++;
	}
	return $fdg;
    }
}

sub breach {
    my($dem, $fdg, $limit) = @_;
    $limit = 0 unless defined($limit);
    if ($fdg) {
	return ral_dem_breach($dem->{GRID}, $fdg->{GRID}, $limit);
    } else {
	$fdg = $dem->fdg(method=>'D8');
	$fdg->fixflats($dem,method=>'m');
	$fdg->fixflats($dem,method=>'o');
	my $c = $fdg->contents();
	my $pits = $$c{0} + 0;
	print STDERR "breach: $pits depressions exist\n";
	my $i = 1;
	my $pits_last_time = $pits+1;
	while ($pits > 0 and $pits < $pits_last_time) {
	    ral_dem_breach($dem->{GRID}, $fdg->{GRID}, $limit);
	    $fdg = $dem->fdg(method=>'D8');
	    $fdg->fixflats($dem,method=>'m');
	    $fdg->fixflats($dem,method=>'o');
	    $c = $fdg->contents();
	    $pits_last_time = $pits;
	    $pits = $$c{0};
	    $pits = 0 unless defined $pits;
	    print STDERR "breach: iteration $i: $pits depressions remain\n";
	    $i++;
	}
	return $fdg;
    }
}

sub pitless_fdg {
    my($dem) = @_;
    my $fdg = $dem->fdg(method=>'D8');
    $fdg->fixflats($dem,method=>'m');
    $fdg->fixflats($dem,method=>'o');
    my $c = $fdg->contents();
    my $pits = $$c{0} + 0;
    print STDERR "pitless_fdg: $pits depressions exist\n";
    my $i = 1;
    my $pits_last_time = $pits+1;
    while ($pits > 0 and $pits != $pits_last_time) {
	ral_fdg_fixpits($fdg->{GRID}, $dem->{GRID});
	$c = $fdg->contents();
	$pits_last_time = $pits;
	$pits = $$c{0};
	$pits = 0 unless defined $pits;
	print STDERR "pitless_fdg: iteration $i: $pits depressions remain\n";
	$i++;
    }
    return $fdg;
}

sub fixpits {
    my($fdg, $dem) = @_;
    croak "fixpits: no DEM supplied" unless $dem;
    $fdg = new Geo::Raster $fdg if defined wantarray;
    ral_fdg_fixpits($fdg->{GRID}, $dem->{GRID});
    return new Geo::Raster $fdg if defined wantarray;
}


=pod

=head2 Routing of water

Method 

    $water->route($dem, $fdg, $flow, $k, $d, $f, $r);

routes water out from a catchment. The method is recursive and routes
water from each cell downslope if water from all its upslope cells
have been routed downslope. 

The catchment tree is traversed using the flow direction grid, which thus
must contain only valid directions (no pits nor flat area cells).

The flow from cell a to a downstream cell b is calculated using eq:

    slope = r * (h(a) - h(b)) / (UNIT_DISTANCE * distance_unit(dir(a->b)))
    flow = k * (slope + d) * water(a)

    r               is the unit of z dived by the unit of x and y, e.g, 
                    if z is given in cm and UNIT_DISTANCE = 25 m, then 
                    r = 1 cm / 1 m = 0.01. $r is by default 1

    h(x)            is the elevation of x

    dir(a->b)       is the direction from a to b

    UNIT_DISTANCE   is a property of the DEM 

    distance_unit() is 1 if direction is north, east, ... and sqrt(2) if
                    direction is north-east, south-east, ...  
    
    k               is a parameter

    d               is a parameter

    water(a)        is the amount of water at cell a

Arguments:

    $water Storage at each cell [grid]
    $dem   DEM (input) [grid]
    $fdg   FDG (input) [grid]
    $flow  Amount of water leaving each cell (output) [grid]
    $k     parameter [grid]
    $d     parameter [grid]
    $f     determines if water is routed from each cell to all of its
           neighbors having the same or lower elevation ($f == 1) or
           to the cell pointed by FDG ($f == 0) (default 1)
    $r     is the unit of z dived by the unit of x and y (default 1)

=cut

sub route {
    my($water, $dem, $fdg, $flow, $k, $d, $f, $r) = @_;
    $f = 1 unless defined $f;
    $r = 1 unless defined $r;
    croak ("usage: $water->route($dem, $fdg, $flow, $k, $d, $f, $r)") unless $flow;
    return water_route($water->{GRID}, $dem->{GRID}, $fdg->{GRID}, $flow->{GRID}, $k->{GRID}, $d->{GRID}, $f, $r);
}


=pod

=head2 Upslope area

Upslope area (as a number of cells) grid (UAG) from D8 FDG:

    $uag = $fdg->uag();

upslope area (as a cell area) directly from a depressionless DEM

    $uag = $dem->uag(fdg=>$fdg);

The FDG should be calculated from the DEM and have no pits or flat
area cells (the FDG returned by the filldepressions is ok).

UAG is a real number grid.

=cut

sub uag {
    my $self = shift;
    my(%options) = @_;

    unless ($options{fdg}) {
	my $fdg = $self;
	my $uag = $options{load} ? 
	    fdg2uag_b($fdg->{GRID}, $options{load}->{GRID}) : 
	    fdg2uag_a($fdg->{GRID});

	if (defined wantarray) {
	    return new Geo::Raster $uag;
	} else {
	    $fdg->_new_grid($uag);
	}
    } else {
	my $dem = $self;
	my $fdg = $options{fdg};
	
#	if (!$fdg) {
#	    $fdg = $dem->fdg(method=>'D8');
#	    $fdg->fixflats($dem,method=>'m');
#	    $fdg->fixflats($dem,method=>'o');
#	}

	my $recursive = $options{recursive} ? 1 : 0;

	my $uag = ral_dem2uag($dem->{GRID}, $fdg->{GRID}, $recursive);
	unless ($uag) {
	    my $msg = ral_get_error_msg() if ral_has_msg();
	    $msg = "undefined error in ral_dem2uag" unless $msg;
	    croak($msg);
	}

	if (defined wantarray) {
	    return new Geo::Raster $uag;
	} else {
	    $dem->_new_grid($uag);
	}
    }
}

sub dag {
    my $dem = shift;
    my $fdg = shift;
    if (!$fdg) {
	$fdg = $dem->fdg(method=>'D8');
	$fdg->fixflats($dem,method=>'m');
	$fdg->fixflats($dem,method=>'o');
    }
    my $dag = ral_dem2dag($dem->{GRID}, $fdg->{GRID});
    if (defined wantarray) {
	return new Geo::Raster $dag;
    } else {
	$dem->_new_grid($dag);
    }
}

=pod

From a 8-direction FDG one can get the upslope area (catchment) of a
cell:

    $catchment = $fdg->catchment($i, $j, $m);

or to mark on an existing grid

    $fdg->catchment($catchment, $i, $j, $m);

The method marks the catchment with $m. $m is not required 1 is used
by default. In an array context the returned array is ($catchment,
$size) where the $size is the size of the catchment.

=cut

sub catchment {
    my $fdg = shift;
    my $i = shift;
    my ($M, $N) = $fdg->size();
    my ($j, $m, $catchment);
    if (ref($i) eq 'Geo::Raster') {
	$catchment = $i;
	$i = shift;
	$j = shift;
	$m = shift;
    } else {
	$catchment = new Geo::Raster(like=>$fdg);
	$j = shift;
	$m = shift;
    }
    if ($i<0 or $i>=$M or $j<0 or $j>=$N) {
	croak "catchment: i or j out of bounds";
    }    
    $m = 1 unless defined($m);
    my $size = ral_fdg_catchment($fdg->{GRID}, $catchment->{GRID}, $i, $j, $m);
    return wantarray ? ($catchment, $size) : $catchment;
}

sub killoutlets {
    my ($fdg, $lakes, $uag) = @_;
    $fdg->{FDG} = 1;
    $uag = $fdg->uag unless $uag;
    return ral_fdg_killoutlets($fdg->{GRID}, $lakes->{GRID}, $uag->{GRID});
}


=pod

=head2 Distance along flow path to open water

Usage: 

$d = $fdg->distance_to_channel($open_water_grid,[$steps])

Description:

Returns a new (real-numbered) grid whose cell values represent the
distance to nearest channel (non-zero value in streams grid) along the
flow path (defined by flow direction grid fdg). The distance is in the
grid units. If steps is given and non-zero, the returned integer grid
measures the distance in steps from pixel to pixel.

=cut

sub distance_to_pit {
    my $fdg = shift;
    my $steps = shift;
    my $g = ral_fdg_distance_to_pit($fdg->{GRID}, $steps);
    return unless $g;
    my $ret = new Geo::Raster $g;
    return $ret;
}

sub distance_to_channel {
    my $fdg = shift;
    my $streams = shift;
    my $steps = shift;
    my $g = ral_fdg_distance_to_channel($fdg->{GRID}, $streams->{GRID}, $steps);
    return unless $g;
    return new Geo::Raster $g;
}

# does not make sense??
sub distance_to_divide {
    my $fdg = shift;
    my $steps = shift;
    my $g = ral_fdg_distance_to_divide($fdg->{GRID}, $steps);
    return unless $g;
    return new Geo::Raster $g;
}

=pod

=head2 METHODS FOR STREAMS GRIDS

Streams grid may be obtained from the upslope-area grid by
thresholding.  If it is to be used with a lakes grid in the
subcatchment method, it should be elaborated using methods:

    $streams->prune($fdg, $lakes, $i, $j, $l);

which removes streams shorter than $l (in grid scale), note: also
streams which end in a lake may be removed. If $l is not given the
method removes one pixel streams. The lakes grid is optional and can
be left out.

    $streams->number_streams($fdg, $lakes, $i, $j);

Gives a unique id for each stream section in a stream-tree, which root
is at (i,j). The lakes grid is optional and can be left out.

=cut

sub prune {
    my $streams = shift;
    my $fdg = shift;
    my $lakes = shift;
    my $i;
    if (ref($lakes)) {
	$i = shift;
    } else {
	$i = $lakes;
	undef $lakes;
    }
    my $j = shift;
    my $l = shift;
    $l = 1.5*$streams->{GRID}->{CELL_SIZE} unless defined($l);
    if ($lakes) {
	return ral_streams_prune($streams->{GRID}, $fdg->{GRID}, $lakes->{GRID}, $i, $j, $l);
    } else {
	return _streams_prune($streams->{GRID}, $fdg->{GRID}, $i, $j, $l);
    }
}

sub number_streams {
    my $streams = shift;
    my $fdg = shift;
    my $lakes = shift;
    my $i;
    if (ref($lakes)) {
	$i = shift;
    } else {
	$i = $lakes;
	undef $lakes;
    }
    my $j = shift;
    my $sid = shift;
    $sid = 1 unless defined($sid);
    ral_streams_number($streams->{GRID}, $fdg->{GRID}, $i, $j, $sid);
    if ($lakes) {
	$sid = $streams->max() + 1;
	ral_streams_break($streams->{GRID}, $fdg->{GRID}, $lakes->{GRID}, $sid);
    }
}

=pod

=head2 Generation of a subcatchment grid 

Subcatchment grid shows all subcatchments defined by a stream network.

    $subcatchments = $streams->subcatchments($fdg, $i, $j);

or 

    ($subcatchments, $topo) = 
        $streams->subcatchments($fdg, $lakes, $i, $j);

where the i,j is the outlet point of the whole catchment. $topo is the
topology of the catchment as a hash of associations:

$upstream_element=>$downstream_element

=cut

sub subcatchments {
    my $streams = shift;
    my $fdg = shift;
    my $lakes;
    my $i = shift;
    if (ref($i) eq 'Geo::Raster') {
	$lakes = $i;
	$i = shift;
    }
    my $j = shift;
    my $headwaters = shift;
    $headwaters = 0 unless defined($headwaters);
    if ($lakes) {
	my $subs = new Geo::Raster(like=>$streams);
	my $r = ral_ws_subcatchments($subs->{GRID}, 
				     $streams->{GRID}, 
				     $fdg->{GRID}, 
				     $lakes->{GRID}, $i, $j, $headwaters);
	
	# drainage structure:
	# sub -> lake or stream
	# lake -> stream
	# stream -> lake or stream

	my %ds;
	foreach (sort keys %{$r}) {
	    ($i, $j) = split /,/;
	    my($i_down, $j_down) = split(/,/, $$r{$_});
	    my $sub = $subs->get($i, $j);
	    my $stream = $streams->get($i, $j);
	    my $lake = $lakes->get($i, $j);
	    my $sub_down = $subs->get($i_down, $j_down);
	    my $stream_down = $streams->get($i_down, $j_down);
	    my $lake_down = $lakes->get($i_down, $j_down);
	    if ($lake <= 0) {
		if ($stream != $stream_down) {
		    $ds{"sub $sub $i $j"} = "stream $stream";
		    $ds{"stream $stream $i $j"} = "stream $stream_down";
		} else {
		    $ds{"head $sub $i $j"} = "stream $stream";
		}
	    } else {
		$ds{"sub $sub $i $j"} = "lake $lake";
		$ds{"lake $lake $i $j"} = "stream $stream_down";
	    }
	    if ($lake_down > 0) {
		$ds{"stream $stream $i $j"} = "lake $lake_down";
	    }
	}

	return wantarray ? ($subs,\%ds) : $subs;
    } else {
	return new Geo::Raster(streams_subcatchments($streams->{GRID}, $fdg->{GRID}, $i, $j));
    }
}

call_g_type_init();
gdal::AllRegister;
gdal::UseExceptions();

1;
__END__


=head1 BUGS

DInfinity grids can be made but otherwise the methods to handle them
do not work.

=head1 SEE ALSO

gdalconst, gdal

This module should be discussed in geo-perl@list.hut.fi.

The homepage of this module is http://libral.sf.net.

=head1 AUTHOR

Ari Jolma, ari.jolma _at_ tkk.fi

=head1 COPYRIGHT AND LICENSE

Copyright (C) 1999-2006 by Ari Jolma

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut

