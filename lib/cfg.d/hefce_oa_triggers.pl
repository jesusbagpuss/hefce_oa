#Define what types of items we're interested in
$c->{hefce_oa}->{item_types} = ['article', 'conference_item'];

$c->add_dataset_trigger( 'eprint', EPrints::Const::EP_TRIGGER_BEFORE_COMMIT, sub
{
    my( %args ) = @_;
    my( $repo, $eprint, $changed ) = @args{qw( repository dataobj changed )};

    return unless $eprint->dataset->has_field( "hoa_exclude" );

    if(!$eprint->is_set('hoa_exclude'))
    {
        $eprint->set_value('hoa_exclude', 'FALSE');
    }

    return EP_TRIGGER_OK;

}, priority => 100 );

# date of first compliant deposit
$c->add_dataset_trigger( 'eprint', EPrints::Const::EP_TRIGGER_BEFORE_COMMIT, sub
{
	my( %args ) = @_; 
	my( $repo, $eprint, $changed ) = @args{qw( repository dataobj changed )};

	# trigger only applies to repos with hefce_oa plugin enabled
	return unless $eprint->dataset->has_field( "hoa_compliant" );

	return if $eprint->is_set( "hoa_date_fcd" );
	return if $eprint->value( "eprint_status" ) eq "inbox";

	for( $eprint->get_all_documents )
	{
		next unless $_->is_set( "content" );
		next unless $_->value( "content" ) eq "accepted" || $_->value( "content" ) eq "published";
    		$eprint->set_value( "hoa_date_fcd", EPrints::Time::get_iso_date() );
    		$eprint->set_value( "hoa_version_fcd", $_->value( "content" ) eq "accepted" ? "AM" : "VoR" );
	}
}, priority => 100 );

# date of first compliant open access
$c->add_dataset_trigger( 'eprint', EPrints::Const::EP_TRIGGER_BEFORE_COMMIT, sub
{
	my( %args ) = @_; 
	my( $repo, $eprint, $changed ) = @args{qw( repository dataobj changed )};

	# trigger only applies to repos with hefce_oa plugin enabled
	return unless $eprint->dataset->has_field( "hoa_compliant" );

	return unless $eprint->is_set( "hoa_date_fcd" );
	return if $eprint->is_set( "hoa_date_foa" );

	for( $eprint->get_all_documents )
	{
		next unless $_->is_set( "content" );
		next unless $_->value( "content" ) eq "accepted" || $_->value( "content" ) eq "published";
		next unless $_->is_public;
    		$eprint->set_value( "hoa_date_foa", EPrints::Time::get_iso_date() );
	}
}, priority => 200 );

$c->add_dataset_trigger( 'document', EPrints::Const::EP_TRIGGER_BEFORE_COMMIT, sub
{
	my( %args ) = @_; 
	my( $repo, $doc, $changed ) = @args{qw( repository dataobj changed )};

	# trigger only applies to repos with hefce_oa plugin enabled
	return unless $doc->parent->dataset->has_field( "hoa_compliant" );

	return unless $doc->is_public;
	return if $doc->parent->is_set( "hoa_date_foa" );

	# make sure eprint->commit calls triggers..
	# see https://github.com/eprintsug/hefce_oa/issues/19
	$doc->parent->{changed}->{hoa_update_ep}++;
}, priority => 100 );


# set compliance flag
$c->add_dataset_trigger( 'eprint', EPrints::Const::EP_TRIGGER_BEFORE_COMMIT, sub
{
	my( %args ) = @_;
	my( $repo, $eprint, $changed ) = @args{qw( repository dataobj changed )};

	# trigger only applies to repos with hefce_oa plugin enabled
	return unless $eprint->dataset->has_field( "hoa_compliant" );

	my $type = $eprint->value( "type" );

	unless( defined $type && grep( /^$type$/, @{$repo->config( "hefce_oa", "item_types" )} ) )
	{		
		$eprint->set_value( "hoa_compliant", undef );
		return;
	}

	my $flag = 0;
	for(qw(
		DEP_COMPLIANT
		DEP_TIMING
		DEP
		DIS_DISCOVERABLE
		DIS
		ACC_TIMING
		ACC_EMBARGO
		ACC
		EX_DEP
		EX_ACC
		EX_TEC
		EX_FUR
		EX
		COMPLIANT
	))
	{
		$flag |= HefceOA::Const->$_ if $repo->call( [qw( hefce_oa run_test )], $repo, $_, $eprint, $flag );
	}

	$eprint->set_value( "hoa_compliant", $flag );

}, priority => 300 );
