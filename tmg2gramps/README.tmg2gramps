                     tmg2gramps.pl

PURPOSE 
Reads a TMG (The Master Genealogist) V6 database and converts what
it can to a Gramps V2.2.6 xml file. This file can then be imported into
Gramps, V2.2.6 or higher.

USAGE 
Unpack the program whereever suits you. Make sure all data you want to keep
is backed up, just in case.

You need a MySQL database available on localhost that the program can
connect to. Although the usage message says this is optional, there are two
problems with not using it. Firstly, some of the data will not be
transferred correctly. Secondly, and the real reason I decided to use MySQL
as an intermediary, is without MySQL the transfer will be extremely slow.

Once you have a MySQL server available on localhost, make sure it has a
database that can be used. Most installations of MySQL include a 'test'
database as standard. tmg2gramps will happily use this if you tell it to.

You will also need Perl installed, along with its MySQL and xBase DBI
connectors. How to do this depends on the OS and distribution you use.

The example below makes the following assumptions:

  name of TMG project: smith  
  home directory: /home/asmith
  directory under home holding tmg database files: tmgdata
  name of MySQL database to use: test
  username for MySQL access: asmith
  password for MySQL access: password
  name of destination Gramps xml file: smith.xml

From the directory where you unpacked the tmg2gramps program, run it as
follows:

 tmg2gramps.pl /home/asmith/tmgdata smith smith.xml test asmith password


WHY MYSQL?
Initial runs of this program did not use an intermediate database system. On
my small, 10 person, test database, this worked fine. I knew it would run
slowly on a real TMG project, but my first attempt to transfer a real project
was abandoned after 8 hours. At that point it was about half way. There were
several possible solutions to this, but I chose to use a database server.

Why did I choose MySQL? Because I already had it installed and running, and
so it was convenient at the time. This program should work with any other
DBI compatible database server, with minor changes to the source.

KNOWN PROBLEMS 
The main problem for anyone using this program is that I wrote it to
transfer my database and hence ignored the things I wasn't interested in
transferring (DNA being the major thing in this category). Also in entering
my data into TMG I had followed several standards of my own, and took these
into account when deciding what field in TMG would match which field in
Gramps. It is unlikely anyone else followed the same standards as I when
entering data into TMG, so the decisions I made might not suit your data.
This will be particularly obvious in the way Sources and Events are
described.

There are things TMG stores that have no counterpart in the destination
version of Gramps. On the whole, these are ignored as they were unimportant
to me. They may not be unimportant to you.

I was only able to test this program against databases I had created, using
my copy of TMG. TMG is very flexible, and stores a lot of its configuration
and the meanings of fields in its database. It is possible this program
makes assumptions that were valid for my data but are not for your data.

There are a few things I thought were important to transfer which Gramps
does not handle well. These are not transferred by this program. Instead the
program prints warnings about them, and leaves it to you to manually record
them in Gramps however you choose. These primarily relate to the
non-biological parent/child relationships, such as adopted or godparents.

Your TMG database will presumably have been moved from a Windows file
system, and the resultant filenames may be mixed case. If so, use your
favourite utility to ensure they are all consistently lower or upper case.
If they don't all match, tmg2gramps will be unable to find some of them.

Make sure you type on the command line the correct case (upper or lower) for
your project name.

SUPPORT
I am not able to offer any support for this program. If you have problems, I
suggest you consult a Perl programmer to assist. If the Perl programmer
finds it hard going, don't be too critical of them. This program is not as
well written and documented as it should be. I wrote it for a purpose,
learning what it needed to do as I went along, by trial and error. Once I
got it working such that it transferred all my data, I had no further use
for it. I therefore did not invest the time fully testing, documenting,
refactoring. For this I apologise to anyone trying to extend its
capabilities.

If you are an experienced Perl programmer and require some help
understanding one of the poorly documented parts of the code, I am willing
to try to assist. In this case if you want a reply to your email, please
take care that it does not look like spam!

COPYRIGHT 
TMG is copyright by Wholly Genes (http://www.whollygenes.com/). Please see
their web site for details. Gramps copyright details can be found at the
Gramps web site (http://www.gramps-project.org/). tmg2gramps.pl was written
by Anne Jessel in 2007. The source is released to the Public Domain. As such
there is no support or warranty of any sort, implied or otherwise.





REFERENCES
http://www.whollygenes.com/
http://www.gramps-project.org/
http://www.cohsoft.com.au/tmg2gramps/

