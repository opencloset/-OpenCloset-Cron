package OpenCloset::Cron::Role::HTTPD;
# ABSTRACT: OpenCloset cron httpd role

use utf8;

use Moo::Role;
use MooX::Types::MooseLike::Base qw( Int );
use namespace::clean -except => 'meta';

our $VERSION = '0.001';

use AnyEvent::HTTPD;
use AnyEvent;

use OpenCloset::Patch::AnyEvent::HTTPD;
use OpenCloset::Patch::Object::Event;

has port => ( is => 'ro', isa => Int, required => 1 );
has httpd => ( is => 'lazy' );

sub _build_httpd {
    my $self = shift;

    my $httpd = AnyEvent::HTTPD->new( port => $self->port );
    $httpd->reg_cb(
        'auto' => sub {
            my ( $httpd, $req ) = @_;

            AE::log info => sprintf( 'HTTP-REQ [%s:%s]->[%s:%s] %s',
                $req->client_host, $req->client_port, $httpd->host, $httpd->port, $req->url );
        },
    );

    return $httpd;
}

1;

# COPYRIGHT

__END__

=head1 SYNOPSIS

    package Your::Module;
    use Moo;
    with qw( OpenCloset::Cron::Role::HTTPD );

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

    # $ curl http://localhost:20000/foo
    # foo
    # $ curl http://localhost:20000/bar
    # bar
    # $ curl http://localhost:20000/
    # not found


=head1 DESCRIPTION

This role will help to equip HTTPD feature in you module.


=attr port

Specify ping port via HTTP. Read-only.
No default value.

    my $ym = Your::Module->new(
        port => 20000,
    );


=attr httpd
