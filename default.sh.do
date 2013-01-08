#!/usr/bin/perl

$arg1=$ARGV[0];
$arg2=$ARGV[1];
$arg3=$ARGV[2];

@args = ("redo-ifchange", "bootstrap_pkgs.sh", "$arg1.in");
system(@args) == 0 or exit $?;

open SRC, '<', "$arg1.in";
open BOOTSTRAP_PKGS, '<', "bootstrap_pkgs.sh";
open OUT, '>', $arg3;

while ( <SRC> ) {
    if(/\%\%BOOTSTRAP_PKGS\%\%\n/) {
        while ( <BOOTSTRAP_PKGS> ) {
            print OUT;
        }
    } else {
        print OUT;
    }
}




