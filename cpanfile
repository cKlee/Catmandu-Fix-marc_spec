requires 'perl', 'v5.10.1';

requires 'Catmandu', '1.0201';
requires 'Catmandu::MARC', '0.218';
requires 'Const::Fast', '0.014';
requires 'MARC::Spec';
requires 'Moo', '1.0';

on test => sub {
    requires 'Test::More', '0.96';
};
