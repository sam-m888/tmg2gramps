#
# A hash mapping the TMG database 'names' to more memorable strings

package TmgGramps::TableMappings;

use strict;
use warnings;

BEGIN
{
  use Exporter ();
  our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
  $VERSION = 0.1;
  @ISA = qw(Exporter);
  @EXPORT = ();
  %EXPORT_TAGS = ();
  @EXPORT_OK = qw(get_tablename);
}
our @EXPORT_OK;

my %tablemapping  = ( 'people'=>'$', 'events'=>'g', 'namepv'=>'npv',
                  'namept'=>'npt', 'namedict'=>'nd', 'names'=>'n',
                  'witnesses'=>'e', 'tasks'=>'l', 'tagtypes'=>'t',
                  'family'=>'f', 'places'=>'p', 'placept'=>'ppt',
                  'placepv'=>'ppv', 'placedict'=>'pd', 'sources'=>'m',
                  'sourcerepo'=>'w', 'repo'=>'r', 'citations'=>'s',
                  'exhibits'=>'i', 'sourcecat'=>'a', 'sourcecomponent'=>'u',
                  'sourcemap'=>'map'
                  );
  

sub get_tablename($$)
{
  my( $tablebase, $tablename) = @_;
#  print STDERR "looking for $tablename\n";
  return $tablebase.'_'.$tablemapping{$tablename};
}

END
{
}

                  
1;
