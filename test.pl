# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..1\n"; }
END {print "not ok 1\n" unless $loaded;}
use Geo::Raster qw/:types :logics :db/;
$loaded = 1;
print "ok 1\n";

#use lib './';
#require 'rash.pl';

$test = 2;

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

### Basic tests

my $datatype = $REAL_GRID;
my $gd = new Geo::Raster($datatype,5,10);
$test++;
if (defined($gd)) {
    print "ok $test\n";
} else {
    print "not ok $test\n";
}

$gd->set(1,1,1);
$gd->dump("test.gd");
$gd->restore("test.gd");
unlink("test.gd");
$test++;
if ($gd->get(1,1) == 1) {
    print "ok $test\n";
} else {
    print "not ok $test\n";
}
$gd->set(1,1,0);

$gd->set(1.5);
$test++;
if ($gd->count == 50 and $gd->sum == 75 and $gd->mean == 1.5 and $gd->variance == 0) {
    print "ok $test\n";
} else {
    print "not ok $test\n";
}

my $mask = new Geo::Raster(5,10);
$mask->circle(3,5,2,1);
$mask->setmask();
$test++;
if ($gd->count == 9 and $gd->sum == 13.5 and $gd->mean == 1.5 and $gd->variance == 0) {
    print "ok $test\n";
} else {
    print "not ok $test\n";
}
$mask->removemask();

$gd->set(0);
my($dt,$M,$N,@bounds) = $gd->attrib();
$test++;
if ($dt == $datatype and $M == 5 and $N == 10) {
    print "ok $test\n";
} else {
    print "not ok $test (set size to 5,10 and datatype to $datatype and this thing says its $M,$N and $dt\n";
}

my $i = 1;
my $j = 7;
my $val = 5;
$gd->set($i,$j,$val);
my $check = $gd->get($i,$j);
$test++;
if (abs($val-$check)<0.01) {
    print "ok $test\n";
} else {
    print "not ok $test (set [$i,$j] to $val and got $check from [$i,$j]\n";
}

my ($min,$max) = $gd->getminmax();
$test++;
if (abs($min-0)<0.01 and abs($max-5)<0.01) {
    print "ok $test\n";
} else {
    print "not ok $test min should now be 0 instead of $min and max should now be $val instead of $max\n";
}

my @bin = (2);
my @histogram = $gd->histogram(\@bin);
$test++;
if (abs($histogram[0]-($M*$N-1))<0.01 and abs($histogram[1]-1)<0.01) {
    print "ok $test\n";
} else {
    print "not ok $test histogram[0] should now be ",$M*$N-1," instead of $histogram[0] and histogram[1] should now be 1 instead of $histogram[1]\n";
}

$gd->setbounds(unitdist=>1,minX=>1,minY=>2);
($x,$y) = $gd->g2w($i,$j);
($i2,$j2) = $gd->w2g($x,$y);
$test++;
if ($i2 == $i and $j2 == $j) {
    print "ok $test\n";
} else {
    print "not ok $test (g2w($i,$j) returned ($x,$y) and w2g($x,$y) returned ($i2,$j2) != ($i,$j)\n";
}

my $i2 = 4;
my $j2 = 3;
my $val2 = 2;
$gd->set($i2,$j2,$val2);
my($points) = $gd->print(nonzeros=>1,quiet=>1);
for $i (0..$#$points) {
    $p[$i]="$points->[$i]->[0],$points->[$i]->[1]=$points->[$i]->[2]";
}
print "";
$test++;
if ($#$points == 1 and (($p[0] eq '1,7=5' and $p[1] eq '4,3=2') or ($p[1] eq '1,7=5' and $p[0] eq '4,3=2'))) {
    print "ok $test\n";
} else {
    print "not ok $test, $#$points should be 1 and '@p' should be '1,7=5 4,3=2' or '4,3=2 1,7=5'\n";
}

$a=new Geo::Raster(like=>$gd);
$dump = 'dumptest';
$gd->dump($dump);
$a->restore($dump);
system "rm -f $dump";
$a = $gd == $a;
($min,$max) = $a->getminmax();
$test++;
if ($min == $max and $max == 1) {
    print "ok $test\n";
} else {
    print "not ok $test, $min and $max should both be 1\n";
}

$a = new Geo::Raster 2,3,3;
$a->set(1,1,1);
$a->set(2,2,-1);
$a->fill(1.5);
$x1 = $a->get(2,2);
$a->fill(0.5);
$x2 = $a->get(2,2);
$a->cut(1.5);
$y1 = $a->get(1,1);
$a->cut(0.5);
$y2 = $a->get(1,1);
$test++;
if ($x1 == -1 and $x2 == 0 and $y1 == 1 and $y2 == 0) {
    print "ok $test\n";
} else {
    print "not ok $x1 != -1 or $x2 != 0 or $y1 != 1 or $y2 != 0 $test\n";
}

### Demonstrate basic graphical capacity
###

print "Done basic tests, now you need to visually check the result and hit enter.\n";
# more undocumented tests follow...

# mapping is defined only for integer grids:
$gd = new Geo::Raster datatype=>1,copy=>$gd;
($x,$y) = $gd->g2w($i,$j);
($x2,$y2) = $gd->g2w($i2,$j2);
$a = $gd->get($i,$j);
$b = $gd->get($i2,$j2);
print "\nLet's look at this grid, which has the size M (height) = $M, N (width) = $N.\n";
print "There should be a white rectangle at cell (i,j)=($i,$j), i.e., (x,y)=($x,$y)\n";
print "and a grey rectangle at cell (i,j)=($i2,$j2), i.e., (x,y)=($x2,$y2).\n";

$check = $gd->plot('/xserve');
print "\npress any key to continue:";
$check = <STDIN>;

$map{$a} = $b;
$map{$b} = $a;
$gd->map(\%map);

print "The white rectangle (value $a) should now be grey (value $b) and vice versa.\n";
print "This a the result of a mapping with a hash ($a=>$b,$b=>$a).\n";
$check = $gd->plot('/xserve');
print "\npress any key to continue:";
$check = <STDIN>;

print "\nSome map algebra.\n";
print "Let's first make the grid look more interesting (grid A)\n";
$max = ($M-1)*($N-1)*($N-1);
print "Values are 0..$max, 0 at the top left and $max at the low right.\n";
print "Right is also more bright.\n";
for $i (0..$M-1) {
    for $j (0..$N-1) {
	$gd->set($i,$j,$i*$j*$j);
    }
}

$gd->plot('/xserve');
print "\npress any key to continue:";
$check = <STDIN>;

print "\nInvert a copy of the grid (grid B).\n";
$g2 = new Geo::Raster($gd);
($minval,$maxval)=$g2->getminmax();
$g2 *= -1;
$g2 += $maxval;

$g2->plot('/xserve');
print "\npress any key to continue:";
$check = <STDIN>;

print "\nTesting joining, inverted goes below the original.\n";
($datatype,$M,$N,$unitdist,$minX,undef,undef,$maxY) = $g2->attrib();
$gx = new Geo::Raster $gd;
$gx->setbounds(unitdist=>$unitdist,minX=>$minX,minY=>$maxY);
$gjoin = &Geo::Raster::join($g2,$gx);

$gjoin->plot('/xserve');
print "\npress any key to continue:";
$check = <STDIN>;

print "\nMultiply grids A and B.\n";
$g2 *= $gd;

$g2->plot('/xserve');
print "\npress any key to continue:";
$check = <STDIN>;

print "\nThreshold by comparing the grid to a scalar to find the area with value < 500.\n";
print "You may also compare two grids.\n";
$g3 = $g2 < 500;

$g3->plot('/xserve');
print "\npress any key to continue:";
$check = <STDIN>;

### Demonstrate hydrological routines (catchment delineation, stream
### networks, and subcatchments)

HYDRO:

&Geo::Raster::ral_sethashmarks(0);

$dem = new Geo::Raster('data/dem');
$lake = new Geo::Raster('data/lake');

$dem->if_then($lake,$dem->min)->plot();

print <<eot;

On the PGPLOT window you should see a digital elevation model (DEM) of
a small catchment. The black area in the middle is a small lake. In
this demo we will delineate the catchment and find the stream network
on it. The first thing we need to do is check if the lake and the DEM
grids agree.

eot

print "<press enter to continue>";
$check = <STDIN>;

$fdg = $dem->fdg(method=>'D8');
($fdg == -1)->if_then($lake,2)->plot;

print <<eot;

The grey area is now found to be flat in the DEM and the white area is
the lake. As you see, the lake is actually larger than what the lake
grid shows and the DEM may not be all flat where the lake is. We'll
have to fix this in both grids (expand the lake and make the DEM flat
on its area.

eot

print "<press enter to continue>";
$check = <STDIN>;

# expand the lake to cover the whole flat areas it covers 
# at least to some extent

$g = ($fdg==-1)->number_areas();
$c = ($g*$lake)->contents();
delete($c->{0});
undef %m;
foreach (keys %{$c}) {$m{$_}=-1}
$g->map(\%m);
$lake->if_then($g==-1,1);

# set all cells in the DEM under the lake to the lake elevation: 
# (first find out the lake elevation..)

$c = ($dem * $lake)->contents();
$cmax = 0; # ????????
foreach (keys %$c) {$z = $_ if !defined($z) or $c{$_} > $cmax}
$dem->if_then($lake,$z);

$fdg = $dem->fdg(method=>'D8');
($fdg == -1)->if_then($lake,2)->plot;

print <<eot;

The flat area and the lake based on the fixed DEM and lake grid.

eot

print "<press enter to continue>";
$check = <STDIN>;

$dem->if_then($lake,$dem->min)->plot();

print <<eot;

In the next step we will remove the depressions from the DEM. A
depression is an area within the grid which has only neighbors with
higher elevation on its rim. 

First we will look where the depressions are:

eot

print "<press enter to continue>";
$check = <STDIN>;

$dem->depressions()->plot;

print <<eot;

Here are the depressions. The depressions are removed in an iterative
process where a flow direction grid (FDG) is first calculated from the
DEM and the flat areas in the FDG are routed to lower areas. Then the
FDG contains only pit cells (cells with no neighbor lower than it) and
cells having a valid flow direction. Then the depression parts of the
catchments of the pits are filled to the lowest elevation on their
rims. The FDG is here calculated using the standard D8 method and the
flat areas are routed to lower areas using the one pour point method.

eot

print "<press enter to continue>";
$check = <STDIN>;

#$fdg = $dem->filldepressions();
#&Geo::Raster::gddebug(5);
$fdg = $dem->breach();
#&Geo::Raster::gddebug(0);

$dem->plot();

print <<eot;

This is the depressionless DEM. We can now calculate the FDG from this
DEM and it will contain only flat area cells and cells with a valid
drainage direction.

eot

print "<press enter to continue>";
$check = <STDIN>;

$fdg = $dem->fdg(method=>'D8');
$fdg->plot();

print <<eot;

Now you see the FDG calculated from the depressionless DEM. We will
still have to drain the flat areas in the FDG. We must pay attention
to the lake in this process so that it is drained through only one
cell (we know that there is no bifurcation in this lake).

eot

print "<press enter to continue>";
$check = <STDIN>;

#$fdg->if_then($lake,-2);
$fdg->fixflats($dem,method=>'m');
#$fdg->if_then($lake,-1);
#$fdg->fixflats($dem,method=>'o');
$fdg->killoutlets($lake);
$fdg->plot();

print <<eot;

Now we will use an algorithm on the FDG which calculates the upslope
area for each cell in the grid. We will call the resulting grid UAG.

eot

print "<press enter to continue>";
$check = <STDIN>;

$uag = $fdg->uag();
($minval,$maxval) = $uag->getminmax();
$minval=int($minval);
$maxval=int($maxval);
$uag->plot();

print <<eot;

A convenient method to apply to the UAG before plotting is log10(),
which takes base-10 logarithm of each value in the AU grid.

eot

print "<press enter to continue>";
$check = <STDIN>;

$nice = new Geo::Raster($uag);
$nice = $nice->log10();
$nice->getminmax();
$nice->plot();

print <<eot;

See?

eot

print "<press enter to continue>";
$check = <STDIN>;

$uag->plot();

print <<eot;

We will now use thresholding on the UAG to get the network.  You may
give the threshold or just press enter and a default value will be
used. The thresholding value has to be an integer between $minval and
$maxval

eot

$p = 'Give me a number or press enter, please: ';
while (1) {
    print "\n$p";
    $th = <STDIN>;
    chomp $th;
    if (!$th) {
	$p = $th = 364;
	$streams = $uag > $th;
	($streams->if_then($lake,1))->plot();
	$th = 'ok';
    }
    last if $th =~ /ok/ and $p;
    if (!($th =~ m/^\d+$/ and $th>=$minval and $th<=$maxval)) {
	print "Please type a number or ok.";
    } else {
	$p = 'Give me a new number or ok to continue, please: ';
	$streams = $uag > $th;
	($streams->if_then($lake,1))->plot();
    }
}

draw:

print <<eot;

Now we will select the outlet cell of the catchment.

eot

@outlet = (98,20);
print "<press enter to continue>";
$check = <STDIN>;
goto CATCHMENT;

print <<eot;

Now you will need to mark the outlet of the catchment.  I will put the
PGPLOT into an interactive mode and you should draw a line across the
stream at the outlet. Draw it well downstream of the lake.

eot

$outlet_mask = ($streams->if_then($lake,1))->drawon();
$masked = $streams * $outlet_mask;

$a = $masked->print(quiet=>1,nonzeros=>1);

if ($#$a < 0) {
    print "\nIt happened so that the line you draw did not have any common cells with\n";
    print "the stream network, please try again.\n";
    goto draw;
}

print "\nNonzero values from the masked stream network:\ni,j value\n";
for $i (0..$#$a) {
    $outlets{"$a->[$i]->[0],$a->[$i]->[1]"} = $a->[$i]->[2];
    print "$a->[$i]->[0],$a->[$i]->[1]\n";
}
print "\n";

$masked->plot();

print <<eot;

We have now masked the network with your drawing
Masking was done by multiplication:
  for each cell do {
	   cell(masked) = cell(stream_network) * cell(mask)
  }
The masked grid is plotted and the nonzero values from it
are printed above in the form i,j value
Now we are ready to delineate the catchment.\nGive me the outlet point (from above):

eot

while (1) {
    print "\nThe i, please: ";
    $i = <STDIN>;
    chomp $i;
    print "The j, please: ";
    $j = <STDIN>;
    chomp $j;
    if (!("$i$j" =~ m/^\d+$/)) {
	print "Now, be a good boy or girl and type more carefully!\n";
    } else {
	if (!defined($outlets{"$i,$j"})) {
	    print "Hmm.. how do you know $i,$j is an outlet point?\n";
	} else {
	    last;
	}
    }
}
print "$i,$j, ok, that cell is on the stream network\n";
@outlet = ($i,$j);

 CATCHMENT:

print <<eot;

This is now the catchment. To partition it to subcatchments defined by
your stream network we first tag the river sections in the network
with unique ids. Before this we will remove all headwater stream segments
which are shorter than 25 m (the size a cell is 5 m x 5 m in this DEM).

eot

$catchment = $fdg->catchment(@outlet);
($catchment->if_then($lake,0))->plot();

print "<press enter to continue>";
$check = <STDIN>;

$streams->prune($fdg, $lake, @outlet, 25);
$streams->number_streams($fdg, $lake, @outlet, 2);
$streams -= 1; # start stream numbering from 1
$streams->map({-1=>0});
$x = $streams->if_then($lake,0);
$x->if_then($lake,$x->max+1);
$x->plot();
$c = $x->contents();
foreach (sort {$a<=>$b} keys %{$c}) {
    print "$_ $$c{$_}\n" unless $_ < 1;
}

print <<eot;

I have printed the contents of the net and plotted it. Well, in fact a
part of the stream network is "below" the lake and the lake is in fact
a part of the network. What I have printed and plotted are the
contents a grid which is a combination of the streams and lake
grids. Next we'll find the subcatchments on the catchment.

eot

print "<press enter to continue>";
$check = <STDIN>;

#&Geo::Raster::gddebug(20);
($subcatchments,undef) = $streams->subcatchments($fdg, $lake, @outlet, 1);
($subcatchments->if_then($lake,0))->plot();

print <<eot;

Here, subcatchments. And a pretty picture...

eot

print "<press enter to continue>";
$check = <STDIN>;

$subcatchments->colored_map();
$subcatchments->if_then($streams,0);
($subcatchments->if_then($lake,0))->plot();

print <<eot;

Here.

That's all folks!

eot
