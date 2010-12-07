#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 3;

# Add the path to the perl_nvcc script:
$ENV{PATH} = 'blib/script';

# See if the script is in our path. This will return a nasty message telling
# us we didn't provide enough arguments, but that's ok because Perl will
# evaluate that message to true, which is all we need:
my $results = `perl_nvcc`;
ok ($results, 'perl_nvcc is in the test path');

# Test the effects of the environment variables:
$ENV{PERL_NVCC_VERBOSE} = 'yes';
$ENV{PERL_NVCC_DRY_RUN} = 'yes';
$results = `perl_nvcc test.c`;
#diag "Got $results\n";

ok ($results =~ /verbose/s, 'perl_nvcc recognizes verbose environment variable');
ok ($results =~ /dry-run/s, 'perl_nvcc recognizes dry-run environment variable');

# working here