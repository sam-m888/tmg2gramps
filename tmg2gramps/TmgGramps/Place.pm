package TmgGramps::Place;

use strict;
use warnings;
use Carp;
use TmgGramps::TableMappings qw(get_tablename);
use TmgGramps::Converters ();
use TmgGramps::GrampsEntity;
use TmgGramps::ExhibitRef;

@TmgGramps::Place::ISA = qw(TmgGramps::GrampsEntity);

# maps fields in tmg to those in gramps location
# element. lat/long not part of gramps location
# element, so not mapped here.
my %placemapper = ( 'Detail'=>'street',
							'City'=>'city',
							'County'=>'county',
							'State'=>'state',
							'Country'=>'country',
							'Postal'=>'postal',
							'Phone'=>'phone',
#							'Latitude/Longitude'=>'',
							'Temple'=>'',
							'Village/Area'=>'parish',
							'Town/City'=>'city',
							'County/Region'=>'state'
#							'Addressee'=>''   # ignore addressee TODO prob not good idea
							);

my @addressfields = ( 'street', 'city', 'county', 'state', 'country', 'postal', 'phone' );

my %placecolspecs = ( recno=>'int unsigned', comment=>'blob', shortplace=>'blob' );
my %placevalcolspecs = ( id=>'int unsigned', uid=>'int unsigned', type=>'int unsigned', recno=>'int unsigned' );
my %placetypecolspecs = ( id=>'int unsigned', type=>'int unsigned', value=>'char(100)' );
my %placedictcolspecs = ( uid=>'int unsigned', value=>'blob' );

my @placeindexes = ( 'recno' );
my @placevalindexes = ( 'type', 'recno' );
my @placetypeindexes = ( 'type', 'id' );
my @placedictindexes = ( 'uid' );

sub new 
{
  my $class = shift;
  my $self  = $class->SUPER::new('places');
  $self->{_PPTTABLE} = undef;
  $self->{_PPVTABLE} = undef;
  $self->{_PDTABLE} = undef;
  bless ($self, $class);
  return $self;
}


 sub tablebase
 {
   my $self = shift;
      $self->SUPER::tablebase(@_);
   if (@_) 
   { 
     $self->{_PPTTABLE} = get_tablename( $self->SUPER::tablebase,'placept' );
     $self->{_PPVTABLE} = get_tablename( $self->SUPER::tablebase,'placepv' );
     $self->{_PDTABLE} = get_tablename( $self->SUPER::tablebase,'placedict');
   }
   return $self->{TABLEBASE};
 }


 sub writeall
 {
   my $self = shift;
   my $out = shift;
   my @dataall;
   my $sthall = $self->dbhandle->prepare( 'select RECNO,comment,shortplace from '.$self->{_TABLE} ); 
   my $sthval = $self->dbhandle->prepare( "select UID,TYPE from ".$self->{_PPVTABLE}.' where RECNO=?' );
     # place part type 9 is lat/long
   my $sthcoord = $self->dbhandle->prepare( 'select uid from '.$self->{_PPVTABLE}.' where type=9 and recno=?' );
   my $sthdict = $self->dbhandle->prepare( 'select value from '.$self->{_PDTABLE}.' where uid=?' );
   my $sthtype = $self->dbhandle->prepare( "select VALUE from ".$self->{_PPTTABLE}." where type=?" );
   
   my $objref = TmgGramps::ExhibitRef->new();
   $objref->dbhandle( $self->dbhandle );
   $objref->tablebase( $self->tablebase );
   $objref->sourcetype( 'L' );

   my $count = 0;

   $sthall->execute() or die $sthall->errstr();
   while( @dataall = $sthall->fetchrow_array() )
   {
       ++$count;
    print STDERR '.' if( ($count % 100) == 0 );

     my @data;
     my @vals;

     $self->id( $dataall[0] );
   
     printf $out '<placeobj id="P%04d" handle="%s" change="%s">', $self->id, $self->makehandle(), time();
     
     my @shortplc = TmgGramps::Converters::memo2array( $dataall[2] );
     if( @shortplc && defined( $shortplc[0] ) )
     {
         print $out '<ptitle>',$self->safexml(join(', ',@shortplc)),"</ptitle>\n";
     }
     # else leave ptitle out ?????????????

     #now for coordinates
     $sthcoord->execute( $self->id ) or die $sthcoord->errstr();
     if( @data = $sthcoord->fetchrow_array() )  # assume only one
     {
       $sthdict->execute( $data[0] ) or die $sthdict->errstr();
       if( @vals = $sthdict->fetchrow_array() )
       {
         my ($lat, $long) = split( '/', $vals[0] );
         if( defined($lat) && defined($long) )
         {
           printf $out '<coord lat="%s" long="%s"/>', $lat, $long;
         }
       }
     }
     
     
     print $out '<location ';
     $sthval->execute( $self->id ) or die $sthval->errstr();
     while( @data= $sthval->fetchrow_array() )
     {
        my @datadict;
 
        $sthdict->execute( $data[0]) or die $sthdict->errstr();
        if( @datadict = $sthdict->fetchrow_array() )
        {
            my $val = $datadict[0];
            my @datatype;
               
            $sthtype->execute( $data[1] ) or die $sthtype->errstr();
            if( @datatype = $sthtype->fetchrow_array() )
            {
              my $type = $datatype[0];
             
              # should now have place portion type in $type, and corresponding value in $val
              if( defined $placemapper{$type} )
              {
                print $out $placemapper{$type},'="',$self->safexml($val),'" ';
              }
              else
              {
                print STDERR "Cannot use place portion $val of type $type\n";
              }
            }
         }
     }
     print $out "/>\n";
       
     $objref->id( $self->id );
     $objref->writerefs( $out );
   
     my @memo = TmgGramps::Converters::memo2array( $dataall[1] );
     if( @memo && defined( $memo[0] ) )
     {
       print $out '<note>',$self->safexml(join(', ', @memo)),"</note>\n";
     }
     
     # my tmg doesn't appear to have sources linked to place, so none supported here
       
     print $out "</placeobj>\n";
  }
     
}

sub writeaddresslocation
{
  my $self = shift;
  my $out = shift;
  my @data;
  my %addressparts;

   my $query = "select RECNO,UID,TYPE,ID from ".$self->{_PPVTABLE}." where RECNO=".$self->id;
   
   my $sth = $self->{DBHANDLE}->prepare( $query );
   $sth->execute() or die $sth->errstr();
   
#   print STDERR "$query\n";
   # output needs to be in order specified in dtd,
   # so need to read all relevant values in before beginning to write
   while( @data= $sth->fetchrow_array() )
   {
#   print STDERR "type $data[2], uid $data[1]\n";
      my $sth1 = $self->{DBHANDLE}->prepare( "select VALUE from ".$self->{_PDTABLE}." where UID=".$data[1] );
      $sth1->execute() or die $sth1->errstr();
      my @data1;
      if( @data1 = $sth1->fetchrow_array() )
      {
          my $val = $data1[0];
          my @data2;     
          my $sth2 = $self->{DBHANDLE}->prepare( "select VALUE from ".$self->{_PPTTABLE}." where TYPE=".$data[2] );
          $sth2->execute or die $sth2->errstr();
          if( @data2 = $sth2->fetchrow_array() )
          {
            my $type = $data2[0];
            # should now have place portion type in $type, and corresponding value in $val
#            print STDERR "type/val $type $val\n";
            if( defined $placemapper{$type} )
            {
                $addressparts{ $placemapper{$type} } = $val;
            }
            else
            {
              print STDERR "Cannot use place portion $val of type $type in address\n";
            }
          }
       }
   }
   # now to output bits in right order
   # street, city, county, state, country, postal, phone
   if( %addressparts )
   {
     foreach my $addrbit (@addressfields )
     {
        if( defined $addressparts{$addrbit} )
        {
          printf $out "<%s>%s</%s>\n", $addrbit, $self->safexml($addressparts{$addrbit}), $addrbit;
        }
      }
    }
  
  # DEBUGGING
#  print STDERR "\nADDRESS\n";
#  foreach my $ad (keys (%addressparts))
#  {
#      print STDERR  "$ad:$addressparts{$ad} ";
#  }
#  print STDERR "\nEND ADDRESS\n";


}

# does not do sourceref - use writeaddresslocation and custom code for that
sub writeaddress
{
  my $self = shift;
  my $out = shift;
  my $dateval = shift;
  my $note = shift;

  print $out "<address>\n";
  if( defined( $dateval) )
  {
      print $out $dateval;
  }
  $self->writeaddresslocation( $out );
  if( defined( $note ) )
  {
      print $out $note;
  }
  print $out "</address>\n";
}



sub makehandle
{
   my $self = shift;
   if( ref $self )
   {
       return $self->SUPER::makehandle('P');
   }
   else
   {
       return TmgGramps::GrampsEntity::makehandle('P',@_);
    }
 }


 sub createTable
 {
   my $self = shift;
   my $myh = shift;
   
   $self->_create_table( $myh, $self->{_TABLE}, \%placecolspecs ); 
   $self->_create_table( $myh, $self->{_PDTABLE}, \%placedictcolspecs ); 
   $self->_create_table( $myh, $self->{_PPVTABLE}, \%placevalcolspecs ); 
   $self->_create_table( $myh, $self->{_PPTTABLE}, \%placetypecolspecs ); 

 }
 
 sub copyTable
 {
   my $self = shift;
   my $myh = shift;
   my $dbfh = shift;

   $self->_copy_table( $dbfh, $myh, $self->{_TABLE}, [ keys(%placecolspecs) ] );
   $self->_copy_table( $dbfh, $myh, $self->{_PDTABLE}, [ keys(%placedictcolspecs) ] );
   $self->_copy_table( $dbfh, $myh, $self->{_PPVTABLE}, [ keys(%placevalcolspecs) ] );
   $self->_copy_table( $dbfh, $myh, $self->{_PPTTABLE}, [ keys(%placetypecolspecs) ] );
   $self->_create_indexes( $myh, $self->{_TABLE}, \@placeindexes );
   $self->_create_indexes( $myh, $self->{_PDTABLE}, \@placedictindexes );
   $self->_create_indexes( $myh, $self->{_PPVTABLE}, \@placevalindexes );
   $self->_create_indexes( $myh, $self->{_PPTTABLE}, \@placetypeindexes );
 }
 


1;







