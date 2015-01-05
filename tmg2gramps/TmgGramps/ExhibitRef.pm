package TmgGramps::ExhibitRef;

use strict;
use warnings;
use Carp;
use TmgGramps::TableMappings qw(get_tablename);
use TmgGramps::Converters ();
use TmgGramps::GrampsEntity;

@TmgGramps::ExhibitRef::ISA = qw(TmgGramps::GrampsEntity);

sub new 
{
  my $class = shift;
  my $self  = $class->SUPER::new('exhibits');
  $self->{_STYPE} = undef;
  bless ($self, $class);
  return $self;
}

                            
 sub sourcetype 
 {
   my $self = shift;
   if (@_) 
   {
     my $styp = shift;
     if(  $styp eq 'E' )
     {
         $self->{_STYPE} = 'id_event';
     }
     elsif( $styp eq 'P' )
     {
         $self->{_STYPE} ='id_person';
     }
     elsif( $styp eq 'M' || $styp eq 'S' )
     {
         $self->{_STYPE} = 'id_source';
     }
     elsif( $styp eq 'R' )
     {
         $self->{_STYPE} = 'id_repos';
     } 
     elsif( $styp eq 'C' )
     {
         $self->{_STYPE} = 'id_cit';
     } 
     elsif( $styp eq 'L' )
     {
         $self->{_STYPE} = 'id_place';
     } 
   }
   return $self->{_STYPE};
 }

                            

sub writerefs
{
  my $self = shift;
  my $out = shift;
  my @data;
  
  my $query = "select IDEXHIBIT from ".$self->{_TABLE}." where ".$self->sourcetype.'=?';
  my $sth = $self->{DBHANDLE}->prepare( $query );
  $sth->execute( $self->id() ) or die $sth->errstr();
  while( @data = $sth->fetchrow_array() )
  { 
     printf $out '<objref hlink="%s"/>', TmgGramps::Exhibit->makehandle( $data[0] );
     print $out "\n";
  }
     
}     
     



    
1;


