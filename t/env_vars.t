#!/usr/bin/perl
use strict;
use warnings;

# A collection of tests that exercise the environment-variable processing of
# perl_nvcc, as well as confirming a few basic behaviors of Perl's interaction
# with the environment.

use Test::More tests => 12;

# Ensure we are in the distribution's root directory (otherwise, including the
# blib in the path will prove futile).
use Cwd;
use File::Spec;
if (cwd =~ /t$/) {
	print "# moving up one directory\n";
	chdir File::Spec->updir() or die "Need to move out of test directory, but can't\n";
}

# Add blib/script to the path:
use Config;
$ENV{PATH} .= $Config{path_sep} . File::Spec->catfile('blib', 'script');

# See if the script is in our path. This will return a nasty message telling
# us we didn't provide enough arguments, but that's ok because Perl will
# evaluate that message to true, which is all we need:
my $results = `perl_nvcc`;
ok ($results, 'perl_nvcc is in the test path');

# Make sure the script gave an angry message since no file was specified:
ok ($results =~ /Nothing to do/, 'perl_nvcc gripes if no file is specified');

# Make sure the verbose variable works
$ENV{PERL_NVCC_VERBOSE} = 'yes';
$results = `perl_nvcc`;
ok ($results =~ /verbose/s, 'perl_nvcc recognizes verbose environment variable');

# Make sure the verbose variable can be unset:
$ENV{PERL_NVCC_VERBOSE} = '';
$results = `perl_nvcc`;
ok ($results !~ /verbose/s, 'perl_nvcc ignores false-valued environment variable');

# Test awareness of the environment variables:
$ENV{PERL_NVCC_VERBOSE} = 'yes';
$ENV{PERL_NVCC_DRY_RUN} = 'yes';
$ENV{PERL_NVCC_MATCHING} = 'yes';
$ENV{PERL_NVCC_NON_MATCHING} = 'yes';
$ENV{PERL_NVCC_MODE} = 'yes';

$results = `perl_nvcc`;

ok ($results =~ /dry-run/s, 'perl_nvcc recognizes dry-run environment variable');
ok ($results =~ /print matching/, 'perl_nvcc recognizes matching environment variable');
ok ($results =~ /print non-matching/, 'perl_nvcc recognizes non-matching environment variable');
ok ($results =~ /compiler\/linker/, 'perl_nvcc recognizes mode environment variable');

# Check the effects of true, false and non-setting of PERL_NVCC_C_AS_CU.
# For the first round, it wasn't set; I shouldn't get any messages about
# renaming:
ok ($results !~ /renaming/i, 'In dry-run mode, perl_nvcc says nothing about renaming when PERL_NVCC_C_AS_CU is not set');
# Now set it to something true and see what happens:
$ENV{PERL_NVCC_C_AS_CU} = 'yes';
$results = `perl_nvcc`;
ok ($results =~ /Renaming/, 'perl_nvcc recognizes rename environment variable');
# Set it to something explicitly false:
$ENV{PERL_NVCC_C_AS_CU} = '';
$results = `perl_nvcc`;
ok ($results =~ /Not renaming/, 'perl_nvcc recognizes false-but-defined rename environment variable');
# Check that removing the key actually undefines the variable
delete $ENV{PERL_NVCC_C_AS_CU};
$results = `perl_nvcc`;
ok ($results !~ /renaming/i, 'deleting key from \%ENV is different from specifying a false value');

# working here: test the file-already-exists problem:
# 1) create rename_test.cu (with whatever contents; could be empty)
# 2) run perl_nvcc against rename_test.c
# 3) make sure that perl_nvcc croaks

