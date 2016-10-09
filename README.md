# libconfig-d

Port of [libconfig](http://www.hyperrealm.com/libconfig/) to the D programming language.

example:
```d
import config;
import std.stdio;

int main()
{
	// read a configuration string (can also read from open file or filename)
	auto conf = Config.readString(
		`inventory = { books = (
			{
				title  = "Treasure Island";
				author = "Robert Louis Stevenson";
				price  = 29.99;
				qty    = 5;
			}, {
				title  = "Snow Crash";
				author = "Neal Stephenson";
				price  = 9.99;
				qty    = 8;
			}
		)}`
	);

	// fetch and read nodes
	auto books = conf.lookUp("inventory.books").asList;
	if (books)
	{
		writeln("Available books in inventory:");
		writefln("%-30s  %-30s   %-6s  %s", "TITLE", "AUTHOR", "PRICE", "QTY");
		foreach (book; books.children)
		{
			auto title = book.lookUpValue!string("title");
			auto author = book.lookUpValue!string("author");
			auto price = book.lookUpValue!float("price");
			auto qty = book.lookUpValue!int("qty");
			if (!title.isNull && !author.isNull && !price.isNull && !qty.isNull)
			{
				writefln("%-30s  %-30s  $%6.2f  %3d", title, author, price, qty);
			}
		}
		writeln();
	}

	// add nodes and values
	auto book = books.add!(Type.Group);
	book.addScalar("title", "The Plague");
	book.addScalar("author", "Albert Camus");
	book.addScalar("price", 8.99);
	book.addScalar("qty", 3);

	// write to a file (can also write to string)
	conf.writeTo(File("updated.cfg", "w").lockingTextWriter());

	return 0;
}
```