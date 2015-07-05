package OpenCloset::Cron::Role::AELog;
# ABSTRACT: OpenCloset AnyEvent log role

use utf8;

use Moo::Role;
use MooX::Types::MooseLike::Base qw( Str );
use namespace::clean -except => 'meta';

our $VERSION = '0.002';

use AnyEvent::Log;

requires 'BUILD';

has aelog => ( is => 'ro', isa => Str );

after BUILD => sub {
    my $self = shift;

    my $conf = $self->aelog;

    return unless $conf;

    my %anon;

    my $pkg = sub {
              $_[0] eq "log"     ? $AnyEvent::Log::LOG
            : $_[0] eq "filter"  ? $AnyEvent::Log::FILTER
            : $_[0] eq "collect" ? $AnyEvent::Log::COLLECT
            : $_[0] =~ /^%(.+)$/ ? (
            $anon{$1} ||=
                do { my $ctx = AnyEvent::Log::ctx undef; $ctx->[0] = $_[0]; $ctx }
            )
            : $_[0] =~ /^(.*?)(?:::)?$/ ? AnyEvent::Log::ctx "$1" # egad :/
            : die                                                 # never reached?
    };

    $_ = $conf;

    /\G[[:space:]]+/gc; # skip initial whitespace

    while (/\G((?:[^:=[:space:]]+|::|\\.)+)=/gc) {
        my $ctx   = $pkg->($1);
        my $level = "level";

        while (/\G((?:[^,:[:space:]]+|::|\\.)+)/gc) {
            for ("$1") {
                if ( $_ eq "stderr" ) {
                    $ctx->log_to_warn;
                }
                elsif (/^file=(.+)/) {
                    $ctx->log_to_file("$1");
                }
                elsif (/^path=(.+)/) {
                    $ctx->log_to_path("$1");
                }
                elsif (/^syslog(?:=(.*))?/) {
                    require Sys::Syslog;
                    $ctx->log_to_syslog("$1");
                }
                elsif ( $_ eq "nolog" ) {
                    $ctx->log_cb(undef);
                }
                elsif (/^cap=(.+)/) {
                    $ctx->cap("$1");
                }
                elsif (/^\+(.+)$/) {
                    $ctx->attach( $pkg->("$1") );
                }
                elsif ( $_ eq "+" ) {
                    $ctx->slaves;
                }
                elsif ( $_ eq "off" or $_ eq "0" ) {
                    $ctx->level(0);
                }
                elsif ( $_ eq "all" ) {
                    $ctx->level("all");
                }
                elsif ( $_ eq "level" ) {
                    $ctx->level("all");
                    $level = "level";
                }
                elsif ( $_ eq "only" ) {
                    $ctx->level("off");
                    $level = "enable";
                }
                elsif ( $_ eq "except" ) {
                    $ctx->level("all");
                    $level = "disable";
                }
                elsif (/^\d$/) {
                    $ctx->$level($_);
                }
                elsif ( exists $AnyEvent::Log::STR2LEVEL{$_} ) {
                    $ctx->$level($_);
                }
                else {
                    die "PERL_ANYEVENT_LOG ($conf): parse error at '$_'\n";
                }
            }

            /\G,/gc or last;
        }

        /\G[:[:space:]]+/gc or last;
    }

    /\G[[:space:]]+/gc; # skip trailing whitespace

    if (/\G(.+)/g) {
        die "PERL_ANYEVENT_LOG ($conf): parse error at '$1'\n";
    }
};

1;

# COPYRIGHT

__END__

=head1 SYNOPSIS

    package Your::Module;
    use Moo;
    with qw( OpenCloset::Cron::Role::AELog );

    sub BUILD { }

    package main;
    use AnyEvent;
    use Your::Module;

    my $ym = Your::Module->new(
        aelog => 'filter=info',
    );

    AnyEvent->condvar->recv;


=head1 DESCRIPTION

This role will help to modify AnyEvent log in you module.


=attr aelog
