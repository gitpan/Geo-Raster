my($inc,$libs,$cflags) = ('','','');

my %missing_modules;

$missing_modules{chk_module('POSIX')} = 1;
$missing_modules{chk_module('Carp')} = 1;
$missing_modules{chk_module('FileHandle')} = 1;
$missing_modules{chk_module('Statistics::Descriptive')} = 1;
$missing_modules{chk_module('Config')} = 1;
$missing_modules{chk_module('Geo::GDAL')} = 1;
$missing_modules{chk_module('ExtUtils::MakeMaker')} = 1;
$missing_modules{chk_module('ExtUtils::Depends')} = 1;
delete $missing_modules{''};

my @missing_modules = keys %missing_modules;
warn "Following required modules are missing: @missing_modules\n" if @missing_modules;

use ExtUtils::MakeMaker;
use ExtUtils::Depends;
use ExtUtils::PkgConfig;

my($inc,$libs,$cflags) = ('','','');

for $package ('gdal','gdk-pixbuf-2.0','libral') {
    print "Checking for $package: ";
    my($c, $l);
    if ($package eq 'gdal' and $^O ne 'MSWin32') {
	$c = `gdal-config --cflags`;
	chomp $c;
	$l = `gdal-config --libs`;
	chomp $l;
    } else {
	%pkg_info = ExtUtils::PkgConfig->find ($package);
	$c = $pkg_info{cflags};
	$l = $pkg_info{libs};
    }
    $cflags .= " $c";
    # this code is for MinGW in fact
    if ($^O eq "MSWin32") {
	my @a = split /\s+/,$l;
	for (@a) {
	    if (/^-l/ and !(/.dll/)) {
		$_ .= '.dll.a';
	    }
	}
	$l = join(' ',@a);
    }
    $libs .= " $l";
    print "ok\n";
}

$package = new ExtUtils::Depends('Geo::Raster');

$package->set_inc($inc);
$package->set_libs($libs);

$package->add_typemaps("typemap");

$package->save_config("Files.pm");

our %pm_files = 
    (
     'lib/Geo/Layer.pm'                   => '$(INST_LIBDIR)/Layer.pm',
     'lib/Geo/Raster.pm'                  => '$(INST_LIBDIR)/Raster.pm',
     'lib/Geo/Raster/IO.pm'               => '$(INST_LIBDIR)/Raster/IO.pm',
     'lib/Geo/Raster/Image.pm'            => '$(INST_LIBDIR)/Raster/Image.pm',
     'lib/Geo/Raster/Algorithms.pm'       => '$(INST_LIBDIR)/Raster/Algorithms.pm',
     'lib/Geo/Raster/TerrainAnalysis.pm'  => '$(INST_LIBDIR)/Raster/TerrainAnalysis.pm',
     'lib/Geo/Raster/Geostatistics.pm'    => '$(INST_LIBDIR)/Raster/Geostatistics.pm',
     );

$package->add_pm (%pm_files);

WriteMakefile('NAME'	     => 'Geo::Raster',
	      'VERSION_FROM' => 'lib/Geo/Raster.pm',
	      $package->get_makefile_vars(),
	      'EXE_FILES' => [ 'rash' ],
	      CCFLAGS => "-O2 -fno-builtin $cflags $inc",
	      );

sub chk_module {
    my $pkg = shift;
    print "Checking for $pkg:";
    eval { 
	my $p; 
	($p = $pkg . ".pm") =~ s#::#/#g; 
	require $p; 
    };
    if ($@) {
	print " failed\n";
	return $pkg;
    } else {
	print " ok\n";
	return '';
    }
}

