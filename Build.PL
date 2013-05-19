
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "JSON" => 0,
    "Module::Build" => "0.3601",
    "Test::Compile" => 0,
    "Test::Most" => 0,
    "YAML" => 0
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
  "dist_version" => "0.011",
  "license" => "perl",
  "module_name" => "Beam::Wire",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "Class::Load" => 0,
    "Config::Any" => "0.23",
    "Data::DPath" => "0.49",
    "Moo" => 0,
    "MooX::Types::MooseLike" => 0
  },
  "script_files" => []
);


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
