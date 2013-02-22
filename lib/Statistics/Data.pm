package Statistics::Data;
use strict;
use warnings FATAL => 'all';
use Carp qw(croak);
use Data::Serializer;
use List::AllUtils qw(all); # the fn 'all', not "all fns"
use String::Util qw(hascontent nocontent);

our $VERSION = '0.01';

=head1 NAME

Statistics-Data - Manage loading, reading, updating, storing, etc. one or more sequences of data for statistical analysis

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

Statistics-Data - Load, update, delete data for use by several Statistics modules

 use Statistics::Data;
 my $dat = Statistics::Data->new();
 
 # With labelled sequences (recommended):
 $dat->load({'aname' => \@data1, 'anothername' => \@data2}); # labels are arbitrary
 $aref = $dat->read(label => 'aname'); # gets back a copy of @data1
 $dat->add(aname => [2, 3]); # pushes new values onto loaded copy of @data1
 $dat->dump_list(); # check if both arrays are loaded and their number of elements
 $dat->unload(label => 'anothername'); # only 'aname' data remains loaded
 $aref = $dat->read(label => 'aname'); # $aref is a reference to a copy of @data1
 $dat->save(path => 'aname.dat'); # with optional serializer options, eg "encrypt"
 $dat->unload(); # all gone, but wait ...!
 $dat->open(path => 'aname.dat') # sequence @data1 is loaded again as 'aname'
 $dat->dump_line(label => 'aname', delim => ','); # proof it's back 
 
 # With multiple anonymous sequences (simple, but not recommended):
 $dat->load(\@data1, \@data2); # any number of anonymous arrays
 $dat->add([2], [6]); # pushes a single value apiece onto copies of @data1 and @data2
 $aref = $dat->read(index => 1); # returns reference to copy of @data2, with its new values
 $dat->unload(index => 0); # only @data2 remains loaded, and its index is now 0

 # With a single anonymouse data sequence (handy):
 $dat->load(1, 2, 2);
 $dat->add(1); # loaded sequence is now 1, 2, 2, 1
 $dat->dump_line(); # same as: print @{$dat->read()}, "\n";
 $dat->unload(); # all gone
 
=head1 DESCRIPTION

Handles data for some other statistics modules, as in loading, updating and retrieving data for analysis. Performs no actual statistical analysis itself.

Rationale is not wanting to write the same or similar load, add, etc. methods for every statistics module I write, not to provide an omnibus API for Perl stat modules. It, however, encompasses much of the variety of how Perl stats modules do the basic handling their data - coping with the several I've already used and might still need. This is all implemented in core Perl functions; there might be some later value in developing this. At the moment (or soon), the modules L<Statistics::ANOVA|Statistics::ANOVA>, L<Statistics::Sequences|Statistics::Sequences> (and its several sub-tests), and L<Statistics::FisherPitman|Statistics::FisherPitman> use this module for their data-handling. 

=head1 METHODS

The basics aims/rules/behaviors of the methods have been/are as described in the L<RATIONALE|Statistics::Data/RATIONALE> section, below. The possibilities are many, but, to wrap up: any loaded/added sequence of data ends up cached within the class object's '_DATA' aref as an aref itself. Optionally (but preferably), this sequence is associated with a 'label', i.e., a stringy name, if it's been loaded/added as such. The sequences can be updated or retrieved according to the order in which they were loaded/added (by index) or (preferably) its 'label'. In this way, any particular statistical method (e.g., to calculate the number of runs in the sequence, as in L<Statistics::Sequences::Runs|Statistics::Sequences::Runs>), can refer to the 'index' or 'label' of the sequence to do its analysis upon - or it can still use its own rules to select the appropriate sequence, or provide the appropriate sequence within the call to itself. The particular data structures supported here to load, update, retrieve, unload, store, etc., data are specified under L<load|load>.

The methods have been made available to several Perl stats modules as simple ISA-type "children" (not plugins) of this module. Those I've found useful to rewrite as such are L<Statistics::ANOVA|Statistics::ANOVA> (for one-way parametric and nonparametric comparison of two or more independent or dependent sequences), L<Statistics::Autocorrelation|Statistics::Autocorrelation> (for analysis of within-sequence dependencies), L<Statistics::Data::Dichotomize|Statistics::Data::Dichotomize>, L<Statistics::FisherPitman|Statistics::FisherPitman>, and the several L<Statistics::Sequences|Statistics::Sequences> modules for testing a sequence's Wald-type L<runs|Statistics::Sequences::Runs>, Schmidt's L<pot|Statistics::Sequences::Pot>, Kendall's L<turns|Statistics::Sequences::Turns>, Good's L<vnomes|Statistics::Sequences::Vnomes> (serial test) and Wishart-Hirshfeld L<joins|Statistics::Sequences::Joins>. So please not that any modifications to the basic operations of this module will likely affect those of these modules.

=head2 new

 $seq = Statistics::Data->new();
 $seq = Statistics::Data->new(serializer => 'XML::Simple', compress => 1, secret => '123');

Returns a new Statistics::Data object. This is just a plain old blessed hash. Options for serialization are those given in Data::Serializer, including B<serializer> (e.g., XML::Simple, YAML; default = Data::Dumper), B<compress> (default = 0), and B<secret> (for encryption; default is undef, no encryption). Data are only serialized for the L<save|save> and L<open|open> methods, and, of course, to get and set serialized copies of data by L<thaw|thaw> and L<freeze|freeze>. 

=cut

sub new {
    my $class = shift;
    my $self = bless {}, ref($class) ? ref($class) : $class;
    $self->{_DATA} = [];
    $self->{_SERIALIZER} = Data::Serializer->new(@_);
    return $self;
}

=head2 copy

 $seq2 = $dat->copy();

I<Alias>: B<clone>

Returns a copy of the class object with its data loaded (if any). Note this is not a copy of any particular data but the whole blessed hash. If you want that, use L<pass|Statistics::Data/pass> to get all the data added to a new object, or L<read|Statistics::Data/read> to load/add particular sequences into another object. Nothing modified in this new object affects the original.

=cut

sub copy {
    my $self = shift;
    my $copy = (ref $self)->new;
    $copy->load(@{$self->{_DATA}});
    return $copy;
}
*clone = \*copy;

=head2 load

 $dat->load(@data);             # CASE 1. - can be updated/retrieved anonymously, or as index => i (load order)
 $dat->load(\@data);            # CASE 2. - same, as ref
 $dat->load(data => \@data);    # CASE 3. - can be updated/retrieved as label => 'data' (arbitrary name, not just 'data'); or by index (order) as well
 $dat->load({ data => \@data }) # CASE 4. - same, but referenced hash
 $dat->load(blues => \@blue_data, reds => \@red_data);      # CASE 5. multiple named loads
 $dat->load({ blues => \@blue_data, reds => \@red_data });    # CASE 6. same, but referenced hash
 $dat->load(\@blue_data, \@red_data);  # CASE 7. can be got at by index (load order)
 # Not here supported:
 #$dat->load(blues => \@blue_data, reds => [\@red_data1, \@red_data2]); # CASE 8. as for multiple matching problems: not yet? supported
 #$dat->load(data => @data); # CASE 9. ok but wrong (puts string "data" in @data - so load(data => ['a']) is right but not load(data => 'a')
 #$dat->load([\@blue_data, \@red_data]); # CASE 10. use CASE 7 instead
 #dat->load([ [blues => \@blue_data], [reds => \@red_data] ]); CASE 11. you've got to be joking ...

I<Alias>: B<load_data>

Cache an anonymous list of data as an array-reference. Each call to L<load|load> removes previous loads. Sending nothing deletes all loaded data (by C<undef>fing B<$seq-E<gt>{'data'}>). If data not loaded need to be analyzed alongside these, try L<add|Statistics::Data/add>.

=cut

sub load { # load single aref: cannot load more than one sequence; keeps a direct reference to the data: any edits creep back.
    my $self = shift;
    $self->unload();
    $self->add(@_);
    return 1;
}
*load_data = \&load;

=head2 add

I<Alias>: B<add_data>, B<append_data>, B<update>

Same usage as shown above for L<load|Statistics::Data/load>. Just push any value(s) or so along, or loads an entirely labelled sequence, without clobbering what's already in there (as L<load|Statistics::Data/load> would). To add a new sequence without having labelled any loaded ones, could use, e.g., to create a second sequence: $dat->add([], \new_data) - adding nothing to the first loaded sequence, and initialising a second array.

=cut

sub add {
    my $self = shift;
    if (ref $_[0]) {
        if (all { ref($_) eq 'ARRAY' } @_) { # case 2 or 7
            foreach (my $i = 0; $i < scalar @_; $i++) {#print "load $_[$i]\n";
                push @{$self->{_DATA}->[$i]->{seq}}, @{$_[$i]}; # arefs not labelled, $self->[$i]->[1] remains undefined
            }
        }
        elsif (ref $_[0] eq 'HASH') { # cases 4 & 6
            while (my ($lab, $seq) = each %{$_[0]}) {#print "load $lab $seq\n";
                my $i = _seq_index_by_label($self, $lab);
                if (defined $i) {
                    push @{$self->{_DATA}->[$i]->{seq}}, @$seq;
                }
                else {# no aref labelled $lab yet: define both $self->[$i]->[0] and $self->[$i]->[1] (label)
                    $i = scalar(@{$self->{_DATA}}); # print "i = $i seq = $seq lab = $lab\n";
                    $self->{_DATA}->[$i] = {seq => [@$seq], lab => $lab}; # don't just store given reference or further adds will alter it
                }
            }
        }
        else {
            croak "Don't know how to load/add @_";
        }
    }
    elsif (ref $_[1]) { # cases 3 & 5 
        $self->add({@_});
    }
    else { # case 1
        push @{$self->{_DATA}->[0]->{seq}}, @_;
    }
    return 1;
}
*add_data = \&add;
*append_data = \&add;
*update = \&add;

=head2 read

 $aref = $dat->read(); #returns the first and/or only sequence anonymously loaded, if any
 $aref = $dat->read(index => integer); #returns the ith sequence anonymously loaded
 $aref = $dat->read(label => 'a_name'); # returns a particular named cache of data

I<Alias>: B<read_data>, B<get_data>

Return the data that have been loaded/added to. Only one read of a single sequence at a time; just tries to get 'data' if no 'label' is given or the given 'label' does not exist. If this fails, a croak is given.

=cut

sub read {
    my $self = shift;
    my $i;
    if (!$_[0]) {
        $i = 0;
    }
    else {
        my $args = ref $_[0] ? $_[0] : {@_};
        $i = _index_by_args($self, $args);
    }
    if (defined $i and ref $self->{_DATA}->[$i]->{seq}) {
       return $self->{_DATA}->[$i]->{seq};
    }
    else {
       croak __PACKAGE__, "::read Data for reading need to be loaded";
    }
}
*read_data = \&read;
*get_data = \&read;

=head2 unload

 $dat->unload(); # deletes all cached data, named or not
 $dat->unload(index => integer); # deletes the aref named 'data' whatever
 $dat->unload(label => 'a name'); # deletes the aref named 'data' whatever

Empty, clear, clobber what's in there. Croaks if given index or label does not refer to any loaded data. This should be used whenever any already loaded or added data are no longer required ahead of another L<add|add>, including via L<open|open>, L<copy|copy> or L<share|share>.

=cut

sub unload {
    my $self = shift;
    if (!$_[0]) {
        $self->{_DATA} = [];
    }
    else {
        my $args = ref $_[0] ? $_[0] : {@_};
        my $i = _index_by_args($self, $args);
        if (defined $i and ref $self->{_DATA}->[$i]) {
            splice @{$self->{_DATA}}, $i, 1;
        }        
        else {
            croak __PACKAGE__, "::unload Data for unloading need to be loaded";
        }
    }
    return 1;
}

=head2 share

 $dat_new->share($dat_old);

I<Alias>: B<pass>

Adds all the data from one Statistics::Data object to another. Changes in the new copies do not affect the originals.

=cut

sub share {
    my ($self, $other) = @_;
    _add_from_object_aref($self, $other->{_DATA});
    return 1;
}
*pass = \&share;

=head2 dump_line

 $seq->dump_line(delim => ", "); # assumes the first (only?) loaded sequence should be dumped
 $seq->dump_line(index => I<int>, delim => ", "); # dump the i'th loaded sequence
 $seq->dump_line(label => 'mysequence', delim => ", "); # dump the sequence loaded/added with the given "label"

I<Alias>: B<dump_data>

Prints to STDOUT a space-separated line (ending with "\n") of loaded/added data. Optionally, give a value for B<delim> to specify how the elements in each sequence should be separated; default is a single space.

=cut

sub dump_line {
    my $self = shift;
    my $args = ref $_[0] ? $_[0] : {@_};
    my $delim = $args->{'delim'} || ' ';
    print join($delim, @{$self->read($args)}), "\n";
}
*dump_data = \&dump_line;

=head2 save

  $dat->save(path => 'mysequences.csv');

I<Alias>: B<store>

Saves the data presently loaded in the Statistics::Data object to a file, with the given B<path>. This can be opened, with all the data added to the Statistics::Data object, via L<open|Statistics::Data/open>. Data are serialized as per L<Data::Serializer|Data::Serializer> with options as set in L<new|new>. (Future version might permit saving individual sequences by index/label, but why not L<unload|unload> any not needed before saving?)

=cut

sub save {
    my $self = shift;
    my $args = ref $_[0] ? $_[0] : {@_};
    croak 'There is no save path' if nocontent($args->{'path'}); # is filepath valid?
    eval { open D, '>' . $args->{'path'} };
    croak "Cannot open save path '$args->{'path'}'" if $@;
    close D;
    $self->{_SERIALIZER}->store({DATA => $self->{_DATA}}, $args->{'path'} );
    return 1;
}
*store = \&save;

=head2 open

 $dat->open(path => 'medata.csv', format => 'xml|csv');

I<Alias>: B<retrieve>

Essentially, a "L<add_data|Statistics::Data/add> from file" method, assuming there are data in the given path that have been saved in the format given by the L<save|Statistics::Data/save> method. Not a "load" - any already loaded  data aren't clobbered; use L<unload|Statistics::Data/unload> first if that's what's expected. Data are serialized as per L<Data::Serializer|Data::Serializer> with options as set in L<new|new>.  (Future version might permit adding only individual sequences, but why not L<unload|unload> any not needed after opening?)

=cut

sub open {
    my $self = shift;
    my $args = ref $_[0] ? $_[0] : {@_};
    croak 'There is no save path' if nocontent($args->{'path'}); # is filepath valid?
    eval { open D, '<' . $args->{'path'} };
    croak "Cannot open save path '$args->{'path'}'" if $@;
    close D;
    my $href = $self->{_SERIALIZER}->retrieve($args->{'path'});
    _add_from_object_aref($self, $href->{DATA});
    return 1;
}
*retrieve = \&open;

=head2 freeze

 $serialized = $dat->freeze();

Returns a serialized copy of the loaded data, with options (if any given) as supported by L<Data::Serializer|Data::Serializer> (e.g., to compress, encrypt); otherwise uses options given in L<new|new>, or, if none given there, then the defaults for L<Data::Serializer|Data::Serializer>.

=cut

sub freeze {
    my $self = shift;
    return $self->{_SERIALIZER}->freeze({DATA => $self->{_DATA}}, @_);
}

=head2 thaw

 $deserialized = $dat->thaw();

Returns a deserialized copy of serialized data, as would be returned from L<freeze|freeze>, and with options (if any given) as supported by L<Data::Serializer|Data::Serializer> (e.g., to compress, encrypt); otherwise uses options given in L<new|new>, or, if none given there, then the defaults for L<Data::Serializer|Data::Serializer>.

=cut

sub thaw {
    my ($self, $href) = @_;
    return $self->{_SERIALIZER}->thaw($href);
}

=head2 list

I<Alias>: B<list_data>

Dumps a simpletable (using L<Text::SimpleTable|Text::SimpleTable>) of the data currently loaded, without showing their actual elements. List is firstly by index, then by label (if any), then gives the number of elements in the associated sequence.

=cut

sub list {
    my ($self, $i, $lim, $lab, $N, $len_lab, $len_N, $tbl, @rows, @maxlens) = (shift);
    $lim = $self->ndata();
    @maxlens = (($lim > 5 ? $lim : 5), 5, 1);
    for ($i = 0; $i < $lim; $i++) {
        $lab = defined $self->{_DATA}->[$i]->{lab} ? $self->{_DATA}->[$i]->{lab} : '-';
        $N = scalar @{$self->{_DATA}->[$i]->{seq}};
        $len_lab = length($lab);
        $len_N = length($N);
        $maxlens[1] = $len_lab if $len_lab > $maxlens[1];
        $maxlens[2] = $len_N if $len_N > $maxlens[2];
        $rows[$i] = [$i, $lab, $N];
    }
    require Text::SimpleTable;
    $tbl = Text::SimpleTable->new([$maxlens[0], 'index'], [$maxlens[1], 'label'], [$maxlens[2], 'N']);
    $tbl->row(@$_) foreach @rows;
    print $tbl->draw;
}
*list_data = \&list;

=head2 exists

Returns 1 if the data sequence, as named or indexed, exists in the cached data.

=cut

=head2 full

Checks not only if the data sequence, as named or indexed, exists, but if it is non-empty: has no empty elements, with any elements that might exist in there being checked with L<hascontent|String::Util/hascontent>.

=cut

sub full {
    my $self = shift;
    
    foreach my $seq(@{$self->{'_DATA'}}) {
        
    }
    
}

=head2 ndata

 $n = $self->ndata();

Returns the number of loaded data sequences.

=cut

sub ndata {
    my $self = shift;
    return scalar(@{$self->{'_DATA'}});    
}

=head2 autolag

=cut

sub autolag {
    my $self = shift;
    my $args = ref $_[0] ? $_[0] : {@_};
    
}

=head2 crosslag

 my @lagged_arefs = $dat->crosslag(data => [\@ari1, @ari2], lag => signed integer, loop => 0|1);
 my $aref_of_arefs = $dat->crosslag(data => [\@ari1, @ari2], lag => signed integer, loop => 0|1); # same but not "wanting array" 

Takes two arrays and returns them cross-lagged against each other, shifting and popping values according to the number of "lags". Typically used when wanting to match the two arrays against each other.

=over 4

=item lag => signed integer up to the number of elements

Takes the first array sent as "data" as the reference or "target" array for the second "response" array to be shifted so many lags before or behind it. With no looping of the lags, this means the returned arrays are "lag"-elements smaller than the original arrays. For example, with lag => +1 (and loop => 0, the default):

 @t = qw(c p w p s) becomes (p w p s)
 @r = qw(p s s w r) becomes (p s s w)

=item loop => 0|1

For circularized lagging), B<loop> => 1, and the size of the returned array is the same as those for the given data. For example, with a lag of +1, the last element in the "response" array is matched to the first element of the "target" array:

 @t = qw(c p w p s) becomes (p w p s c) (looped with +1)
 @r = qw(p s s w r) becomes (p s s w r) (no effect)

In this case, it might be more efficient to simply autolag the "target" sequence against itself.

=back

=cut

sub crosslag {
    my $self = shift;
    my $args = ref $_[0] ? $_[0] : {@_};
    my $lag = $args->{'lag'};
    my $dat1 = $args->{'data'}->[0];
    my $dat2 = $args->{'data'}->[1];
    my $loop = $args->{'loop'};
 
    return ( wantarray ? ($dat1, $dat2) : [$dat1, $dat2] ) if !$lag or abs($lag) >= scalar @{$dat1};
    
    my @tgt = @{$dat1};
    my @rsp = @{$dat2};

    if ($lag > 0) {
        foreach (1 .. abs($lag) ) {
            if ($loop) {
                unshift(@tgt, pop @tgt);
            }
            else {
                shift @tgt;
                pop @rsp;
            }
        }
    }
    elsif ($lag < 0) {
        foreach (1 .. abs($lag) ) {
            if ($loop) {
                push(@tgt, shift @tgt);
            }
            else {
                pop @tgt;
                shift @rsp;
            }
        }
    }
    return wantarray ? (\@tgt, \@rsp) : [\@tgt, \@rsp];
}

=head2 all_numeric

 $bool = $dat->all_numeric(\@data); # useful if want to test that the data are valid before loading them
 $bool = $dat->all_numeric(label => \@data); # checking after loading/adding the data (or key in 'index')

Ensure data are all numerical.

=cut

sub all_numeric {
    my $self = shift;
    my $data = ref $_[0] ? shift: $self->read(@_); 
    require Scalar::Util;
    foreach (@{$data}) {
         return 0 if ! Scalar::Util::looks_like_number($_);
    }
    return 1;
}

=head2 all_proportions

 $bool = $dat->all_proportions(\@data); # useful if want to test that the data are valid before loading them
 $bool = $dat->all_proportions(label => \@data); # checking after loading/adding the data  (or key in 'index')

Ensure data are all proportions. Sometimes, the data a module needs are all proportions, ranging from 0 to 1 inclusive. A dataset might have to be cleaned 

=cut

sub all_proportions {
    my $self = shift;
    my $data = ref $_[0] ? shift: $self->read(@_); 
    foreach (@{$data}) {
         return 0 if ! _valid_p($_);
    }
    return 1;
}

# PRIVATMETHODEN:

sub _index_by_args {
    my ($self, $args, $i) = @_;
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
    foreach my $dat(@$aref) {
        if (hascontent($dat->{'lab'})) {
            $self->add($dat->{'lab'} => $dat->{'seq'});
        }
        else {
            $self->add($dat->{'seq'});
        }
    }
    return 1;
}

sub _valid_p {
    return ($_[0] !~ /^0?\.\d+$/) || ($_[0] < 0 || $_[0] > 1) ? 0 : 1;
}

=head1 EXAMPLES

B<1. Multivariate data (a tale of horny frogs)>

In a study of how doing mental arithmetic affects arousal in self and others (i.e., how mind, body and world interact), three male frogs were trained to continually report 22/7. Measures of pupillary dilation and perceived attractiveness over time were taken. After four trials, averages per frog were: 

 $frogs->load( Pupil => [59.2, 77.7, 56.1], Attract => [3.11, 8.79, 6.99], Names => [qw/Freddo Kermit Larry/]);
# But data were not ready to be analyzed: one more frog was still to graduate from training. So, without discriminating against slow-learners:
 $frogs->save(path => 'frog_data_001.csv'); # then, after frog-#4 gets tested, in a new session ...
 $frogs->open(path => 'frog_data_001.csv');
 $frogs->add(Pupil => [135.0], Attract => [5.30], Names => ['Sleepy']);
 $frogs->dump_data(label => 'Pupil'); # shows all 4 frogs' pupillary dilations open to analysis by some module

B<2. Piggy-backing and frog-hopping>

This is how Statistics::Sequences simply does it with Statistics::Data for data-handling:

 use Statistics::Data;
 use Exporter;
 use vars (@ISA);
 @ISA = qw(Statistics::Data Exporter);

So when using Statistics::Sequences, it doesn't have to do very much itself:

 use Statistics::Sequences;
 my $seq = Statistics::Sequences->new();
 $seq->load(qw/f b f b b/); # using Statistics::Data method
 say $seq->p_value(stat => 'runs', exact => 1); # using Statistics::Sequences::Runs method
 
Or if these data were loaded directly within Statistics::Data, the data can be shared around modules that "ISA" it:

 use Statistics::Data;
 use Statistics::Sequences::Runs;
 my $dat = Statistics::Data->new();
 my $runs = Statistics::Sequences::Runs->new();
 $dat->load(qw/f b f b b/);
 $runs->pass($dat);
 say $runs->p_value(exact => 1);
 # or between sessions:
 $runs->unload();
 $dat->save(path => 'file.dat');
 $runs->open(path => 'file.dat');
 say $runs->p_value(exact => 1);

=head1 RATIONALE

The basics aims/rules/behaviors of all the methods have been/are to: 

=over 6

=item lump data as arefs into the class object

That's sequences in general, without discriminating at the outset between continuous/numeric or categorical/nominal/stringy data - because the stats methods themselves don't matter here. The point is to make these things available for modular statistical analysis without having to worry about all the loading, adding, reading, etc. within the same package. No other information is cached, not whether they've been analysed, updated ... - just the arefs themselves. Maybe later versions could distinguish data from other info, but for now, that's all left up to the stat analysis modules themselves.

=item handle multiple arefs

That's much of the crux of having a Statistics::Data object, or making any stats object - otherwise, they'd just use a module from the Data or List families to handle the data. Also because many Perl stats modules have found it useful to have this functionality - rather than managing multiple objects, and the ones I write anyway do this happily enough ... 

=item distinguish between handling whole sequences or just their elements

To add_data in most stats modules is to append (push) values to an existing aref, and same thing for deleting data. Some do this just for the single sequence they cache, others by naming particular sequences to append values to, delete values from. But sometimes it's useful to add a whole new sequence without clobbering what was already in there as data, or delete one or more (but not all) sequences already loaded; e.g., some stats modules find it useful to load/add to/delete sequences in multiple separate calls: Statistics::DependantTTest, Statistics::KruskalWallis, Statistics::LogRank. That's taken here as a matter of loading and unloading, not adding and deleting.

=item handle (preferably) named arefs

That's both hashes of arefs, and hashrefs of arefs. This is already useful for Statistics::ANOVA and Statistics::FisherPitman - loaded/added to in single calls. There's also the case of having one or more named sequences (arefs) to have multiple sequences attached to them - e.g., when testing for a match of one "target" sequence to one or more "response" sequences; not implemented here, but the existing methods should be able to readily serve up such things.

=item handle anonymous data

If there's only ever a single sequence of data to analyse by a stats module (such as in L<Statistics::Autocorrelation|Statistics::Autocorrelation> and L<Statistics::Sequences|Statistics::Sequences>), then naming them, and getting at them by names, might be overkill. There should also be support for multiple anonymous loads, which would be accessed by index (order of load) (modules L<Statistics::ChisqIndep|Statistics::ChisqIndep> and L<Statistics::TTest|Statistics::TTest> have found this useful). Still, providing this functionality has meant (so far) not keying data by any label, only storing the label within an anonymous hash, alongside the data. This might, in the end, prove too limiting and confusing, such as when serializing the data (see below). So named sequences are recommended. (Is there a deprecation warning here?) Coming up with random names as labels when none is supplied doesn't seem manageable in the long term either; and would lead to more curly code at the moment. 

=item ample aliases

Perl stats modules use a wide variety of names for performing the same or similar data-handling operations within them; e.g., a load in one is an add in another which is really an update in yet another. This gets me confused when just using modules I've authored myself - so the methods here have several aliases representing method names used in other modules.

=item serialization

Some basic L<freeze|freeze>/L<thaw|thaw> with associated L<save|save>/L<open|open> from files has proven useful to routinize here.

=item easy, obvious adoption by other modules of the methods

The modules that use this one for data-handling aren't plugins to it; they simply make themselves "ISA" it, and they're always free to define their own load, read, etc. methods. A more formal marriage doesn't seem warrented, but the arrangement could well still need some work (subtext => 'beta').

=item don't create an app

It's easy to embed many features that other Perl stats modules have found useful in here only to come away with more of an application than could be useful when creating or managing a module that wants to "ISA" itself as this.

=back

=head1 AUTHOR

Roderick Garton, C<< <rgarton at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-statistics-data-0.01 at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Statistics-Data-0.01>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 TODO

+ finding that it's often useful to get results - eg from L<read()|Statistics::Data/read> - for more than sequence, so a need to be able to specify "labels" and "indices" in the call, and the methods loops about its core operation. But maybe best to keep the looping on the user's side.

+ the data structure could handle any number of other attributes for data, e.g., if numerical values are required, if it's meant to be continuous or nominal, if it's meant to be correlated with or an IV/DV for another sequence, what the theoretical distribution is for its alternative values, how it was sampled ... For now, not supporting attributes like these seems appropriate; an application using this just codes and tracks this type of information itself. Anyway, all these attributes, if important, can be coded into the sequence's 'label' ...

+ L<Moosify|Moose>? Tried but don't seem to get much immediate value - even writing more lines. But have only scratched the surface. It might make other "TODO"s more do-able, and call for less complex (adaptive) data-handling - which aren't altogether good or bad - so backburner for now.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Statistics::Data


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Statistics-Data-0.01>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Statistics-Data-0.01>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Statistics-Data-0.01>

=item * Search CPAN

L<http://search.cpan.org/dist/Statistics-Data-0.01/>

=back

=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2012 Roderick Garton.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1; # End of Statistics::Data
