package TmgGramps::Converters;

use strict;
use warnings;
use POSIX ();
use Text::Iconv;

BEGIN
{
  use Exporter ();
  our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS );
  $VERSION = 0.1;
  @ISA = qw(Exporter);
  @EXPORT = ();
  %EXPORT_TAGS = ();
  @EXPORT_OK = qw(date2unixtime );
}
our @EXPORT_OK;
our $converter = Text::Iconv->new("WINDOWS-1250", "UTF-8");

sub date2unixtime($) 
{
  my $origdate = shift;
  my ($yr,$mn,$dy,$hr,$min,$sec);
  $origdate =~ /(\d{4})(\d{2})(\d{2})(\d{2})?(\d{2})?(\d{2})?/;
  $yr = ($1)?($1):(0);
  $mn = ($2)?($2):(0);
  $dy = ($3)?($3):(0);
  $hr = ($4)?($4):(0);
  $min = ($5)?($%):(0);
  $sec = ($6)?($6):(0);
  $yr -= 1900;
  $mn--;
  
  return POSIX::mktime( $sec, $min, $hr, $dy, $mn, $yr );
}


sub tmg2grampsdate
{
  my $tmgdate = shift;
  return undef if( !(defined $tmgdate) || $tmgdate =~ /^\s*$/ );
  my $irreg = substr $tmgdate, 0, 1;
  if( $irreg == 0 )
  {
    # an irregular date
    return sprintf( '<datestr val="%s"/>', substr( $tmgdate, 1 ) );
  }
  # else a regular date
  my $date1 = sprintf( '%s-%s-%s', substr( $tmgdate, 1, 4), substr( $tmgdate, 5, 2), substr( $tmgdate, 7, 2) );
  # TODO ignoring old style date option for now
  my $datetype = substr $tmgdate, 10, 1;
  my $question = substr $tmgdate, 21, 1;
  if( $datetype > 4 )
  {
     # date range
     my $date2 = sprintf( '%s-%s-%s', substr( $tmgdate, 11, 4 ), substr( $tmgdate, 15, 2 ), substr( $tmgdate, 17, 2 ) );
     # TODO ignoring old style dates for now
     return sprintf( '<daterange start="%s" stop="%s" %s/>', $date1, $date2, (($question eq '1')?('quality="estimated"'):('')) );
   }
   else
   {
     # date value
     my $type = '';
     if( $datetype == 0 ) # 'before'
     {
           $type = ' type="before" ';
     }
     elsif( $datetype == 1 || $datetype == 2 ) # 'say' or 'circa'
     {
           $type = ' type="about" ';
     }
     elsif( $datetype == 4 ) # 'after'
     {
           $type = ' type="after" ';
     }
     # else no type attribute
     return sprintf( '<dateval val="%s" %s %s/>', $date1,(($question eq '1')?('quality="estimated"'):('')), $type );
   }
       
}


sub tmg2grampsdateyear
{
  my $tmgdate = shift;
  my $irreg = substr $tmgdate, 0, 1;
  if( $irreg == 0 )
  {
     # an irregular date
     return '';
  }
  else
  {
    return substr $tmgdate, 1, 4;
  }
}

  

# Escapes appropriate entities for xml
# Also converts Windows-1250 encoding to UTF-8
sub safexml
{
  my $str = shift;
  $str = $converter->convert( $str );
  $str =~ s/&/&amp;/g;
  $str =~ s/\</&lt;/g;
  $str =~ s/\>/&gt;/g;
  $str =~ s/\"/&quot;/g;
  
  return $str;
}

sub memo2array
{
  my $memo = shift;
  my @result;
  
#print STDERR "mem starts as $memo\n";

  if( !(defined $memo) || ($memo =~ /^\s*$/) )
  {
#  print STDERR "Returning undef\n";
    return undef;
  }
  
  $memo =~ s/^\s+//;
  $memo =~ s/\s+$//;
  
  my @flds = split /(\$\!\&)+/, $memo;
  
  foreach my $res (@flds)
  {
    $res =~ s/^\s+//;
    $res =~ s/\s+$//;
    $res =~ s/\$\!\&//g;
    if( !($res =~ /^\s*$/) )
    {
      push @result, $res;
    }
  }
  
  # special case
  if( @result && $#result == 0 && ($result[0] =~ /^\[.+\]$/) )
  {
#  print STDERR "Splitting [][][]\n";
    @result = split '\]\[', $result[0];
    $result[0] =~ s/\[//;
    $result[$#result] =~ s/\]//;
  }

#if( @result )
#{
#  print STDERR "memo ends as ",join( ' : ', @result),"\n";
#}
#else
#{
#  print STDERR "result is undef\n";
#}   
  return @result;
  
}
  
  
 




END
{
}

1;