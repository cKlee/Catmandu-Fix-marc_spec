package Catmandu::Fix::marc_spec;

use DDP;
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
    #p $cache;
    #p $ms;
    #p $ms->field;
    #p $ms->subfields;
    #p $ms->field->tag;
    
    
    #p $self->spec;
    #p $self->data;
    #p $self->path;
    #p $data;
    #p $data->{$record_key};


    my %opts;
    $opts{'-split'}  = $self->split;
    $opts{'-join'}   = $self->join;
    $opts{'-pluck'}  = $self->pluck;
    #$opts{'-value'}  = $self->value;
    #$opts{'-record'} = $self->record;
    
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
        #p @sf_spec;
        #@{$ms->subfields} = sort {$a->code cmp $b->code} @{$ms->subfields}
        @sf_spec = sort {$a->code cmp $b->code} @sf_spec
            unless($self->pluck);
        #p @sf_spec;
        #p $ms->subfields;
        my ($subfields,$subfield,$sf_range,$char_start);

        for my $field (@fields) {
            
            my $start = (defined $field->[3] && $field->[3] eq '_') ? 5 : 3;
            
            #for my $sf (@{$ms->subfields}) {
            for my $sf (@sf_spec) {
                $subfield = [];
                my $code = $sf->code;
                for (my $i = $start; $i < @$field; $i += 2) {
                    if ($field->[$i] =~ /$code/) {
                        push(@$subfield, $field->[$i + 1]);
                    }
                }
                next unless(@$subfield);
    #p $sf->code;
    #p $subfield;
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
                #p $subfields;
            }
        }

#p $subfields;
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
#p $marc_path;
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
#p $data;
    return $data;
}

1;