use ExtUtils::MakeMaker;
use ExtUtils::Depends; 
eval "use ExtUtils::F77;";
unless ($@) {
    $F77 = 1;
}

# search for ral_config.h

my($pgplot_inc,$pgplot_libs,$netpbm_libs,$ral_libs) = ('','','','');

my $ral_config;
for ($ENV{RAL_PREFIX},'/usr','/usr/local') {
    next unless -f "$_/include/ral_config.h";
    $ral_prefix = $_;
    $ral_config = "$_/include/ral_config.h";
}
unless ($ral_config) {
    print "Can't find ral_config.h, unable to continue.\n";
    print "Consider export RAL_PREFIX=DIR; perl Makefile.PL\n";
    exit 1;
}
print "Using $ral_config for libral configuration.\n";
open CONFIG,$ral_config or die "$ral_config: $!";
while (<CONFIG>) {
    if (/#define\s+HAVE_NETPBM\s+1/) {
	$netpbm_libs = ' -lnetpbm -L/usr/X11R6/lib -lX11';
    }
    if (/#define\s+HAVE_PGPLOT\s+1/) {

	my $pgplot_dir;
	for ('/usr/local/pgplot',$ENV{PGPLOT_DIR}) {
	    next unless -f "$_/cpgplot.h";
	    $pgplot_dir = $_;
	}
	die "Can't find PGPLOT\n" unless $pgplot_dir;

	print "Using PGPLOT from $pgplot_dir.\n";

	die "ExtUtils::F77 not available, it is need to link to PGPLOT" unless $F77;
	
	$pgplot_inc = " -I$pgplot_dir";
	$pgplot_libs = ExtUtils::F77->runtime . " -L$pgplot_dir -lcpgplot -lpgplot";
    }
}
close CONFIG;

$ral_inc = " -I$ral_prefix/include";
$ral_libs = " -L$ral_prefix/lib -lral";


# check for the modules required by Geo::Raster

sub chk_module {
    my($pkg) = @_;
    print "Checking for $pkg ..";
    eval { 
	my $p; 
	($p = $pkg . ".pm") =~ s#::#/#g; 
	require $p; 
    };
    if ($@) {
	print " failed\n";
	$missing_modules++;
    } else {
	print " ok\n";
    }
}

chk_module('DBI');
chk_module('Statistics::Descriptive');  # needed by zonalfct
#chk_module('Math::MatrixReal');         # could be needed in rash

if ($missing_modules) {
    print "One or more required modules is missing\n";
#    exit;
}

$package = new ExtUtils::Depends('Geo::Raster');

$package->set_inc($pgplot_inc . $ral_inc);
$package->set_libs($pgplot_libs . $netpbm_libs . $ral_libs);

$package->add_typemaps("typemap");

$package->save_config("Files.pm");

our %pm_files = (
	'Raster.pm'          => '$(INST_LIBDIR)/Raster.pm',
);

$package->add_pm (%pm_files);

WriteMakefile(
	      'NAME'	     => 'Geo::Raster',
	      'VERSION_FROM' => 'Raster.pm',
	      $package->get_makefile_vars(),
	      'EXE_FILES' => [ 'rash' ],
	      );

