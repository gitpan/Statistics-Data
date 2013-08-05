use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Statistics::Data',
    license             => 'perl',
    dist_author         => q{Roderick Garton <rgarton@cpan.org>},
    dist_version_from   => 'lib/Statistics/Data.pm',
    dist_abstract       => 'Load, access, update, save one or more sequences of data for statistical analysis',
    configure_requires => {
        'Module::Build' => '0.4007',
    },
    build_requires => {
        'Test::More' => '0.92',
        'Array::Compare' => '2.02',
    },
    requires => {
        'Data::Serializer' => '0.59',
        'List::AllUtils' => '0.03', # "AllUtils" in case later versions require more than in "Utils" itself
        'Number::Misc' => '1.0',
        'Scalar::Util' => '1.27',
        'String::Util' => '0.21',
        'Text::SimpleTable' => '2.03',
    },
    add_to_cleanup      => [ 'Statistics-Data-0.07-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
