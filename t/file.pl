{
    "foo" => {
        "class" => "Foo",
        "args" => { "bar" => { "ref" => "bar" } }
    },
    "bar" => {
        "class" => "Bar",
        "args" => { "text" => "Hello, World" }
    },
    "buzz" => {
        "class" => "Buzz",
        "args" => [[ "one", "two", "three" ]]
    },
    "fizz" => {
        "class" => "Fizz",
        "args" => { "href" => { "one" => "two" } }
    }
}
