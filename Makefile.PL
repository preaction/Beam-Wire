
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "A Dependency Injection Container",
  "AUTHOR" => "Doug Bell <preaction\@cpan.org>, Al Newkirk <anewkirk\@ana.io>",
  "BUILD_REQUIRES" => {
    "JSON" => 0,
    "Module::Build" => "0.3601",
    "Test::Compile" => 0,
    "Test::Most" => 0,
    "YAML" => 0
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30",
    "Module::Build" => "0.3601"
  },
  "DISTNAME" => "Beam-Wire",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "NAME" => "Beam::Wire",
  "PREREQ_PM" => {
    "Class::Load" => 0,
    "Config::Any" => "0.23",
    "Data::DPath" => "0.49",
    "List::MoreUtils" => 0,
    "Moo" => 0,
    "MooX::Types::MooseLike" => 0
  },
  "VERSION" => "0.014",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



