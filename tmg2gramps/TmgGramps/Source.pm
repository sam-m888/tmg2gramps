package TmgGramps::Source;

use strict;
use warnings;
use Carp;
use TmgGramps::TableMappings qw(get_tablename);
use TmgGramps::Converters ();
use TmgGramps::GrampsEntity;
use TmgGramps::ExhibitRef;

@TmgGramps::Source::ISA = qw(TmgGramps::GrampsEntity);

my @recorders = ( '', 'Other', 'Person', 'Civil', 'Church','Commercial','Institutional');
my @mediatypes = ( '', 'Other', 'Film', 'Book', 'Visual','Audio','Memory' );
my @fidelities = ('', 'Other','Original','Photocopy','Transcript','Extract');
my @indexed = ('', 'Unknown', 'No', 'Yes');

my %srccolspecs = ( abbrev=>'char(50)', info=>'blob', title=>'blob', uncitedfld=>'blob', type=>'int unsigned',
                    majnum=>'int unsigned', recorder=>'smallint unsigned', media=>'smallint unsigned',
                    fidelity=>'smallint unsigned', indexed=>'smallint unsigned', text=>'blob', custtype=>'int unsigned' );

my %srccompcolspecs = ( groupnum=>'int unsigned', element=>'char(30)' );

my @indexes = ( 'majnum' );
my @compindexes = ('element');

sub new 
{
  my $class = shift;
  my $self  = $class->SUPER::new('sources');
  bless ($self, $class);
  return $self;
}

    

 sub tablebase
 {
   my $self = shift;
      $self->SUPER::tablebase(@_);
   return $self->{TABLEBASE};
 }


 sub writeall
 {
   my $self = shift;
   my $out = shift;
   my @data;
   my $query = "select ABBREV,INFO,TITLE,UNCITEDFLD,MAJNUM,RECORDER,MEDIA,FIDELITY,INDEXED,TEXT,CUSTTYPE from ".$self->{_TABLE};
   my $objref = TmgGramps::ExhibitRef->new();
   $objref->dbhandle( $self->dbhandle );
   $objref->tablebase( $self->tablebase );
   $objref->sourcetype( 'S' );

   my $count = 0;
   
  my $sth = $self->{DBHANDLE}->prepare( $query );
  $sth->execute() or die $sth->errstr();
  while( @data= $sth->fetchrow_array() )
  {
      ++$count;
    print STDERR '.' if( ($count % 100) == 0 );

    $self->id( $data[4] );
    printf $out '<source id="S%04d" handle="%s" change="%s">', $self->id, $self->makehandle(), time();

    # the way my sources have been created, I want tmg's abbrev to become gramps' title
    print $out '<stitle>',$self->safexml($data[0]),"</stitle>\n";
    print $out '<sabbrev>',$self->safexml($data[0]),"</sabbrev>\n";
    my @ttlflds = TmgGramps::Converters::memo2array( $data[2] );
    my @memoflds = TmgGramps::Converters::memo2array( $data[9] );
    print $out '<note>';
    if( @ttlflds && (defined $ttlflds[0]) )
    {
      print $out $self->safexml(join(', ', @ttlflds));
    }
    if( @memoflds && (defined $memoflds[0]) )
    {
      print $out $self->safexml(join(', ', @memoflds));
    }
    print $out '</note>';
    
    $objref->id( $self->id() );
    $objref->writerefs( $out );


    if( defined( $data[5] ) &&  !($data[5] =~ /^\s*$/) )
    {
        printf $out '<data_item key="%s" value="%s"/>', 'Recorder', $recorders[$data[5]];  
    }  
    if( defined( $data[6] ) && !($data[6] =~ /^\s*$/) )
    {
        printf $out '<data_item key="%s" value="%s"/>', 'Media Type', $mediatypes[$data[6]];  
    }  
    if( defined( $data[7]) && !($data[7] =~ /^\s*$/) )
    {
        printf $out '<data_item key="%s" value="%s"/>', 'Fidelity', $fidelities[$data[7]];  
    }  
    if( defined( $data[8]) && !($data[8] =~ /^\s*$/) )
    {
        printf $out '<data_item key="%s" value="%s"/>', 'Indexed', $indexed[$data[8]];  
    }  
    
#    my @memovals = TmgGramps::Converters::memo2array( $data[1] );
#    @memoflds = TmgGramps::Converters::memo2array( $data[3] );
    
#    if( @memovals )
#    {
#      foreach my $ii (0..$#memovals)
#      {
#        printf $out '<data_item key="%s" value="%s"/>', ((defined $memoflds[$ii])?($memoflds[$ii]):('data')), $self->safexml($memovals[$ii]);
#      }
#    }

    my $srcmaptable = get_tablename( $self->tablebase, 'sourcemap' );
    my $stfldnum = $self->dbhandle->prepare( "select fieldname from $srcmaptable where custtype=? and fieldnum=?" );
    my @memovals = split /\$\!\&/, $data[1], -1;
    foreach my $i (0..$#memovals)
    {
        if( defined($memovals[$i]) && !($memovals[$i] =~ /^\s*$/) )
        {
           $stfldnum->execute( $data[10], $i+1 );
           my @result = $stfldnum->fetchrow_array();
           if( @result )
           {
               printf $out '<data_item key="%s" value="%s"/>', $self->safexml($result[0]), $self->safexml($memovals[$i]);
           }
        }
    
    }
    print $out "</source>\n";
    
   }
   
 }
 

sub makehandle
{
   my $self = shift;
   if( ref $self )
   {
       return $self->SUPER::makehandle('S');
   }
   else
   {
       return TmgGramps::GrampsEntity::makehandle('S',@_);
    }
 }


 sub createTable
 {
   my $self = shift;
   my $myh = shift;

   $self->_create_table( $myh, $self->{_TABLE}, \%srccolspecs ); 
   $self->_create_table( $myh, get_tablename( $self->tablebase, 'sourcecomponent'), \%srccompcolspecs );
 }
 
 sub copyTable
 {
   my $self = shift;
   my $myh = shift;
   my $dbfh = shift;
   my $comptable = get_tablename( $self->tablebase, 'sourcecomponent');

   $self->_copy_table( $dbfh, $myh, $self->{_TABLE}, [ keys(%srccolspecs) ] );
   $self->_copy_table( $dbfh, $myh, $comptable, [ keys(%srccompcolspecs) ] );
   $self->_create_indexes( $myh, $self->{_TABLE}, \@indexes );
   $self->_create_indexes( $myh, $comptable, \@compindexes );
 }

1;
