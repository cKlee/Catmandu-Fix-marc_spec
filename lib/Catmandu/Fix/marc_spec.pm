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
    my $indicators = "";
    my $ind2 = (defined $ms->field->indicator2) ? ",".$ms->field->indicator2 : "";
    my $ind1 = (defined $ms->field->indicator1) ? $ms->field->indicator1 : "";
    $indicators = "[".$ind1.$ind2."]"
        unless($ind1 eq "" and $ind2 eq "");
    
    # char positions
    my $char_pos = (defined $ms->field->charPos) ? "/".$ms->field->charPos : "";
    
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

        return [$index_start .. $index_end];
    };

    my @filtered = ();
    
    if(-1 ne $ms->field->indexLength) { # index is requested
        # filter by tag
        my @fields = ();
        my $tag = $ms->field->tag;
        return $data
            unless(@fields = grep { $_->[0] =~ m/$tag/xms } @{$data->{$record_key}});
        
        # filter by index
        my $index_range = $get_index_range->($ms->field,scalar @fields);
        my $prevTag = "";
        my $index = 0;

        for my $pos (0 .. $#fields ) {
            my $tag = $fields[$pos][0];
            $index = ($prevTag eq $tag or "" eq $prevTag) ? $index : 0;
            push @filtered, $fields[$pos]
                if( grep(m/^$index$/xms, @$index_range) );
            $index++;
            $prevTag = $tag;
        }
        return $data unless(@filtered);
    }

    my $tmp_record = (@filtered) ? {'_id' => $_id, $record_key => [@filtered]} : $data;

    if(defined $ms->subfields) { # now we dealing with subfields
        # set the order of subfields
        @{$ms->subfields} = sort {$a->code cmp $b->code} @{$ms->subfields}
            unless($self->pluck);
        
        my (@subfields,@subfield,$subfield_path,$sf_range,$char_start);

        for my $sf (@{$ms->subfields}) {
            $subfield_path = $marc_path.$sf->code;
            next unless( @subfield = marc_map($tmp_record,$subfield_path) );

            # filter by index
            unless(-1 eq $sf->indexLength) {
                $sf_range = $get_index_range->($sf, scalar @subfield);
                @subfield = map { $subfield[$_] if defined $subfield[$_]} @{$sf_range};
            }
            
            # get substring
            if(defined $sf->charPos) {
                $char_start = ('#' eq $sf->charStart) ? $sf->charLength * -1 : $sf->charStart;
                @subfield = map {substr ($_, $char_start, $sf->charLength)} @subfield;
            }

            push @subfields, @subfield if(@subfield);
        }
        
        return $data unless(@subfields);

        my $nested = data_at($path, $data, create => 1, key => $key);
        
        if($self->value) {
            set_data($nested, $key, $self->value);
            return $data;
        }

        $self->split ? set_data($nested, $key, @subfields) : set_data($nested, $key, join($join_char, @subfields));
    } else { # no subfields requested
        my $mapped;
        if($self->split) {
            @$mapped = marc_map( $tmp_record, $marc_path, %opts); # is an AoA
        } else {
            $mapped = marc_map( $tmp_record, $marc_path, %opts); # is a string
        }
        
        return $data unless($mapped);

        my $nested = data_at($path, $data, create => 1, key => $key);
        
        $self->value ? set_data($nested, $key, $self->value) : set_data($nested, $key, $mapped);
    }
    
    return $data;
}

1;