package OpenCloset::Cron::Worker;
# ABSTRACT: OpenCloset cron worker module

use utf8;

use Moo;
use MooX::Types::MooseLike::Base qw( CodeRef Str );
use namespace::clean -except => 'meta';

our $VERSION = '0.002';

use AnyEvent::Timer::Cron;
use AnyEvent;
use Scalar::Util qw( weaken );

has name => ( is => 'ro', isa => Str,     required => 1 );
has cron => ( is => 'ro', isa => Str,     required => 1 );
has cb   => ( is => 'rw', isa => CodeRef, builder  => '_default_cb' );

sub _default_cb {
    my $self = shift;

    weaken($self);
    return sub {
        my $name = $self->name;
        my $cron = $self->cron;
        AE::log( info => "$name\[$cron] dummy cron worker" );
    };
}

has _timer => (
    is        => 'rw',
    predicate => '_has_timer',
    clearer   => '_clear_timer',
);

has _cron => (
    is        => 'rw',
    predicate => '_has_cron',
    clearer   => '_clear_cron',
);

sub register {
    my $self = shift;

    my $name = $self->name;
    my $cron = $self->cron;
    my $cb   = $self->cb;

    $cron //= q{};
    AE::log( debug => "$name: cron[$cron]" );

    if ( !$cron || $cron =~ /^\s*$/ ) {
        if ( $self->_has_timer ) {
            AE::log( info => "$name: clearing timer, cron rule is empty" );
            $self->_clear_cron;
            $self->_clear_timer;
        }
        return;
    }

    my @cron_items = split q{ }, $cron;
    unless ( @cron_items == 5 ) {
        AE::log( warn => "$name: invalid cron format" );
        return;
    }

    if ( $self->_has_timer ) {
        AE::log( debug => "$name: timer is already exists" );

        if ( $cron && $cron eq $self->_cron ) {
            return;
        }
        AE::log( info => "$name: clearing timer before register" );
        $self->_clear_cron;
        $self->_clear_timer;
    }

    AE::log( info => "$name: register [$cron]" );
    my $cron_timer = AnyEvent::Timer::Cron->new(
        cron => $cron,
        cb   => $cb,
    );
    $self->_cron($cron);
    $self->_timer($cron_timer);
}

1;

# COPYRIGHT

__END__

=head1 SYNOPSIS

    use OpenCloset::Cron::Worker;

    my $worker1 = do {
        my $w; $w = OpenCloset::Cron::Worker->new(
            name => '1min_cron',
            cron => '* * * * *',
            cb   => sub {
                my $name = $w->name;
                my $cron = $w->cron;
                AE::log( info => "$name $cron 1 minute cron worker" );
            },
        );
    };


=head1 DESCRIPTION

...


=attr name

=attr cron

=attr cb

=method register
