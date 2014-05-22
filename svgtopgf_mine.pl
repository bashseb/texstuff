#! /usr/bin/perl -w
# SE May 22 added
# LPPL licencse (http://www.tex.ac.uk/tex-archive/help/Catalogue/licenses.lppl.html)
# original from http://bazaar.launchpad.net/~tex-sx/tex-sx/development/view/head:/svgtopgf.pl
# changed name to svgtopgf_mime.pl

exit unless (@ARGV);

use XML::Tiny qw(parsefile);

$precision = 10**3;

open($xmlfile,$ARGV[0]);

$prefix = $ARGV[1];
$debug = 2;

$doc = parsefile($xmlfile);

%fontattribs = %{$doc->[0]{"content"}[1]{"content"}[0]{"attrib"}};
%attribs = %{$doc->[0]{"content"}[1]{"content"}[0]{"content"}[0]{"attrib"}};
$scale = $attribs{"units-per-em"};
$fontwidth = $fontattribs{"horiz-adv-x"}/$scale;
$height = $attribs{"ascent"}/$scale;
$depth = $attribs{"descent"}/$scale;
@glyphs =  @{$doc->[0]{"content"}[1]{"content"}[0]{"content"}};
$nglyphs = @glyphs;

$dir = "chars";
mkdir $dir;

$actions = &init_actions();

for ($i = 0; $i<$nglyphs; $i++) {
    if ($glyphs[$i]{"name"} eq "glyph" and exists($glyphs[$i]{"attrib"}{"unicode"})) {
        $glyph = ord($glyphs[$i]{"attrib"}{"unicode"});
        debugmsg(1,"Generating $glyph");
        if (exists $glyphs[$i]{"attrib"}{"d"}) {
            $svg = $glyphs[$i]{"attrib"}{"d"};
            $svg =~ s/\n//g;
            $lsvg = length($svg);
            $j = 0;
            $path = [];
            $elt = {};
            while ($j < $lsvg) {
                $c = substr($svg,$j,1);
                if ($c eq " ") {
                    $j++;
                } elsif (index("mzlhvcsqtaMZLHVCSQTA",$c) != -1) {
                    $elt = {
                        "type" => $c,
                        "coordinates" => [],
                    };
                    push @$path,$elt;
                    $j++;
                } else {
                    pos($svg) = $j;
                    if ($svg =~ /\G(-?[0-9]*\.?[0-9]+)/) {
                        push @{$elt->{"coordinates"}}, $1/$scale;
                        $j = pos($svg) + length($1);
                    } else {
                        $j++;
                    }
                }
            }
            &printpgf($prefix . $glyph,$path);
        } else {
            debugmsg(2,"Empty path, skipping $glyph");
        }
        if (exists $glyphs[$i]{"attrib"}{"horiz-adv-x"}) {
            $width = $glyphs[$i]{"attrib"}{"horiz-adv-x"}/$scale;
        } else {
            $width = $fontwidth;
        }
        &printbb($prefix . $glyph,$width,$height,$depth);
    } elsif ($glyphs[$i]{"name"} eq "hkern") {
#       debugmsg(2,"Considering kern");
#       $kerna = ord($glyphs[$i]{"attrib"}{"u1"});
#       $kernb = ord($glyphs[$i]{"attrib"}{"u2"});
#       $kern = -$glyphs[$i]{"attrib"}{"k"}/$scale;
#       &printkern($prefix,$kerna,$kernb,$kern);
    }
}

sub printpgf {
    my $name = shift;
    my $path = shift;
    my $l = @$path;
    my $action;
    my $coord = [0,0,0,0];
    my $lc;
    my $tc;
    my $act;
    my $step;
    # handle for glyph
    open(MYGLYPH, ">$dir/gly_$name") 
      or die  "cannot open $dir/gly_$name";
    # handle for file for points
    open(MYPTS, ">$dir/pts_$name") 
      or die  "cannot open $dir/pts_$name";
    # handle for Bezier control handles
    open(MYBEZ, ">$dir/bezier_$name") 
      or die  "cannot open $dir/bezier_$name";
    select(MYGLYPH);
    #     print '\expandafter\def\csname ' . $name . '\endcsname{%' . "\n";
    for (my $i = 0; $i < $l; $i++) {
        $action = $path->[$i]{"type"};
        $coords = $path->[$i]{"coordinates"};
        while ($action) {
            if (exists $actions->{$action}) {
                $action = &{$actions->{$action}}($coord,$coords);
            } else {
                debugmsg(1,"No action defined for $action");
                $action = '';
            }
        }
    }
    # print '}%' . "\n\n";
    close(MYGLYPH);
    close(MYPTS);
    close(MYBEZ);
    select(STDOUT);
}

sub printbb {
    my ($name,$w,$h,$d) = @_;
    print '\expandafter\def\csname ' . $name . '@minbb\endcsname{%' . "\n"
        . '\pgfpointxy{0}{' . $d . '}%' . "\n"
        . '}' . "\n\n";
    print '\expandafter\def\csname ' . $name . '@maxbb\endcsname{%' . "\n"
        . '\pgfpointxy{' . $w . '}{' . $h . '}%' . "\n"
        . '}' . "\n\n";
    return;    
}

sub printkern {
    my ($p,$a,$b,$k) = @_;
    print '\expandafter\def\csname ' . $p . 'kern@' . $a . '@' . $b . '\endcsname{' . &printnum($k) . '}' . "\n";
    return;
}

sub init_actions {

    return  {
    "M" => sub {
        my $coord = shift;
        my $coords = shift;
        my $x = shift @$coords;
        my $y = shift @$coords; 
        $coord->[0] = $x;
        $coord->[1] = $y;
        $coord->[2] = $coord->[0];
        $coord->[3] = $coord->[1];
        print '\pgfpathmoveto{\pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . '}}' . "%\n";
        print MYPTS '\pgfpathcircle{ \pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . "} } {.1pt}\n";
        if (@$coords) {
            return 'L';
        } else {
            return '';
        }
    },
    "m" => sub {
        my $coord = shift;
        my $coords = shift;
        my $x = shift @$coords;
        my $y = shift @$coords; 
        $coord->[0] += $x;
        $coord->[1] += $y;
        $coord->[2] = $coord->[0];
        $coord->[3] = $coord->[1];
        print '\pgfpathmoveto{\pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . '}}' . "%\n";
        print MYPTS '\pgfpathcircle{ \pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . "} } {.1pt}\n";
        if (@$coords) {
            return 'l';
        } else {
            return '';
        }
    },
    "L" => sub {
        my $coord = shift;
        my $coords = shift;
        my $x = shift @$coords;
        my $y = shift @$coords; 
        $coord->[0] = $x;
        $coord->[1] = $y;
        $coord->[2] = $coord->[0];
        $coord->[3] = $coord->[1];
        print '\pgfpathlineto{\pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . '}}' . "%\n";
        print MYPTS '\pgfpathcircle{ \pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . "} } {.1pt}\n";
        if (@$coords) {
            return 'L';
        } else {
            return '';
        }
    },
    "l" => sub {
        my $coord = shift;
        my $coords = shift;
        my $x = shift @$coords;
        my $y = shift @$coords; 
        $coord->[0] += $x;
        $coord->[1] += $y;
        $coord->[2] = $coord->[0];
        $coord->[3] = $coord->[1];
        print '\pgfpathlineto{\pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . '}}' . "%\n";
        print MYPTS '\pgfpathcircle{ \pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . "} } {.1pt}\n";
        if (@$coords) {
            return 'l';
        } else {
            return '';
        }
    },
    "V" => sub {
        my $coord = shift;
        my $coords = shift;
        my $y = shift @$coords; 
        $coord->[1] = $y;
        $coord->[2] = $coord->[0];
        $coord->[3] = $coord->[1];
        print '\pgfpathlineto{\pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . '}}' . "%\n";
        print MYPTS '\pgfpathcircle{ \pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . "} } {.1pt}\n";
        if (@$coords) {
            return 'V';
        } else {
            return '';
        }
    },
    "v" => sub {
        my $coord = shift;
        my $coords = shift;
        my $y = shift @$coords; 
        $coord->[1] += $y;
        $coord->[2] = $coord->[0];
        $coord->[3] = $coord->[1];
        print '\pgfpathlineto{\pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . '}}' . "%\n";
        print MYPTS '\pgfpathcircle{ \pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . "} } {.1pt}\n";
        if (@$coords) {
            return 'v';
        } else {
            return '';
        }
    },
    "H" => sub {
        my $coord = shift;
        my $coords = shift;
        my $x = shift @$coords; 
        $coord->[0] = $x;
        $coord->[2] = $coord->[0];
        $coord->[3] = $coord->[1];
        print '\pgfpathlineto{\pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . '}}' . "%\n";
        print MYPTS '\pgfpathcircle{ \pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . "} } {.1pt}\n";
        if (@$coords) {
            return 'H';
        } else {
            return '';
        }
    },
    "h" => sub {
        my $coord = shift;
        my $coords = shift;
        my $x = shift @$coords; 
        $coord->[0] += $x;
        $coord->[2] = $coord->[0];
        $coord->[3] = $coord->[1];
        print '\pgfpathlineto{\pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . '}}' . "%\n";
        print MYPTS '\pgfpathcircle{ \pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . "} } {.1pt}\n";
        if (@$coords) {
            return 'h';
        } else {
            return '';
        }
    },
    "C" => sub {
        my $coord = shift;
        my $coords = shift;
        my $xa = shift @$coords;
        my $ya = shift @$coords; 
        my $xb = shift @$coords;
        my $yb = shift @$coords; 
        my $x = shift @$coords;
        my $y = shift @$coords; 
        # print first cubic bezier handle
        print MYBEZ '\draw[{Arc Barb[length=2pt]}-{Ellipse[]}] (' . 
            &printnum($coord->[0]) . ',' . &printnum($coord->[1]) . ') -- (' . 
            &printnum($xa) . ',' . &printnum($ya) . ");\n";
        $coord->[0] = $x;
        $coord->[1] = $y;
        $coord->[2] = 2*$x - $xb;
        $coord->[3] = 2*$y - $yb;
        # print second cubic bezier handle
        print MYBEZ '\draw[{Arc Barb[length=2pt]}-{Ellipse[]}] (' . 
            &printnum($coord->[0]) . ',' . &printnum($coord->[1]) . ') -- (' . 
            &printnum($xb) . ',' . &printnum($yb) . ");\n";
        print '\pgfpathcurveto{' 
            . '\pgfpointxy{' . &printnum($xa) . '}{' . &printnum($ya) . '}}{'
            . '\pgfpointxy{' . &printnum($xb) . '}{' . &printnum($yb) . '}}{'
            . '\pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . '}}' . "%\n";
        print MYPTS '\pgfpathcircle{ \pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . "} } {.1pt}% Bezier c end\n";
        if (@$coords) {
            return 'C';
        } else {
            return '';
        }
    },
    "c" => sub {
        my $coord = shift;
        my $coords = shift;
        my $xa = shift @$coords;
        my $ya = shift @$coords; 
        my $xb = shift @$coords;
        my $yb = shift @$coords; 
        my $x = shift @$coords;
        my $y = shift @$coords; 
        $xa += $coord->[0];
        $ya += $coord->[1];
        # print first cubic bezier handle
        print MYBEZ '\draw[{Arc Barb[length=2pt]}-{Ellipse[]}] (' . 
            &printnum($coord->[0]) . ',' . &printnum($coord->[1]) . ') -- (' . 
            &printnum($xa) . ',' . &printnum($ya) . ");\n";
        $xb += $coord->[0];
        $yb += $coord->[1];
        $coord->[0] += $x;
        $coord->[1] += $y;
        $coord->[2] = 2*$coord->[0] - $xb;
        $coord->[3] = 2*$coord->[1] - $yb;
        # print second cubic bezier handle
        print MYBEZ '\draw[{Arc Barb[length=2pt]}-{Ellipse[]}] (' . 
            &printnum($coord->[0]) . ',' . &printnum($coord->[1]) . ') -- (' . 
            &printnum($xb) . ',' . &printnum($yb) . ");\n";

        print '\pgfpathcurveto{' 
            . '\pgfpointxy{' . &printnum($xa) . '}{' . &printnum($ya) . '}}{'
            . '\pgfpointxy{' . &printnum($xb) . '}{' . &printnum($yb) . '}}{'
            . '\pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . '}}' . "%\n";
        print MYPTS '\pgfpathcircle{ \pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . "} } {.1pt}% Bezier c end\n";
        if (@$coords) {
            return 'c';
        } else {
            return '';
        }
    },
    "S" => sub {
        my $coord = shift;
        my $coords = shift;
        my $xa = $coord->[2];
        my $ya = $coord->[3];
        my $xb = shift @$coords;
        my $yb = shift @$coords; 
        my $x = shift @$coords;
        my $y = shift @$coords; 
        # print first cubic bezier handle
        print MYBEZ '\draw[{Arc Barb[length=2pt]}-{Ellipse[]}] (' . 
            &printnum($coord->[0]) . ',' . &printnum($coord->[1]) . ') -- (' . 
            &printnum($xa) . ',' . &printnum($ya) . ");\n";
        $coord->[0] = $x;
        $coord->[1] = $y;
        $coord->[2] = 2*$x - $xb;
        $coord->[3] = 2*$y - $yb;
        # print second cubic bezier handle
        print MYBEZ '\draw[{Arc Barb[length=2pt]}-{Ellipse[]}] (' . 
            &printnum($coord->[0]) . ',' . &printnum($coord->[1]) . ') -- (' . 
            &printnum($xb) . ',' . &printnum($yb) . ");\n";
        print '\pgfpathcurveto{' 
            . '\pgfpointxy{' . &printnum($xa) . '}{' . &printnum($ya) . '}}{'
            . '\pgfpointxy{' . &printnum($xb) . '}{' . &printnum($yb) . '}}{'
            . '\pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . '}}' . "%\n";
        print MYPTS '\pgfpathcircle{ \pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . "} } {.1pt}% Bezier c end\n";
        if (@$coords) {
            return 'S';
        } else {
            return '';
        }
    },
    "s" => sub {
        my $coord = shift;
        my $coords = shift;
        my $xa = $coord->[2];
        my $ya = $coord->[3];
        my $xb = shift @$coords;
        my $yb = shift @$coords; 
        my $x = shift @$coords;
        my $y = shift @$coords; 
        # print first cubic bezier handle
        print MYBEZ '\draw[{Arc Barb[length=2pt]}-{Ellipse[]}] (' . 
            &printnum($coord->[0]) . ',' . &printnum($coord->[1]) . ') -- (' . 
            &printnum($xa) . ',' . &printnum($ya) . ");\n";
        $xb += $coord->[0];
        $yb += $coord->[1];
        $coord->[0] += $x;
        $coord->[1] += $y;
        $coord->[2] = 2*$coord->[0] - $xb;
        $coord->[3] = 2*$coord->[1] - $yb;
        # print second cubic bezier handle
        print MYBEZ '\draw[{Arc Barb[length=2pt]}-{Ellipse[]}] (' . 
            &printnum($coord->[0]) . ',' . &printnum($coord->[1]) . ') -- (' . 
            &printnum($xb) . ',' . &printnum($yb) . ");\n";
        print '\pgfpathcurveto{' 
            . '\pgfpointxy{' . &printnum($xa) . '}{' . &printnum($ya) . '}}{'
            . '\pgfpointxy{' . &printnum($xb) . '}{' . &printnum($yb) . '}}{'
            . '\pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . '}}' . "%\n";
        print MYPTS '\pgfpathcircle{ \pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . "} } {.1pt}% Bezier c end\n";
        if (@$coords) {
            return 's';
        } else {
            return '';
        }
    },
    "Z" => sub {
        print '\pgfpathclose' . "%\n";
        print MYPTS "% (closed)\n";
        return '';
    },
    "z" => sub {
        print '\pgfpathclose' . "%\n";
        print MYPTS "% (closed)\n";
        return '';
    },
    "Q" => sub {
        my $coord = shift;
        my $coords = shift;
        my $xa = shift @$coords;
        my $ya = shift @$coords; 
        my $x = shift @$coords;
        my $y = shift @$coords; 
        # print first quadratic bezier handle
        print MYBEZ '\draw[{Arc Barb[length=2pt]}-{Ellipse[]}] (' . 
            &printnum($coord->[0]) . ',' . &printnum($coord->[1]) . ') -- (' . 
            &printnum($xa) . ',' . &printnum($ya) . ");\n";
        $coord->[0] = $x;
        $coord->[1] = $y;
        $coord->[2] = 2*$x - $xa;
        $coord->[3] = 2*$y - $ya;
        # print second quadratic bezier handle (same destination as first one)
        print MYBEZ '\draw[{Arc Barb[length=2pt]}-{Ellipse[]}] (' . 
            &printnum($coord->[0]) . ',' . &printnum($coord->[1]) . ') -- (' . 
            &printnum($xa) . ',' . &printnum($ya) . ");\n";
        print '\pgfpathquadraticcurveto{' 
            . '\pgfpointxy{' . &printnum($xa) . '}{' . &printnum($ya) . '}}{'
            . '\pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . '}}' . "%\n";
        print MYPTS '\pgfpathcircle{ \pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . "} } {.1pt}% Quadr Bezier c end\n";
        if (@$coords) {
            return 'Q';
        } else {
            return '';
        }
    },
    "q" => sub {
        my $coord = shift;
        my $coords = shift;
        my $xa = shift @$coords;
        my $ya = shift @$coords; 
        my $x = shift @$coords;
        my $y = shift @$coords; 
        $xa += $coord->[0];
        $ya += $coord->[1];
        # print first quadratic bezier handle
        print MYBEZ '\draw[{Arc Barb[length=2pt]}-{Ellipse[]}] (' . 
            &printnum($coord->[0]) . ',' . &printnum($coord->[1]) . ') -- (' . 
            &printnum($xa) . ',' . &printnum($ya) . ");\n";
        $coord->[0] += $x;
        $coord->[1] += $y;
        $coord->[2] = 2*$coord->[0] - $xa;
        $coord->[3] = 2*$coord->[1] - $ya;
        # print second quadratic bezier handle (same destination as first one)
        print MYBEZ '\draw[{Arc Barb[length=2pt]}-{Ellipse[]}] (' . 
            &printnum($coord->[0]) . ',' . &printnum($coord->[1]) . ') -- (' . 
            &printnum($xa) . ',' . &printnum($ya) . ");\n";
        print '\pgfpathquadraticcurveto{' 
            . '\pgfpointxy{' . &printnum($xa) . '}{' . &printnum($ya) . '}}{'
            . '\pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . '}}' . "%\n";
        print MYPTS '\pgfpathcircle{ \pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . "} } {.1pt}% Quadr Bezier c end\n";
        if (@$coords) {
            return 'q';
        } else {
            return '';
        }
    },
    "T" => sub {
        my $coord = shift;
        my $coords = shift;
        my $xa = $coord->[2];
        my $ya = $coord->[3];
        my $x = shift @$coords;
        my $y = shift @$coords; 
        # print first quadratic bezier handle
        print MYBEZ '\draw[{Arc Barb[length=2pt]}-{Ellipse[]}] (' . 
            &printnum($coord->[0]) . ',' . &printnum($coord->[1]) . ') -- (' . 
            &printnum($xa) . ',' . &printnum($ya) . ");\n";
        $coord->[0] = $x;
        $coord->[1] = $y;
        $coord->[2] = 2*$x - $xa;
        $coord->[3] = 2*$y - $ya;
        # print second quadratic bezier handle (same destination as first one)
        print MYBEZ '\draw[{Arc Barb[length=2pt]}-{Ellipse[]}] (' . 
            &printnum($coord->[0]) . ',' . &printnum($coord->[1]) . ') -- (' . 
            &printnum($xa) . ',' . &printnum($ya) . ");\n";
        print '\pgfpathquadraticcurveto{' 
            . '\pgfpointxy{' . &printnum($xa) . '}{' . &printnum($ya) . '}}{'
            . '\pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . '}}' . "%\n";
        print MYPTS '\pgfpathcircle{ \pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . "} } {.1pt}% Quadr Bezier c end\n";
        if (@$coords) {
            return 'T';
        } else {
            return '';
        }
    },
    "t" => sub {
        my $coord = shift;
        my $coords = shift;
        my $xa = $coord->[2];
        my $ya = $coord->[3];
        my $x = shift @$coords;
        my $y = shift @$coords; 
        # print first quadratic bezier handle
        print MYBEZ '\draw[{Arc Barb[length=2pt]}-{Ellipse[]}] (' . 
            &printnum($coord->[0]) . ',' . &printnum($coord->[1]) . ') -- (' . 
            &printnum($xa) . ',' . &printnum($ya) . ");\n";
        $coord->[0] += $x;
        $coord->[1] += $y;
        $coord->[2] = 2*$coord->[0] - $xa;
        $coord->[3] = 2*$coord->[1] - $ya;
        # print second quadratic bezier handle (same destination as first one)
        print MYBEZ '\draw[{Arc Barb[length=2pt]}-{Ellipse[]}] (' . 
            &printnum($coord->[0]) . ',' . &printnum($coord->[1]) . ') -- (' . 
            &printnum($xa) . ',' . &printnum($ya) . ");\n";
        print '\pgfpathquadraticcurveto{' 
            . '\pgfpointxy{' . &printnum($xa) . '}{' . &printnum($ya) . '}}{'
            . '\pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . '}}' . "%\n";
        print MYPTS '\pgfpathcircle{ \pgfpointxy{' . &printnum($coord->[0]) . '}{' . &printnum($coord->[1]) . "} } {.1pt}% Quadr Bezier c end\n";
        if (@$coords) {
            return 't';
        } else {
            return '';
        }
    },

};

}

sub printnum {
    my $n = shift;
    my $m = 1;
    if ($n < 0) {
        $n = -$n;
        $m = -1;
    }
    return $m * int($precision*$n + .5)/$precision;
}

sub debugmsg {
    my ($lvl, $msg) = @_;
    if ($lvl <= $debug) {
        print STDERR $msg . "\n";
    }
    return;
}
