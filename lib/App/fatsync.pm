package App::fatsync;

our $VERSION = '0.01';

use 5.010;

use strict;
use warnings;
use Carp;
use File::Path qw(make_path);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(fatsync);




sub new {
    my ($class, %opts) = @_;
    my $self = { debug => 0,
                 opts => \%opts };
    bless $self, $class;
}

sub _debug {
    return unless shift->{debug};
    print STDERR join(': ', debug => @_), "\n";
}

sub fatsync {
    my ($self, $src, $dst) = @_;

    -d $src or croak "$src is not a directory";

    $dst = File::Spec->rel2abs($dst);

    make_path($dst);
    -d $dst or croak "could not create $dst dir";

    $self->_fatsync($src, $dst);
}

sub _error {
    shift;
    print STDERR join(': ', @_), "\n";
}

sub _fatorize {
    my ($self, $name) = @_;
    $name =~ s/[:?"]/_/g;
    $name;
}

sub _fatsync {
    my ($self, $src0, $dst0) = @_;

    local $self->{fatorized} = {};

    my @rel = ('.');
    my %mode;

    while (@rel) {
        my $rel = shift @rel;
        my $rel_fat = $self->_fatorize($rel);
        next unless defined $rel_fat;
        my $src = File::Spec->rel2abs($rel, $src0);
        my $dh;
        unless (opendir $dh, $src) {
            $self->_error("unable to open directory $src", $!);
            next;
        }
        my $dst = File::Spec->rel2abs($rel_fat, $dst0);

        $self->_debug("mkdir $dst");
        mkdir $dst, 0700;
        unless (-d $dst) {
            $self->_error("unable to create directory $dst");
        }
        $mode{$dst} = (stat $src)[2];

        while (defined(my $entry = readdir $dh)) {
            next if $entry =~ /^\.\.?$/;
            my $rel_entry = File::Spec->join($rel, $entry);
            my $rel_entry_fat = $self->_fatorize($rel_entry);
            next unless defined $rel_entry_fat;
            my $abs_entry = File::Spec->rel2abs($rel_entry, $src0);
            my $abs_entry_fat = File::Spec->rel2abs($rel_entry_fat, $dst0);
            $self->_debug("rel: $rel, entry: $entry, rel_entry: $rel_entry, rel_entry_fat: $rel_entry_fat, abs_entry: $abs_entry, abs_entry_fat: $abs_entry_fat");

            if (-d $abs_entry) {
                push @rel, $rel_entry;
            }
            elsif (-f $abs_entry) {
                $self->_cp($abs_entry, $abs_entry_fat);
            }
        }
        unless (closedir $dh) {
            $self->_error("unable to read directory $src", $!);
            next;
        }
    }
}

sub _cp {
    my ($self, $src, $dst) = @_;
    my ($from, $to);

    $self->_debug("copying $src to $dst");

    unless (open $from, '<', $src) {
        $self->_error("Unable to open $src for reading", $!);
        return;
    }

    unless (open $to, '>', $dst) {
        $self->_error("Unable top open $dst for writing", $!);
        return;
    }

    return;

    binmode $from;
    binmode $to;
    my $eof;

    while (1) {
        my $buffer = '';
        if (!eof and length $buffer < 128 * 1024) {
            my $bytes = sysread $from, $buffer, 16 * 1024, length $buffer;
            $eof = 1 unless $bytes;
        }
        if (length $buffer) {
            my $bytes = syswrite $to, $buffer, 16 * 1024;
            if ($bytes) {
                substr($buffer, 0, $bytes, '');
            }
            else {
                goto ERROR;
            }
        }
        elsif ($eof) {
            last;
        }
    }
    close $to or goto ERROR;
    return 1;

 ERROR:
    my $err = $!;
    unlink $to;
    $self->_error("write to $dst failed", $err);
    0;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

App::fatsync - Perl extension for blah blah blah

=head1 SYNOPSIS

  use App::fatsync;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for App::fatsync, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Salvador Fandiño, E<lt>salva@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Salvador Fandiño

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.12.4 or,
at your option, any later version of Perl 5 you may have available.


=cut
