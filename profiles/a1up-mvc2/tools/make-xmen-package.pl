#!/usr/bin/perl
#
# Builds the X-Men '97 deluxe package out of the MvC2 one.
#
# The two cabinets are the same board, so the installer, RetroArch, the cores, the ROM list and
# every shell step are identical -- the only real differences are the frontend APK (different
# artwork, different music, and the MvC2 tile pointed at XmenLegalActivity) and the wording of
# the documents. Copying and rewriting beats maintaining a second tree by hand: run this again
# after any change to the MvC2 package and the X-Men one follows along.
#
# usage: perl make-xmen-package.pl <src-package-dir> <dst-package-dir> <xmen-frontend.apk>

use strict;
use warnings;
use File::Find;
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy);
use File::Basename qw(dirname basename);
use File::Spec;

my ($SRC, $DST, $APK) = @ARGV;
die "usage: make-xmen-package.pl <src> <dst> <frontend.apk>\n" unless $SRC && $DST && $APK;
die "no such source package: $SRC\n" unless -d $SRC;
die "no such apk: $APK\n" unless -f $APK;

remove_tree($DST) if -d $DST;
make_path($DST);

# Documents that are build notes rather than user-facing copy. CONTROL-SCREENS.md describes how
# the control diagrams were derived from the stock MvC2 app's own artwork -- that history is
# true regardless of which cabinet the package is for, so rewriting "MVC2" inside it would make
# it wrong.
my %VERBATIM = map { $_ => 1 } ('docs/CONTROL-SCREENS.md');

# Longest first: the folder name has to be consumed before "MVC2" gets at it (otherwise the
# mac instructions tell people to cd into "X-Men '97-Cabinet-Mod-v2"), and "Marvel vs Capcom 2"
# before anything tries "MvC2".
my @RULES = (
    [basename($SRC)       => basename($DST)],
    ['MARVEL VS CAPCOM 2' => "X-MEN '97 DELUXE"],
    ['Marvel vs Capcom 2' => "X-Men '97"],
    ['MvC2'               => "X-Men '97"],
    ['MVC2'               => "X-Men '97"],
    ['Mvc2'               => "X-Men '97"],
);

my $rewritten = 0;
my $copied    = 0;

find({
    no_chdir => 1,
    wanted   => sub {
        my $path = $File::Find::name;
        return if -d $path;
        my $rel = File::Spec->abs2rel($path, $SRC);
        $rel =~ s{\\}{/}g;
        my $out = "$DST/$rel";
        make_path(dirname($out));

        if ($rel =~ /\.(txt|bat|command|sh|ps1|md|cfg)$/i && !$VERBATIM{$rel}) {
            open my $in, '<:raw', $path or die "read $path: $!";
            my $body = do { local $/; <$in> };
            close $in;
            my $before = $body;
            for my $r (@RULES) {
                my ($from, $to) = @$r;
                $body =~ s/\Q$from\E/$to/g;
            }
            open my $o, '>:raw', $out or die "write $out: $!";
            print $o $body;
            close $o;
            $rewritten++ if $body ne $before;
            $copied++;
        } else {
            copy($path, $out) or die "copy $path: $!";
            $copied++;
        }
    },
}, $SRC);

# The one binary that actually differs.
copy($APK, "$DST/apk/Frontend.apk") or die "copy apk: $!";

# --- fixes the blanket search-and-replace cannot make ------------------------------------------

# "Marvel vs Capcom 2" was 18 characters wide and held a column; "X-Men '97" is 9.
edit("$DST/docs/GAMES.txt", sub {
    $_[0] =~ s/^  X-Men '97      the original/  X-Men '97               the original/m;
});

# A reader who downloaded the wrong one of the two packages needs to find that out here, and an
# owner who hit the "com.arcade is not installed" toast deserves to know it is dealt with.
edit("$DST/README.txt", sub {
    $_[0] =~ s/(WHAT'S NEW IN THIS BUILD)/about_build() . $1/e
        or die "README.txt: could not find the WHAT'S NEW heading\n";
});

print "copied $copied files, rewrote wording in $rewritten of them\n";
print "frontend: ", basename($APK), " -> apk/Frontend.apk\n";

# Applies $fn to a file's contents in place, keeping its CRLF line endings.
sub edit {
    my ($path, $fn) = @_;
    open my $r, '<:raw', $path or die "read $path: $!";
    my $body = do { local $/; <$r> };
    close $r;
    $fn->($body);
    open my $w, '>:raw', $path or die "write $path: $!";
    print $w $body;
    close $w;
}

sub about_build {
    my $note = <<'TEXT';
ABOUT THIS BUILD
----------------
This is the X-MEN '97 edition of the mod.  There is a separate
download for the Marvel vs Capcom 2 cabinet - use whichever one
matches your machine.

Both cabinets run the same board and the same software, so this
package is identical to the MvC2 one apart from two things:

  *  The menu background, the tile for your own game and the menu
     music are X-Men '97.
  *  The menu finds your cabinet's own game by asking Android for
     it, instead of by a fixed name.  The X-Men cabinet calls its
     start-up screen XmenLegalActivity where the MvC2 cabinet calls
     it LegalActivity - which is why an earlier release put up
     "com.arcade is not installed" when you picked your own game.

Thanks to the X-Men '97 owner who tracked that name down and
reported it.

TEXT
    $note =~ s/\n/\r\n/g;
    return $note;
}
