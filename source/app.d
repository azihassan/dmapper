import std.stdio;
import dmapper;

void main()
{
    writeln("Edit source/app.d to start your project.");
    Mapper!(Foo, Bar)(Foo(2))
        .convert!()
        .get()
        .writeln();
}

struct Foo
{
    int a;
}

struct Bar
{
    int a;
}
