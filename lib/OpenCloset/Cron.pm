package OpenCloset::Cron;
# ABSTRACT: OpenCloset cron daemon module

use utf8;

use Moo;
use MooX::Types::MooseLike::Base qw( ArrayRef Int );
use namespace::clean -except => 'meta';

our $VERSION = '0.002';

extends qw( Object::Event );
with qw(
    OpenCloset::Cron::Role::HTTPD
    OpenCloset::Cron::Role::Ping
);

use AnyEvent;
use Object::Event;

has delay   => ( is => 'ro', isa => Int,      required => 1 );
has workers => ( is => 'ro', isa => ArrayRef, required => 1 );

has _condvar => ( is => 'rw' );
has _timer => (
    is        => 'rw',
    predicate => '_has_timer',
    clearer   => '_clear_timer',
);

sub BUILD {
    my $self = shift;

    $self->reg_cb(
        'start' => sub {
            my $self = shift;

            my $t = AE::timer( $self->delay, 0, sub { $self->event('do.work') } );
            $self->_timer($t);

            my $cv = AnyEvent->condvar;
            $self->_condvar($cv);
            $self->_condvar->recv;
        },
        'stop' => sub {
            my ( $self, $msg ) = @_;
            AE::log warn => $msg if $msg;

            $self->_condvar->send;
        },
        'do.work' => sub {
            my $self = shift;

            $_->register for @{ $self->workers };

            $self->_clear_timer if $self->_has_timer;
            my $t = AE::timer( $self->delay, 0, sub { $self->event('do.work') } );
            $self->_timer($t);
        },
    );

    $self->httpd->reg_cb(
        '' => sub {
            my ( $httpd, $req ) = @_;

            $req->respond(
                [ 404, 'not found', { 'Content-Type' => 'text/plain' }, "not found\n" ] );
        },
        '/stop' => sub {
            my ( $httpd, $req ) = @_;

            $self->event( 'stop', 'stop by httpd' );

            $req->respond( [ 200, 'OK', { 'Content-Type' => 'text/plain' }, "stop\n" ] );
        },
    );
}

sub start { $_[0]->event('start') }
sub stop  { $_[0]->event('stop') }

1;

# COPYRIGHT

__END__

=for Pod::Coverage BUILD

=head1 SYNOPSIS

    use OpenCloset::Cron;
    use OpenCloset::Cron::Worker;

    my $worker1 = do {
        my $w; $w = OpenCloset::Cron::Worker->new(
            name => '1min_cron',
            cron => '* * * * *',
            cb   => sub {
                my $name = $w->name;
                my $cron = $w->cron;
                AE::log( info => "$name\[$cron] 1 minute cron worker" );
            },
        );
    };

    my $worker2 = do {
        my $w; $w = OpenCloset::Cron::Worker->new(
            name => '2min_cron',
            cron => '*/2 * * * *',
            cb   => sub {
                my $name = $w->name;
                my $cron = $w->cron;
                AE::log( info => "$name\[$cron] 2 minute cron worker" );
            },
        );
    };

    my $cron = OpenCloset::Cron->new(
        port    => 8080,
        delay   => 10,
        workers => [ $worker1, $worker2 ],
    );
    $cron->start;


=head1 DESCRIPTION

...


=attr delay

=attr workers

=attr port

See L<OpenCloset::Cron::Role::HTTPD>

=attr httpd

See L<OpenCloset::Cron::Role::HTTPD>

=attr ping

See L<OpenCloset::Cron::Role::Ping>


=method start

=method stop
