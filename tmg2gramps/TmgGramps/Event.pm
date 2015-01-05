package TmgGramps::Event;

use strict;
use warnings;
use Carp;
use TmgGramps::TableMappings qw(get_tablename);
use TmgGramps::Converters ();
use TmgGramps::GrampsEntity;
use TmgGramps::SourceRef;
use TmgGramps::ExhibitRef;

@TmgGramps::Event::ISA = qw(TmgGramps::GrampsEntity);

my %evtcolspecs = ( edate=>'char(30)', placenum=>'int unsigned', recno=>'int unsigned', efoot=>'blob',
                    etype=>'int unsigned', per1=>'int unsigned', per2=>'int unsigned', ensure=>'char',
                    essure=>'char', edsure=>'char', epsure=>'char', efsure=>'char' );
# also responsible for tagtable
my %tagtypecolspecs = ( etypename=>'char(20)', etypenum=>'int unsigned' );           
                    
my @evtindexes = ( 'etype', 'per1', 'per2' );
my @tagindexes = ( 'etypenum', 'etypename' );

sub new 
{
  my $class = shift;
  my $self  = $class->SUPER::new('events');
  $self->{_TAGTABLE} = undef;
  bless ($self, $class);
  return $self;
}


 sub tablebase
 {
   my $self = shift;
      $self->SUPER::tablebase(@_);

   if (@_) 
   { 
     $self->{_TAGTABLE} = get_tablename( $self->SUPER::tablebase,'tagtypes' );
   }
   return $self->{TABLEBASE};
 }



 
 sub writeall
 {
   my $self = shift;
   my $out = shift;
   my @data;
   my $srcref =  TmgGramps::SourceRef->new();
   $srcref->sourcetype( 'E' );
   $srcref->dbhandle( $self->dbhandle );
   $srcref->tablebase( $self->tablebase );
   
   my $objref = TmgGramps::ExhibitRef->new();
   $objref->dbhandle( $self->dbhandle );
   $objref->tablebase( $self->tablebase );
   $objref->sourcetype( 'E' );

   my $count = 0;

   my $query = "select ETYPE, EDATE, PLACENUM, RECNO, PER1, PER2,ENSURE,ESSURE,EDSURE,EPSURE,EFSURE,EFOOT from ".$self->{_TABLE};
   
     my $sth = $self->{DBHANDLE}->prepare( $query );
  $sth->execute() or die $sth->errstr();
  while( @data= $sth->fetchrow_array() )
  {
      ++$count;
    print STDERR '.' if( ($count % 100) == 0 );

    $self->id( $data[3] );
    printf $out '<event id="E%04d" handle="%s" change="%s">', $self->id, $self->makehandle(), time();
    print $out "\n<type>";
    my $evttype = $self->_fetch_evttype( $data[0] );
    print $out $evttype;
    print $out "</type>\n";
    print $out TmgGramps::Converters::tmg2grampsdate( $data[1] );
    print $out "\n";
    printf $out '<place hlink="%s"/>', TmgGramps::Place->makehandle($data[2]);
    print $out "\n";
# dtd includes 'cause' element here, but cannot see where it is displayed in UI
    $self->_write_description( $out, $evttype, $data[1], $data[4], $data[5] );
    
    
    my @note = TmgGramps::Converters::memo2array( $data[11] );
    if( defined( $note[0] ) )
    {
      # if one of specific set of events, assume first note is actually a particular attribute
      if( $evttype eq 'Occupation' )
      {
          print $out "\n",'<attribute type="occupation" value="',$self->safexml($note[0]),'"/>';
      }
      elsif( $evttype eq 'Burial' )
      {
          if( $note[0] =~ /Unknown GEDCOM info: (.+)$/ )
          {
              print $out "\n",'<attribute type="cemetery" value="',$self->safexml( $1 ), '"/>';
          }
      }
      elsif( $evttype eq 'Immigratn' )
      {
          my $ship = $note[0];
          if( $note[0] =~ /Ship: (.+)$/ )
          {
              $ship = $1;
          }
          print $out "\n",'<attribute type="Ship" value="', $self->safexml( $ship ), '"/>';
      }
      elsif( $evttype eq 'Death' )
      {
          if( $note[0] =~ /Cause: (.+)$/ )
          {
              print $out "\n",'<attribute type="Cause" value="',$self->safexml($1),'"/>';
          }
      }
      elsif( $evttype eq 'Religion' )
      {
          print $out "\n",'<attribute type="Denomination" value="',$self->safexml($note[0]),'"/>';
      }
      print $out '<note>',$self->safexml(join( ', ',@note)),"</note>\n";
    }
    
    $srcref->refrec( $self->id() );
    $srcref->resetconf();
    foreach my $i (6..10)
    {
      $srcref->confidence( $data[$i] );
    }
    $srcref->writerefs( $out );

    $objref->id( $self->id() );
    $objref->writerefs( $out );
    
    print $out "</event>\n";
    
   }
}   

sub _write_description
{
  my $self = shift;
  my $out = shift;
  my $evttype = shift;
  my $edate = shift;
  my $per1 = shift;
  my $per2 = shift;
  my @descript = ();
  
  push @descript, $evttype;
  
  
  my $sth = $self->dbhandle->prepare( 'select SURID,GIVID from '.get_tablename($self->tablebase,'names').' where pr1mary=1 and nper=?' );
  my $sthd = $self->dbhandle->prepare( 'select value from '.get_tablename($self->tablebase,'namedict').' where uid=?' );
  
  foreach my $p ($per1,$per2)
  {
    if( defined($p) && $p > 0 )
    {
      $sth->execute( $p ) or die $sth->errstr();
      if( my @names = $sth->fetchrow_array() )
      {
        my @ndict;
        $sthd->execute( $names[0] ) or die $sthd->errstr();
        if( @ndict = $sthd->fetchrow_array() )
        {
          push @descript, $ndict[0];
        }
        $sthd->execute( $names[1] ) or die $sthd->errstr();
        if( @ndict = $sthd->fetchrow_array() )
        {
          push @descript, substr( $ndict[0], 0, 1 );
        }
      }
    }
  }
  push @descript, TmgGramps::Converters::tmg2grampsdateyear( $edate );
        
  print $out "<description>".$self->safexml(join( ' ', @descript ))."</description>\n";

}
  
  
 
 sub _fetch_evttype
 {
   my $self = shift;
   my $evttypeid = shift;
   my $result = '';
   my $query = "select ETYPENAME from ".$self->{_TAGTABLE}." where ETYPENUM=$evttypeid";
   
   my $sth = $self->{DBHANDLE}->prepare( $query );
   $sth->execute or die $sth->errstr();
   if( my @data = $sth->fetchrow_array() )
   {
     $result = $data[0];
   }
   $sth->finish;
   
   return $result;
 }


sub makehandle
{
   my $self = shift;
   if( ref $self )
   {
       return $self->SUPER::makehandle('E');
   }
   else
   {
       return TmgGramps::GrampsEntity::makehandle('E',@_);
    }
 }


 sub createTable
 {
   my $self = shift;
   my $myh = shift;

   $self->_create_table( $myh, $self->{_TABLE}, \%evtcolspecs ); 
   $self->_create_table( $myh, $self->{_TAGTABLE}, \%tagtypecolspecs ); 
 }
 
 sub copyTable
 {
   my $self = shift;
   my $myh = shift;
   my $dbfh = shift;

   $self->_copy_table( $dbfh, $myh, $self->{_TABLE}, [ keys(%evtcolspecs) ] );
   $self->_copy_table( $dbfh, $myh, $self->{_TAGTABLE}, [ keys(%tagtypecolspecs) ] );
   $self->_create_indexes( $myh, $self->{_TABLE}, \@evtindexes );
   $self->_create_indexes( $myh, $self->{_TAGTABLE}, \@tagindexes );
   
 }
1;
