package TmgGramps::RepositoryRef;

use strict;
use warnings;
use Carp;
use TmgGramps::TableMappings qw(get_tablename);
use TmgGramps::Converters ();
use TmgGramps::GrampsEntity;

@TmgGramps::RepositoryRef::ISA = qw(TmgGramps::GrampsEntity);

my %srcrepocolspecs = ( rnumber=>'int unsigned', mnumber=>'int unsigned', reference=>'char(25)' );

my @indexes = ( 'mnumber' );

sub new 
{
  my $class = shift;
  my $self  = $class->SUPER::new('sourcerepo');
  $self->{_SRCREF} = undef;
  $self->{_REPOREF} = undef;
  bless ($self, $class);
  return $self;
}

                            
 sub sourceref
 {
   my $self = shift;
   if (@_) { $self->{_SRCREF} = shift }
   return $self->{_SRCREF};
 }
 
 sub reporef
 {
   my $self = shift;
   if (@_) { $self->{_REPOREF} = shift }
   return $self->{_REPOREF};
 }

sub writerefs
{
  my $self = shift;
  my $out = shift;
  my @data;
  
  my $query = "select RNUMBER,REFERENCE from ".$self->{_TABLE}." where MNUMBER=?";
  my $sth = $self->{DBHANDLE}->prepare( $query );
  $sth->execute( $self->sourceref() ) or die $sth->errstr();
  while( @data = $sth->fetchrow_array() )
  { 
       printf $out '<reporef hlink="%s">', TmgGramps::Repository->makehandle( $data[0] );
       if( defined($data[1]) )
       {
         print $out '<note>',$self->safexml($data[1]),"</note>\n";
       }
       print $out "</reporef>\n";
  }
     
}     
     


 sub createTable
 {
   my $self = shift;
   my $myh = shift;

   $self->_create_table( $myh, $self->{_TABLE}, \%srcrepocolspecs ); 
 }
 
 sub copyTable
 {
   my $self = shift;
   my $myh = shift;
   my $dbfh = shift;

   $self->_copy_table( $dbfh, $myh, $self->{_TABLE}, [ keys(%srcrepocolspecs) ] );
   $self->_create_indexes( $myh, $self->{_TABLE}, \@indexes );
   
 }
 


    
1;


