package TmgGramps::Person;

use strict;
use warnings;
use Carp;
use TmgGramps::TableMappings qw(get_tablename);
use TmgGramps::Converters ();
use TmgGramps::Names ();
use TmgGramps::GrampsEntity;
use TmgGramps::EventRef;
use TmgGramps::ExhibitRef;

@TmgGramps::Person::ISA = qw(TmgGramps::GrampsEntity);

my %psncolspecs = ( per_no=>'int unsigned', ref_id=>'int unsigned', last_edit=>'char(8)', sex=>'char' );

my @psnindexes = ( 'per_no' );

sub new 
{
  my $class = shift;
  my $self  = $class->SUPER::new('people');
  $self->{FAMILIES} = undef;
  bless ($self, $class);
  return $self;
}

         
 sub tablebase
 {
   my $self = shift;
   $self->SUPER::tablebase(@_);
   if (@_) 
   { 
     $self->{_WITTABLE} = get_tablename( $self->SUPER::tablebase,'witnesses' );
   }
   return $self->{TABLEBASE};
 }



# a hash to a reference to an array of references to all
# Family object this person belongs to
# hash key is person id.
 sub families
 {
   my $self = shift;
   if (@_) { $self->{FAMILIES} = shift }
   return $self->{FAMILIES};
 }
 
sub writeall
{
  my $self = shift;
  my $out = shift;
  my $family;
  my @data;
  my $query = "select PER_NO,REF_ID,LAST_EDIT, SEX from ".$self->{_TABLE};
  my $evttable = get_tablename( $self->tablebase, 'events' );
  
  my $tagtable = get_tablename( $self->tablebase, 'tagtypes' );
  my @addrnum =  ();
  my $sthaddrnum = $self->dbhandle->prepare( "select etypenum from $tagtable where etypename='Address'" );
  $sthaddrnum->execute();
  while( @data = $sthaddrnum->fetchrow_array() )
  {
      push @addrnum, $data[0];
  }
  
  my $sthaddr = $self->dbhandle->prepare( "select edate,placenum,recno,efoot from $evttable where etype in (".join(',',@addrnum).") and per1=?" );

  my $objrefs = TmgGramps::ExhibitRef->new();
  $objrefs->dbhandle( $self->dbhandle );
  $objrefs->tablebase( $self->tablebase );
  $objrefs->sourcetype( 'P' );

  my $eventrefs = TmgGramps::EventRef->new();
  $eventrefs->dbhandle( $self->dbhandle );
  $eventrefs->tablebase( $self->tablebase );
  
  my $addrplace = TmgGramps::Place->new();
  $addrplace->dbhandle( $self->dbhandle );
  $addrplace->tablebase( $self->tablebase );
  
  my $addrsrcref = TmgGramps::SourceRef->new();
  $addrsrcref->dbhandle( $self->dbhandle );
  $addrsrcref->tablebase( $self->tablebase );
  $addrsrcref->sourcetype( 'E' );

  my $count = 0;
  
  my $sth = $self->{DBHANDLE}->prepare( $query );
  $sth->execute() or die $sth->errstr();
  while( @data= $sth->fetchrow_array() )
  {
    ++$count;
    print STDERR '.' if( ($count % 100) == 0 );
    
    $self->id( $data[0] );
    
    printf $out '<person id="I%04d" handle="%s" change="%s">', $data[1], $self->makehandle(), TmgGramps::Converters::date2unixtime( $data[2] );
    print $out "\n<gender>";
    print $out ($data[3] eq '?')?('U'):($data[3]);  # tmg has M/F/?, Gramps uses M/F/U
    print $out "</gender>\n";
    
    my $names = TmgGramps::Names->new( );
    $names->dbhandle( $self->dbhandle );
    $names->tablebase( $self->tablebase );
    $names->per_no( $self->id );
    $names->writexml( $out );
    
    $eventrefs->id( $self->id );
    $eventrefs->writerefs( $out );
    
    $objrefs->id( $self->id );
    $objrefs->writerefs( $out );    

    
    # add any ADDRESS details
    $sthaddr->execute( $self->id ) or die $sthaddr->errstr();
    while( my @addrs = $sthaddr->fetchrow_array() )
    {
        my $dateval = TmgGramps::Converters::tmg2grampsdate( $addrs[0] );
        my @notelist = TmgGramps::Converters::memo2array( $addrs[3] );
        my $note = undef;
        if( @notelist && defined($notelist[0]) )
        {
          $note = '<note>'.$self->safexml(join( ', ', @notelist )).'</note>';
        }
        
        print $out "<address>\n";
        if( defined( $dateval ) )
        {
            print $out $dateval;
        }
        $addrplace->id( $addrs[1] );
        $addrplace->writeaddresslocation( $out );
        print $out $note if( defined($note) );
        $addrsrcref->refrec( $addrs[2] );
        $addrsrcref->writerefs( $out );
        
        print $out "</address>\n";
    }
         
          
    
    # now to write family relationships
    # and update the Family reference with sex details
    my %famlisthash = %{ $self->families };
    my $famsref = $famlisthash{ $self->id };
    foreach $family (@{$famsref})
    {
      ${$family}->set_sex( $self->id, $data[3] );
      
      if( ${$family}->is_child( $self->id ) )
      {
        print $out '<childof hlink="',${$family}->makehandle(), '"/>';
      }
      elsif( ${$family}->is_parent( $self->id ) )
      {
        print $out '<parentin hlink="',${$family}->makehandle(), '"/>';
      }
    }
    
    print $out "\n</person>\n";
  }
}

sub makehandle
{
   my $self = shift;
   if( ref $self )
   {
       return $self->SUPER::makehandle('I');
   }
   else
   {
       return TmgGramps::GrampsEntity::makehandle('I',@_);
    }
 }
 
 sub createTable
 {
   my $self = shift;
   my $myh = shift;
   
   $self->_create_table( $myh, $self->{_TABLE}, \%psncolspecs ); 
 }
 
 sub copyTable
 {
   my $self = shift;
   my $myh = shift;
   my $dbfh = shift;
   
   $self->_copy_table( $dbfh, $myh, $self->{_TABLE}, [ keys(%psncolspecs) ] );
   $self->_create_indexes( $myh, $self->{_TABLE}, \@psnindexes );
 }
 


1;
