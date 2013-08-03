#!perl -T

use Test::More tests => 12;
use constant EPS => 1e-3;
use Statistics::Data;
use Array::Compare;

BEGIN {
    use_ok( 'Statistics::Data' ) || print "Bail out!\n";
}

my $dat = Statistics::Data->new();
isa_ok($dat, 'Statistics::Data');

my $cmp_aref = Array::Compare->new;

my ($ret, @data1, @data2) = ();

@data1 = (1, 2, 3, 3, 3, 1, 4, 2, 'x', 2);
@data2 = (2, 4, 4, 1, 3, 3, 5, 2, '', 5);

# using anonymous, unloaded data:
$ret = $dat->all_full(\@data1);
ok($ret == 1, "Error in testing all_full(): Should be 1, is $ret");

$ret = $dat->all_full(\@data2);
ok($ret == 0, "Error in testing all_full(): Should be 0, is $ret");

$ret = $dat->all_numeric(\@data1);
ok($ret == 0, "Error in testing all_numeric(): Should be 0, is $ret");

# using loaded data:
$dat->load(dist1 => [@data1[0 .. 7]]);
$ret = $dat->all_numeric(label => 'dist1');
ok($ret == 1, "Error in testing all_numeric(): Should be 1, is $ret");

$dat->add(dist1 => ['x', 1]);
$ret = $dat->all_numeric(label => 'dist1');
ok($ret == 0, "Error in testing all_numeric(): Should be 0, is $ret");

$ret = $dat->all_numeric(\@data2);
ok($ret == 0, "Error in testing all_numeric(): Should be 0, is $ret");

$ret = $dat->all_proportions(label => 'dist1');
ok($ret == 0, "Error in testing all_proportions(): Should be 0, is $ret");

$dat->load([0, 1]);
$ret = $dat->all_proportions();
ok($ret == 1, "Error in testing all_proportions(): Should be 1, is $ret");

$dat->load([.8, .3, '', .4]);
$ret = $dat->all_proportions();
ok($ret == 0, "Error in testing all_proportions(): Should be 0, is $ret");

$dat->load(dist => [.3, .25, .8]);
$ret = $dat->all_proportions(label => 'dist');
ok($ret == 1, "Error in testing all_proportions(): Should be 1, is $ret");

sub equal {
    return 0 if ! defined $_[0] || ! defined $_[1];
    return 1 if $_[0] + EPS > $_[1] and $_[0] - EPS < $_[1];
    return 0;
}
