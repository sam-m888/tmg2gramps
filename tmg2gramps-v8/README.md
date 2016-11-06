The official version of tmg2gramps does not work with well with TMG v8 databases, because of changed relation types.

This can be corrected with a modified tmg2gramps.pl file, which can be downloaded here. 

To apply this upgrade, you must first unpack the official download, and then overwrite the tmg2gramps.pl file with the version above.

From [Ennoborg] found on the Gramps wiki

---

Note by Ian Strang:

There are three lines changed between tmg2gramps.pl and trm2gramps-v8. ... the changes .... list[ed] them below for clarity.

See also: https://github.com/sam-m888/tmg2gramps for tmg2gramps-v8

    l117
    my $sthbio = $dbh->prepare( "select etypenum from $tagtable where etypename='Father-Bio' or etypename='Mother-Bio' or etypename='Parent-Bio'" );     
    my $sthbio = $dbh->prepare( "select etypenum from $tagtable where etypename='Father-Biological' or etypename='Mother-Biological' or etypename='Parent-Biological'" );


     
    l168
    #    print STDERR " does exist\n";                                                                                                                                                                                                                                             
         print STDERR " does exist\n";

    l683 
    my $sthtypenums = $dbh->prepare( "select etypenum from $tagtable where etypename='Father-Bio' or etypename='Mother-Bio' or etypename='Parent-Bio'" );  
    my $sthtypenums = $dbh->prepare( "select etypenum from $tagtable where etypename='Father-Biological' or etypename='Mother-Biological' or etypename='Parent-Biological'" );


Mentioned:
http://www.rhus.org.uk/linux/tmg2gramps.htm
