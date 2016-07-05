# NAME

Catmandu::Fix::marc\_spec - reference MARC values via [MARCspec - A common MARC record path language](http://marcspec.github.io/MARCspec/)

# SYNOPSIS

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
    
    # Assign values of of all other subfields than a of field 020
    # to my.isbn.other.subfields
    marc_spec('020$a' my.isbn.other.subfields, invert:1)

# DESCRIPTION

[Catmandu::Fix::marc\_spec](https://metacpan.org/pod/Catmandu::Fix::marc_spec) is a fix method for the 
famous [Catmandu Framework](https://metacpan.org/pod/Catmandu).

It behaves like <Catmandu::Fix::marc\_map|Catmandu::Fix::marc\_map> for the most
part, but has a more fine grained method to reference data content.

See [MARCspec - A common MARC record path language](http://marcspec.github.io/MARCspec/) 
for documentation on the path syntax.

# SUBROUTINES/METHODS

## marc\_spec($marcspec, $var, %options)

$marcspec is a string with the syntax of
[MARCspec - A common MARC record path language](http://marcspec.github.io/MARCspec/).
Use always single quotes with this first parameter.

$var is the variable to assign referenced values to. Use $var.$append to
add referenced data values as an array element.

    # INPUT
    [245,1,0,"a","Cross-platform Perl /","c","Eric F. Johnson."]
    
    # CALL
    marc_spec('245', my.title.$append)
    
    # OUTPUT
    ["Cross-platform Perl /Eric F. Johnson."]

# OPTIONS

## split

If split is set to 1, every fixed fields value or every subfield will be
an array element.

    # INPUT
    [650," ",0,"a","Perl (Computer program language)"],
    [650," ",0,"a","Web servers."]
    
    # CALL
    marc_spec('650', my.split.subjects, split:1)
    
    # OUTPUT
    ["Perl (Computer program language)", "Web servers."]

## join

If set, value of join will be used to join the referenced data content.
This will only have an effect if option split is undefined (not set or set to 0).

    # INPUT
    [650," ",0,"a","Perl (Computer program language)"],
    [650," ",0,"a","Web servers."]
    
    # CALL
    marc_spec('650', my.join.subjects, join:'###')
    
    # OUTPUT
    "Perl (Computer program language)###Web servers."

## pluck

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
    marc_spec('020$q$a', my.plucked.isbn, split:1, pluck:1)
    
    # OUTPUT
    ["black leather", 0491001304]

## value

If set to a value, this value will be assigned to $var if MARCspec references
data content (if the field or subfield exists).

In case two or more subfields are referenced, the value will be assigned to $var if
at least one of them exists:

    # INPUT
    ["020"," ", " ","a","0491001304"]
    
    # CALL
    marc_spec('020$a$q', my.isbns, value:'one subfield exists')
    
    # OUTPUT
    "one subfield exists"

## record

The value of option record is used as a record key. Thus not the default record,
but the other record will be processed.

This option is useful if you created another (temporary) record and want to
work on this record instead of the default record.

    copy_field(record, record2)
    # do some stuff with record2 an later
    marc_spec('245$a', my.title.other, record:'record2')

## invert

This has only an effect on subfield (values). If set to 1 it will invert the 
last pattern for every subfield. E.g.

    # references all subfields but not subfield a and q
    marc_spec('020$a$q' my.other.subfields, invert:1)
    
    # references all subfields but not subfield a and not the last repetition
    # of subfield q
    marc_spec('020$a$q[#]' my.other.subfields, invert:1)
    
    # references all but not the last two characters of first subfield a
    marc_spec('020$a[0]/#-1' my.other.subfields, invert:1)

# BUGS AND LIMITATIONS

This version of is agnostic of Subspecs as described in  [MARCspec - A common MARC record path language](http://marcspec.github.io/MARCspec/).
Later versions will include this feature.

# AUTHOR

Carsten Klee &lt;klee@cpan.org>

# CONTRIBUTORS

- Johann Rolschewski, `<jorol at cpan>`,
- Patrick Hochstenbach, `<patrick.hochstenbach at ugent.be>`,
- Nicolas Steenlant, `<nicolas.steenlant at ugent.be>`

# LICENSE AND COPYRIGHT

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO

[Catmandu::Fix](https://metacpan.org/pod/Catmandu::Fix),
[Catmandu::MARC](https://metacpan.org/pod/Catmandu::MARC),
[Catmandu::MARC::Fix::marc\_map](https://metacpan.org/pod/Catmandu::MARC::Fix::marc_map)
