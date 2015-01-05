package TmgGramps::Family;


use strict;
use warnings;
use TmgGramps::TableMappings qw(get_tablename);
use TmgGramps::GrampsEntity;

@TmgGramps::Family::ISA = qw(TmgGramps::GrampsEntity);

my $familyid = 0;

my %famcolspecs = ( child=>'int unsigned', parent=>'int unsigned', ptype=>'int unsigned', pnote=>'blob',
							psure=>'char', fsure=>'char', recno=>'int unsigned' );

my @indexes = ( 'ptype', 'parent', 'child' );

sub new 
{
  my $class = shift;
  my $self  = $class->SUPER::new('family');
  $self->{FATHER}   = undef;
  $self->{MOTHER} = undef;
  $self->{PARENTS} = ();
  $self->{CHILDREN} = ();
  $self->{_FAMILYID} = \$familyid;
  bless ($self, $class);
  ++ ${ $self->{_FAMILYID} };
  $self->{REC_NO} = ${ $self->{_FAMILYID} };
  return $self;
}


  
  sub set_sex
  {
    my $self = shift;
    my $psnid = shift;
    my $sex = shift;
    
    if( defined ${ $self->{PARENTS}}{$psnid} )
    {
        if( $sex eq 'M' )
        {
            $self->{FATHER} = $psnid;
        }
        elsif( $sex eq 'F' )
        {
            $self->{MOTHER} = $psnid;
        }
    }
  }
  
  sub is_child
  {
    my $self = shift;
    my $psnid = shift;
    
    return ${ $self->{CHILDREN} }{$psnid};
  }
  
  sub is_parent
  {
    my $self = shift;
    my $psnid = shift;
    
    if( (defined($self->{FATHER}) && $self->{FATHER} == $psnid) ||
        (defined($self->{MOTHER}) && $self->{MOTHER} == $psnid) )
    {
        return 1;
    }
    else
    {
        return ${ $self->{PARENTS} }{$psnid };
    }
  }
    
  sub get_psnidlist
  {
    my $self = shift;
    my @idlist = ();
    push @idlist, keys(%{ $self->{PARENTS} });
    push @idlist, keys(%{ $self->{CHILDREN} });
    return @idlist;
  }
  
  sub father
  {
    my $self = shift;
   if (@_) { $self->{FATHER} = shift }
   return $self->{FATHER};
  }
  
  sub mother
  {
    my $self = shift;
   if (@_) { $self->{MOTHER} = shift }
   return $self->{MOTHER};
  }
  
  sub add_parents
  {
    my $self = shift;
    my $parents = shift;
    my $pid;
    foreach $pid (@$parents)
    {
       ${ $self->{PARENTS} }{$pid} = 1;
    }
  }

  sub add_child
  {
    my $self = shift;
    my $ch = shift;
    ${ $self->{CHILDREN} }{$ch} = 1;
  }
  
  sub get_children
  {
    my $self = shift;
    return keys( %{ $self->{CHILDREN} } );
  }
  

sub makehandle
{
   my $self = shift;
   if( ref $self )
   {
       return $self->SUPER::makehandle('F');
   }
   else
   {
       return TmgGramps::GrampsEntity::makehandle('F',@_);
    }
 }


 sub createTable
 {
   my $self = shift;
   my $myh = shift;

   $self->_create_table( $myh, $self->{_TABLE}, \%famcolspecs ); 
 }
 
 sub copyTable
 {
   my $self = shift;
   my $myh = shift;
   my $dbfh = shift;

   $self->_copy_table( $dbfh, $myh, $self->{_TABLE}, [ keys(%famcolspecs) ] );
   $self->_create_indexes( $myh, $self->{_TABLE}, \@indexes );
   
 }
 
1;

