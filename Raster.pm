package Geo::Raster;

use strict;
use POSIX;
use Carp;
use FileHandle;
use Statistics::Descriptive; # used in zonalfct
use Config; # for byteorder
use vars qw(@ISA @EXPORT %EXPORT_TAGS @EXPORT_OK $AUTOLOAD 
	    $VERSION $BYTE_ORDER $dbh $INTEGER_GRID $REAL_GRID);

$VERSION = '0.21';

# TODO: make these constants:
$INTEGER_GRID = 1;
$REAL_GRID = 2;

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

use vars qw(%recognized_extensions);

%recognized_extensions = (asc=>'Arc/Info ascii',
			  e=>'Arc/Info interchange',
			  ppm=>'ppm',
			  jpeg=>'ppmtojpeg',
			  jpg=>'ppmtojpeg',
			  png=>'pnmtopng');

sub dl_load_flags {0x01}

bootstrap Geo::Raster $VERSION;

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

use overload ('fallback' => undef,
	      'bool'     => 'bool',
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
adds some very useful functionality to it.

Each cell in raster/grid is assumed to be a square. The grid point
represents the center of the cell.

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

    $gd = new Geo::Raster(filename=>"data/dem");

or simply

    $gd = new Geo::Raster("data/dem");

The default format for grids is a pair of [bil|dem]/hdr files. The
extension of the binary file can be set using named parameter
ext. Currently only one-channel 8, 16, or 32 bit images can be read. 8
and 16 bit images are loaded as integer grids and 32 bit images as
real grids. The datatype of the grid can be specified using named
parameter datatype. byte images are by default read into integer
grids. If a hdr file is not found the method attempts to read a pair
of img/doc (Idrisi (c)) files. NOTE 1: in hdr files ULXMAP and ULYMAP
denote the x,y of the center point of the upper left pixel. NOTE 2: in
hdr files BYTEORDER may be I (intel, little-endian) or M (motorola,
big-endian).

To start with a new grid:

    $gd = new Geo::Raster(datatype=>$datatype,M=>100,N=>100);

or simply

    $gd = new Geo::Raster(1,100,100);

or even more simply

    $gd = new Geo::Raster(100,100);

$datatype is optional, the default is $INTEGER_GRID, $REAL_GRID is
another possibility. Constants $INTEGER_GRID and $REAL_GRID are imported
by :types. Opening a previously saved grid sets the name attribute
of the grid.

Other constructors exist, this is a copy:

    $g2 = new Geo::Raster(copy=>$g1);

or simply

    $gd = new Geo::Raster($g1); 

See below a note about known extensions.

to create a grid with same size use like:

    $g2 = new Geo::Raster(like=>$g1);

In both copy methods the datatype of the result is the same as in the
original grid. Use named parameter datatype=>DATATYPE to upgrade an integer
grid to a real grid or downgrade a real grid to an integer grid.

You can also import data:

    $gd = new Geo::Raster(filename=>$filename, import=>$format);

or simply

    $gd = new Geo::Raster("image.ppm");

$format may currently be "Arc/Info ascii export", "Arc/Info
interchange" or "ppm".  Arc/Info interchange format may contain other
information besides the grid, this is printed out if the option
print_header is set. Currently the number of columns in the grid as
specified by the interchange file is increased by 3 - why it must do
this is unexplained. Datatype may also be set while importing. When
importing ppm images you can specify option "channel" as "red",
"green", or "blue", the default is to use the luminance value.

Importing is launched if the filename of the grid to be opened has
a recognized extension.

=cut

sub _set_attr {
    my $self = shift;
    $self->{M} = ral_gdgetM($self->{GRID});
    $self->{N} = ral_gdgetN($self->{GRID});
    $self->{DATATYPE} = ral_gddatatype($self->{GRID});
}

sub _new_grid {
    my $self = shift;
    my $grid = shift;
    return unless $grid;
    ral_gddestroy($self->{GRID});
    $self->{GRID} = $grid;
    $self->_set_attr;
}

sub new {
    my $class = shift;
    my $self = {};
    $self->{COLOR_TABLE} = ral_ctcreate(0, 0, 0);

    if (ref($_[0]) eq 'gridPtr' or ref($_[0]) eq 'Geo::Raster') {

	my $gd = ref($_[0]) eq 'Geo::Raster' ? $_[0]->{GRID} : $_[0];
	my $datatype = $_[1] ? $_[1] : ral_gddatatype($gd);
	$self->{GRID} = ral_gdcreatecopy($gd, $datatype);

    } elsif ($#_ == 0) {

	$self->{NAME} = $_[0];
	my $ext = '';
	$ext = $1 if $_[0] =~ /\.(\w+)$/;

	if ($recognized_extensions{$ext}) {
	    return unless _import($self, filename=>$_[0], datatype=>$REAL_GRID);
	} else {
	    return unless _open($self, filename=>$_[0]);
	}

    } elsif ($#_ == 1 and ($_[0] =~ /\d+/) and ($_[1] =~ /\d+/)) {

	$self->{GRID} = ral_gdnew($INTEGER_GRID, $_[0], $_[1]);

    } elsif ($#_ == 2) {

	$self->{GRID} = ral_gdnew($_[0], $_[1], $_[2]);

    }

    my(%opt) = @_ if !$self->{GRID}; # using named arguments

    if (exists $opt{copy}) { # 

	$opt{datatype} = 0 if !$opt{datatype};
	$opt{copy} = $opt{copy}->{GRID} if ref($opt{copy}) eq 'Geo::Raster';
	$self->{GRID} = ral_gdcreatecopy($opt{copy}, $opt{datatype});

    } elsif (exists $opt{like}) {

	my($datatype, $M, $N, $unitdist, $minX, $maxX, $minY, $maxY) = $opt{like}->attrib();
	$self->{GRID} = ral_gdnew($datatype, $M, $N);
	ral_gdcopybounds($opt{like}->{GRID}, $self->{GRID});

    }

    $opt{datatype} = $INTEGER_GRID if !$opt{datatype};

    if ($opt{filename}) {

	$self->{NAME} = $opt{filename};
	my $ext;
	$ext = $1 if $opt{filename} =~ /\.(\w+)$/;
	if ($opt{import} or $recognized_extensions{$ext}) {
	    return unless _import($self, %opt);
	} else {
	    return unless _open($self, %opt);
	}

    } elsif ($opt{M} and $opt{N}) {

	$self->{GRID} = ral_gdnew($opt{datatype}, $opt{M}, $opt{N});
       
    }
    return unless $self->{GRID};
    _set_attr($self);
    attrib($self);
    bless($self, $class);
}


sub _open {
    my($self,%opt) = @_;
    my $fn = $opt{filename};
    $fn =~ s/\.(\w+)$//;
    my $hdr = "$fn.hdr";
    $hdr = "$fn.HDR" unless -e $hdr;
    if (-e $hdr) {
	my %hdr;
	my $fh = new FileHandle;
	croak "can't open $hdr: $!\n" unless $fh->open($hdr);
	while (<$fh>) {
	    chomp;
	    my($key, $value) = split/\s+/;
	    $hdr{uc($key)} = uc($value);
	}		
	$fh->close;
	croak "$hdr{LAYOUT}: unsupported layout\n" unless $hdr{LAYOUT} eq 'BIL';
	croak "$hdr{NBANDS}: too many bands\n" unless $hdr{NBANDS} == 1;

	my $datatype = $INTEGER_GRID;  # an integer

	my $byteorder = $hdr{BYTEORDER} =~ /^m/i ? 4321 : 1234; # big-endian, motorola ; or little-endian, intel 

# leave for backwards compatibility
	$datatype = $REAL_GRID if $hdr{BYTEORDER} =~ /^f/i; # undocumented tweak of format...

	if ($hdr{NBITS}/8 == 1 or $hdr{NBITS}/8 == 2) {
	    $datatype = $INTEGER_GRID;
	} else {
	    $datatype = $REAL_GRID;
	}

# this is maybe not working?
	$datatype = $opt{datatype} if $opt{datatype};

	$self->{GRID} = ral_gdnew($datatype, $hdr{NROWS}, $hdr{NCOLS});

	if ($hdr{XDIM} and $hdr{YDIM}) {
	    croak "not a uniform grid\n" unless $hdr{XDIM} == $hdr{YDIM};
	    ral_gdsetbounds2($self->{GRID}, $hdr{XDIM}, 
			 $hdr{ULXMAP}-$hdr{XDIM}/2, $hdr{ULYMAP}+$hdr{XDIM}/2) 
		if $hdr{ULXMAP} and $hdr{ULYMAP};
	}

	my $ext;
	if ($opt{ext}) {
	    $ext = $opt{ext};
	} else {
	    for ('.bil','.BIL','.dem','.DEM') {
		$ext = $_ if -e "$fn$_";
	    }
	}
	croak "image file not found, tried $fn.bil, $fn.BIL, $fn.dem, and $fn.DEM\n" unless $ext;

	# this reads into given type if supported $hdr{NBITS}/8
	return unless ral_gdread($self->{GRID}, $fn, $ext, $hdr{NBITS}/8, $byteorder);

    } else {
	my $doc = "$fn.doc";
	$doc = "$fn.DOC" unless -e $doc;
	croak "can't open grid: $opt{filename}\n" unless -e $doc;
	$self->{GRID} = ral_gdopen($fn);
	return unless $self->{GRID};
    }
    return 1;
}


sub _import {
    my($self,%opt) = @_;
    my $fn = $opt{filename};
    my $ext;
    $ext = $1 if $fn =~ /\.(\w+)$/;

    if ($ext eq 'asc' or ($opt{import} =~ /arc\/info/i and $opt{import} =~ /asc/)) {

	my $fh = new FileHandle;
	croak "can't open $fn: $!\n" unless $fh->open($fn);
	my @p; # N M minX minY unitdist
	my $i;
	for $i (0..4) {
	    $_ = <$fh>;
	    chomp;
	    (undef, $p[$i]) = split /\s+/;
	}		
	$fh->close;
	$self->{GRID} = ral_a2gd($opt{datatype}, $p[1], $p[0], $fn, 1);
	if ($self->{GRID}) {
	    # arc/info xllmin is the same as our minX:
	    ral_gdsetbounds($self->{GRID}, $p[4], $p[2], $p[3]);
	}
	
    } elsif ($ext eq 'e' or ($opt{import} =~ /arc\/info/i and $opt{import} =~ /interc/)) {
	
	my $fh = new FileHandle;
	croak "can't open $fn: $!\n" unless $fh->open($fn);
	my($M, $N, $x, $y);
	my($unitdist, $minX, $minY, $maxX, $maxY);
	my $i = 0;
	my $data = 0;
	my $grid = 0;
	while (<$fh>) {
	    $data = 0 if /^EOG/;
	    next if $data;
	    $_ =~ s/\s+$//;
	    if ($grid) {
		$i++;
		my $tmp;
		(undef, $x, $y, $tmp) = split /\s+/;
		if ($i == 1) {
		    $N = $x;
		    $M = $y;
		    print "M=$M, N=$N\n" if $opt{debug};
		    if ($opt{print_header}) {
			print "... BTW: I don't know what $tmp means in the grid header\n";
			print "... skipping the grid header and data\n";
		    }
		} elsif ($i == 2) {
		    if ($x != $y) {
			print "ERROR: not square cells\n";
			return;
		    }
		    $unitdist = $x*1.0;
		    print "unitdist=$unitdist\n" if $opt{debug};
		} elsif ($i == 3) {
		    $minX = $x*1.0;
		    $minY = $y*1.0;
		    print "minX=$minX, minY=$minY\n" if $opt{debug};
		} elsif ($i == 4) {
		    $maxX = $x*1.0;
		    $maxY = $y*1.0;
		    $x = $minX + $N*$unitdist;
		    $y = $minY + $M*$unitdist;
		    if (abs($x - $maxX) > 0.0001) {
			print STDERR "WARNING: input file says maxX is $maxX but will use $x\n";
		    }
		    if (abs($y - $maxY) > 0.0001) {
			print STDERR "WARNING: input file says maxY is $maxY but will use $y\n";
		    }
		} else {
		    $data = 1;
		    $grid = 0;
		}
		next;
	    }
	    print $_,"\n" if !/^~/ and $opt{print_header};
	    $grid = 1 if /^GRD/;
	}
	$fh->close;
	$N += 3; # WHAT THE *!% IS THIS !!!
	$self->{GRID} = ral_a2gd($opt{datatype}, $M, $N, $fn, 2);
	if ($self->{GRID}) {
	    # arc/info xllmin is the same as our minX:
	    ral_gdsetbounds($self->{GRID}, $unitdist, $minX, $minY);
	}
	
    } elsif ($ext eq 'ppm' or $opt{import} =~ /ppm/i) {
	
	$opt{channel} = 'luminance' if !$opt{channel};
	if ($opt{channel} eq 'red') {
	    $opt{channel} = 1;
	} elsif ($opt{channel} eq 'green') {
	    $opt{channel} = 2;
	} elsif ($opt{channel} eq 'blue') {
	    $opt{channel} = 3;
	} else {
	    $opt{channel} = 0;
	}
	$self->{GRID} = ral_ppm2gd($opt{datatype}, $fn, $opt{channel});

    } else {
	
	croak "new Geo::Raster: $opt{import}: import method not supported";
	
    }
    return 1;
}


sub DESTROY {
    my $self = shift;
    return unless $self;
    ral_gddestroy($self->{GRID}) if $self->{GRID};
    delete($self->{GRID});
    ral_ctdestroy($self->{COLOR_TABLE}) if $self->{COLOR_TABLE};
    delete($self->{COLOR_TABLE});
    ral_vddestroy($self->{VD}) if $self->{VD};
    delete($self->{VD});
}


=pod

=head2 Saving a grid:

    $gd->save("data/dem");

If no filename is given the method tries to use the name attribute of
the grid.

The default saving format is a pair of hdr/bil files but see below.

Exporting a grid:

    $gd->save(filename=>$filename, export=>$method, options=>$options);

or simply

    $gd->save("grid.ppm");

Currently only "arc/info ascii" and "ppm" have built-in native support
for exporting. Filename is optional. The default filename is the name
of the grid. The name of the grid is set if the grid is initialized
from a disk file or it can be set using the method set_name. This
method also sets the name attribute.

NOTE: ppm export uses the colortable if one exists, otherwise all
channels (r,g,b) are set to the cell value. Cell values are forced to
the integere range 0..PPM_MAXMAXVAL. PPM_MAXMAXVAL is platform
dependent, in my Intel Linux it is 1023.

If a recognized extension is detected in the filename or in the name
of the grid then that will be used as the export method. Recognized
extensions are:

asc for arc/info ascii
ppm
jpeg and jpg (needs ppmtojpeg program)
png (needs pnmtopng program)

Options for ppmto... programs can be given as the options argument.

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
    if ($opt{export} or $recognized_extensions{$ext}) {
	if ($ext eq 'asc' or ($opt{export} and $opt{export} =~ /arc\/info/i and $opt{export} =~ /asc/)) {
	    return ral_gd2a($self->{GRID}, $name);
	} elsif ($ext eq 'ppm' or ($opt{export} and $opt{export} eq 'ppm')) {
	    
	    if ($opt{R} or $opt{G} or $opt{B} or $opt{H} or $opt{S} or $opt{V}) {
		
		if ($opt{H} or $opt{S} or $opt{V}) {
		    
		    for ('H','S','V') {
			$opt{$_} = $self unless $opt{$_};
		    }
		    
		    return ral_HSVgd2ppm($opt{H}->{GRID}, $opt{S}->{GRID}, $opt{V}->{GRID}, $name);

		} else {

		    for ('R','G','B') {
			$opt{$_} = $self unless $opt{$_};
		    }

		    return ral_RGBgd2ppm($opt{R}->{GRID}, $opt{G}->{GRID}, $opt{B}->{GRID}, $name);

		}
		
	    } else {
		return ral_gd2ppm($self->{GRID}, $name, $self->{COLOR_TABLE});
	    }

	} elsif ($opt{export}) {
	    croak "save Geo::Raster: $opt{export}: export method not supported";
	} else {
	    my $ret = ral_gd2ppm($self->{GRID}, "$name.tmp.ppm", $self->{COLOR_TABLE});
	    my $options = $opt{options};
	    $options = '' unless $options;
	    $ret = system "$recognized_extensions{$ext} $options $name.tmp.ppm >$name" if $ret;
	    system "rm -f $name.tmp.ppm";
	    return $ret;
	}
    }
    if ($name) {
	$name =~ s/\.(\w+)$//;
	my $fh = new FileHandle;
        croak "can't write to $name.hdr: $!\n" unless $fh->open(">$name.hdr");

	my($datatype, $M, $N, $unitdist, $minX, $maxX, $minY, $maxY, $nodata) = $self->attrib();
	my $nbits = 16;
	$nbits = 32 if $datatype == $REAL_GRID;

	my $byteorder = $Config{byteorder} == 4321 ? 'M' : 'I';

# forget this: and rely on $nbits
#	$byteorder = 'F' if $datatype == $REAL_GRID;

	print $fh "BYTEORDER      $byteorder\n";
	print $fh "LAYOUT       BIL\n";
	print $fh "NROWS         $M\n";
	print $fh "NCOLS         $N\n";
	print $fh "NBANDS        1\n";
	print $fh "NBITS         $nbits\n";
	my $rowbytes = $nbits/8*$N;
	print $fh "BANDROWBYTES         $rowbytes\n";
	print $fh "TOTALROWBYTES        $rowbytes\n";
	print $fh "BANDGAPBYTES         0\n";
	print $fh "NODATA        $nodata\n";
	$minX += $unitdist / 2;
	$maxY -= $unitdist / 2;
	print $fh "ULXMAP        $minX\n";
	print $fh "ULYMAP        $maxY\n";
	print $fh "XDIM          $unitdist\n";
	print $fh "YDIM          $unitdist\n";
	$fh->close;
	return ral_gdwrite($self->{GRID}, $name, '.bil')
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
    my $points = $self->print(quiet=>1,nonzeros=>1);
    for (my $i = 0; $i <= $#$points; $i++) {
	print $to "$points->[$i]->[0], $points->[$i]->[1], $points->[$i]->[2]\n";
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
    ral_gdsetall($self->{GRID},0);
    while (<$from>) {
	my($i, $j, $x) = split /,/;
	ral_gdset($self->{GRID}, $i, $j, $x);
    }
    $from->close if $close;
}


=pod

=head2 The name of the grid

The name of the grid is (or may be) the same as its filename
(including the path) without extension. The name is set when a grid is
constructed from a file (or files). The extension is used for import
and export if it is one the recognized extensions.

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
    if ($o{unitdist} and defined($o{minX}) and defined($o{minY})) {

	ral_gdsetbounds($self->{GRID}, $o{unitdist}, $o{minX}, $o{minY});

    } elsif ($o{unitdist} and defined($o{minX}) and defined($o{maxY})) {

	ral_gdsetbounds2($self->{GRID}, $o{unitdist}, $o{minX}, $o{maxY});

    } elsif ($o{unitdist} and defined($o{maxX}) and defined($o{minY})) {

	ral_gdsetbounds3($self->{GRID}, $o{unitdist}, $o{maxX}, $o{minY});

    } elsif (defined($o{minX}) and defined($o{maxX}) and defined($o{minY})) {

	ral_gdsetbounds4($self->{GRID}, $o{minX}, $o{maxX}, $o{minY});

    } elsif (defined($o{minX}) and defined($o{maxX}) and defined($o{maxY})) {

	ral_gdsetbounds5($self->{GRID}, $o{minX}, $o{maxX}, $o{maxY});

    } elsif (defined($o{minX}) and defined($o{minY}) and defined($o{maxY})) {

	ral_gdsetbounds6($self->{GRID}, $o{minX}, $o{minY}, $o{maxY});

    } elsif (defined($o{maxX}) and defined($o{minY}) and defined($o{maxY})) {

	ral_gdsetbounds7($self->{GRID}, $o{maxX}, $o{minY}, $o{maxY});

    } else {

	croak "not enough parameters to set bounds";

    }
    $self->attrib;
}


sub copyboundsto {
    my($self, $to) = @_;
    return ral_gdcopybounds($self->{GRID}, $to->{GRID});
}

=pod

=head2 Setting the world coordinate system:

    $gd->setbounds(unitdist=>10,
		   minX=>0,
		   maxX=>0,
		   minY=>0, 
		   maxY=>0);

at least three parameters must be set: unitdist, minX and minY; minX,
maxX and minY; or minX, minY and maxY. minX (or easting) is the left
edge of the leftmost cell, i.e. _not_ the center of the leftmost cell.

The world coordinate system can be copied to another grid:

    $g1->copyboundsto($g2);

Conversions between coordinate systems (Cell<->World):

    ($x, $y) = $gd->g2w($i, $j);
    ($i, $j) = $gd->w2g($x, $y);

=cut

sub g2w {
    my($self, $i, $j) = @_;
    $j = ral_gdj2x($self->{GRID}, $j);
    $i = ral_gdi2y($self->{GRID}, $i);
    return($j, $i);
}


sub w2g {
    my($self, $x, $y) = @_;
    $y = ral_gdy2i($self->{GRID}, $y);
    $x = ral_gdx2j($self->{GRID}, $x);
    return($y, $x);
}


=pod

=head2 Setting and removing a mask

    $gd->setmask();

    $gd->removemask();

The mask is used in ALL grid operations and affects ALL grids. The
removemask method does not need to be called with the same grid as
setmask.

=cut


sub setmask {
    my $self = shift;
    ral_gdsetmask($self->{GRID});
}


sub getmask {
    my $mask = new Geo::Raster(ral_gdgetmask());
    return $mask;
}


sub removemask {  
    ral_gdremovemask();
}


=pod

=head2 Setting a cell value

    $gd->set($i, $j, $x);

If $x is undefined or string "nodata", the cell value is set to nodata.

=head2 Setting all cells to a value

    $gd->set($x);

If $x is undefined or string "nodata", the cell value is set to nodata.

=head2 Copying values from another grid

    $gd->set($g);

$g needs to be a similar Geo::Raster.

The return value is 0 in the case of an error.

=cut

sub set {
    my($self, $i, $j, $x) = @_;
    if (defined($j)) {
	if (!defined($x) or $x eq 'nodata') {
	    return ral_gdsetnodata($self->{GRID}, $i, $j);
	}
	if ($x =~ /^\d+$/) {
	    return ral_gdset2($self->{GRID}, $i, $j, $x);
	}
	return ral_gdset($self->{GRID}, $i, $j, $x);
    } else {
	if (!defined($i) or $i eq 'nodata') {
	    return ral_gdsetallnodata($self->{GRID});
	} 
	if (!ref($i)) {
	    if ($i =~ /^\d+$/) { # integer
		return ral_gdsetall_int($self->{GRID}, $i);
	    } else {
		return ral_gdsetall($self->{GRID}, $i);
	    }
	} 
	if (ref($i) eq 'Geo::Raster') {
	    return ral_gdcopy($self->{GRID}, $i->{GRID});
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
    return ral_gdsetallnodata($self->{GRID});
}

=pod

=head2 Retrieving a cell's value

    $x = $gd->get($i, $j);

the returned value is undef if it is a nodata cell.

=cut


sub get {
    my($self, $i, $j) = @_;
    if ($self->{DATATYPE} == $INTEGER_GRID) {
	my $ret = ral_gdget2($self->{GRID}, $i, $j);
	return if $ret == $self->{NODATA};
	return $ret;
    }
    my $ret = ral_gdget($self->{GRID}, $i, $j);
    return if $ret == $self->{NODATA};
    return $ret;
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
    $self->{DATATYPE} = ral_gddatatype($self->{GRID}); # may have been changed
    return $self if defined wantarray and $g;
}


=pod

=head2 Calculating min and max values

    ($minval, $maxval) = $gd->getminmax(); 

or

    $minval = $gd->min();
    $maxval = $gd->max();

If you just want to know where the min or max value resides:

    @min = $gd->min();
    @max = $gd->max();

@min and @max will be the cell (i,j) of the min or max value.

Methods min and max have quite another meaning if a parameter is
supplied, see below.

minvalue and maxvalue are also stored into the grid hash as
attributes.

=cut

sub getminmax {
    my $self = shift;
    ral_gdsetminmax($self->{GRID});
    my $minval = ral_gdgetminval($self->{GRID});
    my $maxval = ral_gdgetmaxval($self->{GRID});
    return($minval, $maxval);
}


=pod

=head2 Retrieving attributes of a grid

    ($datatype, $M, $N, $unitdist, $minX, $maxX, $minY, $maxY, $nodata) = 
      $gd->attrib();

works also in a perlish way:

    @size = ($gd->attrib())[1..2];

for this there is also a separate method:

    ($M, $N) = $gd->size();

=cut

sub attrib {
    my $self = shift;
    my $datatype = $self->{DATATYPE};
    my $M = $self->{M} = ral_gdgetM($self->{GRID});
    my $N = $self->{N} = ral_gdgetN($self->{GRID});
    my $unitdist = $self->{UNITDIST} = ral_gdunitdist($self->{GRID});
    my $minX = $self->{MINX} = ral_gdminX($self->{GRID});
    my $maxX = $self->{MAXX} = ral_gdmaxX($self->{GRID});
    my $minY = $self->{MINY} = ral_gdminY($self->{GRID});
    my $maxY = $self->{MAXY} = ral_gdmaxY($self->{GRID});
    my $nodata;
    if ($self->{DATATYPE} == $INTEGER_GRID) {
	$nodata = $self->{NODATA} = ral_gdget_nodata_value_int($self->{GRID});
    } elsif ($self->{DATATYPE} == $REAL_GRID) {
	$nodata = $self->{NODATA} = ral_gdget_nodata_value_real($self->{GRID});
    }
    return($datatype, $M, $N, $unitdist, $minX, $maxX, $minY, $maxY, $nodata);
}


sub size {
    my($self, $i, $j) = @_;
    if (defined($i) and defined($j)) {
	return _gdzonesize($self->{GRID}, $i, $j);
    } else {
	return ($self->{M}, $self->{N});
    }
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


sub clone { # thanks to anno4000@lublin.zrz.tu-berlin.de (Anno Siegel)
    my $self = shift;
    bless $self, ref $self;
}


sub neg {
    my $self = shift;
    my $copy = new Geo::Raster($self);
    ral_gdmultsv($copy->{GRID}, -1);
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
	ral_gdaddsv($copy->{GRID}, $second);
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
	    ral_gdmultsv($copy->{GRID},-1);
	} else {
	    $second *= -1;
	}
	ral_gdaddsv($copy->{GRID}, $second);
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
	ral_gdmultsv($copy->{GRID}, $second);
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
	    ral_svdivgd($second, $copy->{GRID});
	} else {
	    ral_gddivsv($copy->{GRID}, $second);
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
	    ral_svpowergd($second, $copy->{GRID});
	} else {
	    ral_gdpowersv($copy->{GRID}, $second);
	}
    }
    return $copy;
}


sub add {
    my($self, $second) = @_;
    my $datatype = $self->typeconversion($second);
    return unless defined($datatype);
    $self->_new_grid(ral_gdcreatecopy($self->{GRID}, $datatype)) if $datatype != $self->{DATATYPE};
    if (ref($second)) {
	ral_gdaddgd($self->{GRID}, $second->{GRID});
    } else {
	ral_gdaddsv($self->{GRID}, $second);
    }
    return $self;
}


sub subtract {
    my($self, $second) = @_;
    my $datatype = $self->typeconversion($second);
    return unless defined($datatype);
    $self->_new_grid(ral_gdcreatecopy($self->{GRID}, $datatype)) if $datatype != $self->{DATATYPE};
    if (ref($second)) {
	ral_gdsubgd($self->{GRID}, $second->{GRID});
    } else {
	ral_gdaddsv($self->{GRID}, -$second);
    }
    return $self;
}


sub multiply_by {
    my($self, $second) = @_;
    my $datatype = $self->typeconversion($second);
    return unless defined($datatype);
    $self->_new_grid(ral_gdcreatecopy($self->{GRID}, $datatype)) if $datatype != $self->{DATATYPE};
    if (ref($second)) {
	ral_gdmultgd($self->{GRID}, $second->{GRID});
    } else {
	ral_gdmultsv($self->{GRID}, $second);
    }
    return $self;
}


sub divide_by {
    my($self, $second) = @_;
    $self->_new_grid(ral_gdcreatecopy($self->{GRID}, $REAL_GRID));
    if (ref($second)) {
	ral_gddivgd($self->{GRID}, $second->{GRID});
    } else {
	ral_gddivsv($self->{GRID}, $second);
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
    $self->_new_grid(ral_gdcreatecopy($self->{GRID}, $datatype)) if $datatype != $self->{DATATYPE};
    if (ref($second)) {
	ral_gdpowergd($self->{GRID}, $second->{GRID});
    } else {
	ral_gdpowersv($self->{GRID}, $second);
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


sub atan2 {
    my($self, $second, $reversed) = @_;
    if (ref($self) and ref($second)) {
	if (defined wantarray) {
	    $self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
	} elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	    $self->_new_grid(ral_gdcreatecopy($self->{GRID}, $REAL_GRID));
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
	$self->_new_grid(ral_gdcreatecopy($self->{GRID}, $REAL_GRID));
    }
    ral_gdcos($self->{GRID});
    return $self;
}


sub exp {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_gdcreatecopy($self->{GRID}, $REAL_GRID));
    }
    ral_gdexp($self->{GRID});
    return $self;
}


sub log {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_gdcreatecopy($self->{GRID}, $REAL_GRID));
    }
    ral_gdlog($self->{GRID});
    return $self;
}


sub sin {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_gdcreatecopy($self->{GRID}, $REAL_GRID));
    }
    ral_gdsin($self->{GRID});
    return $self;
}


sub sqrt {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_gdcreatecopy($self->{GRID}, $REAL_GRID));
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
	    $self = new Geo::Raster $grid;
	    return $self;
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
	$self->_new_grid(ral_gdcreatecopy($self->{GRID}, $REAL_GRID));
    }
    ral_gdacos($self->{GRID});
    return $self;
}


sub atan {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_gdcreatecopy($self->{GRID}, $REAL_GRID));
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
	return main::ceil($self);
    }
}


sub cosh {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_gdcreatecopy($self->{GRID}, $REAL_GRID));
    }
    ral_gdcosh($self->{GRID});
    return $self;
}


sub floor {
    my $self = shift;
    $self = new Geo::Raster($self) if defined wantarray;
    ral_gdfloor($self->{GRID});
    return $self;
}


sub log10 {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_gdcreatecopy($self->{GRID}, $REAL_GRID));
    }
    ral_gdlog10($self->{GRID});
    return $self;
}


sub sinh {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_gdcreatecopy($self->{GRID}, $REAL_GRID));
    }
    ral_gdsinh($self->{GRID});
    return $self;
}

sub tan {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_gdcreatecopy($self->{GRID}, $REAL_GRID));
    }
    ral_gdtan($self->{GRID});
    return $self;
}


sub tanh {
    my $self = shift;
    if (defined wantarray) {
	$self = new Geo::Raster datatype=>$REAL_GRID, copy=>$self;
    } elsif ($self->{DATATYPE} == $INTEGER_GRID) {
	$self->_new_grid(ral_gdcreatecopy($self->{GRID}, $REAL_GRID));
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
    my $g;
    if (ref($second)) {
	$g = ral_gdltgd($self->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    $g = ral_gdgtsv($self->{GRID}, $second);
	} else {
	    $g = ral_gdltsv($self->{GRID}, $second);
	}
    }
    $self->{DATATYPE} = ral_gddatatype($self->{GRID}); # may have been changed
    return $self if defined wantarray and $g;
}


sub gt {
    my($self, $second, $reversed) = @_;
    $self = new Geo::Raster $self if defined wantarray;
    my $g;
    if (ref($second)) {
	$g = ral_gdgtgd($self->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    $g = ral_gdltsv($self->{GRID}, $second);
	} else {
	    $g = ral_gdgtsv($self->{GRID}, $second);
	}
    }
    $self->{DATATYPE} = ral_gddatatype($self->{GRID}); # may have been changed
    return $self if defined wantarray and $g;
}


sub le {
    my($self, $second, $reversed) = @_;
    $self = new Geo::Raster $self if defined wantarray;
    my $g;
    if (ref($second)) {
	$g = ral_gdlegd($self->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    $g = ral_gdgesv($self->{GRID}, $second);
	} else {
	    $g = ral_gdlesv($self->{GRID}, $second);
	}
    }
    $self->{DATATYPE} = ral_gddatatype($self->{GRID}); # may have been changed
    return $self if defined wantarray and $g;
}


sub ge {
    my($self, $second, $reversed) = @_;
    $self = new Geo::Raster $self if defined wantarray;
    my $g;
    if (ref($second)) {
	$g = ral_gdgegd($self->{GRID}, $second->{GRID});
    } else {
	if ($reversed) {
	    $g = ral_gdlesv($self->{GRID}, $second);
	} else {
	    $g = ral_gdgesv($self->{GRID}, $second);
	}
    }
    $self->{DATATYPE} = ral_gddatatype($self->{GRID}); # may have been changed
    return $self if defined wantarray and $g;
}


sub eq {
    my $self = shift;
    my $second = shift;
    $self = new Geo::Raster $self if defined wantarray;
    my $g;
    if (ref($second)) {
	$g = ral_gdeqgd($self->{GRID}, $second->{GRID});
    } else {
	$g = ral_gdeqsv($self->{GRID}, $second);
    }
    $self->{DATATYPE} = ral_gddatatype($self->{GRID}); # may have been changed
    return $self if defined wantarray and $g;
}


sub ne {
    my $self = shift;
    my $second = shift;
    $self = new Geo::Raster $self if defined wantarray;
    my $g;
    if (ref($second)) {
	$g = ral_gdnegd($self->{GRID}, $second->{GRID});
    } else {
	$g = ral_gdnesv($self->{GRID}, $second);
    }
    $self->{DATATYPE} = ral_gddatatype($self->{GRID}); # may have been changed
    return $self if defined wantarray and $g;
}


sub cmp {
    my($self, $second, $reversed) = @_;
    $self = new Geo::Raster $self if defined wantarray;
    my $g;
    if (ref($second)) {
	$g = ral_gdcmpgd($self->{GRID}, $second->{GRID});
    } else {
	$g = ral_gdcmpsv($self->{GRID}, $second);
	if ($reversed) {
	    ral_gdmultsv($self->{GRID}, -1);
	}
    }
    $self->{DATATYPE} = ral_gddatatype($self->{GRID}); # may have been changed
    return $self if defined wantarray and $g;
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
    my $g = ral_gdnot($self->{GRID});
    return $self if defined wantarray and $g;
}


sub and {
    my $self = shift;
    my $second = shift;
    $self = new Geo::Raster $self if defined wantarray;
    my $g = ral_gdandgd($self->{GRID}, $second->{GRID});
    return $self if defined wantarray and $g;
}


sub or {
    my $self = shift;
    my $second = shift;
    $self = new Geo::Raster $self if defined wantarray;
    my $g = ral_gdorgd($self->{GRID}, $second->{GRID});
    return $self if defined wantarray and $g;
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
In array context the methods return the location (i,j) of the minimum 
value.

=cut

sub min {
    my $self = shift;
    if (wantarray) {
	my $c = _gdgetmin($self->{GRID});
	return @$c;
    }
    my $second = shift;
    $self = new Geo::Raster $self if defined wantarray;
    my $g;
    if (ref($second)) {
	$g = ral_gdmingd($self->{GRID}, $second->{GRID});
    } else {
	if (defined($second)) {
	    $g = ral_gdminsv($self->{GRID}, $second);
	} else {
	    ral_gdsetminmax($self->{GRID});
	    return gdgetminval($self->{GRID});
	}
    }
    return $self if defined wantarray and $g;
}


sub max {
    my $self = shift;
    if (wantarray) {
	my $c = _gdgetmax($self->{GRID});
	return @$c;
    }
    my $second = shift;   
    $self = new Geo::Raster $self if defined wantarray;
    my $g;
    if (ref($second)) {
	$g = ral_gdmaxgd($self->{GRID}, $second->{GRID});
    } else {
	if (defined($second)) {
	    $g = ral_gdmaxsv($self->{GRID}, $second);
	} else {
	    ral_gdsetminmax($self->{GRID});
	    return ral_gdgetmaxval($self->{GRID});
	}
    }
    return $self if defined wantarray and $g;
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

    $a->if_then($b, $c);

$a and $b are grids and $c can be a grid or a scalar, the
effect of this subroutine is:

for all i,j if (b[i,j]) then a[i,j]=c[i,j]

if a return value is requested

    $d = $a->if_then($b, $c);

then d is a but if b then c

If $c is a reference to a zonal mapping hash, i.e., it has value pairs
k=>v, where k is an integer, which represents a zone in b, then a is
set to v on that zone. A zone mapping hash can, for example, be
obtained using the zonal functions (see below).

=cut

sub if_then {
    my $a = shift;
    my $b = shift;    
    my $c = shift;
    my $d = shift;
    my $ret;
    $a = new Geo::Raster ($a) if defined wantarray;
    if (ref($c)) {
	if (ref($c) eq 'Geo::Raster') {
	    $ret = ral_gdif_thengd($b->{GRID}, $a->{GRID}, $c->{GRID});
	} elsif (ref($c) eq 'HASH') {
	    my(@k,@v);
	    foreach (keys %{$c}) {
		push @k, int($_);
		push @v, $c->{$_};
	    }
	    $ret = gdzonal_if_then($b->{GRID}, $a->{GRID}, \@k, \@v, $#k+1);
	} else {
	    croak("if_then: usage: if_then->(Geo::Raster, [Geo::Raster|HASH])");
	}
    } else {
	unless (defined $d) {
	    $ret = ral_gdif_thensv($b->{GRID}, $a->{GRID}, $c);
	} else {
	    $ret = ral_gdif_thenelsesv($b->{GRID}, $a->{GRID}, $c, $d);
	}
    }
    return $a if defined wantarray;
    return $ret;
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

=cut

sub clip {
    my($self, $i1, $j1, $i2, $j2) = @_;
    if (defined wantarray) {
	my $g = new Geo::Raster(ral_gdclip($self->{GRID}, $i1, $j1, $i2, $j2));
	return $g;
    } else {
	$self->_new_grid(ral_gdclip($self->{GRID}, $i1, $j1, $i2, $j2));
    }
}

=pod

=head2 Joining two grids:

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
which the i2,j2 cell maps to. NOTE: In this case the pixel coordinates
are assumed to denote the upper left corner of the pixel. This makes
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
	return new Geo::Raster(gdtransform($self->{GRID}, $tr, $M, $N, $pick, $value));
    } else {
	$self->_new_grid(gdtransform($self->{GRID}, $tr, $M, $N, $pick, $value));
    }
}

=pod

=head2 Printing a grid:

    $gd->print(%options);

if no options are given simply prints the grid, if option list=>1
is set prints the nonzero cells of the grid in format:

i,j,val

and returns the points as a reference to an array of references to
point arrays ($i, $j, $val).  Printing can be suppressed using option
quiet=>1, i.e, $g->print(quiet=>1) (quiet implicitly assumes list
mode) only returns a reference to an array of points. Other options
are "wc" which changes image coordinates i,j to world coordinates x,y.

=cut

sub print {
    my($self,%opt) = @_;
    if (!%opt) {
	return gdprint($self->{GRID});
    }
    my $quiet = 0;
    $quiet = 1 if $opt{quiet};
    my $wc = 0;
    $wc = 1 if $opt{wc};
    my $a = _gdprint1($self->{GRID}, $quiet, $wc);
    my $b = [];
    my $i = 0;
    while (3*$i < $#$a) {
	$b->[$i] = [$a->[3*$i], $a->[3*$i+1], $a->[3*$i+2]];
	$i++;
    }
    return $b;
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
	ral_gdcopybounds($self->{GRID}, $g->{GRID});
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
	$a = _gdhistogram($self->{GRID}, $bins, $#$bins+1);
	return @$a;
    } else {
	my $bins = int($bins);
	ral_gdsetminmax($self->{GRID});
	my $minval = ral_gdgetminval($self->{GRID});
	my $maxval = ral_gdgetmaxval($self->{GRID});
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
	return _gdcontents($self->{GRID});
    } else {
	my $c = $self->print(quiet=>1);
	my %d;
	for (0..$#$c) {$d{$c->[$_]->[2]}++}
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
    return _gdzones($self->{GRID}, $zones->{GRID});
}

sub most_common_values_in_zones {
    my($self, $zones) = @_;
    my $z = $self->zones($zones);
    # replace the arrays with most common values
    foreach my $zk (keys %$z) {
	my %m;
	foreach my $x (@{$z->{$zk}}) {
	    $m{$x}++;
	}
	my($c, $v);
	foreach my $x (keys %m) {
	    if (!defined($v) or $m{$x} > $c) {
		$v = $x;
		$c = $m{$x};
	    }
	}
	$z->{$zk} = $v;
    }
    return $z;
}

sub zonalfct {
    my($self, $zones, $fct) = @_;
    my $z = _gdzones($self->{GRID}, $zones->{GRID});
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
    return _gdzonalcount($self->{GRID}, $zones->{GRID});
}

sub zonalsum {
    my($self, $zones) = @_;
    return _gdzonalsum($self->{GRID}, $zones->{GRID});
}

sub zonalmin {
    my($self, $zones) = @_;
    return _gdzonalmin($self->{GRID}, $zones->{GRID});
}

sub zonalmax {
    my($self, $zones) = @_;
    return _gdzonalmax($self->{GRID}, $zones->{GRID});
}

sub zonalmean {
    my($self, $zones) = @_;
    return _gdzonalmean($self->{GRID}, $zones->{GRID});
}

sub zonalvariance {
    my($self, $zones) = @_;
    return _gdzonalvariance($self->{GRID}, $zones->{GRID});
}

sub growzones {
    my($zones, $grow, $connectivity) = @_;
    $connectivity = 8 unless defined($connectivity);
    $zones = new Geo::Raster $zones if defined wantarray;
    my $ret = gdgrowzones($zones->{GRID}, $grow->{GRID}, $connectivity);
    return $zones if defined wantarray and $ret;
    return $ret;
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
function string is "2*$x+3*$y", which creates a plane.

=cut

sub function {
    my($self, $fct) = @_;
    my(undef, $M, $N, $unitdist, $minX, $maxX, $minY, $maxY) = $self->attrib();
    my $y = $minY+$unitdist/2;
    for my $i (0..$M-1) {
	my $x = $minX+$unitdist/2;
	$y += $unitdist;
	for my $j (0..$N-1) {
	    $x += $unitdist;
	    my $z = eval $fct;
	    $self->set($i, $j, $z);
	}
    }
}


=pod

=head1 GRAPHICS

=head2 The color system

Plotting is grayscale unless a colortable is created for the grid;

    $gd->colortable(number_of_colors=>number_of_colors,
		    extra_colors=>extra_colors,
		    contrast=>contra, 
		    brightness=>brightness,
		    offset=>offset);

This creates a new colortable (and disposes of the old one). All
parameters are optional. The default number of colors is maxvalue -
minvalue + 1 for integer grids, for real grids there is no default
value (an error is croaked). The default number of extra colors is
0. Contrast is the contrast of the color ramp (default is
1.0). Negative values reverse the direction of the ramp.  Brightness
is the brightness of the color ramp. Default is 0.5, but can sensibly
hold any value between 0.0 and 1.0. Values at or beyond the latter two
extremes, saturate the color ramp with the colors of the respective
end of the color table. Offset is for those cases when the minimum
value in the grid is not zero, the default is the minimum value in the
grid.  (mostly from pgplot.doc)

    $gd->color($i, $l, $r, $g, $b);
or
    $gd->color($i, $r, $g, $b);
or
    $gd->color($i, colorname);

If colorname is given, the method tries to look up its RGB values
from the file /usr/X11/lib/X11/rgb.txt.

This sets one color at index i (first index is 0 or offset if you have
set it) in the colortable. l is a normalized ramp-intensity level
corresponding to the RGB primary color intensities r, g, and b. l can
be set by the method to value $i / ($self->{COLOR_TABLE_SIZE} -
1). Colors on the ramp are linearly interpolated from neighbouring
levels. Levels must be sorted in increasing order.  0.0 places a color
at the beginning of the ramp.  1.0 places a color at the end of the
ramp.  Colors outside these limits are legal, but will not be visible
if contra=1.0 and bright=0.5. r, g, and b values should be integers
between 0 and 255. (mostly from pgplot.doc)

More colors can be added to the colortable using method

    $gd->addcolors($newcolors);

Typically colors are retrieved into a grid from the database using the
method rgb. See below.

A color can be returned from the colormap using the color method 
with only the index:

    ($r, $g, $b) = $gd->color($i);

The whole colortable is returned by the method get_colortable;

    $colortable = $gd->get_colortable();

$colortable is a hash with colortable indexes as keys and references
to ($r, $g, $b) arrays as values.

=cut

sub colortable {
    my($self, %opt) = @_;
    ctdestroy($self->{COLOR_TABLE}) if $self->{COLOR_TABLE};
    delete $self->{COLOR_TABLE};
    delete($self->{RGBI});
    delete($self->{IRGB});
    my($min, $max) = $self->getminmax;    
    $opt{offset} = $min unless defined $opt{offset};
    unless (defined $opt{number_of_colors}) {
	croak "number of colors not set" unless 
	    $self->{DATATYPE} == $INTEGER_GRID;
	$opt{number_of_colors} = $max - $min + 1 ;
    }
    $opt{extra_colors} = 0 unless defined $opt{extra_colors};
    $opt{contrast} = 1.0 unless defined $opt{contrast};
    $opt{brightness} = 0.5 unless defined $opt{brightness};
    $self->{COLOR_TABLE_OFFSET} = $opt{offset};
    $self->{COLOR_TABLE_SIZE} = $opt{number_of_colors} + $opt{extra_colors};
    $self->{COLOR_TABLE} = ctcreate($self->{COLOR_TABLE_SIZE}, 
				    $opt{contrast}, 
				    $opt{brightness});
    return $self->{COLOR_TABLE};
}


sub get_colortable {
    my $self = shift;
    croak "no colortable" unless $self->{COLOR_TABLE};
    my $offset = $self->{COLOR_TABLE_OFFSET};
    $self->{COLOR_TABLE_OFFSET} = 0;
    my %ct;
    for my $i (0..$self->{COLOR_TABLE_SIZE}-1) {
	$ct{$i} = [$self->color($i)];
    }
    $self->{COLOR_TABLE_OFFSET} = $offset;
    return \%ct;
}


sub color {
    my $self = shift;
    croak "no colortable" unless $self->{COLOR_TABLE};
    my $i = shift;
    $i -= $self->{COLOR_TABLE_OFFSET} if $self->{COLOR_TABLE_OFFSET};
    if ($#_ == -1) {
	my $r = ral_ctgetr($self->{COLOR_TABLE}, $i);
	my $g = ral_ctgetg($self->{COLOR_TABLE}, $i);
	my $b = ral_ctgetb($self->{COLOR_TABLE}, $i);
	return (round($r*255), round($g*255), round($b*255));
    }
    if ($#_ == 0) {	
	my $rgb = shift;
	my @rgb = `grep $rgb /usr/X11/lib/X11/rgb.txt`;
	croak "color $rgb not found in X11 rgb.txt" if $#rgb < 0;
	my($r, $g, $b) = split /\s+/, $rgb[0];
	push @_, ($r, $g, $b);
    }
    if ($#_ == 3) {
	my($l, $r, $g, $b) = @_;
	$self->{RGBI}->{"$r, $g, $b"} = $i;
	$self->{IRGB}->{$i} = "$r, $g, $b";
	return ral_ctset($self->{COLOR_TABLE}, $i, $l, $r/255, $g/255, $b/255);
    } elsif ($#_ == 2) {
	my($r, $g, $b) = @_;
	$self->{RGBI}->{"$r, $g, $b"} = $i;
	$self->{IRGB}->{$i} = "$r, $g, $b";
	my $l = 0.5;
	$l = $i / ($self->{COLOR_TABLE_SIZE} - 1) if $self->{COLOR_TABLE_SIZE} > 1;
	return ral_ctset($self->{COLOR_TABLE}, $i, $l, $r/255, $g/255, $b/255);
    }
}


sub addcolors {
    my($self, $newcolors) = @_;
    return unless $self->{COLOR_TABLE};
    my $contrast = ral_ctget_contrast($self->{COLOR_TABLE});
    my $brightness = ral_ctget_brightness($self->{COLOR_TABLE});
    my $old_size = $self->{COLOR_TABLE_SIZE};
    my %old_table;
    %old_table = %{$self->{IRGB}} if $self->{IRGB};
    $self->colortable(number_of_colors=>($old_size + $newcolors),
		      offset=>$self->{COLOR_TABLE_OFFSET},
		      contrast=>$contrast,
		      brightness=>$brightness);
    if (%old_table) {
	foreach (sort {$a<=>$b} keys %old_table) {
	    my($r, $g, $b) = split /,/, $old_table{$_};
	    $self->color($_, $r, $g, $b);
	}
    }
    return $old_size+$self->{COLOR_TABLE_OFFSET};
}

=pod

=head2 Primitives:

Drawing a line to a grid:

    $gd->line($i1, $j1, $i2, $j2, $pen);

a filled rectangle:

    $gd->rect($i1, $j1, $i2, $j2, $pen);

a circle:

    $gd->circle($i, $j, $r, $pen);

=cut

sub line {
    my($self, $i1, $j1, $i2, $j2, $pen) = @_;
    return gdline($self->{GRID}, $i1, $j1, $i2, $j2, $pen);
}


sub rect {
    my($self, $i1, $j1, $i2, $j2, $pen) = @_;
    return gdfilledrect($self->{GRID}, $i1, $j1, $i2, $j2, $pen);
}

sub circle {
    my($self, $i, $j, $r, $pen) = @_;
    ral_gdfilledcircle($self->{GRID}, $i, $j, round($r), round($r*$r), $pen);
}

sub floodfill {
    my($self, $i, $j, $pen, $connectivity) = @_;
    $connectivity = 8 unless $connectivity;
    _gdfloodfill($self->{GRID}, $i, $j, round($pen), $pen, $connectivity);
}

=pod

=head2 Plotting, viewing, and editing a grid

The plain plot:

    $gd->plot(%options); 

device and donotsetminmax and visual can be set using options. device
is a pgplot device, the default is "/xserve". donotsetminmax skips
setminmax before plotting. Visual options are labels_off and scale.
labels_off skips showing of (vector data) labels. scale skips scaling
of x and y-axis. width sets the initial width (in inches) of
the plotting window, it is 7 unless set. Plot returns right after it
has done its job, i.e. it does not remain in interactive state as
view:

    $gd->view(%options);

The interactive state in view includes export, redraw, scroll, zoom,
restore, and area calculation. Using the method drawon adds the capability 
of drawing lines and rectangles on the viewed grid. The mehod returns
the drawn layer as a grid:
    
    $drawing = $gd->drawon(%options);

In the case of interactive methods (view and drawon) the device option
can be used to specify the export device, "/ps" is the default.

In all plotting integer grids are first converted to real grids
internally.

=head2 Using multiple windows

Opening two pgplot windows:

    $w1 = &Geo::Raster::gdwindow_open;
    $w2 = &Geo::Raster::gdwindow_open;

Plotting two grids to these two windows:

    $g1->plot(window=>$w1);
    $g2->plot(window=>$w1);

The windows are always automatically closed after plotting. Thus you
need to reopen them using &Geo::Raster::gdwindow_open again if you want to
use multiple windows.

An opened window can be closed explicitly by subroutine

   &Geo::Raster::gdwindow_close($window);

Either plot a grid or close explicitly an opened window.

=cut

sub _plot {
    my($self, $o) = @_;
    ral_gdsetminmax($self->{GRID}) unless $o->{donotsetminmax};
    my $vd = ral_vdnull();
    $vd = $self->{VD} if $self->{VD};
    $o->{_draw} = -1 unless defined($o->{_draw});
    $o->{view_options} = 7 unless $o->{view_options};
    $o->{view_options} += 8 if $o->{scale};
    $o->{view_options} &= (1+2+8+16+32+64+128) if $o->{labels_off};
    $o->{window} = 0 unless $o->{window};
    $o->{width} = 7 unless $o->{width};
    my $ret = ral_gdplot($self->{GRID}, $vd, $o->{device}, $o->{window},
			$self->{COLOR_TABLE}, $o->{_draw}, $o->{view_options},
			$o->{width});
    return $ret;
}

sub plot {
    my($self, %o) = @_;
    $o{_draw} = -1;
    $o{device} = '/xserve' unless $o{device};
    $self->_plot(\%o);
}

sub view {
    my($self, %o) = @_;
    $o{_draw} = 0;
    $o{device} = '/ps' unless $o{device};
    $self->_plot(\%o);
}

sub drawon {
    my($self, %o) = @_;
    $o{_draw} = 1;
    $o{device} = '/ps' unless $o{device};
    return new Geo::Raster($self->_plot(\%o));
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
    my $ret = ral_gdmap($self->{GRID}, \@source, \@destiny, $n);
    return $self if defined wantarray and $ret;
}


sub neighbors {
    my $self = shift;
    $a = _gdneighbors($self->{GRID});
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

# discarding the count how many times template matched
    my $ret = gdapplytempl($self->{GRID}, $templ, $new_val); 

    return $self if defined wantarray and $ret >= 0;
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
pixels are deleted), if width is used, maxiterations is set to
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
	    $m += gdapplytempl($self, $_, 0);
	    print STDERR "#";
	}
	print STDERR " thinning, pass $i/$maxiterations: deleted ", 
	$m-$M, " pixels\n";
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
	    return new Geo::Raster(gdborders($self->{GRID}));
	} else {
	    $self->_new_grid(gdborders($self->{GRID}));
	}
    } elsif ($method eq 'recursive') {
	if (defined wantarray) {
	    return new Geo::Raster(gdborders2($self->{GRID}));
	} else {
	    $self->_new_grid(gdborders2($self->{GRID}));
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
	return new Geo::Raster(gdareas($self->{GRID}, $k));
    } else {
	$self->_new_grid(gdareas($self->{GRID}, $k));
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
	if (ral_gdnrareas($g->{GRID}, $connectivity)) {
	    return $g;
	}
    } else {
	ral_gdnrareas($self->{GRID}, $connectivity);	
    }
}


=pod

=head1 DBMS CONNECTIVITY

Geo::Raster.pm maintains internally a database handle which can be 
initialized using the method:

    db_connect(\%opt, \%attr);

A table in database can be used to store information about a grid.
A database connection must be established before database methods
can be used:

    use Geo::Raster qw(:db);

    db_connect({driver=>"driver",
		hostname=>"hostname",
		port=>"portnumber",
		database=>"database",
		username=>"username",
		password=>"password"});

The default driver is "Pg" (for PostgreSQL), the default hostname is
"", the default port number is 5432 (the default of PostgreSQL), the
default database is the current directory name (obtained with "pwd"),
the default username is the current user (obtained with "whoami"), and
the default password is "". 

=cut

sub db_connect { # \%opt, \%attr
    my($opt, $attr) = @_;
    $dbh->disconnect if $dbh;

    $opt->{driver} = 'Pg' unless $opt->{driver};
    $opt->{database} = dirname(`pwd`) unless $opt->{database};
    $opt->{hostname} = 'localhost' unless $opt->{hostname};
    $opt->{port} = '5432' unless $opt->{port};
    $opt->{username} = `whoami` unless $opt->{username};
    $opt->{password} = '' unless $opt->{password};

    my $data_source = "dbi:$opt->{driver}:dbname=$opt->{database}";
    $data_source .= ";host=" . $opt->{hostname} . ";port=" . $opt->{port} if $opt->{hostname};
    $dbh = DBI->connect($data_source, $opt->{username}, $opt->{password}, $attr);

    croak STDERR ("$DBI::errstr") unless $dbh;
    return 1;
}

=pod

The database connection is closed with

    db_close();

=cut

sub db_close {
    $dbh->disconnect if $dbh;
    undef $dbh;
}

=pod

The subroutine 

    ($rows, $fields) = sql($sql, %options);

is a wrapper for running SQL commands. Usage examples:

    use Geo::Raster qw(:db);
    db_connect();
    $lu = new Geo::Raster "lu";
    ($rows, $fields) = sql("select * from $lu->{NAME}");
    print "@{$fields}\n";
    foreach (@{$rows}) {print "@{$_}\n"}

another:

    $c = $lu->contents();
    foreach (keys %{$c}) {
	sql("insert into $lu->{NAME} (index,count) values ($_, $$c{$_})");
    }

These examples assume that there is a table "lu" in the database and
that there are columns index and count in that table.

=cut

sub sql {
    my($sql,%opt) = @_;
    croak "not connected to a DB" unless $dbh;
#    my $opt = $_[0] if ref($_[0]);
#    pop @_ if $opt;
#    my $print = ($opt and $opt->{print});
    my $print = $opt{print};
#    my $sql = CORE::join "\n", @_;
#    print "$sql\n" if ($opt and $opt->{debug});
    print "$sql\n" if $opt{debug};
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    if ($sql =~ /^select/i) {
	my @fnames = @{ $sth->{NAME} };
	print "@fnames\n" if $print;
	my @aa;    
	for (1..$sth->rows) {
	    my(@a) = $sth->fetchrow_array;
	    print "@a\n" if $print;
	    push @aa, [ @a ];
	}
	$sth->finish;
	if (wantarray()) {
	    return (\@aa,\@fnames);
	} else {
	    return \@aa;
	}
    }
}

=pod

If the table has integer columns r, g, and b we can use
the method:

    $lu->rgb(extra_colors=>extra_colors);

to create a colortable into grid lu based on the r, g, and b values in
the table lu in the database. The r, g, and b should have values in
the range 0..255. extra_colors is the number of extra colors in the
color table and its default is 0.

=cut

sub rgb {
    my($self, %opt) = @_;
    croak "not connected to a DB" unless $dbh;
    my $name = $self->{NAME};
    $name = $opt{name} if $opt{name};
    my $a = sql("select index,r,g,b from $name order by index");
    return if defined($a) and !$a;
    $self->colortable(%opt);
    foreach (@{$a}) {
	my ($index, $r, $g, $b) = @{$_};
	$self->color($index, $r, $g, $b);
    }
    return $self;
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
	return new Geo::Raster(ral_dem2aspect($self->{GRID}));
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
	return new Geo::Raster(ral_dem2slope($self->{GRID}, $z_factor));
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
    my $ret;
    if (!$opt{method}) {
	$opt{method} = 'one pour point';
	print "fixflats: Warning: method not set, using '$opt{method}'\n";
    }    
    if ($opt{method} =~ /^m/) {
	$ret = ral_fdg_fixflats1($fdg->{GRID}, $dem->{GRID});
    } elsif ($opt{method} =~ /^o/) {
	$ret = ral_fdg_fixflats2($fdg->{GRID}, $dem->{GRID});
    } else {
	croak "fixflats: $opt{method}: unknown method";
    }
    return $fdg if defined wantarray and $ret;
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
	while ($pits > 0) {
	    ral_dem_filldepressions($dem->{GRID}, $fdg->{GRID});
	    $fdg = $dem->fdg(method=>'D8');
	    $fdg->fixflats($dem,method=>'m');
	    $fdg->fixflats($dem,method=>'o');
	    $c = $fdg->contents();
	    $pits = $$c{0};
	    $pits = 0 unless $pits;
	    print STDERR "filldepressions: iteration $i: $pits depressions remain\n";
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
	    $pits = $$c{0} + 0;
	    print STDERR "breach: iteration $i: $pits depressions remain\n";
	    $i++;
	}
	return $fdg;
    }
}

sub fixpits {
    my($fdg, $dem) = @_;
    croak "fixpits: no DEM supplied" unless $dem;
    $fdg = new Geo::Raster $fdg if defined wantarray;
    my $ret;
    $ret = ral_fdg_fixpits($fdg->{GRID}, $dem->{GRID});
    return new Geo::Raster $fdg if defined wantarray and $ret;
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
	    _fdg2uag_b($fdg->{GRID}, $options{load}->{GRID}) : 
	    _fdg2uag_a($fdg->{GRID});

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
    return new Geo::Raster $g;
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
    $l = 1.5*&Geo::Raster::gdunitdist($streams->{GRID}) unless defined($l);
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
    my $ret = ral_streams_number($streams->{GRID}, $fdg->{GRID}, $i, $j, $sid);
    if ($lakes) {
	$sid = $streams->max() + 1;
	my $ret2 = ral_streams_break($streams->{GRID}, $fdg->{GRID}, $lakes->{GRID}, $sid);
	return ($ret, $ret2);
    } else {
	return $ret;
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
	my $r = _subcatchments($subs->{GRID}, 
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
	return new Geo::Raster(streams_subcatchments($streams->{GRID}, 
					      $fdg->{GRID}, $i, $j));
    }
}


1;
__END__


=head1 BUGS

DInfinity grids can be made but otherwise the methods to handle them
do not work.

=head1 AUTHOR

Ari Jolma, ari.jolma@hut.fi

=head1 SEE ALSO

perl(1).

=cut

