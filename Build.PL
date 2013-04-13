use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Statistics::Data',
    license             => 'perl',
    dist_author         => q{Roderick Garton <rgarton@cpan.org>},
    dist_version_from   => 'lib/Statistics/Data.pm',
    configure_requires => {
        'Module::Build' => '0.36',
    },
    build_requires => {
        'Test::More' => 0,
        'Array::Compare' => 0,
    },
    requires => {
        'Data::Serializer' => '0.59',
        'List::AllUtils' => '0.03', # "AllUtils" in case later versions require more than in "Utils" itself
        'Scalar::Util' => '1.23',
        'String::Util' => '0.11',
        'Text::SimpleTable' => '2.03',
    },
    add_to_cleanup      => [ 'Statistics-Data-0.03-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
