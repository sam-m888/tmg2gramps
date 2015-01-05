package TmgGramps::SourceRef;

use strict;
use warnings;
use Carp;
use TmgGramps::TableMappings qw(get_tablename);
use TmgGramps::Converters ();
use TmgGramps::GrampsEntity;

@TmgGramps::SourceRef::ISA = qw(TmgGramps::GrampsEntity);

my %citecolspecs = ( majsource=>'int unsigned', subsource=>'blob', citmemo=>'blob',
                     citref=>'char(30)', snsure=>'char', sssure=>'char', sdsure=>'char',
                     spsure=>'char', sfsure=>'char', refrec=>'int unsigned', stype=>'char' );

my @indexes = ( 'refrec', 'stype' );                     
                     
sub new 
{
  my $class = shift;
  my $self  = $class->SUPER::new('citations');
  $self->{_STYPE} = undef;
  $self->{_REFREC} = undef;
  $self->{_CONF} = undef;
  bless ($self, $class);
  return $self;
}

  
 sub confidence
 {
   my $self = shift;
   if( @_ )
   {
       my $conf = shift;
       if( !($conf =~ /^\s*$/) )
       {
       	$conf = -1 if( $conf eq '-' );
         if(!(defined($self->{_CONF})) || ( $conf > $self->{_CONF}) )
         {
           $self->{_CONF} = $conf;
         }
       }
   }
   return $self->{_CONF};
 }
 
 sub resetconf
 {
   my $self = shift;
   $self->{_CONF} = undef;
 }  
                            
 sub sourcetype 
 {
   my $self = shift;
   if (@_) { $self->{_STYPE} = shift }
   return $self->{_STYPE};
 }
 
 # mapping tmg surety levels to gramps confidence levels:
 # tmg  gramps
 #  -    0
 #  0    1
 #  1    2
 #  2    3
 #  3    4
 sub grampsconfidence
 {
   my $self = shift;
   my $conf = $self->confidence;
   my $gconf = undef;
   
   if( defined($conf) )
   {
       $gconf = abs($conf + 1   );
   }
   
   return $gconf;
 }
       
                            
 sub refrec 
 {
   my $self = shift;
   if (@_) { $self->{_REFREC} = shift }
   return $self->{_REFREC};
 }

# a Gramps srcref can have only one conf value,
# but tmg allows for many sureties. 
sub writerefs
{
  my $self = shift;
  my $out = shift;
  my @data;
  
  my $query = "select MAJSOURCE,SUBSOURCE,CITMEMO,CITREF,SNSURE,SSSURE,SDSURE,SPSURE,SFSURE from ".$self->{_TABLE}." where REFREC=? and STYPE=?";
  my $sth = $self->{DBHANDLE}->prepare( $query );
  $sth->execute( $self->refrec(), $self->sourcetype() ) or die $sth->errstr();
  while( @data = $sth->fetchrow_array() )
  { 
     my $conf = $self->grampsconfidence();  
     if( defined( $conf ) )
     { 
       printf $out '<sourceref hlink="%s" conf="%s">', TmgGramps::Source->makehandle( $data[0] ), $conf;
     }
     else
     {
       printf $out '<sourceref hlink="%s">', TmgGramps::Source->makehandle( $data[0] );
     }
     my @memo = TmgGramps::Converters::memo2array( $data[2] );
     push @memo, $data[3] if( defined( $data[3] ) );
     if( defined( $memo[0] ) )
     {
       print $out '<scomments>',$self->safexml(join(', ', @memo)),"</scomments>\n";
     }
     @memo = TmgGramps::Converters::memo2array( $data[1] );
     if( defined( $memo[0] ) )
     {
       print $out '<stext>',$self->safexml(join(', ', @memo)),"</stext>\n";
     }
     # gramps has a possible date field next, but tmg doesn't seem to have a match
     print $out "</sourceref>\n";
   }
     
}     
     



 sub createTable
 {
   my $self = shift;
   my $myh = shift;

   $self->_create_table( $myh, $self->{_TABLE}, \%citecolspecs ); 
 }
 
 sub copyTable
 {
   my $self = shift;
   my $myh = shift;
   my $dbfh = shift;

   $self->_copy_table( $dbfh, $myh, $self->{_TABLE}, [ keys(%citecolspecs) ] );
   $self->_create_indexes( $myh, $self->{_TABLE}, \@indexes );
   
 }
 


    
1;


