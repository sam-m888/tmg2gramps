package TmgGramps::Repository;

use strict;
use warnings;
use Carp;
use TmgGramps::Place;
use TmgGramps::TableMappings qw(get_tablename);
use TmgGramps::Converters ();
use TmgGramps::GrampsEntity;

@TmgGramps::Repository::ISA = qw(TmgGramps::GrampsEntity);

my %repocolspecs = ( name=>'blob', recno=>'int unsigned', abbrev=>'char(50)', address=>'int unsigned',
                     rnote=>'blob', rperno=>'int unsigned' );
                          
my @indexes = ( 'recno' );

sub new 
{
  my $class = shift;
  my $self  = $class->SUPER::new('repo');
  bless ($self, $class);
  return $self;
}


 sub writeall
 {
   my $self = shift;
   my $out = shift;
   my @data;
   my $query = "select NAME,RECNO,ABBREV,ADDRESS,RNOTE,RPERNO from ".$self->{_TABLE};
     my $count = 0;
   
     my $sth = $self->{DBHANDLE}->prepare( $query );
  $sth->execute() or die $sth->errstr();
  while( @data= $sth->fetchrow_array() )
  {
    ++$count;
    print STDERR '.' if( ($count % 100) == 0 );
    $self->id( $data[1] );
    # rname is mandatory in gramps dtd
    my $rname;
    if( (defined $data[0]) && !($data[0] =~ /^\s*$/) )
    {
      $rname = join ', ', TmgGramps::Converters::memo2array($data[0]);
    }
    elsif( defined $data[2] )
    {
      $rname = $data[2];
    }
    else
    {
      $rname = 'Unnamed';
    }
    $rname = $self->safexml( $rname );
    printf $out '<repository id="R%04d" handle="%s" change="%s">', $self->id, $self->makehandle(), time();
    print $out "<rname>$rname</rname>\n";
    print $out "<type>Unknown</type>\n";  # TODO - this info doesn't really exist in tmg, so may have to leave as 'Unknown'
    
    my $address = TmgGramps::Place->new();
    $address->tablebase( $self->{TABLEBASE} );
    $address->dbhandle( $self->{DBHANDLE} );
    $address->id( $data[3] );
    $address->writeaddress( $out, undef, undef );

    if( defined $data[4] )
    {
      my $rnote = join ', ', TmgGramps::Converters::memo2array($data[4]);
      if( defined $rnote )
      { 
      	$rnote = $self->safexml( $rnote );
        print $out "<note>$rnote</note>\n";
      }
    }
        
    print $out "</repository>";
    
   }
   
 }


sub makehandle
{
   my $self = shift;
   if( ref $self )
   {
       return $self->SUPER::makehandle('R');
   }
   else
   {
       return TmgGramps::GrampsEntity::makehandle('R',@_);
    }
 }


 sub createTable
 {
   my $self = shift;
   my $myh = shift;

   $self->_create_table( $myh, $self->{_TABLE}, \%repocolspecs ); 
 }
 
 sub copyTable
 {
   my $self = shift;
   my $myh = shift;
   my $dbfh = shift;

   $self->_copy_table( $dbfh, $myh, $self->{_TABLE}, [ keys(%repocolspecs) ] );
   $self->_create_indexes( $myh, $self->{_TABLE}, \@indexes );
   
 }


1;

