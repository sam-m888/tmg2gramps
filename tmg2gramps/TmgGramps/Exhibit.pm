package TmgGramps::Exhibit;

use strict;
use warnings;
use Carp;
use TmgGramps::TableMappings qw(get_tablename);
use TmgGramps::Converters ();
use TmgGramps::GrampsEntity;

@TmgGramps::Exhibit::ISA = qw(TmgGramps::GrampsEntity);
     

my %mimes = ( 'jpg'=>'image/jpeg', 'jpeg'=>'image/jpeg', 'tiff'=>'image/tiff', 'tif'=>'image/tiff',
              'gif'=>'image/gif', 'png'=>'image/png',   'svg'=>'image/svg+xml', 'bmp'=>'image/x-ms-bmp',
              'au'=>'/audio/basic', 'wav'=>'audio/x-wav', 'mp3'=>'audio/mpeg', 'wma'=>'audio/x-ms-wma',
              'ogg'=>'application/ogg', 'pdf'=>'application/pdf', 'doc'=>'application/msword',
              'ps'=>'application/postscript', 'xml'=>'application/xml', 'odt'=>'application/vnd.oasis.opendocument.text',
              'html'=>'text/html', 'htm'=>'text/html', 'txt'=>'text/plain', 'rtf'=>'text/rtf', 
              'fli'=>'video/fli', 'mpeg'=>'video/mpeg', 'mpg'=>'/video/mpg', 'qt'=>'/video/quicktime',
              'mov'=>'video/quicktime', 'avi'=>'video/x-msvideo'
              );
                                

my %exhcolspecs = ( descript=>'blob', vfilename=>'blob', ifilename=>'blob', afilename=>'blob',
                    tfilename=>'blob', text=>'blob', xname=>'char(30)', caption=>'blob', 
                    idexhibit=>'int unsigned', reference=>'char(25)', id_event=>'int unsigned', 
                    id_person=>'int unsigned', id_source=>'int unsigned', id_repos=>'int unsigned', 
                    id_cit=>'int unsigned', id_place=>'int unsigned', image=>'blob', audio=>'blob');
                    
my @indexes = ( 'id_event','id_person','id_source','id_repos','id_cit','id_place');                    

sub new 
{
  my $class = shift;
  my $self  = $class->SUPER::new('exhibits','X');
  bless ($self, $class);
  return $self;
}

 sub writeall
 {
   my $self = shift;
   my $out = shift;
   my @data;
   my $fcount = 1;
   my $filebase ='exhibit';
   my $query = "select DESCRIPT,VFILENAME,IFILENAME,AFILENAME,TFILENAME,CAPTION,IDEXHIBIT,XNAME,REFERENCE,TEXT,IMAGE,AUDIO from ".$self->{_TABLE};
   my $count = 0;
     my $sth = $self->{DBHANDLE}->prepare( $query );
  $sth->execute() or die $sth->errstr();
  while( @data= $sth->fetchrow_array() )
  {
      ++$count;
    print STDERR '.' if( ($count % 100) == 0 );

    $self->id( $data[6] );
    my $fname;
    my $mimetype;
    my $caption;
    if( defined $data[1] ) # video
    {
      $fname = join '', TmgGramps::Converters::memo2array($data[1]);
    }
    elsif( defined $data[2] ) # image
    {
      $fname = join '', TmgGramps::Converters::memo2array($data[2]);
    }
    elsif( defined $data[3] ) # audio
    {
      $fname = join '', TmgGramps::Converters::memo2array($data[3]);
    }
    elsif( defined $data[4] ) # text
    {
      $fname = join '', TmgGramps::Converters::memo2array($data[4]);
    }
    elsif( defined $data[9] ) # internal text
    {
      $fname = sprintf( "%s%05d.txt", $filebase, $fcount++ );
      open( EOUT, ">$fname" ) || die "Couldn't create file $fname: $!\n";
      print EOUT $data[9];
      close( EOUT );
    }
    elsif( defined $data[10] ) # internal image
    {
      $fname = sprintf( "%s%05d.image", $filebase, $fcount++ );
      open( EOUT, ">$fname" ) || die "Couldn't create file $fname: $!\n";
      print EOUT $data[10];
      close( EOUT );
      
    }
    elsif( defined $data[11] ) # internal audio
    {
      $fname = sprintf( "%s%05d.audio", $filebase, $fcount++ );
      open( EOUT, ">$fname" ) || die "Couldn't create file $fname: $!\n";
      print EOUT $data[11];
      close( EOUT );
      
    }
      
    $caption = '';
    if( defined $data[0] )
    {
      $caption .= join ' ', TmgGramps::Converters::memo2array($data[0]);
    }
    elsif( defined $data[5] )
    {
      $caption .= join ' ', TmgGramps::Converters::memo2array($data[5]);
    }
    if( ($caption =~ /^\s*$/) && defined $data[7] )
    {
      $caption = $data[7];
    }

    if( defined $fname )
    {
      $mimetype = $self->_getmimetype( $fname );

      printf $out '<object id="O%04d" handle="%s" change="%s">', $self->id, $self->makehandle(), time();
      print $out "\n";
      printf $out '<file src="%s" mime="%s" description="%s"/>', $fname, $mimetype, $self->safexml($caption);
      print $out "\n";
      if( !($data[7] =~ /^\s*$/) )
      {
          printf $out '<attribute type="Name" value="%s"/>', $self->safexml($data[7]);
      }
      if( !($data[8] =~ /^\s*$/) )
      {
          printf $out '<attribute type="Reference" value="%s"/>', $self->safexml($data[8]);
      }
      my @note = TmgGramps::Converters::memo2array( $data[9] );
      if( @note && defined($note[0]) )
      {
          print $out '<note>',$self->safexml(join(' ',@note)),"</note>\n";
      }
      print $out "</object>";
    }
  }
   
 }

 
 sub _getmimetype
 {
   my $self = shift;
   my $fname = shift;
   
   my $mime = `file -ib $fname`;
   chomp $mime;
   return $mime;
   
 }
 
   
sub makehandle
{
   my $self = shift;
   if( ref $self )
   {
       return $self->SUPER::makehandle('X');
   }
   else
   {
       return TmgGramps::GrampsEntity::makehandle('X',@_);
    }
 }




 sub createTable
 {
   my $self = shift;
   my $myh = shift;

   $self->_create_table( $myh, $self->{_TABLE}, \%exhcolspecs ); 
 }
 
 sub copyTable
 {
   my $self = shift;
   my $myh = shift;
   my $dbfh = shift;

   $self->_copy_table( $dbfh, $myh, $self->{_TABLE}, [ keys(%exhcolspecs) ] );
   $self->_create_indexes( $myh, $self->{_TABLE}, \@indexes );
   
 }
 
1;

