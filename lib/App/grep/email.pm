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

        comment_contains => {
            schema => 'str*',
            tags => ['category:email-criteria'],
        },
        comment_not_contains => {
            schema => 'str*',
            tags => ['category:email-criteria'],
        },
        comment_matches => {
            schema => 're*',
            tags => ['category:email-criteria'],
        },

        address_contains => {
            schema => 'str*',
            tags => ['category:email-criteria'],
        },
        address_not_contains => {
            schema => 'str*',
            tags => ['category:email-criteria'],
        },
        address_matches => {
            schema => 're*',
            tags => ['category:email-criteria'],
        },

        host_contains => {
            schema => 'str*',
            tags => ['category:email-criteria'],
        },
        host_not_contains => {
            schema => 'str*',
            tags => ['category:email-criteria'],
        },
        host_matches => {
            schema => 're*',
            tags => ['category:email-criteria'],
        },

        user_contains => {
            schema => 'str*',
            tags => ['category:email-criteria'],
        },
        user_not_contains => {
            schema => 'str*',
            tags => ['category:email-criteria'],
        },
        user_matches => {
            schema => 're*',
            tags => ['category:email-criteria'],
        },

        name_contains => {
            schema => 'str*',
            tags => ['category:email-criteria'],
        },
        name_not_contains => {
            schema => 'str*',
            tags => ['category:email-criteria'],
        },
        name_matches => {
            schema => 're*',
            tags => ['category:email-criteria'],
        },

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

        my $re = qr/(?:\b|\A)$Regexp::Pattern::Email::RE{email_address}{pat}(?:\b|\z)/;

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

                # comment criteria
                if (defined $fargs->{comment_contains}) {
                    if ($fargs->{ignore_case} ?
                         index(lc($email->comment), lc($fargs->{comment_contains})) >= 0 :
                         index($email->comment    , $fargs->{comment_contains})     >= 0) {
                    } else {
                        next;
                    }
                }
                if (defined $fargs->{comment_not_contains}) {
                    if ($fargs->{ignore_case} ?
                         index(lc($email->comment), lc($fargs->{comment_not_contains})) < 0 :
                         index($email->comment    , $fargs->{comment_not_contains})     < 0) {
                    } else {
                        next;
                    }
                }
                if (defined $fargs->{comment_matches}) {
                    if ($fargs->{ignore_case} ?
                            $email->comment =~ qr/$fargs->{comment_matches}/i :
                            $email->comment =~ qr/$fargs->{comment_matches}/) {
                    } else {
                        next;
                    }
                }

                # address criteria
                if (defined $fargs->{address_contains}) {
                    if ($fargs->{ignore_case} ?
                         index(lc($email->address), lc($fargs->{address_contains})) >= 0 :
                         index($email->address    , $fargs->{address_contains})     >= 0) {
                    } else {
                        next;
                    }
                }
                if (defined $fargs->{address_not_contains}) {
                    if ($fargs->{ignore_case} ?
                         index(lc($email->address), lc($fargs->{address_not_contains})) < 0 :
                         index($email->address    , $fargs->{address_not_contains})     < 0) {
                    } else {
                        next;
                    }
                }
                if (defined $fargs->{address_matches}) {
                    if ($fargs->{ignore_case} ?
                            $email->address =~ qr/$fargs->{address_matches}/i :
                            $email->address =~ qr/$fargs->{address_matches}/) {
                    } else {
                        next;
                    }
                }

                # host criteria
                if (defined $fargs->{host_contains}) {
                    if ($fargs->{ignore_case} ?
                         index(lc($email->host), lc($fargs->{host_contains})) >= 0 :
                         index($email->host    , $fargs->{host_contains})     >= 0) {
                    } else {
                        next;
                    }
                }
                if (defined $fargs->{host_not_contains}) {
                    if ($fargs->{ignore_case} ?
                         index(lc($email->host), lc($fargs->{host_not_contains})) < 0 :
                         index($email->host    , $fargs->{host_not_contains})     < 0) {
                    } else {
                        next;
                    }
                }
                if (defined $fargs->{host_matches}) {
                    if ($fargs->{ignore_case} ?
                            $email->host =~ qr/$fargs->{host_matches}/i :
                            $email->host =~ qr/$fargs->{host_matches}/) {
                    } else {
                        next;
                    }
                }

                # user criteria
                if (defined $fargs->{user_contains}) {
                    if ($fargs->{ignore_case} ?
                         index(lc($email->user), lc($fargs->{user_contains})) >= 0 :
                         index($email->user    , $fargs->{user_contains})     >= 0) {
                    } else {
                        next;
                    }
                }
                if (defined $fargs->{user_not_contains}) {
                    if ($fargs->{ignore_case} ?
                         index(lc($email->user), lc($fargs->{user_not_contains})) < 0 :
                         index($email->user    , $fargs->{user_not_contains})     < 0) {
                    } else {
                        next;
                    }
                }
                if (defined $fargs->{user_matches}) {
                    if ($fargs->{ignore_case} ?
                            $email->user =~ qr/$fargs->{user_matches}/i :
                            $email->user =~ qr/$fargs->{user_matches}/) {
                    } else {
                        next;
                    }
                }

                # name criteria
                if (defined $fargs->{name_contains}) {
                    if ($fargs->{ignore_case} ?
                         index(lc($email->name), lc($fargs->{name_contains})) >= 0 :
                         index($email->name    , $fargs->{name_contains})     >= 0) {
                    } else {
                        next;
                    }
                }
                if (defined $fargs->{name_not_contains}) {
                    if ($fargs->{ignore_case} ?
                         index(lc($email->name), lc($fargs->{name_not_contains})) < 0 :
                         index($email->name    , $fargs->{name_not_contains})     < 0) {
                    } else {
                        next;
                    }
                }
                if (defined $fargs->{name_matches}) {
                    if ($fargs->{ignore_case} ?
                            $email->name =~ qr/$fargs->{name_matches}/i :
                            $email->name =~ qr/$fargs->{name_matches}/) {
                    } else {
                        next;
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
