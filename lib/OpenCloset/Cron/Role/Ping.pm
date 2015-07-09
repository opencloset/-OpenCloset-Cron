package OpenCloset::Cron::Role::Ping;
# ABSTRACT: OpenCloset cron ping role

use utf8;

use Moo::Role;
use MooX::Types::MooseLike::Base qw( CodeRef );
use namespace::clean -except => 'meta';

our $VERSION = '0.004';

use AnyEvent::HTTPD;
use AnyEvent;

use OpenCloset::Patch::AnyEvent::HTTPD;
use OpenCloset::Patch::Object::Event;

requires 'BUILD';
requires 'httpd';

has ping => (
    is      => 'ro',
    isa     => CodeRef,
    builder => '_builder_ping',
);

sub _builder_ping {
    return sub { return 1; };
}

after BUILD => sub {
    my $self = shift;

    $self->httpd->reg_cb(
        '/ping' => sub {
            my ( $httpd, $req ) = @_;

            if ( $self->ping ) {
                $req->respond( [ 200, 'OK', { 'Content-Type' => 'text/plain' }, "pong\n" ] );
            }
            else {
                $req->respond(
                    [ 400, 'Bad Request', { 'Content-Type' => 'text/plain' }, "failed to pong\n" ] );
            }
        },
    );
};

1;

# COPYRIGHT

__END__

=head1 SYNOPSIS

    package Your::Module;
    use Moo;
    with qw(
        OpenCloset::Cron::Role::HTTPD
        OpenCloset::Cron::Role::Ping
    );

    sub BUILD {
        my $self = shift;

        $self->httpd->reg_cb(
            '' => sub {
                my ( $httpd, $req ) = @_;

                $req->respond([ 404, 'not found', { 'Content-Type' => 'text/plain' }, "not found\n" ]);
            },
        );
    }

    package main;
    use AnyEvent;
    use Your::Module;

    my $ym = Your::Module->new(
        port => 20000,
        ping => sub { return is_alive() ? 1 : 0; },
    );

    $ym->httpd->reg_cb(
        '/foo' => sub {
            my ( $httpd, $req ) = @_;

            $req->respond([ 200, 'OK', { 'Content-Type' => 'text/plain' }, "foo\n" ]);
        },
        '/bar' => sub {
            my ( $httpd, $req ) = @_;

            $req->respond([ 200, 'OK', { 'Content-Type' => 'text/plain' }, "bar\n" ]);
        },
    );

    AnyEvent->condvar->recv;

    sub is_alive { return 1; }

    # $ curl http://localhost:20000/ping
    # pong


=head1 DESCRIPTION

This role will help to equip ping based on HTTP feature in you module.


=attr ping
