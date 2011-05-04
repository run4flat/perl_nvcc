=head1 NAME

ExtUtils::nvcc - CUDA compiler and linker wrapper for Perl's toolchain

=cut

use strict;
use warnings;

# These are necessary for Module::Build to work simply:
package ExtUtils::nvcc;
use vars qw($VERSION);
$VERSION = '0.01';

# For errors, of course:
use Carp qw(:all);

=head1 SYNOPSES

=head2 Inline::C

 #!/usr/bin/perl
 use strict;
 use warnings;
 
 # Here's the magic sauce
 
 use Inline C => DATA => CC => "$^X -MExtUtils::nvcc -ecompile"
        , LD => "$^X -MExtUtils::nvcc -elink"
        ;
 
 # The rest of this is just a working example
 
 # Generate a series of 100 sequential values and pack them
 # as an array of floats:
 my $data = pack('f*', 1..100); 
 
 # Call the Perl-callable wrapper to the CUDA kernel:
 cuda_test($data);
 
 # Print the results
 print "Got ", join (', ', unpack('f*', $data)), "\n";
 
 END {
     # I am having trouble with memory leaks. This messgae
     # indicates that the segmentation fault occurrs after
     # the end of the script's execution.
     print "Really done!\n";
 }
 
 __END__
 
 __C__
 
 // This is a very simple CUDA kernel that triples the value of the
 // global data associated with the location at threadIdx.x. NOTE: this
 // is a particularly good example of BAD programming - it should be
 // more defensive. It is just a proof of concept, to show that you can
 // indeed write CUDA kernels using Inline::C.
 
 __global__ void triple(float * data_g) {
     data_g[threadIdx.x] *= 3;
 }
 
 // NOTE: Do not make such a kernel a regular habit. Generally, copying
 // data to and from the device is very, very slow (compared with all
 // other CUDA operations). This is just a proof of concept.
 
 void cuda_test(char * input) {
     // Inline::C knows how to massage a Perl scalar into a char
     // array (pointer), which I can easily cast as a float pointer:
     float * data = (float * ) input;
     
     // Allocate the memory of the device:
     float * data_d;
     unsigned int data_bytes = sizeof(float) * 100;
     cudaMalloc(&data_d, data_bytes);
  
    // Copy the host memory to the device:
     cudaMemcpy(data_d, data, data_bytes, cudaMemcpyHostToDevice);
     
     // Print a status indicator and execuate the kernel
     printf("Trippling values via CUDA\n");
 
     // Execute the kernel:
     triple <<<1, 100>>>(data_d);
     
     // Copy the contents back to the Perl scalar:
     cudaMemcpy(data, data_d, data_bytes, cudaMemcpyDeviceToHost);
     
     // Free the device memory
     cudaFree(data_d);
 }

=head2 ExtUtils::MakeMaker

 # In your Makefile.PL:
 WriteMakefile(
     # ... other options ...
	 CC => "$^X -MExtUtils::nvcc -ecompile",
     LD => "$^X -MExtUtils::nvcc -elink",
     
 );

=head2 Module::Build

 # In your Build.PL file:
 my $build = Module::Build->new(
     # ... other options ...
     config => {cc => "$^X -MExtUtils::nvcc -ecompile",
                ld => "$^X -MExtUtils::nvcc -elink"},
 );


=head1 DESCRIPTION

This module provides functionality to preprocess and wrap arguments
that would normally go to gcc. After processing the arguments, it calls
nvcc, nVidia's compiler wrapper, supplying the same arguments in a way
that nvcc can digest them.

To use this, the basic recipe involves replacing the compiler and
linker options with the strings C<"$^X -MExtUtils::nvcc -ecompile">
and C<"$^X -MExtUtils::nvcc -elink">, respectively.

The library provides a number of functions, but only exports C<compile>
and C<link>, which go through the argument list and call other library
functions to process what they see.

=head2 compile

The compile function processes all arguments in C<@ARGS>, ensures that
the source file ends in a .cu extension, and invokes nvcc as a compiler.

nvcc's behavior depends on the filename's ending (can't set it with a flag, as
far as I can tell), so filenames with CUDA code must have a .cu ending. However,
the Inline::C and pretty much any utility that creates XS extensions for Perl)
sends files with a .c file extension to the compiler. To make
this work as a drop-in replacement for gcc in Inline::C, this needs to send .cu
files to nvcc whenever it encounters .c files.

The way this is actually implemented, C<ExtUtils::nvcc> first tries to create a symbolic
link to the .c file with the .cu extension; it then tries a hard link; it last
tries a direct copy. If none of these work, perl_nvcc croaks. In particular, you
will encounter trouble if you try to compile a .c file and you
have an identically named .cu file.

=cut

################################################################################
# Usage			: compile()
# Purpose		: Process the command-line arguments and send digestable
#				: arguments to nvcc in compiler mode.
# Returns		: nothing
# Parameters	: none
# Throws		: if there are no arguments or no source files.
# Comments		: Most of the hard work is done by process_args
# See also		: link

sub compile {
	# First make sure that we have arguments (since I'll need a file to
	# compile, in the very least):
	die "Nothing to do! You didn't give me any arguments, not even a file!\n"
		unless @ARGV;
	
	# Get the nvcc args, the compiler args, and the source files:
	my ($nvcc_args, $other_args, $source_files) = process_args(@ARGV);
	
	# Unpack array refs into normal arrays
	my @nvcc_args = @$nvcc_args;
	my @other_args = @$other_args;
	my @source_files = @$source_files;
	
	# rename the source files if they end in .c
	# (croak if they don't end in .c?)
	foreach (@source_files) {
		if (/\.c$/) {
			make_cu_file($_);
			s/\.c$/.cu/;
		}
	}
	
	# Make sure they provided at least one source file:
	die "You must provide at least one source file\n"
		unless @source_files;
	
	# Set up the flags for the compiler arguments:
	unshift @nvcc_args, ("-Xcompiler=" . join ',', @other_args)
		if @other_args;
	
	# Run nvcc in an eval block in case of errors:
	eval {run_nvcc(@nvcc_args, @source_files) };
	
	# Remove the .cu files and finish with death if nvcc failed:
	unlink $_ foreach @source_files;
	die $@ if $@;
}

=head2 link

The link function processes all arguments in C<@ARGS>, and invokes nvcc
as a linker with properly modified arguments.

=cut

################################################################################
# Usage			: link()
# Purpose		: Process the command-line arguments and send digestable
#				: arguments to nvcc in linker mode.
# Returns		: nothing
# Parameters	: none
# Throws		: if there are no arguments or no source files.
# Comments		: Most of the hard work is done by process_args
# See also		: compile

sub link {
	# First make sure that we have arguments (since I'll need a file to
	# link, in the very least):
	die "Nothing to do! You didn't give me any arguments, not even a file!\n"
		unless @ARGV;
	
	# Get the nvcc args, the compiler args, and the source files:
	my ($nvcc_args, $other_args, $source_files) = process_args(@ARGV);
	
	# Unpack array refs into normal arrays
	my @nvcc_args = @$nvcc_args;
	my @other_args = @$other_args;
	my @source_files = @$source_files;
	
	# Make sure they provided at least one source file:
	die "You must provide at least one source file\n"
		unless @source_files;
	
	# Set up the flags for the compiler arguments:
	unshift @nvcc_args, ("-Xlinker=" . join ',', @other_args)
		if @other_args;
	
	# Run nvcc in an eval block in case of errors:
	eval {run_nvcc(@nvcc_args, @source_files) };
	
	# finish with death if nvcc failed:
	die $@ if $@;
}

=head2 run_nvcc

Runs nvcc with the supplied list of nvcc-compatible command-line arguments,
using the L<system> Perl function.

If the system call fails, run_nvcc checks that it can find nvcc in the first
place, and croaks with one of two messages:

=over

=item nvcc encountered a problem

This message means that nvcc is in your path but the system call failed, which
means that the compile didn't like what you sent it.

=item Unable to run nvcc. Is it in your path?

This message means that nvcc cannot be found. Make sure you've installed nVidia's
toolkit and double-check your path settings.

=back

To use, try something like this:

 eval {run_nvcc qw(my_source.cu -o my_program)};
 
 # Die if there was an error:
 die $@ if $@;

=cut

################################################################################
# Usage			: run_nvcc(@args)
# Purpose		: Run nvcc with the supplied arguments and die if errors.
# Returns		: nothing
# Parameters	: command-line arguments for nvcc
# Throws		: if nvcc fails; gives different exception if nvcc is
#				: or is not available
# Comments		: 
# See also		: compile, link

sub run_nvcc {
	# Run the nvcc command and return the results:
	my $results = system('nvcc', @_);

	# Make sure things didn't go bad:
	if ($results != 0) {
		# Can't find it in the path! Of course it'll fail!
		die "Unable to run nvcc. Is it in your path?\n" unless `nvcc -V`;
		
		# If nvcc is available, it must be compiler error:
		die "nvcc encountered a problem\n";
	}
}

=head2 process_args

Processes the list of supplied (gcc-style) arguments, seperating out 
nvcc-compatible arguments, and nvcc-incompatible arguments, and source file
names. The resulting lists are returned by reference in that order.

Here's a usage example:

 # Get the nvcc args, the compiler args, and the source files:
 my ($nvcc_args, $other_args, $source_files) = process_args(@ARGV);
 
 # Unpack array refs into normal arrays
 my @nvcc_args = @$nvcc_args;
 my @other_args = @$other_args;
 my @source_files = @$source_files;


=cut

################################################################################
# Usage			: ($nvcc_args, $other_args, $files) = process_args(@array)
# Purpose		: Process the command-line arguments, seperating out the nvcc-
#				: compatible options from the source file names and the other
#				: compiler options.
# Returns		: Three array references containing
#				:	- nvcc args
#				:	- other args
#				:	- file names
# Parameters	: The array of command-line options to be processed.
# Throws		: if the last argument was expecting a value, such as -o file.o
#				: but without the file.o bit.
# Comments		: The means by which this function performs its work is hackish,
#				: but I doubt it needs to be improved except possibly for
#				: legibility. Perhaps all of these options can be seperated into
#				: some text file, or put in the __DATA__ section, in more readable
#				: form and then parsed once upon loading?
# See also		: compile, link


sub process_args {
	my (@nvcc_args, @extra_options, @source_files);
	my $include_next_arg = 0;

	foreach (@_) {
		# First check if the next arg was flagged as something to include (as
		# an argument to the previous option). 
		if ($include_next_arg) {
			push @nvcc_args, $_;
			$include_next_arg = 0;
		}
		elsif (
			# check if it's an nvcc-safe flag or option, and pass it along if so:
			
			# Make sure the argument is a valid argument. These are the valid flags
			# (i.e. options that do not take values)
			m{^-(?:
				[EMcgv]|cuda|cubin|fatbin|ptx|gpu|lib|pg|extdeb|shared
				|noprof|foreign|dryrun|keep|clean|deviceemu|use_fast_math
			)$}x
			or
			m{^--(?:
				cuda|cubin|fatbin|ptx|gpu|preprocess|generate-dependencies|lib
				|profile|debug|extern-debug-info|shared|dont-use-profile|foreign
				|dryrun|verbose|keep|clean-targets|no-align-double
				|device-emulation|use_fast_math
			)$}x
			# These are valid command-line options with associated values, but which
			# don't have an = seperating the option from the value
			m/^-[lLDUIoOmG]./
			or
			# These are valid command-line options that have an = seperating the
			# option from the value.
			m{^-(?:
				include|isystem|odir|ccbin
				|X(?:compiler|linker|opencc|cudafe|ptxas|fatbin)
				|idp|ddp|dp|arch|code|gencode|dir|ext|int
				|maxrregcount|ftz|prec-div|prec-sqrt
			)=.+}x
			or 
			m{^--(?:
				output-file|pre-include|library|define-macro|undefine-macro
				|include-path|system-include|library-path|output-directory
				|compiler-bindir|device-debug|optimize|machine|compiler-options
				|linker-options|opencc-options|cudafe-options|ptxas-options
				|fatbin-options|input-drive-prefix|dependency-drive-prefix
				|gpu-name|gpu-code|generate-code|export-dir|extern-mode
				|intern-mode|maxrregcount|ftz|prec-div|prec-sqrt|host-compilation
				|options-file
			)=.+}x
		) {
			# Matches one of the many known flags; include in nvcc args
			push @nvcc_args, $_;
		}
		# Check if this is a bare flag that sets an option and allows a space
		# between it and the option. That indicates that the next option should
		# be passed along untouched
		# XXX - these must be verified!!!
		elsif (
			m{^-(?:
				[oDUlLImG]|include|isystem|odir|ccbin
				|X(?:compiler|linker|opencc|cudafe|ptxas|fatbin)
				|idp|ddp|dp|arch|code|gencode|dir|ext|int
				|maxrregcount|ftz|prec-div|prec-sqrt
			)$}x
			or
			m{^--(?:
				output-file|pre-include|library|define-macro|undefine-macro
				|include-path|system-include|library-path|output-directory
				|compiler-bindir|device-debug|optimize|machine|compiler-options
				|linker-options|opencc-options|cudafe-options|ptxas-options
				|fatbin-options|input-drive-prefix|dependency-drive-prefix
				|gpu-name|gpu-code|generate-code|export-dir|extern-mode
				|intern-mode|maxrregcount|ftz|prec-div|prec-sqrt|host-compilation
				|options-file
			)$}x
		) {
			# If those are found without equal signs after them, include them
			# as an nvcc_arg and indicate that the next arg should also be included
			push @nvcc_args, $_;
			$include_next_arg = 1;
		}
		# Otherwise pull it out and add it to the collection of external flags and
		# options.
		elsif (/^-/) {
			push @extra_options, $_;
		}
		# If there is no dash, it's just a source filename.
		else {
			push @source_files, $_;
		}
	}
	
	# The last option should not leave the loop expecting an entry, so check for that
	# and croak if that's the case:
	croak ("Last argument [[" . $_[-1] . "]] left me expecting a value, but I didn't find one\n")
		if $include_next_arg;
	
	return (\@nvcc_args, \@other_args, \@source_files);
}

=head2 make_cu_file

Takes a C source file with a .c extension and makes an associated .cu file. Sure,
I could just copy the contents of the file, or temporarily rename the source
file, but I decided to first try making a symbolic link or hard link before
resorting to copying.

As it turns out, the command to copy a file takes different arguments from the
command to create a symbolic link, so one purpose of this function is to
encapsulate the annoyance that is those differences.

=cut

################################################################################
# Usage			: make_cu_file($c_file_name)
# Purpose		: Create a like-named file with a .cu extension, either by
#				: creating a symbolic link, a hard link, or a direct copy.
# Returns		: nothing
# Parameters	: $c_file_name, a string with the c file name,
#				: with the .c extension
# Throws		: when unable to create the .cu file, usually when such
#				: a file already exists.
# Comments		: The way that link and symlink handle relative file paths
#				: differs from the way that copy handles relative file paths.
#				: Relative paths are computed with respect to the SECOND
#				: ARGUMENT'S LOCATION, rather than the present working directory.
#				: In other words, if you're making a link, but you're not working
#				: in the directory where the link resides, you have to do some
#				: file name munging. This is particularly annoying, since plain
#				: old copies DON'T behave this way. The purpose of this function
#				: is to encapsulate that annoying edge case.
# See also		: compile

sub make_cu_file {
	my $filename = shift;
	
	# Localize the system error string, just to be safe:
	local $!;
	
	# Extract just the filename:
	(undef, undef, my $old_name) = File::Spec->splitpath($filename);
	
	# Try a symbolic link:
	return if eval {symlink($old_name, $filename.'u')};
	# Try a hard link:
	return if eval {link($old_name, $filename.'u')};
	# Try a direct file copy (notice this does not use $old_name like
	# the others):
	return if not -f $filename.'u' and copy($filename, $filename.'u');
	
	# That didn't work, so croak:
	my $message = "Unable to create file name ${filename}u ";
	if (-f $filename.'u') {
		$message .= 'because it already exists';
	}
	else {
		$message .= 'for an unknown reason';
	}
	# working here - document this error message:
	$message .= "\nI need to be able to use that file name to use nvcc correctly\n";
	die $message;
}

1;

=head1 AUTHOR

David Mertens <dcmertens.perl@gmail.com>

=head1 SEE ALSO

L<Inline::C>, L<KappaCUDA>, L<http://www.nvidia.com/object/cuda_home_new.html>
L<Module::Build>, L<ExtUtils::MakeMaker>

=cut
