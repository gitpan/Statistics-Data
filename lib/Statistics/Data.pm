package Statistics::Data;
use strict;
use warnings FATAL => 'all';
use Carp qw(croak);
use List::AllUtils qw(all);
use Number::Misc qw(is_even);
use String::Util qw(hascontent nocontent);
our $VERSION = '0.06';

=head1 NAME

Statistics::Data - Manage loading, accessing, updating one or more sequences of data for statistical analysis

=head1 VERSION

This is documentation for Version 0.06 of Statistics/Data.pm, released August 2013.

=head1 SYNOPSIS

 use Statistics::Data 0.06;
 my $dat = Statistics::Data->new();
 
 # With labelled sequences:
 $dat->load({'aname' => \@data1, 'anothername' => \@data2}); # labels are arbitrary
 $aref = $dat->access(label => 'aname'); # gets back a copy of @data1
 $dat->add(aname => [2, 3]); # pushes new values onto loaded copy of @data1
 $dat->dump_list(); # print to check if both arrays are loaded and their number of elements
 $dat->unload(label => 'anothername'); # only 'aname' data remains loaded
 $aref = $dat->access(label => 'aname'); # $aref is a reference to a copy of @data1
 $dat->dump_vals(label => 'aname', delim => ','); # proof in print it's back 
 
 # With multiple anonymous sequences:
 $dat->load(\@data1, \@data2); # any number of anonymous arrays
 $dat->add([2], [6]); # pushes a single value apiece onto copies of @data1 and @data2
 $aref = $dat->access(index => 1); # returns reference to copy of @data2, with its new values
 $dat->unload(index => 0); # only @data2 remains loaded, and its index is now 0

 # With a single anonymous data sequence:
 $dat->load(1, 2, 2);
 $dat->add(1); # loaded sequence is now 1, 2, 2, 1
 $dat->dump_vals(); # same as: print @{$dat->access()}, "\n";
 $dat->unload(); # all gone

=head1 DESCRIPTION

Handles data for some other statistics modules, as in loading, updating and retrieving data for analysis. Performs no actual statistical analysis itself.

Rationale is not wanting to write the same or similar load, add, etc. methods for every statistics module, not to provide an omnibus API for Perl stat modules. It, however, encompasses much of the variety of how Perl stats modules do the basic handling their data. Used for L<Statistics::Sequences|Statistics::Sequences> (and its sub-tests). 

=head1 SUBROUTINES/METHODS

The basics aims/rules/behaviors of the methods have been/are as described in the L<RATIONALE|Statistics::Data/RATIONALE> section, below. The possibilities are many, but, to wrap up: any loaded/added sequence of data ends up cached within the class object's '_DATA' aref as an aref itself. Optionally (but preferably), this sequence is associated with a 'label', i.e., a stringy name, if it's been loaded/added as such. The sequences can be updated or retrieved according to the order in which they were loaded/added (by index) or (preferably) its 'label'. In this way, any particular statistical method (e.g., to calculate the number of runs in the sequence, as in L<Statistics::Sequences::Runs|Statistics::Sequences::Runs>), can refer to the 'index' or 'label' of the sequence to do its analysis upon - or it can still use its own rules to select the appropriate sequence, or provide the appropriate sequence within the call to itself. The particular data structures supported here to load, update, retrieve, unload data are specified under L<load|Statistics::Data/load>.

=head2 new

 $dat = Statistics::Data->new();

Returns a new Statistics::Data object.

=cut

sub new {
    my $class = shift;
    my $self = bless {}, ref($class) ? ref($class) : $class;
    $self->{_DATA} = [];
    return $self;
}

=head2 copy

 $seq2 = $dat->copy();

I<Alias>: B<clone>

Returns a copy of the class object with its data loaded (if any). Note this is not a copy of any particular data but the whole blessed hash. Alternatively, use L<pass|Statistics::Data/pass> to get all the data added to a new object, or use L<access|Statistics::Data/access> to load/add particular sequences into another object. Nothing modified in this new object affects the original.

=cut

sub copy {
    my $self = shift;
    my $copy = (ref $self)->new;
    $copy->load(@{$self->{_DATA}});
    return $copy;
}
*clone = \*copy;

=head2 load

 $dat->load(@data);             # CASE 1 - can be updated/retrieved anonymously, or as index => i (load order)
 $dat->load(\@data);            # CASE 2 - same, as aref
 $dat->load(data => \@data);    # CASE 3 - updated/retrieved as label => 'data' (arbitrary name, not just 'data'); or by index (order)
 $dat->load({ data => \@data }) # CASE 4 - same as CASE 4, as hashref
 $dat->load(blues => \@blue_data, reds => \@red_data);      # CASE 5 - same as CASE 3 but with multiple named loads
 $dat->load({ blues => \@blue_data, reds => \@red_data });  # CASE 6 - same as CASE 5 bu as hashref
 $dat->load(\@blue_data, \@red_data);  # CASE 7 - same as CASE 2 but with multiple aref loads

 # Not supported:
 #$dat->load(data => @data); # not OK - use CASE 3 instead
 #$dat->load([\@blue_data, \@red_data]); # not OK - use CASE 7 instead
 #$dat->load([ [blues => \@blue_data], [reds => \@red_data] ]); # not OK - use CASE 5 or CASE 6 instead
 #$dat->load(blues => \@blue_data, reds => [\@red_data1, \@red_data2]); # not OK - too mixed to make sense

I<Alias>: B<load_data>

Cache a list of data as an array-reference. Each call removes previous loads, as does sending nothing. If data need to be cached without unloading previous loads, try L<add|Statistics::Data/add>. Arguments with the following structures are acceptable as data, and will be L<access|Statistics::Data/access>ible by either index or label as expected:

=over 4

=item load ARRAY

Load an anonymous array that has no named values. For example:

 $dat->load(1, 4, 7);
 $dat->load(@ari);

This is loaded as a single sequence, with an undefined label, and indexed as 0. Note that trying to load a labelled dataset with an unreferenced array is wrong for it will be treated like this case - the label will be "folded" into the sequence itself:

 $dat->load('dist' => 3); # no croak but not ok! 

=item load AREF

Load a reference to a single anonymous array that has no named values, e.g.: 

 $dat->load([1, 4, 7]);
 $dat->load(\@ari);

This is loaded as a single sequence, with an undefined label, and indexed as 0.

=item load ARRAY of AREF(s)

Same as above, but note that more than one unlabelled array-reference can also be loaded at once, e.g.:

 $dat->load([1, 4, 7], [2, 5, 9]);
 $dat->load(\@ari1, \@ari2);

Each sequence can be accessed, using L<access|Statistics::Data/access>, by specifying B<index> => index, the latter value representing the order in which these arrays were loaded.

=item load HASH of AREF(s)

Load one or more labelled references to arrays, e.g.:

 $dat->load('dist1' => [1, 4, 7]);
 $dat->load('dist1' => [1, 4, 7], 'dist2' => [2, 5, 9]);

This loads the sequence(s) with a label attribute, so that when calling L<access|Statistics::Data/access>, they can be retrieved by name, e.g., passing B<label> => 'dist1'. The load method involves a check that there is an even number of arguments, and that, if this really is a hash, all the keys are defined and not empty, and all the values are in fact array-references.

=item load HASHREF of AREF(s)

As above, but where the hash is referenced, e.g.:

 $dat->load({'dist1' => [1, 4, 7], 'dist2' => [2, 5, 9]});

=back

This means that using the following forms will produce unexpected results, if they do not actually croak, and so should not be used:

 $dat->load(data => @data); # no croak but wrong - puts "data" in @data - use \@data
 $dat->load([\@blue_data, \@red_data]); # use unreferenced ARRAY of AREFs instead
 $dat->load([ [blues => \@blue_data], [reds => \@red_data] ]); # treated as single AREF; use HASH of AREFs instead
 $dat->load(blues => \@blue_data, reds => [\@red_data1, \@red_data2]); # mixed structures not supported

=cut

sub load { # load single aref: cannot load more than one sequence; keeps a direct reference to the data: any edits creep back.
    my ($self, @args) = @_;
    $self->unload();
    $self->add(@args);
    return 1;
}
*load_data = \&load;

=head2 add

I<Alias>: B<add_data>, B<append_data>, B<update>

Same usage as shown above for L<load|Statistics::Data/load>. Just push any value(s) or so along, or loads an entirely labelled sequence, without clobbering what's already in there (as L<load|Statistics::Data/load> would). If data have not been loaded with a label, then appending data to them happens according to the order of array-refs set here, see L<EXAMPLES|EXAMPLES> could even skip adding something to one previously loaded sequence by, e.g., going $dat->add([], \new_data) - adding nothing to the first loaded sequence, and initialising a second array, if none already, or appending these data to it.

=cut

sub add {
    my ($self, @args) = @_;
    my $tmp = _init_data($self, @args); # hashref of data sequence(s) keyed by index to use for loading or adding
    while (my($key, $val) = each %{$tmp}) {
        if (defined $val->{'lab'}) { # newly labelled data
            $self->{_DATA}->[$key] = {seq => $val->{'seq'}, lab => $val->{'lab'}};
        }
        else { # data to be added to existing cache, or an anonymous load, indexed only
            push @{$self->{_DATA}->[$key]->{seq}}, @{$val->{'seq'}};
        }
    }
    return 1;
}
*add_data = \&add;
*append_data = \&add;
*update = \&add;

=head2 access

 $aref = $dat->access(); #returns the first and/or only sequence anonymously loaded, if any
 $aref = $dat->access(index => integer); #returns the ith sequence anonymously loaded
 $aref = $dat->access(label => 'a_name'); # returns a particular named cache of data

I<Alias>: B<get_data>

Return the data that have been loaded/added to. Only one access of a single sequence at a time; just tries to get 'data' if no 'label' is given or the given 'label' does not exist. If this fails, a croak is given.

=cut

sub access {
    my ($self, @args) = @_;
    my $i = !$args[0] ? 0 : _index_by_args($self, @args);
    if (defined $i and ref $self->{_DATA}->[$i]->{seq}) {
       return $self->{_DATA}->[$i]->{seq};
    }
    else {
       croak __PACKAGE__, '::access Data for accessing need to be loaded';
    }
}
*read = \&access; # legacy only
*get_data = \&access;

=head2 unload

 $dat->unload(); # deletes all cached data, named or not
 $dat->unload(index => integer); # deletes the aref named 'data' whatever
 $dat->unload(label => 'a name'); # deletes the aref named 'data' whatever

Empty, clear, clobber what's in there. Croaks if given index or label does not refer to any loaded data. This should be used whenever any already loaded or added data are no longer required ahead of another L<add|Statistics::Data/add>, including via L<copy|Statistics::Data/copy> or L<share|Statistics::Data/share>.

=cut

sub unload {
    my ($self, @args) = @_;
    if (!$args[0]) {
        $self->{_DATA} = [];
    }
    else {
        my $i = _index_by_args($self, @args);
        if (defined $i and ref $self->{_DATA}->[$i]) {
            splice @{$self->{_DATA}}, $i, 1;
        }
        else {
            croak __PACKAGE__, '::unload Data for unloading need to be loaded';
        }
    }
    return 1;
}

=head2 share

 $dat_new->share($dat_old);

I<Aliases>: B<pass>, B<import>

Adds all the data from one Statistics::Data object to another. Changes in the new copies do not affect the originals.

=cut

sub share {
    my ($self, $other) = @_;
    _add_from_object_aref($self, $other->{_DATA});
    return 1;
}
*pass = \&share;
*import = \&share;

=head2 ndata

 $n = $self->ndata();

Returns the number of loaded data sequences.

=cut

sub ndata {
    my $self = shift;
    return scalar(@{$self->{'_DATA'}});
}

=head2 all_full

 $bool = $dat->all_full(\@data); # test data are valid before loading them
 $bool = $dat->all_full(label => 'mydata'); # checking after loading/adding the data (or key in 'index')

Checks not only if the data sequence, as named or indexed, exists, but if it is non-empty: has no empty elements, with any elements that might exist in there being checked with L<hascontent|String::Util/hascontent>.

=cut

sub all_full {
    my ($self, @args) = @_;
    my $data = ref $args[0] ? shift @args: $self->access(@args);
    foreach (@{$data}) {
        return 0 if nocontent($_);
    }
    return 1;
}

=head2 all_numeric

 $bool = $dat->all_numeric(\@data); # test data are valid before loading them
 $bool = $dat->all_numeric(label => 'mydata'); # checking after loading/adding the data (or key in 'index')

Ensure data are all numerical, using C<looks_like_number> in L<Scalar::Util|Scalar::Util/looks_like_number>.

=cut

sub all_numeric {
    my ($self, @args) = @_;
    my $data = ref $args[0] ? shift @args: $self->access(@args);
    require Scalar::Util;
    my $ret = 0;
    foreach (@{$data}) {
        $ret =  (nocontent($_) or not Scalar::Util::looks_like_number($_)) ? 0 : 1;
        last if $ret == 0;
    }
    return $ret;
}
*all_numerical = \&all_numeric;

=head2 all_proportions

 $bool = $dat->all_proportions(\@data); # test data are valid before loading them
 $bool = $dat->all_proportions(label => 'mydata'); # checking after loading/adding the data  (or key in 'index')

Ensure data are all proportions. Sometimes, the data a module needs are all proportions, ranging from 0 to 1 inclusive. A dataset might have to be cleaned 

=cut

sub all_proportions {
    my ($self, @args) = @_;
    my $data = ref $args[0] ? shift @args: $self->access(@args);
    require Scalar::Util;
    my $ret = 0;
    foreach (@{$data}) {
        if (nocontent($_)) {
            $ret = 0;
        }
        elsif (Scalar::Util::looks_like_number($_)) {
            $ret = ( $_ < 0 || $_ > 1 ) ? 0 : 1;
        }
        last if $ret == 0;
    }
    return $ret;
}

=head2 dump_vals

 $seq->dump_vals(delim => ", "); # assumes the first (only?) loaded sequence should be dumped
 $seq->dump_vals(index => I<int>, delim => ", "); # dump the i'th loaded sequence
 $seq->dump_vals(label => 'mysequence', delim => ", "); # dump the sequence loaded/added with the given "label"

Prints to STDOUT a space-separated line (ending with "\n") of a loaded/added data's elements. Optionally, give a value for B<delim> to specify how the elements in each sequence should be separated; default is a single space.

=cut

sub dump_vals {
    my ($self, @args) = @_;
    my $args = ref $args[0] ? $args[0] : {@args};
    my $delim = $args->{'delim'} || q{ };
    print join($delim, @{$self->access($args)}), "\n" or croak 'Could not print line to STDOUT';
    return 1;
}
*dump_line = \&dump_vals; # legacy only
*dump_data = \&dump_vals; # legacy only

=head2 dump_list

Dumps a list (using L<Text::SimpleTable|Text::SimpleTable>) of the data currently loaded, without showing their actual elements. List is firstly by index, then by label (if any), then gives the number of elements in the associated sequence.

=cut

sub dump_list {
    my ($self, $i, $lim, $lab, $N, $len_lab, $len_n, $tbl, @rows, @maxlens) = (shift);
    $lim = $self->ndata();
    @maxlens = (($lim > 5 ? $lim : 5), 5, 1);
    for my $i(0 .. $lim - 1) {
        $lab = defined $self->{_DATA}->[$i]->{lab} ? $self->{_DATA}->[$i]->{lab} : q{-};
        $N = scalar @{$self->{_DATA}->[$i]->{seq}};
        $len_lab = length $lab;
        $len_n = length $N;
        $maxlens[1] = $len_lab if $len_lab > $maxlens[1];
        $maxlens[2] = $len_n if $len_n > $maxlens[2];
        $rows[$i] = [$i, $lab, $N];
    }
    require Text::SimpleTable;
    $tbl = Text::SimpleTable->new([$maxlens[0], 'index'], [$maxlens[1], 'label'], [$maxlens[2], 'N']);
    $tbl->row(@{$_}) foreach @rows;
    print $tbl->draw or croak 'Could not print list of loaded data';
    return 1;
}
*list = \&dump_list; # legacy only
*list_data = \&dump_list; # legacy only

=head2 save_to_file

  $dat->save_to_file(path => 'mysequences.csv');
  $dat->save_to_file(path => 'mysequences.csv', serializer => 'XML::Simple', compress => 1, secret => '123'); # serialization options

Saves the data presently loaded in the Statistics::Data object to a file, with the given B<path>. This can be retrieved, with all the data added to the Statistics::Data object, via L<load_from_file|Statistics::Data/load_from_file>. Basically a wrapper to C<store> method in L<Data::Serializer|Data::Serializer/store>; cf. for options.

=cut

sub save_to_file {
    my ($self, @args) = @_;
    my $args = ref $args[0] ? $args[0] : {@args};
    croak 'There is no path for saving data' if nocontent($args->{'path'});
    require Data::Serializer;
    my $serializer = Data::Serializer->new(%{$args});
    $serializer->store({DATA => $self->{_DATA}}, $args->{'path'} );
    return 1;
}
*save = \&save_to_file;

=head2 load_from_file

 $dat->load_from_file(path => 'medata.csv', format => 'xml|csv');
 $dat->load_from_file(path => 'mysequences.csv', serializer => 'XML::Simple', compress => 1, secret => '123'); # serialization options

Loads data from a file, assuming there are data in the given path that have been saved in the format used in L<save_to_file|Statistics::Data/save_to_file>. Basically a wrapper to C<retrieve> method in L<Data::Serializer|Data::Serializer/retrieve>; cf. for options; and then to L<load|Statistics::Data/load>. If the data retreived are actually to be added to any data already cached via a previous load or add, define the optional parameter B<keep> => 1.

=cut

sub load_from_file {
    my ($self, @args) = @_;
    my $args = ref $args[0] ? $args[0] : {@args};
    croak 'There is no path for loading data' if nocontent($args->{'path'}) || !-e $args->{'path'}; # is filepath valid?
    require Data::Serializer;
    my $serializer = Data::Serializer->new(%{$args});
    my $href = $serializer->retrieve($args->{'path'});
    $self->unload() unless $args->{'keep'};
    _add_from_object_aref($self, $href->{DATA});
    return 1;
}
*open = \&load_from_file; # legacy only

# PRIVATMETHODEN:

sub _init_data {
    my ($self, @args) = @_;
    my $tmp = {};
    if (_isa_hashref_of_arefs($args[0]) ) { # cases 4 & 6
        $tmp = _init_labelled_data($self, $args[0]);
    }
    elsif (_isa_hash_of_arefs(@args)) { # cases 3 & 5
        $tmp = _init_labelled_data($self, {@args});
    }
    elsif (_isa_array_of_arefs(@args)) { # case 2 & 7
        $tmp = _init_unlabelled_data(@args);
    }
    elsif (ref $args[0]) {
        croak 'Don\'t know how to load/add data';
    }
    else { # case 1
        $tmp->{0} = {seq => [@args], lab => undef};
    }
    return $tmp;
}

sub _isa_hashref_of_arefs {
    my $arg = shift;
    if ( not ref $arg or ref $arg ne 'HASH') {
        return 0;
    }
    else {
        return _isa_hash_of_arefs(%{$arg});
    }
}

sub _isa_hash_of_arefs {
    # determines that:
    # - scalar @args passes Number::Misc is_even, then that:
    # - every odd indexed value 'hascontent' via String::Util
    # - every even indexed value is aref
    my @args = @_;
    my $ret = 0;
    if (is_even(scalar @args)) { # Number::Misc method - not odd number in assignment
        my %args = @args; # so assume is hash
        HASHCHECK:
        while ( my ($lab, $val) = each %args ) { # print "lab = $lab, val = $val\n";
            if ( hascontent($lab) && ref $val eq 'ARRAY' ) {
                $ret = 1;
            }
            else {
                $ret = 0;
            }
            last HASHCHECK if $ret == 0;
        }
    }
    else {
        $ret = 0;
    }
    return $ret;
}

sub _isa_array_of_arefs {
    my @args = @_;
    if ( all { ref($_) eq 'ARRAY' } @args ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub _init_labelled_data {
    my ($self, $href) = @_;
    my ($i, %tmp) = (scalar @{$self->{_DATA}});
    while ( my($lab, $seq) = each %{$href}) {
        my $j = _seq_index_by_label($self, $lab);
        if (defined $j) { # there is already a label for these data, so don't need to define it for this init
            $tmp{$j} = {seq => [@{$seq}], lab => undef};
        }
        else {# no aref labelled $lab yet: define for seq and label
            print "init lab = $lab seq = $seq\n";
            $tmp{$i++} = {seq => [@{$seq}], lab => $lab};
        }
    }
    return \%tmp;
}

sub _init_unlabelled_data {
    my @args = @_;
    my %tmp = ();
    for my $i(0 .. scalar @args - 1) {
        $tmp{$i} = {seq => [@{$args[$i]}], lab => undef};
    }
    return \%tmp;
}

sub _index_by_args {
    my ($self, @args) = @_;
    my $args = ref $args[0] ? $args[0] : {@args};
    my $i;
    if (hascontent($args->{'index'})) {
        $i = $args->{'index'};
    }
    elsif (hascontent($args->{'label'})) {
        $i = _seq_index_by_label($self, $args->{'label'});
    }
    else {
        $i = 0;
    }
    return $i;
}

sub _seq_index_by_label {
    my ($self, $label, $i, $k) = @_;
    for ($i = 0; $i < scalar(@{$self->{_DATA}}); $i++) {
        do {$k++; last;} if $self->{_DATA}->[$i]->{lab} and $self->{_DATA}->[$i]->{lab} eq $label;
    }
    return $k ? $i : undef;
}

sub _add_from_object_aref {
    my ($self, $aref) = @_;
    foreach my $dat(@{$aref}) {
        if (hascontent($dat->{'lab'})) {
            $self->add($dat->{'lab'} => $dat->{'seq'});
        }
        else {
            $self->add($dat->{'seq'});
        }
    }
    return 1;
}

=head1 EXAMPLES

B<1. Multivariate data (a tale of horny frogs)>

In a study of how doing mental arithmetic affects arousal in self and others (i.e., how mind, body and world interact), three male frogs were maths-trained and then, as they did their calculations, were measured for pupillary dilation and perceived attractiveness. After four runs, average measures per frog can be loaded: 

 $frogs->load(Names => [qw/Freddo Kermit Larry/], Pupil => [59.2, 77.7, 56.1], Attract => [3.11, 8.79, 6.99]);

But one more frog still had to graudate from training, and data are now ready for loading:

 $frogs->add(Names => ['Sleepy'], Pupil => [83.4], Attract => [5.30]);
 $frogs->dump_data(label => 'Pupil'); # prints "59.2 77.7 56.1 83.4" : all 4 frogs' pupil data for analysis by some module

Say we're finished testing for now, so:

 $frogs->save_to_file(path => 'frogs.csv');
 $frogs->unload();

But another frog has been trained, measures taken:

 $frogs->load_from_file(path => 'frogs.csv');
 $frogs->add(Pupil => [93], Attract => [6.47], Names => ['Jack']); # add yet another frog's data
 $frogs->dump_data(label => 'Pupil'); # prints "59.2 77.7 56.1 83.4 93": all 5 frogs' pupil data

Now we run another experiment, taking measures of heart-rate, and can add them to the current load of data for analysis:

 $frogs->add(Heartrate => [.70, .50, .44, .67, .66]); # add entire new sequence for all frogs
 print "heartrate data are bung" if ! $frogs->all_proportions(label => 'Heartrate'); # validity check (could do before add)
 $frogs->dump_list(); # see all four data-sequences now loaded, each with 5 observations (1 per frog), i.e.:
 .-------+-----------+----.
 | index | label     | N  |
 +-------+-----------+----+
 | 0     | Names     | 5  |
 | 1     | Attract   | 5  |
 | 2     | Pupil     | 5  |
 | 3     | Heartrate | 5  |
 '-------+-----------+----'

B<2. Using as a base module>

As L<Statistics::Sequences|Statistics::Sequences>, and so its sub-modules, use this module as their base, it doesn't have to do much data-managing itself:

 use Statistics::Sequences;
 my $seq = Statistics::Sequences->new();
 $seq->load(qw/f b f b b/); # using Statistics::Data method
 say $seq->p_value(stat => 'runs', exact => 1); # using Statistics::Sequences::Runs method

Or if these data were loaded directly within Statistics::Data, the data can be shared around modules that use it as a base:

 use Statistics::Data;
 use Statistics::Sequences::Runs;
 my $dat = Statistics::Data->new();
 my $runs = Statistics::Sequences::Runs->new();
 $dat->load(qw/f b f b b/);
 $runs->pass($dat);
 say $runs->p_value(exact => 1);

=head1 DIAGNOSTICS

=over 4

=item Don't know how to load/add data

Croaked when attempting to load or add data with an unsupported data structure where the first argument is a reference. See the examples under L<load|Statistics::Data/load> for valid (and invalid) ways of sending data to them.

=item Data for accessing need to be loaded

Croaked when calling L<access|Statistics::Data/access>, or any methods that use it internally -- viz., L<dump_vals|Statistics::Data/dump_vals> and the validity checks L<all_numeric|Statistics::Data/all_numeric> -- when it is called with a label for data that have not been loaded, or did not load successfully.

=item Data for unloading need to be loaded

Croaked when calling L<unload|Statistics::Data/unload> with an index or a label attribute and the data these refer to have not been loaded, or did not load successfully.

=item There is no path for saving (or loading) data

Croaked when calling L<save_to_file|Statistics::Data/save_to_file> or L<load_from_file|Statistics::Data/load_from_file> without a value for the required B<path> argument, or if (when loading from it) it does not exist.

=back

=head1 DEPENDENCIES

L<List::AllUtils|List::AllUtils> - used for its C<all> method when testing loads

L<Number::Misc|Number::Misc> - used for its C<is_even> method when testing loads

L<String::Util|String::Util> - used for its C<hascontent> and C<nocontent> methods

L<Data::Serializer|Data::Serializer> - required for L<save_to_file|Statistics::Data/save_to_file> and L<load_from_file|Statistics::Data/load_from_file>

L<Scalar::Util|Scalar::Util> - required for L<all_numeric|Statistics::Data/all_numeric>

L<Text::SimpleTable|Text::SimpleTable> - required for L<dump_list|Statistics::Data/dump_list>

=head1 RATIONALE

The basics aims/rules/behaviors of all the methods have been/are to: 

=over 4

=item lump data as arefs into the class object

That's sequences in general, without discriminating at the outset between continuous/numeric or categorical/nominal/stringy data - because the stats methods themselves don't matter here. The point is to make these things available for modular statistical analysis without having to worry about all the loading, adding, accessing, etc. within the same package. No other information is cached, not whether they've been analysed, updated ... - just the arefs themselves. Maybe later versions could distinguish data from other info, but for now, that's all left up to the stat analysis modules themselves.

=item handle multiple arefs

That's much of the crux of having a Statistics::Data object, or making any stats object - otherwise, they'd just use a module from the Data or List families to handle the data. Also because many Perl stats modules have found it useful to have this functionality - rather than managing multiple objects. 

=item distinguish between handling whole sequences or just their elements

To add_data in most stats modules is to append (push) values to an existing aref, and same thing for deleting data. Some do this just for the single sequence they cache, others by naming particular sequences to append values to, delete values from. But sometimes it's useful to add a whole new sequence without clobbering what was already in there as data, or delete one or more (but not all) sequences already loaded; e.g., some stats modules find it useful to load/add to/delete sequences in multiple separate calls: L<Statistics::DependantTTest|Statistics::DependantTTest>, L<Statistics::KruskalWallis|Statistics::KruskalWallis>, L<Statistics::LogRank|Statistics::LogRank>. That's taken here as a matter of loading and unloading, not adding and deleting.

=item handle named arefs

That's both hashes of arefs, and hashrefs of arefs. This is already useful for L<Statistics::ANOVA|Statistics::ANOVA> and L<Statistics::FisherPitman|Statistics::FisherPitman> - loaded/added to in single calls. There's also the case of having one or more named sequences (arefs) to have multiple sequences attached to them - e.g., when testing for a match of one "target" sequence to one or more "response" sequences; not implemented here, but the existing methods should be able to readily serve up such things.

=item handle anonymous data

If there's only ever a single sequence of data to analyse by a stats module (such as in L<Statistics::Autocorrelation|Statistics::Autocorrelation> and L<Statistics::Sequences|Statistics::Sequences>), then naming them, and getting at them by names, might be inconvenient. There should also be support for multiple anonymous loads, which would be accessed by index (order of load) (modules L<Statistics::ChisqIndep|Statistics::ChisqIndep> and L<Statistics::TTest|Statistics::TTest> have found this useful). Still, providing this functionality has meant (so far) not keying data by any label, only storing the label within an anonymous hash, alongside the data.

=item ample aliases

Perl stats modules use a wide variety of names for performing the same or similar data-handling operations within them; e.g., a load in one is an add in another which is really an update in yet another. So the methods here have several aliases representing method names used in other modules.

=item easy, obvious adoption by other modules of the methods

The modules that use this one simply make themselves "based" on it, and they're always free to define their own load, access, etc. methods.

=back

=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to C<bug-statistics-data-0.01 at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Statistics-Data-0.01>. This will notify the author, and then you'll automatically be notified of progress on your bug as any changes are made.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Statistics::Data

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Statistics-Data-0.06>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Statistics-Data-0.06>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Statistics-Data-0.06>

=item * Search CPAN

L<http://search.cpan.org/dist/Statistics-Data-0.06/>

=back

=head1 AUTHOR

Roderick Garton, C<< <rgarton at cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2009-2013 Roderick Garton

This program is free software; you can redistribute it and/or modify it under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License. See L<perl.org/licenses|http://dev.perl.org/licenses/> for more information.

=cut

1; # End of Statistics::Data
