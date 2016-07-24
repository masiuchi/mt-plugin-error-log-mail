package MT::Plugin::ErrorLogMail::Callbaack;
use strict;
use warnings;

use MT;
use MT::Author;
use MT::Mail;

my @log_fields
    = qw( id message ip blog_id author_id level category metadata );

sub post_save_log {
    my ( $obj, $orig_obj ) = @_;

    my $after_create    = !$orig_obj;
    my $match_log_level = $obj->level & MT->config->ErrorLogMailLevel;
    my $oldest_admin    = _oldest_admin();

    if ( $after_create && $match_log_level && $oldest_admin ) {
        _send_mail( $obj, $oldest_admin );
    }
}

sub _send_mail {
    my ( $log, $user ) = @_;
    my $headers = _mail_headers( $log, $user );
    my $body = _mail_body($log);
    MT::Mail->send( $headers, $body );
}

sub _mail_body {
    my $log  = shift;
    my $body = "";
    for my $field (@log_fields) {
        $body .= "$field: " . $log->$field . "\n";
    }
    $body;
}

sub _mail_headers {
    my ( $log, $user ) = @_;
    +{  From    => $user->email,
        To      => $user->email,
        Subject => _mail_subject($log),
    };
}

sub _mail_subject {
    my ($log)   = @_;
    my $level   = _log_level_string($log);
    my $message = $log->message;
    "[$level] $message";
}

sub _log_level_string {
    my ($log) = @_;
    return 'INFO'     if $log->level == 1;
    return 'WARNING'  if $log->level == 2;
    return 'ERROR'    if $log->level == 4;
    return 'SECURITY' if $log->level == 8;
    return 'DEBUG'    if $log->level == 16;
    return 'UNKNOWN';
}

sub _oldest_admin {
    my $iter = MT::Author->load_iter( undef, { sort => 'id' } );
    while ( my $user = $iter->() ) {
        return $user if $user->is_superuser;
    }
    undef;
}

1;

