use ExtUtils::MakeMaker;
use ExtUtils::Depends; 

chk_module('gdalconst','gdal','Statistics::Descriptive');  # needed by zonalfct

if (%missing_modules) {
    print "Following required modules are missing:";
    for (keys %missing_modules) {
	print " $_";
    }
    print "\n";
    exit;
}

# search for ral_config.h

my($ral_libs) = ('');

my $ral_config;
for ('/usr/include','/usr/local/include',$ENV{RAL_DIR},'../libral') {
    print "testing: $_/ral_config.h\n";
    next unless -f "$_/ral_config.h";
    $ral_dir = $_;
    $ral_config = "$_/ral_config.h";
    last;
}
unless ($ral_config) {
    print "Can't find ral_config.h, unable to continue.\n";
    print "Consider export RAL_DIR=DIR; perl Makefile.PL\n";
    exit 1;
}
print "Using $ral_config for libral configuration.\n";
my $version;
open PM,'Raster.pm' or die "Raster.pm: $!";
while (<PM>) {
    if (/\$VERSION = \'([\d\.]+)\'/) {
	$version = $1;
    }
}
close PM;
open CONFIG,$ral_config or die "$ral_config: $!";
while (<CONFIG>) {
    if (/PACKAGE_VERSION "([\d\.]+)"/) {
	die "the version of libral (=$1) is newer than that of this (=$version)!" if $1 > $version;
    }
}
close CONFIG;

$ral_inc = " -I$ral_dir";
if ($ral_dir =~ /\/include$/) {
    $ral_dir =~ s/\/include$//;
    $ral_dir .= '/lib';
} else {
    $ral_dir .= '/.libs';
}
$ral_libs = " -L$ral_dir -lral";

$ral_libs .= " -lgdal";


# check for modules

sub chk_module {
    for my $pkg (@_) {
	print "Checking for $pkg ..";
	eval { 
	    my $p; 
	    ($p = $pkg . ".pm") =~ s#::#/#g; 
	    require $p; 
	};
	if ($@) {
	    print " failed\n";
	    $missing_modules{$pkg} = 1;
	} else {
	    print " ok\n";
	}
    }
}

my $GLIB_CFLAGS = `pkg-config --cflags glib-2.0`;
chomp $GLIB_CFLAGS;
my $GLIB_LIBS = `pkg-config --libs glib-2.0`;
chomp $GLIB_LIBS;

my $GTK_CFLAGS = `pkg-config --cflags gtk+-2.0`;
chomp $GTK_CFLAGS;
my $GTK_LIBS = `pkg-config --libs gtk+-2.0`;
chomp $GTK_LIBS;

$package = new ExtUtils::Depends('Geo::Raster');

$package->set_inc($ral_inc);
$package->set_libs($ral_libs .' ' . $GLIB_LIBS .' ' . $GTK_LIBS);

$package->add_typemaps("typemap");

$package->save_config("Files.pm");

our %pm_files = (
	'Raster.pm'          => '$(INST_LIBDIR)/Raster.pm',
);

$package->add_pm (%pm_files);

#       

WriteMakefile(
	      'NAME'	     => 'Geo::Raster',
	      'VERSION_FROM' => 'Raster.pm',
	      $package->get_makefile_vars(),
	      'EXE_FILES' => [ 'rash' ],
	      MYEXTLIB => "$ral_dir/libral\$(LIB_EXT)",
	      CCFLAGS => '-O2 -fno-builtin -ansi '.$GLIB_CFLAGS.' '.$GTK_CFLAGS
	      );

sub My::postamble {
"
\$(MYEXTLIB): $ral_dir/Makefile
	cd $ral_dir && \$(MAKE) \$(PASTHRU)
";
}
