# Screw all this. Just issue the script, and use environment variables to make
# the script output debugging and/or dry run info instead of going through the
# works. Librarify it, eventually, just not now.

=head1 NAME

ExtUtils::nvcc - the library that will eventually be behind C<perl_nvcc>

=head1 DESCRIPTION

This is a work in progress, and for now C<perl_nvcc> operates without this
library. Check out it's documentation: L<perl_nvcc>.

=begin later

=head1 SYNOPSIS

 use ExtUtils::nvcc;
 
 # Create a new wrapper with the default options:
 my $wrapper = ExtUtils::nvcc->new(@args);
 
 # Create a new wrapper, to be tweaked before giving it arguments:
 my $wrapper = ExtUtils::nvcc->new({verbose => 1, });
 $wrapper->set_args(@args);
 $wrapper->add_args(@args);
 
 # Create a new tweaked wrapper 
 
 print "I'm compiling (as opposed to linking)\n" if ($wrapper->is_compiling);
 print "The unrecognized options include\n  "
	, join("\n  ", $wrapper->unrecognized), "\n";
 $wrapper->rename_c_source;
 $wrapper->execute;

=head1 DESCRIPTION

This module provides a class aimed at taking an arbitrary set of command-line
options for a generic compiler and rewriting them in a way that nVidia's nvcc
can understand.

=end later

=cut


use strict;
use warnings;

# These are necessary for Module::Build to work simply:
package ExtUtils::nvcc;

use vars qw($VERSION);
$VERSION = '0.01';

=begin later

=head2 ExtUtils::nvcc->new

The class constructor. This takes a list of arguments that you would expect to
send to gcc/g++.

=cut

sub new {
	my $class = shift;
	
	# Start building the new object, starting with the original args.
	my $self = {original => [@_]};
	
	bless $self, $class;
}

=head2 execute

Executes nvcc using the L<system> command and the set of modified arguments.

=cut

sub execute {
	my $self = shift;
	system('nvcc', $self->{revised_args});
}

=head2 verbose

Gets/sets the verbosity of the argument processing functions.

=cut

sub verbose {
	my $self = shift;
	my $new_value = shift;
	$self->{verbose} = $new_value if (defined $new_value);
	return $self->{verbose};
}

=head2 compiler_or_linker

This takes a single argument--the list of command-line arguments--and determines
whether they makes sense as a call to a compiler or to a linker. The function
returns a string that is either 'compiler' or 'linker'. It does not modify the
array.

=cut

sub compiler_or_linker (\@) {
	my $args = shift;
	
}

=head2 rename_source_file

nvcc has special file handling that depends on the file extension. Specifically,
files ending in the .cu extension have many more steps performed during the
compilation phase than files ending with a .c extension. Unfortunately,
L<Inline::C> does not provide for fine-grained control over the file extension
of the temporary file without overloading (and why should it?), so in order for
nvcc to work as a drop-in replacement for gcc or g++, this function will look
for source files ending in .c and rename them so they end in .cu.

This function is really only necessary if one plans on directly invoking
Inline::C with perl_nvcc. A better general solution is to create the module
Inline::CUDA which handles the file-naming conventions, but until that arrives,
this function will be important.

This function only takes a single argument, the array of arguments, modifies the
source filename in the argument list, and renames the file.

=cut

sub rename_source_file {
	my $args = shift;
	
	# go through each argument, looking for the 
}

=end later

=cut

1;

=head1 AUTHOR

David Mertens <dcmertens.perl@gmail.com>

=head1 SEE ALSO

L<Inline::C>, L<KappaCUDA>, L<http://www.nvidia.com/object/cuda_home_new.html>
