import std.traits : FieldNameTuple, hasMember;

template FieldType(T, string field)
{
    alias FieldType = typeof(__traits(getMember, T, field));
}

unittest
{
    struct Foo
    {
        ulong bar;
    }
    static assert(is(FieldType!(Foo, "bar") == ulong));
}

unittest
{
    class Foo
    {
        ulong bar;
    }
    static assert(is(FieldType!(Foo, "bar") == ulong));
}

struct Mapper(From, To)
{
    private From from;
    private To to;

    this(From from)
    {
        this.from = from;
    }

    this(From from, To to)
    {
        this.from = from;
        this.to = to;
    }

    auto convert()()
    {
        static foreach(field; FieldNameTuple!From)
        {
            static if(hasMember!(To, field) && is(FieldType!(From, field) == FieldType!(To, field)))
            {
                convert!(field, field);
            }
        }
        return this;
    }

    auto convert(string fromField, string toField)()
    {
        mixin("to." ~ toField ~ " = from." ~ fromField ~ ";");
        return this;
    }

    auto convert(string targetField, typeof(targetField) function(From from) customMapping)()
    {
        mixin("to." ~ targetField ~ " = customMapping(from);");
        return this;
    }

    auto convert(To function(From, To) afterMapping)()
    {
        to = afterMapping!(From, To)(from, to);
        return this;
    }

    To get()
    {
        return to;
    }
}

unittest
{
    import std.stdio : writeln;
    import std.datetime : Date, DateTime;
    import std.algorithm : map, canFind;

    writeln("Should apply multiple conversions");

    enum RoleType { ROLE_ADMIN, ROLE_USER }
    struct Role
    {
        int id;
        RoleType type;
    }
    struct Address
    {
        int buildingNumber;
        string street;
        string city;
    }
    struct User
    {
        int id;
        string username;
        string password;
        string firstName;
        string lastName;
        int age;
        Address address;
        Role[] roles;
        DateTime createdAt;
    }

    class UserDTO
    {
        int id;
        string email;
        string fullName;
        string cityName;
        string age;
        bool isAdmin;
        Date registeredAt;
    }


    auto user = User(
        1,
        "john.doe@mail.com",
        "foobar",
        "John",
        "Doe",
        20,
        Address(15, "Yemen road", "Yemen"),
        [
            Role(1, RoleType.ROLE_ADMIN),
            Role(2, RoleType.ROLE_USER)
        ],
        DateTime(2020, 1, 1, 10, 30, 0)
    );

    auto dto = new UserDTO();
    auto result = Mapper!(User, UserDTO)(user, dto)
        .convert!() //auto mapping between the same fields
        .convert!("username", "email") //aliasing
        .convert!("address.city", "cityName") //embedded source, flat target
        .convert!("createdAt.day", "registeredAt.day") //embedded source, embedded target
        .convert!("createdAt.month", "registeredAt.month")
        .convert!("createdAt.year", "registeredAt.year")
        .convert!("fullName", f => f.firstName ~ " " ~ f.lastName) //custom mapping logic for one field
        .convert!((from, to) { //custom mapping logic
            to.isAdmin = from.roles.map!(r => r.type).canFind(RoleType.ROLE_ADMIN);
            return to;
        })
        .get();

    assert(result.id == 1);
    assert(result.email == "john.doe@mail.com");
    assert(result.fullName == "John Doe");
    assert(result.cityName == "Yemen");
    assert(result.age == "");
    assert(result.isAdmin);
    assert(result.registeredAt == Date(2020, 1, 1));
}
