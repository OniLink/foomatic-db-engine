
package Foomatic::DB;
use Exporter;
@ISA = qw(Exporter);

@EXPORT_OK = qw(normalizename comment_filter
		get_overview
		getexecdocs
		);

use Foomatic::Defaults qw(:DEFAULT $DEBUG);
use Data::Dumper;
use POSIX;                      # for rounding integers

my $ver = '$Revision$ ';

# constructor for Foomatic::DB
sub new {
    my $type = shift(@_);
    my $this = bless {@_}, $type;
    return $this;
}

# A map from the database's internal one-letter types to English
my %driver_types = ('F' => 'Filter',
		    'P' => 'Postscript',
		    'U' => 'Ghostscript Uniprint',
		    'G' => 'Ghostscript');

# List of driver names
sub get_driverlist {
    my ($this) = @_;
    return $this->_get_xml_filelist('source/driver');
}

# List of printer id's
sub get_printerlist {
    my ($this) = @_;
    return $this->_get_xml_filelist('source/printer');
}

sub get_overview {
    my ($this, $rebuild) = @_;

    # "$this->{'overview'}" is a memory cache only for the current process
    if ((!defined($this->{'overview'}))
	or (defined($rebuild) and $rebuild)) {
	# Generate overview Perl data structure from database
	my $VAR1;
	eval (`$bindir/foomatic-combo-xml -O -l '$libdir' | $bindir/foomatic-perl-data -O`) ||
	    die ("Could not run \"foomatic-combo-xml\"/\"foomatic-perl-data\"!");
	$this->{'overview'} = $VAR1;
    }

    return $this->{'overview'};
}

sub get_overview_xml {
    my ($this, $compile) = @_;

    open( FCX, "$bindir/foomatic-combo-xml -O -l '$libdir'|")
	or die "Can't execute $bindir/foomatic-combo-xml -O -l '$libdir'";
    $_ = join('', <FCX>);
    close FCX;
    return $_;
}

sub get_combo_data_xml {
    my ($this, $drv, $poid, $withoptions) = @_;

    # Insert the default option settings if there are some and the user
    # desires it.
    my $options = "";
    if (($withoptions) && (defined($this->{'dat'}))) {
	my $dat = $this->{'dat'};
	for $arg (@{$dat->{'args'}}) {
	    my $name = $arg->{'name'};
	    my $default = $arg->{'default'};
	    if (($name) && ($default)) {
		$options .= " -o '$name'='$default'";
	    }
	}
    }

    open( FCX, "$bindir/foomatic-combo-xml -d '$drv' -p '$poid'$options -l '$libdir'|")
	or die "Can't execute $bindir/foomatic-combo-xml -d '$drv' -p '$poid'$options -l '$libdir'";
    $_ = join('', <FCX>);
    close FCX;
    return $_;
}

sub get_printer {
    my ($this, $poid) = @_;
    # Generate printer Perl data structure from database
    my $VAR1;
    if (-r "$libdir/db/source/printer/$poid.xml") {
	eval (`$bindir/foomatic-perl-data -P '$libdir/db/source/printer/$poid.xml'`) ||
	    die ("Could not run \"foomatic-perl-data\"!");
    } else {
	return undef;
    }
    return $VAR1;
}

sub get_printer_xml {
    my ($this, $poid) = @_;
    return $this->_get_object_xml("source/printer/$poid", 1);
}

sub get_driver {
    my ($this, $drv) = @_;
    # Generate driver Perl data structure from database
    my $VAR1;
    if (-r "$libdir/db/source/driver/$drv.xml") {
	eval (`$bindir/foomatic-perl-data -D '$libdir/db/source/driver/$drv.xml'`) ||
	    die ("Could not run \"foomatic-perl-data\"!");
    } else {
	return undef;
    }
    return $VAR1;
}

sub get_driver_xml {
    my ($this, $drv) = @_;
    return $this->_get_object_xml("source/driver/$drv", 1);
}

# Utility query function sorts of things:

sub get_printers_for_driver {
    my ($this, $drv) = @_;

    my $driver = $this->get_driver($drv);

    if (!defined($driver)) {return undef;}

    return map { $_->{'id'} } @{$driver->{'printers'}};
}

# Routine lookup; just examine the overview
sub get_drivers_for_printer {
    my ($this, $printer) = @_;

    my @drivers = ();

    my $over = $this->get_overview();

    my $p;
    for $p (@{$over}) {
	if ($p->{'id'} eq $printer) {
	    return @{$p->{'drivers'}};
	}
    }

    return undef;
}

# This function should apply a more or less senseful order to the argument
# names so that they appear kind of sorted in frontends
sub sortargs {

    # All sorting done case-insensitive and characters which are not a letter
    # or number are taken out!!

    # List of typical option names to appear at first
    # The terms must fit to the beginning of the line, terms which must fit
    # exactly must have '\$' in the end.
    my @standardopts = (
			# Options which appear in the "General" group in CUPS
			# and similar media handling options
			"pagesize",
			"papersize",
			"mediasize",
			"inputslot",
			"papersource",
			"mediasource",
			"sheetfeeder",
			"mediafeed",
			"paperfeed",
			"manualfeed",
			"manual",
			"outputtray",
			"outputslot",
			"outtray",
			"faceup",
			"facedown",
			"mediatype",
			"papertype",
			"mediaweight",
			"paperweight",
			"duplex",
			"sides",
			"binding",
			"tumble",
			"notumble",
			"media",
			"paper",
			# Other hardware options
			"inktype",
			"ink",
			# Page choice/ordering options
			"pageset",
			"pagerange",
			"pages",
			"nup",
			"numberup",
			# Printout quality, colour/bw
			"resolution",
			"gsresolution",
			"hwresolution",
			"quality",
			"printquality",
			"printoutquality",
			"bitsperpixel",
			"photomode",
			"photo",
			"colormode",
			"colourmode",
			"color",
			"colour",
			"grayscale",
			"gray",
			"monochrome",
			"mono",
			"blackonly",
			"colormodel",
			"colourmodel",
			"processcolormodel",
			"processcolourmodel",
			"printcolors",
			"printcolours",
			"outputtype",
			"outputmode",
			"printingmode",
			"printoutmode",
			"printmode",
			"mode",
			"imagetype",
			"imagemode",
			"image",
			"dithering",
			"dither",
			"halftoning",
			"halftone",
			"floydsteinberg",
			"ret\$",
			"cret\$",
			"photoret\$",
			# Adjustments
			"gammacorrection",
			"gammacorr",
			"gammageneral",
			"mastergamma",
			"stpgamma",
			"gammablack",
			"gammacyan",
			"gammamagenta",
			"gammayellow",
			"gamma",
			"density",
			"stpdensity",
			"hpljdensity",
			"tonerdensity",
			"inkdensity",
			"brightness",
			"stpbrightness",
			"saturation",
			"stpsaturation",
			"hue",
			"stphue",
			"tint",
			"stptint",
			"contrast",
			"stpcontrast",
			"black",
			"stpblack",
			"cyan",
			"stpcyan",
			"magenta",
			"stpmagenta",
			"yellow",
			"stpyellow"
			);
    # Bring the two option names into a standard form to compare them
    # in a better way
    my $first = normalizename(lc($a));
    $first =~ s/[\W_]//g;
    my $second = normalizename(lc($b));
    $second =~ s/[\W_]//g;
    # Check whether they are in the @standardopts list
    my $i;
    for ($i = 0; $i <= $#standardopts; $i++) {
	my $firstinlist = ($first =~ /^$standardopts[$i]/);
	my $secondinlist = ($second =~ /^$standardopts[$i]/);
	if (($firstinlist) && (!$secondinlist)) {return -1};
	if (($secondinlist) && (!$firstinlist)) {return 1};
    }

    # None of the search terms in the list, compare the standard-formed strings
    my $compare = ( $first cmp $second );
    if ($compare != 0) {return $compare};

    # No other criteria fullfilled, compare the original input strings
    return $a cmp $b;
}

sub sortvals {

    # All sorting done case-insensitive and characters which are not a letter
    # or number are taken out!!

    # List of typical choice names to appear at first
    # The terms must fit to the beginning of the line, terms which must fit
    # exactly must have '\$' in the end.
    my @standardvals = (
			# Default setting
			"default",
			"printerdefault",
			# Paper sizes
			"letter\$",
			#"legal",
			"a000004\$",
			# Resolutions
			"000060x60",
			"000060\\D",
			"000060\$",
			"000060x72",
			"000060x90",
			"000060x120",
			"000060x144",
			"000060x180",
			"000060x216",
			"000060x240",
			"000060x360",
			"000072x60",
			"000072x72",
			"000072\\D",
			"000072\$",
			"000072x90",
			"000072x120",
			"000072x144",
			"000072x180",
			"000072x216",
			"000072x240",
			"000072x360",
			"000075x75",
			"000075\\D",
			"000075\$",
			"000090x60",
			"000090x72",
			"000090x90",
			"000090\\D",
			"000090\$",
			"000090x120",
			"000090x144",
			"000090x180",
			"000090x216",
			"000090x240",
			"000090x360",
			"000100x100",
			"000100\\D",
			"000100\$",
			"000120x60",
			"000120x72",
			"000120x90",
			"000120x120",
			"000120\\D",
			"000120\$",
			"000120x144",
			"000120x180",
			"000120x216",
			"000120x240",
			"000120x360",
			"000128x128",
			"000128\\D",
			"000128\$",
			"000144x60",
			"000144x72",
			"000144x90",
			"000144x120",
			"000144x144",
			"000144\\D",
			"000144\$",
			"000144x180",
			"000144x216",
			"000144x240",
			"000144x360",
			"000150x75",
			"000150x150",
			"000150\\D",
			"000150\$",
			"000150x300",
			"000150x600",
			"000180x60",
			"000180x72",
			"000180x90",
			"000180x120",
			"000180x144",
			"000180x180",
			"000180\\D",
			"000180\$",
			"000180x216",
			"000180x240",
			"000180x360",
			"000200x200",
			"000200\\D",
			"000200\$",
			"000216x60",
			"000216x72",
			"000216x90",
			"000216x120",
			"000216x144",
			"000216x180",
			"000216x216",
			"000216\\D",
			"000216\$",
			"000216x240",
			"000216x360",
			"000240x60",
			"000240x72",
			"000240x90",
			"000240x120",
			"000240x144",
			"000240x180",
			"000240x216",
			"000240x240",
			"000240\\D",
			"000240\$",
			"000240x360",
			"000240x480",
			"000240x720",
			"000300x75",
			"000300x150",
			"000300x300",
			"000300\\D",
			"000300\$",
			"000300x600",
			"000300x1200",
			"000360x60",
			"000360x72",
			"000360x90",
			"000360x120",
			"000360x144",
			"000360x180",
			"000360x216",
			"000360x240",
			"000360x360",
			"000360\\D",
			"000360\$",
			"000360x720",
			"000360x1440",
			"000400x400",
			"000400\\D",
			"000400\$",
			"000600x150",
			"000600x300",
			"000600x600",
			"000600\\D",
			"000600\$",
			"000600x1200",
			"000600x2400",
			"000720x360",
			"000720x720",
			"000720\\D",
			"000720\$",
			"000720x1440",
			"000720x2880",
			"001200x300",
			"001200x600",
			"001200x1200",
			"001200\\D",
			"001200\$",
			"001200x2400",
			"001200x4800",
			"001440x360",
			"001440x720",
			"001440x1440",
			"001440\\D",
			"001440\$",
			"001440x2880",
			"002400x600",
			"002400x1200",
			"002400x2400",
			"002400\\D",
			"002400\$",
			"002400x4800",
			"002880x360",
			"002880x720",
			"002880x1440",
			"002880x2880",
			"002880\\D",
			"002880\$",
			"004800x4800",
			"004800\\D",
			"004800\$",
			# Trays
			"upper",
			"top",
			"middle",
			"mid",
			"lower",
			"bottom",
			"highcapacity",
			"multipurpose",
			"tray",
			# Paper types
			"plain",
			"normal",
			);
    # Bring the two option names into a standard form to compare them
    # in a better way
    my $first = normalizename(lc($a));
    $first =~ s/[\W_]//g;
    my $second = normalizename(lc($b));
    $second =~ s/[\W_]//g;
    # Check whether they are in the @standardopts list
    my $i;
    for ($i = 0; $i <= $#standardvals; $i++) {
	my $firstinlist = ($first =~ /^$standardvals[$i]/);
	my $secondinlist = ($second =~ /^$standardvals[$i]/);
	if (($firstinlist) && (!$secondinlist)) {return -1};
	if (($secondinlist) && (!$firstinlist)) {return 1};
    }

    # None of the search terms in the list, compare the standard-formed strings
    my $compare = ( $first cmp $second );
    if ($compare != 0) {return $compare};

    # No other criteria fullfilled, compare the original input strings
    return $a cmp $b;
}

# Take driver/pid arguments and generate a Perl data structure for the
# Perl filter scripts. Sort the options and enumerated choices so that
# they get presented more nicely on frontends which do not sort by
# themselves

sub getdat {
    my ($this, $drv, $poid) = @_;

    my %dat;			# Our purpose in life...

    # Generate Perl data structure from database
    my $VAR1;
    eval (`$bindir/foomatic-combo-xml -d '$drv' -p '$poid' -l '$libdir' | $bindir/foomatic-perl-data -C`) ||
	die ("Could not run \"foomatic-combo-xml\"/\"foomatic-perl-data\"!");
    %dat = %{$VAR1};

    # The following stuff is very awkward to implement in C, so we do
    # it here.

    # Sort options with "sortargs" function
    my @sortedarglist = sort sortargs keys(%{$dat{'args_byname'}});
    @{$dat{'args'}} = ();
    for my $i (@sortedarglist) {
	my $arg = $dat{'args_byname'}{$i};
	push (@{$dat{'args'}}, $arg);
    }

    # Sort values of enumerated options with "sortvals" function
    for my $arg (@{$dat{'args'}}) {
       	my @sortedvalslist = sort sortvals keys(%{$arg->{'vals_byname'}});
	@{$arg->{'vals'}} = ();
	for my $i (@sortedvalslist) {
	    my $val = $arg->{'vals_byname'}{$i};
	    push (@{$arg->{'vals'}}, $val);
	}
    }

    $dat{'compiled-at'} = localtime(time());
    $dat{'timestamp'} = time();

    my $user = `whoami`; chomp $user;
    my $host = `hostname`; chomp $host;

    $dat{'compiled-by'} = "$user\@$host";

    # Funky one-at-a-time cache thing
    $this->{'dat'} = \%dat;

    return \%dat;
}



###################
# MagicFilter with LPRng
#
# getmfdata() returns a magicfilter 2 printer m4 def file

sub getmfdata {
    my ($this) = @_;
    die "you must call getdat first\n" if (!$this->{'dat'});

    my $dat = $this->{'dat'};
    my $driver = $dat->{'driver'};

    my $make = $dat->{'make'};
    my $model = $dat->{'model'};
    my $color = ($dat->{'color'} ? 'true' : 'false');
    my $text = ($dat->{'ascii'} ? 'true' : 'false');
    my $filename = "$make-$model-$driver";
    $filename =~ s![ /]!_!g;
    
    my $tag = $this->{'tag'};
    my $tagfilen;
    if ($tag) {
	$tagfilen = "-$tag";
    }

    push (@decl,
	  "#! \@MAGICFILTER\@\n",
	  "define(Vendor, `$make')dnl\n",
	  "define(Printer, `$model (via $driver driver)')dnl\n",
	  "define(FOOMATIC, `$libdir/data$tagfilen/$filename.foo')dnl\n",
	  "define(COLOR, $color)dnl\n",
	  "define(TEXT, $text)dnl\n");

    return @decl;
}


###################
# PDQ
#
# getpdqdata() returns a PDQ driver description file.

my $pdqomaticversion = $ver;
my $enscriptcommand = 'mpage -o -1 -P- -';

sub getpdqdata {
    my ($this) = @_;
    die "you must call getdat first\n" if (!$this->{'dat'});

    my $dat = $this->{'dat'};
    my $driver = $dat->{'driver'};
    my $make = $dat->{'make'};
    my $model = $dat->{'model'};

    # Encase data for inclusion in the PDQ config file
    my @datablob;
    for(split('\n',$this->getascii())) {
	push(@datablob, "# COMDATA #$_\n");
    }
    
    # Construct structure with driver information
    my @declaration=undef;

    # Construct structure for searching the job whether it contains options
    # added by a PPD-driven client application
    my @searchjobforoptions;
    push (@searchjobforoptions, 
	  "    for opt in \`grep FoomaticOpt \$INPUT | cut -d \" \" -f 3\`; do\n",
	  "        option=\`echo \$opt | cut -d \"=\" -f 1\`\n",
	  "        value=\`echo \$opt | cut -d \"=\" -f 2\`\n",
	  "        case \"\$option\" in\n");

    # If we find only *ostScript style options, the job cannot contain
    # "%% FoomaticOpt" lines. Then we remove @searchjobforoptions
    # afterwards because we do not need to examine the job file.
    my $onlygsargs = 1;

    # First, compute the various option/value clauses
    for $arg (@{$dat->{'args'}}) {

	if ($arg->{'type'} eq 'enum') {
	    
	    my $com = $arg->{'comment'};
	    my $idx = $arg->{'idx'};
	    my $def = $p->{'arg_default'};
	    my $nam = $arg->{'name'};
	    $arg->{'varname'} = "EOPT_$idx";
	    $arg->{'varname'} =~ s![\-\/\.]!\_!g;
	    my $varn = $arg->{'varname'};
	    my $gsarg = 1 if ($arg->{'style'} eq 'G');

	    if (!$gsarg) {$onlygsargs = 0};

	    # No quotes, thank you.
	    $com =~ s!\"!\\\"!g;
	    
	    push(@driveropts,
		 "  option {\n",
		 "    var = \"$varn\"\n",
		 "    desc = \"$com\"\n");
	    
	    push(@searchjobforoptions,
		 "          $nam)\n",
		 "            case \"\$value\" in\n") unless $gsarg;
	
	    # get enumeration values for each enum arg
	    my ($ev, @vals, @valstmp);
	    for $ev (@{$arg->{'vals'}}) {
		my $choiceshortname = $ev->{'value'};
		my $choicename = "${nam}_${choiceshortname}";
		my $val = (defined($ev->{'driverval'}) 
			   ? $ev->{'driverval'} 
			   : $ev->{'value'});
		$val =~ s!\"!\\\"!g;
		my $com = $ev->{'comment'};
		
		# stick another choice on driveropts
		push(@valstmp,
		     "    choice \"$choicename\" {\n",
		     "      desc = \"$com\"\n",
		     "      value = \"$val\"\n",
		     "    }\n");
		push(@searchjobforoptions,
		     "              $choiceshortname)\n",
		     "                $varn=\"$val\"\n",
		     "                ;;\n") unless $gsarg;
	    }
	    
	    push(@driveropts,
		 "    default_choice \"" . $nam . "_" . $arg->{'default'} . 
		 "\"\n",
		 @valstmp,
		 "  }\n\n");

	    push(@searchjobforoptions,
		 "            esac\n",
		 "            ;;\n") unless $gsarg;
	    
	} elsif ($arg->{'type'} eq 'int' or $arg->{'type'} eq 'float') {
	    
	    my $com = $arg->{'comment'};
	    my $idx = $arg->{'idx'};
	    my $nam = $arg->{'name'};
	    my $max = $arg->{'max'};
	    my $min = $arg->{'min'};
	    $arg->{'varname'} = "OPT_$nam";
	    $arg->{'varname'} =~ s![\-\/\.]!\_!g;
	    my $varn = $arg->{'varname'};
	    my $legal = $arg->{'legal'} = "Minimum value: $min, Maximum value: $max";
	    my $gsarg = 1 if ($arg->{'style'} eq 'G');
	    
	    if (!$gsarg) {$onlygsargs = 0};

	    my $defstr = "";
	    if ($arg->{'default'}) {
		$defstr = sprintf("    def_value \"%s\"\n", 
				  $arg->{'default'});
	    }
	    
	    push(@driveropts,
		 "  argument {\n",
		 "    var = \"$varn\"\n",
		 "    desc = \"$nam\"\n",
		 $defstr,
		 "    help = \"$com $legal\"\n",
		 "  }\n\n");
	    
	    push(@searchjobforoptions,
		 "          $nam)\n",
		 "            $varn=\"\$value\"\n",
		 "            ;;\n") unless $gsarg;

	} elsif ($arg->{'type'} eq 'bool') {
	    
	    my $com = $arg->{'comment'};
	    my $tname = $arg->{'name_true'};
	    my $fname = $arg->{'name_false'};
	    my $idx = $arg->{'idx'};
	    $arg->{'legal'} = "Value is a boolean flag";
	    $arg->{'varname'} = "BOPT_$idx";
	    $arg->{'varname'} =~ s![\-\/\.]!\_!g;
	    my $varn = $arg->{'varname'};
	    my $proto = $arg->{'proto'}; 
	    my $gsarg = 1 if ($arg->{'style'} eq 'G');
	    
	    if (!$gsarg) {$onlygsargs = 0};

	    my $defstr = "";
	    if ($arg->{'default'}) {
		$defstr = sprintf("    default_choice \"%s\"\n", 
				  $arg->{'default'} ? "$tname" : "$fname");
	    } else {
		$defstr = sprintf("    default_choice \"%s\"\n", "$fname");
	    }
	    push(@driveropts,
		 "  option {\n",
		 "    var = \"$varn\"\n",
		 "    desc = \"$com\"\n",
		 $defstr,
		 "    choice \"$tname\" {\n",
		 "      desc = \"$tname\"\n",
		 "      value = \"TRUE\"\n",
		 "    }\n",
		 "    choice \"$fname\" {\n",
		 "      desc = \"$fname\"\n",
		 "      value = \"FALSE\"\n",
		 "    }\n",
		 "  }\n\n");

	    push(@searchjobforoptions,
		 "          $tname)\n",
		 "            case \"\$value\" in\n",
		 "              True)\n",
		 "                $varn=\"TRUE\"\n",
		 "                ;;\n",
		 "              False)\n",
		 "                $varn=\"FALSE\"\n",
		 "                ;;\n",
		 "            esac\n",
		 "            ;;\n") unless $gsarg;
	}
	
    }
    
    if ($onlygsargs) {
	@searchjobforoptions = ();
    } else {
	push (@searchjobforoptions, 
	      "        esac\n",
	      "    done\n\n");
    }

    ## Define the "docs" option to print the driver documentation page

    push(@driveropts,
	 "  option {\n",
	 "    var = \"DRIVERDOCS\"\n",
	 "    desc = \"Print driver usage information\"\n",
	 "    default_choice \"nodocs\"\n", 
	 "    choice \"docs\" {\n",
	 "      desc = \"Yes\"\n",
	 "      value = \"yes\"\n",
	 "    }\n",
	 "    choice \"nodocs\" {\n",
	 "      desc = \"No\"\n",
	 "      value = \"no\"\n",
	 "    }\n",
	 "  }\n\n");
    
    ## Now let's compute the postscript filter part
    my @drivfilter;
    push(@drivfilter,
	 "  language_driver postscript {\n",
	 "    # Various postscript tricks would go here\n",
	 "  }\n\n");

    ## Add ASCII to drivfilter!
    ## FIXME
    # Options: we do ascii, so just crlf fix it

    push (@drivfilter,
	  "  language_driver text {\n");

    # temporarily force slow-path ascii for stable release
    if (0 and $dat->{'ascii'}) {
	push(@drivfilter,
	     "\n",
             "     convert_exec {#!/bin/sh\n",
	     "\n",
	     "        sed 's/\$/\r/' \$INPUT > \$OUTPUT\n",
	     "        touch \$OUTPUT.ok\n",
	     "     }\n");
    } else {
	push(@drivfilter,
	     "
     convert_exec {#!/bin/sh

        cat \$INPUT | $enscriptcommand > \$OUTPUT
     }
");
    }

    push (@drivfilter,
	  "  }\n\n");

    ## Load the command line prototype, from which the final command line
    ## will be built.

    my $commandline = $dat->{'cmd'};

    ## Quote special characters so that they are not interpreted when
    ## PDQ builds the filter shell script, but only when PDQ executes it.

    $commandline =~ s!\\!\\\\!g;
    $commandline =~ s!\"!\\\"!g;
    $commandline =~ s!\$!\\\$!g;
        
    ## Now we go through all the options, ordered by the spots in the
    ## command line. The options will be stuffed into the right place
    ## depending on their type

    my @letters = qw/A B C D E F G H I J K L M Z/;
    for $spot (@letters) {
	if ($commandline =~ m!\%$spot!) {
	    
	  argument:
	    for $arg (sort { $a->{'order'} <=> $b->{'order'} } 
		      @{$dat->{'args'}}) {
		
		# Only do arguments that go in this spot
		next argument if ($arg->{'spot'} ne $spot);
		next argument if (($arg->{'style'} ne 'C') && 
				  ($arg->{'style'} ne 'G'));
		
		my $varname = $arg->{'varname'};
		my $cmd = $arg->{'proto'};
		my $comment = $arg->{'comment'};
		my $cmdvar = $arg->{'cmdvarname'} = "CMD_$varname";
		my $type = $arg->{'type'};
		my $gsarg = 1 if ($arg->{'style'} eq 'G');
		
		if ($type eq 'bool') {
		    
		    # If BOPT_whatever is true, the cmd is present.
		    # Otherwise this option is the empty string
		    push(@psfilter,
			 "      # $comment\n",
			 "      if [ \"x\${$varname}\" == 'xTRUE' ]; then\n",
			 "         $cmdvar=\'$cmd\'\n",
			 "      fi\n\n");
		    
		} elsif ($type eq 'int' or $type eq 'float'){
		    
		    # If [IF]OPT_whatever is non-null, put in the
		    # argument.  Otherwise this option is the empty
		    # string.  Error checking?
		    
		    my $fixedcmd = $cmd;
		    $fixedcmd =~ s!\%([^s])!\%\%$1!g;
		    if ($gsarg) {
			$fixedcmd =~ s!\"!\\\"!g;
		    } else {
			#$fixedcmd =~ s!([\\\"\$\;\,\!\&\<\>])!\\\\$1!g;
		    }
		    $fixedcmd = sprintf($fixedcmd, "\${$varname}");
		    
		    push(@psfilter,
			 "      # $comment\n",
			 "      # We aren't really checking for max/min.\n",
			 "      if [ \"x\${$varname}\" != 'x' ]; then\n",
			 "         $cmdvar=\"$fixedcmd\"\n",
			 "      fi\n\n");
		    
		} elsif ($type eq 'enum') {
		    
		    # If EOPT_whatever is non-null, put in the
		    # choice value.
		    
		    my $fixedcmd = $cmd;
		    $fixedcmd =~ s!\%([^s])!\%\%$1!g;
		    if ($gsarg) {
			$fixedcmd =~ s!\"!\\\"!g;
		    } else {
			#$fixedcmd =~ s!([\\\"\$\;\,\!\&\<\>])!\\\\$1!g;
		    }
		    $fixedcmd = sprintf($fixedcmd, "\${$varname}");
		    
		    push(@psfilter,
			 "      # $comment\n",
			 "      # We aren't really checking for legal vals.\n",
			 "      if [ \"x\${$varname}\" != 'x' ]; then\n",
			 "         $cmdvar=\"$fixedcmd\"\n",
			 "      fi\n\n");
		    
		} else {
		    
		    die "evil type!?\n";
		    
		}
		
		if (! $gsarg) {
		    # Insert the processed variable in the commandline
		    # just before the spot marker.
		    $commandline =~ s!\%$spot!\$$cmdvar\%$spot!;
		} else {
		    # Ghostscript/Postscript argument, prepend to job
		    push(@echoes, "echo \"\${$cmdvar}\"");
		}
	    }
	    
	    # Remove the letter marker from the commandline
	    $commandline =~ s!\%$spot!!;
	
	}
    }

    # Generate a driver documentation page which is printed when the user
    # uses the "docs" option.

    my $optstr = ("Specify each option as a -o/-a argument to pdq ie\n",
                  "% pdq -P printer -oDuplex_On -aTwo=2\n");
    
    push(@doctext, 
	 "Invokation summary for your $make $model printer as driven by\n",
	 "the $driver driver.\n",
	 "\n",
	 "$optstr\n",
	 "The following options are available for this printer:\n",
	 "\n");

    for $arg (@{$dat->{'args'}}) {
        my ($name,
            $required,
            $type,
            $comment,
            $spot,
            $default) = ($arg->{'name'},
                         $arg->{'required'},
                         $arg->{'type'},
                         $arg->{'comment'},
                         $arg->{'spot'},
                         $arg->{'default'});
 
        my $reqstr = ($required ? " required" : "n optional");
	push(@doctext,
	     "Option '$name':\n  A$reqstr $type argument.\n  $comment\n");
	push(@doctext,
	     "  This options corresponds to a PJL command.\n") if ($arg->{'style'} eq 'J');
 
        if ($type eq 'bool') {
            push(@doctext, "  Possible choices:\n");
	    my $tname = $arg->{'name_true'};
	    my $fname = $arg->{'name_false'};
	    push(@doctext, "   o -o${tname}: $tname\n");
	    push(@doctext, "   o -o${fname}: $fname\n");
	    my $defstr;
            if (defined($default)) {
                $defstr = ($default ? "$tname" : "$fname");
	    } else {
		$defstr = $fname;
	    }
	    push(@doctext, "  Default: $defstr\n");
	    push(@doctext, "  Example: -o$tname\n");
        } elsif ($type eq 'enum') {
            push(@doctext, "  Possible choices:\n");
            my $exarg;
            for (@{$arg->{'vals'}}) {
                my ($choice, $comment) = ($_->{'value'}, $_->{'comment'});
		push(@doctext, "   o -o${name}_$choice: $comment\n");
                $exarg=$choice;
            }
            if (defined($default)) {
                push(@doctext, "  Default: -o${name}_$default\n");
            }
            push(@doctext, "  Example: -o${name}_$exarg\n");
        } elsif ($type eq 'int' or $type eq 'float') {
            my ($max, $min) = ($arg->{'max'}, $arg->{'min'});
            my $exarg;
            if (defined($max)) {
                push(@doctext, "  Range: $min <= x <= $max\n");
                $exarg=$max;
            }
            if (defined($default)) {
                push(@doctext, "  Default: $default\n");
                $exarg=$default;
            }
            if (!$exarg) { $exarg=0; }
            push(@doctext, "  Example: -aOPT_$name=$exarg\n");
        }
 
	push(@doctext, "\n");
    }

    $docstr = join ("", @doctext);

    # Embed this text file as a "here document" in a shell script which makes
    # PostScript out of it because it will be passed through GhostScript and
    # GhostScript does not understand plain text

    $docstr = "cat <<EOF | $enscriptcommand\n" . $docstr . "\nEOF\n";

    # Execute command
    #
    # Spit out the command with all the post-processed arguments
    # stuffed in where the %A %B etc were.  Don't forget to deal
    # with the %Z normal gs option stuff.

    my $echostr = undef;
    if (scalar(@echoes)) {
	$echostr = join (";\\\n         ", @echoes);
    }

    $commandline =~ s!^\s*gs !\$gs !;
    $commandline =~ s!(\|\s*)gs !\|\$gs !;
    $commandline =~ s!(;\s*)gs !; \$gs !;

    # Important: the parantheses around "$commandline" allow the driver's
    # command line to be composed from various shell commands.
    push(@psfilter,
         "      gs=gs      # assume normal gs unless...\n",
         "      hash foomatic-gswrapper	&& gs='foomatic-gswrapper'\n",
	 "      if ! test -e \$INPUT.ok; then\n",
	 "        # Execute this puppy, already...\n",
	 ( defined($echostr) 
	   ? "        ($echostr;\\\n"
	   : "        ( \n"),
	 "         if [ \"x\$DRIVERDOCS\" == 'xyes' ]; then\n",
	 "           $docstr\n",
	 "         else\n",
	 "           cat \$INPUT\n",
	 "         fi\n",
	 "        ) | sh -c \"( $commandline )\"\\\n",
	 "            >> \$OUTPUT\n",
	 "        if ! test -e \$OUTPUT; then \n",
	 "           echo 'Error running Ghostscript; no output!'\n",
	 "           exit 1\n",
	 "        fi\n",
	 "      else\n",
	 "        ln -s \$INPUT \$OUTPUT\n",
	 "      fi\n\n");
    
    # OK, so much for the postscript_filter part.
    
    # Now let's compute the filter_exec script, which processes
    # all jobs right before sending.  Here is where we do PJL options.

    my (@pjlfilter, @pjlfilter_bot);
    if (defined($dat->{'pjl'})) {
	# Taken out the "JOB" PJL command here, some printers do not
	# support it
	#push(@pjlfilter, 
	#     "    echo -ne '\33%-12345X' > \$OUTPUT\n",
	#     "    echo '\@PJL JOB NAME=\"PDQ Print Job\"' >> \$OUTPUT\n");
	push(@pjlfilter, 
	     "    echo -ne '\33%-12345X' > \$OUTPUT\n",
	     "    echo '\@PJL' >> \$OUTPUT\n");
	
      argument:
	for $arg (sort { $a->{'order'} <=> $b->{'order'} } 
		  @{$dat->{'args'}}) {
	    
	    # Only do PJL arguments 
	    next argument if ($arg->{'style'} ne 'J');
	    
	    my $varname = $arg->{'varname'};
	    my $cmd = $arg->{'proto'};
	    my $comment = $arg->{'comment'};
	    my $cmdvar = $arg->{'cmdvarname'} = "CMD_$varname";
	    my $type = $arg->{'type'};
	    
	    my $pjlcmd = sprintf($cmd, "\$$varname");
	    $pjlcmd =~ s!\"!\\\"!g;
	    $pjlcmd =~ s!\\!\\\\!g;
	    
	    if ($type eq 'bool') {
		
		push(@pjlfilter,
		     "      # $comment\n",
		     "      if [ \"x\${$varname}\" != 'x' ]; then\n",
		     "        if [ \"x\${$varname}\" == 'xTRUE' ]; then\n",
		     "          echo \"\@PJL $pjlcmd\" >> \$OUTPUT\n",
		     "        fi\n",
		     "      fi\n\n");
		
	    } elsif ($type eq 'int' or $type eq 'float'){
		
		push(@pjlfilter,
		     "      # $comment\n",
		     "      if [ \"x\${$varname}\" != 'x' ]; then\n",
		     "        echo \"\@PJL $pjlcmd\" >> \$OUTPUT\n",
		     "      fi\n\n");
		
	    } elsif ($type eq 'enum') {
		
		# If EOPT_whatever is non-null, put in the
		# choice value.
		
		push(@pjlfilter,
		     "      # $comment\n",
		     "      if [ \"x\${$varname}\" != 'x' ]; then\n",
		     "        echo \"\@PJL $pjlcmd\" >> \$OUTPUT\n",
		     "      fi\n\n");
		
	    } else {
		
		die "evil type!?\n";
		
	    }
	    
	    # Insert the processed variable in the commandline
	    # just before the spot marker.
	    $commandline =~ s!\%$spot!\$$cmdvar\%$spot!;
	}
	
	# Send the job, followed by the end of job command
	# Taken out the "EOJ" PJL command here, some printers do not
	# support it
	#push(@pjlfilter_bot, 
	#     "    echo -ne '\33%-12345X' >> \$OUTPUT\n",
	#     "    echo '\@PJL RESET' >> \$OUTPUT\n",
	#     "    echo '\@PJL EOJ' >> \$OUTPUT\n\n");
	push(@pjlfilter_bot, 
	     "    echo -ne '\33%-12345X' >> \$OUTPUT\n",
	     "    echo '\@PJL RESET' >> \$OUTPUT\n\n");
	
    }

    my $wwwhome = 'http://www.linuxprinting.org/show_driver.cgi';
    my $showurl = "$wwwhome?driver=$driver";
    my $notes = $dat->{'comment'};
    $notes =~ s!\"!\\\"!sg;
    my $pname = $dat->{'make'} . " " . $dat->{'model'};
    
    push (@body,
	  "  # This PDQ driver was generated automatically by pdq-o-matic.cgi from\n",
	  "  # information in the Printing HOWTO's compatibility database.  It uses\n",
	  "  # the $driver driver to drive a $pname.  \n",
	  "  #\n",
	  "  # For more information on this driver please see the HOWTO's $driver\n",
	  "  # driver database entry at \n",
	  "  # $showurl\n\n",
	  "  help \"$notes\"\n\n",
	  
#	      (  $dat->{'type'} eq 'G' or $dat->{'type'} eq 'U' ? 
#		 "  requires \"gs\"\n" : ""),
	  
	  "  # We need the $driver driver, but I haven't implemented requires yet.\n\n",
	  
	  @driveropts,

	  @drivfilter,
	  
	  "  filter_exec {\n",
	  @searchjobforoptions,
	  @pjlfilter,
	  @psfilter,
	  @pjlfilter_bot,
	  "  }\n"
	  );
    
    my $version = $dat->{'timestamp'};
    my ($smake, $smodel) = ($dat->{'make'}, $dat->{'model'});
    $smake =~ s/ /\-/g;
    $smodel =~ s/ /\-/g;
    my $name = "POM-$driver-$smake-$smodel-$version";
    $name =~ s! !\-!g;
    
    push (@declaration,
	  "# This is a PDQ driver declaration for the ", 
	  lc($driver_types{$dat->{'type'}}), " driver $driver.\n",
	  "# It was generated by pdq-o-matic.cgi version $pdqomaticversion\n\n",
	  "# You should append this file to your personal .printrc, the system\n",
	  "# /etc/printrc, or place it by itself in the systemwide /etc/pdq/drivers\n",
	  "# area.  Then run PDQ's new printer setup wizard.\n\n",
	  "driver \"$name\" {\n\n",
	  @body,
	  "}\n\n",
	  @datablob);
    
    return @declaration;
}

#################
# LPD and spooler-less printing stuff
#
# getlpddata() returns a data file which you can give to lpdomatic or
# directomatic

# Set when you change.  (Not used, but should be?)
my $lpdomaticversion = $ver;
sub getlpddata {

    my ($db) = @_;

    die "you need to call getdat first!\n" 
	if (!defined($db->{'dat'}));

    my $dat = $db->{'dat'};

    # Encase data for inclusion in FOO file
    my @datablob;
    for(split('\n',$db->getascii())) {
	push(@datablob, "$_\n");
    }	

    ## OK, now we have a whole structure named $dat about the
    ## calling of this driver.

    my ($make, $model, $driver, $poid) = ($dat->{'make'}, 
					  $dat->{'model'}, 
					  $dat->{'driver'},
					  $dat->{'id'});
    my @ppd;
    push(@ppd,
	 "# This is an LPD-O-Matic/Direct-O-Matic printer definition file for the\n",
	 "# $make $model printer using the $driver driver.\n",
	 "#\n",
	 "# It is designed to be used together with the lpdomatic or directomatic\n",
	 "# backend filter script.  For more information, see:\n#\n",
	 "# Documentation: http://www.linuxprinting.org/lpd-doc.html\n",
	 "#                http://www.linuxprinting.org/direct-doc.html\n",
	 "# Driver `$driver': http://www.linuxprinting.org/show_driver.cgi?driver=$driver\n",
	 "# $make $model: http://www.linuxprinting.org/show_printer.cgi?recnum=$poid\n\n",
	 
	 
	 "# \"\$postpipe\" is a command to pipe the printer data to somewhere on the\n",
	 "# network or, in case of Direct-O-Matic, to a local printer port (parallel,\n",
	 "# serial, or USB).  Uncomment/modify a line you like. For local printers\n",
	 "# under LPD-O-Matic this doesn't apply.\n",
	 "#\n",
	 "# Netware users might stick something here like:\n",
	 "#\n",
	 "# \$postpipe = '| nprint -U guest -S net -q foo1 -';\n",
	 "#\n",
	 "# Remote LPD printers should be done using rlpr.  The if= isn't run\n",
	 "# with any arguments locally, so you have to set up lpdomatic printing\n",
	 "# to a local printer on /dev/null, and set this to *really* send the\n",
	 "# job over the network.\n",
	 "#\n",
	 "# \$postpipe = '| rlpr -Premotequeue\@remotehost';\n",
	 "#\n",
	 "# Windows/SMB remote printers would use an smbprint command.\n",
	 "#\n",
	 "# Remote HP JetDirect network printers will usually work with either of:\n",
	 "#\n",
	 "# \$postpipe = '| nc -w 1 ipaddress 9100';\n",
	 "# \$postpipe = '| rlpr -Praw\@ipaddress';\n",
	 "#\n",
	 "# Note the \"-w 1\" in the \"nc\" command line, it makes \"nc\" exiting\n",
	 "# immediately after the data is tranferred to the printer.\n",
	 "#\n",
	 "# To print on local printers with Direct-O-Matic use the \"cat\" command:\n",
	 "#\n",
	 "# \$postpipe = '| cat > /dev/lp0';\n",
	 "# \$postpipe = '| cat > /dev/usb/lp0';\n",
	 "#\n",

	 "# Important is to remember the leading | symbol.\n\n",

	 @datablob
	 );
    
    return @ppd;

}


#####################
# CUPS stuff
#

## Set this whenever you change the getcupsppd code!!!!
# NOT USED!!!
#my $cupsomaticversion = $ver;

# Return a PPD for CUPS and the cupsomatic script.  Built from the
# standard data; you must call getdat() first.

# This function will probably removed later on and only PPD-O-Matic PPD
# files will be used.

sub getcupsppd {
    my ($db) = @_;
    die "you need to call getdat first!\n" 
	if (!defined($db->{'dat'}));

    # Encase data for inclusion in PPD file
    my @datablob;
    push(@datablob, 
"*% What follows is a dumped representation of the internal Perl data
*% structure representing one entry in the Linux Printing Database.
*% This is used by the backend filter to deal with the options. 
*%
");
    for(split('\n',$db->getascii())) {
	push(@datablob, "*% COMDATA #$_\n");
	}	

    # Construct various selectors for PPD file
    my @optionblob;
    
    my $dat = $db->{'dat'};
    
    for $arg (@{$dat->{'args'}}) {
	my $name = $arg->{'name'};
	my $type = $arg->{'type'};
	my $com  = $arg->{'comment'};
	my $default = $arg->{'default'};
	my $idx = $arg->{'idx'};
	
	if ($type eq 'enum') {
	    # Skip zero or one choice arguments (except "PageSize", a PPD
	    # file without "PageSize" will break the CUPS environment).
	    if ((1 < scalar(@{$arg->{'vals'}})) ||
		($name eq "PageSize")) {
		push(@optionblob,
		     sprintf("\n*OpenUI *%s/%s: PickOne\n", $name, $com),
		     sprintf("*Default%s: %s\n", 
			     $name,
			     (defined($default) ? $default : 'Unknown')));
		if (!defined($default)) {
		    my $whr = sprintf("%s %s driver %s",
				      $dat->{'make'},
				      $dat->{'model'},
				      $dat->{'driver'});
		    warn "undefined default for $idx/$name on a $whr\n";
		}
	    
		my $v;
		for $v (@{$arg->{'vals'}}) {
		    my $psstr = "";
		    
		    if ($arg->{'style'} eq 'G') {
			# Ghostscript argument; offer up ps for insertion
			$psstr = sprintf($arg->{'proto'}, 
					 (defined($v->{'driverval'})
					  ? $v->{'driverval'}
					  : $v->{'value'}));
		    }
		    push(@optionblob,
			 sprintf("*%s %s/%s: \"$psstr\"\n", 
				 $name, $v->{'value'}, $v->{'comment'}));
		}
		
		push(@optionblob,
		     sprintf("*CloseUI: *%s\n", $name));
		if ($name eq "PageSize") {
		    push (@optionblob, "\@\@PAPERDIM\@\@");
		}
	    }
	    
	} elsif ($type eq 'bool') {
	    my $name = $arg->{'name'};
	    my $namef = $arg->{'name_false'};
	    my $defstr = ($default ? 'True' : 'False');
	    my $psstr = "";
	    if ($arg->{'style'} eq 'G') {
		# Ghostscript argument
		$psstr = $arg->{'proto'};
	    }
	    if (!defined($default)) { 
		$defstr = 'Unknown';
	    }
	    push(@optionblob,
		 sprintf("\n*OpenUI *%s/%s: Boolean\n", $name, $com),
		 sprintf("*Default%s: $defstr\n", $name),
		 sprintf("*%s True/%s: \"$psstr\"\n", $name, $name),
		 sprintf("*%s False/%s: \"\"\n", $name, $namef),
		 sprintf("*CloseUI: *%s\n", $name));
	    
	} elsif ($type eq 'int') {
	    
	    # max, min, and a few in between?
	    
	} elsif ($type eq 'float') {
	    
	    # max, min, and a few in between?
	    
	}
	
    }

    my $paperdim;		# computed as side effect of PageSize
    if (! $dat->{'args_byname'}{'PageSize'} ) {
	
	# This is a problem, since CUPS segfaults on PPD files without
	# a default PageSize set.  Indeed, the PPD spec requires a
	# PageSize clause.
	
	# GhostScript does not understand "/PageRegion[...]", therefore
	# we use "/PageSize[...]" in the "*PageRegion" option here, in
	# addition, for most modern PostScript interpreters "PageRegion"
	# is the same as "PageSize".

	push(@optionblob, <<EOFPGSZ);

*% This is fake. We have no information on how to
*% set the pagesize for this driver in the database. To
*% prevent PPD users from blowing up, we must provide a
*% default pagesize value.

*OpenUI *PageSize/Media Size: PickOne
*OrderDependency: 10 AnySetup *PageSize
*DefaultPageSize: Letter
*PageSize Letter/Letter: "<</PageSize[612 792]/ImagingBBox null>>setpagedevice"
*PageSize Legal/Legal: "<</PageSize[612 1008]/ImagingBBox null>>setpagedevice"
*PageSize A4/A4: "<</PageSize[595 842]/ImagingBBox null>>setpagedevice"
*CloseUI: *PageSize

*OpenUI *PageRegion: PickOne
*OrderDependency: 10 AnySetup *PageRegion
*DefaultPageRegion: Letter
*PageRegion Letter/Letter: "<</PageSize[612 792]/ImagingBBox null>>setpagedevice"
*PageRegion Legal/Legal: "<</PageSize[612 1008]/ImagingBBox null>>setpagedevice"
*PageRegion A4/A4: "<</PageSize[595 842]/ImagingBBox null>>setpagedevice"
*CloseUI: *PageRegion

*DefaultImageableArea: Letter
*ImageableArea Letter/Letter:	"0 0 612 792"
*ImageableArea Legal/Legal:	"0 0 612 1008"
*ImageableArea A4/A4:	"0 0 595 842"

*DefaultPaperDimension: Letter
*PaperDimension Letter/Letter:	"612 792"
*PaperDimension Legal/Legal:	"612 1008"
*PaperDimension A4/A4:	"595 842"

EOFPGSZ

    } else {
	# We *do* have a page size argument; construct
	# PageRegion, ImageableArea, and PaperDimension clauses from it.
	# Arguably this is all backwards, but what can you do! ;)

	my @pageregion;
	my @imageablearea;
	my @paperdimension;

	push(@pageregion,
	     "*OpenUI *PageRegion: PickOne
*OrderDependency: 10 AnySetup *PageRegion
*DefaultPageRegion: $dat->{'args_byname'}{'PageSize'}{'default'}");
	push(@imageablearea, 
	     "*DefaultImageableArea: $dat->{'args_byname'}{'PageSize'}{'default'}");
	push(@paperdimension, 
	     "*DefaultPaperDimension: $dat->{'args_byname'}{'PageSize'}{'default'}");

	for (@{$dat->{'args_byname'}{'PageSize'}{'vals'}}) {
	    my $name = $_->{'value'}; # in a PPD, the value is the PPD 
	                              # name...
	    my $comment = $_->{'comment'};

	    # In modern PostScript interpreters "PageRegion" and "PageSize"
	    # are the same option, so we fill in the "PageRegion" the same
	    # way as the "PageSize" choices.
	    if ($dat->{'args_byname'}{'PageSize'}{'style'} eq 'G') {
		# Ghostscript argument; offer up ps for insertion
		$psstr = sprintf($dat->{'args_byname'}{'PageSize'}{'proto'},
				 (defined($_->{'driverval'})
				  ? $_->{'driverval'}
				  : $_->{'value'}));
	    } else {
		$psstr = "";
	    }
	    push(@pageregion,
		 sprintf("*PageRegion %s/%s: \"$psstr\"", 
			 $_->{'value'}, $_->{'comment'}));
	    # Here we have to fill in the absolute sizes of the papers. We
	    # consult a table when we could not read the sizes out of the
	    # choices of the "PageSize" option.
	    my $size = $_->{'driverval'};
	    my $value = $_->{'value'};
	    if (($size !~ /^\s*(\d+)\s+(\d+)\s*$/) &&
		# 2 positive integers separated by whitespace
		($size !~ /\-dDEVICEWIDTHPOINTS\=(\d+)\s+\-dDEVICEHEIGHTPOINTS\=(\d+)/)) {
		# "-dDEVICEWIDTHPOINTS=..."/"-dDEVICEHEIGHTPOINTS=..."
		$size = getpapersize($value);
	    } else {
		$size = "$1 $2";
	    }
	    push(@imageablearea,
		 "*ImageableArea $name/$comment: \"0 0 $size\"");
	    push(@paperdimension,
		 "*PaperDimension $name/$comment: \"$size\"");
	}

	push(@pageregion,
	     "*CloseUI: *PageRegion");


	$paperdim = join("\n", 
			 ("", @pageregion, "", @imageablearea, "",
			  @paperdimension, ""));
    }

    my @others;

    # *pnpFoo are KUPS extensions.  There is actually a PPD ieee probe
    # string value already, but they didn't use that for whatever
    # reason...
    if (defined($dat->{'pnp_mfg'})) {
	push(@others, "*pnpManufacturer: \"", $dat->{'pnp_mfg'}, "\"\n");
	
    }
    if (defined($dat->{'pnp_mdl'})) {
	push(@others, "*pnpModel: \"", $dat->{'pnp_mdl'}, "\"\n");
	
    }
    if (defined($dat->{'pnp_cmd'})) {
	push(@others, "*pnpCmd: \"", $dat->{'pnp_cmd'}, "\"\n");
	
    }
    if (defined($dat->{'pnp_des'})) {
	push(@others, "*pnpDescr: \"", $dat->{'pnp_des'}, "\"\n");
    }
    
    my $headcomment =
"*% For information on using this, and to obtain the required backend
*% script, consult http://www.linuxprinting.org/cups-doc.html
*%
*% CUPS-O-MATIC generated this PPD file.  It is for use with the CUPS 
*% printing system and the \"cupsomatic\" backend filter script.  These
*% two files work together to support the use of arbitrary free
*% software drivers with CUPS, replete with basic support for
*% driver-provided options.";

    my $blob = join('',@datablob);
    my $opts = join('',@optionblob);
    my $otherstuff = join('',@others);
    $driver =~ m!(^(.{1,5}))!;
    my $shortname = uc($1);
    my $model = $dat->{'model'};
    my $make = $dat->{'make'};
    my $filename = join('-',($dat->{'make'},
			     $dat->{'model'},
			     $dat->{'driver'},
			     "cups"));;
    $filename =~ s![ /]!_!g;
    my $longname = "$filename.ppd";

    my $drivername = $dat->{'driver'};
    
    # evil special case.
    $drivername = "stp-4.0" if $drivername eq 'stp';

    my $nickname = "$make $model, Foomatic + $drivername";

    my $tmpl = get_tmpl();
    $tmpl =~ s!\@\@HEADCOMMENT\@\@!$headcomment!g;
    $tmpl =~ s!\@\@MODEL\@\@!$model!g;
    $tmpl =~ s!\@\@NICKNAME\@\@!$nickname!g;
    $tmpl =~ s!\@\@MAKE\@\@!$make!g;
    $tmpl =~ s!\@\@SAVETHISAS\@\@!$longname!g;
    $tmpl =~ s!\@\@NUMBER\@\@!$shortname!g;
    $tmpl =~ s!\@\@OTHERSTUFF\@\@!$otherstuff!g;
    $tmpl =~ s!\@\@OPTIONS\@\@!$opts!g;
    $tmpl =~ s!\@\@COMDATABLOB\@\@!$blob!g;
    #$tmpl =~ s!\@\@PAPERDIMENSION\@\@!$paperdim!g;
    $tmpl =~ s!\@\@PAPERDIMENSION\@\@!!g;
    $tmpl =~ s!\@\@PAPERDIM\@\@!$paperdim!g;
    
    return ($tmpl);
}


#####################
# Generic PPD stuff
#

## Set this whenever you change the getgenericppd code!!!!
# NOT USED!!!
#my $ppdomaticversion = $ver;

# Return a generic Adobe-compliant PPD for the filter scripts for all
# spoolers.  Built from the standard data; you must call getdat()
# first.
sub getgenericppd {
    my ($db) = @_;
    die "you need to call getdat first!\n" 
	if (!defined($db->{'dat'}));

    # Encase data for inclusion in PPD file
    my @datablob;
    if (1) {
	push(@datablob, 
"*% What follows is a dumped representation of the internal Perl data
*% structure representing one entry in the Linux Printing Database.
*% This can be used by frontends to give advanced features which are
*% beyond the possibilities which can be defined by Adobe-compliant PPDs.
*% The lines are comment lines, so that programs which require 
*% Adobe-compliant PPD files can handle this file. They simply ignore
*% this additional information.
*%
");
	for(split('\n',$db->getascii())) {
	    push(@datablob, "*% COMDATA #$_\n");
	    }	
    }

    # Construct various selectors for PPD file
    my @optionblob;
    
    my $dat = $db->{'dat'};
    
    for $arg (@{$dat->{'args'}}) {
	my $name = $arg->{'name'};
	my $type = $arg->{'type'};
	my $com  = $arg->{'comment'};
	my $default = $arg->{'default'};
	my $idx = $arg->{'idx'};
	
	if ($type eq 'enum') {
	    # Skip zero or one choice arguments (except "PageSize", a PPD
	    # file without "PageSize" will break the CUPS environment).
	    if ((1 < scalar(@{$arg->{'vals'}})) ||
		($name eq "PageSize")) {
		push(@optionblob,
		     sprintf("\n*OpenUI *%s/%s: PickOne\n", $name, $com),
		     sprintf("*Default%s: %s\n", 
			     $name,
			     (defined($default) ? $default : 'Unknown')));
		if (!defined($default)) {
		    my $whr = sprintf("%s %s driver %s",
				      $dat->{'make'},
				      $dat->{'model'},
				      $dat->{'driver'});
		    warn "undefined default for $idx/$name on a $whr\n";
		}
	    
		my $v;
		for $v (@{$arg->{'vals'}}) {
		    my $psstr = "";
		    
		    if ($arg->{'style'} eq 'G') {
			# Ghostscript argument; offer up ps for insertion
			$psstr = sprintf($arg->{'proto'}, 
					 (defined($v->{'driverval'})
					  ? $v->{'driverval'}
					  : $v->{'value'}));
		    } else {
			# Option setting directive for Foomatic filter
			# 8 "%" because of several "sprintf� applied to it
			# In the end stay 2 "%" to have a PostScript comment
			$psstr = sprintf("%%%%%%%% FoomaticOpt: %s=%s",
					 $name, $v->{'value'});
		    }
		    push(@optionblob,
			 sprintf("*%s %s/%s: \"$psstr\"\n", 
				 $name, $v->{'value'}, $v->{'comment'}));
		}
		
		push(@optionblob,
		     sprintf("*CloseUI: *%s\n", $name));
		if ($name eq "PageSize") {
		    push (@optionblob, "\@\@PAPERDIM\@\@");
		}
	    }
	    
	} elsif ($type eq 'bool') {
	    my $name = $arg->{'name'};
	    my $namef = $arg->{'name_false'};
	    my $defstr = ($default ? 'True' : 'False');
	    my $psstr = "";
	    my $psstrf = "";
	    if ($arg->{'style'} eq 'G') {
		# Ghostscript argument
		$psstr = $arg->{'proto'};
	    } else {
		# Option setting directive for Foomatic filter
		# 8 "%" because of several "sprintf� applied to it
		# In the end stay 2 "%" to have a PostScript comment
		$psstr = sprintf("%%%%%%%% FoomaticOpt: %s=True", $name);
		$psstrf = sprintf("%%%%%%%% FoomaticOpt: %s=False", $name);
	    }
	    if (!defined($default)) { 
		$defstr = 'Unknown';
	    }
	    push(@optionblob,
		 sprintf("\n*OpenUI *%s/%s: Boolean\n", $name, $com),
		 sprintf("*Default%s: $defstr\n", $name),
		 sprintf("*%s True/%s: \"$psstr\"\n", $name, $name),
		 sprintf("*%s False/%s: \"$psstrf\"\n", $name, $namef),
		 sprintf("*CloseUI: *%s\n", $name));
	    
	} elsif ($type eq 'int') {

	    # Real numerical options do not exist in the Adobe
	    # specification for PPD files. So we map the numerical
	    # options to enumerated options offering the minimum, the
	    # maximum, the default, and some values inbetween to the
	    # user.

	    my $min = $arg->{'min'};
	    my $max = $arg->{'max'};
	    my $second = $min + 1;
	    my $stepsize = 1;
	    if (($max - $min > 100) && ($name ne "Copies")) {
		# We don't want to have more than 1000 values, but when the
		# difference between min and max is more than 1000 we should
		# have at least 100 steps.
		my $mindesiredvalues = 10;
		my $maxdesiredvalues = 100;
		# Find the order of magnitude of the value range
		my $rangesize = $max - $min;
		my $log10 = log(10.0);
		my $rangeom = POSIX::floor(log($rangesize)/$log10);
		# Now find the step size
		my $trialstepsize = 10 ** $rangeom;
		my $numvalues = 0;
		while (($numvalues <= $mindesiredvalues) &&
		       ($trialstepsize > 2)) {
		    $trialstepsize /= 10;
		    $numvalues = $rangesize/$trialstepsize;
		}
		# Try to find a finer stepping
		$stepsize = $trialstepsize;
		$trialstepsize = $stepsize / 2;
		$numvalues = $rangesize/$trialstepsize;
		if ($numvalues <= $maxdesiredvalues) {
		    if ($stepsize > 20) { 
			$trialstepsize = $stepsize / 4;
			$numvalues = $rangesize/$trialstepsize;
		    }
		    if ($numvalues <= $maxdesiredvalues) {
			$trialstepsize = $stepsize / 5;
			$numvalues = $rangesize/$trialstepsize;
		    }
		    if ($numvalues <= $maxdesiredvalues) {
			$stepsize = $trialstepsize;
		    } else {
			$stepsize /= 2;
		    }
		}
		$numvalues = $rangesize/$stepsize;
		# We have the step size. Now we must find an appropriate
		# second value for the value list, so that it contains
		# the integer multiples of 10, 100, 1000, ...
		$second = $stepsize * POSIX::ceil($min / $stepsize);
		if ($second <= $min) {$second += $stepsize};
	    }
	    # Generate the choice list
	    my @choicelist;
	    push (@choicelist, $min);
	    if (($default < $second) && ($default > $min)) {
		push (@choicelist, $default);
	    }
	    my $item = $second;
	    while ($item < $max) {
		push (@choicelist, $item);
		if (($default < $item + $stepsize) && ($default > $item) &&
		    ($default < $max)) {
		    push (@choicelist, $default);
		}
		$item += $stepsize;
	    }
	    push (@choicelist, $max);

            # Add the option

	    # Skip zero or one choice arguments
	    if (1 < scalar(@choicelist)) {
		push(@optionblob,
		     sprintf("\n*OpenUI *%s/%s: PickOne\n", $name, $com),
		     sprintf("*Default%s: %s\n", 
			     $name,
			     (defined($default) ? $default : 'Unknown')));
		if (!defined($default)) {
		    my $whr = sprintf("%s %s driver %s",
				      $dat->{'make'},
				      $dat->{'model'},
				      $dat->{'driver'});
		    warn "undefined default for $idx/$name on a $whr\n";
		}
	    
		my $v;
		for $v (@choicelist) {
		    my $psstr = "";
		    
		    if ($arg->{'style'} eq 'G') {
			# Ghostscript argument; offer up ps for insertion
			$psstr = sprintf($arg->{'proto'}, $v);
		    } else {
			# Option setting directive for Foomatic filter
			# 8 "%" because of several "sprintf� applied to it
			# In the end stay 2 "%" to have a PostScript comment
			$psstr = sprintf("%%%%%%%% FoomaticOpt: %s=%s",
					 $name, $v);
		    }
		    push(@optionblob,
			 sprintf("*%s %s/%s: \"$psstr\"\n", 
				 $name, $v, $v));
		}
		
		push(@optionblob,
		     sprintf("*CloseUI: *%s\n", $name));
	    }
	    
	} elsif ($type eq 'float') {
	    
	    my $min = $arg->{'min'};
	    my $max = $arg->{'max'};
	    # We don't want to have more than 500 values or less than 50
	    # values.
	    my $mindesiredvalues = 10;
	    my $maxdesiredvalues = 100;
	    # Find the order of magnitude of the value range
	    my $rangesize = $max - $min;
	    my $log10 = log(10.0);
	    my $rangeom = POSIX::floor(log($rangesize)/$log10);
	    # Now find the step size
	    my $trialstepsize = 10 ** $rangeom;
	    my $stepom = $rangeom; # Order of magnitude of stepsize,
	                           # needed for determining necessary number
	                           # of digits
	    my $numvalues = 0;
	    while ($numvalues <= $mindesiredvalues) {
		$trialstepsize /= 10;
		$stepom -= 1;
		$numvalues = $rangesize/$trialstepsize;
	    }
	    # Try to find a finer stepping
	    $stepsize = $trialstepsize;
	    my $stepsizeorig = $stepsize;
	    $trialstepsize = $stepsizeorig / 2;
	    $numvalues = $rangesize/$trialstepsize;
	    if ($numvalues <= $maxdesiredvalues) {
		$stepsize = $trialstepsize;
		$trialstepsize = $stepsizeorig / 4;
		$numvalues = $rangesize/$trialstepsize;
		if ($numvalues <= $maxdesiredvalues) {
		    $stepsize = $trialstepsize;
		    $trialstepsize = $stepsizeorig / 5;
		    $numvalues = $rangesize/$trialstepsize;
		    if ($numvalues <= $maxdesiredvalues) {
			$stepsize = $trialstepsize;
		    }
		}
	    }
	    $numvalues = $rangesize/$stepsize;
	    if ($stepsize < $stepsizeorig * 0.9) {$stepom -= 1;}
	    # Determine number of digits after the decimal point for
	    # formatting the output values.
	    my $digits = 0;
	    if ($stepom < 0) {
		$digits = - $stepom;
	    }
	    # We have the step size. Now we must find an appropriate
	    # second value for the value list, so that it contains
	    # the integer multiples of 10, 100, 1000, ...
	    $second = $stepsize * POSIX::ceil($min / $stepsize);
	    if ($second <= $min) {$second += $stepsize};
	    # Generate the choice list
	    my @choicelist;
	    my $choicestr =  sprintf("%.${digits}f", $min);
	    push (@choicelist, $choicestr);
	    if (($default < $second) && ($default > $min)) {
		$choicestr =  sprintf("%.${digits}f", $default);
		# Prevent values from entering twice because of rounding
		# inacuracy
		if ($choicestr ne $choicelist[$#choicelist]) {
		    push (@choicelist, $choicestr);
		}
	    }
	    my $item = $second;
	    my $i = 0;
	    while ($item < $max) {
		$choicestr =  sprintf("%.${digits}f", $item);
		# Prevent values from entering twice because of rounding
		# inacuracy
		if ($choicestr ne $choicelist[$#choicelist]) {
		    push (@choicelist, $choicestr);
		}
		if (($default < $item + $stepsize) && ($default > $item) &&
		    ($default < $max)) {
		    $choicestr =  sprintf("%.${digits}f", $default);
		    # Prevent values from entering twice because of rounding
		    # inacuracy
		    if ($choicestr ne $choicelist[$#choicelist]) {
			push (@choicelist, $choicestr);
		    }
		}
		$i += 1;
		$item = $second + $i * $stepsize;
	    }
	    $choicestr =  sprintf("%.${digits}f", $max);
	    # Prevent values from entering twice because of rounding
	    # inacuracy
	    if ($choicestr ne $choicelist[$#choicelist]) {
		push (@choicelist, $choicestr);
	    }

            # Add the option

	    # Skip zero or one choice arguments
	    if (1 < scalar(@choicelist)) {
		push(@optionblob,
		     sprintf("\n*OpenUI *%s/%s: PickOne\n", $name, $com),
		     sprintf("*Default%s: %s\n", 
			     $name,
			     (defined($default) ? 
			      sprintf("%.${digits}f", $default) : 'Unknown')));
		if (!defined($default)) {
		    my $whr = sprintf("%s %s driver %s",
				      $dat->{'make'},
				      $dat->{'model'},
				      $dat->{'driver'});
		    warn "undefined default for $idx/$name on a $whr\n";
		}
	    
		my $v;
		for $v (@choicelist) {
		    my $psstr = "";
		    if ($arg->{'style'} eq 'G') {
			# Ghostscript argument; offer up ps for insertion
			$psstr = sprintf($arg->{'proto'}, $v);
		    } else {
			# Option setting directive for Foomatic filter
			# 8 "%" because of several "sprintf� applied to it
			# In the end stay 2 "%" to have a PostScript comment
			$psstr = sprintf("%%%%%%%% FoomaticOpt: %s=%s",
					 $name, $v);
		    }
		    push(@optionblob,
			 sprintf("*%s %s/%s: \"$psstr\"\n", 
				 $name, $v, $v));
		}
		
		push(@optionblob,
		     sprintf("*CloseUI: *%s\n", $name));
	    }
        }
    }

    my $paperdim = "";		# computed as side effect of PageSize
    if (! $dat->{'args_byname'}{'PageSize'} ) {
	
	# This is a problem, since CUPS segfaults on PPD files without
	# a default PageSize set.  Indeed, the PPD spec requires a
	# PageSize clause.
	
	# GhostScript does not understand "/PageRegion[...]", therefore
	# we use "/PageSize[...]" in the "*PageRegion" option here, in
	# addition, for most modern PostScript interpreters "PageRegion"
	# is the same as "PageSize".

	push(@optionblob, <<EOFPGSZ);

*% This is fake. We have no information on how to
*% set the pagesize for this driver in the database. To
*% prevent PPD users from blowing up, we must provide a
*% default pagesize value.

*OpenUI *PageSize/Media Size: PickOne
*OrderDependency: 10 AnySetup *PageSize
*DefaultPageSize: Letter
*PageSize Letter/Letter: "<</PageSize[612 792]/ImagingBBox null>>setpagedevice"
*PageSize Legal/Legal: "<</PageSize[612 1008]/ImagingBBox null>>setpagedevice"
*PageSize A4/A4: "<</PageSize[595 842]/ImagingBBox null>>setpagedevice"
*CloseUI: *PageSize

*OpenUI *PageRegion: PickOne
*OrderDependency: 10 AnySetup *PageRegion
*DefaultPageRegion: Letter
*PageRegion Letter/Letter: "<</PageSize[612 792]/ImagingBBox null>>setpagedevice"
*PageRegion Legal/Legal: "<</PageSize[612 1008]/ImagingBBox null>>setpagedevice"
*PageRegion A4/A4: "<</PageSize[595 842]/ImagingBBox null>>setpagedevice"
*CloseUI: *PageRegion

*DefaultImageableArea: Letter
*ImageableArea Letter/Letter:	"0 0 612 792"
*ImageableArea Legal/Legal:	"0 0 612 1008"
*ImageableArea A4/A4:	"0 0 595 842"

*DefaultPaperDimension: Letter
*PaperDimension Letter/Letter:	"612 792"
*PaperDimension Legal/Legal:	"612 1008"
*PaperDimension A4/A4:	"595 842"

EOFPGSZ

    } else {
	# We *do* have a page size argument; construct
	# PageRegion, ImageableArea, and PaperDimension clauses from it.
	# Arguably this is all backwards, but what can you do! ;)

	my @pageregion;
	my @imageablearea;
	my @paperdimension;

	push(@pageregion,
	     "*OpenUI *PageRegion: PickOne
*OrderDependency: 10 AnySetup *PageRegion
*DefaultPageRegion: $dat->{'args_byname'}{'PageSize'}{'default'}");
	push(@imageablearea, 
	     "*DefaultImageableArea: $dat->{'args_byname'}{'PageSize'}{'default'}");
	push(@paperdimension, 
	     "*DefaultPaperDimension: $dat->{'args_byname'}{'PageSize'}{'default'}");

	for (@{$dat->{'args_byname'}{'PageSize'}{'vals'}}) {
	    my $name = $_->{'value'}; # in a PPD, the value is the PPD 
	                              # name...
	    my $comment = $_->{'comment'};

	    # In modern PostScript interpreters "PageRegion" and "PageSize"
	    # are the same option, so we fill in the "PageRegion" the same
	    # way as the "PageSize" choices.
	    if ($dat->{'args_byname'}{'PageSize'}{'style'} eq 'G') {
		# Ghostscript argument; offer up ps for insertion
		$psstr = sprintf($dat->{'args_byname'}{'PageSize'}{'proto'},
				 (defined($_->{'driverval'})
				  ? $_->{'driverval'}
				  : $_->{'value'}));
	    } else {
		# Option setting directive for Foomatic filter
		# 8 "%" because of several "sprintf� applied to it
		# In the end stay 2 "%" to have a PostScript comment
		$psstr = sprintf("%%%%%%%% FoomaticOpt: PageSize=%s",
				 $_->{'value'});
	    }
	    push(@pageregion,
		 sprintf("*PageRegion %s/%s: \"$psstr\"", 
			 $_->{'value'}, $_->{'comment'}));
	    # Here we have to fill in the absolute sizes of the papers. We
	    # consult a table when we could not read the sizes out of the
	    # choices of the "PageSize" option.
	    my $size = $_->{'driverval'};
	    my $value = $_->{'value'};
	    if (($size !~ /^\s*(\d+)\s+(\d+)\s*$/) &&
		# 2 positive integers separated by whitespace
		($size !~ /\-dDEVICEWIDTHPOINTS\=(\d+)\s+\-dDEVICEHEIGHTPOINTS\=(\d+)/)) {
		# "-dDEVICEWIDTHPOINTS=..."/"-dDEVICEHEIGHTPOINTS=..."
		$size = getpapersize($value);
	    } else {
		$size = "$1 $2";
	    }
	    push(@imageablearea,
		 "*ImageableArea $name/$comment: \"0 0 $size\"");
	    push(@paperdimension,
		 "*PaperDimension $name/$comment: \"$size\"");
	}

	push(@pageregion,
	     "*CloseUI: *PageRegion");


	$paperdim = join("\n", 
			 ("", @pageregion, "", @imageablearea, "",
			  @paperdimension, ""));
    }

    my @others;

    my $headcomment =
"*% For information on using this, and to obtain the required backend
*% script, consult http://www.linuxprinting.org/ppd-doc.html
*%
*% PPD-O-MATIC generated this PPD file. It is for use with all programs 
*% and environments which use PPD files for dealing with printer capabilty
*% information. The printer must be configured with a Foomatic backend
*% filter script. This file and the backend filter script work together to
*% support PPD-controlled printer driver option access with arbitrary free 
*% software printer drivers and printing spoolers.";

    my $blob = join('',@datablob);
    my $opts = join('',@optionblob);
    my $otherstuff = join('',@others);
    $driver =~ m!(^(.{1,5}))!;
    my $shortname = uc($1);
    my $model = $dat->{'model'};
    my $make = $dat->{'make'};
    my $filename = join('-',($dat->{'make'},
			     $dat->{'model'},
			     $dat->{'driver'},
			     "ppd"));;
    $filename =~ s![ /]!_!g;
    my $longname = "$filename.ppd";

    my $drivername = $dat->{'driver'};
    
    # evil special case.
    $drivername = "stp-4.0" if $drivername eq 'stp';

    my $nickname = "$make $model, Foomatic + $drivername";

    my $tmpl = get_tmpl();
    $tmpl =~ s!\@\@HEADCOMMENT\@\@!$headcomment!g;
    $tmpl =~ s!\@\@MODEL\@\@!$model!g;
    $tmpl =~ s!\@\@NICKNAME\@\@!$nickname!g;
    $tmpl =~ s!\@\@MAKE\@\@!$make!g;
    $tmpl =~ s!\@\@SAVETHISAS\@\@!$longname!g;
    $tmpl =~ s!\@\@NUMBER\@\@!$shortname!g;
    $tmpl =~ s!\@\@OTHERSTUFF\@\@!$otherstuff!g;
    $tmpl =~ s!\@\@OPTIONS\@\@!$opts!g;
    $tmpl =~ s!\@\@COMDATABLOB\@\@!$blob!g;
    $tmpl =~ s!\@\@PAPERDIMENSION\@\@!!g;
    $tmpl =~ s!\@\@PAPERDIM\@\@!$paperdim!g;
    
    return ($tmpl);
}


# Utility function; returns content of a URL
sub getpage {
    my ($this, $url, $dontdie) = @_;

    my $failed = 0;
    my $page = undef;
    # Try it first to retrieve the page with the "wget" shell command
    if (-x $sysdeps->{'wget'}) {
	if (open PAGE, "$sysdeps->{'wget'} $url -O - 2>/dev/null |") {
	    $page = join('', <PAGE>);
	    close PAGE;
	} else {
	    $failed = 1;
	}
    # Then try to retrieve the page with the "curl" shell command
    } elsif (-x $sysdeps->{'curl'}) {
	if (open PAGE, "$sysdeps->{'curl'} $url -o - 2>/dev/null |") {
	    $page = join('', <PAGE>);
	    close PAGE;
	} else {
	    $failed = 1;
	}
    } else {
	warn("WARNING: No tool for downloading web content found, please install either\n\"wget\" or \"curl\"! The result you got may be incorrect!\n");
    }

    if ((!$page) || ($failed)) {
	if ($dontdie) {
	    return undef;
	} else {
	    die ("http error: " . $request->status_line . "\n");
	}
    }

    return $page;
}

# Prepare strings for being part of an HTML document by, converting
# "<" to "&lt;", ">" to "&gt;", and "&" to "&amp;"
sub htmlify {
    my $str = $_[0];
    $str =~ s!&!&amp;!g;
    $str =~ s/\</\&lt;/g;
    $str =~ s/\>/\&gt;/g;
    return $str;
}

# Get documentation for the printer/driver pair to print out. For
# "Execution Details" section of driver web pages of linuxprinting.org

sub getexecdocs {

    my ($this) = $_[0];

    my $dat = $this->{'dat'};

    my @docs;
    
    # Construct the proper command line.
    my $commandline = htmlify($dat->{'cmd'});

    if ($commandline eq "") {return ();}

    my @letters = qw/A B C D E F G H I J K L M Z/;
    my $spot;
    
    for $spot (@letters) {
	
	if($commandline =~ m!\%$spot!) {

	    my $arg;
	  argument:
	    for $arg (@{$dat->{'args'}}) {
#	    for $arg (sort { $a->{'order'} <=> $b->{'order'} } 
#		      @{$dat->{'args'}}) {
		
		# Only do arguments that go in this spot
		next argument if ($arg->{'spot'} ne $spot);
		# PJL arguments are not inserted at a spot in the command
		# line
		next argument if ($arg->{'style'} eq 'J');
		
		my $name = htmlify($arg->{'name'});
		my $varname = htmlify($arg->{'varname'});
		my $cmd = htmlify($arg->{'proto'});
		my $comment = htmlify($arg->{'comment'});
		my $placeholder = "</TT><I>&lt;$name&gt;</I><TT>";
		my $default = htmlify($arg->{'default'});
		my $type = $arg->{'type'};
		my $cmdvar = "";
		my $gsarg1 = "";
		my $gsarg2 = "";
		if ($arg->{'style'} eq 'G') {
		    $gsarg1 = ' -c "';
		    $gsarg2 = '"';
		    $cmd =~ s/\"/\\\"/g;
		}
		#my $leftbr = ($arg->{'required'} ? "" : "[");
		#my $rightbr = ($arg->{'required'} ? "" : "]");
		my $leftbr = "";
		my $rightbr = "";
	
		if ($type eq 'bool') {
		    $cmdvar = "$leftbr$gsarg1$cmd$gsarg2$rightbr";
		} elsif ($type eq 'int' or $type eq 'float') {
		    $cmdvar = sprintf("$leftbr$gsarg1$cmd$gsarg2$rightbr",$placeholder);
		} elsif ($type eq 'enum') {
		    my $val;
		    if ($val=valbyname($arg,$default)) {
			$cmdvar = sprintf("$leftbr$gsarg1$cmd$gsarg2$rightbr",
					  $placeholder);
		    }
		}
		
		# Insert the processed argument in the commandline
		# just before the spot marker.
		$cmdvar =~ s!^\[\ !\ \[!;
		$commandline =~ s!\%$spot!$cmdvar\%$spot!;
	    }
	    
	    # Remove the letter marker from the commandline
	    $commandline =~ s!\%$spot!!;
	    
	}
	
    }

    $dat->{'excommandline'} = $commandline;

    push(@docs, "<B>Command Line</B><P>");
    push(@docs, "<BLOCKQUOTE><TT>$commandline</TT></BLOCKQUOTE><P>");

    my ($arg, @doctmp);
    my @pjlcommands = ();
  argt:
    for $arg (@{$dat->{'args'}}) {
#    for $arg (sort { $a->{'order'} <=> $b->{'order'} } 
#	      @{$dat->{'args'}}) {

	my $name = htmlify($arg->{'name'});
	my $cmd = htmlify($arg->{'proto'});
	my $comment = htmlify($arg->{'comment'});
	my $placeholder = "</TT><I>&lt;$name&gt;</I><TT>";
	if ($arg->{'style'} eq 'J') {
	    $cmd = "\@PJL $cmd";
	    push (@pjlcommands, sprintf($cmd, $placeholder));
	}

	my $default = htmlify($arg->{'default'});
	my $type = $arg->{'type'};
	
	my $required = ($arg->{'required'} ? " required" : "n optional");
	my $pjl = ($arg->{'style'} eq 'J' ? "PJL " : "");

	if ($type eq 'bool') {
	    my $name_false = htmlify($arg->{'name_false'});
	    push(@doctmp,
		 "<DL><DT><I>$name</I></DT>",
		 "<DD>A$required boolean ${pjl}argument meaning $name if present or $name_false if not.<BR>",
		 "$comment<BR>",
		 "Prototype: <TT>$cmd</TT><BR>",
		 "Default: ", $default ? "True" : "False",
		 "</DD></DL><P>"
		 );

	} elsif ($type eq 'int' or $type eq 'float') {
	    my $max = (defined($arg->{'max'}) ? $arg->{'max'} : "none");
	    my $min = (defined($arg->{'min'}) ? $arg->{'min'} : "none");
	    push(@doctmp,
		 "<DL><DT><I>$name</I></DT>",
		 "<DD>A$required $type ${pjl}argument.<BR>",
		 "$comment<BR>",
		 "Prototype: <TT>", sprintf($cmd, $placeholder),
		 "</TT><BR>",
		 "Default: <TT>$default</TT><BR>",
		 "Range: <TT>$min &lt;= $placeholder &lt;= $max</TT>",
		 "</DD></DL><P>"
		 );

	} elsif ($type eq 'enum') {
	    my ($val, $defstr);
	    my (@choicelist) = ();

	    for $val (@{$arg->{'vals'}}) {
		my ($value, $comment, $driverval) = 
		    (htmlify($val->{'value'}),
		     htmlify($val->{'comment'}),
		     htmlify($val->{'driverval'}));

		if (defined($driverval)) {
		    if ($driverval eq "") {
			push(@choicelist,
			     "<LI>$value: $comment (<TT>$placeholder</TT> is left blank)</LI>");
		    } else {
			push(@choicelist,
			     "<LI>$value: $comment (<TT>$placeholder</TT> is '<TT>$driverval</TT>')</LI>");
		    }
		} else {
		    push(@choicelist,
			 "<LI>$value: $comment (<TT>$placeholder</TT> is '<TT>$value</TT>')</LI>");
		}
	    }

	    push(@doctmp,
		 "<DL><DT><I>$name</I></DT>",
		 "<DD>A$required enumerated choice ${pjl}argument.<BR>",
		 "$comment<BR>",
		 "Prototype: <TT>", sprintf($cmd, $placeholder),
		 "</TT><BR>",
		 "Default: $default",
		 "<UL>", 
		 join("", @choicelist), 
		 "</UL></DD></DL><P>"
		 );

	}
    }

    # Instructions for PJL commands
    if (($#pjlcommands > -1) && (defined($dat->{'pjl'}))) {
    #if (($#pjlcommands > -1)) {
	my @pjltmp;
	push(@pjltmp,
	     "PJL arguments are not put into the command line, they must be put into a PJL header which is prepended to the actual job data which is generated by the command line shown above and sent to the printer. After the job data one can reset the printer via PJL. So a complete job looks as follows:<BLOCKQUOTE>",
	     "<I>&lt;ESC&gt;</I>",
	     # The "JOB" PJL command is not supported by all printers
	     "<TT>%-12345X\@PJL</TT><BR>");
	     #"<TT>%-12345X\@PJL JOB NAME=\"</TT>",
	     #"<I>&lt;A job name&gt;</I>",
	     #"<TT>\"</TT><BR>");
	for $command (@pjlcommands) {
	    push(@pjltmp,
		 "<TT>$command</TT><BR>");
	}
	push(@pjltmp,
	     "<I>&lt;The job data&gt;</I><BR>",
	     "<I>&lt;ESC&gt;</I>",
	     # The "JOB" PJL command is not supported by all printers
	     "<TT>%-12345X\@PJL RESET</TT></BLOCKQUOTE><P>",
	     #"<TT>%-12345X\@PJL EOJ</TT></BLOCKQUOTE><P>",
	     "<I>&lt;ESC&gt;</I>",
	     ": This is the ",
	     "<I>ESC</I>",
	     " character, ASCII code 27.<P>",
	     #"<I>&lt;A job name&gt;</I>",
	     #": The job name can be chosen arbitrarily, some printers show it on their front panel displays.<P>",
	     "It is not required to give the PJL arguments, you can leave out some of them or you can even send only the job data without PJL header and PJL end-of-job mark.<P>");
	push(@docs, "<B>PJL</B><P>");
	push(@docs, @pjltmp);
    } elsif ((defined($dat->{'drivernopjl'})) && 
	     ($dat->{'drivernopjl'} == 1) && 
	     (defined($dat->{'pjl'}))) {
	my @pjltmp;
	push(@pjltmp,
	     "This driver produces a PJL header with PJL commands internally, so commands in a PJL header sent to the printer before the output of this driver would be ignored. Therefore there are no PJL options available when using this driver.<P>");
	push(@docs, "<B>PJL</B><P>");
	push(@docs, @pjltmp);
    }

    push(@docs, "<B>Options</B><P>");

    push(@docs, @doctmp);

    return @docs;
   
}

# Get a shorter summary documentation thing.
sub get_summarydocs {
    my ($this) = $_[0];

    my $dat = $this->{'dat'};

    my @docs;

    for $arg (@{$dat->{'args'}}) {
	my ($name,
	    $required,
	    $type,
	    $comment,
	    $spot,
	    $default) = ($arg->{'name'},
			 $arg->{'required'},
			 $arg->{'type'},
			 $arg->{'comment'},
			 $arg->{'spot'},
			 $arg->{'default'});
	
	my $reqstr = ($required ? " required" : "n optional");
	push(@docs,
	     "Option `$name':\n  A$reqstr $type argument.\n  $comment\n");

	push(@docs,
	     "  This option corresponds to a PJL command.\n") 
	    if ($spot eq 'Y');
	
	if ($type eq 'bool') {
	    if (defined($default)) {
		my $defstr = ($default ? "True" : "False");
		push(@docs, "  Default: $defstr\n");
	    }
	    push(@docs, "  Example (true): `$name'\n");
	    push(@docs, "  Example (false): `no$name'\n");
	} elsif ($type eq 'enum') {
	    push(@docs, "  Possible choices:\n");
	    my $exarg;
	    for (@{$arg->{'vals'}}) {
		my ($choice, $comment) = ($_->{'value'}, $_->{'comment'});
		push(@docs, "   * $choice: $comment\n");
		$exarg=$choice;
	    }
	    if (defined($default)) {
		push(@docs, "  Default: $default\n");
	    }
	    push(@docs, "  Example: `$name=$exarg'\n");
	} elsif ($type eq 'int' or $type eq 'float') {
	    my ($max, $min) = ($arg->{'max'}, $arg->{'min'});
	    my $exarg;
	    if (defined($max)) {
		push(@docs, "  Range: $min <= x <= $max\n");
		$exarg=$max;
	    }
	    if (defined($default)) {
		push(@docs, "  Default: $default\n");
		$exarg=$default;
	    }
	    if (!$exarg) { $exarg=0; }
	    push(@docs, "  Example: `$name=$exarg'\n");
	}

	push(@docs, "\n");
    }

    return @docs;

}

# About as obsolete as the other docs functions.  Why on earth are
# there three, anyway?!
sub getdocs {
    my ($this) = $_[0];

    my $dat = $this->{'dat'};

    my @docs;

    for $arg (@{$dat->{'args'}}) {
	my ($name,
	    $required,
	    $type,
	    $comment,
	    $spot,
	    $default) = ($arg->{'name'},
			 $arg->{'required'},
			 $arg->{'type'},
			 $arg->{'comment'},
			 $arg->{'spot'},
			 $arg->{'default'});
	
	my $reqstr = ($required ? " required" : "n optional");
	push(@docs,
	     "Option `$name':\n  A$reqstr $type argument.\n  $comment\n");

	push(@docs,
	     "  This option corresponds to a PJL command.\n") 
	    if ($spot eq 'Y');
	
	if ($type eq 'bool') {
	    if (defined($default)) {
		my $defstr = ($default ? "True" : "False");
		push(@docs, "  Default: $defstr\n");
	    }
	    push(@docs, "  Example (true): `$name'\n");
	    push(@docs, "  Example (false): `no$name'\n");
	} elsif ($type eq 'enum') {
	    push(@docs, "  Possible choices:\n");
	    my $exarg;
	    for (@{$arg->{'vals'}}) {
		my ($choice, $comment) = ($_->{'value'}, $_->{'comment'});
		push(@docs, "   * $choice: $comment\n");
		$exarg=$choice;
	    }
	    if (defined($default)) {
		push(@docs, "  Default: $default\n");
	    }
	    push(@docs, "  Example: `$name=$exarg'\n");
	} elsif ($type eq 'int' or $type eq 'float') {
	    my ($max, $min) = ($arg->{'max'}, $arg->{'min'});
	    my $exarg;
	    if (defined($max)) {
		push(@docs, "  Range: $min <= x <= $max\n");
		$exarg=$max;
	    }
	    if (defined($default)) {
		push(@docs, "  Default: $default\n");
		$exarg=$default;
	    }
	    if (!$exarg) { $exarg=0; }
	    push(@docs, "  Example: `$name=$exarg'\n");
	}

	push(@docs, "\n");
    }

    return @docs;

}

# Find a choice value hash by name.
# Operates on old dat structure...
sub valbyname {
    my ($arg,$name) = @_;

    my $val;
    for $val (@{$arg->{'vals'}}) {
	return $val if (lc($name) eq lc($val->{'value'}));
    }

    return undef;
}

# replace numbers with fixed 6-digit number for ease of sorting
# ie: sort { normalizename($a) cmp normalizename($b) } @foo;
sub normalizename {
    my $n = $_[0];

    if ($n =~ m!(\d+)!) {
	my $num = sprintf("%06d", $1);
	$n =~ s!(\d+)!$num!;
    }
    return $n;
}


# PPD boilerplate template

sub get_tmpl_paperdimension {
    return <<ENDPDTEMPL;
*% Generic PaperDimension; evidently there was no normal PageSize argument

*DefaultPaperDimension: Letter
*PaperDimension Letter:	"612 792"
*PaperDimension Legal:	"612 1008"
*PaperDimension A4:	"595 842"
ENDPDTEMPL
}

sub get_tmpl {
    return <<ENDTMPL;
*PPD-Adobe: "4.3"
*%
\@\@HEADCOMMENT\@\@
*%
*% You may save this file as '\@\@SAVETHISAS\@\@'
*%
*%
*FormatVersion:	"4.3"
*FileVersion:	"1.1"
*LanguageVersion: English 
*LanguageEncoding: ISOLatin1
*PCFileName:	"COM\@\@NUMBER\@\@.PPD"
*Manufacturer:	"\@\@MAKE\@\@"
*Product:	"\@\@MODEL\@\@"
*cupsVersion:	1.0
*cupsManualCopies: True
*cupsModelNumber:  2
*cupsFilter:	"application/vnd.cups-postscript 0 cupsomatic"
*ModelName:     "\@\@MODEL\@\@"
*ShortNickName: "\@\@MODEL\@\@"
*NickName:      "\@\@NICKNAME\@\@"
*PSVersion:	"(3010.000) 550"
*PSVersion:	"(3010.000) 651"
*PSVersion:	"(3010.000) 652"
*PSVersion:	"(3010.000) 653"
*LanguageLevel:	"3"
*ColorDevice:	True
*DefaultColorSpace: RGB
*FileSystem:	False
*Throughput:	"1"
*LandscapeOrientation: Plus90
*VariablePaperSize: False
*TTRasterizer:	Type42
\@\@OTHERSTUFF\@\@
 
\@\@OPTIONS\@\@

*% Generic boilerplate PPD stuff as standard PostScript fonts and so on

\@\@PAPERDIMENSION\@\@

*DefaultFont: Courier
*Font AvantGarde-Book: Standard "(001.006S)" Standard ROM
*Font AvantGarde-BookOblique: Standard "(001.006S)" Standard ROM
*Font AvantGarde-Demi: Standard "(001.007S)" Standard ROM
*Font AvantGarde-DemiOblique: Standard "(001.007S)" Standard ROM
*Font Bookman-Demi: Standard "(001.004S)" Standard ROM
*Font Bookman-DemiItalic: Standard "(001.004S)" Standard ROM
*Font Bookman-Light: Standard "(001.004S)" Standard ROM
*Font Bookman-LightItalic: Standard "(001.004S)" Standard ROM
*Font Courier: Standard "(002.004S)" Standard ROM
*Font Courier-Bold: Standard "(002.004S)" Standard ROM
*Font Courier-BoldOblique: Standard "(002.004S)" Standard ROM
*Font Courier-Oblique: Standard "(002.004S)" Standard ROM
*Font Helvetica: Standard "(001.006S)" Standard ROM
*Font Helvetica-Bold: Standard "(001.007S)" Standard ROM
*Font Helvetica-BoldOblique: Standard "(001.007S)" Standard ROM
*Font Helvetica-Narrow: Standard "(001.006S)" Standard ROM
*Font Helvetica-Narrow-Bold: Standard "(001.007S)" Standard ROM
*Font Helvetica-Narrow-BoldOblique: Standard "(001.007S)" Standard ROM
*Font Helvetica-Narrow-Oblique: Standard "(001.006S)" Standard ROM
*Font Helvetica-Oblique: Standard "(001.006S)" Standard ROM
*Font NewCenturySchlbk-Bold: Standard "(001.009S)" Standard ROM
*Font NewCenturySchlbk-BoldItalic: Standard "(001.007S)" Standard ROM
*Font NewCenturySchlbk-Italic: Standard "(001.006S)" Standard ROM
*Font NewCenturySchlbk-Roman: Standard "(001.007S)" Standard ROM
*Font Palatino-Bold: Standard "(001.005S)" Standard ROM
*Font Palatino-BoldItalic: Standard "(001.005S)" Standard ROM
*Font Palatino-Italic: Standard "(001.005S)" Standard ROM
*Font Palatino-Roman: Standard "(001.005S)" Standard ROM
*Font Symbol: Special "(001.007S)" Special ROM
*Font Times-Bold: Standard "(001.007S)" Standard ROM
*Font Times-BoldItalic: Standard "(001.009S)" Standard ROM
*Font Times-Italic: Standard "(001.007S)" Standard ROM
*Font Times-Roman: Standard "(001.007S)" Standard ROM
*Font ZapfChancery-MediumItalic: Standard "(001.007S)" Standard ROM
*Font ZapfDingbats: Special "(001.004S)" Standard ROM

\@\@COMDATABLOB\@\@
ENDTMPL
}

# Determine the paper width and height in points from a given paper size
# name. Used for the "PaperDimension" and "ImageableArea" entries in PPD
# files.
#
# The paper sizes in the list are all sizes known to GhostScript, all
# of GIMP-Print, all sizes of HPIJS, and some others found in the data
# of printer drivers.

sub getpapersize {
    my $papersize = lc(join('', @_));

    my $sizetable = {
	'germanlegalfanfold' => '612 936',
	'letterwide'       => '647 957',
	'lettersmall'      => '612 792',
	'letter'           => '612 792',
	'legal'            => '612 1008',
	'postcard'         => '283 416',
	'tabloid'          => '792 1224',
	'ledger'           => '1224 792',
	'tabloidextra'     => '864 1296',
	'statement'        => '396 612',
	'manual'           => '396 612',
	'halfletter'       => '396 612',
	'executive'        => '522 756',
	'archa'            => '648 864',
	'archb'            => '864 1296',
	'archc'            => '1296 1728',
	'archd'            => '1728 2592',
	'arche'            => '2592 3456',
	'usaarch'          => '648 864',
	'usbarch'          => '864 1296',
	'uscarch'          => '1296 1728',
	'usdarch'          => '1728 2592',
	'usearch'          => '2592 3456',
	'a2.*invit.*'      => '315 414',
	'b6-c4'            => '354 918',
	'c7-6'             => '229 459',
	'supera3-b'        => '932 1369',
	'a3wide'           => '936 1368',
	'a4wide'           => '633 1008',
	'a4small'          => '595 842',
	'sra4'             => '637 907',
	'sra3'             => '907 1275',
	'sra2'             => '1275 1814',
	'sra1'             => '1814 2551',
	'sra0'             => '2551 3628',
	'ra4'              => '609 864',
	'ra3'              => '864 1218',
	'ra2'              => '1218 1729',
	'ra1'              => '1729 2437',
	'ra0'              => '2437 3458',
	'a10'              => '74 105',
	'a9'               => '105 148',
	'a8'               => '148 210',
	'a7'               => '210 297',
	'a6'               => '297 420',
	'a5'               => '420 595',
	'a4'               => '595 842',
	'a3'               => '842 1191',
	'a2'               => '1191 1684',
	'a1'               => '1684 2384',
	'a0'               => '2384 3370',
	'2a'               => '3370 4768',
	'4a'               => '4768 6749',
	'c10'              => '79 113',
	'c9'               => '113 161',
	'c8'               => '161 229',
	'c7'               => '229 323',
	'c6'               => '323 459',
	'c5'               => '459 649',
	'c4'               => '649 918',
	'c3'               => '918 1298',
	'c2'               => '1298 1836',
	'c1'               => '1836 2599',
	'c0'               => '2599 3676',
	'b10.*jis'         => '90 127',
	'b9.*jis'          => '127 180',
	'b8.*jis'          => '180 257',
	'b7.*jis'          => '257 362',
	'b6.*jis'          => '362 518',
	'b5.*jis'          => '518 727',
	'b4.*jis'          => '727 1029',
	'b3.*jis'          => '1029 1459',
	'b2.*jis'          => '1459 2063',
	'b1.*jis'          => '2063 2919',
	'b0.*jis'          => '2919 4127',
	'jis.*b10'         => '90 127',
	'jis.*b9'          => '127 180',
	'jis.*b8'          => '180 257',
	'jis.*b7'          => '257 362',
	'jis.*b6'          => '362 518',
	'jis.*b5'          => '518 727',
	'jis.*b4'          => '727 1029',
	'jis.*b3'          => '1029 1459',
	'jis.*b2'          => '1459 2063',
	'jis.*b1'          => '2063 2919',
	'jis.*b0'          => '2919 4127',
	'b10.*iso'         => '87 124',
	'b9.*iso'          => '124 175',
	'b8.*iso'          => '175 249',
	'b7.*iso'          => '249 354',
	'b6.*iso'          => '354 498',
	'b5.*iso'          => '498 708',
	'b4.*iso'          => '708 1000',
	'b3.*iso'          => '1000 1417',
	'b2.*iso'          => '1417 2004',
	'b1.*iso'          => '2004 2834',
	'b0.*iso'          => '2834 4008',
	'2b.*iso'          => '4008 5669',
	'4b.*iso'          => '5669 8016',
	'iso.*b10'         => '87 124',
	'iso.*b9'          => '124 175',
	'iso.*b8'          => '175 249',
	'iso.*b7'          => '249 354',
	'iso.*b6'          => '354 498',
	'iso.*b5'          => '498 708',
	'iso.*b4'          => '708 1000',
	'iso.*b3'          => '1000 1417',
	'iso.*b2'          => '1417 2004',
	'iso.*b1'          => '2004 2834',
	'iso.*b0'          => '2834 4008',
	'iso.*2b'          => '4008 5669',
	'iso.*4b'          => '5669 8016',
	'b10envelope'      => '87 124',
	'b9envelope'       => '124 175',
	'b8envelope'       => '175 249',
	'b7envelope'       => '249 354',
	'b6envelope'       => '354 498',
	'b5envelope'       => '498 708',
	'b4envelope'       => '708 1000',
	'b3envelope'       => '1000 1417',
	'b2envelope'       => '1417 2004',
	'b1envelope'       => '2004 2834',
	'b0envelope'       => '2834 4008',
	'b10'              => '87 124',
	'b9'               => '124 175',
	'b8'               => '175 249',
	'b7'               => '249 354',
	'b6'               => '354 498',
	'b5'               => '498 708',
	'b4'               => '708 1000',
	'b3'               => '1000 1417',
	'b2'               => '1417 2004',
	'b1'               => '2004 2834',
	'b0'               => '2834 4008',
	'monarch'          => '279 540',
	'dl'               => '311 623',
	'com10'            => '297 684',
	'com.*10'          => '297 684',
	'hagaki'           => '283 420',
	'oufuku'           => '420 567',
	'kaku'             => '680 941',
	'long.*3'          => '340 666',
	'long.*4'          => '255 581',
	'foolscap'         => '576 936',
	'flsa'             => '612 936',
	'flse'             => '648 936',
	'photo100x150'     => '283 425',
	'photo200x300'     => '567 850',
	'photofullbleed'   => '298 440',
	'photo4x6'         => '288 432',
	'photo'            => '288 432',
	'wide'             => '977 792',
	'card148'          => '419 297',
	'envelope132x220'  => '374 623',
	'envelope61/2'     => '468 260',
	'supera'           => '644 1008',
	'superb'           => '936 1368',
	'fanfold5'         => '612 792',
	'fanfold4'         => '612 864',
	'fanfold3'         => '684 792',
	'fanfold2'         => '864 612',
	'fanfold1'         => '1044 792',
	'fanfold'          => '1071 792',
	'panoramic'        => '595 1683',
	'plotter.*size.*a' => '612 792',
	'plotter.*size.*b' => '792 1124',
	'plotter.*size.*c' => '1124 1584',
	'plotter.*size.*d' => '1584 2448',
	'plotter.*size.*e' => '2448 3168',
	'plotter.*size.*f' => '3168 4896',
	'archlarge'        => '162 540',
	'standardaddr'     => '81 252',
	'largeaddr'        => '101 252',
	'suspensionfile'   => '36 144',
	'videospine'       => '54 423',
	'badge'            => '153 288',
	'archsmall'        => '101 540',
	'videotop'         => '130 223',
	'diskette'         => '153 198',
	'76\.2mmroll'      => '216 0',
	'69\.5mmroll'      => '197 0',
	'roll'             => '612 0',
	'custom'           => '0 0'
	};

    # Remove prefixes which sometimes could appear
    $papersize =~ s/form_//;

    # Check whether the paper size name is in the list above
    for $item (keys(%{$sizetable})) {
	if ($papersize =~ /$item/) {
	    return $sizetable->{$item};
	}
    }

    # Check if we have a "<Width>x<Height>" format, assume the numbers are
    # given in inches
    if ($papersize =~ /(\d+)x(\d+)/) {
	my $w = $1 * 72;
	my $h = $2 * 72;
	return sprintf("%d %d", $w, $h);
    }

    # Check if we have a "w<Width>h<Height>" format, assume the numbers are
    # given in points
    if ($papersize =~ /w(\d+)h(\d+)/) {
	return "$1 $2";
    }

    # Check if we have a "w<Width>" format, assume roll paper with the given
    # width in points
    if ($papersize =~ /w(\d+)/) {
	return "$1 0";
    }

    # This paper size is absolutely unknown, issue a warning
    warn "WARNING: Unknown paper size: $papersize!";
    return "0 0";
}

# Load an XML object from the library
# You specify the relative file path (to .../db/), less the .xml on the end.
sub _get_object_xml {
    my ($this, $file, $quiet) = @_;

    open XML, "$libdir/db/$file.xml"
	or do { warn "Cannot open file $libdir/db/$file.xml\n"
		    if !$quiet;
		return undef; };
    my $xml = join('', (<XML>));
    close XML;

    return $xml;
}

# Write an XML object from the library
# You specify the relative file path (to .../db/), less the .xml on the end.
sub _set_object_xml {
    my ($this, $file, $stuff, $cache) = @_;

    my $dir = "$libdir/db";
    my $xfile = "$dir/$file.xml";
    umask 0002;
    open XML, ">$xfile.$$"
	or do { warn "Cannot write file $xfile.$$\n";
		return undef; };
    print XML $stuff;
    close XML;
    rename "$xfile.$$", $xfile
	or die "Cannot rename $xfile.$$ to $xfile\n";

    return 1;
}

# Get a list of XML filenames from a library directory.  These could then be
# read with _get_object_xml.
sub _get_xml_filelist {
    my ($this, $dir) = @_;

    if (!defined($this->{"names-$dir"})) {
	opendir DRV, "$libdir/db/$dir"
	    or die 'Cannot find source db for $dir\n';
	my $driverfile;
	while($driverfile = readdir(DRV)) {
	    next if ($driverfile !~ m!^(.+)\.xml$!);
	    push(@{$this->{"names-$dir"}}, $1);
	}
	closedir(DRV);
    }

    return @{$this->{"names-$dir"}};
}


# Return a Perl structure in eval-able ascii format
sub getascii {
    my ($this) = $_[0];
    if (! $this->{'dat'}) {
	$this->getdat();
    }
    
    local $Data::Dumper::Purity=1;
    local $Data::Dumper::Indent=1;

    # Encase data for inclusion in PPD file
    return Dumper($this->{'dat'});
}

# Return list of printer makes
sub get_makes {
    my ($this) = @_;

    my @makes;
    my %seenmakes;
    my $p;
    for $p (@{$this->get_overview()}) {
	my $make = $p->{'make'};
	push (@makes, $make) 
	    if ! $seenmakes{$make}++;
    }
	
    return @makes;
	
}

# get a list of model names from a make
sub get_models_by_make {
    my ($this, $wantmake) = @_;

    my $over = $this->get_overview();

    my @models;
    my $p;
    for $p (@{$over}) {
	push (@models, $p->{'model'}) 
	    if ($wantmake eq $p->{'make'});
    }

    return @models;
}

# get a printer id from a make/model
sub get_printer_from_make_model {
    my ($this, $wantmake, $wantmodel) = @_;

    my $over = $this->get_overview();
    my $p;
    for $p (@{$over}) {
	return $p->{'id'} if ($p->{'make'} eq $wantmake
			      and $p->{'model'} eq $wantmodel);
    }

    return undef;
}

sub get_javascript2 {

    my ($this) = @_;

    my @swit;
    my $mak;
    my $else = "";
    for $mak ($this->get_makes()) {
	push (@swit,
	      " $else if (make == \"$mak\") {\n");

	my $ct = 0;
	my $mod;
	for $mod (sort {normalizename($a) cmp normalizename($b) } 
		  $this->get_models_by_make($mak)) {
	    
	    my $p;
	    $p = $this->get_printer_from_make_model($mak, $mod);
	    if (defined($p)) {
		push (@swit,
		      "      o[i++]=new Option(\"$mod\", \"$p\");\n");
		$ct++;
	    }
	}

	if (!$ct) {
	    push(@swit,
		 "      o[i++]=new Option(\"No Printers\", \"0\");\n");
	}

	push (@swit,
	      "    }");
	$else = "else";
    }

    my $switch = join('',@swit);

    my $javascript = '
       function reflectMake(makeselector, modelselector) {
	 //
	 // This function is called when makeselector changes
	 // by an onchange thingy on the makeselector.
	 //

	 // Get the value of the OPTION that just changed
	 selected_value=makeselector.options[makeselector.selectedIndex].value;
	 // Get the text of the OPTION that just changed
	 make=makeselector.options[makeselector.selectedIndex].text;

	 o = new Array;
	 i=0;

     ' . $switch . '    if (i==0) {
	   alert("Error: that dropdown should do something, but it doesnt");
	 } else {
	   modelselector.length=o.length;
	   for (i=0; i < o.length; i++) {
	     modelselector.options[i]=o[i];
	   }
	   modelselector.options[0].selected=true;
	 }

       }
     ';

    return $javascript;
}

################################3
#################################


# Modify comments text to contain only what it should:
#
# <a>, <p>, <br> (<br> -> <p>)
#
sub comment_filter {
    my ($text) = @_;

    my $fake = ("INSERTFIXEDTHINGHERE" . sprintf("%06x", rand(1000000)));
    my %replacements;
    my $num = 1;

    # extract all the A href tags
    my $replace = "ANCHOR$fake$num";
    while ($text =~ 
	   s!(<\s*a\s+href\s*=\s*['"]([^'"]+)['"]\s*>)!$replace!i) {
	$replacements{$replace} = $1;
	$num++;
	$replace = "ANCHOR$fake$num";
    }

    # extract all the A tail tags
    my $replace = "ANCHORTAIL$fake$num";
    while ($text =~ 
	   s!(<\s*/\s*a\s*>)!$replace!i) {
	$replacements{$replace} = $1;
	$num++;
	$replace = "ANCHOR$fake$num";
    }

    # extract all the P tags
    $replace = "PARA$fake$num";
    while ($text =~ 
	   s!(<\s*p\s*>)!$replace!i) {

	$replacements{$replace} = $1;
	$num++;
	$replace = "PARA$fake$num";
    }

    # extract all the BR tags
    $replace = "PARA$fake$num";
    while ($text =~ 
	   s!(<\s*br\s*>)!$replace!i) {

	$replacements{$replace} = $1;
	$num++;
	$replace = "PARA$fake$num";
    }

    # Now it's just clean text; remove all tags and &foo;s
    $text =~ s!<[^>]+>! !g;
    $text =~ s!&amp;!&!g;
    $text =~ s!&lt;!<!g;
    $text =~ s!&gt;!>!g;
    $text =~ s!&[^;]+?;! !g;

    # Now rewrite into our teeny-html subset
    $text =~ s!&!&amp;!g;
    $text =~ s!<!&lt;!g;
    $text =~ s!>!&gt;!g;

    # And reinsert the few things we wanted to preserve
    for (keys(%replacements)) {
	my ($k, $r) = ($_, $replacements{$_});
	$text =~ s!$k!$r!;
    }

#    print STDERR "$text";

    return $text;
}

1;
