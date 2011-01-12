# A script to see if nvcc actually compiles code that runs.

use Test::More tests => 12;
use strict;
use warnings;

# This script has four main parts. First, we ensure that we are in the
# distribution's root directory and include the blib's script diretory in our
# path. Then we run some basic compile tests against .cu files. Third, we run
# more compile tests against .c files. Finally, I define a function that I use
# for a number of tests called compile_and_run.

#####################
# Environment Setup #
#####################

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

# We'll need verbosity to test results:
$ENV{PERL_NVCC_VERBOSE} = 1;

# Make sure we don't encounter the file-already-exists problem:
unlink 'rename_test.cu' if -f 'rename_test.cu';

###################
# CUDA file tests #
###################
# Tests 1-5 for plain C code and plain cuda code, using .cu file extension.

my $compile_output = compile_and_run('t/simple_compile_test.cu', 'good to go!');
like($compile_output, qr/compiler/, 'perl_nvcc runs as compiler for .cu files');
$compile_output = compile_and_run('t/cuda_test.cu', 'Success');

################
# C file tests #
################

# Check that the file renaming, .c => .cu, only happens when we want. The
# default behavior is to rename the file, as is the behavior when the the
# environment variable is set to a true value:
$compile_output = compile_and_run('t/rename_test.c', 'Renamed');
like($compile_output, qr/silently renaming/i
	, 'perl_nvcc properly announces silent renaming');

diag($compile_output);

$ENV{PERL_NVCC_C_AS_CU} = 1;
$compile_output = compile_and_run('t/rename_test.c', 'Renamed');

# If the environment variable is defined but false, it should not rename:
$ENV{PERL_NVCC_C_AS_CU} = 0;
compile_and_run('t/rename_test.c', 'Not renamed');

###################
# compile_and_run #
###################

# Handy function that wraps a number of lines of code that I kept reusing in my
# testing:
sub compile_and_run {
	my ($filename, $match) = @_;

	# Compile the test code:
	my $to_run = join(' ', 'perl_nvcc', '-o', 'test', $filename);
	my $compile_output = `$to_run`;
	# Get the compiler's return value:
	my $results = $?;
	
	# make sure the compilation returns a good result:
	ok($results == 0, "perl_nvcc compiled $filename");
	
	# Run the program:
	$results = `./test`;
	$match = qr/$match/ unless ref($match) eq 'Regexp';
	like($results, $match, "Output of $filename is correct");
	
	# Remove the executable file, and return the results of the compile:
	unlink 'test';
	
	return $compile_output;
}

