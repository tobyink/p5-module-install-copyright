package Module::Install::Admin::Copyright;

use 5.008;
use base qw(Module::Install::Base);
use strict;

use Debian::Copyright;
use Module::Install::Admin::RDF 0.003;
use Module::Manifest;
use List::MoreUtils qw( uniq );
use RDF::Trine qw( iri literal statement );
use Software::License;
use Software::LicenseUtils;
use Path::Class qw( file dir );

our $AUTHOR_ONLY = 1;
our $AUTHORITY   = 'cpan:TOBYINK';
our $VERSION     = '0.001';

use RDF::Trine::Namespace qw[RDF RDFS OWL XSD];
my $CPAN = RDF::Trine::Namespace->new('http://purl.org/NET/cpan-uri/terms#');
my $DC   = RDF::Trine::Namespace->new('http://purl.org/dc/terms/');
my $DOAP = RDF::Trine::Namespace->new('http://usefulinc.com/ns/doap#');
my $FOAF = RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');
my $NFO  = RDF::Trine::Namespace->new('http://www.semanticdesktop.org/ontologies/2007/03/22/nfo#');
my $SKOS = RDF::Trine::Namespace->new('http://www.w3.org/2004/02/skos/core#');

sub write_copyright_file
{
	my $self  = shift;	
	my @files = uniq COPYRIGHT => sort $self->_get_dist_files;
	
	my $c = 'Debian::Copyright'->new;
	my @unknown;
	for my $f (@files)
	{
		my $stanza = $self->_handle_file($f);
		$stanza
			? $c->files->Push($stanza->Files => $stanza)
			: push(@unknown, $f);
	}
	
	if (@unknown)
	{
		my $stanza = 'Debian::Copyright::Stanza::Files'->new({
			Files     => join(q[ ], @unknown),
			Copyright => 'Unknown',
			License   => 'Unknown',
		});
		$c->files->Push($stanza->Files => $stanza);
	}

	$c->write('COPYRIGHT');
	$self->clean_files('COPYRIGHT');
}

sub _get_dist_files
{
	my @files;
	my $manifest = 'Module::Manifest'->new(undef, 'MANIFEST.SKIP');	
	dir()->recurse(callback => sub {
		my $file = shift;
		return if $file->is_dir;
		return if $manifest->skipped($file);
		return if $file =~ /^(\.\/)?MYMETA\./;
		return if $file =~ /^(\.\/)?Makefile$/;
		push @files, $file;
	});
	return map { s{^[.]/}{} ; "$_" } @files;
}

sub _handle_file
{
	my ($self, $f) = @_;
	my ($copyright, $licence, $comment) = $self->_determine_rights($f);
	return unless $copyright;
	
	'Debian::Copyright::Stanza::Files'->new({
		Files     => $f,
		Copyright => $copyright,
		License   => $licence,
		(Comment  => $comment)x(defined $comment),
	});
}

sub _determine_rights
{
	my ($self, $f) = @_;
	
	if (my @rights = $self->_determine_rights_from_rdf($f))
	{
		return @rights;
	}
	
	if (my @rights = $self->_determine_rights_from_pod($f))
	{
		return @rights;
	}
	
	if (my @rights = $self->_determine_rights_by_convention($f))
	{
		return @rights;
	}
	
	return;
}

sub _determine_rights_from_rdf
{
	return;
}

sub _determine_rights_from_pod
{
	my ($self, $f) = @_;
	return unless $f =~ /\.(?:pl|pm|pod|t)$/i;
	
	# For files in 'inc' try to figure out the normal (not stripped of pod)
	# module.
	#
	$f = $INC{$1} if $f =~ m{^inc/(.+\.pm)$}i && exists $INC{$1};
	
	my $text = file($f)->slurp;
	
	my @guesses = 'Software::LicenseUtils'->guess_license_from_pod($text);
	if (@guesses) {
		my $copyright =
			join q[ ],
			map  { s/\s+$//; /[.?!]$/ ? $_ : "$_." }
			grep { /^Copyright/i or /^This software is copyright/ }
			split /(?:\r?\n|\r)/, $text;
		
		$copyright =~ s{E<lt>}{<}g;
		$copyright =~ s{E<gt>}{>}g;
		
		return(
			$copyright,
			$guesses[0]->name,
		) if $copyright;
	}
	
	return;
}

sub _determine_rights_by_convention
{
	my ($self, $f) = @_;
	
	if ($f =~ /^META\.(yml|json)$/)
	{
		return(
			'None',
			'public-domain',
			'Automatically generated metadata.',
		);
	}

	if ($f =~ /^COPYRIGHT$/)
	{
		return(
			'None',
			'public-domain',
			'This file! Automatically generated.',
		);
	}
	
	if ($f =~ m{ inc/Module/Install/(
		Admin | Admin/Include | Base | Bundle | Can | Compiler | Deprecated |
		External | Makefile | PAR | Share | DSL | Admin/Bundle |
		Admin/Compiler | Admin/Find | Admin/Makefile | Admin/Manifest |
		Admin/Metadata | Admin/ScanDeps | Admin/WhiteAll | AutoInstall |
		Base/FakeAdmin | Fetch | Include | Inline | MakeMaker | Metadata |
		Run | Scripts | Win32 | With | WriteAll
	).pm }x or $f eq 'inc/Module/Install.pm')
	{
		return(
			'Copyright 2002 - 2012 Brian Ingerson, Audrey Tang and Adam Kennedy.',
			'Artistic or GPL-1+',
		);
	}
	
	if ($f eq 'inc/Module/Install/Package.pm') 
	{
		return(
			'Copyright (c) 2011. Ingy doet Net.',
			'Artistic or GPL-1+',
		);
	}
	
	if ($f eq 'inc/unicore/Name.pm' or $f eq 'inc/utf8.pm') 
	{
		return(
			'1993-2012, Larry Wall and others',
			'Artistic or GPL-1+',
		);
	}

	return;
}

1;
