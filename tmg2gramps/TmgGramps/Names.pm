package TmgGramps::Names;

use strict;
use warnings;
use Carp;
use TmgGramps::TableMappings qw(get_tablename);
use TmgGramps::Converters ();
use TmgGramps::GrampsEntity;
use TmgGramps::SourceRef;

@TmgGramps::Names::ISA = qw(TmgGramps::GrampsEntity);

my %namecolspecs = ( recno=>'int unsigned', altype=>'int unsigned', pr1mary=>'char', nnote=>'blob', 
                     ndate=>'char(30)', nsure=>'char', fsure=>'char', dsure=>'char', nper=>'int unsigned',
                     surid=>'int unsigned', givid=>'int unsigned', srnamedisp=>'char(70)' );
my %namedictcolspecs = ( value=>'blob', uid=>'int unsigned' );
my %namevalcolspecs = ( uid=>'int unsigned', type=>'int unsigned', recno=>'int unsigned' );
my %nametypecolspecs = ( value=>'char(100)', type=>'int unsigned' );

my @nameindexes = ( 'pr1mary', 'nper' );
my @namedictindexes = ( 'uid' );
my @nametypeindexes = ( 'type' );
my @namevalindexes = ( 'recno' );

sub new 
{
  my $class = shift;
  my $self  = $class->SUPER::new('names');
  $self->{PER_NO}   = undef;
  bless ($self, $class);
  return $self;
}

                            
 sub per_no
 {
   my $self = shift;
   if (@_) { $self->{PER_NO} = shift }
   return $self->{PER_NO};
 }



# Cannot do joins in following code, as XBase does not support them
sub writexml
{
  my $self = shift;
  my $out = shift;
  my $nametable = get_tablename( $self->{TABLEBASE}, 'names' );
  my $namedicttable = get_tablename( $self->{TABLEBASE}, 'namedict' );
  my $namevaltable = get_tablename( $self->{TABLEBASE}, 'namepv' );
  my $nametypetable = get_tablename( $self->{TABLEBASE}, 'namept' );
  my $tagtable = get_tablename( $self->{TABLEBASE}, 'tagtypes' );
  my @namevals;
  my @names;
  my @nametypes;
  my @namedicts;
  my @tagtypes;
  # following bit needed b/c primary is a field name used in tmg/xbase, and is keyword in mysql
  my $primary = ($self->{DBHANDLE}->get_info(17) =~ /mysql/i)?('pr1mary'):('primary');
  my $queryname = "select RECNO,ALTYPE,$primary,NNOTE,NDATE,NSURE,FSURE,DSURE from $nametable where nper=".$self->per_no;
  my $queryval = "select UID,TYPE from $namevaltable where recno=?";
  my $querydict = "select VALUE from $namedicttable where UID=?";
  my $querytype = "select VALUE from $nametypetable where type=?";
  my $querytagtype = "select ETYPENAME from $tagtable where etypenum=?";
  
  my $sthname = $self->{DBHANDLE}->prepare( $queryname );
  my $sthnval = $self->{DBHANDLE}->prepare( $queryval ); 
  my $sthndict = $self->{DBHANDLE}->prepare( $querydict );
  my $sthntype = $self->{DBHANDLE}->prepare( $querytype );
  my $sthtagtype = $self->{DBHANDLE}->prepare( $querytagtype );
  
  my $srcref =  TmgGramps::SourceRef->new();
  $srcref->sourcetype( 'N' );
  $srcref->dbhandle( $self->dbhandle );
  $srcref->tablebase( $self->tablebase );


  $sthname->execute() or die $sthname->errstr();
  
  
  while( @names= $sthname->fetchrow_array() )
  {
      print $out '<name';
    if( $names[2] != 1 ) 	# not primary
    {
      print $out ' alt="1"';
    }
    $sthtagtype->bind_param( 1, $names[1] );
    $sthtagtype->execute() or die $sthtagtype->errstr();
    @tagtypes = $sthtagtype->fetchrow_array();
    if( @tagtypes ) # assume one row matched
    {
      # ignored are Name-Baptm, Name-Var.
      # Name-Nick is mapped to Also Known As.
      # Assumes Name-Var is birth name, and does not add a type= for this,
      # which may perhaps cause problems with some databases?
      # CHANGE: Despite dtd saying otherwise, Gramps does not cope
      # with name tag without type attribute.
      if( $tagtypes[0] eq 'Name-Marr' )
      {
          print $out ' type="Married Name"';
      }
      elsif( $tagtypes[0] eq 'Name-Chg' )
      {
          print $out ' type="Other Name"';
      }
      elsif( $tagtypes[0] eq 'Name-Nick' )
      {
          print $out ' type="Also Known As"';
      }
      elsif( $tagtypes[0] eq 'Name-Var' )
      {
          print $out ' type="Birth Name"';
      }
      # else ignore
    }
    print $out '>';

    $sthnval->execute($names[0]) or die $sthnval->errstr();
    while( @namevals = $sthnval->fetchrow_array() )
    {
        $sthndict->execute( $namevals[0] );
        @namedicts = $sthndict->fetchrow_array();
        $sthntype->execute( $namevals[1] );
        @nametypes = $sthntype->fetchrow_array();
        
        # now should have details of one part of current name
        # TODO does not handle PreSurname which should map to 'prefix' attribute of 'last' element
        if( $nametypes[0] eq 'Title' )
        {
            print $out '<title>',$self->safexml($namedicts[0]),"</title>\n";
        }
        elsif( $nametypes[0] eq 'GivenName' )
        {
            print $out '<first>',$self->safexml($namedicts[0]),"</first>\n";
        }
        elsif( $nametypes[0] eq 'Surname' )
        {
            print $out '<last>',$self->safexml($namedicts[0]),"</last>\n";
        }
        elsif( $nametypes[0] eq 'Suffix' )
        {
            print $out '<suffix>',$self->safexml($namedicts[0]),"</suffix>\n";
        }
        # else ignore it
    }
        

    print $out TmgGramps::Converters::tmg2grampsdate( $names[4] );
    my @namenotes = TmgGramps::Converters::memo2array( $names[3] );
    if( defined( $namenotes[0] ) )
    {
      print $out '<note>',$self->safexml( join( ', ', @namenotes ) ), "</note>\n";
    }

    $srcref->refrec( $names[0] );
    $srcref->resetconf();
    $srcref->confidence( $names[5] );
    $srcref->confidence( $names[6] );
    $srcref->confidence( $names[7] );
    $srcref->writerefs( $out );
    
    print $out "</name>\n";
  }
  
}
    

sub makehandle
{
   my $self = shift;
   if( ref $self )
   {
       return $self->SUPER::makehandle('N');
   }
   else
   {
       return TmgGramps::GrampsEntity::makehandle('N',@_);
    }
 }
    

 sub createTable
 {
   my $self = shift;
   my $myh = shift;
   
   my $nametable = get_tablename( $self->{TABLEBASE}, 'names' );
   my $namedicttable = get_tablename( $self->{TABLEBASE}, 'namedict' );
   my $namevaltable = get_tablename( $self->{TABLEBASE}, 'namepv' );
   my $nametypetable = get_tablename( $self->{TABLEBASE}, 'namept' );

   $self->_create_table( $myh, $nametable, \%namecolspecs ); 
   $self->_create_table( $myh, $namedicttable, \%namedictcolspecs ); 
   $self->_create_table( $myh, $namevaltable, \%namevalcolspecs ); 
   $self->_create_table( $myh, $nametypetable, \%nametypecolspecs ); 

 }
 
 sub copyTable
 {
   my $self = shift;
   my $myh = shift;
   my $dbfh = shift;

   my $nametable = get_tablename( $self->{TABLEBASE}, 'names' );
   my $namedicttable = get_tablename( $self->{TABLEBASE}, 'namedict' );
   my $namevaltable = get_tablename( $self->{TABLEBASE}, 'namepv' );
   my $nametypetable = get_tablename( $self->{TABLEBASE}, 'namept' );
   
   $self->_copy_table( $dbfh, $myh, $nametable, [ keys(%namecolspecs) ] );
   $self->_copy_table( $dbfh, $myh, $namedicttable, [ keys(%namedictcolspecs) ] );
   $self->_copy_table( $dbfh, $myh, $namevaltable, [ keys(%namevalcolspecs) ] );
   $self->_copy_table( $dbfh, $myh, $nametypetable, [ keys(%nametypecolspecs) ] );
   $self->_create_indexes( $myh, $nametable, \@nameindexes );
   $self->_create_indexes( $myh, $namedicttable, \@namedictindexes );
   $self->_create_indexes( $myh, $namevaltable, \@namevalindexes );
   $self->_create_indexes( $myh, $nametypetable, \@nametypeindexes );
   
 }
 
      
1;
