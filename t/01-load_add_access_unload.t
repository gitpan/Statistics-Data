#!perl -T

use Test::More tests => 41;
use constant EPS => 1e-3;
use Statistics::Data;
use Array::Compare;

BEGIN {
    use_ok( 'Statistics::Data' ) || print "Bail out!\n";
}

my $dat = Statistics::Data->new();
isa_ok($dat, 'Statistics::Data');

my $cmp_aref = Array::Compare->new;

my ($ret_data, @data1, @data2, @data1e) = ();

@data1 = (1, 2, 3, 3, 3, 1, 4, 2, 1, 2);
@data2 = (2, 4, 4, 1, 3, 3, 5, 2, 3, 5);
@data1e = (@data1, 'a', 'b');

# TEST load/add/access for each case: case numbers are those in the POD for load() method:

# CASE 1 
eval {$dat->load(@data1);};
ok(!$@, "Error in load: Case 1");
# should be stored as aref labelled 'seq' in the first index of _DATA:
ok(ref $dat->{_DATA}->[0]->{seq} eq 'ARRAY', "Error in load of anonymous data: Case 1: not an aref");
$ret_data = $dat->access();
ok( $cmp_aref->simple_compare(\@data1, $ret_data), 'Error in access after load: Case 1: got '. join('',@$ret_data) );
eval {$dat->add('a', 'b');};
ok(!$@, "Error in add: Case 1");
$ret_data = $dat->access();
ok( $cmp_aref->simple_compare(\@data1e, $ret_data), 'Error in access after add: Case 1: got '. join('',@$ret_data) );

# CASE 2
eval {$dat->load(\@data1);};
ok(!$@, "Error in load: Case 2");
$ret_data = $dat->access();
ok($cmp_aref->simple_compare(\@data1, $ret_data), 'Error in access after load: Case 2: got '. join('',@$ret_data));
eval {$dat->add(['a', 'b']);};
ok(!$@, "Error in add: Case 2");
$ret_data = $dat->access();
ok( $cmp_aref->simple_compare(\@data1e, $ret_data), 'Error in access after add: Case 2: got '. join('',@$ret_data) );
#$dat->unload();

# CASE 3
eval {$dat->load(data => \@data1);};
ok(!$@, "Error in load: Case 3");
# should be stored as aref labelled 'seq' in the first index of _DATA:
ok(ref $dat->{_DATA}->[0]->{seq} eq 'ARRAY', "Error in load of labelled data: Case 3: not an aref");
ok($dat->{_DATA}->[0]->{lab} eq 'data', "Error in load of labelled data: Case 3: not equal to given label");
$ret_data = $dat->access(label => 'data');
ok($cmp_aref->simple_compare(\@data1, $ret_data), 'Error in access after load: Case 3: got '. join('',@$ret_data));
eval {$dat->add(data => ['a', 'b']);};
ok(!$@, "Error in add: Case 3");
$ret_data = $dat->access(label => 'data');
ok( $cmp_aref->simple_compare(\@data1e, $ret_data), 'Error in access after add: Case 3: got '. join('',@$ret_data) );

# CASE 4
eval {$dat->load({ vascular => \@data1});};
ok(!$@, "Error in load: Case 4");
$ret_data = $dat->access(label => 'vascular');
ok($cmp_aref->simple_compare(\@data1, $ret_data), 'Error in access after load: Case 4: got '. join('',@$ret_data));
eval {$dat->add({vascular => ['a', 'b']});};
ok(!$@, "Error in add: Case 4");
$ret_data = $dat->access(label => 'vascular');
ok( $cmp_aref->simple_compare(\@data1e, $ret_data), 'Error in access after add: Case 4: got '. join('',@$ret_data) );

# CASE 5
eval {$dat->load(dist1 => \@data1, dist2 => \@data2);};
ok(!$@, "Error in load: Case 5");
my $num = $dat->ndata();
ok($num == 2, "Error in load of multiple data by hash: Should be two sequences, got $num");
$ret_data = $dat->access(label => 'dist1');
ok($cmp_aref->simple_compare(\@data1, $ret_data), 'Error in access after load: Case 5: got '. join('',@$ret_data));
eval {$dat->add(dist1 => ['a', 'b']);};
ok(!$@, "Error in add: Case 5");
$ret_data = $dat->access(label => 'dist1');
ok( $cmp_aref->simple_compare(\@data1e, $ret_data), 'Error in access after add: Case 5: got '. join('',@$ret_data) );

# CASE 6:
eval {$dat->load({dist1 => \@data1, dist2 => \@data2});};
ok(!$@);
$num = $dat->ndata();
ok($num == 2, "Error in load of multiple data by hashref: Should be two sequences, got $num");
$ret_data = $dat->access(label => 'dist1');
ok($cmp_aref->simple_compare(\@data1, $ret_data), 'Error in access after load: Case 6: got '. join('',@$ret_data));
eval {$dat->add(dist1 => ['a', 'b']);};
ok(!$@, "Error in add: Case 6");
$ret_data = $dat->access(label => 'dist1');
ok( $cmp_aref->simple_compare(\@data1e, $ret_data), 'Error in access after add: Case 6: got '. join('',@$ret_data) );

# unload() test:
eval {$dat->unload();};
ok(!$@, "Error in unload");
ok(!scalar @{$dat->{_DATA}}, 'Error in total unload');
ok($dat->ndata() == 0, "Error in unload - Number of loaded sequences does not equal 0");

# - named unload()
$dat->load({dist1 => \@data1, dist2 => \@data2});
eval {$dat->unload(label => 'dist1');};
ok(!$@, "Error in unload");
ok($dat->ndata() == 1, "Number of loaded sequences does not equal 1 after unload()");
$dat->add('dist1' => ['3']); # should be nothing in there but 3 now
ok($dat->ndata() == 2, "Number of loaded sequences does not equal 2 after add()");
$ret_data = $dat->access(label => 'dist1');
ok( $cmp_aref->simple_compare([3], $ret_data), 'Error in access after unload and add: got '. join('',@$ret_data) );
# - but dist2 should be still okay:
$ret_data = $dat->access(label => 'dist2');
ok( $cmp_aref->simple_compare(\@data2, $ret_data), 'Error in access after unload and add: got '. join('',@$ret_data) );

# share()
my $dat_new = Statistics::Data->new();
$dat_new->share($dat);
ok($dat_new->ndata() == 2, "Number of loaded sequences does not equal 2 after share()");
$ret_data = $dat_new->access(label => 'dist2');
ok( $cmp_aref->simple_compare(\@data2, $ret_data), 'Error in access after share(): got '. join('',@$ret_data) );


# does a new load() clobber all prior loads()? (it shouldn't - unless it's named the same, or anonymous)

sub equal {
    return 1 if $_[0] + EPS > $_[1] and $_[0] - EPS < $_[1];
    return 0;
}
