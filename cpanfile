requires 'perl', '5.008005';

requires 'HTTP::Tiny';
requires 'IO::Socket::SSL';
requires 'Term::ReadKey';
requires 'Text::Fold';

on test => sub {
    requires 'Test::More', '0.98';
};
