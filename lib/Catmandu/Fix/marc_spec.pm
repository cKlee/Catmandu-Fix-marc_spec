package Catmandu::Fix::marc_spec;

use Moo;
use Catmandu::Sane;
use Catmandu::Util qw(:data);
use Catmandu::Fix::Has;
use Catmandu::Fix::Inline::marc_map qw(:all);
use MARC::Spec;

has spec       => (fix_arg => 1);
has path       => (fix_arg => 1);
has record     => (fix_opt => 1);
has split      => (fix_opt => 1);
has join       => (fix_opt => 1);
has value      => (fix_opt => 1);
has pluck      => (fix_opt => 1);
has data       => (fix_opt => 1, default => sub {{}} );

my $cache;

sub fix {
    my ($self, $data) = @_;

    my $join_char  = $self->join // '';
    my $record_key = $self->record // 'record';
    my $_id        = $data->{_id};
    
    my ($path, $key) = parse_data_path($self->path);
    

    # get MARCspec
    $cache->{$self->spec} = MARC::Spec->new($self->spec) unless(defined $cache->{$self->spec});
    my $ms = $cache->{$self->spec};

    my %opts;
    $opts{'-split'}  = $self->split;
    $opts{'-join'}   = $self->join;
    $opts{'-pluck'}  = $self->pluck;
    
    # indicators
    my $indicators = '';
    my $ind2 = (defined $ms->field->indicator2) ? ','.$ms->field->indicator2 : '';
    my $ind1 = (defined $ms->field->indicator1) ? $ms->field->indicator1 : '';
    $indicators = '['.$ind1.$ind2.']'
        unless($ind1 eq '' and $ind2 eq '');
    
    # char positions
    my $char_pos = (defined $ms->field->charPos && '#' ne $ms->field->charStart) ? '/'.$ms->field->charPos : '';
    
    my $marc_path = $ms->field->tag.$indicators.$char_pos;

    my $get_index_range = sub {
        my ($spec,$total) = @_;

        my $lastIndex = $total - 1;
        my $index_start = $spec->indexStart;
        my $index_end = $spec->indexEnd;
        
        if('#' eq $index_start) {
            return [$lastIndex]
                if('#' eq $index_end or 0 eq $index_end);
            $index_start = $lastIndex;
            $index_end = $lastIndex - $index_end;
            $index_end = 0 if (0 > $index_end);
        } else {
            return [$index_start]
                if ($lastIndex < $index_start); # this will result to no hits
        }
        
        $index_end = $lastIndex if ('#' eq $index_end or $index_end > $lastIndex);

        my @range = ($index_start <= $index_end) ? ($index_start .. $index_end) : ($index_end .. $index_start);
        return \@range;
    };

    # filter by tag
    my @fields = ();
    my $tag = $ms->field->tag;
    return $data
        unless(@fields = grep { $_->[0] =~ m/$tag/xms } @{$data->{$record_key}});

    # filter by index
    if(-1 ne $ms->field->indexLength) { # index is requested
        my $index_range = $get_index_range->($ms->field,scalar @fields);
        my $prevTag = '';
        my $index = 0;
        my $tag;
        my @filtered = ();
        for my $pos (0 .. $#fields ) {
            $tag = $fields[$pos][0];
            $index = ($prevTag eq $tag or '' eq $prevTag) ? $index : 0;
            push @filtered, $fields[$pos]
                if( grep(m/^$index$/xms, @$index_range) );
            $index++;
            $prevTag = $tag;
        }
        return $data unless(@filtered);
        @fields = @filtered;
    }

    my $tmp_record = {'_id' => $_id, $record_key => [@fields]};

    if(defined $ms->subfields) { # now we dealing with subfields
        # set the order of subfields
        my @sf_spec =  map { $_ } @{$ms->subfields};
        @sf_spec = sort {$a->code cmp $b->code} @sf_spec
            unless($self->pluck);

       my ($subfields,$subfield,$sf_range,$char_start);

        for my $field (@fields) {
            my $start = (defined $field->[3] && $field->[3] eq '_') ? 5 : 3;

            for my $sf (@sf_spec) {
                $subfield = [];
                my $code = $sf->code;
                for (my $i = $start; $i < @$field; $i += 2) {
                    if ($field->[$i] =~ /$code/) {
                        push(@$subfield, $field->[$i + 1]);
                    }
                }
                next unless(@$subfield);

                # filter by index
                unless(-1 eq $sf->indexLength) {
                    $sf_range = $get_index_range->($sf, scalar @$subfield);
                    @$subfield = map { defined ${$subfield}[$_] ? ${$subfield}[$_] : () } @$sf_range;
                    next unless(@$subfield);
                }

                # get substring
                if(defined $sf->charPos) {
                    $char_start = ('#' eq $sf->charStart) ? $sf->charLength * -1 : $sf->charStart;
                    @$subfield = map {substr ($_, $char_start, $sf->charLength)} @$subfield;
                }

                push @$subfields, @$subfield if(@$subfield);
            }
        }

        return $data unless($subfields);

        my $nested = data_at($path, $data, create => 1, key => $key);
        
        if($self->value) {
            set_data($nested, $key, $self->value);
            return $data;
        }

        $self->split ? set_data($nested, $key, $subfields) : set_data($nested, $key, join($join_char, @$subfields));
    } else { # no subfields requested
        my $mapped;
        @$mapped = marc_map($tmp_record, $marc_path, %opts);
        return $data unless($mapped);

        # get substring
        if(defined $ms->field->charPos) {
            my $char_start = ('#' eq $ms->field->charStart) ? $ms->field->charLength * -1 : $ms->field->charStart;
            @$mapped = map {substr ($_, $char_start, $ms->field->charLength)} @$mapped;
        }
        
        my $nested = data_at($path, $data, create => 1, key => $key);
        
        if($self->value) {
            set_data($nested, $key, $self->value);
        } elsif(!$self->split) {
            set_data($nested, $key, join($join_char, @$mapped));
        } else {
            set_data($nested, $key, $mapped);
        }
        
    }
    return $data;
}

1;
__END__

=encoding utf-8

=head1 NAME

Catmandu::Fix::marc_spec - reference MARC values via L<MARCspec - A common MARC record path language|http://marcspec.github.io/MARCspec/>

=head1 SYNOPSIS

    # Assign value of MARC leader to my.ldr.all
    marc_spec('LDR', my.ldr.all)
    
    # Assign values of all subfields of field 245 as a joined string
    marc_spec('245', my.title.all)
    
    # If field 245 exists, set string 'the title' as the value of my.title.default
    marc_spec('245', my.title.default, value:'the title')
    
    # Assign values of all subfields of every field 650 to my.subjects.all
    # as a joined string
    marc_spec('650', my.subjects.all)
    
    # Same as above with joining characters '###'
    marc_spec('650', my.subjects.all, join:'###')
    
    # Same as above but added as an element to the array my.append.subjects
    marc_spec('650', my.append.subjects.$append, join:'###')
    
    # Every value of a subfield will be an array element
    marc_spec('650', my.split.subjects, split:1)
    
    # Assign values of all subfields of all fields having indicator 1 = 1
    # and indicator 2 = 0 to the my.fields.indicators10 array.
    marc_spec('..._10', my.fields.indicators10.$append)
    
    # Assign first four characters of leader to my.firstcharpos.ldr
    marc_spec('LDR/0-3', my.firstcharpos.ldr)
    
    # Assign last four characters of leader to my.lastcharpos.ldr
    marc_spec('LDR/#-3', my.lastcharpos.ldr)
    
    # Assign value of subfield a of field 245 to my.title.proper
    marc_spec('245$a', my.title.proper)
    
    # Assign first two characters of subfield a of field 245 to my.title.proper
    marc_spec('245$a/0-1', my.title.charpos)
    
    # Assign all subfields of second field 650 to my.second.subject
    marc_spec('650[1]', my.second.subject)
    
    # Assign values of all subfields of last field 650 to my.last.subject
    marc_spec('650[#]', my.last.subject)
    
    # Assign an array of values of all subfields of the first two fields 650
    # to my.two.split.subjects
    marc_spec('650[0-1]', my.two.split.subjects, split:1)
    
    # Assign a joined string of values of all subfields of the last two fields 650
    # to my.two.join.subjects
    marc_spec('650[#-1]', my.two.join.subjects, join:'###')
    
    
    # Assign value of first subfield a of all fields 020 to my.isbn.number
    marc_spec('020$a[0]', my.isbn.number)
    
    # Assign value of first subfield q of first field 020 to my.isbn.qual.one
    marc_spec('020[0]$q[0]', my.isbn.qual.none)
    
    # Assign values of subfield q and a in the order stated as an array
    # to  my.isbns.pluck.all
    # without option 'pluck:1' the elments will be in 'natural' order
    # see example below
    marc_spec('020$q$a', my.isbns.pluck.all, split:1, pluck:1)
    
    # Assign value of last subfield q and second subfield a 
    # in 'natural' order of last field 020 as an array to my.isbn.qual.other
    marc_spec('020[#]$q[#]$a[1]', my.isbn.qual.other, split:1)
    
    # Assign first five characters of value of last subfield q and last character
    # of value of second subfield a in 'natural' order of all fields 020
    # as an array to  my.isbn.qual.substring.other
    marc_spec('020$q[#]/0-4$a[1]/#', my.isbn.qual.substring.other, split:1)

=head1 DESCRIPTION

L<Catmandu::Fix::marc_spec|Catmandu::Fix::marc_spec> is a fix method for the 
famous L<Catmandu Framework|Catmandu>.

It behaves like <Catmandu::Fix::marc_map|Catmandu::Fix::marc_map> for the most
part, but has a more fine grained method to reference data content.

See L<MARCspec - A common MARC record path language|http://marcspec.github.io/MARCspec/> 
for documentation on the path syntax.

=head1 METHODS

=head2 marc_spec($marcspec, $var, %options)

$marcspec is a string with the syntax of
L<MARCspec - A common MARC record path language|http://marcspec.github.io/MARCspec/>.
Use always single quotes with this first parameter.

$var is the variable to assign referenced values to. Use $var.$append to
add referenced data values as an array element.

    # INPUT
    [245,1,0,"a","Cross-platform Perl /","c","Eric F. Johnson."]
    
    # CALL
    marc_spec('245', my.title.$append)
    
    # OUTPUT
    ["Cross-platform Perl /Eric F. Johnson."]


=head1 OPTIONS

=head2 split

If split is set to 1, every fixed fields value or every subfield will be
an array element.

    # INPUT
    [650," ",0,"a","Perl (Computer program language)"],
    [650," ",0,"a","Web servers."]
    
    # CALL
    marc_spec('650', my.split.subjects, split:1)
    
    # OUTPUT
    ["Perl (Computer program language)", "Web servers."]

=head2 join

If set, value of join will be used to join the referenced data content.
This will only have an effect if option split is undefined (not set or set to 0).

    # INPUT
    [650," ",0,"a","Perl (Computer program language)"],
    [650," ",0,"a","Web servers."]
    
    # CALL
    marc_spec('650', my.join.subjects, join:'###')
    
    # OUTPUT
    "Perl (Computer program language)###Web servers."

=head2 pluck

This has only an effect on subfield values. By default subfield reference
happens in 'natural' order (first number 0 to 9 and then letters a to z).

    # INPUT
    ["020"," ", " ","a","0491001304","q","black leather"]
    
    # CALL
    marc_spec('020$q$a', my.natural.isbn, split:1)
    
    # OUTPUT
    [0491001304, "black leather"]
    

If pluck is set to 1, values will be referenced by the order stated in the
MARCspec.

    # INPUT
    ["020"," ", " ","a","0491001304","q","black leather"]
    
    # CALL
    marc_spec('020$q$a', my.natural.isbn, split:1, pluck:1)
    
    # OUTPUT
    ["black leather", 0491001304]

=head2 value

If set to an value, this value will be assigned to $var if MARCspec references
data content (if the field or subfield exists). 

=head2 record

The value of option record is used as a record key. Thus not the default record,
but the other record will be processed.

This option is useful if you created another (temporary) record and want to
work on this record instead of the default record.

    copy_field(record, record2)
    # do some stuff with record2 an later
    marc_spec('245$a', my.title.other, record:'record2')

=head1 AUTHOR

Carsten Klee E<lt>klee@cpan.orgE<gt>

=head1 CONTRIBUTORS

=over

=item * Johann Rolschewski, C<< <jorol at cpan> >>,

=item * Patrick Hochstenbach, C<< <patrick.hochstenbach at ugent.be> >>,

=item * Nicolas Steenlant, C<< <nicolas.steenlant at ugent.be> >>

=back

=head1 LICENSE AND COPYRIGHT

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Catmandu::Fix|Catmandu::Fix>,
L<Catmandu::MARC|Catmandu::MARC>,
L<Catmandu::MARC::Fix::marc_map|Catmandu::MARC::Fix::marc_map>

=cut