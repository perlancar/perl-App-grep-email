package App::grep::email;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

use AppBase::Grep;
use Perinci::Sub::Util qw(gen_modified_sub);

our %SPEC;

gen_modified_sub(
    output_name => 'grep_email',
    base_name   => 'AppBase::Grep::grep',
    summary     => 'Print lines having email address(es) (optionally of certain criteria) in them',
    description => <<'_',

This is a grep-like utility that greps for emails of certain criteria.

_
    remove_args => [
        'regexps',
        'pattern',
        'dash_prefix_inverts',
        'all',
    ],
    add_args    => {
        min_emails => {
            schema => 'uint*',
            default => 1,
            tags => ['category:filtering'],
        },
        max_emails => {
            schema => 'int*',
            default => -1,
            tags => ['category:filtering'],
        },

        # TODO: comment_contains, comment_not_contains, comment_matches
        # TODO: address_contains, address_not_contains, address_matches
        # TODO: user_contains, user_not_contains, user_matches
        # TODO: name_contains, name_not_contains, name_matches

        files => {
            'x.name.is_plural' => 1,
            'x.name.singular' => 'file',
            schema => ['array*', of=>'filename*'],
            pos => 0,
            slurpy => 1,
        },

        # XXX recursive (-r)
    },
    modify_meta => sub {
        my $meta = shift;
        $meta->{examples} = [
            {
                summary => 'Show lines that contain at least 2 emails',
                'src' => q([[prog]] --min-emails 2 file.txt),
                'src_plang' => 'bash',
                'test' => 0,
                'x.doc.show_result' => 0,
            },
            {
                summary => 'Show lines that contain emails from gmail',
                'src' => q([[prog]] --host-contains gmail.com file.txt),
                'src_plang' => 'bash',
                'test' => 0,
                'x.doc.show_result' => 0,
            },
        ];

        $meta->{links} = [
            {url=>'prog:grep-url'},
        ];
    },
    output_code => sub {
        my %args = @_;
        my ($fh, $file);

        my @files = @{ delete($args{files}) // [] };

        my $show_label = 0;
        if (!@files) {
            $fh = \*STDIN;
        } elsif (@files > 1) {
            $show_label = 1;
        }

        $args{_source} = sub {
          READ_LINE:
            {
                if (!defined $fh) {
                    return unless @files;
                    $file = shift @files;
                    log_trace "Opening $file ...";
                    open $fh, "<", $file or do {
                        warn "abgrep: Can't open '$file': $!, skipped\n";
                        undef $fh;
                    };
                    redo READ_LINE;
                }

                my $line = <$fh>;
                if (defined $line) {
                    return ($line, $show_label ? $file : undef);
                } else {
                    undef $fh;
                    redo READ_LINE;
                }
            }
        };

        require Regexp::Pattern::Email;
        require Email::Address;

        my $re = qr/\b$Regexp::Pattern::Email::Address::RE{email_address}{pat}\b/;

        $args{_highlight_regexp} = $re;
        $args{_filter_code} = sub {
            my ($line, $fargs) = @_;

            my @emails;
            while ($line =~ /($re)/g) {
                push @emails, $1;
            }
            return 0 if $fargs->{min_emails} >= 0 && @emails < $fargs->{min_emails};
            return 0 if $fargs->{max_emails} >= 0 && @emails > $fargs->{max_emails};

            return 1 unless @emails;
            my @email_objs;
            for (@emails) { push @email_objs, Email::Address->parse($_) }

            my $match = 0;
          URL:
            for my $email (@email_objs) {

                # scheme criteria
                if (defined $fargs->{scheme_contains}) {
                    if ($fargs->{ignore_case} ?
                         index(lc($url->scheme), lc($fargs->{scheme_contains})) >= 0 :
                         index($url->scheme    , $fargs->{scheme_contains})     >= 0) {
                    } else {
                        next;
                    }
                }
                if (defined $fargs->{scheme_not_contains}) {
                    if ($fargs->{ignore_case} ?
                         index(lc($url->scheme), lc($fargs->{scheme_not_contains})) < 0 :
                         index($url->scheme    , $fargs->{scheme_not_contains})     < 0) {
                    } else {
                        next;
                    }
                }
                if (defined $fargs->{scheme_matches}) {
                    if ($fargs->{ignore_case} ?
                            $url->scheme =~ qr/$fargs->{scheme_matches}/i :
                            $url->scheme =~ qr/$fargs->{scheme_matches}/) {
                    } else {
                        next;
                    }
                }

                # host criteria
                if (defined $fargs->{host_contains}) {
                    if ($fargs->{ignore_case} ?
                         index(lc($url->host), lc($fargs->{host_contains})) >= 0 :
                         index($url->host    , $fargs->{host_contains})     >= 0) {
                    } else {
                        next;
                    }
                }
                if (defined $fargs->{host_not_contains}) {
                    if ($fargs->{ignore_case} ?
                         index(lc($url->host), lc($fargs->{host_not_contains})) < 0 :
                         index($url->host    , $fargs->{host_not_contains})     < 0) {
                    } else {
                        next;
                    }
                }
                if (defined $fargs->{host_matches}) {
                    if ($fargs->{ignore_case} ?
                            $url->host =~ qr/$fargs->{host_matches}/i :
                            $url->host =~ qr/$fargs->{host_matches}/) {
                    } else {
                        next;
                    }
                }

                # path criteria
                if (defined $fargs->{path_contains}) {
                    if ($fargs->{ignore_case} ?
                         index(lc($url->path), lc($fargs->{path_contains})) >= 0 :
                         index($url->path    , $fargs->{path_contains})     >= 0) {
                    } else {
                        next;
                    }
                }
                if (defined $fargs->{path_not_contains}) {
                    if ($fargs->{ignore_case} ?
                         index(lc($url->path), lc($fargs->{path_not_contains})) < 0 :
                         index($url->path    , $fargs->{path_not_contains})     < 0) {
                    } else {
                        next;
                    }
                }
                if (defined $fargs->{path_matches}) {
                    if ($fargs->{ignore_case} ?
                            $url->path =~ qr/$fargs->{path_matches}/i :
                            $url->path =~ qr/$fargs->{path_matches}/) {
                    } else {
                        next;
                    }
                }

                # query param criteria
                if (defined $fargs->{query_param_contains}) {
                    for my $param (keys %{ $fargs->{query_param_contains} }) {
                        if ($fargs->{ignore_case} ?
                                index((lc($url->query_param($param)) // ''), lc($fargs->{query_param_contains}{$param})) >= 0 :
                                index(($url->query_param($param)  // '')   , $fargs->{query_param_contains}{$param})     >= 0) {
                        } else {
                            next URL;
                        }
                    }
                }
                if (defined $fargs->{query_param_not_contains}) {
                    for my $param (keys %{ $fargs->{query_param_not_contains} }) {
                        if ($fargs->{ignore_case} ?
                                index((lc($url->query_param($param)) // ''), lc($fargs->{query_param_not_contains}{$param})) < 0 :
                                index(($url->query_param($param) // '')    , $fargs->{query_param_not_contains}{$param})     < 0) {
                        } else {
                            next URL;
                        }
                    }
                }
                if (defined $fargs->{query_param_matches}) {
                    for my $param (keys %{ $fargs->{query_param_matches} }) {
                        if ($fargs->{ignore_case} ?
                                ($url->query_param($param) // '') =~ qr/$fargs->{query_param_matches}{$param}/i :
                                ($url->query_param($param) // '') =~ qr/$fargs->{query_param_matches}{$param}/) {
                        } else {
                            next URL;
                        }
                    }
                }

                $match++; last;
            }
            $match;
        };

        AppBase::Grep::grep(%args);
    },
);

1;
# ABSTRACT:
