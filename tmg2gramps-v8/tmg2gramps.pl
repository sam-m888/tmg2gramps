#!/usr/bin/perl
#
# Created 11 Mar 2007
# Copyright Anne Jessel
#
# Intended to read a TMG database and output most of its data 
# as a Gramps XML file.
#

use strict;
use warnings;

use DBI;
use TmgGramps::TableMappings qw(get_tablename);
use TmgGramps::Person;
use TmgGramps::Family;
use TmgGramps::Event;
use TmgGramps::Place;
use TmgGramps::Source;
use TmgGramps::Repository;
use TmgGramps::Exhibit;
use TmgGramps::RepositoryRef;
use TmgGramps::SourceRef;
use TmgGramps::EventRef;



if( $#ARGV < 2 )
{
  print "Usage: tmg2gramps <dbfpath> <dbftablebase> <grampsxml> [mysqldbname [mysqluser [mysqlpwd]]]\n";
  print "  where dbfpath is the absolute path to the tmg data files, \n";
  print "  dbftablebase is the basename of the tmg database (the 'project name' in TMG), and\n";
  print "  grampsxml is the path and name of the desired Gramps xml output file.\n";
  print "  the optional mysql params will cause tmg2gramps to first copy all data from the tmg files\n";
  print "  into the named mysql temporary database. This is MUCH faster than not using mysql.\n";
  print "  WARNING: all tables starting with dbftablebase will be deleted from mysqldbname.\n\n";
  exit(1);
}

my $dbfurl = "DBI:XBase:".$ARGV[0];
my $tablebase = $ARGV[1];
my $xmlfile = $ARGV[2];
my $mysqldbname = '';
my $mysqlusername = 'test';
my $mysqlpwd = '';
my $mysqldsn = '';

my $dbconnection;

$mysqlusername = $ARGV[4] if( defined( $ARGV[4] ));
$mysqlpwd = $ARGV[5] if( defined( $ARGV[5] ));

if( defined( $ARGV[3] )) # copy data into mysql first
{
    $mysqldbname = $ARGV[3];
    $mysqldsn = "DBI:mysql:database=$mysqldbname";
    copy2mysql( $dbfurl, $mysqldsn, $mysqlusername, $mysqlpwd, $tablebase );
    $dbconnection = DBI->connect( $mysqldsn, $mysqlusername, $mysqlpwd ) or die $DBI::errstr;
}
else  # read directly from dbf files - SLOW
{
    $dbconnection = DBI->connect($dbfurl) or die $DBI::errstr;
}

print STDERR "\nGenerating families\n";
my $psn2families = generate_family_groups( $dbconnection );
#dump_families( $psn2families, 'famdump1.txt' );


open( my $out, ">$xmlfile" ) || die( "Cannot open output file $xmlfile: $!\n" );

print STDERR "\nWriting XML headers\n";
write_xml_header( $out );
write_xml_start( $out );
write_gramps_header( $out, $dbconnection ); 
print STDERR "\nWriting events\n";
write_events( $out, $dbconnection );
print STDERR "\nWriting People\n";
write_people( $out, $psn2families, $dbconnection );
#dump_families( $psn2families, 'famdump2.txt' );
print STDERR "\nWriting Families\n";
write_families( $out, $psn2families, $dbconnection );
print STDERR "\nWriting Sources\n";
write_sources( $out, $dbconnection );
print STDERR "\nWriting places\n";
write_places( $out, $dbconnection );
print STDERR "\nWriting exhibits/objects\n";
write_objects( $out, $dbconnection );
print STDERR "\nWriting repositories\n";
write_repositories( $out, $dbconnection );
print STDERR "\nFinishing\n";
write_gramps_end( $out );

write_unhandled( $dbconnection );

$dbconnection->disconnect();

sub generate_family_groups
{
  my $dbh = shift;
  
  my %childof = ();
  my %families = ();
  my %psn2families = ();
  my $childnum;
  my $family;
  
  my $familytable  = get_tablename( $tablebase, 'family' );
  my $tagtable = get_tablename( $tablebase, 'tagtypes' );

  # step through persons, determining mother and father

  # IMPORTANT deals only with 'bio' parents
  # Gramps cannot properly deal with other types, especially godparents
  # You will need to manually include these relationships
  # first need to determine etypenum for these tags
  my $sthbio = $dbh->prepare( "select etypenum from $tagtable where etypename='Father-Biological' or etypename='Mother-Biological' or etypename='Parent-Biological'" );
  my @parentbiolist = ();
  my @data;
  $sthbio->execute();
  while( @data = $sthbio->fetchrow_array() )
  {
      push @parentbiolist, $data[0];
  }
  
  my $famqry = "select CHILD,PARENT,PTYPE from $familytable where PTYPE in (".join(',',@parentbiolist).')';
  print STDERR "$famqry\n";
  
  my $sth = $dbh->prepare( $famqry ) or die $dbh->errstr();
  $sth->execute() or die $sth->errstr();
  
  while (@data = $sth->fetchrow_array())
  {
    my $child = $data[0];
    my $parent = $data[1];
    
#    print STDERR "$child - $parent\n";
    
    if( !(defined $childof{$child}) )
    {
        $childof{$child} = [];
    }
     my @parents = @{ $childof{$child} };
      push @parents, $parent;
      $childof{$child} = \@parents;
      
  }
  
  
  # now have hash keyed to childid, with each value being
  # ref to array of parents.
  # Use this to build Family objects
  foreach $childnum (keys(%childof))
  {
     my $arrayref = $childof{$childnum};
     my @parents = @$arrayref;
     while( $#parents < 1 )
     {
       push @parents, 0;
     }
     my $key = join ',', sort(@parents); 
 
 # see if already exist, and if so add person as child to family
 # TODO following code is not written efficiently, but will be easier
 # to debug. Improve after tested and working properly.
    if( defined $families{$key} )
    {
    print STDERR " does exist\n";
      my $family = ${ $families{$key} };
      $family->add_child( $childnum );
      $families{$key} = \$family;
    }
    else
    {
  # if not, create new family  
#  print STDERR "does NOT exist\n";
      my $family = TmgGramps::Family->new();
      $family->add_parents( \@parents ); # assume do not know sex yet
      $family->add_child( $childnum );
      $families{$key} = \$family;
#      print STDERR "New family id is ",$family->familyid,"\n";
#      print STDERR "  with people ",join(',',$family->get_psnidlist()),"\n";
    }
  
  }
  
  # now need to reorganise data structure so that 
  # all keyed to personid
  foreach my $famref (values(%families))
  {
    my $family = ${ $famref };
#    printf STDERR "Next family is %s\n", $family->id; 
    my @psnidlist = $family->get_psnidlist();
#    print STDERR "With people ", join( ",", @psnidlist),"\n";
    my $psnid;
    foreach $psnid (@psnidlist)
    {
      if( !(defined $psn2families{$psnid}) )
      {
          $psn2families{$psnid} = [];
      }
      my @psnfamilies = @{ $psn2families{$psnid} };
      push @psnfamilies, \$family;
      $psn2families{$psnid} = \@psnfamilies;

    }
  }

  return \%psn2families;
}
  


sub write_xml_header
{
  my $out = shift;
  
  print $out <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE database PUBLIC "-//GRAMPS//DTD GRAMPS XML 1.1.3//EN"
"http://gramps-project.org/xml/1.1.3/grampsxml.dtd">
EOF
;
}

sub write_xml_start
{
  my $out = shift;
  
  print $out '<database xmlns="http://gramps-project.org/xml/1.1.3/">';
  print $out "\n";
}

sub write_gramps_header
{
  my ( $out, $dbh ) = @_;
  
  # ***** TODO *****
  # need to add researcher

  my @dt = localtime;
  my $dtstr = sprintf( "%4d-%02d-%02d", $dt[5] + 1900, $dt[4]+1, $dt[3] );
  print $out <<EOF1;
<header>
  <created date="$dtstr" version="2.2.6-1"/>
</header>
EOF1
;
}

sub write_gramps_end
{
  my $out  = shift;
  
  print $out "</database>\n";
}

sub write_events
{
  my ($out, $dbh ) = @_;
  
  print $out "<events>\n";                                      

  my $evt = TmgGramps::Event->new();
  $evt->tablebase( $tablebase );
  $evt->dbhandle( $dbh );
  $evt->writeall( $out );

  print $out "</events>\n";  
  
  return;
}

             
sub write_people
{
  my ( $out, $psn2families, $dbh ) = @_;
  my %p2f = %{ $psn2families };

  print $out "<people>\n";                                      

  my $psn = TmgGramps::Person->new();
  $psn->tablebase( $tablebase );
  $psn->dbhandle( $dbh );
  $psn->families( \%p2f );
  $psn->writeall($out);
  
  print $out "</people>\n";  
  
}


sub write_families
{
  my( $out, $psn2families, $dbh ) = @_;
  my %uniquefamilies = ();
  my $familyarrayref;
  my $familyref;
  my $fam;
  
  print $out "\n<families>\n";
  
  foreach $familyarrayref (values %{ $psn2families } )
  {
    foreach $familyref ( @{ $familyarrayref } )
    {
        
       $uniquefamilies{ ${$familyref}->id } = $familyref;
    }
  }
      
  foreach $fam (values(%uniquefamilies))
  {
    my $family = ${ $fam };
    printf $out '<family id="F%04d" handle="%s" change="%s">' , $family->id, $family->makehandle(), time();
    if( defined $family->father )
    {
      printf $out '<father hlink="%s"/>', TmgGramps::Person->makehandle( $family->father );
    }
    if( defined $family->mother )
    {
      printf $out '<mother hlink="%s"/>', TmgGramps::Person->makehandle($family->mother);
    }

    write_fam_eventrefs( $out, $family->father, $family->mother, $dbh );

    if( defined $family->get_children )
    {
        my @children = $family->get_children;
        my $child;
        foreach $child (@children)
        {
          write_fam_childref( $out, $child, [$family->father, $family->mother], $dbh );
        }
    }
    print $out "</family>\n";
  }


  print $out "</families>\n";
}

sub write_fam_childref
{
  my $out = shift;
  my $child = shift;
  my $parentsref = shift;
  my $dbh = shift;
  my $query = "select RECNO,PNOTE,PSURE,FSURE from ".get_tablename( $tablebase, 'family').' where child=? and parent=?';
  my $sth = $dbh->prepare( $query );
  my $parent;
  
  printf $out '<childref hlink="%s">', TmgGramps::Person->makehandle($child);
  foreach $parent (@$parentsref)
  {
      if( defined $parent )
      {
          my @data;
          $sth->execute( $child, $parent ) or die $sth->errstr();
          if( @data = $sth->fetchrow_array() ) # assume maximum one match
          {
              # sourcerefs
              my $srcref =  TmgGramps::SourceRef->new();
              $srcref->sourcetype( 'F' );
              $srcref->dbhandle( $dbh );
              $srcref->tablebase( $tablebase );
              $srcref->refrec( $data[0] );
              $srcref->resetconf();
              foreach my $i (2..3)
              {
                 $srcref->confidence( $data[$i] );
              }
              $srcref->writerefs( $out );

              my @memoflds = TmgGramps::Converters::memo2array( $data[1] );
              if( @memoflds && (defined $memoflds[0]) )
              {
                  print $out "<note>",$srcref->safexml(join(', ', @memoflds)),"</note>";
              }
          }
      }
  }
  
  
  print $out '</childref>';
}
    # although next is eventref, cannot use same eventref writing code as
    # used elsewhere because the tmg equivalent of an 'eventref' for a 'family'
    # is different to the 'eventref's used elsewhere
sub write_fam_eventrefs
{
  my $out = shift;
  my $father = shift;
  my $mother = shift;
  my $dbh = shift;
  
  return if( !( defined $father) || !(defined $mother) );
  
  my $query = "select RECNO from ".get_tablename( $tablebase, 'events').' where (PER1=? and PER2=?) or (PER1=? and PER2=?)';
  my $sth = $dbh->prepare( $query );
  $sth->execute( $father, $mother, $mother, $father ) or die $sth->errstr();
  while( my @data = $sth->fetchrow_array() )
  {
    printf $out '<eventref hlink="%s" role="Family"/>', TmgGramps::Event->makehandle($data[0]);
  }
    
}
  

sub write_sources
{
  my( $out, $dbh ) = @_;
  
  print $out "<sources>\n";                                      
  my $src = TmgGramps::Source->new();

  $src->tablebase( $tablebase );
  $src->dbhandle( $dbh );
  $src->writeall($out);

  print $out "</sources>\n";  
  
  return;
}


sub write_places
{
  my ( $out, $dbh ) = @_;
  
  print $out "<places>\n";                                      
  my $plc = TmgGramps::Place->new();

  $plc->tablebase( $tablebase );
  $plc->dbhandle( $dbh );
  $plc->writeall($out);

  print $out "</places>\n";  
  
  return;
  
  
}

sub write_objects
{
  my ( $out, $dbh ) = @_;
  
  print $out "<objects>\n";                                      
  my $obj = TmgGramps::Exhibit->new();
  $obj->tablebase( $tablebase );
  $obj->dbhandle( $dbh );
  $obj->writeall( $out );

  print $out "</objects>\n";  
  
  return;

}


sub write_repositories
{
  my ( $out, $dbh ) = @_;
  
  print $out "<repositories>\n";                                      
  my $rep = TmgGramps::Repository->new();
  $rep->tablebase( $tablebase );
  $rep->dbhandle( $dbh );
  $rep->writeall($out);

  print $out "</repositories>\n";  
  
  return;
  
}
  
sub dump_families
{
  my $p2fref = shift;
  my $outfile = shift;
  my %p2f = %{ $p2fref };
  my $psnid;
  
  open( my $dout, ">$outfile" ) || die( "Cannot open output file $outfile: $!\n" );
  foreach $psnid (keys(%p2f))
  {
    print $dout "\n\npsnid: $psnid\n";
    my $famrefarrayref = $p2f{$psnid};
    my @famrefarray = @$famrefarrayref;
    my $famref;
    foreach $famref (@famrefarray)
    {
      my $family = ${$famref};
      printf $dout " Family id: %s\n", $family->familyid;
      printf $dout "  Father: %s\n", ((defined $family->father)?($family->father):('undefined'));
      printf $dout "  Mother: %s\n", ((defined $family->mother)?($family->mother):('undefined'));
      printf $dout "  Parents: %s\n", join( ',', keys( %{ $family->{PARENTS} } ) );
      printf $dout "  Children: %s\n", join( ',', $family->get_children );
    }
      
    
  }
  
  close( $dout );

}


sub copy2mysql
{
  my $dbfurl = shift;
  my $mysqldsn = shift;
  my $mysqluser = shift;
  my $mysqlpwd = shift;
  my $tablebase = shift;
  
  my $dbfh = DBI->connect( $dbfurl ) or die $DBI::errstr;
  my $myh = DBI->connect( $mysqldsn, $mysqluser, $mysqlpwd ) or die $DBI::errstr;
  
  # first delete any pre-existing tables that we need to use.
  my $sth = $myh->prepare("show tables like '$tablebase\%'");
  $sth->execute();
  while( my @row = $sth->fetchrow_array() )
  {
     $myh->do( "drop table ".$row[0] );
  }
  
  # now to create new tables as needed
  print STDERR "Copying Person details\n";
  my $obj = TmgGramps::Person->new();
  $obj->tablebase( $tablebase );
  $obj->createTable( $myh );
  $obj->copyTable( $myh, $dbfh );

  print STDERR "Copying Name details\n";
  $obj = TmgGramps::Names->new();
  $obj->tablebase( $tablebase );
  $obj->createTable( $myh );
  $obj->copyTable( $myh, $dbfh );
  
  print STDERR "Copying Family details\n";
  $obj = TmgGramps::Family->new();
  $obj->tablebase( $tablebase );
  $obj->createTable( $myh );
  $obj->copyTable( $myh, $dbfh );

  print STDERR "Copying Event details\n";
  $obj = TmgGramps::Event->new();
  $obj->tablebase( $tablebase );
  $obj->createTable( $myh );
  $obj->copyTable( $myh, $dbfh );

  print STDERR "Copying Place details\n";
  $obj = TmgGramps::Place->new();
  $obj->tablebase( $tablebase );
  $obj->createTable( $myh );
  $obj->copyTable( $myh, $dbfh );

  print STDERR "Copying Source details\n";
  $obj = TmgGramps::Source->new();
  $obj->tablebase( $tablebase );
  $obj->createTable( $myh );
  $obj->copyTable( $myh, $dbfh );

  print STDERR "Copying Repository details\n";
  $obj = TmgGramps::Repository->new();
  $obj->tablebase( $tablebase );
  $obj->createTable( $myh );
  $obj->copyTable( $myh, $dbfh );

  print STDERR "Copying Exhibit details\n";
  $obj = TmgGramps::Exhibit->new();
  $obj->tablebase( $tablebase );
  $obj->createTable( $myh );
  $obj->copyTable( $myh, $dbfh );

  print STDERR "Copying Citation details\n";
  $obj = TmgGramps::SourceRef->new();
  $obj->tablebase( $tablebase );
  $obj->createTable( $myh );
  $obj->copyTable( $myh, $dbfh );

  print STDERR "Copying RepositoryRef details\n";
  $obj = TmgGramps::RepositoryRef->new();
  $obj->tablebase( $tablebase );
  $obj->createTable( $myh );
  $obj->copyTable( $myh, $dbfh );

  print STDERR "Copying EventRef details\n";
  $obj = TmgGramps::EventRef->new();
  $obj->tablebase( $tablebase );
  $obj->createTable( $myh );
  $obj->copyTable( $myh, $dbfh );
  
  print STDERR "Generating source maps\n";
  generate_sourcemap( $tablebase, $myh, $dbfh );

}  
  
sub generate_sourcemap
{
  my $tablebase = shift;
  my $myh = shift;
  my $dbfh = shift;
  my @data;
  
  my $srccattable = get_tablename( $tablebase, 'sourcecat' );
  my $srccmptable = get_tablename( $tablebase, 'sourcecomponent' );
  my $srcmaptable = get_tablename( $tablebase, 'sourcemap' );
  
  my $create = "create table $srcmaptable (custtype int unsigned, fieldname varchar(30), fieldnum smallint unsigned, index (fieldname), unique (custtype,fieldnum) )";
  $myh->do( $create );
  
  my $querycat = "select sourtype,foot,short,bib,custfoot,custshort,custbib from $srccattable";
  my $insert = "insert into $srcmaptable (custtype, fieldname, fieldnum) values (?,?,?)";
  my $stinsert = $myh->prepare( $insert );
  my $querycomp = "select groupnum from $srccmptable where element=?";
  my $stcomp = $myh->prepare( $querycomp );
  my $stcheckdupe = $myh->prepare( "select fieldnum from $srcmaptable where custtype=? and fieldnum=?" );
  
  my $sth = $dbfh->prepare( $querycat );
  $sth->execute();
  while( @data = $sth->fetchrow_array() )
  {
    my $custtype = $data[0];
    my %fldnames = ();
    foreach my $i (1..$#data)
    {
        my $datafld = $data[$i];
        next if( !defined($datafld) || $datafld =~ /^\s*$/ );
        my @memo = TmgGramps::Converters::memo2array( $datafld );
        foreach my $str (@memo)
        {
            my @matches = ($str =~ /\[[A-Za-z 0-9]+\]/g);
#            print STDERR "memo fld is $str which has ";
            foreach my $match (@matches)
            {
              $fldnames{"$match"}++;
#              print STDERR "$match,";
            }
#            print STDERR "\n";
        }
    }
    # keys of %fldnames should now contain all text between [ and ] in the memo fields, i.e. info field names
    # need to look each up in sourcecomponent table, and get groupnum which is sourcetable.info's fieldnum
    foreach my $fldname (keys(%fldnames))
    {
        $stcomp->execute( $fldname );
        my @cmpdata = $stcomp->fetchrow_array(); # should be only one match
        if( @cmpdata )
        {
          my $fldnm = $fldname;
          $fldnm =~ tr/\[\]//d;
          # TODO ignore duplicate key errors for this bit, as many inserts will probably fail due to duplicate keys.
          $stcheckdupe->execute( $custtype, $cmpdata[0] );
          my @tmpdata = $stcheckdupe->fetchrow_array();
          if( !@tmpdata )
          {
              $stinsert->execute( $custtype, $fldnm, $cmpdata[0] );
           }       
        }
    }
  } 
}
        
# Write messages to STDOUT explaining which major items not handled
sub write_unhandled
{
  my $dbh = shift;
  
  print "\n\nThis converter does not handle everything. Check your data for incomplete/missing items.";
  print " Items known to be missing will include:\n  DNA\n  Research tasks\n  Timelines\n  Custom flags";
  print "\n  Separation of data sets\n\nThere may be other information in your TMG database that this converter does not know how to find.\n\n";
  print "The following relationships were not converted:\n";
  
  # determine what relationships are missing
  my $tagtable = get_tablename( $tablebase, 'tagtypes' );
  my $nametable = get_tablename( $tablebase, 'names' );
  my $familytable = get_tablename( $tablebase, 'family' );
  my $sthname = $dbh->prepare( "select srnamedisp from $nametable where nper=?" );
  my $sthtag = $dbh->prepare( "select etypename from $tagtable where etypenum=?" );
  my $sthtypenums = $dbh->prepare( "select etypenum from $tagtable where etypename='Father-Biological' or etypename='Mother-Biological' or etypename='Parent-Biological'" );
  $sthtypenums->execute();
  my @parentbiolist = ();
  my @data;
  while( @data = $sthtypenums->fetchrow_array() )
  {
      push @parentbiolist, $data[0];
  }  
  
  
  my $missingrelsquery = "select CHILD,PARENT,PTYPE from $familytable where PTYPE not in (".join(',',@parentbiolist).')';
#  print $missingrelsquery;
  
  my $sth = $dbh->prepare( $missingrelsquery ) or die $dbh->errstr();
  $sth->execute() or die $sth->errstr();
  
  my %relmap = ();
  while (@data = $sth->fetchrow_array())
  {
    $sthname->execute( $data[0] );
    my @childname = $sthname->fetchrow_array();
    $sthname->execute( $data[1] );
    my @parentname = $sthname->fetchrow_array();
    
    if( !(defined $relmap{ $data[2] }) )
    {
        $sthtag->execute( $data[2] );
        my @data1 = $sthtag->fetchrow_array();
        $relmap{ $data[2] } = $data1[0];
    }
    
    printf " %s is the %s of %s\n", $parentname[0], $relmap{ $data[2] }, $childname[0];
  }
  
  print "\nEND\n\n";
}

          
        
    
