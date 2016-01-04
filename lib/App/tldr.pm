package App::tldr;
use strict;
use warnings;
use Encode ();
use File::Spec;
use Getopt::Long qw(:config no_auto_abbrev no_ignore_case bundling);
use HTTP::Tiny;
use IO::Socket::SSL;
use Pod::Usage 'pod2usage';
use Term::ReadKey ();
use Text::Fold ();

use constant DEBUG => $ENV{TLDR_DEBUG};
use constant REPOSITORY => $ENV{TLDR_REPOSITORY};

our $VERSION = '0.01';

my $URL = "https://raw.githubusercontent.com/tldr-pages/tldr/master/pages/%s/%s.md";

sub new {
    my ($class, %option) = @_;
    my $http = HTTP::Tiny->new;
    bless { http => $http, %option }, $class;
}

sub parse_options {
    my ($self, @argv) = @_;
    local @ARGV = @argv;
    $self->{platform} = [];
    GetOptions
        "h|help"    => sub { $self->_help },
        "o|os=s@"   => \($self->{platform}),
        "v|version" => sub { printf "%s %s\n", ref $self, $self->VERSION; exit },
    or exit(2);
    $self->{argv} = \@ARGV;
    push @{$self->{platform}}, $self->_guess_platform, "common";
    $self;
}

sub _help {
    my ($self, $exit) = @_;
    pod2usage( $exit || 0 );
}


# XXX
sub _guess_platform {
    $^O =~ /darwin/i ? "osx"   :
    $^O =~ /linux/i  ? "linux" :
    $^O =~ /sunos/i  ? "sunos" : ();
}

sub _get {
    my $self = shift;
    if (REPOSITORY) {
        $self->_local_get(@_);
    } else {
        $self->_http_get(@_);
    }
}

sub _http_get {
    my ($self, $query, $platform) = @_;
    my $url = sprintf $URL, $platform, $query;
    my $res = $self->{http}->get($url);
    if ($res->{success}) {
        (Encode::decode_utf8($res->{content}), undef);
    } else {
        (undef, "$url: $res->{status} $res->{reason}");
    }
}

sub _local_get {
    my ($self, $query, $platform) = @_;
    my $file = File::Spec->catfile(REPOSITORY, "pages", $platform, "$query.md");
    if (-f $file) {
        open my $fh, "<:utf8", $file or die "$file: $!";
        local $/;
        (<$fh>, undef);
    } else {
        (undef, "Missing $file");
    }
}

sub run {
    my $self = shift;
    my $arg  = shift @{$self->{argv}} or $self->_help(1);
    my $content;
    for my $platform (@{ $self->{platform} }) {
        ($content, my $err) = $self->_get($arg, $platform);
        if ($content) {
            last;
        } elsif (DEBUG) {
            warn "-> $err\n";
        }
    }
    die "Couldn't find tldr for '$arg'\n" unless $content;
    binmode STDOUT, ":utf8";
    $self->_render($content, $arg);
}

my $CHECK = "\N{U+2713}";
my $SUSHI = "\N{U+1F363}";

sub _render {
    my ($self, $content, $query) = @_;

    my ($width) = Term::ReadKey::GetTerminalSize();
    $width -= 4;

    my @line = split /\n/, $content;

    while (defined(my $line = shift @line)) {
        if ($line =~ /^#/) {
            # skip
        } elsif ($line =~ s/^\>\s*//) {
            my $description = $line;
            while (1) {
                my $next = shift @line;
                if ($next eq "") {
                    next;
                } elsif ($next =~ s/^\>\s*//) {
                    $description .= "\n$next";
                } else {
                    unshift @line, $next;
                    last;
                }
            }
            my $fold = Text::Fold::fold_text($description, $width);
            print "\n";
            print "  \e[32m$_\e[m\n" for split /\n/, $fold;
            print "\n";
        } elsif ($line =~ s/^[*-]\s*//) {
            my $fold = Text::Fold::fold_text($line, $width - 2);
            my ($first, @rest) = split /\n/, $fold;
            print "  \e[1m$CHECK \e[4m$first\e[m\n";
            print "    \e[1m\e[4m$_\e[m\n" for @rest;
            print "\n";
        } elsif ($line =~ /`([^`]+)`/) {
            my $code = $1;
            $code =~ s/\b$query\b/
              "\e[32m$query\e[m"
            /eg;
            print "    $SUSHI  $code\n\n";
        }
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

App::tldr - a perl client for http://tldr-pages.github.io/

=head1 SYNOPSIS

  $ tldr tar

=head1 DESCRIPTION

App::tldr is a client for L<http://tldr-pages.github.io/>.

=head1 SEE ALSO

L<https://github.com/tldr-pages/tldr>

=head1 COPYRIGHT AND LICENSE

Copyright 2016 Shoichi Kaji <skaji@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
