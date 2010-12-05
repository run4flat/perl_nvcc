use Module::Build;

# check that nvcc is present and available
my $nvcc_version = `nvcc -V`;
$nvcc_version =~ /NVIDIA/ or die "You must have nvcc (from nVidia's CUDA Toolkit) installed\n";

my $build = Module::Build->new
	(
		module_name => 'ExtUtils::nvcc',
		license  => 'perl',
	);

$build->create_build_script;
