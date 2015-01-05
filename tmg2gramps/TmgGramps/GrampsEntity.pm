package TmgGramps::GrampsEntity;


use strict;
use warnings;
use Carp qw(cluck confess);

use TmgGramps::TableMappings qw(get_tablename);


sub new 
{
  my $class = shift;
  my $self = {};
  $self->{_MAINTABLE} = shift;
  $self->{REC_NO}   = undef;
  $self->{DBHANDLE} = undef;
  $self->{TABLEBASE} = undef;
  $self->{_TABLE}    = undef;
  bless ($self, $class);
#Carp::cluck 'tbase: ',$self->{TABLEBASE},' maintbl : ',$self->{_MAINTABLE},"\n";
  return $self;
}

                            
 sub id 
 {
   my $self = shift;
   if (@_) { $self->{REC_NO} = shift }
   return $self->{REC_NO};
 }

 sub tablebase
 {
   my $self = shift;
   if (@_) 
   { 
     $self->{TABLEBASE} = shift;
		if( !defined( $self->{_MAINTABLE} ) )
		{
		    confess "_MAINTABLE is undefined\n";
		}
     $self->{_TABLE} = get_tablename( $self->{TABLEBASE},$self->{_MAINTABLE} );
   }
   return $self->{TABLEBASE};
 }
 

 sub dbhandle
 {
   my $self = shift;
   if (@_) { $self->{DBHANDLE} = shift }
   return $self->{DBHANDLE};
 }
 
 
sub makehandle
{
  my $self = shift;
  my $prehandle = shift;
  if( ref $self )
  {
    if( !(defined $self->id) )
    {
        confess 'id not defined';
    }
    return sprintf '_%d%07d', ord($prehandle), $self->id;
  }
  else
  {
    return sprintf '_%d%07d', ord($self), $prehandle;
  }
}

sub _create_table
{
   my $self = shift;
   my $myh = shift;
   my $tblname = shift;
   my $colref = shift;
   my %colhash = %$colref;
   
   my @colspecs = map ( "$_ ".$colhash{$_}, keys(%colhash) );
   
  
   my $columns = join( ', ', @colspecs );
   my $query = "create table $tblname ($columns)";
#   print STDERR "$query\n";
   $myh->do( $query );
}


sub _copy_table
{
   my $self = shift;
   my $dbfh = shift;
   my $myh = shift;
   my $tblname = shift;
   my $colnameref = shift;
   my $colnamelist = join( ',', @$colnameref );
   my $numcols = scalar @$colnameref;
   my @data;
   
   my $query = "select $colnamelist from $tblname";
   # following needed as field name 'primary' in dbf is being called 'pr1mary' in mysql, b/c primary is mysql keyword
   $query =~ s/pr1mary/primary/g;
   my $insert = "insert into $tblname ($colnamelist) values (";
   $insert .= join( ',', ('?') x $numcols );
   $insert .= ')';
   
#   print STDERR "$query\n$insert\n";
 
   my $stquery = $dbfh->prepare( $query );
   my $stinsert = $myh->prepare( $insert );
   
   $stquery->execute();
   while( @data = $stquery->fetchrow_array() )
   {
       $stinsert->execute( @data );
   }
}

sub _create_indexes
{
  my $self = shift;
  my $myh = shift;
  my $tblname = shift;
  my $indexref = shift;
  
  foreach my $indexname ( @$indexref )
  {
      $myh->do( "alter table $tblname add index ($indexname)" );
#      print STDERR "Added index $indexname to $tblname\n";
  }
}  

sub safexml
{
  my $self = shift;
  my $str = shift;
  return TmgGramps::Converters::safexml( $str );
}

1;

