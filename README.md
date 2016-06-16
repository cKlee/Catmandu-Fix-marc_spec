# Catmandu::Fix::marc_spec

In development.

Depends on https://github.com/MARCspec/MARC-Spec

## Tests

    catmandu -I lib convert MARC to YAML --fix ms.fix < msplit0.mrc

### field not present

    marc_spec('000', my.no.field, value:nofield)

### one simple field

    marc_spec('245', my.title)

### repeated fields

    marc_spec('084', my.classification.split.testvalue, split:1, value:'test')
    marc_spec('084', my.classification.split, split:1)
    marc_spec('084', my.classification.$append, split:1)
    marc_spec('084', my.classification.longstring)
    marc_spec('084', my.classification.longstring.joined, join:'###')


### field with indicators

    marc_spec('245_10', my.title.indicators)

### control field with charpos

    marc_spec('LDR', my.ldr)
    marc_spec('LDR/0-1', my.ldr.charpos)

### all fields with indicator1 = 1

    marc_spec('..._1', my.fields.with.indicator1, split:1)

### all field with substrings

    marc_spec('.../0-1', my.fields.with.2charpos, join:'###')
    marc_spec('...$a/0-1', my.fields.with.2charpos, split:1)


### repeated fields with index

    marc_spec('084[1]', my.classification.second)
    marc_spec('084[#]', my.classification.last)
    marc_spec('084[0-1]', my.classification.two.split, split:1)
    marc_spec('084[0-1]', my.classification.two, join:'###')

### simple subfield

    marc_spec('245$a', my.subfield.simple)

### single subfield with index

    marc_spec('245$a[0]', my.subfield.first)
    marc_spec('245$a[1]', my.subfield.second)
    marc_spec('245$a[#]', my.subfield.last)

### multiple subfields

    marc_spec('245$a$c', my.subfields)

### multiple subfields with index

    marc_spec('245$a[0]$c[0]', my.subfields.first)
    marc_spec('245$a[1]$c[0]', my.subfields.second)
    marc_spec('245$c[#]$a[1]', my.subfields.last, split:1)

# subfield with char pos

    marc_spec('245$c/#-1', my.subfield.charpos.lasttwo)

### multiple subfields with char pos

    marc_spec('245$c/#$b/#', 'my.subfields.charpos')
