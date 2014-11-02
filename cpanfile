requires "Class::Load" => "0";
requires "Config::Any" => "0.23";
requires "Data::DPath" => "0.49";
requires "List::MoreUtils" => "0";
requires "Moo" => "0";
requires "MooX::Types::MooseLike" => "0";
requires "Throwable" => "0";

on 'build' => sub {
  requires "Module::Build" => "0.28";
};

on 'test' => sub {
  requires "JSON" => "0";
  requires "Test::Compile" => "0";
  requires "Test::Lib" => "0";
  requires "Test::Most" => "0";
  requires "YAML" => "0";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
  requires "Module::Build" => "0.28";
};
