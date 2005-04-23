# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; }
END {print "not ok 1\n" unless $loaded;}
use Geo::Raster qw/:types :logics :db/;
use POSIX;
$loaded = 1;

if (0) {
    $dem = new Geo::Raster '../dem';
#    $fdg = $dem->fdg;
#    $fdg->fixflats($dem);
    Geo::Raster::ral_setdebug(0);
#    $dem->breach;
    $fdg = $dem->pitless_fdg();
    exit;
}

$subs = 1;
$debug = 0;

#goto current;

#use Test::Simple tests => 13;
use Statistics::Descriptive;

sub ok {
    my($test,$msg,$r) = @_;
    $tests_failed = 0 unless defined $tests_failed;
    $test_nr = 1 unless defined $test_nr;

    if (1) {
	print $test ? "ok" : "not ok";
	print " $test_nr - $msg             ";
	print $sub_tests ? "\r" : "\n";
    }

#    print "\n";
    $sub_tests = 0;
    unless ($test) {
	$tests_failed++;
	push @test_failed,"$test_nr - $msg\n";
    }
    $test_nr++;
    $sub_tests = 1 if $r;
    return $test;
}

sub diff_ok {
    my ($a1,$a2,$p) = @_;
    print "a=$a1, b=$a2\n" if $p;
    return 0 unless defined $a1 and defined $a2;
    my $test = abs($a1 - $a2);
    $test /= $a1 unless $a1 == 0;
    return ($test < 0.01);
}

sub tests_done {
    $test_nr--;
    print "\n$tests_failed/$test_nr tests failed\n";
    print "failed tests were:\n @test_failed\n" if @test_failed;
}

ok(1,"loaded");

#my $gd = new Geo::Raster("/home/gis/clime/corine/counts/50-10x10");
#$gd->view;

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

### Basic tests

{
    my $datatype = $REAL_GRID;
    my $gd = new Geo::Raster($datatype,5,10);
    ok(defined($gd),"simple new");
    for ('data/dem','data/landcover') {
	$gd = new Geo::Raster $_;
	ok(defined($gd),"open",$subs);
    }
}
$sub_tests = 0;
#exit;

for my $datatype1 ($INTEGER_GRID,$REAL_GRID) {
    my $gd1 = new Geo::Raster($datatype1,5,10);
    $gd1->set(5);
    ok(diff_ok($gd1->get(3,3),5),'set & get',$subs);
    for my $datatype2 (undef,$INTEGER_GRID,$REAL_GRID) {
	my $gd2 = new Geo::Raster $gd1, $datatype2;
	ok(diff_ok($gd1->get(3,3),$gd2->get(3,3)),'copy',$subs);
    }
}
$sub_tests = 0;

my %dm = (''=>1,1=>1,2=>2,INTEGER_GRID=>1,REAL_GRID=>2,'int'=>1,'real'=>2,'float'=>2);
for my $datatype1 ('INTEGER_GRID','REAL_GRID',$INTEGER_GRID,$REAL_GRID,'int','real','float') {
    my $gd1 = new Geo::Raster($datatype1,5,10);
    my($dt1) = $gd1->attributes();
    for my $datatype2 ('','INTEGER_GRID','REAL_GRID',$INTEGER_GRID,$REAL_GRID,'int','real','float') {
	my $gd2 = new Geo::Raster like=>$gd1, datatype=>$datatype2;
	my($dt2) = $gd2->attributes();
	my $cmp = $dm{$datatype2};
	$cmp = $dt1 if $datatype2 eq '';
#	print "$datatype1 $dm{$datatype1},$dt1 $datatype2 $dm{$datatype2},$dt2\n";
#	next;
	ok(diff_ok($dm{$datatype1},$dt1,$debug),'new like',$subs);
	ok(diff_ok($cmp,$dt2,$debug),'new like',$subs);
    }
}
$sub_tests = 0;
#exit;

{
    for my $datatype ($INTEGER_GRID,$REAL_GRID) {
	my $gd = new Geo::Raster($datatype,5,10);
	$gd->set(5);
	$gd->set(4,3,2);
	my($points) = $gd->array();
	$j = 0;
	for ($i=0; $i<=$#$points; $i+=3) {
	    $p[$j]="$points->[$i],$points->[$i+1]=$points->[$i+2]";
	    $j++;
	}
	ok(($p[17] eq '1,7=5' and $p[43] eq '4,3=2'),"array",$subs);
    }
}
$sub_tests = 0;

{
    for my $datatype ($INTEGER_GRID,$REAL_GRID) {
	my $gd = new Geo::Raster($datatype,5,10);
	$gd->set(5);
	$a=new Geo::Raster(like=>$gd);
	@sgd = $gd->size();
	@sa = $a->size();
	for (0..1) {
	    ok(diff_ok($sgd[0],$sa[0]),"new like",$subs);
	}
	$dump = 'dumptest';
#	$gd->print;
	$gd->dump($dump);
	$a->restore($dump);
	ok(diff_ok($gd->get(3,3),$a->get(3,3)),"dump and restore",$subs);
#    unlink($dump);
	$a = $gd == $a;
	my @nx = $a->getminmax();
	ok(diff_ok($nx[0],$nx[1],$debug),"getminmax",$subs);
	ok(diff_ok($nx[1],1,$debug),"getminmax".$subs);
	my $min = $a->min();
	my $max = $a->max();
	ok(diff_ok($min,$nx[0],$debug),"min from min()",$subs);
	ok(diff_ok($max,$nx[1],$debug),"max from max()".$subs);
    }
}
$sub_tests = 0;

{
    my $test_grid = 'test_grid';
    for my $datatype ($INTEGER_GRID,$REAL_GRID) {
	my $gd1 = new Geo::Raster($datatype,5,10);
	$gd1->set(5);
	$gd1->save($test_grid);
	my $gd2 = new Geo::Raster $test_grid;
	ok(diff_ok($gd1->get(3,3),$gd2->get(3,3)),'save/open',$subs);
    }
    for ('.hdr','.bil') {unlink($test_grid.$_)};
    $sub_tests = 0;

    for my $datatype ($INTEGER_GRID,$REAL_GRID) {
	my $gd = new Geo::Raster($datatype,5,10);
	$gd->set(1,1,1);
	$gd->dump($test_grid);
	$gd->restore($test_grid);
	unlink($test_grid);
	ok(diff_ok($gd->get(1,1),1),"dump and restore",$subs);
    }
}
$sub_tests = 0;

{
    my $gd1 = new Geo::Raster($INTEGER_GRID,5,10);
    my %bm = (1 => unit_length,
	      2 => minX,
	      3 => minY,
	      4 => maxX,
	      5 => maxY);
    #valid bounds:
    my %bounds = (unit_length => 1.5,
		  minX => 3.5,
		  minY => 2.5,
		  maxX => 18.5,
		  maxY => 10);
    for my $b ([1,2,3],[1,2,5],[1,3,4],[2,3,4],[2,3,5],[3,4,5]) {
	my %o;
	for (0..2) {
	    my $bm = $bm{$b->[$_]};
	    $o{$bm} = ($bounds{$bm});
	}
#	for (keys %o) {
#	    print "bo: $_ $o{$_}\n";
#	}
	$gd1->setbounds(%o);
	my @attrib = $gd1->attributes();
	for (1..5) {
	    ok(diff_ok($bounds{$bm{$_}},$attrib[2+$_]),"bounds",$subs);
	}
    }
    $sub_tests = 0;
    my $gd2 = new Geo::Raster($INTEGER_GRID,5,10);
    $gd1->copyboundsto($gd2);
    my @attrib1 = $gd1->attributes();
    my @attrib2 = $gd2->attributes();
    for (1..5) {
	ok(diff_ok($attrib1[2+$_],$attrib2[2+$_]),"copy bounds",$subs);
    }
}
$sub_tests = 0;

{
    my $gd = new Geo::Raster($INTEGER_GRID,5,10);
    $gd->setbounds(unit_length=>1.4,minX=>1.2,minY=>2.4);
    my @point = $gd->g2w(3,7);
    my @cell = $gd->w2g(@point);
    ok(($cell[0] == 3 and $cell[1] == 7),"world coordinates <-> grid coordinates");
}

{
    my $gd = new Geo::Raster($INTEGER_GRID,5,10);
    my $i = 1;
    my $j = 7;
    my $val = 5;
    $gd->set($i,$j,$val);
    my $check = $gd->get($i,$j);
    ok((abs($val-$check)<0.01),"set and get");
    
    my ($min,$max) = $gd->getminmax();
    ok((abs($min-0)<0.01 and abs($max-5)<0.01),"getminmax");
}


current:

# data test here

# test overloaded operators and then some
# integer and real grids 
# grid arg, real arg, integer arg
my %ret = (neg=>1,plus=>1,minus=>1,times=>1,over=>1,modulo=>1,power=>1,add=>1,
	   subtract=>1,multiply_by=>1,divide_by=>1,modulus_with=>1,to_power_of=>1,
	   lt=>1,gt=>1,le=>1,ge=>1,eq=>1,ne=>1,cmp=>1,
	   atan2=>1,cos=>1,sin=>1,exp=>1,abs=>1,log=>1,sqrt=>1,round=>1,
	   acos=>1,atan=>1,ceil=>1,cosh=>1,floor=>1,log10=>1,sinh=>1,tan=>1,tanh=>1,
	   not=>1,and=>1,or=>1,
	   min=>1,max=>1);
my %args = (neg=>0,plus=>1,minus=>1,times=>1,over=>1,modulo=>1,power=>1,add=>1,
	    subtract=>1,multiply_by=>1,divide_by=>1,modulus_with=>1,to_power_of=>1,
	    lt=>1,gt=>1,le=>1,ge=>1,eq=>1,ne=>1,cmp=>1,
	    atan2=>1,cos=>0,sin=>0,exp=>0,abs=>0,log=>0,sqrt=>0,round=>0,
	    acos=>0,atan=>0,ceil=>0,cosh=>0,floor=>0,log10=>0,sinh=>0,tan=>0,tanh=>0,
	    not=>0,and=>1,or=>1,
	    min=>1,max=>1);
my %operator = (neg=>'-',plus=>'+',minus=>'-',times=>'*',over=>'/',modulo=>'%',power=>'**',add=>'+=',
		subtract=>'-=',multiply_by=>'*=',divide_by=>'/=',modulus_with=>'%=',to_power_of=>'**=',
		lt=>'<',gt=>'>',le=>'<=',ge=>'>=',eq=>'==',ne=>'!=',cmp=>'<=>',
		not=>'!',and=>'&&',or=>'||');

for my $method ('neg','plus','minus','times','over','modulo','power','add',
		'subtract','multiply_by','divide_by','modulus_with','to_power_of',
		'lt','gt','le','ge','eq','ne','cmp',
		'atan2','cos','sin','exp','abs','log','sqrt','round',
		'acos','atan','ceil','cosh','floor','log10','sinh','tan','tanh',
		'not','and','or',
		'min','max') {

#    exit if $method eq 'subtract';
#    next if $method eq 'atan2';
    next if $method eq 'and';
    next if $method eq 'or';

    for my $datatype1 ($INTEGER_GRID,$REAL_GRID) {
	my $gd1 = new Geo::Raster($datatype1,10,10);
	$gd1->set(5);

	if ($args{$method}) {

	    if ($ret{$method}) {
		
		for my $a1 ('ig','rg',13.56,4) {

		    my $arg= $a1;
		    if ($a1 eq 'ig') {
			$datatype2 = $INTEGER_GRID;
			$arg = '$gd2';
		    } elsif ($a1 eq 'rg') {
			$datatype2 = $REAL_GRID;
			$arg = '$gd2';
		    } else {
			next if $method eq 'atan2';
		    }

		    my $gd2 = new Geo::Raster($datatype2,10,10);
		    
		    $gd1->set(5) if $method eq 'to_power_of';
		    $gd2->set(2);

		    next if (($method =~ /^modul/) and 
			     ($datatype1 == $REAL_GRID or $datatype2 == $REAL_GRID));

		    mytest($method,$gd1,$gd2,$arg,1,$a);

		}
	    } else {
		die "did not expect this";
	    }
	} else {
	    if ($ret{$method}) {
		mytest($method,$gd1,'','',2);
	    } else {
		die "did not expect this";
	    }
	}
    }
    $sub_tests = 0 if $method eq 'lt';
    $sub_tests = 0 if $method eq 'not';
}
$sub_tests = 0;
#exit;

sub round {
    my $number = shift;
    return int($number + 0.5);
}

sub min {
    my $a = shift;
    my $b = shift;
    return $a < $b ? $a : $b;
}

sub max {
    my $a = shift;
    my $b = shift;
    return $a > $b ? $a : $b;
}

sub mytest {
    my($method,$gd1,$gd2,$arg,$o,$a) = @_;
    print "\nmytest with $method $gd1->{DATATYPE},$gd2->{DATATYPE} arg=$arg\n" if $debug;

    my $ret;
    my $comp;

    return if $method eq 'not' and $gd1->{DATATYPE} != $INTEGER_GRID;
    return if $method eq 'atan2' and $gd1->{DATATYPE} != $REAL_GRID;
    return if $method eq 'atan2' and $gd2->{DATATYPE} != $REAL_GRID;
    return if $method eq 'floor' and $gd1->{DATATYPE} != $REAL_GRID;
    return if $method eq 'ceil' and $gd1->{DATATYPE} != $REAL_GRID;
    
    if ($method eq 'acos') {
	$gd1->set(1);
    }

    my $val = $gd1->get(3,3);

    if ($o == 1) {
	my $a = $arg;
	$a = $gd2->get(3,3) if $arg eq '$gd2';
	$op1 = "\$val $operator{$method} $a";
	$op2 = "$method(\$val,$a)";
	$op2 = "round($op2)" if $gd1->{DATATYPE} == $INTEGER_GRID;
    } else {
	$op1 = "$operator{$method} $val";
	$op2 = "$method(\$val)";
    }

    my $op = $operator{$method} ? $op1 : $op2;

    my $eval = "\$ret = \$gd1->$method($arg); \$comp = $op";

    print "$method $gd1->{DATATYPE}\n$eval\n" if $debug;

    $gd1->{NAME} = 'gd1';

    eval $eval;
    print $@ if $debug;
    
    if (ref($ret) eq 'Geo::Raster') {
	ok($ret->{NAME} eq $gd1->{NAME},"copy attr in $method",$subs);
	if ($debug) {
	    print "eval: $eval\n",$ret->{NAME},' ? ',$gd1->{NAME},"\n" unless $ret->{NAME} eq $gd1->{NAME};
	}
    }

    $ret = $ret->get(3,3);
    print "val = $val, (ret = $ret) == (comp = $comp)?\n" if $debug;
    ok(diff_ok($comp,$ret), "$method", $subs);
}
#exit;

{
    for my $datatype1 ($INTEGER_GRID,$REAL_GRID) {
	my $a = new Geo::Raster($datatype1,5,10);
	$a->{NAME} = 'a';
	for ('+=','-=','*=','/=') {
	    my $eval = "\$a $_ 1;";
	    eval $eval;
#	    print "$eval\n$a->{NAME}\n";
	    print $@ if $debug;
	    ok($a->{NAME} eq 'a',"copy attr in $_",$subs);
	}
	for ('+','-','*','/') {
	    my $b;
	    my $eval = "\$b = \$a $_ 1;";
	    eval $eval;
#	    print "$eval\n$b->{NAME}\n";
	    print $@ if $debug;
	    ok($a->{NAME} eq 'a',"copy attr in $_",$subs);
	}
    }
}
$sub_tests = 0;
#exit;

{
    for my $datatype1 ($INTEGER_GRID,$REAL_GRID) {
	my $a = new Geo::Raster($datatype1,5,10);
	for my $datatype2 ($INTEGER_GRID) { #,$REAL_GRID) {
	    my $b = new Geo::Raster($datatype2,5,10);
	    for my $datatype3 (-1,0,$INTEGER_GRID,$REAL_GRID) {
		my $c = new Geo::Raster($datatype3,5,10) if $datatype3 > 0;
		$c = 4 if $datatype3 == 0;
		$c = {0=>1,6=>2} if $datatype3 == -1;
		
		$a->set(1);	       
		$b->rect(2,2,4,6);

		$d = $a->if_then($b,$c);
		$s = $d->sum;
		ok(diff_ok($s,50),"if then (else)",$subs);

		$a->if_then($b,$c);
		$s = $a->sum;
		ok(diff_ok($s,50),"if then (else)",$subs);

	    }
	}
    }
}
$sub_tests = 0;
#exit;

# cross, binary, bufferzone tests here

{
    for my $datatype ($INTEGER_GRID,$REAL_GRID) {
	my $gd = new Geo::Raster($datatype,5,10);
	$gd->set(5);
	$gd->set(1,1,0);
	$gd->set(2);
	my %ret = (count=>50,sum=>100,mean=>2,variance=>0);
	for ('count','sum','mean','variance') {
	    my $ret; 
	    $eval = "\$ret = \$gd->$_";
	    eval $eval;
#	    print "$_ = $ret\n";
	    ok(diff_ok($ret{$_},$ret),$_,$subs);
	}
    }
}
$sub_tests = 0;

# line rect circle floodfill 

#current:
#$subs = 0;
#$debug = 1;
{
    for my $datatype ($INTEGER_GRID,$REAL_GRID) {
	my $gd1 = new Geo::Raster($datatype,5,5);
	my $gd2 = new Geo::Raster($datatype,5,5);
	my $a;
	$gd2->set(1);
	$gd1->line(0,2,3,4,1);
	$a = $gd2->line(0,2,3,4);
	my $i;
	for ($i = 0; $i < @$a; $i += 3) {
	    ok(diff_ok($gd1->get($a->[$i],$a->[$i+1]),$a->[$i+2]),'get line',$subs);
	}

	$gd1 = new Geo::Raster($datatype,5,5);
	$gd1->rect(0,2,3,4,1);
	$a = $gd2->rect(0,2,3,4);
	for ($i = 0; $i < @$a; $i += 3) {
	    ok(diff_ok($gd1->get($a->[$i],$a->[$i+1]),$a->[$i+2]),'get rect',$subs);
	}

	$gd1 = new Geo::Raster($datatype,5,5);
	$gd1->circle(2,2,2,1);
	$a = $gd2->circle(2,2,2);
	for ($i = 0; $i < @$a; $i += 3) {
	    ok(diff_ok($gd1->get($a->[$i],$a->[$i+1]),$a->[$i+2]),'get circle',$subs);
	}

    }

    my $gd1 = new Geo::Raster($INTEGER_GRID,5,5);
    my $gd2 = new Geo::Raster($REAL_GRID,5,5);
    for ('line','rect','circle','floodfill') {
	$eval = "\$gd1->$_(2,3,4,4,3);\$gd2->$_(2,3,4,4,3);";
	eval $eval;
	if (0) {
	    $gd->print;
	    my $ret = $gd->sum();
	    print "$_ $ret\n";
	}
	ok(diff_ok($gd1->sum(),$gd2->sum()),$_,$subs);
    }
}
#exit;
$sub_tests = 0;
#exit;

{
    for my $datatype ($INTEGER_GRID,$REAL_GRID) {
	my $gd = new Geo::Raster($datatype,5,10);
	$gd->set(5);
	my $mask = new Geo::Raster(5,10);
	$mask->circle(3,5,2,1);
	$mask->setmask();
	my %ret = (count=>9,sum=>45,mean=>5,variance=>0);
	for ('count','sum','mean','variance') {
	    my $ret; 
	    $eval = "\$ret = \$gd->$_";
	    eval $eval;
#	    print "$_ = $ret\n";
	    ok(diff_ok($ret{$_},$ret),"masked $_",$subs);
	}
	$mask->removemask();
    }
}
$sub_tests = 0;

{
    for my $datatype ($INTEGER_GRID,$REAL_GRID) {
	my $gd = new Geo::Raster($datatype,5,10);
	$gd->set(2);
	$gd->circle(3,5,2,3);
#	$gd->print;
	my @bin = (2);
	my @histogram = $gd->histogram(\@bin);
#	print "@histogram\n";
	ok($histogram[0]==41,"histogram",$subs);
	ok($histogram[1]==9,"histogram",$subs);
    }
}
$sub_tests = 0;

# test here 

# distances directions 
# clip join transform frame 

#current:
{
    for my $datatype ($INTEGER_GRID,$REAL_GRID) {
	my %ans = ($INTEGER_GRID=>{0=>1,mean=>1, variance=>0, min=>1, max=>1, count=>100},
		   $REAL_GRID=>{0=>1,mean=>1, variance=>0, min=>1, max=>1, count=>'nodata'});
	for my $pick (0,'mean', "variance", "min", "max", "count") {
	    my $gd = new Geo::Raster($datatype,100,100);
	    $gd->set(1);
	    my @tr = (0, 10, 0, 0, 0, 10);
	    $gd->transform(\@tr,10,10,$pick,1);
	    my $ret = $gd->get(0,0);
#	    print "\nret = $ret, $pick\n";
#	    $gd->print;
	    if ($datatype==$REAL_GRID and $pick eq 'count') {
		ok($ret eq $ans{$datatype}{$pick},"transform",$subs);
	    } else {
		ok(diff_ok($ans{$datatype}{$pick},$ret),"transform",$subs);
	    }
	}
    }
}
$sub_tests = 0;
#exit;

{
    my $gd = new Geo::Raster($REAL_GRID,10,10);
    $gd->function('int(10*rand())');
    my $c = $gd->contents;
    my %c;
    for my $i (0..9) {
	for my $j (0..9) {
	    $c{$gd->get($i,$j)}++;
	}
    }
    for (keys %c) {
	ok(diff_ok($c{$_},$c->{$_}),"contents",$subs);
    }
    $gd = new Geo::Raster(10,10);
    $gd->function('round(10*rand())');
    $c = $gd->contents;
    %c = ();
    for my $i (0..9) {
	for my $j (0..9) {
	    $c{$gd->get($i,$j)}++;
	}
    }
    for (keys %c) {
	ok(diff_ok($c{$_},$c->{$_}),"contents",1);
    }
}
$sub_tests = 0;

{
    for my $datatype ($INTEGER_GRID,$REAL_GRID) {
	my $gd = new Geo::Raster($datatype,10,10);
	$gd->function('rand()');
	my $zones = new Geo::Raster(10,10);
	$zones->rect(3,3,5,7,4);
	my $zh = $gd->zones($zones);
	my $n = 0;
	my %stat;
	my $zc = $gd->zonalcount($zones);
	for my $z (keys %$zh) {
	    $stat{$z} = Statistics::Descriptive::Full->new();
	    my $k = @{$zh->{$z}};
	    $n += $k;
	    for (@{$zh->{$z}}) {
		$stat{$z}->add_data($_);
	    }
	    ok(diff_ok($zc->{$z},$k,$debug),'zonal count',$subs);
	}
	ok(diff_ok($n,10*10,$debug),'zones',$subs);
	for my $z (keys %$zh) {
	    for ('sum','mean','min','max','variance') {
		my $cmp;
		my $eval = "\$zc = \$gd->zonal$_(\$zones);\$cmp=\$stat{\$z}->$_();";
		eval $eval;
		ok(diff_ok($zc->{$z},$cmp,$debug),"zonal $_",$subs);
	    }
	}
    }
    
}
#exit;
$sub_tests = 0;

# growzones interpolate dijkstra map neighbors colored_map applytempl thin borders areas connect number_areas 

{
    my @args; 
    $args[0] = {growzones=>['new Geo::Raster($INTEGER_GRID,10,10)','4'],interpolate=>['method=>"nn"'],
		dijkstra=>['4,5'],map=>['{0=>1,3=>5,4=>3}'],
		applytempl=>['[0,1,0,0,1,0,1,1,1],2'],
		thin=>['quiet=>1'],borders=>['method=>"simple"'],
		areas=>[],
		neighbors=>[],
		colored_map=>[],
		connect=>[],
		number_areas=>[]};

    $args[1] = {borders=>['method=>"recursive"']};

    my %for_real = (interpolate=>1,dijkstra=>1);

    for my $datatype ($INTEGER_GRID,$REAL_GRID) {

	my $gd = new Geo::Raster($datatype,10,10);
	$gd->set(2,2,3);
	for my $method ('growzones','interpolate','dijkstra','map','neighbors',
			'colored_map','applytempl','thin','borders','areas','connect','number_areas') {

	    next if $datatype==$REAL_GRID and !$for_real{$method};
	    
	    for my $cv (0,1) {

		next unless $args[$cv]->{$method};
	  
		my $agd = new Geo::Raster($datatype,10,10);

		my @as;
		for my $a (@{$args[$cv]{$method}}) {
		    if ($a eq 'grid') {
			push @as,"\$agd";
		    } elsif ($a eq 'int') {
			push @as,4;
		    } else {
			push @as,$a;
		    }
		}
		my $arg_list = join(',',@as);

		for (1,0) {
		    my $lvalue = '';
		    $lvalue = '$lvalue=' if $_;
		    my $eval = "$lvalue\$gd->$method($arg_list);";
#		    print "eval: $eval\n";
		    eval $eval;
		    print $@;
		    exit if $@;
		    ok(!$@,$method,$subs);
		}
	    }
	}
    }
}
$sub_tests = 0;

# colortable get_colortable color addcolors 
{
    my $gd = new Geo::Raster($INTEGER_GRID,10,10);
    $gd->set(5,5,5);
    $gd->colortable(); # creates 6 colors
    my $ct = $gd->get_colortable();
    my @c1 = (10,20,30);
    $gd->color(4,@c1);
    $gd->addcolors(4);
    my @c2 = $gd->color(4);
    for (0..2) {
	ok(diff_ok($c1[$_],$c2[$_]),"colors",$subs);
    }
}
$sub_tests = 0;

# begin_animate animate end_animate plot view 

print STDERR "skipping graphics methods\n";

if (0) {
    # png rgba test
    my $r = new Geo::Raster 100,100;
    my $g = new Geo::Raster 100,100;
    my $b = new Geo::Raster 100,100;
    my $a = new Geo::Raster 100,100;
    $r->set(50);
    $g->set(150);
    $b->set(250);
    $a->set(200);
    my $ret = &Geo::Raster::ral_RGBAgd2png($r->{GRID}, $g->{GRID}, $b->{GRID}, $a->{GRID}, "test.png");
    print "ret=$ret\n";
    exit;
}

# 

# db_connect db_close sql rgb 

print STDERR "skipping db methods\n";

# movecell


#current:

# tests here for terrain analysis & hydrological functions
# not tested: route, killoutlets, prune, number_streams, subcatchments

{
    my @args; 
    $args[0] = {
	aspect=>[],slope=>[],fdg=>['method=>"D8"'],fill=>[],cut=>[],ucg=>[],
	depressions=>['$fdg'],filldepressions=>['$fdg'],breach=>['$fdg'],
	uag=>['fdg=>$fdg'],dag=>['$fdg']
    };
    $args[1] = {};

    my $dem = new Geo::Raster 'data/dem';

    my $fdg = $dem->fdg(method=>'D8');

    for my $method (keys %{$args[0]}) {
	
	for my $cv (0..$#args) {
	    
	    next unless $args[$cv]->{$method};

	    my @as;
	    for my $a (@{$args[$cv]{$method}}) {
		push @as,$a;
	    }
	    my $arg_list = join(',',@as);
	    
	    for (1,0) {
		my $lvalue = '';
		$lvalue = '$lvalue=' if $_;
		my $eval = "$lvalue\$dem->$method($arg_list);";
#		print "eval: $eval\n";
		eval $eval;
#		print $@;
		exit if $@;
		ok(!$@,$method,$subs);
	    }
	}
    }
    $sub_tests = 0;

    my $streams = new Geo::Raster like=>$fdg;
    $streams->line(10,10,50,50,1);

    $args[0] = {
	fixflats=>['$dem','method=>"one pour point"'],fixpits=>['$dem'],uag=>[''],
	catchment=>[50,50,1],distance_to_pit=>['10'],distance_to_channel=>['$streams','10'],
    };
    $args[1] = {};

    for my $method (keys %{$args[0]}) {
	
	for my $cv (0..$#args) {

	    $fdg = $dem->fdg(method=>'D8');
	    
	    next unless $args[$cv]->{$method};

	    my @as;
	    for my $a (@{$args[$cv]{$method}}) {
		push @as,$a;
	    }
	    my $arg_list = join(',',@as);
	    
	    for (1,0) {
		my $lvalue = '';
		$lvalue = '$lvalue=' if $_;
		my $eval = "$lvalue\$fdg->$method($arg_list);";
		print "eval: $eval\n" if $debug;
		eval $eval;
#		print $@;
		exit if $@;
		ok(!$@,$method,$subs);
	    }
	}
    }

}
#exit;
$sub_tests = 0;

tests_done();

exit;

unless (&Geo::Raster::have_pgplot) {
    print "skipping graphical tests since PGPLOT is not available\n";
    exit;
}

