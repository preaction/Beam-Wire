
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.3601"
  },
  "configure_requires" => {
    "ExtUtils::MakeMaker" => "6.30",
    "Module::Build" => "0.3601"
  },
  "dist_abstract" => "A Dependency Injection Container",
  "dist_author" => [
    "Doug Bell <preaction\@cpan.org>",
    "Al Newkirk <anewkirk\@ana.io>"
  ],
  "dist_name" => "Beam-Wire",
  "dist_version" => "1.000",
  "license" => "perl",
  "module_name" => "Beam::Wire",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "Class::Load" => 0,
    "Config::Any" => "0.23",
    "Data::DPath" => "0.49",
    "List::MoreUtils" => 0,
    "Moo" => 0,
    "MooX::Types::MooseLike" => 0,
    "Throwable" => 0
  },
  "script_files" => [],
  "test_requires" => {
    "JSON" => 0,
    "Test::Compile" => 0,
    "Test::Lib" => 0,
    "Test::Most" => 0,
    "YAML" => 0
  }
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  my $tr = delete $module_build_args{test_requires};
  my $br = $module_build_args{build_requires};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
