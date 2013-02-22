#!perl -T

use Test::More tests => 39;
use constant EPS => 1e-3;
use Statistics::Data;
use Array::Compare;

BEGIN {
    use_ok( 'Statistics::Data' ) || print "Bail out!\n";
}

my $dat = Statistics::Data->new();
isa_ok($dat, 'Statistics::Data');

my $cmp_aref = Array::Compare->new;

my ($ret_data, @data1, @data2) = ();

@data1 = (1, 2, 3, 3, 3, 1, 4, 2, 1, 2);
@data2 = (2, 4, 4, 1, 3, 3, 5, 2, 3, 5);
@data1e = (@data1, 'a', 'b');

# TEST load/add/read for each case: case numbers are those in the POD for load() method:

# CASE 1 
eval {$dat->load(@data1);};
ok(!$@, "Error in load: Case 1");
# should be stored as aref labelled 'seq' in the first index of _DATA:
ok(ref $dat->{_DATA}->[0]->{seq} eq 'ARRAY', "Error in load of anonymous data: Case 1: not an aref");
$ret_data = $dat->read();
ok( $cmp_aref->simple_compare(\@data1, $ret_data), 'Error in read after load: Case 1: got '. join('',@$ret_data) );
eval {$dat->add('a', 'b');};
ok(!$@, "Error in add: Case 1");
$ret_data = $dat->read();
ok( $cmp_aref->simple_compare(\@data1e, $ret_data), 'Error in read after add: Case 1: got '. join('',@$ret_data) );

# CASE 2
eval {$dat->load(\@data1);};
ok(!$@, "Error in load: Case 2");
$ret_data = $dat->read();
ok($cmp_aref->simple_compare(\@data1, $ret_data), 'Error in read after load: Case 2: got '. join('',@$ret_data));
eval {$dat->add(['a', 'b']);};
ok(!$@, "Error in add: Case 2");
$ret_data = $dat->read();
ok( $cmp_aref->simple_compare(\@data1e, $ret_data), 'Error in read after add: Case 2: got '. join('',@$ret_data) );
#$dat->unload();

# CASE 3
eval {$dat->load(data => \@data1);};
ok(!$@, "Error in load: Case 3");
# should be stored as aref labelled 'seq' in the first index of _DATA:
ok(ref $dat->{_DATA}->[0]->{seq} eq 'ARRAY', "Error in load of labelled data: Case 3: not an aref");
ok($dat->{_DATA}->[0]->{lab} eq 'data', "Error in load of labelled data: Case 3: not equal to given label");
$ret_data = $dat->read(label => 'data');
ok($cmp_aref->simple_compare(\@data1, $ret_data), 'Error in read after load: Case 3: got '. join('',@$ret_data));
eval {$dat->add(data => ['a', 'b']);};
ok(!$@, "Error in add: Case 3");
$ret_data = $dat->read(label => 'data');
ok( $cmp_aref->simple_compare(\@data1e, $ret_data), 'Error in read after add: Case 3: got '. join('',@$ret_data) );

# CASE 4
eval {$dat->load({ vascular => \@data1});};
ok(!$@, "Error in load: Case 4");
$ret_data = $dat->read(label => 'vascular');
ok($cmp_aref->simple_compare(\@data1, $ret_data), 'Error in read after load: Case 4: got '. join('',@$ret_data));
eval {$dat->add({vascular => ['a', 'b']});};
ok(!$@, "Error in add: Case 4");
$ret_data = $dat->read(label => 'vascular');
ok( $cmp_aref->simple_compare(\@data1e, $ret_data), 'Error in read after add: Case 4: got '. join('',@$ret_data) );

# CASE 5
eval {$dat->load(dist1 => \@data1, dist2 => \@data2);};
ok(!$@, "Error in load: Case 5");
$ret_data = $dat->read(label => 'dist1');
ok($cmp_aref->simple_compare(\@data1, $ret_data), 'Error in read after load: Case 5: got '. join('',@$ret_data));
eval {$dat->add(dist1 => ['a', 'b']);};
ok(!$@, "Error in add: Case 5");
$ret_data = $dat->read(label => 'dist1');
ok( $cmp_aref->simple_compare(\@data1e, $ret_data), 'Error in read after add: Case 5: got '. join('',@$ret_data) );

# CASE 6:
eval {$dat->load({dist1 => \@data1, dist2 => \@data2});};
ok(!$@);
ok($dat->ndata() == 2, "Number of loaded sequences does not equal 2");
$ret_data = $dat->read(label => 'dist1');
ok($cmp_aref->simple_compare(\@data1, $ret_data), 'Error in read after load: Case 6: got '. join('',@$ret_data));
eval {$dat->add(dist1 => ['a', 'b']);};
ok(!$@, "Error in add: Case 6");
$ret_data = $dat->read(label => 'dist1');
ok( $cmp_aref->simple_compare(\@data1e, $ret_data), 'Error in read after add: Case 6: got '. join('',@$ret_data) );

# unload() ok?
eval {$dat->unload();};
ok(!$@, "Error in unload");
ok(!scalar @{$dat->{_DATA}}, 'Error in total unload');

# how about a named unload()?
$dat->load({dist1 => \@data1, dist2 => \@data2});
eval {$dat->unload(label => 'dist1');};
ok(!$@, "Error in unload");
$dat->add('dist1' => ['3']); # should be nothing in there but 3 now
$ret_data = $dat->read(label => 'dist1');
ok( $cmp_aref->simple_compare([3], $ret_data), 'Error in read after unload and add: got '. join('',@$ret_data) );
# - but dist2 should be still okay:
$ret_data = $dat->read(label => 'dist2');
ok( $cmp_aref->simple_compare(\@data2, $ret_data), 'Error in read after unload and add: got '. join('',@$ret_data) );

# does a new load() clobber all prior loads()? (it shouldn't - unless it's named the same, or anonymous)

# lag method:
my @a = (qw/c b b b d a c d b d/);
my @b = (qw/d a a d b a d c c e/);
my $aref = $dat->crosslag(data => [\@a, \@b], lag => 1, loop => 1);
ok($cmp_aref->simple_compare([qw/d c b b b d a c d b/], $aref->[0]), "Error in lag");
ok($cmp_aref->simple_compare(\@b, $aref->[1]), "Error in lag");
$aref = $dat->crosslag(data => [\@a, \@b], lag => 1, loop => 0);
ok($cmp_aref->simple_compare([qw/b b b d a c d b d/], $aref->[0]), "Error in lag");
ok($cmp_aref->simple_compare([qw/d a a d b a d c c/], $aref->[1]), "Error in lag");
#ok(equal($val1, 0), "windowize  $val1 = 0");

sub equal {
    return 1 if $_[0] + EPS > $_[1] and $_[0] - EPS < $_[1];
    return 0;
}
