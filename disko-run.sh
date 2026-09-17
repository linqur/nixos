#!/bin/sh

nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode disko ./disko.nix