package Mojolicious::Plugin::Model;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::Util 'camelize';
use Scalar::Util 'weaken';

our $VERSION = '0.02';

has models => sub { {} };

sub register {
  my ($plugin, $app, $conf) = @_;

  my $moniker = camelize $app->moniker;
  my $base = $conf->{namespace} // "${moniker}::Model";

  eval <<CODE;
package $base;
use Mojo::Base -base;
has 'app';
1;
CODE

  $app->helper(
    model => sub {
      my ($self, $name) = @_;

      my $model;
      return $model if $model = $plugin->models->{$name};

      my $class = sprintf '%s::%s', $base, camelize $name;
      eval "require $class";
      if ($@) {
        $app->log->error("[Mojolicious::Plugin::Model] Error while loading $name ($class): $@");
        return undef;
      }

      $model = $class->new(app => $app);
      weaken $model->{app};

      $plugin->models->{$name} = $model;
      return $model;
    }
  );
}

1;

__END__

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Model - Model for Mojolicious applications

=head1 SYNOPSIS

Model Users

  package MyApp::Model::Users;
  use Mojo::Base 'MyApp::Model';

  sub check {
    my ($self, $name, $pass) = @_;

    # Constant
    return int rand 2;

    # Or Mojo::Pg
    return $self->app->pg->db->query('...')->array->[0];

    # Or HTTP check
    return $self->app->ua->post($url => json => {user => $name, pass => $pass})
      ->rex->tx->json('/result');
  }

  1;

Model Users-Client

  package MyApp::Model::Users::Client;
  use Mojo::Base 'MyApp::Model::User';

  sub do {
    my ($self) = @_;
  }

  1;

Mojolicious::Lite application

  #!/usr/bin/env perl
  use Mojolicious::Lite;

  use lib 'lib';

  plugin 'Model';

  # /?user=sebastian&pass=secr3t
  any '/' => sub {
    my $c = shift;

    my $user = $c->param('user') || '';
    my $pass = $c->param('pass') || '';

    # client model
    my $client = $c->model('users-client');
    $client->do();

    return $c->render(text => "Welcome $user.") if $c->model('users')->check($user, $pass);
    $c->render(text => 'Wrong username or password.');
  };

  app->start;

=head1 DESCRIPTION

L<Mojolicious::Plugin::Model> is a Model (M in MVC architecture) for Mojolicious applications. Each
model has an C<app> attribute.

=head1 OPTIONS

L<Mojolicious::Plugin::Model> supports the following options.

=head2 namespace

  # Mojolicious::Lite
  plugin Model => {namespace => 'MyApp::Controller::Module'};

Namespace for model classes. Default to C<$moniker::Model>.

=head1 HELPERS

L<Mojolicious::Plugin::Model> implements the following helpers.

=head2 model

  my $model = $c->model('users');

Create and cache a model object with given name.

=head1 METHODS

L<Mojolicious::Plugin::Model> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register(Mojolicious->new);

Register plugin in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=head1 AUTHOR

Andrey Khozov, C<avkhozov@googlemail.com>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2015, Andrey Khozov.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
