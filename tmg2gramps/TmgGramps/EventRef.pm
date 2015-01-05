package TmgGramps::EventRef;

use strict;
use warnings;
use Carp;
use TmgGramps::TableMappings qw(get_tablename);
use TmgGramps::Converters ();
use TmgGramps::GrampsEntity;

@TmgGramps::EventRef::ISA = qw(TmgGramps::GrampsEntity);

my %colspecs = ( eper=>'int unsigned', gnum=>'int unsigned', pr1mary=>'char', role=>'char(20)', witmemo=>'blob' );

my @indexes = ( 'eper' );


sub new 
{
  my $class = shift;
  my $self  = $class->SUPER::new('witnesses');
  bless ($self, $class);
  return $self;
}

sub writerefs
{
  my $self = shift;
  my $out = shift;
  my @data;

  # following bit needed b/c primary is a field name used in tmg/xbase, and is keyword in mysql
  my $primary = ($self->{DBHANDLE}->get_info(17) =~ /mysql/i)?('pr1mary'):('primary');

    my $query = "select GNUM,$primary,ROLE,WITMEMO from ".$self->{_TABLE}." where EPER=".$self->id;
    
    my $sth = $self->dbhandle->prepare( $query );
    $sth->execute() or die $sth->errstr();
    while( @data = $sth->fetchrow_array() )
    {
      printf $out '<eventref hlink="%s" role="%s">', TmgGramps::Event->makehandle($data[0]), (($data[1]==1)?('Primary'):($data[2]));
      my @memo = TmgGramps::Converters::memo2array( $data[3] );
      if( defined( $memo[0] ) )
      {
        print $out '<note>',$self->safexml(join(', ', @memo)),"</note>\n";
      }
      
      print $out "</eventref>\n";
    }  
}     
     

 sub createTable
 {
   my $self = shift;
   my $myh = shift;
   
   $self->_create_table( $myh, $self->{_TABLE}, \%colspecs );
 }
 
 sub copyTable
 {
   my $self = shift;
   my $myh = shift;
   my $dbfh = shift;
   
   $self->_copy_table( $dbfh, $myh, $self->{_TABLE}, [ keys(%colspecs) ] );
   $self->_create_indexes( $myh, $self->{_TABLE}, \@indexes );
 }



    
1;


